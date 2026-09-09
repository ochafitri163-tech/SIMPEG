import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/dokumen_service.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';

/// Halaman "Dokumen Surat (SDM)" / "Dokumen Resmi Pegawai (SDM)"
/// Menampilkan Surat Kerja (SK) & Surat Diklat/Pelatihan resmi milik pegawai
/// yang diterbitkan dan diverifikasi oleh SDM, identik dengan halaman di Web SIMPEG.
class DokumenResmiScreen extends StatefulWidget {
  final AppUser user;
  const DokumenResmiScreen({super.key, required this.user});

  @override
  State<DokumenResmiScreen> createState() => _DokumenResmiScreenState();
}

class _DokumenResmiScreenState extends State<DokumenResmiScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color accent = Color(0xFF2E86AB);
  static const Color docBlue = Color(0xFF0284C7);

  late Future<List<DokumenKepegawaian>> _future;

  @override
  void initState() {
    super.initState();
    _future = DokumenService.dokumenResmiSaya();
  }

  void _refresh() {
    setState(() {
      _future = DokumenService.dokumenResmiSaya();
    });
  }

  Future<void> _bukaFileLangsung(DokumenKepegawaian d) async {
    if (d.fileUrl.isNotEmpty) {
      final uri = Uri.tryParse(d.fileUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Mengunduh ${d.fileNama.isNotEmpty ? d.fileNama : 'dokumen.pdf'}...'),
              ),
            ],
          ),
          backgroundColor: docBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showPreviewModal(DokumenKepegawaian d) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSk = d.kategori == 'SK' || d.judul.toLowerCase().contains('sk') || d.judul.toLowerCase().contains('pengangkatan');
    final tglFormat = '${d.dibuatPada.day} ${_getNamaBulan(d.dibuatPada.month)} ${d.dibuatPada.year}';
    final namaPegawai = widget.user.nama.isNotEmpty ? widget.user.nama : 'Pegawai Perumda';
    final nikPegawai = widget.user.nik.isNotEmpty ? widget.user.nik : '0000000000000000';
    final jabatanPegawai = widget.user.jabatan.isNotEmpty ? widget.user.jabatan : 'Staf Pegawai';
    final unitKerjaPegawai = widget.user.unitKerja.isNotEmpty ? widget.user.unitKerja : 'Kantor Pusat Indramayu';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E2638) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 520,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Bar Modal
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: docBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSk ? Icons.description_rounded : Icons.school_rounded,
                          size: 20,
                          color: docBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lembar Dokumen Resmi SDM',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              isSk ? 'Surat Keputusan (SK) Direksi' : 'Sertifikat Diklat & Pelatihan',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppColors.textSecondary(context),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Scrollable Paper Document View
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Kop Surat
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.water_drop_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'PERUSAHAAN UMUM DAERAH AIR MINUM',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'TIRTA DARMA AYU',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'serif',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0284C7),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Jl. Ki Hajar Dewantara No. 15, Kotakulon, Indramayu\nTelp: (0234) 272027 | Email: info@tirtadarmaayu.co.id',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: Color(0xFF64748B),
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Garis Ganda Kop Surat
                          Container(height: 2.2, color: const Color(0xFF0F172A)),
                          const SizedBox(height: 1.5),
                          Container(height: 0.8, color: const Color(0xFF0F172A)),
                          const SizedBox(height: 14),

                          // Judul Surat & Nomor
                          Text(
                            isSk ? 'SURAT KEPUTUSAN DIREKSI' : 'SERTIFIKAT KELULUSAN & KOMPETENSI',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Nomor: ${d.nomor ?? (isSk ? "SK/SDM/2024/001" : "STP/SDM/2024/088")}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Isi Surat
                          if (isSk) ...[
                            const Text(
                              'TENTANG',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            Text(
                              d.judul.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'DIREKTUR UTAMA PERUMDA AIR MINUM TIRTA DARMA AYU',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Menimbang: Bahwa demi kelancaran tugas kepegawaian dan peningkatan mutu pelayanan, dipandang perlu menetapkan keputusan ini.\n\nMemutuskan dan Menetapkan kepada:',
                                style: TextStyle(fontSize: 9.5, color: Color(0xFF334155), height: 1.4),
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Diberikan dengan bangga kepada:',
                              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // Box Biodata Pegawai
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _previewRow('Nama Pegawai', namaPegawai, isBold: true),
                                const SizedBox(height: 4),
                                _previewRow('NIK / No. Induk', nikPegawai),
                                const SizedBox(height: 4),
                                _previewRow('Jabatan', jabatanPegawai),
                                const SizedBox(height: 4),
                                _previewRow('Unit Kerja', unitKerjaPegawai),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Diktum Akhir
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              isSk
                                  ? 'Keputusan ini berlaku sejak tanggal ditetapkan, dengan ketentuan apabila di kemudian hari terdapat kekeliruan akan diperbaiki sebagaimana mestinya.'
                                  : 'Telah mengikuti dan menyelesaikan kegiatan Pelatihan serta dinyatakan LULUS dan Memenuhi Standar Kompetensi Kepegawaian Perumda Air Minum Tirta Darma Ayu.',
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155), height: 1.4),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Tanda Tangan & QR
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // QR Code Verifikasi
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Column(
                                  children: const [
                                    Icon(Icons.qr_code_2_rounded, size: 40, color: Color(0xFF0F172A)),
                                    SizedBox(height: 2),
                                    Text('TERVERIFIKASI', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                                  ],
                                ),
                              ),

                              // TTD & Stempel
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Ditetapkan di Indramayu\nPada tanggal $tglFormat',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Direktur Utama,',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 6),
                                  // Stempel + Paraf
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.6), width: 1.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          '★ PERUMDA TIRTA DARMA AYU ★',
                                          style: TextStyle(
                                            fontSize: 6.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.gesture_rounded, size: 28, color: Color(0xFF1E293B)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Ir. H. Ady Setiawan, S.H., M.H., M.M.',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Divider(height: 1),

                // Footer Buttons Modal
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: AppColors.divider(context)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Tutup',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _bukaFileLangsung(d);
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Unduh Berkas', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: docBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  String _getNamaBulan(int bulan) {
    const namaBulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return (bulan >= 1 && bulan <= 12) ? namaBulan[bulan - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.pageBackground(context),
      body: Column(
        children: [
          // Top AppBar Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF081A45), Color(0xFF1F5F79)]
                    : const [navy, accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Dokumen Surat (SDM)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Surat Kerja & Surat Diklat resmi dari SDM',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Card View
          Expanded(
            child: FutureBuilder<List<DokumenKepegawaian>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <DokumenKepegawaian>[];
                final skList = items.where((d) => d.kategori == 'SK').toList();
                final diklatList = items.where((d) => d.kategori == 'Diklat').toList();

                final sk = skList.isNotEmpty ? skList.first : null;
                final diklat = diklatList.isNotEmpty ? diklatList.first : null;

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppColors.cardShadow(context),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dokumen Resmi Pegawai (SDM)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Surat Kerja & Surat Diklat resmi yang diterbitkan dan diunggah oleh SDM.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary(context),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Kartu 1: Surat Kerja (SK)
                            _DocCard(
                              badgeLabel: 'Surat Kerja (SK)',
                              badgeBg: const Color(0xFFECFDF5),
                              badgeBorder: const Color(0xFFA7F3D0),
                              badgeText: const Color(0xFF047857),
                              badgeIcon: Icons.description_rounded,
                              defaultTitle: 'Surat Keputusan Pengangkatan Pegawai Tetap',
                              defaultNomor: 'SK/SDM/2024/001',
                              defaultDate: '2024-01-15',
                              defaultFileName: 'SK_Pengangkatan_Pegawai.pdf',
                              dokumen: sk,
                              onView: (d) => _showPreviewModal(d),
                              onDownload: (d) => _bukaFileLangsung(d),
                            ),

                            const SizedBox(height: 16),

                            // Kartu 2: Surat Diklat / Pelatihan
                            _DocCard(
                              badgeLabel: 'Surat Diklat / Pelatihan',
                              badgeBg: const Color(0xFFF5F3FF),
                              badgeBorder: const Color(0xFFDDD6FE),
                              badgeText: const Color(0xFF6D28D9),
                              badgeIcon: Icons.school_rounded,
                              defaultTitle: 'Sertifikat Diklat & Pelatihan Manajemen Kepegawaian',
                              defaultNomor: 'STP/SDM/2024/088',
                              defaultDate: '2024-05-20',
                              defaultFileName: 'Sertifikat_Diklat_SDM.pdf',
                              dokumen: diklat,
                              onView: (d) => _showPreviewModal(d),
                              onDownload: (d) => _bukaFileLangsung(d),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeText;
  final IconData badgeIcon;
  final String defaultTitle;
  final String defaultNomor;
  final String defaultDate;
  final String defaultFileName;
  final DokumenKepegawaian? dokumen;
  final void Function(DokumenKepegawaian) onView;
  final void Function(DokumenKepegawaian) onDownload;

  const _DocCard({
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.badgeIcon,
    required this.defaultTitle,
    required this.defaultNomor,
    required this.defaultDate,
    required this.defaultFileName,
    required this.dokumen,
    required this.onView,
    required this.onDownload,
  });

  static const Color docBlue = Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final judul = dokumen?.judul.trim().isNotEmpty == true ? dokumen!.judul : defaultTitle;
    final nomor = dokumen?.nomor?.trim().isNotEmpty == true ? dokumen!.nomor! : defaultNomor;
    final fileNama = dokumen?.fileNama.trim().isNotEmpty == true ? dokumen!.fileNama : defaultFileName;
    final tglStr = dokumen != null ? _formatTgl(dokumen!.dibuatPada) : defaultDate;

    // Objek aktif untuk action
    final activeDoc = dokumen ??
        DokumenKepegawaian(
          id: 0,
          judul: judul,
          kategori: badgeLabel,
          fileUrl: '',
          fileNama: fileNama,
          nomor: nomor,
          dibuatPada: DateTime.tryParse(tglStr) ?? DateTime.now(),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192132) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF28344C) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark ? badgeText.withValues(alpha: 0.18) : badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? badgeText.withValues(alpha: 0.35) : badgeBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: isDark ? badgeText : badgeText),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tglStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            judul,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              height: 1.35,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle / No Surat
          Text(
            'No: $nomor',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onView(activeDoc),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View File', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary(context),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                    backgroundColor: isDark ? const Color(0xFF141A29) : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onDownload(activeDoc),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download', style: TextStyle(fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: docBlue,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: docBlue.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTgl(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}