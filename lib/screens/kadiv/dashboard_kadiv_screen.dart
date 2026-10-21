import 'package:flutter/material.dart';
import '../../login_screen.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/notification_bell.dart';
import '../shared/detail_pengaduan_screen.dart';
import '../shared/riwayat_pengaduan_screen.dart';
import '../shared/surat_detail_pengaduan_screen.dart';

import '../../theme/app_colors.dart';
import '../../widgets/konfirmasi_dialog.dart';
import '../../widgets/media_lampiran_picker.dart';
import '../../services/theme_controller.dart';
import '../../services/api_service.dart';
/// Dashboard untuk role Kadiv Kategori — Tahap 3 & Tahap 4 (fungsional).
/// Data pengaduan diambil dari Supabase lewat [PengaduanService], semua
/// aksi (verifikasi, selesaikan tindak lanjut) langsung menulis ke
/// database (bukan lagi mutasi object in-memory).
enum _KadivClusterFilter {
  semua,
  menungguVerifikasi,
  investigasi,
  diterima,
  ditolak,
  selesai,
}

class DashboardKadivScreen extends StatefulWidget {
  final AppUser user;
  final bool showBackButton;
  const DashboardKadivScreen({
    super.key,
    required this.user,
    this.showBackButton = true,
  });

  @override
  State<DashboardKadivScreen> createState() => _DashboardKadivScreenState();
}

