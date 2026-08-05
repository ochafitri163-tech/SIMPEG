import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';

/// Halaman detail satu pengaduan. Panel aksi di bagian bawah BERUBAH
/// otomatis tergantung role user & status pengaduan saat ini — jadi satu
/// screen ini dipakai oleh semua role (Kadiv, KSPI, TPDPK, Direktur, SDM).
class PengaduanDetailScreen extends StatefulWidget {
  final AppUser user;
  final int pengaduanId;
  const PengaduanDetailScreen({
    super.key,
    required this.user,
    required this.pengaduanId,
  });

  @override
  State<PengaduanDetailScreen> createState() => _PengaduanDetailScreenState();
}

class _PengaduanDetailScreenState extends State<PengaduanDetailScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color navyDark = Color(0xFF0A2257);
  static const Color accent = Color(0xFF2E86AB);
  static const Color red = Color(0xFFE74C3C);
  static const Color green = Color(0xFF27AE60);
  Color get labelDark => AppColors.textPrimary(context);
  Color get hintGrey => AppColors.textSecondary(context);

  late Future<Pengaduan?> _future;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _future = PengaduanService.detailLengkap(widget.pengaduanId);
  }

  void _reload() {
    setState(() {
      _future = PengaduanService.detailLengkap(widget.pengaduanId);
    });
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _jalankan(Future<void> Function() aksi,
      {String sukses = 'Berhasil diproses.'}) async {
    setState(() => _isProcessing = true);
    try {
      await aksi();
      if (!mounted) return;
      _showSnack(sukses, green);
      _reload();
    } catch (e) {
      _showSnack('Gagal: $e', red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Dialog input catatan (opsional/wajib) sebelum konfirmasi aksi.
  Future<String?> _dialogCatatan({
    required String judul,
    String hint = 'Tambahkan catatan (opsional)...',
    bool wajib = false,
    String labelTombol = 'Konfirmasi',
    Color warnaTombol = accent,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(judul,
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: warnaTombol),
              onPressed: () {
                final text = controller.text.trim();
                if (wajib && text.isEmpty) return;
                Navigator.pop(context, text.isEmpty ? null : text);
              },
              child: Text(labelTombol,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Dialog form dua field (dipakai untuk hasil investigasi + rekomendasi).
  Future<Map<String, String>?> _dialogDuaField({
    required String judul,
    required String label1,
    required String label2,
  }) async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(judul,
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label1,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: c1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(label2,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: c2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              onPressed: () {
                if (c1.text.trim().isEmpty || c2.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'field1': c1.text.trim(),
                  'field2': c2.text.trim(),
                });
              },
              child: const Text('Kirim', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<Eksekutor?> _dialogPilihEksekutor(
      {required String judul,
      List<Eksekutor> opsi = const [Eksekutor.kadiv, Eksekutor.tpdpk]}) async {
    return showModalBottomSheet<Eksekutor>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E4E9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(judul,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: navy)),
              ),
              for (final e in opsi)
                ListTile(
                  leading: const Icon(Icons.person_pin_circle_outlined,
                      color: accent),
                  title: Text(e.label,
                      style: TextStyle(fontSize: 13.5, color: labelDark)),
                  onTap: () => Navigator.pop(context, e),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10151C) : const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context, isSmallScreen),
          Expanded(
            child: FutureBuilder<Pengaduan?>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final p = snapshot.data;
                if (p == null) {
                  return const Center(
                      child: Text('Pengaduan tidak ditemukan.'));
                }
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    isSmallScreen ? 16.0 : 20.0,
                    isSmallScreen ? 16.0 : 20.0,
                    isSmallScreen ? 16.0 : 20.0,
                    24,
                  ),
                  children: [
                    _buildInfoCard(p, isSmallScreen),
                    const SizedBox(height: 18),
                    if (p.fotoBukti.isNotEmpty) ...[
                      _buildSectionTitle('Foto Bukti', isSmallScreen),
                      const SizedBox(height: 10),
                      _buildFotoBukti(p, isSmallScreen),
                      const SizedBox(height: 18),
                    ],
                    _buildSectionTitle('Riwayat Status', isSmallScreen),
                    const SizedBox(height: 10),
                    _buildTimeline(p, isSmallScreen),
                    const SizedBox(height: 20),
                    _buildActionPanel(p),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16.0 : 20.0,
        MediaQuery.of(context).padding.top + (isSmallScreen ? 10.0 : 14.0),
        isSmallScreen ? 16.0 : 20.0,
        isSmallScreen ? 18.0 : 22.0,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [navyDark, navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: isSmallScreen ? 32.0 : 36.0,
              height: isSmallScreen ? 32.0 : 36.0,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: isSmallScreen ? 19.0 : 22.0),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12.0 : 14.0),
          Expanded(
            child: Text(
              'Detail Pengaduan',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 15.0 : 17.0,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Pengaduan p, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 14.0 : 18.0),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(p.nomorPengaduan,
                    style: TextStyle(
                        fontSize: isSmallScreen ? 11.0 : 12.0,
                        fontWeight: FontWeight.w700,
                        color: hintGrey,
                        letterSpacing: 0.3)),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 9.0 : 11.0,
                    vertical: isSmallScreen ? 5.0 : 6.0),
                decoration: BoxDecoration(
                  color: p.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.status.icon,
                        size: isSmallScreen ? 11.0 : 12.0,
                        color: p.status.color),
                    const SizedBox(width: 5),
                    Text(p.status.label,
                        style: TextStyle(
                            fontSize: isSmallScreen ? 9.5 : 10.5,
                            fontWeight: FontWeight.w700,
                            color: p.status.color)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          Text(p.judul,
              style: TextStyle(
                  fontSize: isSmallScreen ? 15.5 : 17.0,
                  fontWeight: FontWeight.bold,
                  color: labelDark,
                  height: 1.25)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(p.kategori,
                style: TextStyle(
                    fontSize: isSmallScreen ? 10.5 : 11.5,
                    color: accent,
                    fontWeight: FontWeight.w700)),
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 14.0),
          Container(height: 1, color: const Color(0xFFEFF2F6)),
          SizedBox(height: isSmallScreen ? 12.0 : 14.0),
          Text(p.deskripsi,
              style: TextStyle(
                  fontSize: isSmallScreen ? 12.5 : 13.5,
                  height: 1.5,
                  color: labelDark)),
          SizedBox(height: isSmallScreen ? 14.0 : 16.0),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: isSmallScreen ? 14.0 : 15.0, color: hintGrey),
                  const SizedBox(width: 6),
                  Text(p.anonim ? 'Anonim' : p.namaPegawai,
                      style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                          color: hintGrey,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: isSmallScreen ? 12.0 : 13.0, color: hintGrey),
                  const SizedBox(width: 6),
                  Text(formatTanggalIndonesia(p.tanggalPengaduan),
                      style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                          color: hintGrey,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              if (p.eksekutor != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_ind_outlined,
                      size: isSmallScreen ? 14.0 : 15.0, color: hintGrey),
                  const SizedBox(width: 6),
                  Text('Eksekutor Investigasi: ${p.eksekutor!.label}',
                      style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                          color: hintGrey,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              if (p.petugasInvestigasi != null &&
                  p.petugasInvestigasi!.trim().isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_outlined,
                      size: isSmallScreen ? 14.0 : 15.0, color: hintGrey),
                  const SizedBox(width: 6),
                  Text('Petugas: ${p.petugasInvestigasi}',
                      style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                          color: hintGrey,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              if (p.eksekutorTindakLanjut != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.engineering_outlined,
                      size: isSmallScreen ? 14.0 : 15.0, color: hintGrey),
                  const SizedBox(width: 6),
                  Text('Eksekutor Tindak Lanjut: ${p.eksekutorTindakLanjut!.label}',
                      style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                          color: hintGrey,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFotoBukti(Pengaduan p, bool isSmallScreen) {
    final size = isSmallScreen ? 78.0 : 92.0;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: p.fotoBukti.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              p.fotoBukti[i],
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: size,
                height: size,
                color: AppColors.card(context),
                child: Icon(Icons.broken_image_outlined, color: hintGrey),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String text, [bool isSmallScreen = false]) {
    return Text(text,
        style: TextStyle(
            fontSize: isSmallScreen ? 13.0 : 14.0,
            fontWeight: FontWeight.bold,
            color: labelDark));
  }

  Widget _buildTimeline(Pengaduan p, bool isSmallScreen) {
    if (p.riwayatStatus.isEmpty) {
      return Text('Belum ada riwayat.',
          style: TextStyle(fontSize: 12.5, color: hintGrey));
    }
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14.0 : 16.0),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < p.riwayatStatus.length; i++)
            _buildTimelineItem(p.riwayatStatus[i],
                isLast: i == p.riwayatStatus.length - 1,
                isSmallScreen: isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(StatusHistoryEntry h,
      {required bool isLast, required bool isSmallScreen}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: h.status.color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                    child: Container(width: 2, color: const Color(0xFFE0E4E9))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.aksi,
                      style: TextStyle(
                          fontSize: isSmallScreen ? 12.0 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: labelDark)),
                  const SizedBox(height: 2),
                  Text(
                      '${h.oleh}${h.role != null ? ' (${h.role!.label})' : ''} · ${formatTanggalJam(h.tanggal)}',
                      style: TextStyle(
                          fontSize: isSmallScreen ? 10.5 : 11.0,
                          color: hintGrey)),
                  if (h.keterangan != null && h.keterangan!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(h.keterangan!,
                        style: TextStyle(
                            fontSize: 12, color: labelDark, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PANEL AKSI — berubah sesuai role & status.
  // =========================================================
  Widget _buildActionPanel(Pengaduan p) {
    final role = widget.user.role;
    final oleh = widget.user.name;

    Widget? panel;

    if (role == UserRole.kadivKategori) {
      if (p.status == PengaduanStatus.menungguKadiv) {
        panel = _panelTerimaTolak(
          judul: 'Verifikasi Pengaduan',
          onTerima: () => _jalankan(
            () => PengaduanService.kadivAksi(
              pengaduanId: p.supabaseId!,
              oleh: oleh,
              keputusan: Keputusan.terima,
            ),
            sukses: 'Pengaduan diterima, diteruskan ke Dirut.',
          ),
          onTolak: () async {
            final catatan = await _dialogCatatan(
              judul: 'Alasan Menolak',
              wajib: true,
              labelTombol: 'Tolak & Arsipkan',
              warnaTombol: red,
            );
            if (catatan == null) return;
            await _jalankan(
              () => PengaduanService.kadivAksi(
                pengaduanId: p.supabaseId!,
                oleh: oleh,
                keputusan: Keputusan.tolak,
                catatan: catatan,
              ),
              sukses: 'Pengaduan ditolak & diarsipkan.',
            );
          },
        );
      } else if (p.status == PengaduanStatus.investigasiBerjalan &&
          p.eksekutor == Eksekutor.kadiv) {
        panel = _panelKirimHasilInvestigasi(p, oleh, UserRole.kadivKategori);
      } else if (p.status == PengaduanStatus.tindakLanjutBerjalan &&
          p.eksekutorTindakLanjut == Eksekutor.kadiv) {
        panel = _panelSelesaikanTindakLanjut(p, oleh, UserRole.kadivKategori);
      }
    } else if (role == UserRole.kspi) {
      if (p.status == PengaduanStatus.menungguPilihEksekutor) {
        panel = _panelPilihEksekutor(
          judul: 'Pilih Eksekutor Investigasi',
          onPilih: (e) async {
            final petugas = await _dialogCatatan(
              judul: 'Nama Petugas (opsional)',
              hint: 'Nama petugas investigasi...',
            );
            await _jalankan(
              () => PengaduanService.kspiPilihEksekutor(
                pengaduanId: p.supabaseId!,
                oleh: oleh,
                eksekutor: e,
                petugas: petugas,
              ),
              sukses: 'Eksekutor investigasi ditentukan: ${e.label}.',
            );
          },
        );
      } else if (p.status == PengaduanStatus.tindakLanjutBerjalan &&
          p.eksekutorTindakLanjut == Eksekutor.kspi) {
        panel = _panelSelesaikanTindakLanjut(p, oleh, UserRole.kspi);
      }
    } else if (role == UserRole.tpdpk) {
      if (p.status == PengaduanStatus.investigasiBerjalan &&
          p.eksekutor == Eksekutor.tpdpk) {
        panel = _panelKirimHasilInvestigasi(p, oleh, UserRole.tpdpk);
      } else if (p.status == PengaduanStatus.tindakLanjutBerjalan &&
          p.eksekutorTindakLanjut == Eksekutor.tpdpk) {
        panel = _panelSelesaikanTindakLanjut(p, oleh, UserRole.tpdpk);
      }
    } else if (role == UserRole.direktur) {
      if (p.status == PengaduanStatus.menungguDirutTahap1) {
        panel = _panelTerimaTolak(
          judul: 'Persetujuan Tahap 1 — Layak Diinvestigasi?',
          onTerima: () => _jalankan(
            () => PengaduanService.dirutTahap1Aksi(
              pengaduanId: p.supabaseId!,
              oleh: oleh,
              keputusan: Keputusan.terima,
            ),
            sukses: 'Disetujui, dikembalikan ke KSPI untuk pilih eksekutor.',
          ),
          onTolak: () async {
            final catatan = await _dialogCatatan(
              judul: 'Alasan Menolak',
              wajib: true,
              labelTombol: 'Tolak & Arsipkan',
              warnaTombol: red,
            );
            if (catatan == null) return;
            await _jalankan(
              () => PengaduanService.dirutTahap1Aksi(
                pengaduanId: p.supabaseId!,
                oleh: oleh,
                keputusan: Keputusan.tolak,
                catatan: catatan,
              ),
              sukses: 'Pengaduan ditolak & diarsipkan.',
            );
          },
        );
      } else if (p.status == PengaduanStatus.menungguDirutTahap2) {
        panel = _panelTerimaTolak(
          judul: 'Persetujuan Tahap 2 — Hasil Investigasi Diterima?',
          onTerima: () => _jalankan(
            () => PengaduanService.direksiTahap2Aksi(
              pengaduanId: p.supabaseId!,
              oleh: oleh,
              keputusan: Keputusan.terima,
            ),
            sukses:
                'Hasil investigasi diterima, silakan pilih eksekutor tindak lanjut.',
          ),
          onTolak: () async {
            final catatan = await _dialogCatatan(
              judul: 'Alasan Menolak',
              wajib: true,
              labelTombol: 'Tolak & Arsipkan',
              warnaTombol: red,
            );
            if (catatan == null) return;
            await _jalankan(
              () => PengaduanService.direksiTahap2Aksi(
                pengaduanId: p.supabaseId!,
                oleh: oleh,
                keputusan: Keputusan.tolak,
                catatan: catatan,
              ),
              sukses: 'Hasil investigasi ditolak, pengaduan diarsipkan.',
            );
          },
        );
      } else if (p.status ==
          PengaduanStatus.menungguPilihEksekutorTindakLanjut) {
        panel = _panelPilihEksekutor(
          judul: 'Pilih Eksekutor Tindak Lanjut',
          opsi: const [Eksekutor.kspi, Eksekutor.tpdpk],
          onPilih: (e) => _jalankan(
            () => PengaduanService.pilihEksekutorTindakLanjut(
              pengaduanId: p.supabaseId!,
              oleh: oleh,
              eksekutor: e,
            ),
            sukses: 'Eksekutor tindak lanjut ditentukan: ${e.label}.',
          ),
        );
      }
    } else if (role == UserRole.sdm) {
      if (p.status == PengaduanStatus.menungguSdm) {
        panel = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Tindak Lanjut SDM'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final catatan = await _dialogCatatan(
                          judul: 'Catatan Penyelesaian (opsional)',
                        );
                        await _jalankan(
                          () => PengaduanService.sdmSelesaikan(
                            pengaduanId: p.supabaseId!,
                            oleh: oleh,
                            catatan: catatan,
                          ),
                          sukses: 'Pengaduan dinyatakan selesai.',
                        );
                      },
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Tandai Selesai'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        );
      }
    }

    if (panel == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: panel,
    );
  }

  Widget _panelTerimaTolak({
    required String judul,
    required VoidCallback onTerima,
    required VoidCallback onTolak,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(judul),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : onTolak,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Tolak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: red,
                    side: const BorderSide(color: red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : onTerima,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Terima'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panelPilihEksekutor({
    required String judul,
    required void Function(Eksekutor) onPilih,
    List<Eksekutor> opsi = const [Eksekutor.kadiv, Eksekutor.tpdpk],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(judul),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () async {
                    final e = await _dialogPilihEksekutor(judul: judul, opsi: opsi);
                    if (e != null) onPilih(e);
                  },
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: const Text('Pilih Eksekutor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelKirimHasilInvestigasi(Pengaduan p, String oleh, UserRole role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Kirim Hasil Investigasi'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () async {
                    final hasil = await _dialogDuaField(
                      judul: 'Hasil Investigasi',
                      label1: 'Hasil Investigasi',
                      label2: 'Surat Rekomendasi',
                    );
                    if (hasil == null) return;
                    await _jalankan(
                      () => PengaduanService.kirimHasilInvestigasi(
                        pengaduanId: p.supabaseId!,
                        oleh: oleh,
                        role: role,
                        hasil: hasil['field1']!,
                        rekomendasi: hasil['field2']!,
                      ),
                      sukses: 'Hasil investigasi dikirim ke Direksi.',
                    );
                  },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Kirim Hasil Investigasi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelSelesaikanTindakLanjut(Pengaduan p, String oleh, UserRole role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Tindak Lanjut'),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () async {
                    final catatan = await _dialogCatatan(
                      judul: 'Catatan Tindak Lanjut',
                      hint: 'Jelaskan tindak lanjut yang sudah dijalankan...',
                    );
                    await _jalankan(
                      () => PengaduanService.selesaikanTindakLanjut(
                        pengaduanId: p.supabaseId!,
                        oleh: oleh,
                        role: role,
                        catatan: catatan,
                      ),
                      sukses: 'Tindak lanjut selesai, diteruskan ke SDM.',
                    );
                  },
            icon: const Icon(Icons.flag_rounded, size: 18),
            label: const Text('Tandai Tindak Lanjut Selesai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}