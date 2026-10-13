import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feature_scaffold.dart';

enum JenisLampiran { foto, dokumen, video, voice }

class _LampiranItem {
  final int nomor;
  final String label;
  final String folderLabel;
  final String fileName;
  final String url;
  final bool isImage;
  final JenisLampiran jenis;

  _LampiranItem({
    required this.nomor,
    required this.label,
    required this.folderLabel,
    required this.fileName,
    required this.url,
    required this.isImage,
    required this.jenis,
  });
}

class SuratDetailPengaduanScreen extends StatefulWidget {
  final AppUser user;
  final int pengaduanId;
  final Pengaduan? initialPengaduan;

  const SuratDetailPengaduanScreen({
    super.key,
    required this.user,
    required this.pengaduanId,
    this.initialPengaduan,
  });

  @override
  State<SuratDetailPengaduanScreen> createState() =>
      _SuratDetailPengaduanScreenState();
}

class _SuratDetailPengaduanScreenState
    extends State<SuratDetailPengaduanScreen> {
  static const Color navy = Color(0xFF0D2C6E);

  Pengaduan? _pengaduan;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _pengaduan = widget.initialPengaduan;
    _muatDataPengaduan();
  }

  Future<void> _muatDataPengaduan() async {
    setState(() {
      _isLoading = _pengaduan == null;
      _errorMessage = null;
    });

    try {
      final p = await PengaduanService.detailLengkap(widget.pengaduanId);
      if (mounted) {
        if (p != null) {
          setState(() {
            _pengaduan = p;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Data pengaduan tidak ditemukan.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data realtime: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unduhPdf() async {
    if (_isGeneratingPdf) return;

    setState(() => _isGeneratingPdf = true);

    try {
      // Selalu ambil status & isi pengaduan paling update sebelum membuat PDF
      final freshPengaduan =
          await PengaduanService.detailLengkap(widget.pengaduanId);
      final p = freshPengaduan ?? _pengaduan;

      if (p == null) {
        throw Exception('Data pengaduan tidak tersedia untuk dibuatkan PDF.');
      }

      if (mounted && freshPengaduan != null) {
        setState(() => _pengaduan = freshPengaduan);
      }

      final bytes = await _buatDokumenPdf(p);
      final safeNo = p.nomorPengaduan.replaceAll(RegExp(r'[/\\]'), '_');
      final fileName = 'Surat_Pengaduan_$safeNo.pdf';

      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat atau mengunduh PDF: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  bool _isImageFile(String url) {
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.bmp') ||
        clean.endsWith('.heic');
  }

  String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return Uri.decodeComponent(segments.last);
      }
    } catch (_) {}
    return url;
  }

  List<_LampiranItem> _kumpulkanLampiran(Pengaduan p) {
    final list = <_LampiranItem>[];
    int counter = 1;

    // 1. Foto Bukti Pelapor
    for (int i = 0; i < p.fotoBukti.length; i++) {
      final url = p.fotoBukti[i];
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Foto Bukti Pelapor #${i + 1}',
        folderLabel: 'foto_bukti',
        fileName: _extractFileName(url),
        url: url,
        isImage: _isImageFile(url),
        jenis: JenisLampiran.foto,
      ));
    }

    // 2. Dokumen Pendukung Pelapor
    for (int i = 0; i < p.dokumenPendukung.length; i++) {
      final url = p.dokumenPendukung[i];
      final isImg = _isImageFile(url);
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Dokumen Pendukung #${i + 1}',
        folderLabel: 'dokumen_pendukung',
        fileName: _extractFileName(url),
        url: url,
        isImage: isImg,
        jenis: isImg ? JenisLampiran.foto : JenisLampiran.dokumen,
      ));
    }

    // 3. Video Bukti Pelapor
    for (int i = 0; i < p.videoBukti.length; i++) {
      final url = p.videoBukti[i];
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Video Bukti Pelapor #${i + 1}',
        folderLabel: 'video_bukti',
        fileName: _extractFileName(url),
        url: url,
        isImage: false,
        jenis: JenisLampiran.video,
      ));
    }

    // 4. Voice Note Pelapor
    for (int i = 0; i < p.voiceNote.length; i++) {
      final url = p.voiceNote[i];
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Voice Note Pelapor #${i + 1}',
        folderLabel: 'voice_note',
        fileName: _extractFileName(url),
        url: url,
        isImage: false,
        jenis: JenisLampiran.voice,
      ));
    }

    // 5. Foto Hasil Investigasi
    for (int i = 0; i < p.investigasiFoto.length; i++) {
      final url = p.investigasiFoto[i];
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Foto Investigasi #${i + 1}',
        folderLabel: 'investigasi_foto',
        fileName: _extractFileName(url),
        url: url,
        isImage: _isImageFile(url),
        jenis: JenisLampiran.foto,
      ));
    }

    // 6. Dokumen Investigasi
    for (int i = 0; i < p.investigasiDokumen.length; i++) {
      final url = p.investigasiDokumen[i];
      final isImg = _isImageFile(url);
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Dokumen Investigasi #${i + 1}',
        folderLabel: 'investigasi_dokumen',
        fileName: _extractFileName(url),
        url: url,
        isImage: isImg,
        jenis: isImg ? JenisLampiran.foto : JenisLampiran.dokumen,
      ));
    }

    // 7. Video Investigasi
    for (int i = 0; i < p.investigasiVideo.length; i++) {
      final url = p.investigasiVideo[i];
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Video Investigasi #${i + 1}',
        folderLabel: 'investigasi_video',
        fileName: _extractFileName(url),
        url: url,
        isImage: false,
        jenis: JenisLampiran.video,
      ));
    }

    // 8. Voice Note Investigasi
    for (int i = 0; i < p.investigasiVoice.length; i++) {
      final url = p.investigasiVoice[i];
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Voice Note Investigasi #${i + 1}',
        folderLabel: 'investigasi_voice',
        fileName: _extractFileName(url),
        url: url,
        isImage: false,
        jenis: JenisLampiran.voice,
      ));
    }

    return list;
  }

  Future<Uint8List> _buatDokumenPdf(Pengaduan p) async {
    final pdf = pw.Document();

    const pdfNavy = PdfColor.fromInt(0xFF0D2C6E);
    const pdfDark = PdfColor.fromInt(0xFF1E293B);
    const pdfGrey = PdfColor.fromInt(0xFF64748B);
    const pdfLightBg = PdfColor.fromInt(0xFFF8FAFC);
    const pdfBorder = PdfColor.fromInt(0xFFCBD5E1);

    final lampiranList = _kumpulkanLampiran(p);

    // Unduh bytes gambar jika ada (termasuk dokumen yang merupakan berkas gambar .jpg/.png)
    final downloadedImages = <int, Uint8List?>{};
    for (final item in lampiranList) {
      if (item.isImage && item.url.isNotEmpty) {
        try {
          final res = await http
              .get(Uri.parse(item.url))
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            downloadedImages[item.nomor] = res.bodyBytes;
          } else {
            downloadedImages[item.nomor] = null;
          }
        } catch (_) {
          downloadedImages[item.nomor] = null;
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return [
            // Kop Surat Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'PERUMDAM TIRTA DARMA AYU',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfNavy,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'SURAT DETAIL PENGADUAN PEGAWAI',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfDark,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Nomor: ${p.nomorPengaduan}',
                    style: const pw.TextStyle(fontSize: 10, color: pdfGrey),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: pdfNavy, thickness: 1.5),
            pw.SizedBox(height: 12),

            // Section 1: Informasi Pengaduan
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: pdfLightBg,
                border: pw.Border.all(color: pdfBorder),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfBarisInfo('Nomor Pengaduan', p.nomorPengaduan),
                  _pdfBarisInfo(
                    'Tanggal Pengaduan',
                    formatTanggalIndonesia(p.tanggalPengaduan),
                  ),
                  _pdfBarisInfo('Kategori', p.kategori),
                  _pdfBarisInfo('Status Terkini', p.status.label),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Section 2: Identitas Pelapor & Terlapor
            pw.Text(
              'IDENTITAS PELAPOR & TERLAPOR',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: pdfNavy,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: pdfBorder, width: 0.8),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: pdfLightBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Identitas Pelapor',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfNavy,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Identitas Terlapor',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nama: ${p.namaPegawai}',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('NIK: ${p.nik}',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(
                              'Golongan: ${p.golongan.isNotEmpty ? p.golongan : "-"}',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(
                              'Divisi/Unit: ${p.cabang.isNotEmpty ? p.cabang : "-"}',
                              style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nama: ${p.pihakTerlapor ?? "-"}',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('NIK: ${p.nikPelaku ?? "-"}',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Jabatan: ${p.jabatanPelaku ?? "-"}',
                              style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Section 3: Uraian Pengaduan
            pw.Text(
              'URAIAN PENGADUAN',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: pdfNavy,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: pdfBorder),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    p.judul,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfDark,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    p.deskripsi,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Section 4: Riwayat Status Pengaduan
            pw.Text(
              'RIWAYAT STATUS PENGADUAN',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: pdfNavy,
              ),
            ),
            pw.SizedBox(height: 6),
            if (p.riwayatStatus.isEmpty)
              pw.Text('Belum ada riwayat status.',
                  style: const pw.TextStyle(fontSize: 9, color: pdfGrey))
            else
              pw.Table(
                border: pw.TableBorder.all(color: pdfBorder, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.2),
                  1: pw.FlexColumnWidth(3),
                  2: pw.FlexColumnWidth(2.5),
                  3: pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: pdfLightBg),
                    children: [
                      _pdfHeaderTabel('Tanggal & Waktu'),
                      _pdfHeaderTabel('Status / Aksi'),
                      _pdfHeaderTabel('Petugas'),
                      _pdfHeaderTabel('Keterangan'),
                    ],
                  ),
                  ...p.riwayatStatus.map((h) {
                    final petugas =
                        '${h.oleh}${h.role != null ? " (${h.role!.label})" : ""}';
                    return pw.TableRow(
                      children: [
                        _pdfSelTabel(formatTanggalJam(h.tanggal)),
                        _pdfSelTabel(h.aksi),
                        _pdfSelTabel(petugas),
                        _pdfSelTabel(h.keterangan ?? '-'),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 18),

            // Section 5: Lampiran Bukti Pengaduan
            pw.Text(
              'LAMPIRAN BUKTI PENGADUAN',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: pdfNavy,
              ),
            ),
            pw.SizedBox(height: 6),
            if (lampiranList.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdfBorder),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text(
                  'Tidak ada lampiran',
                  style: const pw.TextStyle(fontSize: 9.5, color: pdfGrey),
                ),
              )
            else
              ...lampiranList.map((item) {
                final bytes = downloadedImages[item.nomor];
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: pdfBorder),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Lampiran #${item.nomor}: ${item.label}',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: pdfNavy,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Folder: ${item.folderLabel} | Berkas: ${item.fileName}',
                        style: const pw.TextStyle(fontSize: 8.5, color: pdfGrey),
                      ),
                      pw.SizedBox(height: 6),
                      if (item.isImage)
                        if (bytes != null)
                          pw.Center(
                            child: pw.Image(
                              pw.MemoryImage(bytes),
                              height: 220,
                              fit: pw.BoxFit.contain,
                            ),
                          )
                        else
                          pw.Container(
                            height: 50,
                            alignment: pw.Alignment.center,
                            color: pdfLightBg,
                            child: pw.Text(
                              'Gambar gagal dimuat: ${item.fileName}',
                              style: const pw.TextStyle(
                                fontSize: 8.5,
                                color: pdfGrey,
                              ),
                            ),
                          )
                      else
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          color: pdfLightBg,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Berkas (${item.jenis.name.toUpperCase()}): ${item.fileName}',
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: pdfDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Tautan: ${item.url}',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: pdfGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfBarisInfo(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xFF64748B),
              ),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfHeaderTabel(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0D2C6E),
        ),
      ),
    );
  }

  pw.Widget _pdfSelTabel(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _pengaduan;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FeatureScaffold(
      title: 'Surat Detail Pengaduan',
      subtitle: 'Tampilan resmi detail pengaduan & bukti',
      icon: Icons.description_outlined,
      trailing: IconButton(
        onPressed: _muatDataPengaduan,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        tooltip: 'Perbarui Data',
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBody(context, p, isDark),
        bottomNavigationBar: p == null
            ? null
            : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  border: Border(
                    top: BorderSide(color: AppColors.divider(context)),
                  ),
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _unduhPdf,
                      icon: _isGeneratingPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                      label: Text(
                        _isGeneratingPdf ? 'Membuat PDF...' : 'Unduh PDF',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Pengaduan? p, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Mengambil data surat realtime...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _muatDataPengaduan,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (p == null) return const SizedBox.shrink();

    final lampiranList = _kumpulkanLampiran(p);

    return RefreshIndicator(
      onRefresh: _muatDataPengaduan,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header / Kop Surat
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: navy,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'PERUMDAM TIRTA DARMA AYU',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'SURAT DETAIL PENGADUAN PEGAWAI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No. Pengaduan: ${p.nomorPengaduan}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1.5, color: navy),
                const SizedBox(height: 18),

                // Section 1: Ringkasan Pengaduan
                _buildJudulSeksyen('INFORMASI PENGADUAN'),
                const SizedBox(height: 8),
                _buildBarisInfo(
                  context,
                  'Tanggal Pengaduan',
                  formatTanggalIndonesia(p.tanggalPengaduan),
                ),
                _buildBarisInfo(context, 'Kategori', p.kategori),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(
                          'Status Terkini',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                      const Text(' :  ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: p.status.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            p.status.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: p.status.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Section 2: Identitas Pelapor & Terlapor
                _buildJudulSeksyen('IDENTITAS PELAPOR & TERLAPOR'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildKotakIdentitas(
                        context,
                        judul: 'Pelapor',
                        items: [
                          'Nama: ${p.namaPegawai}',
                          'NIK: ${p.nik}',
                          'Golongan: ${p.golongan.isNotEmpty ? p.golongan : "-"}',
                          'Divisi/Unit: ${p.cabang.isNotEmpty ? p.cabang : "-"}',
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKotakIdentitas(
                        context,
                        judul: 'Terlapor (Diadukan)',
                        items: [
                          'Nama: ${p.pihakTerlapor ?? "-"}',
                          'NIK: ${p.nikPelaku ?? "-"}',
                          'Jabatan: ${p.jabatanPelaku ?? "-"}',
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Section 3: Uraian Pengaduan
                _buildJudulSeksyen('URAIAN PENGADUAN'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.judul,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.deskripsi,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Section 4: Riwayat Status Pengaduan
                _buildJudulSeksyen('RIWAYAT STATUS PENGADUAN'),
                const SizedBox(height: 8),
                if (p.riwayatStatus.isEmpty)
                  Text(
                    'Belum ada riwayat status.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: p.riwayatStatus.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final h = p.riwayatStatus[index];
                      final petugas =
                          '${h.oleh}${h.role != null ? " (${h.role!.label})" : ""}';
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.divider(context), width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatTanggalJam(h.tanggal),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: navy,
                                  ),
                                ),
                                Text(
                                  petugas,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              h.aksi,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            if (h.keterangan != null &&
                                h.keterangan!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Catatan: ${h.keterangan}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 22),

                // Section 5: Lampiran Bukti Pengaduan
                _buildJudulSeksyen('LAMPIRAN BUKTI PENGADUAN'),
                const SizedBox(height: 8),
                if (lampiranList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.attachment_rounded,
                            color: AppColors.textSecondary(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Tidak ada lampiran',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lampiranList
                        .map((item) => _buildAttachmentCard(context, item))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(BuildContext context, _LampiranItem item) {
    IconData iconData;
    String actionText;
    Color themeColor = navy;

    switch (item.jenis) {
      case JenisLampiran.video:
        iconData = Icons.play_circle_fill_rounded;
        actionText = 'Putar / Unduh Video';
        themeColor = const Color(0xFFD35400);
        break;
      case JenisLampiran.voice:
        iconData = Icons.audiotrack_rounded;
        actionText = 'Putar / Unduh Voice Note';
        themeColor = const Color(0xFF8E44AD);
        break;
      case JenisLampiran.dokumen:
        iconData = Icons.insert_drive_file_rounded;
        actionText = 'Buka / Unduh Dokumen';
        themeColor = const Color(0xFF2E86AB);
        break;
      case JenisLampiran.foto:
        iconData = Icons.open_in_new_rounded;
        actionText = 'Buka Foto Ukuran Penuh';
        themeColor = navy;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Lampiran #${item.nomor}: ${item.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Folder: ${item.folderLabel}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Nama Berkas: ${item.fileName}',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          if (item.isImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.url,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    width: double.infinity,
                    color: AppColors.card(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textSecondary(context),
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gambar gagal dimuat',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final uri = Uri.parse(item.url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal membuka berkas: $e')),
                    );
                  }
                }
              },
              icon: Icon(iconData, size: 16),
              label: Text(actionText, style: const TextStyle(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: themeColor,
                side: BorderSide(color: themeColor.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJudulSeksyen(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: navy,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildBarisInfo(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          const Text(' :  ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKotakIdentitas(
    BuildContext context, {
    required String judul,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider(context), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