class _DashboardKadivScreenState extends State<DashboardKadivScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengaduan>> _future;

  /// Cluster filter tab status pengaduan
  _KadivClusterFilter _clusterFilter = _KadivClusterFilter.semua;

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  /// Kotak masuk dibatasi sesuai divisi Kadiv yang login: Kadiv
  /// Administrasi hanya menerima "Pelanggaran Administrasi", Kadiv Teknik
  /// hanya menerima "Pelanggaran Teknik".
  Future<List<Pengaduan>> _muat() {
    return PengaduanService.untukRoleSebagaiObjek(
      UserRole.kadivKategori,
      divisiKadiv: widget.user.divisiKadiv?.name,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _muat();
    });
    await _future;
  }

  Future<void> _logout() async {
    await ApiService.logout();
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

  Future<void> _bukaVerifikasi(Pengaduan p) async {
    String kategoriPilihan = p.kategori;
    const opsiKategori = ['Pelanggaran Administrasi', 'Pelanggaran Teknik'];
    final divisiSaya = widget.user.divisiKadiv;
    final catatanController = TextEditingController();
    String? errorCatatan;

    final aksi = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final divisiKategori = divisiKadivDariKategori(kategoriPilihan);
            final pindahDivisi = divisiSaya != null &&
                divisiKategori != null &&
                divisiKategori != divisiSaya;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.divider(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const Text('Tinjau & Verifikasi Pengaduan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(p.nomorPengaduan,
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary(context))),
                    const SizedBox(height: 14),
                    Text(
                      'Perbaiki jenis kategori pelanggaran bila pelapor salah menempatkannya. '
                      'Bila dialihkan ke divisi lain, pengaduan berpindah ke Kadiv tersebut.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Text('Kategori Pelanggaran',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: opsiKategori.map((k) {
                        final selected = kategoriPilihan == k;
                        return ChoiceChip(
                          label: Text(k,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : AppColors.textPrimary(context),
                                fontWeight: FontWeight.w600,
                              )),
                          selected: selected,
                          selectedColor: _accent,
                          onSelected: (_) => setSheetState(() => kategoriPilihan = k),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: catatanController,
                      maxLines: 3,
                      onChanged: (_) {
                        if (errorCatatan != null) {
                          setSheetState(() => errorCatatan = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: pindahDivisi
                            ? 'Alasan pengalihan kategori (opsional)'
                            : 'Catatan verifikasi (wajib jika ditolak)',
                        errorText: errorCatatan,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (errorCatatan != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE74C3C), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorCatatan!,
                                style: const TextStyle(
                                  color: Color(0xFFE74C3C),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (pindahDivisi) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final setuju = await showKonfirmasiDialog(
                              context: context,
                              judul: 'Konfirmasi Pengalihan',
                              pesan:
                                  'Apakah Anda yakin ingin mengalihkan pengaduan No. ${p.nomorPengaduan} ke ${divisiKategori?.label ?? "divisi lain"}?',
                              labelKonfirmasi: 'Ya, Alihkan',
                              warnaKonfirmasi: const Color(0xFFE67E22),
                              iconHeader: Icons.swap_horiz_rounded,
                            );
                            if (setuju && ctx.mounted) {
                              Navigator.pop(ctx, 'alihkan');
                            }
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: Text('Alihkan ke ${divisiKategori?.label ?? "Divisi Lain"}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE67E22),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                if (catatanController.text.trim().isEmpty) {
                                  setSheetState(() {
                                    errorCatatan = 'Alasan penolakan wajib diisi pada catatan.';
                                  });
                                  return;
                                }
                                final setuju = await showKonfirmasiDialog(
                                  context: context,
                                  judul: 'Konfirmasi Penolakan',
                                  pesan:
                                      'Apakah Anda yakin mencatat TOLAK pengaduan No. ${p.nomorPengaduan} ini? (Tetap diteruskan ke KSPI)',
                                  labelKonfirmasi: 'Ya, Tolak',
                                  warnaKonfirmasi: const Color(0xFFE74C3C),
                                  iconHeader: Icons.cancel_outlined,
                                );
                                if (setuju && ctx.mounted) {
                                  Navigator.pop(ctx, 'tolak');
                                }
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Tolak'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE74C3C),
                                side: const BorderSide(color: Color(0xFFE74C3C)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final setuju = await showKonfirmasiDialog(
                                  context: context,
                                  judul: 'Konfirmasi Penerimaan',
                                  pesan:
                                      'Apakah Anda yakin MENERIMA pengaduan No. ${p.nomorPengaduan} dan meneruskannya ke KSPI?',
                                  labelKonfirmasi: 'Ya, Terima',
                                  warnaKonfirmasi: const Color(0xFF27AE60),
                                  iconHeader: Icons.check_circle_outline,
                                );
                                if (setuju && ctx.mounted) {
                                  Navigator.pop(ctx, 'terima');
                                }
                              },
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text('Terima & Teruskan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (aksi == null) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      if (aksi == 'alihkan') {
        await PengaduanService.alihkanKategoriKadiv(
          pengaduanId: id,
          oleh: widget.user.name,
          kategoriBaru: kategoriPilihan,
          nomorPengaduan: p.nomorPengaduan,
          catatan: catatanController.text.trim().isEmpty ? null : catatanController.text.trim(),
        );
        if (!mounted) return;
        _showSnack('${p.nomorPengaduan} dialihkan ke kategori $kategoriPilihan.', const Color(0xFFE67E22));
      } else {
        final keputusan = aksi == 'terima' ? Keputusan.terima : Keputusan.tolak;
        final kategoriBaru = kategoriPilihan != p.kategori ? kategoriPilihan : null;
        await PengaduanService.kadivAksi(
          pengaduanId: id,
          oleh: widget.user.name,
          keputusan: keputusan,
          catatan: catatanController.text.trim().isEmpty ? null : catatanController.text.trim(),
          kategoriBaru: kategoriBaru,
        );
        if (!mounted) return;
        _showSnack(
          aksi == 'terima'
              ? '${p.nomorPengaduan} diterima & diteruskan ke KSPI.'
              : '${p.nomorPengaduan} ditolak & diteruskan ke KSPI.',
          const Color(0xFF27AE60),
        );
      }
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  Future<void> _bukaKirimHasil(Pengaduan p) async {
    final hasilController = TextEditingController();
    final rekomendasiController = TextEditingController();
    String kesimpulanInvestigasi = p.kesimpulanInvestigasi ?? 'terbukti';
    final mediaController = MediaLampiranController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.divider(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const Text('Kirim Hasil Investigasi',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(p.nomorPengaduan,
                          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context))),
                      const SizedBox(height: 14),
                      Text(
                        'Kesimpulan Pemeriksaan *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => kesimpulanInvestigasi = 'terbukti'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: kesimpulanInvestigasi == 'terbukti'
                                      ? const Color(0xFFE74C3C).withOpacity(0.1)
                                      : AppColors.surfaceMuted(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: kesimpulanInvestigasi == 'terbukti'
                                        ? const Color(0xFFE74C3C)
                                        : AppColors.divider(context),
                                    width: kesimpulanInvestigasi == 'terbukti' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.gavel_rounded,
                                        size: 16,
                                        color: kesimpulanInvestigasi == 'terbukti'
                                            ? const Color(0xFFE74C3C)
                                            : AppColors.textSecondary(context)),
                                    const SizedBox(width: 6),
                                    Text('Terbukti',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: kesimpulanInvestigasi == 'terbukti'
                                              ? const Color(0xFFE74C3C)
                                              : AppColors.textPrimary(context),
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setSheetState(() => kesimpulanInvestigasi = 'tidak_terbukti'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: kesimpulanInvestigasi == 'tidak_terbukti'
                                      ? const Color(0xFF0284C7).withOpacity(0.1)
                                      : AppColors.surfaceMuted(context),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: kesimpulanInvestigasi == 'tidak_terbukti'
                                        ? const Color(0xFF0284C7)
                                        : AppColors.divider(context),
                                    width: kesimpulanInvestigasi == 'tidak_terbukti' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_user_rounded,
                                        size: 16,
                                        color: kesimpulanInvestigasi == 'tidak_terbukti'
                                            ? const Color(0xFF0284C7)
                                            : AppColors.textSecondary(context)),
                                    const SizedBox(width: 6),
                                    Text('Tidak Terbukti',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: kesimpulanInvestigasi == 'tidak_terbukti'
                                              ? const Color(0xFF0284C7)
                                              : AppColors.textPrimary(context),
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Hasil Investigasi (Foto / Video / Voice Note / Dokumen)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      MediaLampiranPicker(
                        controller: mediaController,
                        prefix: p.nomorPengaduan,
                        bucket: 'pengaduan-bukti',
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: hasilController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Catatan temuan investigasi / fakta lapangan',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Surat Rekomendasi *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setSheetState(() {
                                if (kesimpulanInvestigasi == 'terbukti') {
                                  rekomendasiController.text =
                                      'Berdasarkan hasil investigasi dan bukti-bukti yang diperoleh di lapangan, terlapor terbukti melakukan pelanggaran sebagaimana diadukan. Direkomendasikan kepada Direktur Utama untuk meneruskan berkas ini kepada Bagian SDM guna penetapan Surat Putusan Sanksi disiplin sesuai peraturan kepegawaian yang berlaku.';
                                } else {
                                  rekomendasiController.text =
                                      'Berdasarkan hasil investigasi mendalam dan verifikasi bukti-bukti di lapangan, terlapor dinyatakan TIDAK TERBUKTI melakukan pelanggaran yang diadukan. Direkomendasikan kepada Direktur Utama untuk menerima hasil ini, mengarsipkan berkas pengaduan, dan memulihkan nama baik terlapor.';
                                }
                              });
                            },
                            icon: const Icon(Icons.description_outlined, size: 14),
                            label: const Text('Template',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: rekomendasiController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Surat rekomendasi ke Dirut',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (mediaController.isEmpty ||
                                rekomendasiController.text.trim().isEmpty) {
                              _showSnack(
                                  'Lampiran hasil investigasi & surat rekomendasi wajib diisi.',
                                  const Color(0xFFE74C3C));
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Kirim ke Dirut'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;
    final id = p.supabaseId;
    if (id == null) return;
    if (!mounted) return;

    final setuju = await showKonfirmasiDialog(
      context: context,
      judul: 'Konfirmasi Kirim Hasil Investigasi',
      pesan:
          'Apakah Anda yakin ingin mengirim hasil investigasi (Kesimpulan: ${kesimpulanInvestigasi == "terbukti" ? "TERBUKTI" : "TIDAK TERBUKTI"}) pengaduan No. ${p.nomorPengaduan} ini ke Direktur Utama?',
      labelKonfirmasi: 'Ya, Kirim ke Dirut',
      warnaKonfirmasi: _navy,
      iconHeader: Icons.send_rounded,
    );
    if (!setuju) return;

    try {
      await PengaduanService.kirimHasilInvestigasi(
        pengaduanId: id,
        oleh: widget.user.name,
        role: UserRole.kadivKategori,
        hasil: hasilController.text.trim().isEmpty
            ? (kesimpulanInvestigasi == 'terbukti'
                ? 'Terbukti bersalah berdasarkan bukti terlampir.'
                : 'Tidak terbukti berdasarkan bukti terlampir.')
            : hasilController.text.trim(),
        rekomendasi: rekomendasiController.text.trim(),
        kesimpulanInvestigasi: kesimpulanInvestigasi,
        foto: mediaController.foto,
        video: mediaController.video,
        voice: mediaController.voice,
        dokumen: mediaController.dokumen,
      );

      if (!mounted) return;
      _showSnack('Hasil investigasi ${p.nomorPengaduan} dikirim ke Dirut.', const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  Future<void> _bukaSelesaikanTindakLanjut(Pengaduan p) async {
    final catatanController = TextEditingController();

    final konfirmasi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: AppColors.divider(context),
                      borderRadius: BorderRadius.circular(10)),
                ),
                const Text('Selesaikan Tindak Lanjut',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(p.nomorPengaduan,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context))),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.surfaceMuted(context),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Instruksi Direktur',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary(context))),
                      const SizedBox(height: 4),
                      Text(p.tindakLanjutDiminta ?? '-',
                          style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: catatanController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Keterangan penyelesaian (opsional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Tandai Selesai'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8449),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (konfirmasi != true) return;
    final id = p.supabaseId;
    if (id == null) return;
    if (!mounted) return;

    final setuju = await showKonfirmasiDialog(
      context: context,
      judul: 'Konfirmasi Penyelesaian Tindak Lanjut',
      pesan:
          'Apakah Anda yakin tindak lanjut pengaduan No. ${p.nomorPengaduan} ini telah selesai dilaksanakan?',
      labelKonfirmasi: 'Ya, Selesaikan',
      warnaKonfirmasi: const Color(0xFF1E8449),
      iconHeader: Icons.task_alt_rounded,
    );
    if (!setuju) return;

    try {
      await PengaduanService.selesaikanTindakLanjut(
        pengaduanId: id,
        oleh: widget.user.name,
        role: UserRole.kadivKategori,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      // Beri tahu pelapor asli (bukan seluruh role pegawai) bahwa
      // pengaduannya sudah selesai.
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
      _showSnack(
          '${p.nomorPengaduan} ditandai selesai.', const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.kadivKategori],
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
              final menungguVerifikasi = semua
                  .where((p) => p.status == PengaduanStatus.menungguKadiv)
                  .where((p) => widget.user.divisiKadiv == null
                      ? true
                      : divisiKadivDariKategori(p.kategori) ==
                          widget.user.divisiKadiv)
                  .toList();
              final tindakLanjut = semua
                  .where((p) =>
                      p.status == PengaduanStatus.investigasiBerjalan &&
                      p.eksekutor == Eksekutor.kadiv &&
                      (widget.user.divisiKadiv == null ||
                          p.eksekutorDivisiKadiv == null ||
                          p.eksekutorDivisiKadiv == widget.user.divisiKadiv))
                  .toList();
              // Riwayat keputusan Kadiv (Terima/Tolak) yang sudah dicatat,
              // dikelompokkan untuk topbar status "Diterima" / "Ditolak".
              // Kedua kelompok ini SAMA-SAMA sudah/sedang ditinjau ulang
              // oleh KSPI — keputusan Kadiv hanya dicatat, bukan final.
              final keputusanKadivSaya = semua
                  .where((p) => p.keputusanKadiv != null)
                  .where((p) => widget.user.divisiKadiv == null
                      ? true
                      : divisiKadivDariKategori(p.kategori) ==
                              widget.user.divisiKadiv ||
                          p.kategoriDivisi != null)
                  .toList();
              final diterimaKadiv = keputusanKadivSaya
                  .where((p) => p.keputusanKadiv == Keputusan.terima)
                  .toList();
              final ditolakKadiv = keputusanKadivSaya
                  .where((p) => p.keputusanKadiv == Keputusan.tolak)
                  .toList();
              final selesai = semua
                  .where((p) =>
                      p.status == PengaduanStatus.selesai ||
                      p.status == PengaduanStatus.arsip)
                  .toList();

              Widget listContent;
              switch (_clusterFilter) {
                case _KadivClusterFilter.semua:
                  if (semua.isEmpty) {
                    listContent = _buildEmptyState('Tidak ada data pengaduan untuk divisi Anda.');
                  } else {
                    listContent = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (menungguVerifikasi.isNotEmpty) ...[
                          _buildSectionTitle('PENGADUAN MASUK — MENUNGGU VERIFIKASI', menungguVerifikasi.length),
                          const SizedBox(height: 10),
                          ...menungguVerifikasi.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Tinjau & Verifikasi',
                                onAksi: () => _bukaVerifikasi(p),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (tindakLanjut.isNotEmpty) ...[
                          _buildSectionTitle('INVESTIGASI DITUGASKAN', tindakLanjut.length),
                          const SizedBox(height: 10),
                          ...tindakLanjut.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Kirim Hasil Investigasi',
                                onAksi: () => _bukaKirimHasil(p),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (diterimaKadiv.isNotEmpty) ...[
                          _buildSectionTitle('RIWAYAT DITERIMA KADIV', diterimaKadiv.length),
                          const SizedBox(height: 10),
                          ...diterimaKadiv.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Detail',
                                onAksi: () => _bukaDetail(p),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (ditolakKadiv.isNotEmpty) ...[
                          _buildSectionTitle('RIWAYAT DITOLAK KADIV', ditolakKadiv.length),
                          const SizedBox(height: 10),
                          ...ditolakKadiv.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Detail',
                                onAksi: () => _bukaDetail(p),
                              )),
                          const SizedBox(height: 16),
                        ],
                        if (selesai.isNotEmpty) ...[
                          _buildSectionTitle('PENGADUAN SELESAI & ARSIP', selesai.length),
                          const SizedBox(height: 10),
                          ...selesai.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Detail',
                                onAksi: () => _bukaDetail(p),
                              )),
                        ],
                      ],
                    );
                  }
                  break;
                case _KadivClusterFilter.menungguVerifikasi:
                  listContent = menungguVerifikasi.isEmpty
                      ? _buildEmptyState('Tidak ada pengaduan yang menunggu verifikasi.')
                      : Column(
                          children: menungguVerifikasi.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Tinjau & Verifikasi',
                                onAksi: () => _bukaVerifikasi(p),
                              )).toList(),
                        );
                  break;
                case _KadivClusterFilter.investigasi:
                  listContent = tindakLanjut.isEmpty
                      ? _buildEmptyState('Tidak ada investigasi yang ditugaskan ke Anda.')
                      : Column(
                          children: tindakLanjut.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Kirim Hasil Investigasi',
                                onAksi: () => _bukaKirimHasil(p),
                              )).toList(),
                        );
                  break;
                case _KadivClusterFilter.diterima:
                  listContent = diterimaKadiv.isEmpty
                      ? _buildEmptyState('Belum ada pengaduan yang Anda terima.')
                      : Column(
                          children: diterimaKadiv.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Detail',
                                onAksi: () => _bukaDetail(p),
                              )).toList(),
                        );
                  break;
                case _KadivClusterFilter.ditolak:
                  listContent = ditolakKadiv.isEmpty
                      ? _buildEmptyState('Belum ada pengaduan yang Anda tolak.')
                      : Column(
                          children: ditolakKadiv.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Detail',
                                onAksi: () => _bukaDetail(p),
                              )).toList(),
                        );
                  break;
                case _KadivClusterFilter.selesai:
                  listContent = selesai.isEmpty
                      ? _buildEmptyState('Belum ada pengaduan selesai atau diarsipkan.')
                      : Column(
                          children: selesai.map((p) => _buildPengaduanCard(
                                p,
                                tombolLabel: 'Detail',
                                onAksi: () => _bukaDetail(p),
                              )).toList(),
                        );
                  break;
              }

              content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClusterBar(
                    countSemua: semua.length,
                    countMenunggu: menungguVerifikasi.length,
                    countInvestigasi: tindakLanjut.length,
                    countDiterima: diterimaKadiv.length,
                    countDitolak: ditolakKadiv.length,
                    countSelesai: selesai.length,
                  ),
                  listContent,
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
              if (widget.showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  tooltip: 'Kembali',
                  onPressed: () => Navigator.maybePop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'KADIV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                tooltip: 'Riwayat Pengaduan',
                visualDensity: VisualDensity.compact,
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
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ThemeController.instance.setDark(!isDark),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Muat ulang',
                visualDensity: VisualDensity.compact,
                onPressed: _refresh,
              ),
              IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: NotificationBell(role: UserRole.kadivKategori, user: widget.user),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Keluar',
                visualDensity: VisualDensity.compact,
                onPressed: _logout,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tugas Verifikasi & Eksekusi',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 20.0 : 23.0,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Verifikasi & kelola pengaduan divisimu',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: isSmallScreen ? 12.0 : 13.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu putih profil pengguna yang "mengambang" di atas header navy —
  /// ukuran, radius, dan bayangannya meniru persis kartu jadwal
  /// ("Selasa, 04 Agustus") pada dashboard pegawai, agar temanya konsisten.
  Widget _buildProfileCard(int jumlahMasuk) {
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
                Text('$jumlahMasuk',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context))),
                const Text('Masuk',
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

  Widget _buildSectionTitle(String text, int count) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClusterBar({
    required int countSemua,
    required int countMenunggu,
    required int countInvestigasi,
    required int countDiterima,
    required int countDitolak,
    required int countSelesai,
  }) {
    final items = [
      (filter: _KadivClusterFilter.semua, label: 'Semua', count: countSemua, icon: Icons.grid_view_rounded),
      (filter: _KadivClusterFilter.menungguVerifikasi, label: 'Menunggu Verifikasi', count: countMenunggu, icon: Icons.hourglass_top_rounded),
      (filter: _KadivClusterFilter.investigasi, label: 'Investigasi', count: countInvestigasi, icon: Icons.search_rounded),
      (filter: _KadivClusterFilter.diterima, label: 'Diterima', count: countDiterima, icon: Icons.check_circle_outline_rounded),
      (filter: _KadivClusterFilter.ditolak, label: 'Ditolak', count: countDitolak, icon: Icons.highlight_off_rounded),
      (filter: _KadivClusterFilter.selesai, label: 'Selesai & Arsip', count: countSelesai, icon: Icons.task_alt_rounded),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: items.map((c) {
            final isSelected = _clusterFilter == c.filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _clusterFilter = c.filter),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? _navy : AppColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _navy : AppColors.divider(context),
                      width: 1.2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: _navy.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.icon,
                        size: 14,
                        color: isSelected ? Colors.white : AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : AppColors.surfaceMuted(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${c.count}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: AppColors.divider(context)),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildPengaduanCard(
    Pengaduan p, {
    required String tombolLabel,
    required VoidCallback onAksi,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              'Pelapor: ${p.namaPegawai}',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 2),
            Text(
                'Kategori: ${p.kategori} · ${formatTanggalJam(p.tanggalPengaduan)}',
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
                          builder: (_) => SuratDetailPengaduanScreen(
                            user: widget.user,
                            pengaduanId: id,
                            initialPengaduan: p,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Surat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    label: const Text('Detail', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
              ],
            ),
            if (tombolLabel != 'Detail') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAksi,
                  icon: const Icon(Icons.fact_check_rounded, size: 16),
                  label: Text(tombolLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}