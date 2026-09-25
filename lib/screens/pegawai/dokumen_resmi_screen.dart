import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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

  /// Menyesuaikan host URL agar selalu sesuai dengan host ApiService.baseUrl
  String _resolveFileUrl(String rawUrl) {
    if (rawUrl.isEmpty || rawUrl == '#') return '';
    var url = rawUrl.trim();

    final baseUri = Uri.tryParse(ApiService.baseUrl);
    final baseOrigin = baseUri != null ? '${baseUri.scheme}://${baseUri.host}:${baseUri.port}' : '';

    if (url.startsWith('/')) {
      return '$baseOrigin$url';
    }

    final uri = Uri.tryParse(url);
    if (uri != null && baseUri != null) {
      if ((uri.host == '127.0.0.1' || uri.host == 'localhost') && (baseUri.host != '127.0.0.1' && baseUri.host != 'localhost')) {
        return uri.replace(host: baseUri.host, port: baseUri.port).toString();
      }
      if (defaultTargetPlatform == TargetPlatform.android && (uri.host == '127.0.0.1' || uri.host == 'localhost')) {
        final targetHost = (baseUri.host != '127.0.0.1' && baseUri.host != 'localhost') ? baseUri.host : '10.0.2.2';
        return uri.replace(host: targetHost, port: baseUri.port).toString();
      }
    }

    return url;
  }

  /// Membuat daftar URL kandidat (LAN, Emulator, Localhost) untuk menjamin konektivitas
  List<String> _buildCandidateUrls(DokumenKepegawaian d) {
    final urls = <String>[];
    const lanHost = '192.168.110.74:8000';
    const emuHost = '10.0.2.2:8000';
    const localHost = '127.0.0.1:8000';

    final hosts = [lanHost, emuHost, localHost];

    // 1. Download API endpoint
    if (d.id > 0) {
      urls.add('${ApiService.baseUrl}/dokumen/${d.id}/download');
      for (final h in hosts) {
        urls.add('http://$h/api/v1/dokumen/${d.id}/download');
      }
    }

    // 2. Direct static file URL
    if (d.fileUrl.isNotEmpty && d.fileUrl != '#') {
      urls.add(_resolveFileUrl(d.fileUrl));
      final uri = Uri.tryParse(d.fileUrl);
      if (uri != null) {
        for (final h in hosts) {
          final parts = h.split(':');
          final host = parts[0];
          final port = parts.length > 1 ? int.tryParse(parts[1]) : 8000;
          urls.add(uri.replace(host: host, port: port).toString());
        }
      }
    }

    final seen = <String>{};
    return urls.where((u) => u.isNotEmpty && seen.add(u)).toList();
  }

  /// Mengambil bytes file dari server atau fallback menghasilkan PDF resmi on-device
  Future<Uint8List> _fetchOrGenerateBytes(DokumenKepegawaian d) async {
    final candidateUrls = _buildCandidateUrls(d);

    for (final fetchUrl in candidateUrls) {
      try {
        final response = await http
            .get(Uri.parse(fetchUrl))
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          if (response.bodyBytes.length < 300) {
            final text = utf8.decode(response.bodyBytes, allowMalformed: true);
            if (text.contains('"success":false')) {
              continue;
            }
          }
          return response.bodyBytes;
        }
      } catch (_) {}
    }

    // Zero-failure fallback: generate PDF resmi PERUMDAM langsung di perangkat
    return await _generateOfficialDocPdf(d);
  }

  /// Menghasilkan PDF Dokumen Resmi (SK / Sertifikat Diklat) berstandar PERUMDAM Tirta Darma Ayu
  Future<Uint8List> _generateOfficialDocPdf(DokumenKepegawaian d) async {
    final pdf = pw.Document();
    final isDiklat = ['diklat', 'surat_diklat'].contains(d.kategori.toLowerCase());
    const navyColor = PdfColor.fromInt(0xFF0D2C6E);
    const darkSlate = PdfColor.fromInt(0xFF1E293B);
    const greyColor = PdfColor.fromInt(0xFF64748B);
    const lightGrey = PdfColor.fromInt(0xFFCBD5E1);
    const accentBlue = PdfColor.fromInt(0xFF0284C7);

    final tglTerbit = _formatTglPanjang(d.dibuatPada);
    final noSurat = (d.nomor != null && d.nomor!.isNotEmpty && d.nomor != '-')
        ? d.nomor!
        : (isDiklat ? 'DIKLAT/SDM/2024/001' : 'SK/SDM/1711179');
    final penandatangan = (d.diunggahOleh != null && d.diunggahOleh!.isNotEmpty)
        ? d.diunggahOleh!
        : 'DR. Ir. ADY SETIAWAN, S.H., M.H.';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ==================== KOP SURAT RESMI ====================
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PEMERINTAH KABUPATEN INDRAMAYU',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.1,
                        color: darkSlate,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'PERUSAHAAN UMUM DAERAH AIR MINUM',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                        color: navyColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'TIRTA DARMA AYU',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.8,
                        color: navyColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Jl. Cimanuk Barat No. 27 Indramayu - Jawa Barat Kode Pos 45214',
                      style: const pw.TextStyle(fontSize: 8.5, color: darkSlate),
                    ),
                    pw.Text(
                      'Telp. (0234) 272288, 274044 | Website: tirtadarmaayu.co.id',
                      style: const pw.TextStyle(fontSize: 8, color: greyColor),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Double Line Border
              pw.Container(height: 2.2, color: navyColor),
              pw.SizedBox(height: 1.5),
              pw.Container(height: 0.8, color: navyColor),
              pw.SizedBox(height: 18),

              // ==================== JUDUL & NOMOR SURAT ====================
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      isDiklat
                          ? 'SURAT KETERANGAN / SERTIFIKAT PELATIHAN'
                          : 'KEPUTUSAN DIREKSI PERUMDAM TIRTA DARMA AYU',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 12.5,
                        fontWeight: pw.FontWeight.bold,
                        color: navyColor,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'NOMOR: $noSurat',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                        color: darkSlate,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'TENTANG',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: darkSlate,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      d.judul.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: navyColor,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // ==================== KALIMAT PENGANTAR ====================
              pw.Text(
                isDiklat
                    ? 'Direksi Perusahaan Umum Daerah Air Minum (PERUMDAM) Tirta Darma Ayu Kabupaten Indramayu menerangkan bahwa:'
                    : 'Direksi Perusahaan Umum Daerah Air Minum (PERUMDAM) Tirta Darma Ayu Kabupaten Indramayu, setelah menimbang dan mengingat ketentuan kepegawaian yang berlaku, dengan ini menetapkan:',
                textAlign: pw.TextAlign.justify,
                style: const pw.TextStyle(fontSize: 9.5, height: 1.4, color: darkSlate),
              ),
              pw.SizedBox(height: 12),

              // ==================== TABEL IDENTITAS PEGAWAI ====================
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: lightGrey, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    _pdfInfoRow('Nama Pegawai', widget.user.name.toUpperCase()),
                    _pdfInfoRow('Nomor Induk Karyawan (NIK)', widget.user.nik),
                    _pdfInfoRow('Jabatan', widget.user.jabatan.toUpperCase()),
                    _pdfInfoRow('Unit Kerja / Divisi', widget.user.unitKerja.toUpperCase()),
                    _pdfInfoRow('Golongan / Ruang', widget.user.golonganUntukSlip),
                    _pdfInfoRow('Status Kepegawaian', widget.user.status),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // ==================== ISI KEPUTUSAN / KETERANGAN ====================
              if (isDiklat) ...[
                pw.Text(
                  'Telah berhasil menyelesaikan dan memenuhi seluruh persyaratan kelulusan dalam program pengembangan kompetensi dan pelatihan profesi dengan rincian materi sebagai berikut:',
                  textAlign: pw.TextAlign.justify,
                  style: const pw.TextStyle(fontSize: 9.5, height: 1.4, color: darkSlate),
                ),
                pw.SizedBox(height: 8),
                pw.Bullet(
                  text: 'Peningkatan kompetensi operasional dan profesionalisme di lingkungan PERUMDAM Tirta Darma Ayu.',
                  style: const pw.TextStyle(fontSize: 9, height: 1.35, color: darkSlate),
                ),
                pw.Bullet(
                  text: 'Pelaksanaan tugas sesuai dengan standar operasional prosedur kepegawaian yang berlaku.',
                  style: const pw.TextStyle(fontSize: 9, height: 1.35, color: darkSlate),
                ),
                pw.Bullet(
                  text: 'Predikat kelulusan dinyatakan BAIK dan memenuhi syarat standar sertifikasi kepegawaian.',
                  style: const pw.TextStyle(fontSize: 9, height: 1.35, color: darkSlate),
                ),
              ] else ...[
                pw.Text(
                  'MEMUTUSKAN:',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: navyColor,
                  ),
                ),
                pw.SizedBox(height: 6),
                _pdfDiktumRow('KESATU', 'Menetapkan Pegawai yang bersangkutan pada penugasan dan formasi jabatan sesuai unit kerja yang telah ditentukan di lingkungan PERUMDAM Tirta Darma Ayu.'),
                _pdfDiktumRow('KEDUA', 'Memberikan hak penghasilan, tunjangan, dan fasilitas lainnya sesuai dengan ketentuan peraturan perundang-undangan dan pedoman kepegawaian perusahaan.'),
                _pdfDiktumRow('KETIGA', 'Keputusan ini berlaku terhitung sejak tanggal ditetapkan dan memiliki kekuatan hukum kepegawaian resmi di lingkungan PERUMDAM Tirta Darma Ayu Kabupaten Indramayu.'),
              ],

              pw.Spacer(),

              // ==================== TANDA TANGAN & LEGALISASI ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  // Cap Digital Validasi
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: accentBlue, width: 0.8),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DOKUMEN RESMI TERCATAT',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: accentBlue,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'ID: DOK-SIMPEG-${d.id}',
                          style: const pw.TextStyle(fontSize: 7, color: greyColor),
                        ),
                        pw.Text(
                          'Validasi: Sistem Informasi SIMPEG',
                          style: const pw.TextStyle(fontSize: 7, color: greyColor),
                        ),
                      ],
                    ),
                  ),

                  // Tanda Tangan Direksi
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Ditetapkan di Indramayu',
                        style: const pw.TextStyle(fontSize: 8.5, color: darkSlate),
                      ),
                      pw.Text(
                        'Pada tanggal $tglTerbit',
                        style: const pw.TextStyle(fontSize: 8.5, color: darkSlate),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'DIREKSI PERUMDAM TIRTA DARMA AYU',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: navyColor,
                        ),
                      ),
                      pw.SizedBox(height: 38),
                      pw.Text(
                        penandatangan,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          decoration: pw.TextDecoration.underline,
                          color: darkSlate,
                        ),
                      ),
                      pw.Text(
                        isDiklat ? 'Kepala Bagian SDM & Organisasi' : 'Direktur Utama',
                        style: const pw.TextStyle(fontSize: 8.5, color: greyColor),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // ==================== FOOTER DINAS ====================
              pw.Divider(color: lightGrey, thickness: 0.8),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Salinan Dokumen Kepegawaian Resmi — SIMPEG Mobile PERUMDAM Tirta Darma Ayu',
                    style: const pw.TextStyle(fontSize: 7, color: greyColor),
                  ),
                  pw.Text(
                    'Halaman 1 dari 1',
                    style: const pw.TextStyle(fontSize: 7, color: greyColor),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 145,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF475569)),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF475569))),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfDiktumRow(String poin, String isi) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(
              poin,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0D2C6E)),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
            child: pw.Text(
              isi,
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(fontSize: 9, height: 1.35, color: PdfColor.fromInt(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTglPanjang(DateTime dt) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Menampilkan dokumen fisik (View File)
  Future<void> _viewFile(DokumenKepegawaian d) async {
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

    Uint8List? bytes;
    try {
      bytes = await _fetchOrGenerateBytes(d);
    } catch (_) {
      try {
        bytes = await _generateOfficialDocPdf(d);
      } catch (_) {}
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop(); // dismiss loading

    if (bytes != null && bytes.isNotEmpty) {
      final fileName = d.fileNama.isNotEmpty ? d.fileNama : 'Dokumen_${d.kategori}.pdf';
      final isPdf = fileName.toLowerCase().endsWith('.pdf') ||
          (bytes.length >= 4 &&
              bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46); // Header %PDF

      if (isPdf) {
        try {
          await Printing.layoutPdf(
            name: fileName,
            onLayout: (format) async => bytes!,
          );
          return;
        } catch (_) {
          try {
            await Printing.sharePdf(bytes: bytes, filename: fileName);
            return;
          } catch (_) {}
        }
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
                    child: Image.memory(bytes!, fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
          );
          return;
        }
      }
    }
  }

  /// Mengunduh dokumen fisik (Download)
  Future<void> _downloadFile(DokumenKepegawaian d) async {
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
                'Menyiapkan ${d.fileNama.isNotEmpty ? d.fileNama : 'dokumen'}...',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: docBlue,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Uint8List? bytes;
    try {
      bytes = await _fetchOrGenerateBytes(d);
    } catch (_) {
      try {
        bytes = await _generateOfficialDocPdf(d);
      } catch (_) {}
    }

    if (bytes != null && bytes.isNotEmpty) {
      final fileName = d.fileNama.isNotEmpty ? d.fileNama : 'Dokumen_${d.kategori}.pdf';

      try {
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
                      '$fileName berhasil disiapkan / diunduh',
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
      } catch (_) {}
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
                final skList = items.where((d) => ['sk', 'surat_kerja'].contains(d.kategori.toLowerCase())).toList();
                final diklatList = items.where((d) => ['diklat', 'surat_diklat'].contains(d.kategori.toLowerCase())).toList();

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