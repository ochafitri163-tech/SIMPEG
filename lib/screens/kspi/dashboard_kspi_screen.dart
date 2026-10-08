import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_screen.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/pegawai_picker_sheet.dart';
import '../shared/detail_pengaduan_screen.dart';
import '../shared/riwayat_pengaduan_screen.dart';

import '../../theme/app_colors.dart';
import '../../services/theme_controller.dart';
import '../../services/onesignal_service.dart';
/// Dashboard untuk role KSPI — Tahap 3 & Tahap 4 (fungsional).
/// Data & aksi sudah terhubung ke Supabase lewat [PengaduanService].
class DashboardKspiScreen extends StatefulWidget {
  final AppUser user;
  final bool showBackButton;
  const DashboardKspiScreen({
    super.key,
    required this.user,
    this.showBackButton = true,
  });

  @override
  State<DashboardKspiScreen> createState() => _DashboardKspiScreenState();
}

class _DashboardKspiScreenState extends State<DashboardKspiScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengaduan>> _future;

  /// Tab kategori "Review Awal dari Kadiv": 0 = Diterima Kadiv,
  /// 1 = Ditolak Kadiv. Keduanya tetap masuk ke KSPI untuk ditinjau &
  /// diverifikasi ulang (baik yang diterima maupun ditolak Kadiv).
  int _kadivTab = 0;

  @override
  void initState() {
    super.initState();
    _future = PengaduanService.untukRoleSebagaiObjek(UserRole.kspi);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PengaduanService.untukRoleSebagaiObjek(UserRole.kspi);
    });
    await _future;
  }

  Future<void> _logout() async {
    try {
      await OneSignalService.instance.logoutUser();
    } catch (_) {}
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _bukaDetail(Pengaduan p) async {
    final id = p.supabaseId;
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PengaduanDetailScreen(user: widget.user, pengaduanId: id),
      ),
    );
    await _refresh();
  }

  // ---------- Jalankan & selesaikan tindak lanjut (status tindakLanjutBerjalan) ----------
  Future<void> _bukaSelesaikanTindakLanjut(Pengaduan p) async {
    final catatanController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Jalankan & Selesaikan Tindak Lanjut', p),
            _infoBlok('Instruksi Direktur', p.tindakLanjutDiminta ?? '-'),
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Keterangan penyelesaian (opsional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: const Text('Tandai Selesai & Teruskan ke SDM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok != true) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      await PengaduanService.selesaikanTindakLanjut(
        pengaduanId: id,
        oleh: widget.user.name,
        role: UserRole.kspi,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      final detail = await PengaduanService.detail(id);
      final pelaporId = detail?['pelapor_id'] as String?;
      if (pelaporId != null) {
        await NotificationService.kirimKePegawai(
          pegawaiId: pelaporId,
          judul: 'Pengaduan selesai',
          pesan:
              '${p.nomorPengaduan} — tindak lanjut telah dijalankan & dinyatakan selesai.',
          pengaduanId: id,
        );
      }

      if (!mounted) return;
      _showSnack('${p.nomorPengaduan} selesai & diteruskan ke SDM.',
          const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  // ---------- Teruskan ke Dirut / Tolak (status reviewKspi) ----------
  // Baik pengaduan yang tadinya DITERIMA maupun DITOLAK Kadiv sama-sama
  // masuk ke sini untuk ditinjau & diverifikasi ulang oleh KSPI. Dari
  // sini KSPI bisa meneruskan ke Direktur ATAU menolaknya sendiri
  // (wajib isi alasan) — bila ditolak, proses berhenti & diarsipkan.
  Future<void> _bukaTeruskanKeDirut(Pengaduan p) async {
    final catatanController = TextEditingController();

    final aksi = await _openSheet<String>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Review & Verifikasi KSPI', p),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (p.keputusanKadiv == Keputusan.tolak
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFF27AE60))
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    p.keputusanKadiv == Keputusan.tolak
                        ? Icons.close_rounded
                        : Icons.check_rounded,
                    size: 16,
                    color: p.keputusanKadiv == Keputusan.tolak
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFF27AE60),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Keputusan Kadiv: ${p.keputusanKadiv?.label ?? '-'}'
                      '${(p.catatanKadiv ?? '').trim().isNotEmpty ? ' — ${p.catatanKadiv}' : ''}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _infoBlok('Judul', p.judul),
            const SizedBox(height: 10),
            _infoBlok('Deskripsi', p.deskripsi),
            const SizedBox(height: 16),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    'Catatan (opsional utk teruskan, WAJIB bila tolak)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (catatanController.text.trim().isEmpty) {
                        _showSnack(
                            'Alasan penolakan wajib diisi.',
                            const Color(0xFFE74C3C));
                        return;
                      }
                      Navigator.pop(ctx, 'tolak');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Tolak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE74C3C),
                      side: const BorderSide(color: Color(0xFFE74C3C)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'teruskan'),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Teruskan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });

    if (aksi == null) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      if (aksi == 'tolak') {
        await PengaduanService.kspiTolak(
          pengaduanId: id,
          oleh: widget.user.name,
          catatan: catatanController.text.trim(),
        );
        if (!mounted) return;
        _showSnack(
            '${p.nomorPengaduan} ditolak KSPI & diarsipkan. Pelapor telah diberi tahu.',
            const Color(0xFFE74C3C));
      } else {
        await PengaduanService.kspiTeruskanKeDirut(
          pengaduanId: id,
          oleh: widget.user.name,
          catatan: catatanController.text.trim().isEmpty
              ? null
              : catatanController.text.trim(),
        );
        if (!mounted) return;
        _showSnack('${p.nomorPengaduan} diteruskan ke Direktur.',
            const Color(0xFF27AE60));
      }
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  Future<T?> _openSheet<T>(
      Widget Function(BuildContext, void Function(void Function())) builder) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: builder(ctx, setSheetState),
          ),
        ),
      ),
    );
  }

  Widget _grip() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: AppColors.divider(context), borderRadius: BorderRadius.circular(10)),
      );

  Widget _judulSheet(String title, Pengaduan p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(p.nomorPengaduan,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context))),
          const SizedBox(height: 16),
        ],
      );

  // ---------- 1. Review awal & pilih eksekutor ----------
  Future<void> _bukaReviewAwal(Pengaduan p) async {
    List<PegawaiOption> selectedExecutors = [];
    final catatanController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Review & Pilih Eksekutor', p),
            if ((p.catatanPeninjauanKembali ?? '').isNotEmpty) ...[
              _infoBlok(
                  'Peninjauan Kembali dari Direktur', p.catatanPeninjauanKembali!),
              const SizedBox(height: 14),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Eksekutor Pegawai',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (selectedExecutors.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedExecutors.length} Terpilih',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _accent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih 1 atau beberapa pegawai SIMPEG sebagai tim eksekutor investigasi.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // Selector Button / List Card untuk Eksekutor
            if (selectedExecutors.isEmpty)
              InkWell(
                onTap: () async {
                  final res = await showPegawaiMultiPickerSheet(
                    context: ctx,
                    selectedPegawaiList: selectedExecutors,
                    title: 'Pilih Tim Eksekutor Investigasi',
                  );
                  if (res != null) {
                    setSheetState(() => selectedExecutors = res);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E2638)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2C384E)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          color: _accent, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pilih Pegawai Eksekutor',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, color: _accent),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  ...selectedExecutors.map((peg) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _accent,
                            child: Text(
                              peg.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  peg.name,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${peg.jabatan} • NIK: ${peg.nik}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.redAccent),
                            onPressed: () {
                              setSheetState(() {
                                selectedExecutors
                                    .removeWhere((item) => item.id == peg.id);
                              });
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await showPegawaiMultiPickerSheet(
                        context: ctx,
                        selectedPegawaiList: selectedExecutors,
                        title: 'Edit Tim Eksekutor Investigasi',
                      );
                      if (res != null) {
                        setSheetState(() => selectedExecutors = res);
                      }
                    },
                    icon: const Icon(Icons.group_add_rounded, size: 18),
                    label: const Text('Tambah / Edit Tim Eksekutor'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _accent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan Penugasan (opsional)',
                hintText: 'Tambahkan instruksi khusus untuk para eksekutor...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (selectedExecutors.isEmpty) {
                    _showSnack(
                        'Harap pilih minimal 1 pegawai eksekutor.',
                        const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(selectedExecutors.isEmpty
                    ? 'Tetapkan Eksekutor & Buat Tugas'
                    : 'Tetapkan ${selectedExecutors.length} Eksekutor & Buat Tugas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok != true || selectedExecutors.isEmpty) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      await PengaduanService.reviewDanPilihEksekutor(
        pengaduanId: id,
        oleh: widget.user.name,
        selectedExecutors: selectedExecutors,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      if (!mounted) return;
      final names = selectedExecutors.map((e) => e.name).join(', ');
      _showSnack(
          '${p.nomorPengaduan} berhasil ditugaskan ke: $names.',
          const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses penugasan: $e', Colors.red);
    }
  }

  // ---------- 2. Review hasil investigasi dari TPDPK ----------
  Future<void> _bukaReviewHasil(Pengaduan p) async {
    bool sesuai = true;
    final catatanController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Review Hasil Investigasi', p),
            _infoBlok('Hasil Investigasi', p.hasilInvestigasi ?? '-'),
            const SizedBox(height: 10),
            _infoBlok('Surat Rekomendasi', p.suratRekomendasi ?? '-'),
            const SizedBox(height: 16),
            const Text('Apakah hasil investigasi sudah sesuai?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sesuai', style: TextStyle(fontSize: 12)),
                    selected: sesuai,
                    selectedColor: const Color(0xFF27AE60),
                    labelStyle: TextStyle(
                        color: sesuai ? Colors.white : AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setSheetState(() => sesuai = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Belum sesuai',
                        style: TextStyle(fontSize: 12)),
                    selected: !sesuai,
                    selectedColor: const Color(0xFFE74C3C),
                    labelStyle: TextStyle(
                        color: !sesuai ? Colors.white : AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setSheetState(() => sesuai = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: sesuai
                    ? 'Catatan untuk Direktur (opsional)'
                    : 'Alasan revisi (wajib)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!sesuai && catatanController.text.trim().isEmpty) {
                    _showSnack(
                        'Alasan revisi wajib diisi.', const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: Icon(sesuai ? Icons.send_rounded : Icons.replay_rounded,
                    size: 18),
                label: Text(
                    sesuai ? 'Kirim ke Direktur' : 'Kembalikan untuk Revisi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sesuai ? _navy : const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok != true) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      await PengaduanService.reviewHasilInvestigasi(
        pengaduanId: id,
        oleh: widget.user.name,
        sesuai: sesuai,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      await NotificationService.kirimKeRole(
        role: sesuai ? UserRole.direktur : UserRole.tpdpk,
        judul:
            sesuai ? 'Menunggu persetujuan Anda' : 'Revisi investigasi diminta',
        pesan: sesuai
            ? '${p.nomorPengaduan} menunggu persetujuan Direktur.'
            : '${p.nomorPengaduan} dikembalikan untuk revisi investigasi.',
        pengaduanId: id,
      );

      if (!mounted) return;
      _showSnack(
        sesuai
            ? '${p.nomorPengaduan} dikirim ke Direktur.'
            : '${p.nomorPengaduan} dikembalikan untuk revisi.',
        sesuai ? const Color(0xFF27AE60) : const Color(0xFFE67E22),
      );
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  // ---------- 3. Revisi setelah penolakan Direktur ----------
  Future<void> _bukaRevisiPenolakan(Pengaduan p) async {
    final catatanController = TextEditingController();
    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Revisi Setelah Penolakan Direktur', p),
            _infoBlok(
                'Alasan Penolakan Direktur', p.alasanPenolakanDirektur ?? '-'),
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan revisi',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (catatanController.text.trim().isEmpty) {
                    _showSnack(
                        'Catatan revisi wajib diisi.', const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Kirim Ulang ke Direktur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok != true) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      await PengaduanService.kirimUlangSetelahRevisiKspi(
        pengaduanId: id,
        oleh: widget.user.name,
        catatanRevisi: catatanController.text.trim(),
      );

      await NotificationService.kirimKeRole(
        role: UserRole.direktur,
        judul: 'Revisi dari KSPI',
        pesan: '${p.nomorPengaduan} dikirim ulang setelah direvisi KSPI.',
        pengaduanId: id,
      );

      if (!mounted) return;
      _showSnack('${p.nomorPengaduan} dikirim ulang ke Direktur.',
          const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  // ---------- 4. Peninjauan kembali dari Direktur ----------
  Future<void> _bukaPeninjauanKembali(Pengaduan p) async {
    final catatanController = TextEditingController();
    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Peninjauan Kembali dari Direktur', p),
            _infoBlok('Catatan Direktur', p.catatanPeninjauanKembali ?? '-'),
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan pengiriman ulang (opsional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Kirim untuk Investigasi Ulang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok != true) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      await PengaduanService.kirimUntukInvestigasiUlang(
        pengaduanId: id,
        oleh: widget.user.name,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      await NotificationService.kirimKeRole(
        role: UserRole.tpdpk,
        judul: 'Investigasi ulang diminta',
        pesan:
            '${p.nomorPengaduan} perlu investigasi ulang (peninjauan kembali Direktur).',
        pengaduanId: id,
      );

      if (!mounted) return;
      _showSnack('${p.nomorPengaduan} dikirim untuk investigasi ulang.',
          const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  Widget _infoBlok(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.kspi],
      child: Scaffold(
        backgroundColor: AppColors.pageBackground(context),
        // Header & kartu profil sekarang ikut discroll dalam satu ListView
        // (tidak lagi sticky), dan kartu profil diletakkan dalam Stack agar
        // selalu tampil di depan header biru (tidak lagi ketimpa/clip).
        body: FutureBuilder<List<Pengaduan>>(
          future: _future,
          builder: (context, snapshot) {
            Widget content;

            if (snapshot.connectionState == ConnectionState.waiting) {
              content = const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              content = Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'Gagal memuat data: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                ),
              );
            } else {
              final semua = snapshot.data ?? [];
              final siapTeruskanSemua = semua
                  .where((p) => p.status == PengaduanStatus.reviewKspi)
                  .toList();
              final siapTeruskanDiterima = siapTeruskanSemua
                  .where((p) => p.keputusanKadiv == Keputusan.terima)
                  .toList();
              final siapTeruskanDitolak = siapTeruskanSemua
                  .where((p) => p.keputusanKadiv == Keputusan.tolak)
                  .toList();
              final siapTeruskan =
                  _kadivTab == 0 ? siapTeruskanDiterima : siapTeruskanDitolak;
              final reviewAwal = semua
                  .where(
                      (p) => p.status == PengaduanStatus.menungguPilihEksekutor)
                  .toList();
              final reviewHasil = semua
                  .where((p) => p.status == PengaduanStatus.menungguReviewKspi)
                  .toList();
              final ditolak = semua
                  .where((p) =>
                      p.status == PengaduanStatus.tindakLanjutBerjalan &&
                      p.eksekutorTindakLanjut == Eksekutor.kspi)
                  .toList();
              final peninjauan = semua
                  .where((p) => p.status == PengaduanStatus.peninjauanKembali)
                  .toList();

              content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REVIEW AWAL DARI KADIV',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary(context)),
                  ),
                  const SizedBox(height: 10),
                  _buildKadivTabBar(
                      siapTeruskanDiterima.length, siapTeruskanDitolak.length),
                  const SizedBox(height: 12),
                  if (siapTeruskan.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _kadivTab == 0
                            ? 'Belum ada pengaduan yang diterima Kadiv.'
                            : 'Belum ada pengaduan yang ditolak Kadiv.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary(context)),
                      ),
                    )
                  else
                    ...siapTeruskan.map((p) => _buildPengaduanCard(
                        p, _bukaTeruskanKeDirut, 'Tinjau & Verifikasi')),
                  const SizedBox(height: 14),
                  _buildSection(
                      'PILIH EKSEKUTOR INVESTIGASI',
                      reviewAwal,
                      _bukaReviewAwal,
                      'Belum ada pengaduan siap ditugaskan.',
                      'Pilih Eksekutor'),
                  _buildSection(
                      'REVIEW HASIL INVESTIGASI',
                      reviewHasil,
                      _bukaReviewHasil,
                      'Belum ada hasil investigasi masuk.',
                      'Review Hasil'),
                  _buildSection(
                      'TINDAK LANJUT DITUGASKAN',
                      ditolak,
                      _bukaSelesaikanTindakLanjut,
                      'Tidak ada tindak lanjut yang ditugaskan.',
                      'Jalankan'),
                  _buildSection(
                      'PENINJAUAN KEMBALI DARI DIREKTUR',
                      peninjauan,
                      _bukaPeninjauanKembali,
                      'Tidak ada permintaan peninjauan kembali.',
                      'Tindak Lanjuti'),
                ],
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              // Struktur disamakan dengan dashboard pegawai: header & kartu
              // ada dalam satu Column yang discroll bersama (topbar ikut
              // ikut ke atas saat discroll, tidak lagi sticky), dan kartu
              // profil "mengambang" lewat Transform.translate — Column
              // tidak meng-clip contentnya seperti ListView, jadi kartu
              // selalu tampil di depan header, jarak/spacing pun sama
              // persis seperti kartu jadwal di dashboard pegawai.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopHeader(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -28),
                            child: _buildProfileCard(
                                snapshot.data?.length ?? 0),
                          ),
                          const SizedBox(height: 18),
                          content,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16.0 : 20.0,
        MediaQuery.of(context).padding.top + (isSmallScreen ? 10.0 : 14.0),
        isSmallScreen ? 12.0 : 16.0,
        isSmallScreen ? 40.0 : 56.0,
      ),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.showBackButton) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  tooltip: 'Kembali',
                  onPressed: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  'Tasks Penetapan Eksekutor',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18.0 : 21.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                tooltip: 'Riwayat Pengaduan',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiwayatPengaduanScreen(user: widget.user),
                  ),
                ),
              ),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance.themeMode,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: Colors.white,
                    ),
                    tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                    onPressed: () => ThemeController.instance.setDark(!isDark),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Muat ulang',
                onPressed: _refresh,
              ),
              IconTheme(
                data: IconThemeData(color: Colors.white),
                child: NotificationBell(role: UserRole.kspi, user: widget.user),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Keluar',
                onPressed: _logout,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih eksekutor & review hasil investigasi',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: isSmallScreen ? 11.0 : 12.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu putih profil yang mengambang di atas header, meniru persis
  /// kartu jadwal pada dashboard pegawai (ukuran, radius, bayangan).
  Widget _buildProfileCard(int jumlah) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 14.0 : 18.0,
        vertical: isSmallScreen ? 12.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _accent.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 42.0 : 46.0,
            height: isSmallScreen ? 42.0 : 46.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, _accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              image: widget.user.fotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.user.fotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.user.fotoUrl != null
                ? null
                : Text(
                    widget.user.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.5 : 14.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.user.role.label} · ${widget.user.jabatan}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$jumlah',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context))),
                const Text('Perlu Aksi',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Topbar segmented tab "Diterima" / "Ditolak" — mengelompokkan
  /// pengaduan yang masuk ke KSPI berdasarkan keputusan Kadiv sebelumnya.
  Widget _buildKadivTabBar(int jumlahDiterima, int jumlahDitolak) {
    Widget tab(String label, int index, int jumlah, Color warna) {
      final selected = _kadivTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _kadivTab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
            decoration: BoxDecoration(
              color: selected ? warna : warna.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$label ($jumlah)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : warna,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Diterima Kadiv', 0, jumlahDiterima, const Color(0xFF27AE60)),
        tab('Ditolak Kadiv', 1, jumlahDitolak, const Color(0xFFE74C3C)),
      ],
    );
  }

  Widget _buildSection(
    String title,
    List<Pengaduan> items,
    Future<void> Function(Pengaduan) onAksi,
    String emptyText,
    String tombolLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textSecondary(context))),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.centerLeft,
            child: Text(emptyText,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context))),
          )
        else
          ...items.map((p) => _buildPengaduanCard(p, onAksi, tombolLabel)),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildPengaduanCard(Pengaduan p,
      Future<void> Function(Pengaduan) onAksi, String tombolLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.nomorPengaduan,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accent)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: p.status.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(p.status.label,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: p.status.color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.judul,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                'Kategori: ${p.kategori}${p.kategoriDivisi != null ? ' · ${p.kategoriDivisi!.label}' : ''}',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final id = p.supabaseId;
                      if (id == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PengaduanDetailScreen(
                              user: widget.user, pengaduanId: id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Detail', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAksi(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    child:
                        Text(tombolLabel, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}