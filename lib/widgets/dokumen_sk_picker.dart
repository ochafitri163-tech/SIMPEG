import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sk_sanksi_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Satu dokumen tambahan yang sedang disusun SDM (judul diisi bebas).
class DokumenTambahanDraft {
  String judul;
  final List<String> berkas;

  DokumenTambahanDraft({this.judul = '', List<String>? berkas})
      : berkas = berkas ?? <String>[];
}

/// Menampung berkas untuk keempat jenis dokumen wajib pada penerbitan SK.
///
/// Jumlah file per jenis BEBAS — satu berkas boleh memuat empat dokumen
/// sekaligus (tinggal diunggah di keempat slot), atau dipisah 4–5 file.
/// Di luar empat dokumen wajib itu, SDM masih boleh menambahkan dokumen
/// pendukung lain sebanyak yang diperlukan (opsional).
class DokumenSkController {
  final Map<JenisDokumenSk, List<String>> berkas = {
    for (final j in JenisDokumenSk.values) j: <String>[],
  };

  /// Dokumen pendukung di luar empat dokumen wajib. Jumlahnya bebas dan
  /// sifatnya opsional: SDM boleh menambah sebanyak yang diperlukan.
  final List<DokumenTambahanDraft> tambahan = <DokumenTambahanDraft>[];

  List<String> operator [](JenisDokumenSk jenis) => berkas[jenis]!;

  int get total =>
      berkas.values.fold<int>(0, (acc, list) => acc + list.length) +
      totalTambahan;

  /// Jumlah berkas pada dokumen tambahan saja.
  int get totalTambahan =>
      tambahan.fold<int>(0, (acc, d) => acc + d.berkas.length);

  List<JenisDokumenSk> get belumLengkap =>
      SkSanksiService.dokumenBelumLengkap(berkas);

  bool get lengkap => belumLengkap.isEmpty;

  Map<JenisDokumenSk, List<String>> snapshot() => {
        for (final entry in berkas.entries)
          entry.key: List<String>.from(entry.value),
      };

  /// Dokumen tambahan yang benar-benar berisi berkas, siap disimpan.
  List<DokumenTambahan> snapshotTambahan() => [
        for (final d in tambahan)
          if (d.berkas.isNotEmpty)
            DokumenTambahan(
              judul: d.judul.trim().isEmpty
                  ? 'Dokumen Tambahan'
                  : d.judul.trim(),
              berkas: List<String>.from(d.berkas),
            ),
      ];
}

/// Pemilih dokumen SK: empat slot wajib, tiap slot menerima berapa pun
/// jumlah berkas. Menampilkan indikator kelengkapan 4 dokumen.
class DokumenSkPicker extends StatefulWidget {
  final DokumenSkController controller;

  /// Dipanggil setiap ada perubahan berkas, supaya form induk bisa
  /// menyegarkan status tombol simpan.
  final VoidCallback? onChanged;

  const DokumenSkPicker({
    super.key,
    required this.controller,
    this.onChanged,
  });

  @override
  State<DokumenSkPicker> createState() => _DokumenSkPickerState();
}

