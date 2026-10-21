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
import '../../services/theme_controller.dart';
import '../../services/api_service.dart';
import '../../widgets/konfirmasi_dialog.dart';
import '../../widgets/media_lampiran_picker.dart';

enum _TpdpkClusterFilter {
  semua,
  menungguPetugas,
  investigasi,
  revisi,
  tindakLanjut,
  selesai,
}

/// Dashboard untuk role TPDPK — Tahap 3 & Tahap 4 (fungsional).
/// Data & aksi sudah terhubung ke Supabase lewat [PengaduanService].
class DashboardTpdpkScreen extends StatefulWidget {
  final AppUser user;
  final bool showBackButton;
  const DashboardTpdpkScreen({
    super.key,
    required this.user,
    this.showBackButton = true,
  });

  @override
  State<DashboardTpdpkScreen> createState() => _DashboardTpdpkScreenState();
}

class _DashboardTpdpkScreenState extends State<DashboardTpdpkScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengaduan>> _future;

  /// Cluster filter tab status pengaduan
  _TpdpkClusterFilter _clusterFilter = _TpdpkClusterFilter.semua;

  @override
  void initState() {
    super.initState();
    _future = PengaduanService.untukRoleSebagaiObjek(UserRole.tpdpk);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PengaduanService.untukRoleSebagaiObjek(UserRole.tpdpk);
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

  // ---------- 1. Pilih petugas investigasi (eksekutor = TPDPK) ----------
  Future<void> _bukaPilihPetugas(Pengaduan p) async {
    final petugasController = TextEditingController();
    String? errorPetugas;
    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Tetapkan Petugas Investigasi', p),
            TextField(
              controller: petugasController,
              onChanged: (_) {
                if (errorPetugas != null) {
                  setSheetState(() => errorPetugas = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Nama petugas investigasi',
                errorText: errorPetugas,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (errorPetugas != null) ...[
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
                        errorPetugas!,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (petugasController.text.trim().isEmpty) {
                    setSheetState(() {
                      errorPetugas = 'Nama petugas wajib diisi.';
                    });
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.badge_rounded, size: 18),
                label: const Text('Tetapkan & Mulai Investigasi'),
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
    if (!mounted) return;

    final setuju = await showKonfirmasiDialog(
      context: context,
      judul: 'Konfirmasi Penetapan Petugas',
      pesan:
          'Apakah Anda yakin ingin menetapkan ${petugasController.text.trim()} sebagai petugas investigasi pengaduan No. ${p.nomorPengaduan}?',
      labelKonfirmasi: 'Ya, Tetapkan',
      warnaKonfirmasi: _navy,
      iconHeader: Icons.badge_rounded,
    );
    if (!setuju) return;

    try {
      await PengaduanService.tpdpkPilihPetugas(
        pengaduanId: id,
        oleh: widget.user.name,
        petugas: petugasController.text.trim(),
      );

      if (!mounted) return;
      _showSnack('Petugas investigasi ditetapkan untuk ${p.nomorPengaduan}.',
          const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  // ---------- 2. Kirim hasil investigasi + surat rekomendasi ----------
  Future<void> _bukaKirimHasil(Pengaduan p, {required bool revisi}) async {
    final hasilController =
        TextEditingController(text: revisi ? (p.hasilInvestigasi ?? '') : '');
    final rekomendasiController =
        TextEditingController(text: revisi ? (p.suratRekomendasi ?? '') : '');
    String kesimpulanInvestigasi = p.kesimpulanInvestigasi ?? 'terbukti';
    String? errorHasil;
    // Lampiran hasil investigasi berupa media (foto/video/voice/dokumen),
    // bukan lagi teks bebas. Saat revisi, lampiran sebelumnya (jika ada)
    // dimuat ulang agar eksekutor bisa melengkapi, bukan mulai dari nol.
    final mediaController = MediaLampiranController();
    if (revisi) {
      mediaController.foto.addAll(p.investigasiFoto);
      mediaController.video.addAll(p.investigasiVideo);
      mediaController.voice.addAll(p.investigasiVoice);
      mediaController.dokumen.addAll(p.investigasiDokumen);
    }

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet(
                revisi
                    ? 'Kirim Ulang Hasil Investigasi (Revisi)'
                    : 'Hasil Investigasi & Surat Rekomendasi',
                p),
            if (revisi && (p.catatanReviewHasilKspi ?? '').isNotEmpty) ...[
              _infoBlok('Catatan Revisi dari KSPI', p.catatanReviewHasilKspi!),
              const SizedBox(height: 14),
            ],
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              onChanged: (_) {
                if (errorHasil != null) {
                  setSheetState(() => errorHasil = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Surat rekomendasi ke Dirut',
                errorText: errorHasil,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (errorHasil != null) ...[
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
                        errorHasil!,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (mediaController.isEmpty ||
                      rekomendasiController.text.trim().isEmpty) {
                    setSheetState(() {
                      errorHasil =
                          'Lampiran hasil investigasi & surat rekomendasi wajib diisi.';
                    });
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(revisi ? 'Kirim ke KSPI' : 'Kirim ke Dirut'),
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
    if (!mounted) return;

    final setuju = await showKonfirmasiDialog(
      context: context,
      judul: revisi ? 'Konfirmasi Kirim Revisi' : 'Konfirmasi Kirim Hasil Investigasi',
      pesan: revisi
          ? 'Apakah Anda yakin ingin mengirim revisi hasil investigasi pengaduan No. ${p.nomorPengaduan} ke KSPI?'
          : 'Apakah Anda yakin ingin mengirim hasil investigasi (Kesimpulan: ${kesimpulanInvestigasi == "terbukti" ? "TERBUKTI" : "TIDAK TERBUKTI"}) pengaduan No. ${p.nomorPengaduan} ini ke Direktur Utama?',
      labelKonfirmasi: revisi ? 'Ya, Kirim Revisi' : 'Ya, Kirim ke Dirut',
      warnaKonfirmasi: _navy,
      iconHeader: Icons.send_rounded,
    );
    if (!setuju) return;

    try {
      if (revisi) {
        await PengaduanService.kirimRevisiInvestigasi(
          pengaduanId: id,
          oleh: widget.user.name,
          hasil: hasilController.text.trim(),
          rekomendasi: rekomendasiController.text.trim(),
          foto: mediaController.foto,
          video: mediaController.video,
          voice: mediaController.voice,
          dokumen: mediaController.dokumen,
        );
        await NotificationService.kirimKeRole(
          role: UserRole.kspi,
          judul: 'Hasil investigasi masuk',
          pesan:
              '${p.nomorPengaduan} dikirim ulang (revisi), menunggu review KSPI.',
          pengaduanId: id,
        );
      } else {
        await PengaduanService.kirimHasilInvestigasi(
          pengaduanId: id,
          oleh: widget.user.name,
          role: UserRole.tpdpk,
          hasil: hasilController.text.trim(),
          rekomendasi: rekomendasiController.text.trim(),
          kesimpulanInvestigasi: kesimpulanInvestigasi,
          foto: mediaController.foto,
          video: mediaController.video,
          voice: mediaController.voice,
          dokumen: mediaController.dokumen,
        );
      }

      if (!mounted) return;
      _showSnack(
          revisi
              ? 'Hasil revisi ${p.nomorPengaduan} dikirim ke KSPI.'
              : 'Hasil investigasi ${p.nomorPengaduan} diteruskan ke Dirut.',
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
          borderRadius: BorderRadius.circular(10)),
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
        role: UserRole.tpdpk,
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
      allowedRoles: const [UserRole.tpdpk, UserRole.kspi],
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
              final menungguPetugas = semua
                  .where((p) => p.status == PengaduanStatus.menungguInvestigasi)
                  .toList();
              final berjalan = semua
                  .where((p) =>
                      p.status == PengaduanStatus.investigasiBerjalan &&
                      p.eksekutor == Eksekutor.tpdpk)
                  .toList();
              final revisi = semua
                  .where((p) =>
                      p.status == PengaduanStatus.revisiInvestigasi &&
                      p.eksekutor == Eksekutor.tpdpk)
                  .toList();
              final tindakLanjut = semua
                  .where((p) =>
                      p.status == PengaduanStatus.tindakLanjutBerjalan &&
                      p.eksekutorTindakLanjut == Eksekutor.tpdpk)
                  .toList();
              final selesai = semua
                  .where((p) =>
                      p.status == PengaduanStatus.selesai ||
                      p.status == PengaduanStatus.arsip)
                  .toList();

              Widget listContent;
              switch (_clusterFilter) {
                case _TpdpkClusterFilter.semua:
                  listContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        'MENUNGGU PENUGASAN PETUGAS',
                        menungguPetugas,
                        (p) => _bukaPilihPetugas(p),
                        'Tidak ada tugas baru.',
                        'Tetapkan Petugas',
                      ),
                      _buildSection(
                        'INVESTIGASI BERJALAN',
                        berjalan,
                        (p) => _bukaKirimHasil(p, revisi: false),
                        'Tidak ada investigasi berjalan.',
                        'Kirim Hasil',
                      ),
                      _buildSection(
                        'PERLU REVISI (DIKEMBALIKAN KSPI)',
                        revisi,
                        (p) => _bukaKirimHasil(p, revisi: true),
                        'Tidak ada revisi yang diminta.',
                        'Kirim Ulang',
                      ),
                      _buildSection(
                        'TINDAK LANJUT DARI DIREKTUR',
                        tindakLanjut,
                        (p) => _bukaSelesaikanTindakLanjut(p),
                        'Tidak ada tindak lanjut yang ditugaskan.',
                        'Selesaikan',
                      ),
                    ],
                  );
                  break;
                case _TpdpkClusterFilter.menungguPetugas:
                  listContent = menungguPetugas.isEmpty
                      ? _buildEmptyState('Tidak ada tugas penugasan baru.')
                      : Column(
                          children: menungguPetugas
                              .map((p) => _buildPengaduanCard(
                                  p, (item) => _bukaPilihPetugas(item), 'Tetapkan Petugas'))
                              .toList(),
                        );
                  break;
                case _TpdpkClusterFilter.investigasi:
                  listContent = berjalan.isEmpty
                      ? _buildEmptyState('Tidak ada investigasi berjalan.')
                      : Column(
                          children: berjalan
                              .map((p) => _buildPengaduanCard(
                                  p, (item) => _bukaKirimHasil(item, revisi: false), 'Kirim Hasil'))
                              .toList(),
                        );
                  break;
                case _TpdpkClusterFilter.revisi:
                  listContent = revisi.isEmpty
                      ? _buildEmptyState('Tidak ada revisi yang diminta.')
                      : Column(
                          children: revisi
                              .map((p) => _buildPengaduanCard(
                                  p, (item) => _bukaKirimHasil(item, revisi: true), 'Kirim Ulang'))
                              .toList(),
                        );
                  break;
                case _TpdpkClusterFilter.tindakLanjut:
                  listContent = tindakLanjut.isEmpty
                      ? _buildEmptyState('Tidak ada tindak lanjut yang ditugaskan.')
                      : Column(
                          children: tindakLanjut
                              .map((p) => _buildPengaduanCard(
                                  p, (item) => _bukaSelesaikanTindakLanjut(item), 'Selesaikan'))
                              .toList(),
                        );
                  break;
                case _TpdpkClusterFilter.selesai:
                  listContent = selesai.isEmpty
                      ? _buildEmptyState('Belum ada pengaduan selesai atau diarsipkan.')
                      : Column(
                          children: selesai
                              .map((p) => _buildPengaduanCard(
                                  p, (item) => _bukaDetail(item), 'Detail'))
                              .toList(),
                        );
                  break;
              }

              content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClusterBar(
                    countSemua: semua.length,
                    countMenungguPetugas: menungguPetugas.length,
                    countInvestigasi: berjalan.length,
                    countRevisi: revisi.length,
                    countTindakLanjut: tindakLanjut.length,
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
                          if (widget.user.role == UserRole.kspi)
                            _buildSwitcherKspiDanTpdpk(),
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
                    'TPDPK',
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
                child: NotificationBell(role: UserRole.tpdpk, user: widget.user),
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
            'Tugas Investigasi TPDPK',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 20.0 : 23.0,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jalankan & laporkan hasil investigasi',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: isSmallScreen ? 12.0 : 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitcherKspiDanTpdpk() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _accent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.maybePop(context);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_turned_in_rounded,
                        color: _accent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Tugas KSPI',
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Tugas TPDPK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
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

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_rounded,
              size: 40,
              color: AppColors.textSecondary(context).withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterBar({
    required int countSemua,
    required int countMenungguPetugas,
    required int countInvestigasi,
    required int countRevisi,
    required int countTindakLanjut,
    required int countSelesai,
  }) {
    final items = [
      (filter: _TpdpkClusterFilter.semua, label: 'Semua', count: countSemua, icon: Icons.grid_view_rounded),
      (filter: _TpdpkClusterFilter.menungguPetugas, label: 'Tugaskan Petugas', count: countMenungguPetugas, icon: Icons.person_add_alt_1_rounded),
      (filter: _TpdpkClusterFilter.investigasi, label: 'Investigasi Berjalan', count: countInvestigasi, icon: Icons.search_rounded),
      (filter: _TpdpkClusterFilter.revisi, label: 'Perlu Revisi', count: countRevisi, icon: Icons.edit_note_rounded),
      (filter: _TpdpkClusterFilter.tindakLanjut, label: 'Tindak Lanjut', count: countTindakLanjut, icon: Icons.build_circle_rounded),
      (filter: _TpdpkClusterFilter.selesai, label: 'Selesai & Arsip', count: countSelesai, icon: Icons.task_alt_rounded),
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
            Text('Petugas: ${p.petugasInvestigasi ?? '-'}',
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onAksi(p),
                icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
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
        ),
      ),
    );
  }
}