import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../utils/lampiran_helper.dart';
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
  @visibleForTesting
  final void Function(Uint8List pdfBytes)? onPdfGeneratedForTest;

  const SuratDetailPengaduanScreen({
    super.key,
    required this.user,
    required this.pengaduanId,
    this.initialPengaduan,
    this.onPdfGeneratedForTest,
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
  bool _isPreviewingPdf = false;

  bool _tampilkanInfoPelapor(Pengaduan p) {
    if (p.anonim) return false;

    final userNik = widget.user.nik.trim();
    final userName = widget.user.name.trim().toLowerCase();

    // Pihak yang dilaporkan (terlapor) tidak boleh melihat identitas pelapor
    final nikPelaku = (p.nikPelaku ?? '').trim();
    final namaPelaku = (p.pihakTerlapor ?? '').trim().toLowerCase();
    final isTerlapor = (nikPelaku.isNotEmpty && userNik == nikPelaku) ||
        (namaPelaku.isNotEmpty && userName == namaPelaku);
    if (isTerlapor) return false;

    // Hanya KSPI dan Kadiv Kategori (Administrasi & Teknik) yang bisa melihat pelapor
    final isKspi = widget.user.role == UserRole.kspi ||
        widget.user.nik == '1711161' ||
        widget.user.name.toLowerCase().contains('dodi');
    final isKadivKategori = widget.user.role == UserRole.kadivKategori;

    return isKspi || isKadivKategori;
  }

  @override
  void initState() {
    super.initState();
    _pengaduan = widget.initialPengaduan;
    _muatDataPengaduan();
  }

  Future<void> _muatDataPengaduan({bool showRefreshToast = false}) async {
    setState(() {
      _isLoading = _pengaduan == null;
      _errorMessage = null;
    });

    try {
      final p = await PengaduanService.detailLengkap(widget.pengaduanId);
      if (!mounted) return;
      if (p != null) {
        setState(() {
          _pengaduan = p;
          _isLoading = false;
          _errorMessage = null;
        });
        if (showRefreshToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Data surat pengaduan berhasil diperbarui.'),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        setState(() {
          if (_pengaduan == null) {
            _errorMessage = 'Data pengaduan tidak ditemukan.';
          }
          _isLoading = false;
        });
        if (_pengaduan != null && showRefreshToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat memperbarui data dari server.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_pengaduan == null) {
          _errorMessage = 'Gagal memuat data realtime: $e';
        }
        _isLoading = false;
      });
      if (_pengaduan != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui data: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _prosesPdf({required bool previewOnly}) async {
    if (_isGeneratingPdf || _isPreviewingPdf) return;

    setState(() {
      if (previewOnly) {
        _isPreviewingPdf = true;
      } else {
        _isGeneratingPdf = true;
      }
    });

    try {
      // Ambil pembaruan status pengaduan terbaik dengan batas waktu singkat
      // agar tombol Unduh / Pratinjau PDF tidak macet saat jaringan lambat.
      Pengaduan? freshPengaduan;
      try {
        freshPengaduan = await PengaduanService.detailLengkap(widget.pengaduanId)
            .timeout(
          Duration(seconds: _pengaduan != null ? 3 : 8),
          onTimeout: () => null,
        );
      } catch (_) {}
      final p = freshPengaduan ?? _pengaduan;

      if (p == null) {
        throw Exception('Data pengaduan tidak tersedia untuk dibuatkan PDF.');
      }

      if (mounted && freshPengaduan != null) {
        setState(() => _pengaduan = freshPengaduan);
      }

      final bytes = await _buatDokumenPdf(p);
      widget.onPdfGeneratedForTest?.call(bytes);
      final safeNo = p.nomorPengaduan.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final fileName = 'Surat_Pengaduan_$safeNo.pdf';

      final ok = previewOnly
          ? await LampiranHelper.openBytesInViewer(
              bytes,
              fileName,
              'application/pdf',
            )
          : await LampiranHelper.downloadBytes(
              bytes,
              fileName,
              'application/pdf',
            );

      if (mounted) {
        if (ok) {
          if (!previewOnly) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF $fileName berhasil diunduh.'),
                backgroundColor: const Color(0xFF27AE60),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(previewOnly
                  ? 'Pratinjau PDF tidak dapat dibuka di perangkat ini.'
                  : 'Gagal mengunduh PDF $fileName.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
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
        setState(() {
          _isGeneratingPdf = false;
          _isPreviewingPdf = false;
        });
      }
    }
  }

  /// Membersihkan teks dari karakter Unicode yang tidak didukung oleh font
  /// Helvetica bawaan paket PDF agar tidak muncul missing glyph.
  String _sanitizePdfText(String? input, {String defaultValue = ''}) {
    if (input == null || input.trim().isEmpty) return defaultValue;
    final sanitized = input
        .replaceAll('•', '-')
        .replaceAll('·', '-')
        .replaceAll('●', '-')
        .replaceAll('○', '-')
        .replaceAll('■', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('„', '"')
        .replaceAll('«', '"')
        .replaceAll('»', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('‚', "'")
        .replaceAll('`', "'")
        .replaceAll('…', '...')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('✓', '[V]')
        .replaceAll('✔', '[V]')
        .replaceAll('✗', '[X]')
        .replaceAll('✘', '[X]')
        .replaceAll('★', '*')
        .replaceAll('☆', '*')
        .replaceAll(RegExp(r'[^\x00-\x7F\u00A0-\u00FF]'), ' ')
        .trim();
    return sanitized.isEmpty ? defaultValue : sanitized;
  }

  JenisLampiran _tentukanJenis(String url, {required JenisLampiran defaultJenis}) {
    if (LampiranHelper.isImageUrl(url)) return JenisLampiran.foto;
    if (LampiranHelper.isVideoUrl(url)) return JenisLampiran.video;
    if (LampiranHelper.isAudioUrl(url)) return JenisLampiran.voice;
    if (LampiranHelper.isPdfUrl(url) ||
        LampiranHelper.isWordUrl(url) ||
        LampiranHelper.isExcelUrl(url) ||
        LampiranHelper.isTextDocUrl(url)) {
      return JenisLampiran.dokumen;
    }
    return defaultJenis;
  }

  List<_LampiranItem> _kumpulkanLampiran(Pengaduan p) {
    final list = <_LampiranItem>[];
    int counter = 1;

    void tambahDaftar(
      List<String> urls, {
      required String labelPrefix,
      required String folderLabel,
      required String fallbackPrefix,
      required JenisLampiran defaultJenis,
    }) {
      for (int i = 0; i < urls.length; i++) {
        final raw = urls[i].trim();
        if (raw.isEmpty) continue;
        final jenis = _tentukanJenis(raw, defaultJenis: defaultJenis);
        final isImg = jenis == JenisLampiran.foto;
        list.add(_LampiranItem(
          nomor: counter++,
          label: '$labelPrefix #${i + 1}',
          folderLabel: folderLabel,
          fileName: LampiranHelper.extractFileName(
            raw,
            fallback: '${fallbackPrefix}_${i + 1}',
          ),
          url: raw,
          isImage: isImg,
          jenis: jenis,
        ));
      }
    }

    tambahDaftar(
      p.fotoBukti,
      labelPrefix: 'Foto Bukti Pelapor',
      folderLabel: 'foto_bukti',
      fallbackPrefix: 'Foto_Bukti',
      defaultJenis: JenisLampiran.foto,
    );
    tambahDaftar(
      p.dokumenPendukung,
      labelPrefix: 'Dokumen Pendukung',
      folderLabel: 'dokumen_pendukung',
      fallbackPrefix: 'Dokumen_Pendukung',
      defaultJenis: JenisLampiran.dokumen,
    );
    tambahDaftar(
      p.videoBukti,
      labelPrefix: 'Video Bukti Pelapor',
      folderLabel: 'video_bukti',
      fallbackPrefix: 'Video_Bukti',
      defaultJenis: JenisLampiran.video,
    );
    tambahDaftar(
      p.voiceNote,
      labelPrefix: 'Voice Note Pelapor',
      folderLabel: 'voice_note',
      fallbackPrefix: 'Voice_Note',
      defaultJenis: JenisLampiran.voice,
    );
    final rounds = p.daftarHasilInvestigasi;
    if (rounds.isNotEmpty) {
      final seenUrls = <String>{};
      for (final r in rounds) {
        final pTag = 'P${r.tahapKe}';
        void addRoundList(
          List<String> urls, {
          required String labelPrefix,
          required String folderSuffix,
          required String fallbackPrefix,
          required JenisLampiran defaultJenis,
        }) {
          final unique = <String>[];
          for (final u in urls) {
            final clean = u.trim();
            if (clean.isEmpty || seenUrls.contains(clean)) continue;
            seenUrls.add(clean);
            unique.add(clean);
          }
          if (unique.isEmpty) return;
          tambahDaftar(
            unique,
            labelPrefix: '$labelPrefix ($pTag)',
            folderLabel: '$pTag/$folderSuffix',
            fallbackPrefix: '${fallbackPrefix}_$pTag',
            defaultJenis: defaultJenis,
          );
        }

        addRoundList(
          r.investigasiFoto,
          labelPrefix: 'Foto Investigasi',
          folderSuffix: 'investigasi_foto',
          fallbackPrefix: 'Foto_Investigasi',
          defaultJenis: JenisLampiran.foto,
        );
        addRoundList(
          r.investigasiDokumen,
          labelPrefix: 'Dokumen Investigasi',
          folderSuffix: 'investigasi_dokumen',
          fallbackPrefix: 'Dokumen_Investigasi',
          defaultJenis: JenisLampiran.dokumen,
        );
        addRoundList(
          r.investigasiVideo,
          labelPrefix: 'Video Investigasi',
          folderSuffix: 'investigasi_video',
          fallbackPrefix: 'Video_Investigasi',
          defaultJenis: JenisLampiran.video,
        );
        addRoundList(
          r.investigasiVoice,
          labelPrefix: 'Voice Note Investigasi',
          folderSuffix: 'investigasi_voice',
          fallbackPrefix: 'Voice_Note_Investigasi',
          defaultJenis: JenisLampiran.voice,
        );
      }
    } else {
      tambahDaftar(
        p.investigasiFoto,
        labelPrefix: 'Foto Investigasi',
        folderLabel: 'investigasi_foto',
        fallbackPrefix: 'Foto_Investigasi',
        defaultJenis: JenisLampiran.foto,
      );
      tambahDaftar(
        p.investigasiDokumen,
        labelPrefix: 'Dokumen Investigasi',
        folderLabel: 'investigasi_dokumen',
        fallbackPrefix: 'Dokumen_Investigasi',
        defaultJenis: JenisLampiran.dokumen,
      );
      tambahDaftar(
        p.investigasiVideo,
        labelPrefix: 'Video Investigasi',
        folderLabel: 'investigasi_video',
        fallbackPrefix: 'Video_Investigasi',
        defaultJenis: JenisLampiran.video,
      );
      tambahDaftar(
        p.investigasiVoice,
        labelPrefix: 'Voice Note Investigasi',
        folderLabel: 'investigasi_voice',
        fallbackPrefix: 'Voice_Note_Investigasi',
        defaultJenis: JenisLampiran.voice,
      );
    }

    final filePutusan = (p.fileSuratPutusan ?? '').trim();
    if (filePutusan.isNotEmpty) {
      final jenis = _tentukanJenis(filePutusan, defaultJenis: JenisLampiran.dokumen);
      list.add(_LampiranItem(
        nomor: counter++,
        label: 'Surat Putusan Sanksi SDM',
        folderLabel: 'surat_putusan',
        fileName: LampiranHelper.extractFileName(
          filePutusan,
          fallback: 'Surat_Putusan_Sanksi',
        ),
        url: filePutusan,
        isImage: jenis == JenisLampiran.foto,
        jenis: jenis,
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

    // Siapkan seluruh konten lampiran (gambar, halaman PDF ter-raster, maupun isi teks dokumen)
    // sebelum menyusun halaman PDF agar Lampiran #2 dan seterusnya ikut menampilkan isinya.
    final preparedAttachments = <int, _PdfPreparedAttachment>{};
    for (final item in lampiranList) {
      preparedAttachments[item.nomor] = await _preparePdfAttachment(item);
    }

    final investigasiRounds = p.daftarHasilInvestigasi;
    final bool adaHasilAtauPutusan = investigasiRounds.isNotEmpty ||
        (p.nomorSuratPutusan != null &&
            p.nomorSuratPutusan!.trim().isNotEmpty) ||
        (p.jenisSanksi != null && p.jenisSanksi!.trim().isNotEmpty) ||
        (p.catatanSdm != null && p.catatanSdm!.trim().isNotEmpty);

    // Pecah uraian deskripsi per paragraf agar MultiPage aman untuk teks panjang
    final deskripsiLines = _sanitizePdfText(p.deskripsi, defaultValue: '-')
        .split('\n')
        .map((e) => e.trimRight())
        .toList();

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
                    'Nomor: ${_sanitizePdfText(p.nomorPengaduan)}',
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
                  _pdfBarisInfo('Status Terkini', p.statusTampilLabel),
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
                          pw.Text(
                            'Nama: ${_tampilkanInfoPelapor(p) ? _sanitizePdfText(p.namaPegawai) : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'NIK: ${_tampilkanInfoPelapor(p) ? _sanitizePdfText(p.nik) : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Golongan: ${_tampilkanInfoPelapor(p) ? _sanitizePdfText(p.golongan, defaultValue: "-") : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Unit Kerja: ${_tampilkanInfoPelapor(p) ? _sanitizePdfText(p.cabang, defaultValue: "-") : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Nama: ${_sanitizePdfText(p.pihakTerlapor, defaultValue: "-")}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'NIK: ${_sanitizePdfText(p.nikPelaku, defaultValue: "-")}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Jabatan: ${_sanitizePdfText(p.jabatanPelaku, defaultValue: "-")}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const pw.BoxDecoration(
                color: pdfLightBg,
                border: pw.Border(
                  left: pw.BorderSide(color: pdfNavy, width: 2.5),
                ),
              ),
              child: pw.Text(
                _sanitizePdfText(p.judul, defaultValue: '-'),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfDark,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            ...deskripsiLines.map(
              (line) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3, left: 4, right: 4),
                child: pw.Text(
                  line.isEmpty ? ' ' : line,
                  style: const pw.TextStyle(fontSize: 9, color: pdfDark),
                ),
              ),
            ),
            pw.SizedBox(height: 14),

            // Section Hasil Investigasi & Putusan Sanksi (jika ada)
            if (adaHasilAtauPutusan) ...[
              pw.Text(
                'HASIL INVESTIGASI & PUTUSAN SANKSI',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: pdfNavy,
                ),
              ),
              pw.SizedBox(height: 6),
              if ((p.nomorSuratPutusan != null &&
                      p.nomorSuratPutusan!.trim().isNotEmpty) ||
                  (p.jenisSanksi != null && p.jenisSanksi!.trim().isNotEmpty) ||
                  (p.catatanSdm != null && p.catatanSdm!.trim().isNotEmpty))
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: pdfLightBg,
                    border: pw.Border.all(color: pdfBorder),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (p.nomorSuratPutusan != null &&
                          p.nomorSuratPutusan!.trim().isNotEmpty)
                        _pdfBarisInfo(
                            'No. Surat Putusan', p.nomorSuratPutusan!),
                      if (p.jenisSanksi != null &&
                          p.jenisSanksi!.trim().isNotEmpty)
                        _pdfBarisInfo('Jenis Sanksi', p.jenisSanksi!),
                      if (p.catatanSdm != null &&
                          p.catatanSdm!.trim().isNotEmpty)
                        _pdfBarisInfo('Catatan SDM', p.catatanSdm!),
                    ],
                  ),
                ),
              ...investigasiRounds.map((r) {
                final buktiItems = <String>[
                  if (r.investigasiFoto.isNotEmpty)
                    '${r.investigasiFoto.length} Foto',
                  if (r.investigasiDokumen.isNotEmpty)
                    '${r.investigasiDokumen.length} Dokumen',
                  if (r.investigasiVideo.isNotEmpty)
                    '${r.investigasiVideo.length} Video',
                  if (r.investigasiVoice.isNotEmpty)
                    '${r.investigasiVoice.length} Voice',
                ];
                return pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: pdfLightBg,
                    border: pw.Border.all(color: pdfBorder),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfBarisInfo('Tahap Investigasi', r.labelTahap),
                      if (r.tanggal != null)
                        _pdfBarisInfo(
                            'Waktu Kirim', formatTanggalJam(r.tanggal!)),
                      if (r.isTerbukti || r.isTidakTerbukti)
                        _pdfBarisInfo(
                          'Kesimpulan',
                          r.isTerbukti ? 'TERBUKTI' : 'TIDAK TERBUKTI',
                        ),
                      if (r.petugasInvestigasi != null &&
                          r.petugasInvestigasi!.trim().isNotEmpty)
                        _pdfBarisInfo(
                            'Tim Investigator', r.petugasInvestigasi!),
                      if (r.catatanPeninjauanKembali != null &&
                          r.catatanPeninjauanKembali!.trim().isNotEmpty)
                        _pdfBarisInfo('Instruksi Dirut (PK)',
                            r.catatanPeninjauanKembali!),
                      if (r.hasilInvestigasi != null &&
                          r.hasilInvestigasi!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Temuan / Hasil Investigasi:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfNavy,
                          ),
                        ),
                        ..._sanitizePdfText(r.hasilInvestigasi,
                                defaultValue: '-')
                            .split('\n')
                            .map(
                              (line) => pw.Padding(
                                padding: const pw.EdgeInsets.only(
                                    bottom: 2, left: 4),
                                child: pw.Text(
                                  line.trim().isEmpty ? ' ' : line,
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: pdfDark),
                                ),
                              ),
                            ),
                      ],
                      if (r.suratRekomendasi != null &&
                          r.suratRekomendasi!.trim().isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Surat Rekomendasi:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfNavy,
                          ),
                        ),
                        ..._sanitizePdfText(r.suratRekomendasi,
                                defaultValue: '-')
                            .split('\n')
                            .map(
                              (line) => pw.Padding(
                                padding: const pw.EdgeInsets.only(
                                    bottom: 2, left: 4),
                                child: pw.Text(
                                  line.trim().isEmpty ? ' ' : line,
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: pdfDark),
                                ),
                              ),
                            ),
                      ],
                      if (buktiItems.isNotEmpty)
                        _pdfBarisInfo(
                            'Bukti Lampiran', buktiItems.join(', ')),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 6),
            ],

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
                    final bool isPelakuAuto = h.keterangan != null &&
                        h.keterangan!.trim().startsWith('Pelaku diadukan:');
                    final ket = isPelakuAuto
                        ? '-'
                        : (h.keterangan != null &&
                                h.keterangan!.trim().isNotEmpty
                            ? h.keterangan!
                            : '-');
                    return pw.TableRow(
                      children: [
                        _pdfSelTabel(formatTanggalJam(h.tanggal)),
                        _pdfSelTabel(h.aksi),
                        _pdfSelTabel(petugas),
                        _pdfSelTabel(ket),
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
              for (final item in lampiranList)
                ..._buildPdfAttachmentWidgets(
                  item,
                  preparedAttachments[item.nomor] ??
                      const _PdfPreparedAttachment(isDataUri: false),
                  pdfNavy: pdfNavy,
                  pdfDark: pdfDark,
                  pdfGrey: pdfGrey,
                  pdfLightBg: pdfLightBg,
                  pdfBorder: pdfBorder,
                ),
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
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              _sanitizePdfText(label),
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xFF64748B),
              ),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
            child: pw.Text(
              _sanitizePdfText(value),
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
        _sanitizePdfText(text),
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
      child: pw.Text(_sanitizePdfText(text), style: const pw.TextStyle(fontSize: 8)),
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
        onPressed: () => _muatDataPengaduan(showRefreshToast: true),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: (_isGeneratingPdf || _isPreviewingPdf)
                                ? null
                                : () => _prosesPdf(previewOnly: true),
                            icon: _isPreviewingPdf
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.visibility_rounded,
                                    size: 19),
                            label: Text(
                              _isPreviewingPdf ? 'Membuka...' : 'Pratinjau PDF',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: navy,
                              side: const BorderSide(color: navy, width: 1.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: (_isGeneratingPdf || _isPreviewingPdf)
                                ? null
                                : () => _prosesPdf(previewOnly: false),
                            icon: _isGeneratingPdf
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_rounded,
                                    size: 20),
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
                    ],
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
    final investigasiRounds = p.daftarHasilInvestigasi;
    final bool adaHasilAtauPutusan = investigasiRounds.isNotEmpty ||
        (p.nomorSuratPutusan != null &&
            p.nomorSuratPutusan!.trim().isNotEmpty) ||
        (p.jenisSanksi != null && p.jenisSanksi!.trim().isNotEmpty) ||
        (p.catatanSdm != null && p.catatanSdm!.trim().isNotEmpty);

    return RefreshIndicator(
      onRefresh: () => _muatDataPengaduan(showRefreshToast: true),
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
                        child: Align(
                          alignment: Alignment.centerLeft,
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
                          'Nama: ${_tampilkanInfoPelapor(p) ? p.namaPegawai : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
                          'NIK: ${_tampilkanInfoPelapor(p) ? p.nik : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
                          'Golongan: ${_tampilkanInfoPelapor(p) ? (p.golongan.isNotEmpty ? p.golongan : "-") : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
                          'Unit Kerja: ${_tampilkanInfoPelapor(p) ? (p.cabang.isNotEmpty ? p.cabang : "-") : (p.anonim ? "[Anonim]" : "[Dirahasiakan]")}',
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

                // Section Hasil Investigasi & Putusan Sanksi (jika ada)
                if (adaHasilAtauPutusan) ...[
                  _buildJudulSeksyen('HASIL INVESTIGASI & PUTUSAN SANKSI'),
                  const SizedBox(height: 8),
                  if ((p.nomorSuratPutusan != null &&
                          p.nomorSuratPutusan!.trim().isNotEmpty) ||
                      (p.jenisSanksi != null &&
                          p.jenisSanksi!.trim().isNotEmpty) ||
                      (p.catatanSdm != null && p.catatanSdm!.trim().isNotEmpty))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.nomorSuratPutusan != null &&
                              p.nomorSuratPutusan!.trim().isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'No. Surat Putusan',
                              p.nomorSuratPutusan!,
                            ),
                          if (p.jenisSanksi != null &&
                              p.jenisSanksi!.trim().isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'Jenis Sanksi',
                              p.jenisSanksi!,
                            ),
                          if (p.catatanSdm != null &&
                              p.catatanSdm!.trim().isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'Catatan SDM',
                              p.catatanSdm!,
                            ),
                        ],
                      ),
                    ),
                  ...investigasiRounds.map((r) {
                    final buktiItems = <String>[
                      if (r.investigasiFoto.isNotEmpty)
                        '${r.investigasiFoto.length} Foto',
                      if (r.investigasiDokumen.isNotEmpty)
                        '${r.investigasiDokumen.length} Dokumen',
                      if (r.investigasiVideo.isNotEmpty)
                        '${r.investigasiVideo.length} Video',
                      if (r.investigasiVoice.isNotEmpty)
                        '${r.investigasiVoice.length} Voice',
                    ];
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBarisInfo(
                            context,
                            'Tahap',
                            r.labelTahap,
                          ),
                          if (r.tanggal != null)
                            _buildBarisInfo(
                              context,
                              'Waktu Kirim',
                              formatTanggalJam(r.tanggal!),
                            ),
                          if (r.isTerbukti || r.isTidakTerbukti)
                            _buildBarisInfo(
                              context,
                              'Kesimpulan',
                              r.isTerbukti ? 'TERBUKTI' : 'TIDAK TERBUKTI',
                            ),
                          if (r.petugasInvestigasi != null &&
                              r.petugasInvestigasi!.trim().isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'Tim Investigator',
                              r.petugasInvestigasi!,
                            ),
                          if (r.catatanPeninjauanKembali != null &&
                              r.catatanPeninjauanKembali!.trim().isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'Instruksi Dirut (PK)',
                              r.catatanPeninjauanKembali!,
                            ),
                          if (r.hasilInvestigasi != null &&
                              r.hasilInvestigasi!.trim().isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'Hasil Investigasi',
                              r.hasilInvestigasi!,
                            ),
                          if (r.suratRekomendasi != null &&
                              r.suratRekomendasi!.trim().isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'Rekomendasi',
                              r.suratRekomendasi!,
                            ),
                          if (buktiItems.isNotEmpty)
                            _buildBarisInfo(
                              context,
                              'Bukti Lampiran',
                              buktiItems.join(', '),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatTanggalJam(h.tanggal),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: navy,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    petugas,
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _sanitizePdfText(h.aksi),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            if (h.keterangan != null &&
                                h.keterangan!.trim().isNotEmpty &&
                                !h.keterangan!
                                    .trim()
                                    .startsWith('Pelaku diadukan:')) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.card(context),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.divider(context),
                                    width: 0.7,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.comment_outlined,
                                      size: 13,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Catatan: ${_sanitizePdfText(h.keterangan)}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ),
                                  ],
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

  Future<void> _bukaItemLampiran(
    BuildContext context,
    _LampiranItem item,
  ) async {
    await LampiranHelper.bukaLampiran(
      context,
      item.url,
      fallbackName: item.fileName,
      forceImage: item.jenis == JenisLampiran.foto,
      forceVideo: item.jenis == JenisLampiran.video,
      forceAudio: item.jenis == JenisLampiran.voice,
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
              const SizedBox(width: 8),
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
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _bukaItemLampiran(context, item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LampiranHelper.buildImageWidget(
                  item.url,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            _InlineLampiranContentPreview(
              url: item.url,
              fileName: item.fileName,
              jenis: item.jenis,
              accentColor: themeColor,
              onOpenFull: () => _bukaItemLampiran(context, item),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _bukaItemLampiran(context, item),
              icon: Icon(iconData, size: 16),
              label: Text(actionText, style: const TextStyle(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: themeColor,
                side: BorderSide(color: themeColor.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
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

  Future<_PdfPreparedAttachment> _preparePdfAttachment(_LampiranItem item) async {
    final trimmed = item.url.trim();
    final isDataUri = trimmed.toLowerCase().startsWith('data:');
    final resolvedLink =
        isDataUri || trimmed.isEmpty ? null : LampiranHelper.resolveUrl(trimmed);

    if (trimmed.isEmpty) {
      return _PdfPreparedAttachment(
        isDataUri: isDataUri,
        resolvedLink: resolvedLink,
      );
    }

    Uint8List? bytes;
    try {
      bytes = await LampiranHelper.fetchBytes(
        trimmed,
        timeout: const Duration(seconds: 12),
      );
    } catch (_) {}

    if (bytes == null || bytes.isEmpty) {
      return _PdfPreparedAttachment(
        isDataUri: isDataUri,
        resolvedLink: resolvedLink,
      );
    }

    final mimeType = LampiranHelper.inferMimeType(trimmed, bytes: bytes);
    final isImage = item.isImage || LampiranHelper.isImageUrl(trimmed, bytes);

    if (isImage) {
      pw.MemoryImage? memImg;
      try {
        memImg = pw.MemoryImage(bytes);
      } catch (_) {}
      return _PdfPreparedAttachment(
        image: memImg,
        byteLength: bytes.length,
        isDataUri: isDataUri,
        resolvedLink: resolvedLink,
      );
    }

    if (LampiranHelper.isPdfUrl(trimmed, bytes)) {
      final pageImages = <pw.MemoryImage>[];
      final pageSizes = <({double width, double height})>[];
      final rasters = await LampiranHelper.rasterPdfPages(
        bytes,
        dpi: 145,
        maxPages: 25,
        timeout: const Duration(seconds: 20),
      );
      for (final r in rasters) {
        try {
          pageImages.add(pw.MemoryImage(r.pngBytes));
          pageSizes.add((
            width: r.width.toDouble(),
            height: r.height.toDouble(),
          ));
        } catch (_) {}
      }

      String? fallbackText;
      if (pageImages.isEmpty) {
        fallbackText = LampiranHelper.extractReadableDocumentText(
          bytes,
          item.fileName,
          mimeType: mimeType,
        );
      }

      return _PdfPreparedAttachment(
        pdfPages: pageImages,
        pdfPageSizes: pageSizes,
        extractedText: fallbackText,
        byteLength: bytes.length,
        isDataUri: isDataUri,
        resolvedLink: resolvedLink,
      );
    }

    String? extractedText;
    if (LampiranHelper.isReadableDocument(
      trimmed,
      fileName: item.fileName,
      bytes: bytes,
    )) {
      extractedText = LampiranHelper.extractReadableDocumentText(
        bytes,
        item.fileName,
        mimeType: mimeType,
      );
    }

    return _PdfPreparedAttachment(
      extractedText: extractedText,
      byteLength: bytes.length,
      isDataUri: isDataUri,
      resolvedLink: resolvedLink,
    );
  }

  List<pw.Widget> _buildPdfAttachmentWidgets(
    _LampiranItem item,
    _PdfPreparedAttachment data, {
    required PdfColor pdfNavy,
    required PdfColor pdfDark,
    required PdfColor pdfGrey,
    required PdfColor pdfLightBg,
    required PdfColor pdfBorder,
  }) {
    final sizeKb = data.byteLength != null
        ? (data.byteLength! / 1024).toStringAsFixed(1)
        : null;
    final widgets = <pw.Widget>[];

    // Header ringkasan lampiran (selalu tampil rapi di atas isi lampiran)
    widgets.add(
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: pdfLightBg,
          border: pw.Border.all(color: pdfBorder),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _sanitizePdfText('Lampiran #${item.nomor}: ${item.label}'),
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: pdfNavy,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _sanitizePdfText(
                'Folder: ${item.folderLabel} | Berkas (${item.jenis.name.toUpperCase()}): ${item.fileName}${sizeKb != null ? ' ($sizeKb KB)' : ''}',
              ),
              style: pw.TextStyle(fontSize: 8.5, color: pdfGrey),
            ),
            if (!data.isDataUri && (data.resolvedLink ?? item.url).isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                _sanitizePdfText(
                  'Tautan: ${(data.resolvedLink ?? item.url).length > 350 ? '${(data.resolvedLink ?? item.url).substring(0, 350)}...' : (data.resolvedLink ?? item.url)}',
                ),
                style: pw.TextStyle(fontSize: 7.5, color: pdfGrey),
              ),
            ],
          ],
        ),
      ),
    );

    if (item.isImage) {
      if (data.image != null) {
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pdfBorder),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Center(
              child: pw.Image(
                data.image!,
                height: 220,
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(10),
            color: pdfLightBg,
            child: pw.Text(
              _sanitizePdfText(
                'Gambar tidak dapat disisipkan: ${item.fileName}',
              ),
              style: pw.TextStyle(fontSize: 8.5, color: pdfGrey),
            ),
          ),
        );
      }
      return widgets;
    }

    // Jika lampiran berupa PDF yang berhasil dirasterisasi per halaman:
    // setiap halaman dipancarkan sebagai item MultiPage terpisah agar tidak overflow.
    if (data.pdfPages.isNotEmpty) {
      const double maxPageW = 495.0;
      const double maxPageH = 580.0;
      for (int i = 0; i < data.pdfPages.length; i++) {
        final rawSize = i < data.pdfPageSizes.length
            ? data.pdfPageSizes[i]
            : (width: maxPageW, height: maxPageH);
        final scale = (rawSize.width > 0 && rawSize.height > 0)
            ? math.min(maxPageW / rawSize.width, maxPageH / rawSize.height)
            : 1.0;
        final drawW =
            rawSize.width > 0 ? math.max(120.0, rawSize.width * scale) : maxPageW;
        final drawH =
            rawSize.height > 0 ? math.max(80.0, rawSize.height * scale) : maxPageH;

        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: pw.EdgeInsets.only(
              bottom: i == data.pdfPages.length - 1 ? 12 : 8,
            ),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: pdfBorder, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _sanitizePdfText(
                    'Isi Lampiran ${item.fileName} - Halaman ${i + 1} dari ${data.pdfPages.length}',
                  ),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: pdfNavy,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Image(
                    data.pdfPages[i],
                    width: drawW,
                    height: drawH,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return widgets;
    }

    // Jika dokumen berupa DOCX / XLSX / TXT / CSV / RTF atau hasil ekstraksi teks PDF
    final extracted = data.extractedText?.trim();
    if (extracted != null && extracted.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 2, bottom: 3),
          child: pw.Text(
            _sanitizePdfText('Isi Dokumen ${item.fileName}:'),
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: pdfNavy,
            ),
          ),
        ),
      );
      final rawLines = _sanitizePdfText(extracted).split('\n');
      const int maxPdfLines = 350;
      final emittedLines = rawLines.take(maxPdfLines).toList();
      for (int i = 0; i < emittedLines.length; i++) {
        final line = emittedLines[i];
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: pw.EdgeInsets.only(
              bottom: i == emittedLines.length - 1 && rawLines.length <= maxPdfLines
                  ? 12
                  : 0,
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              color: pdfLightBg,
              border: pw.Border(
                left: pw.BorderSide(color: pdfNavy, width: 2),
              ),
            ),
            child: pw.Text(
              line.trim().isEmpty ? ' ' : line,
              style: pw.TextStyle(fontSize: 8.5, color: pdfDark, lineSpacing: 1.5),
            ),
          ),
        );
      }
      if (rawLines.length > maxPdfLines) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3, bottom: 12),
            child: pw.Text(
              '... (${rawLines.length - maxPdfLines} baris lanjutan tersedia pada berkas asli)',
              style: pw.TextStyle(fontSize: 8, color: pdfGrey),
            ),
          ),
        );
      }
      return widgets;
    }

    // Fallback metadata untuk berkas biner (video/audio/.doc lama/gagal unduh)
    widgets.add(
      pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: pdfLightBg,
          border: pw.Border.all(color: pdfBorder, width: 0.7),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Text(
          _sanitizePdfText(
            data.isDataUri
                ? 'Berkas ${item.fileName}${sizeKb != null ? ' ($sizeKb KB)' : ''} tersimpan secara digital dan dapat dibuka langsung melalui aplikasi.'
                : 'Berkas ${item.fileName} tidak dapat dirender langsung di dalam PDF; buka tautan atau unduh berkas melalui aplikasi.',
          ),
          style: pw.TextStyle(fontSize: 8, color: pdfGrey),
        ),
      ),
    );
    return widgets;
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