class _DokumenSkPickerState extends State<DokumenSkPicker> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _red = Color(0xFFE74C3C);
  static const Color _green = Color(0xFF27AE60);

  JenisDokumenSk? _sedangUnggah;
  int? _sedangUnggahTambahan;

  DokumenSkController get c => widget.controller;

  void _perubahan() {
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _pilihBerkas(JenisDokumenSk jenis) async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
      allowMultiple: true,
    );
    if (hasil == null || hasil.files.isEmpty) return;

    const ekstensiValid = {'pdf', 'doc', 'docx', 'xls', 'xlsx'};
    final filesValid = hasil.files.where((file) {
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      return ekstensiValid.contains(ext);
    }).toList();

    if (filesValid.length < hasil.files.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Hanya berkas PDF, Word (.doc, .docx), atau Excel (.xls, .xlsx) yang diperbolehkan.'),
          backgroundColor: _red,
        ),
      );
    }
    if (filesValid.isEmpty) return;

    setState(() => _sedangUnggah = jenis);
    try {
      for (final file in filesValid) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final url = await SkSanksiService.unggahBerkas(
          namaFile: file.name,
          bytes: bytes,
          jenis: jenis,
        );
        c[jenis].add(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah berkas: $e'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sedangUnggah = null);
        _perubahan();
      }
    }
  }

  void _tampilkanDetailDokumen({
    required String namaFile,
    Uint8List? bytes,
    String? networkUrl,
  }) {
    if (!mounted) return;

    final lower = namaFile.toLowerCase();
    final isGambar = _isGambar(namaFile, bytes) ||
        (networkUrl != null && _isGambar(networkUrl));
    final isPdf =
        _isPdf(namaFile, bytes) || (networkUrl != null && _isPdf(networkUrl));
    final isWord = lower.endsWith('.doc') || lower.endsWith('.docx');
    final isExcel = lower.endsWith('.xls') || lower.endsWith('.xlsx');

    // 1. Jika GAMBAR, tampilkan viewer foto penuh tema gelap (seperti contoh gambar 2)
    if (isGambar) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          namaFile,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bytes != null && bytes.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await Printing.sharePdf(
                                  bytes: bytes, filename: namaFile);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Berkas $namaFile berhasil diunduh.'),
                                    backgroundColor: _green,
                                  ),
                                );
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.download_rounded,
                              size: 16, color: Colors.white),
                          label: const Text('Unduh',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      maxScale: 5.0,
                      child: bytes != null
                          ? Image.memory(bytes, fit: BoxFit.contain)
                          : (networkUrl != null
                              ? Image.network(networkUrl, fit: BoxFit.contain)
                              : const SizedBox()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // 2. Jika DOKUMEN (Word, Excel, PDF, dll.), tampilkan Modal Detail Dokumen
    final ukuranKb =
        bytes != null ? (bytes.length / 1024).toStringAsFixed(1) : null;
    Color iconColor = _navy;
    Color iconBg = _navy.withValues(alpha: 0.1);
    IconData docIcon = Icons.insert_drive_file_rounded;
    String jenisLabel = 'Dokumen Lampiran';

    if (isWord) {
      iconColor = const Color(0xFF185ABD);
      iconBg = const Color(0xFF185ABD).withValues(alpha: 0.1);
      docIcon = Icons.description_rounded;
      final ext = lower.split('.').last.toUpperCase();
      jenisLabel = 'Dokumen Microsoft Word (.$ext)';
    } else if (isExcel) {
      iconColor = const Color(0xFF107C41);
      iconBg = const Color(0xFF107C41).withValues(alpha: 0.1);
      docIcon = Icons.table_chart_rounded;
      final ext = lower.split('.').last.toUpperCase();
      jenisLabel = 'Spreadsheet Microsoft Excel (.$ext)';
    } else if (isPdf) {
      iconColor = const Color(0xFFD32F2F);
      iconBg = const Color(0xFFD32F2F).withValues(alpha: 0.1);
      docIcon = Icons.picture_as_pdf_rounded;
      jenisLabel = 'Dokumen PDF (Portable Document Format)';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: _navy,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Detail Berkas Dokumen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Icon(docIcon, size: 36, color: iconColor),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      namaFile,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      jenisLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (ukuranKb != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ukuran: $ukuranKb KB',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (isPdf && bytes != null && bytes.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await Printing.layoutPdf(
                                name: namaFile,
                                onLayout: (_) async => bytes,
                              );
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('Buka Pratinjau PDF',
                              style: TextStyle(fontSize: 12.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await Printing.sharePdf(
                                  bytes: bytes, filename: namaFile);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Berkas $namaFile berhasil diunduh.'),
                                    backgroundColor: _green,
                                  ),
                                );
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Unduh Berkas PDF',
                              style: TextStyle(fontSize: 12.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _navy,
                            side:
                                BorderSide(color: _navy.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                    ] else if (bytes != null && bytes.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await Printing.sharePdf(
                                  bytes: bytes, filename: namaFile);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Berkas $namaFile berhasil diunduh.'),
                                    backgroundColor: _green,
                                  ),
                                );
                              }
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.download_rounded, size: 17),
                          label: const Text('Unduh Berkas',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                    ] else if (networkUrl != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.tryParse(networkUrl);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon:
                              const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Buka Tautan Berkas',
                              style: TextStyle(fontSize: 12.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isGambar(String url, [Uint8List? bytes]) {
    final lower = url.toLowerCase();
    if (lower.startsWith('data:')) {
      final header = lower.split(',').first;
      if (header.contains('image/')) return true;
    }
    final clean = lower.split('?').first;
    if (clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.bmp')) {
      return true;
    }
    if (bytes != null && bytes.length >= 4) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
    }
    return false;
  }

  bool _isPdf(String url, [Uint8List? bytes]) {
    if (url.startsWith('data:')) {
      final header = url.split(',').first.toLowerCase();
      if (header.contains('application/pdf') || header.contains('.pdf')) return true;
    }
    final clean = url.split('?').first.toLowerCase();
    if (clean.endsWith('.pdf')) return true;
    if (bytes != null && bytes.length >= 4) {
      if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) return true;
    }
    return false;
  }

  Future<void> _buka(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.startsWith('data:')) {
      try {
        final commaIdx = trimmed.indexOf(',');
        if (commaIdx == -1) return;
        final base64Part =
            trimmed.substring(commaIdx + 1).replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(base64Part);
        final fileName = _namaFile(trimmed);

        _tampilkanDetailDokumen(namaFile: fileName, bytes: bytes);
        return;
      } catch (_) {
        return;
      }
    }

    String resolvedUrl = trimmed;
    if (trimmed.startsWith('/storage/') || trimmed.startsWith('storage/')) {
      final host =
          ApiService.baseUrl.replaceAll('/api/v1', '').replaceAll('/api', '');
      final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      resolvedUrl = '$host$cleanPath';
    }

    _tampilkanDetailDokumen(
      namaFile: _namaFile(resolvedUrl),
      networkUrl: resolvedUrl,
    );
  }

  String _namaFile(String url) {
    if (url.startsWith('data:')) {
      final match = RegExp(r'name=([^;]+)').firstMatch(url);
      if (match != null) return Uri.decodeComponent(match.group(1)!);
      if (url.contains('application/pdf')) return 'Dokumen_SK.pdf';
      if (url.contains('word') || url.contains('msword')) {
        return 'Dokumen_SK.docx';
      }
      if (url.contains('excel') || url.contains('sheet')) {
        return 'Dokumen_SK.xlsx';
      }
      if (url.contains('image/png')) return 'Dokumen_SK.png';
      if (url.contains('image/jpeg') || url.contains('image/jpg')) {
        return 'Dokumen_SK.jpg';
      }
      return 'Dokumen_SK';
    }
    final tanpaQuery = url.split('?').first;
    final segmen = tanpaQuery.split('/');
    var nama = segmen.isNotEmpty ? segmen.last : url;
    // Buang prefiks timestamp yang ditambahkan saat upload.
    final pisah = nama.split('_');
    if (pisah.length > 1 && int.tryParse(pisah.first) != null) {
      nama = pisah.sublist(1).join('_');
    }
    return nama;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final jenis in JenisDokumenSk.values) ...[
          _slotDokumen(jenis),
          const SizedBox(height: 12),
        ],
        _bagianTambahan(),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Dokumen tambahan (opsional, jumlahnya bebas)
  // ---------------------------------------------------------------

  Widget _bagianTambahan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 15, color: _navy),
            const SizedBox(width: 6),
            Text(
              'DOKUMEN TAMBAHAN (OPSIONAL)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < c.tambahan.length; i++) ...[
          _kartuTambahan(i),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _tambahDokumen,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text(
              'Tambah dokumen lain',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: BorderSide(color: _accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Dialog untuk memberi judul dokumen tambahan, mis. "Berita Acara
  /// Pemeriksaan" atau "Surat Panggilan".
  Future<void> _tambahDokumen() async {
    final controller = TextEditingController();
    final judul = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Dokumen tambahan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Beri nama dokumen pendukung yang ingin ditambahkan.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'mis. Berita Acara Pemeriksaan',
                  hintStyle: const TextStyle(fontSize: 12.5),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final saran in const [
                    'Berita Acara Pemeriksaan',
                    'Surat Panggilan',
                    'Notulen Rapat',
                    'Foto Lapangan',
                  ])
                    ActionChip(
                      label: Text(saran,
                          style: const TextStyle(fontSize: 10.5)),
                      onPressed: () => Navigator.pop(ctx, saran),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (judul == null) return;
    c.tambahan.add(
      DokumenTambahanDraft(
        judul: judul.trim().isEmpty ? 'Dokumen Tambahan' : judul.trim(),
      ),
    );
    _perubahan();
  }

  Future<void> _pilihBerkasTambahan(int index) async {
    final hasil = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
      allowMultiple: true,
    );
    if (hasil == null || hasil.files.isEmpty) return;

    const ekstensiValid = {'pdf', 'doc', 'docx', 'xls', 'xlsx'};
    final filesValid = hasil.files.where((file) {
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      return ekstensiValid.contains(ext);
    }).toList();

    if (filesValid.length < hasil.files.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Hanya berkas PDF, Word (.doc, .docx), atau Excel (.xls, .xlsx) yang diperbolehkan.'),
          backgroundColor: _red,
        ),
      );
    }
    if (filesValid.isEmpty) return;

    setState(() => _sedangUnggahTambahan = index);
    try {
      for (final file in filesValid) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final url = await SkSanksiService.unggahBerkasTambahan(
          namaFile: file.name,
          bytes: bytes,
        );
        if (index < c.tambahan.length) c.tambahan[index].berkas.add(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah berkas: $e'),
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sedangUnggahTambahan = null);
        _perubahan();
      }
    }
  }

  Widget _kartuTambahan(int index) {
    final item = c.tambahan[index];
    final sedang = _sedangUnggahTambahan == index;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_copy_rounded, size: 16, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.judul,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Nama dokumen',
                    hintStyle: TextStyle(fontSize: 12.5),
                  ),
                  onChanged: (v) => item.judul = v,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'OPSIONAL',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  c.tambahan.removeAt(index);
                  _perubahan();
                },
                icon: const Icon(Icons.close_rounded, size: 17, color: _red),
                tooltip: 'Hapus dokumen ini',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < item.berkas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _buka(item.berkas[i]),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted(context),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPdf(item.berkas[i])
                            ? Icons.picture_as_pdf_rounded
                            : (_isGambar(item.berkas[i])
                                ? Icons.image_rounded
                                : Icons.description_rounded),
                        size: 16,
                        color: _accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _namaFile(item.berkas[i]),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          item.berkas.removeAt(i);
                          _perubahan();
                        },
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 17, color: _red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: sedang ? null : () => _pilihBerkasTambahan(index),
              icon: sedang
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 16),
              label: Text(
                sedang
                    ? 'Mengunggah...'
                    : item.berkas.isEmpty
                        ? 'Unggah berkas'
                        : 'Tambah berkas (${item.berkas.length})',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: BorderSide(color: _navy.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotDokumen(JenisDokumenSk jenis) {
    final berkas = c[jenis];
    final terisi = berkas.isNotEmpty;
    final sedang = _sedangUnggah == jenis;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: terisi
            ? _green.withValues(alpha: 0.05)
            : AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: terisi
              ? _green.withValues(alpha: 0.3)
              : AppColors.divider(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                terisi
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 17,
                color: terisi ? _green : _red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            jenis.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'WAJIB',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: _red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (berkas.isNotEmpty)
            for (int i = 0; i < berkas.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => _buka(berkas[i]),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted(context),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPdf(berkas[i])
                              ? Icons.picture_as_pdf_rounded
                              : (_isGambar(berkas[i])
                                  ? Icons.image_rounded
                                  : Icons.description_rounded),
                          size: 16,
                          color: _accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _namaFile(berkas[i]),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            berkas.removeAt(i);
                            _perubahan();
                          },
                          child: const Icon(Icons.delete_outline_rounded,
                              size: 17, color: _red),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: sedang ? null : () => _pilihBerkas(jenis),
              icon: sedang
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 16),
              label: Text(
                sedang
                    ? 'Mengunggah...'
                    : berkas.isEmpty
                        ? 'Unggah berkas'
                        : 'Tambah berkas (${berkas.length})',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: BorderSide(color: _navy.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}