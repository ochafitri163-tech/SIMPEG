import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/sk_sanksi_service.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../widgets/media_lampiran_picker.dart';
import '../../widgets/pegawai_picker_sheet.dart';
import '../../theme/app_colors.dart';
import '../sdm/terbitkan_sk_screen.dart';

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
  static const Color accent = Color(0xFF2E86AB);
  static const Color red = Color(0xFFE74C3C);
  static const Color green = Color(0xFF27AE60);
  Color get labelDark => AppColors.textPrimary(context);
  Color get hintGrey => AppColors.textSecondary(context);

  late Future<Pengaduan?> _future;
  bool _isProcessing = false;

  // Dipakai panel investigasi SPI / TPDPK.
  String _kesimpulanInvestigasi = 'terbukti';
  final MediaLampiranController _investigasiMedia = MediaLampiranController();
  final TextEditingController _hasilController = TextEditingController();
  final TextEditingController _rekomendasiController = TextEditingController();

  // Dipakai panel putusan sanksi SDM.
  final TextEditingController _nomorSuratController = TextEditingController();
  final TextEditingController _catatanSdmController = TextEditingController();
  String _selectedJenisSanksi = 'Teguran Tertulis';
  final MediaLampiranController _putusanMedia = MediaLampiranController();

  void _isiTemplateRekomendasi(Pengaduan p) {
    final nomor = p.nomorPengaduan;
    final terlapor = p.pihakTerlapor ?? 'Pihak Terlapor';
    final kategori = p.kategori;
    if (_kesimpulanInvestigasi == 'terbukti') {
      _rekomendasiController.text =
          'SURAT REKOMENDASI HASIL INVESTIGASI\n'
          'Nomor: REK/SPI/${DateTime.now().year}/${nomor.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0')}\n\n'
          'Berdasarkan hasil investigasi atas $nomor ($kategori) mengenai Sdr/i $terlapor, '
          'Tim Pemeriksa menyimpulkan bahwa dugaan pelanggaran TERBUKTI secara sah dan meyakinkan.\n\n'
          'REKOMENDASI:\n'
          '1. Menjatuhkan sanksi disiplin kepada Sdr/i $terlapor sesuai peraturan perusahaan.\n'
          '2. Meneruskan berkas perkara ke Bagian SDM untuk penetapan Surat Putusan Sanksi.\n'
          '3. Melakukan evaluasi berkala di unit kerja terkait.';
    } else {
      _rekomendasiController.text =
          'SURAT REKOMENDASI HASIL INVESTIGASI\n'
          'Nomor: REK/SPI/${DateTime.now().year}/${nomor.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0')}\n\n'
          'Berdasarkan hasil investigasi atas $nomor ($kategori) mengenai Sdr/i $terlapor, '
          'Tim Pemeriksa menyimpulkan bahwa dugaan pelanggaran TIDAK TERBUKTI dan tidak ditemukan bukti yang cukup.\n\n'
          'REKOMENDASI:\n'
          '1. Menghentikan proses pemeriksaan dan mengarsipkan pengaduan ini.\n'
          '2. Merehabilitasi dan memulihkan nama baik Sdr/i $terlapor.\n'
          '3. Menjaga kerahasiaan proses pengaduan.';
    }
  }

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

  @override
  void dispose() {
    _hasilController.dispose();
    _rekomendasiController.dispose();
    _nomorSuratController.dispose();
    _catatanSdmController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF10151C)
          : const Color(0xFFF3F6F9),
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
                    if (p.adaDataPelaku) ...[
                      _buildPelakuCard(p),
                      const SizedBox(height: 16),
                    ],
                    if (p.fotoBukti.isNotEmpty) ...[
                      _buildSectionTitle('Foto Bukti'),
                      const SizedBox(height: 8),
                      _buildFotoBukti(p),
                      const SizedBox(height: 16),
                    ],
                    _buildLampiranLain(p),
                    _buildHasilInvestigasi(p),
                    _buildSuratPutusanSdm(p),
                    _buildSectionTitle('Riwayat Status'),
                    const SizedBox(height: 8),
                    _buildTimeline(p),
                    const SizedBox(height: 16),
                    _buildKartuSk(p),
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
        20,
      ),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Pengaduan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Informasi dan perkembangan laporan',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Pengaduan p) {
    final String namaPelapor = p.anonim ? 'Anonim' : p.namaPegawai;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  p.status.color,
                  p.status.color.withValues(alpha: 0.42),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p.nomorPengaduan,
                        style: TextStyle(
                          color: hintGrey,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: p.status.color.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            p.status.icon,
                            size: 14,
                            color: p.status.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.status.label,
                            style: TextStyle(
                              color: p.status.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  p.judul,
                  style: TextStyle(
                    color: labelDark,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    p.kategori,
                    style: const TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Divider(height: 1, color: AppColors.divider(context)),
                const SizedBox(height: 17),
                Text(
                  p.deskripsi,
                  style: TextStyle(
                    color: labelDark,
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 18),

                // Layout responsif: nama dan tanggal tidak dipaksa berada
                // dalam satu Row, sehingga tidak ada RIGHT OVERFLOW.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool compact = constraints.maxWidth < 520;
                    final double itemWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _buildInfoMeta(
                            icon: Icons.person_outline_rounded,
                            label: 'Pelapor',
                            value: namaPelapor,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _buildInfoMeta(
                            icon: Icons.calendar_today_outlined,
                            label: 'Tanggal pengaduan',
                            value: formatTanggalIndonesia(
                              p.tanggalPengaduan,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (p.eksekutor != null) ...[
                  const SizedBox(height: 10),
                  _buildInfoMeta(
                    icon: Icons.assignment_ind_outlined,
                    label: 'Eksekutor investigasi',
                    value: p.eksekutor == Eksekutor.kadiv &&
                            p.eksekutorDivisiKadiv != null
                        ? p.eksekutorDivisiKadiv!.label
                        : p.eksekutor!.label,
                  ),
                ],
                if (p.petugasInvestigasi != null &&
                    p.petugasInvestigasi!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildInfoMeta(
                    icon: Icons.groups_outlined,
                    label: 'Petugas investigasi',
                    value: p.petugasInvestigasi!.trim(),
                  ),
                ],
                if (p.eksekutorTindakLanjut != null) ...[
                  const SizedBox(height: 10),
                  _buildInfoMeta(
                    icon: Icons.engineering_outlined,
                    label: 'Eksekutor tindak lanjut',
                    value: p.eksekutorTindakLanjut!.label,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoMeta({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(context),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: hintGrey,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  softWrap: true,
                  style: TextStyle(
                    color: labelDark,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
                color: AppColors.card(context),
                child: Icon(Icons.broken_image_outlined, color: hintGrey),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLampiranLain(Pengaduan p) {
    final ada = p.videoBukti.isNotEmpty ||
        p.voiceNote.isNotEmpty ||
        p.dokumenPendukung.isNotEmpty;
    if (!ada) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Lampiran Lain'),
        const SizedBox(height: 8),
        if (p.videoBukti.isNotEmpty)
          _buildLampiranLinks('Video', p.videoBukti, Icons.videocam_rounded),
        if (p.voiceNote.isNotEmpty)
          _buildLampiranLinks('Voice Note', p.voiceNote, Icons.mic_rounded),
        if (p.dokumenPendukung.isNotEmpty)
          _buildLampiranLinks(
              'Dokumen', p.dokumenPendukung, Icons.attach_file_rounded),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHasilInvestigasi(Pengaduan p) {
    final punyaHasil =
        (p.hasilInvestigasi != null && p.hasilInvestigasi!.isNotEmpty) ||
            (p.suratRekomendasi != null && p.suratRekomendasi!.isNotEmpty);
    final punyaMedia = p.investigasiFoto.isNotEmpty ||
        p.investigasiVideo.isNotEmpty ||
        p.investigasiVoice.isNotEmpty ||
        p.investigasiDokumen.isNotEmpty;
    if (!punyaHasil && !punyaMedia && !p.isTerbukti && !p.isTidakTerbukti) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Hasil Investigasi'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.isTerbukti || p.isTidakTerbukti) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.isTerbukti
                        ? red.withOpacity(0.08)
                        : const Color(0xFF0284C7).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.isTerbukti
                          ? red.withOpacity(0.3)
                          : const Color(0xFF0284C7).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: p.isTerbukti
                              ? red.withOpacity(0.12)
                              : const Color(0xFF0284C7).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p.isTerbukti
                              ? Icons.gavel_rounded
                              : Icons.verified_user_rounded,
                          size: 20,
                          color: p.isTerbukti ? red : const Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.isTerbukti
                                  ? 'KESIMPULAN: TERBUKTI'
                                  : 'KESIMPULAN: TIDAK TERBUKTI',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: p.isTerbukti
                                    ? red
                                    : const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.isTerbukti
                                  ? 'Dugaan pelanggaran terbukti sah berdasarkan hasil investigasi & diteruskan ke SDM.'
                                  : 'Tidak ditemukan bukti yang cukup atas dugaan pelanggaran.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: hintGrey,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (p.hasilInvestigasi != null &&
                  p.hasilInvestigasi!.isNotEmpty) ...[
                Text('Temuan / Fakta Lapangan',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: labelDark)),
                const SizedBox(height: 4),
                Text(p.hasilInvestigasi!,
                    style: TextStyle(
                        fontSize: 12.5, color: labelDark, height: 1.4)),
                const SizedBox(height: 10),
              ],
              if (p.suratRekomendasi != null &&
                  p.suratRekomendasi!.isNotEmpty) ...[
                Text('Surat Rekomendasi',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: labelDark)),
                const SizedBox(height: 4),
                Text(p.suratRekomendasi!,
                    style: TextStyle(
                        fontSize: 12.5, color: labelDark, height: 1.4)),
                const SizedBox(height: 10),
              ],
              if (p.investigasiFoto.isNotEmpty)
                _buildLampiranLinks(
                    'Foto', p.investigasiFoto, Icons.image_rounded),
              if (p.investigasiVideo.isNotEmpty)
                _buildLampiranLinks(
                    'Video', p.investigasiVideo, Icons.videocam_rounded),
              if (p.investigasiVoice.isNotEmpty)
                _buildLampiranLinks(
                    'Voice Note', p.investigasiVoice, Icons.mic_rounded),
              if (p.investigasiDokumen.isNotEmpty)
                _buildLampiranLinks(
                    'Dokumen', p.investigasiDokumen, Icons.attach_file_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuratPutusanSdm(Pengaduan p) {
    if (!p.adaPutusanSdm) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Surat Putusan Sanksi SDM'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_turned_in_rounded,
                            size: 16, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text(
                          'Keputusan Resmi SDM',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (p.nomorSuratPutusan != null &&
                  p.nomorSuratPutusan!.isNotEmpty) ...[
                Text('Nomor Surat Putusan',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hintGrey)),
                const SizedBox(height: 3),
                Text(
                  p.nomorSuratPutusan!,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: labelDark),
                ),
                const SizedBox(height: 10),
              ],
              if (p.jenisSanksi != null && p.jenisSanksi!.isNotEmpty) ...[
                Text('Jenis Sanksi yang Dikenakan',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hintGrey)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: red.withOpacity(0.2)),
                  ),
                  child: Text(
                    p.jenisSanksi!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: red,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (p.tanggalSuratPutusan != null) ...[
                Text('Tanggal Penetapan',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hintGrey)),
                const SizedBox(height: 3),
                Text(
                  formatTanggalJam(p.tanggalSuratPutusan!),
                  style: TextStyle(fontSize: 12.5, color: labelDark),
                ),
                const SizedBox(height: 10),
              ],
              if (p.catatanSdm != null && p.catatanSdm!.isNotEmpty) ...[
                Text('Catatan / Diktum SDM',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hintGrey)),
                const SizedBox(height: 3),
                Text(
                  p.catatanSdm!,
                  style: TextStyle(fontSize: 12.5, color: labelDark, height: 1.4),
                ),
                const SizedBox(height: 12),
              ],
              if (p.fileSuratPutusan != null &&
                  p.fileSuratPutusan!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _bukaUrl(p.fileSuratPutusan!),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Unduh / Buka Dokumen Putusan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLampiranLinks(String label, List<String> urls, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < urls.length; i++)
                InkWell(
                  onTap: () => _bukaUrl(urls[i]),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: accent),
                        const SizedBox(width: 6),
                        Text('$label ${i + 1}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: accent,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _bukaUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Tidak dapat membuka lampiran.', red);
    }
  }

  /// Kartu info pelaku/pihak yang diadukan (Nama, NIK, Jabatan) — selalu
  /// ditampilkan mencolok di bagian atas, terlihat oleh semua role.
  Widget _buildPelakuCard(Pengaduan p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: red.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.report_gmailerrorred_rounded,
                  size: 18,
                  color: red,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pelaku / Pihak yang Diadukan',
                  softWrap: true,
                  style: TextStyle(
                    color: red,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (p.pihakTerlapor != null && p.pihakTerlapor!.trim().isNotEmpty)
            _buildPelakuRow('Nama', p.pihakTerlapor!.trim()),
          if (p.nikPelaku != null && p.nikPelaku!.trim().isNotEmpty)
            _buildPelakuRow('NIK', p.nikPelaku!.trim()),
          if (p.jabatanPelaku != null && p.jabatanPelaku!.trim().isNotEmpty)
            _buildPelakuRow('Jabatan', p.jabatanPelaku!.trim()),
        ],
      ),
    );
  }

  Widget _buildPelakuRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                color: hintGrey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              softWrap: true,
              style: TextStyle(
                color: labelDark,
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.bold, color: labelDark));
  }

  /// SK Sanksi yang terbit dari pengaduan ini (kalau ada). Ditampilkan
  /// untuk semua role agar SDM bisa memverifikasi hasil penerbitannya.
  Widget _buildKartuSk(Pengaduan p) {
    if (p.supabaseId == null) return const SizedBox.shrink();
    return FutureBuilder<List<SkSanksi>>(
      future: SkSanksiService.untukPengaduan(p.supabaseId!),
      builder: (context, snap) {
        final list = snap.data ?? const <SkSanksi>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('SK Sanksi Terbit'),
            const SizedBox(height: 8),
            ...list.map((sk) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: green.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gavel_rounded, size: 16, color: green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(sk.nomorSk,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: labelDark)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${sk.jenisSanksi} \u00b7 ${sk.tingkat}'
                        '${sk.perubahanJabatan != null ? ' \u00b7 ${sk.perubahanJabatan}' : ''}',
                        style: TextStyle(fontSize: 12, color: hintGrey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sk.totalBerkas} berkas'
                        '${sk.dokumenLengkap ? ' \u00b7 dokumen wajib lengkap' : ' \u00b7 dokumen wajib BELUM lengkap'}',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: sk.dokumenLengkap ? green : red,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildTimeline(Pengaduan p) {
    if (p.riwayatStatus.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Text(
          'Belum ada riwayat.',
          style: TextStyle(fontSize: 12.5, color: hintGrey),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < p.riwayatStatus.length; i++)
            _buildTimelineItem(
              p.riwayatStatus[i],
              isLast: i == p.riwayatStatus.length - 1,
              pelakuLabel: p.adaDataPelaku ? p.infoPelakuLabel : null,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    StatusHistoryEntry h, {
    required bool isLast,
    String? pelakuLabel,
  }) {
    return Stack(
      children: [
        if (!isLast)
          Positioned(
            left: 8,
            top: 18,
            bottom: 0,
            child: Container(
              width: 2,
              color: AppColors.divider(context),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 18,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: h.status.color.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: h.status.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.aksi,
                      softWrap: true,
                      style: TextStyle(
                        color: labelDark,
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: hintGrey,
                        ),
                        Text(
                          '${h.oleh}${h.role != null ? ' (${h.role!.label})' : ''}',
                          softWrap: true,
                          style: TextStyle(
                            color: hintGrey,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(color: hintGrey, fontSize: 11),
                        ),
                        Text(
                          formatTanggalJam(h.tanggal),
                          softWrap: true,
                          style: TextStyle(
                            color: hintGrey,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    if (pelakuLabel != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          pelakuLabel,
                          softWrap: true,
                          style: const TextStyle(
                            color: red,
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (h.keterangan != null &&
                        h.keterangan!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        h.keterangan!.trim(),
                        softWrap: true,
                        style: TextStyle(
                          color: labelDark,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
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
        panel = _panelVerifikasiKadiv(p, oleh);
      } else if (p.status == PengaduanStatus.investigasiBerjalan) {
        panel = _panelKirimHasilInvestigasi(p, oleh, UserRole.kadivKategori);
      } else if (p.status == PengaduanStatus.tindakLanjutBerjalan &&
          p.eksekutorTindakLanjut == Eksekutor.kadiv) {
        panel = _panelSelesaikanTindakLanjut(p, oleh, UserRole.kadivKategori);
      }
    } else if (role == UserRole.kspi) {
      if (p.status == PengaduanStatus.reviewKspi) {
        panel = _panelTeruskanKeDirut(p, oleh);
      } else if (p.status == PengaduanStatus.menungguPilihEksekutor) {
        panel = _panelKspiPilihEksekutor(p, oleh);
      } else if (p.status == PengaduanStatus.investigasiBerjalan &&
          (widget.user.nik == '1711161' ||
              widget.user.name.toLowerCase().contains('dodi'))) {
        panel = _panelKirimHasilInvestigasi(p, oleh, UserRole.tpdpk);
      } else if (p.status == PengaduanStatus.tindakLanjutBerjalan &&
          p.eksekutorTindakLanjut == Eksekutor.kspi) {
        panel = _panelSelesaikanTindakLanjut(p, oleh, UserRole.kspi);
      }
    } else if (role == UserRole.tpdpk) {
      if (p.status == PengaduanStatus.menungguInvestigasi ||
          p.status == PengaduanStatus.investigasiBerjalan) {
        panel = _panelKirimHasilInvestigasi(p, oleh, UserRole.tpdpk);
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
            sukses: 'Disetujui, diteruskan ke KSPI untuk penunjukan eksekutor.',
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
        panel = _panelDirutTahap2(p, oleh);
      }
    } else if (role == UserRole.sdm) {
      if (p.status == PengaduanStatus.menungguSdm) {
        panel = _panelSdmPutusanSanksi(p, oleh);
      }
    }

    // Fail-safe untuk eksekutor resmi investigasi (Nurkhuliyah, Ghani Rashid, Dodi Sudrajat)
    if (panel == null &&
        p.status == PengaduanStatus.investigasiBerjalan &&
        (widget.user.nik == '1711161' ||
            widget.user.nik == '1711251' ||
            widget.user.nik == '1711571' ||
            p.eksekutorPegawaiId == widget.user.id)) {
      final r = widget.user.nik == '1711161'
          ? UserRole.tpdpk
          : UserRole.kadivKategori;
      panel = _panelKirimHasilInvestigasi(p, oleh, r);
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

  /// Buka halaman Terbitkan SK Sanksi dengan data terlapor sudah terisi
  /// otomatis. [SkSanksiService.terbitkan] akan menandai pengaduan ini
  /// selesai, jadi setelah kembali cukup reload detail.
  Future<void> _bukaTerbitkanSk(Pengaduan p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TerbitkanSkScreen(
          user: widget.user,
          pengaduan: p,
          pengaduanId: p.supabaseId,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
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
                    final e =
                        await _dialogPilihEksekutor(judul: judul, opsi: opsi);
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

  Widget _panelDirutTahap2(Pengaduan p, String oleh) {
    final isTerbukti = p.isTerbukti;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Persetujuan Direktur Utama (Tahap 2)'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isTerbukti ? red : const Color(0xFF0284C7)).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isTerbukti ? red : const Color(0xFF0284C7)).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isTerbukti ? Icons.gavel_rounded : Icons.verified_user_rounded,
                color: isTerbukti ? red : const Color(0xFF0284C7),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isTerbukti
                      ? 'Hasil Investigasi: TERBUKTI.\nBila disetujui, pengaduan akan diteruskan ke Bagian SDM untuk pembuatan Surat Putusan Sanksi resmi.'
                      : 'Hasil Investigasi: TIDAK TERBUKTI.\nBila disetujui, pengaduan akan langsung diarsipkan dan nama baik terlapor dipulihkan.',
                  style: TextStyle(fontSize: 12, color: labelDark, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          final catatan = await _dialogCatatan(
                            judul: 'Catatan Peninjauan Kembali (Tinjau Ulang)',
                            wajib: true,
                            labelTombol: 'Kirim ke KSPI',
                            hint:
                                'Jelaskan poin yang perlu diinvestigasi ulang oleh KSPI/Eksekutor...',
                          );
                          if (catatan == null) return;
                          await _jalankan(
                            () => PengaduanService.direksiTahap2PeninjauanKembali(
                              pengaduanId: p.supabaseId!,
                              oleh: oleh,
                              catatan: catatan,
                            ),
                            sukses:
                                'Dikembalikan ke KSPI untuk investigasi ulang.',
                          );
                        },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Tinjau Ulang'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () => _jalankan(
                            () => PengaduanService.direksiTahap2Aksi(
                              pengaduanId: p.supabaseId!,
                              oleh: oleh,
                              keputusan: Keputusan.terima,
                              kesimpulanInvestigasi: p.kesimpulanInvestigasi,
                            ),
                            sukses: isTerbukti
                                ? 'Hasil diterima & diteruskan ke SDM.'
                                : 'Hasil diterima & pengaduan diarsipkan.',
                          ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Terima Hasil'),
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

  Widget _panelSdmPutusanSanksi(Pengaduan p, String oleh) {
    const listJenisSanksi = [
      'Teguran Lisan',
      'Teguran Tertulis',
      'Penundaan Kenaikan Gaji Berkala',
      'Penurunan Pangkat / Golongan',
      'Pemotongan Gaji',
      'Pembebasan Dari Jabatan',
      'Pemberhentian Dengan Hormat',
      'Pemberhentian Tidak Dengan Hormat (PHK)',
      'Sanksi Disiplin Lainnya',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Penerbitan Surat Putusan Sanksi SDM'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: red.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: red.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gavel_rounded, size: 18, color: red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengaduan ini telah terbukti bersalah berdasarkan investigasi dan disetujui Direktur Utama. Bagian SDM berwenang menetapkan Surat Putusan Sanksi resmi.',
                  style:
                      TextStyle(fontSize: 11.5, color: labelDark, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Nomor Surat Putusan Sanksi *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
        const SizedBox(height: 6),
        TextField(
          controller: _nomorSuratController,
          decoration: InputDecoration(
            hintText: 'Contoh: SP/SDM/2026/014',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
        Text('Jenis Sanksi yang Dikenakan *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedJenisSanksi,
          items: listJenisSanksi
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedJenisSanksi = val);
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
        Text('Catatan / Diktum Putusan (Opsional)',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
        const SizedBox(height: 6),
        TextField(
          controller: _catatanSdmController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Uraikan isi sanksi atau dasar pertimbangan putusan...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        Text('Unggah Dokumen Surat Putusan (PDF / Scan)',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
        const SizedBox(height: 6),
        MediaLampiranPicker(
          controller: _putusanMedia,
          prefix: 'putusan_${p.nomorPengaduan}',
          includeFoto: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () async {
                    final nomor = _nomorSuratController.text.trim();
                    if (nomor.isEmpty) {
                      _showSnack('Nomor Surat Putusan wajib diisi.', red);
                      return;
                    }
                    final file = _putusanMedia.dokumen.isNotEmpty
                        ? _putusanMedia.dokumen.first
                        : (_putusanMedia.foto.isNotEmpty
                            ? _putusanMedia.foto.first
                            : '');
                    await _jalankan(
                      () => PengaduanService.sdmPutusanSanksi(
                        pengaduanId: p.supabaseId!,
                        oleh: oleh,
                        nomorSuratPutusan: nomor,
                        jenisSanksi: _selectedJenisSanksi,
                        fileSuratPutusan: file,
                        catatan: _catatanSdmController.text.trim().isEmpty
                            ? null
                            : _catatanSdmController.text.trim(),
                      ),
                      sukses:
                          'Surat Putusan Sanksi berhasil diterbitkan. Pengaduan selesai.',
                    );
                  },
            icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
            label: const Text('Tetapkan Sanksi & Selesaikan Pengaduan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => _bukaTerbitkanSk(p),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text('Buka Form SK Sanksi Lengkap (Opsi Lanjutan)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF0284C7)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelKspiPilihEksekutor(Pengaduan p, String oleh) {
    final listOfficial = [
      {
        'nik': '1711251',
        'nama': 'Nurkhuliyah',
        'jabatan': 'Kepala Divisi SPI (Teknik)',
        'category': 'kadiv',
        'divisi': 'Teknik',
      },
      {
        'nik': '1711571',
        'nama': 'Ghani Rashid',
        'jabatan': 'Kepala Divisi SPI (Administrasi & Keuangan)',
        'category': 'kadiv',
        'divisi': 'Administrasi',
      },
      {
        'nik': '1711161',
        'nama': 'Dodi Sudrajat',
        'jabatan': 'TPDPK / Anggota Tim SPI',
        'category': 'tpdpk',
        'divisi': null,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Pilih Tim Eksekutor Investigasi'),
        const SizedBox(height: 6),
        Text(
          'Direktur Utama telah menyetujui investigasi. Pilih salah satu eksekutor resmi di bawah atau cari dari daftar pegawai:',
          style: TextStyle(fontSize: 11.5, color: hintGrey, height: 1.4),
        ),
        const SizedBox(height: 12),
        for (final item in listOfficial) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF0284C7).withOpacity(0.25)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0284C7).withOpacity(0.12),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF0284C7), size: 20),
              ),
              title: Text(
                item['nama']!,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: labelDark),
              ),
              subtitle: Text(
                '${item['jabatan']} • NIK ${item['nik']}',
                style: TextStyle(fontSize: 11, color: hintGrey),
              ),
              trailing: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final catatan = await _dialogCatatan(
                          judul: 'Catatan Penugasan Investigasi (Opsional)',
                          hint: 'Instruksi khusus kepada ${item['nama']}...',
                        );
                        await _jalankan(
                          () => PengaduanService.reviewDanPilihEksekutor(
                            pengaduanId: p.supabaseId!,
                            oleh: oleh,
                            selectedExecutors: [
                              PegawaiOption(
                                id: item['nik']!,
                                name: item['nama']!,
                                nik: item['nik']!,
                                jabatan: item['jabatan']!,
                                unitKerja: 'SPI',
                                role: item['category']!,
                                divisiKadiv: item['divisi'],
                              ),
                            ],
                            eksekutorCategory: item['category'],
                            divisiKadiv: item['divisi'],
                            catatan: catatan,
                          ),
                          sukses:
                              'Eksekutor ${item['nama']} berhasil ditugaskan.',
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Tugaskan', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _isProcessing
                ? null
                : () async {
                    final picked =
                        await showPegawaiPickerSheet(context: context);
                    if (picked == null) return;
                    final catatan = await _dialogCatatan(
                      judul: 'Catatan Penugasan Investigasi (Opsional)',
                      hint: 'Instruksi khusus kepada ${picked.name}...',
                    );
                    await _jalankan(
                      () => PengaduanService.reviewDanPilihEksekutor(
                        pengaduanId: p.supabaseId!,
                        oleh: oleh,
                        selectedExecutors: [picked],
                        eksekutorCategory: picked.role,
                        divisiKadiv: picked.divisiKadiv,
                        catatan: catatan,
                      ),
                      sukses: 'Eksekutor ${picked.name} berhasil ditugaskan.',
                    );
                  },
            icon: const Icon(Icons.people_outline_rounded, size: 18),
            label: const Text('Pilih dari Daftar Pegawai Lainnya'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF0284C7)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
        const SizedBox(height: 6),
        Text(
          'Tentukan kesimpulan pemeriksaan, uraikan temuan fakta lapangan, buat surat rekomendasi, serta lampirkan bukti investigasi. Berkas langsung masuk ke Direktur Utama.',
          style: TextStyle(fontSize: 11.5, color: hintGrey, height: 1.4),
        ),
        const SizedBox(height: 14),
        Text('Kesimpulan Investigasi *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _kesimpulanInvestigasi = 'terbukti';
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _kesimpulanInvestigasi == 'terbukti'
                        ? red.withOpacity(0.08)
                        : AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kesimpulanInvestigasi == 'terbukti'
                          ? red
                          : AppColors.divider(context),
                      width: _kesimpulanInvestigasi == 'terbukti' ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gavel_rounded,
                          size: 18,
                          color: _kesimpulanInvestigasi == 'terbukti'
                              ? red
                              : hintGrey),
                      const SizedBox(width: 6),
                      Text(
                        '⚖️ Terbukti',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kesimpulanInvestigasi == 'terbukti'
                              ? red
                              : labelDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _kesimpulanInvestigasi = 'tidak_terbukti';
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: _kesimpulanInvestigasi == 'tidak_terbukti'
                        ? const Color(0xFF0284C7).withOpacity(0.08)
                        : AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kesimpulanInvestigasi == 'tidak_terbukti'
                          ? const Color(0xFF0284C7)
                          : AppColors.divider(context),
                      width:
                          _kesimpulanInvestigasi == 'tidak_terbukti' ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_rounded,
                          size: 18,
                          color: _kesimpulanInvestigasi == 'tidak_terbukti'
                              ? const Color(0xFF0284C7)
                              : hintGrey),
                      const SizedBox(width: 6),
                      Text(
                        '🛡️ Tidak Terbukti',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kesimpulanInvestigasi == 'tidak_terbukti'
                              ? const Color(0xFF0284C7)
                              : labelDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Temuan / Fakta Investigasi *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
        const SizedBox(height: 6),
        TextField(
          controller: _hasilController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Uraikan hasil investigasi dan temuan fakta di lapangan...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Surat Rekomendasi *',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelDark)),
            TextButton.icon(
              onPressed: () => setState(() => _isiTemplateRekomendasi(p)),
              icon: const Icon(Icons.description_outlined, size: 15),
              label: const Text('Gunakan Template',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _rekomendasiController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Ketik surat rekomendasi atau gunakan tombol template di atas...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),
        Text('Unggah Bukti (Foto, Video, Voice Note, Dokumen BAP)',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: labelDark)),
        const SizedBox(height: 6),
        MediaLampiranPicker(
          controller: _investigasiMedia,
          prefix: 'inv_${p.nomorPengaduan}',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () async {
                    final hasil = _hasilController.text.trim();
                    final rekomendasi = _rekomendasiController.text.trim();
                    if (hasil.isEmpty || rekomendasi.isEmpty) {
                      _showSnack(
                          'Hasil investigasi & surat rekomendasi wajib diisi.',
                          red);
                      return;
                    }
                    await _jalankan(
                      () => PengaduanService.kirimHasilInvestigasi(
                        pengaduanId: p.supabaseId!,
                        oleh: oleh,
                        role: role,
                        hasil: hasil,
                        rekomendasi: rekomendasi,
                        kesimpulanInvestigasi: _kesimpulanInvestigasi,
                        foto: _investigasiMedia.foto,
                        video: _investigasiMedia.video,
                        voice: _investigasiMedia.voice,
                        dokumen: _investigasiMedia.dokumen,
                      ),
                      sukses:
                          'Hasil investigasi dikirim langsung ke Direktur Utama.',
                    );
                  },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Kirim Hasil Investigasi ke Dirut'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelVerifikasiKadiv(Pengaduan p, String oleh) {
    String kategoriPilihan = p.kategori;
    const opsiKategori = ['Pelanggaran Administrasi', 'Pelanggaran Teknik'];
    final divisiSaya = widget.user.divisiKadiv;
    return StatefulBuilder(
      builder: (context, setLocal) {
        // Divisi Kadiv yang berwenang atas kategori yang sedang dipilih.
        final divisiKategori = divisiKadivDariKategori(kategoriPilihan);
        // True bila Kadiv mengubah jenis pelanggaran menjadi milik divisi
        // lain -> pengaduan harus DILEMPAR ke Kadiv divisi tsb, bukan
        // diteruskan ke KSPI oleh Kadiv yang sekarang.
        final pindahDivisi = divisiSaya != null &&
            divisiKategori != null &&
            divisiKategori != divisiSaya;

        Future<void> proses(Keputusan keputusan) async {
          String? catatan;
          if (keputusan == Keputusan.tolak) {
            catatan = await _dialogCatatan(
              judul: 'Catatan Penolakan (opsional)',
            );
          }
          final kategoriBaru =
              kategoriPilihan != p.kategori ? kategoriPilihan : null;
          await _jalankan(
            () => PengaduanService.kadivAksi(
              pengaduanId: p.supabaseId!,
              oleh: oleh,
              keputusan: keputusan,
              catatan: catatan,
              kategoriBaru: kategoriBaru,
            ),
            sukses: 'Terverifikasi & diteruskan ke KSPI.',
          );
        }

        Future<void> alihkan() async {
          final catatan = await _dialogCatatan(
            judul: 'Alasan Pengalihan (opsional)',
            hint: 'Mis. isi laporan menyangkut pekerjaan teknis di lapangan...',
            labelTombol: 'Alihkan',
          );
          await _jalankan(
            () => PengaduanService.alihkanKategoriKadiv(
              pengaduanId: p.supabaseId!,
              oleh: oleh,
              kategoriBaru: kategoriPilihan,
              nomorPengaduan: p.nomorPengaduan,
              catatan: catatan,
            ),
            sukses: 'Pengaduan dialihkan ke ${divisiKategori!.label}.',
          );
          if (mounted) Navigator.of(context).maybePop();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Verifikasi Pengaduan'),
            const SizedBox(height: 6),
            Text(
              'Perbaiki jenis pelanggaran bila pegawai salah menempatkannya. '
              'Bila jenisnya menjadi kewenangan divisi lain, pengaduan '
              'otomatis dialihkan ke Kadiv divisi tersebut. Selama jenisnya '
              'tetap di divisi Anda, Terima maupun Tolak sama-sama '
              'diteruskan ke KSPI (keputusan tetap dicatat).',
              style: TextStyle(fontSize: 11.5, color: hintGrey, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text('Kategori Pelanggaran',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: labelDark)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final k in opsiKategori)
                  ChoiceChip(
                    label: Text(k, style: const TextStyle(fontSize: 11.5)),
                    selected: kategoriPilihan == k,
                    selectedColor: accent,
                    labelStyle: TextStyle(
                      color: kategoriPilihan == k ? Colors.white : labelDark,
                    ),
                    onSelected: (_) => setLocal(() => kategoriPilihan = k),
                  ),
              ],
            ),
            if (pindahDivisi) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE67E22).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE67E22).withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 18, color: Color(0xFFE67E22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jenis pelanggaran ini bukan kewenangan '
                        '${divisiSaya.label}. Pengaduan akan dialihkan ke '
                        '${divisiKategori.label} dan hilang dari kotak masuk '
                        'Anda.',
                        style: TextStyle(
                            fontSize: 11.5, color: labelDark, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : alihkan,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text('Alihkan ke ${divisiKategori.label}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE67E22),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => proses(Keputusan.tolak),
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
                        onPressed: _isProcessing
                            ? null
                            : () => proses(Keputusan.terima),
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
          ],
        );
      },
    );
  }

  Widget _panelTeruskanKeDirut(Pengaduan p, String oleh) {
    final keputusanKadivLabel = p.keputusanKadiv?.label ?? '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Review & Verifikasi KSPI'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (p.keputusanKadiv == Keputusan.tolak ? red : green)
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
                color: p.keputusanKadiv == Keputusan.tolak ? red : green,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Keputusan Kadiv: $keputusanKadivLabel'
                  '${p.catatanKadiv != null && p.catatanKadiv!.trim().isNotEmpty ? ' — ${p.catatanKadiv}' : ''}',
                  style:
                      TextStyle(fontSize: 11.5, color: labelDark, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tinjau & verifikasi kembali laporan ini sebelum diteruskan ke '
          'Dirut. KSPI dapat menolak pengaduan di tahap ini — bila ditolak, '
          'proses berhenti, pengaduan diarsipkan, dan alasannya '
          'disampaikan ke pelapor.',
          style: TextStyle(fontSize: 11.5, color: hintGrey, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          final catatan = await _dialogCatatan(
                            judul: 'Alasan Penolakan KSPI',
                            hint: 'Jelaskan alasan pengaduan ini ditolak...',
                            wajib: true,
                            labelTombol: 'Tolak & Arsipkan',
                            warnaTombol: red,
                          );
                          if (catatan == null) return;
                          await _jalankan(
                            () => PengaduanService.kspiTolak(
                              pengaduanId: p.supabaseId!,
                              oleh: oleh,
                              catatan: catatan,
                            ),
                            sukses:
                                'Pengaduan ditolak KSPI & diarsipkan. Pelapor telah diberi tahu.',
                          );
                        },
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
                  onPressed: _isProcessing
                      ? null
                      : () => _jalankan(
                            () => PengaduanService.kspiTeruskanKeDirut(
                              pengaduanId: p.supabaseId!,
                              oleh: oleh,
                            ),
                            sukses: 'Pengaduan diteruskan ke Dirut.',
                          ),
                  icon: const Icon(Icons.forward_to_inbox_rounded, size: 18),
                  label: const Text('Teruskan ke Dirut'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
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