class _PdfPreparedAttachment {
  final pw.MemoryImage? image;
  final List<pw.MemoryImage> pdfPages;
  final List<({double width, double height})> pdfPageSizes;
  final String? extractedText;
  final int? byteLength;
  final bool isDataUri;
  final String? resolvedLink;

  const _PdfPreparedAttachment({
    this.image,
    this.pdfPages = const [],
    this.pdfPageSizes = const [],
    this.extractedText,
    this.byteLength,
    required this.isDataUri,
    this.resolvedLink,
  });
}

class _InlinePreviewPayload {
  final Uint8List? bytes;
  final List<PdfPageRaster> pdfPages;
  final String? extractedText;
  final bool isPdf;
  final String mimeType;
  final String? loadError;

  const _InlinePreviewPayload({
    this.bytes,
    this.pdfPages = const [],
    this.extractedText,
    this.isPdf = false,
    this.mimeType = 'application/octet-stream',
    this.loadError,
  });
}

class _InlineLampiranContentPreview extends StatefulWidget {
  final String url;
  final String fileName;
  final JenisLampiran jenis;
  final Color accentColor;
  final VoidCallback onOpenFull;

  const _InlineLampiranContentPreview({
    required this.url,
    required this.fileName,
    required this.jenis,
    required this.accentColor,
    required this.onOpenFull,
  });

