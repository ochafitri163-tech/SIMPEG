import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/dokumen_service.dart';
import '../../models/user_role.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

/// Custom Painter untuk menggambar border putus-putus (dashed border)
/// persis seperti CSS `border: 1px dashed #CBD5E1;` pada Web SIMPEG.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  const DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.borderRadius = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final currentDash = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        final extract = metric.extractPath(distance, distance + currentDash);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// Halaman "Dokumen Surat (SDM)" / "Dokumen Resmi Pegawai (SDM)"
/// Menampilkan Surat Kerja (SK) & Surat Diklat/Pelatihan resmi milik pegawai
/// yang diterbitkan dan diunggah oleh SDM, identik 100% dengan tampilan di Web SIMPEG.
class DokumenResmiScreen extends StatefulWidget {
  final AppUser user;
  const DokumenResmiScreen({super.key, required this.user});

  @override
  State<DokumenResmiScreen> createState() => _DokumenResmiScreenState();
}

class _DokumenResmiScreenState extends State<DokumenResmiScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color docBlue = Color(0xFF0284C7);

  late Future<List<DokumenKepegawaian>> _future;

  @override
  void initState() {
    super.initState();
    _future = DokumenService.dokumenResmiSaya(nik: widget.user.nik);
  }

  void _refresh() {
    setState(() {
      _future = DokumenService.dokumenResmiSaya(nik: widget.user.nik);
    });
  }

  /// Menyesuaikan host localhost / 127.0.0.1 bila berjalan di emulator Android
  String _resolveFileUrl(String rawUrl) {
    if (rawUrl.isEmpty || rawUrl == '#') return '';
    var url = rawUrl;
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (url.contains('127.0.0.1')) {
        url = url.replaceAll('127.0.0.1', '10.0.2.2');
      } else if (url.contains('localhost')) {
        url = url.replaceAll('localhost', '10.0.2.2');
      }
    }
    return url;
  }

  /// Menampilkan dokumen fisik (View File)
  Future<void> _viewFile(DokumenKepegawaian d) async {
    final url = _resolveFileUrl(d.fileUrl);
    if (url.isEmpty || url == '#') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berkas fisik dokumen ini belum diunggah oleh SDM.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Pada browser Web, buka langsung PDF/gambar di tab baru
    if (kIsWeb) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          return;
        } catch (_) {}
      }
    }

    // Tampilkan modal loading sederhana
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: docBlue),
                SizedBox(height: 14),
                Text(
                  'Membuka dokumen...',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        final isPdf = d.fileNama.toLowerCase().endsWith('.pdf') ||
            url.toLowerCase().endsWith('.pdf') ||
            (bytes.length >= 4 &&
                bytes[0] == 0x25 &&
                bytes[1] == 0x50 &&
                bytes[2] == 0x44 &&
                bytes[3] == 0x46); // Header %PDF

        if (isPdf) {
          // Buka interactive PDF viewer native
          await Printing.layoutPdf(
            name: d.fileNama.isNotEmpty ? d.fileNama : 'Dokumen.pdf',
            onLayout: (format) async => bytes,
          );
          return;
        } else {
          // Buka viewer gambar
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      title: Text(
                        d.judul,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    InteractiveViewer(
                      maxScale: 4.0,
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            );
            return;
          }
        }
      }
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    // Fallback: coba luncurkan URL langsung ke aplikasi eksternal / browser
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka ${d.fileNama}. Periksa koneksi ke server.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Mengunduh dokumen fisik (Download)
  Future<void> _downloadFile(DokumenKepegawaian d) async {
    final url = _resolveFileUrl(d.fileUrl);
    if (url.isEmpty || url == '#') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berkas fisik dokumen ini belum diunggah oleh SDM.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final downloadApiUrl = (d.id != null && d.id!.isNotEmpty && int.tryParse(d.id!) != null)
        ? '${ApiService.baseUrl}/dokumen/${d.id}/download'
        : url;

    // Pada browser Web, gunakan link download API langsung untuk trigger browser file download
    if (kIsWeb) {
      final uri = Uri.tryParse(downloadApiUrl);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {}
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mengunduh ${d.fileNama.isNotEmpty ? d.fileNama : 'dokumen'}...',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: docBlue,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        final fileName = d.fileNama.isNotEmpty ? d.fileNama : 'Dokumen.pdf';

        // Trigger native OS save / share sheet (Downloads / Drive / File Manager)
        await Printing.sharePdf(bytes: bytes, filename: fileName);

        if (mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$fileName berhasil diunduh',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF047857),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    // Fallback: buka link unduh langsung di browser eksternal
    final uri = Uri.tryParse(downloadApiUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }

    if (mounted) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh ${d.fileNama}. Periksa koneksi ke server.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground(context),
      body: Column(
        children: [
          // Top Header Bar
          ClipRRect(
            child: Container(
              width: double.infinity,
              color: navy,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    right: -40,
                    top: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 20,
                      right: 20,
                      bottom: 20,
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                ],
              ),
            ),
          ),

          // Main Card View
          Expanded(
            child: FutureBuilder<List<DokumenKepegawaian>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: docBlue));
                }

                final items = snapshot.data ?? const <DokumenKepegawaian>[];
                final skList = items.where((d) => d.kategori == 'SK').toList();
                final diklatList = items.where((d) => d.kategori == 'Diklat').toList();

                final sk = skList.isNotEmpty ? skList.first : null;
                final diklat = diklatList.isNotEmpty ? diklatList.first : null;

                return RefreshIndicator(
                  color: docBlue,
                  onRefresh: () async => _refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // Ribbon Card Header
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
                            // Header Title & Subtitle persis Web
                            Text(
                              'Dokumen Resmi Pegawai (SDM)',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Surat Kerja & Surat Diklat resmi yang diterbitkan dan diunggah oleh SDM.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary(context),
                                height: 1.35,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Kartu 1: Surat Kerja (SK)
                            _DocCard(
                              badgeLabel: 'Surat Kerja (SK)',
                              badgeBg: const Color(0xFFECFDF5),
                              badgeBorder: const Color(0xFFA7F3D0),
                              badgeText: const Color(0xFF047857),
                              badgeIcon: Icons.description_outlined,
                              emptyTitle: 'Belum Ada Dokumen SK',
                              emptySubtitle: 'Surat Keputusan belum diterbitkan atau diunggah oleh SDM.',
                              dokumen: sk,
                              onView: (d) => _viewFile(d),
                              onDownload: (d) => _downloadFile(d),
                            ),

                            const SizedBox(height: 18),

                            // Kartu 2: Surat Diklat / Pelatihan
                            _DocCard(
                              badgeLabel: 'Surat Diklat / Pelatihan',
                              badgeBg: const Color(0xFFF5F3FF),
                              badgeBorder: const Color(0xFFDDD6FE),
                              badgeText: const Color(0xFF6D28D9),
                              badgeIcon: Icons.school_outlined,
                              emptyTitle: 'Belum Ada Dokumen Diklat',
                              emptySubtitle: 'Sertifikat Diklat belum diterbitkan atau diunggah oleh SDM.',
                              dokumen: diklat,
                              onView: (d) => _viewFile(d),
                              onDownload: (d) => _downloadFile(d),
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

/// Widget Kartu Dokumen (SK & Diklat) yang identik dengan Web SIMPEG
class _DocCard extends StatelessWidget {
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeText;
  final IconData badgeIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final DokumenKepegawaian? dokumen;
  final void Function(DokumenKepegawaian) onView;
  final void Function(DokumenKepegawaian) onDownload;

  const _DocCard({
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.badgeIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.dokumen,
    required this.onView,
    required this.onDownload,
  });

  static const Color docBlue = Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adaDokumen = dokumen != null;

    final judul = adaDokumen ? dokumen!.judul : emptyTitle;
    final sub = adaDokumen ? 'No: ${dokumen!.nomor ?? '-'}' : emptySubtitle;
    final tglStr = adaDokumen ? _formatTgl(dokumen!.dibuatPada) : 'Belum terbit';

    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192132) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: adaDokumen
            ? Border.all(
                color: isDark ? const Color(0xFF28344C) : const Color(0xFFE2E8F0),
                width: 1,
              )
            : null, // border digambar oleh DashedBorderPainter bila kosong
        boxShadow: adaDokumen
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Badge Kategori & Tanggal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? badgeText.withValues(alpha: 0.16) : badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? badgeText.withValues(alpha: 0.35) : badgeBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeText),
                    const SizedBox(width: 6),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tglStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Judul Dokumen
          Text(
            judul,
            style: TextStyle(
              fontSize: 15,
              fontWeight: adaDokumen ? FontWeight.w700 : FontWeight.w600,
              color: adaDokumen
                  ? AppColors.textPrimary(context)
                  : AppColors.textSecondary(context),
              height: 1.35,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle (No Surat atau Keterangan Belum Diterbitkan)
          Text(
            sub,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary(context),
              height: 1.35,
            ),
          ),

          const SizedBox(height: 18),

          // Aksi Dokumen (Tombol View File & Download ATAU Status "Belum Tersedia")
          if (adaDokumen)
            Row(
              children: [
                // Tombol [View File] persis Web
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onView(dokumen!),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text(
                      'View File',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                      backgroundColor:
                          isDark ? const Color(0xFF141A29) : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Tombol [Download] persis Web
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onDownload(dokumen!),
                    icon: const Icon(Icons.download_rounded, size: 15),
                    label: const Text(
                      'Download',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: docBlue,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shadowColor: docBlue.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            )
          else
            // Status Footer saat Belum Ada Dokumen
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Belum Tersedia',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
        ],
      ),
    );

    // Bila belum ada dokumen, bungkus dengan dashed border & opacity 0.85
    if (!adaDokumen) {
      return Opacity(
        opacity: 0.85,
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            borderRadius: 14,
            strokeWidth: 1.2,
          ),
          child: content,
        ),
      );
    }

    return content;
  }

  String _formatTgl(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}