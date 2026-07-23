import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';

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
  static const Color labelDark = Color(0xFF1B2733);
  static const Color hintGrey = Color(0xFF9AA5B1);

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
      backgroundColor: Colors.white,
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
                      style: const TextStyle(fontSize: 13.5, color: labelDark)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context),
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    _buildInfoCard(p),
                    const SizedBox(height: 16),
                    if (p.fotoBukti.isNotEmpty) ...[
                      _buildSectionTitle('Foto Bukti'),
                      const SizedBox(height: 8),
                      _buildFotoBukti(p),
                      const SizedBox(height: 16),
                    ],
                    _buildSectionTitle('Riwayat Status'),
                    const SizedBox(height: 8),
                    _buildTimeline(p),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navyDark, navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Detail Pengaduan',
            style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Pengaduan p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.nomorPengaduan,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hintGrey)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(p.status.icon, size: 12, color: p.status.color),
                    const SizedBox(width: 5),
                    Text(p.status.label,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: p.status.color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(p.judul,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: labelDark)),
          const SizedBox(height: 6),
          Text(p.kategori,
              style: const TextStyle(
                  fontSize: 12.5, color: accent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(p.deskripsi,
              style:
                  const TextStyle(fontSize: 13, height: 1.5, color: labelDark)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 15, color: hintGrey),
              const SizedBox(width: 6),
              Text(p.anonim ? 'Anonim' : p.namaPegawai,
                  style: const TextStyle(fontSize: 12, color: hintGrey)),
              const SizedBox(width: 14),
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: hintGrey),
              const SizedBox(width: 6),
              Text(formatTanggalIndonesia(p.tanggalPengaduan),
                  style: const TextStyle(fontSize: 12, color: hintGrey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFotoBukti(Pengaduan p) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: p.fotoBukti.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              p.fotoBukti[i],
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 90,
                height: 90,
                color: Colors.white,
                child: const Icon(Icons.broken_image_outlined, color: hintGrey),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.bold, color: labelDark));
  }

  Widget _buildTimeline(Pengaduan p) {
    if (p.riwayatStatus.isEmpty) {
      return const Text('Belum ada riwayat.',
          style: TextStyle(fontSize: 12.5, color: hintGrey));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (int i = 0; i < p.riwayatStatus.length; i++)
            _buildTimelineItem(p.riwayatStatus[i],
                isLast: i == p.riwayatStatus.length - 1),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(StatusHistoryEntry h, {required bool isLast}) {
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
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: labelDark)),
                  const SizedBox(height: 2),
                  Text(
                      '${h.oleh}${h.role != null ? ' (${h.role!.label})' : ''} · ${formatTanggalJam(h.tanggal)}',
                      style: const TextStyle(fontSize: 11, color: hintGrey)),
                  if (h.keterangan != null && h.keterangan!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(h.keterangan!,
                        style: const TextStyle(
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
        color: Colors.white,
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