  @override
  State<_InlineLampiranContentPreview> createState() =>
      _InlineLampiranContentPreviewState();
}

class _InlineLampiranContentPreviewState
    extends State<_InlineLampiranContentPreview> {
  _InlinePreviewPayload? _syncPayload;
  Future<_InlinePreviewPayload>? _asyncFuture;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  @override
  void didUpdateWidget(covariant _InlineLampiranContentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.fileName != widget.fileName) {
      _initPreview();
    }
  }

  void _initPreview() {
    _syncPayload = null;
    _asyncFuture = null;

    final decoded = LampiranHelper.tryDecodeDataUri(widget.url);
    if (decoded != null) {
      final bytes = decoded.bytes;
      final mime = decoded.mimeType.isNotEmpty
          ? decoded.mimeType
          : LampiranHelper.inferMimeType(widget.url, bytes: bytes);
      final isPdf = LampiranHelper.isPdfUrl(widget.url, bytes) ||
          mime == 'application/pdf';

      // Non-PDF data URI dapat diekstrak seketika tanpa menunggu proses async rasterisasi
      if (!isPdf) {
        String? extracted;
        if (LampiranHelper.isReadableDocument(
          widget.url,
          fileName: widget.fileName,
          bytes: bytes,
        )) {
          extracted = LampiranHelper.extractReadableDocumentText(
            bytes,
            widget.fileName,
            mimeType: mime,
          );
        }
        _syncPayload = _InlinePreviewPayload(
          bytes: bytes,
          extractedText: extracted,
          isPdf: false,
          mimeType: mime,
        );
        return;
      }
    }

    _asyncFuture = _loadAsyncPreview(preDecoded: decoded);
  }

  Future<_InlinePreviewPayload> _loadAsyncPreview({
    DecodedDataUri? preDecoded,
  }) async {
    try {
      final bytes = preDecoded?.bytes ??
          await LampiranHelper.fetchBytes(
            widget.url,
            timeout: const Duration(seconds: 12),
          );
      if (bytes == null || bytes.isEmpty) {
        return const _InlinePreviewPayload(
          loadError: 'Isi berkas tidak dapat dimuat secara langsung.',
        );
      }

      final mime = (preDecoded?.mimeType.isNotEmpty ?? false)
          ? preDecoded!.mimeType
          : LampiranHelper.inferMimeType(widget.url, bytes: bytes);
      final isPdf = LampiranHelper.isPdfUrl(widget.url, bytes) ||
          mime == 'application/pdf';

      if (isPdf) {
        final pages = await LampiranHelper.rasterPdfPages(
          bytes,
          dpi: 115,
          maxPages: 15,
          timeout: const Duration(seconds: 18),
        );
        String? fallbackText;
        if (pages.isEmpty) {
          fallbackText = LampiranHelper.extractReadableDocumentText(
            bytes,
            widget.fileName,
            mimeType: mime,
          );
        }
        return _InlinePreviewPayload(
          bytes: bytes,
          pdfPages: pages,
          extractedText: fallbackText,
          isPdf: true,
          mimeType: mime,
        );
      }

      String? extracted;
      if (LampiranHelper.isReadableDocument(
        widget.url,
        fileName: widget.fileName,
        bytes: bytes,
      )) {
        extracted = LampiranHelper.extractReadableDocumentText(
          bytes,
          widget.fileName,
          mimeType: mime,
        );
      }

      return _InlinePreviewPayload(
        bytes: bytes,
        extractedText: extracted,
        isPdf: false,
        mimeType: mime,
      );
    } catch (_) {
      return const _InlinePreviewPayload(
        loadError: 'Pratinjau isi berkas tidak tersedia.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_syncPayload != null) {
      return _buildPreviewContent(context, _syncPayload!);
    }

    return FutureBuilder<_InlinePreviewPayload>(
      future: _asyncFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider(context)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.accentColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Memuat isi berkas ${widget.fileName}...',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final payload = snapshot.data ??
            const _InlinePreviewPayload(
              loadError: 'Pratinjau isi berkas belum dapat dimuat.',
            );
        return _buildPreviewContent(context, payload);
      },
    );
  }

  Widget _buildPreviewContent(
    BuildContext context,
    _InlinePreviewPayload payload,
  ) {
    final sizeKb = payload.bytes != null
        ? '${(payload.bytes!.length / 1024).toStringAsFixed(1)} KB'
        : null;

    if (payload.pdfPages.isNotEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 15,
                    color: widget.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Isi Dokumen PDF (${payload.pdfPages.length} halaman)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  if (sizeKb != null)
                    Text(
                      sizeKb,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: List.generate(payload.pdfPages.length, (idx) {
                    final page = payload.pdfPages[idx];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: idx == payload.pdfPages.length - 1 ? 0 : 10,
                      ),
                      child: InkWell(
                        onTap: widget.onOpenFull,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.divider(context),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                color: Colors.black.withValues(alpha: 0.04),
                                child: Text(
                                  'Halaman ${idx + 1} dari ${payload.pdfPages.length}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(5),
                                ),
                                child: Image.memory(
                                  page.pngBytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final extracted = payload.extractedText?.trim();
    if (extracted != null && extracted.isNotEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 15,
                    color: widget.accentColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      payload.isPdf
                          ? 'Ringkasan Teks Isi Dokumen PDF'
                          : 'Isi Dokumen Lampiran',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  if (sizeKb != null)
                    Text(
                      sizeKb,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(
                    extracted,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final statusMsg = payload.loadError ??
        (payload.isPdf
            ? 'Berkas PDF${sizeKb != null ? ' ($sizeKb)' : ''} siap dilihat. Ketuk tombol di bawah untuk membuka pratinjau penuh.'
            : (widget.jenis == JenisLampiran.video ||
                    widget.jenis == JenisLampiran.voice)
                ? 'Berkas media${sizeKb != null ? ' ($sizeKb)' : ''} tersimpan. Ketuk tombol di bawah untuk memutar atau mengunduh.'
                : 'Format berkas ${widget.fileName}${sizeKb != null ? ' ($sizeKb)' : ''} dapat dibuka melalui tombol di bawah.');

    return InkWell(
      onTap: widget.onOpenFull,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Row(
          children: [
            Icon(
              payload.isPdf
                  ? Icons.picture_as_pdf_rounded
                  : widget.jenis == JenisLampiran.video
                      ? Icons.video_file_rounded
                      : widget.jenis == JenisLampiran.voice
                          ? Icons.audio_file_rounded
                          : Icons.description_outlined,
              size: 18,
              color: widget.accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusMsg,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
