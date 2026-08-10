import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sk_sanksi_service.dart';
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
      withData: true,
      allowMultiple: true,
    );
    if (hasil == null || hasil.files.isEmpty) return;

    setState(() => _sedangUnggah = jenis);
    try {
      for (final file in hasil.files) {
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

  Future<void> _buka(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _namaFile(String url) {
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
    final kurang = c.belumLengkap;
    final lengkap = kurang.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (lengkap ? _green : _accent).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (lengkap ? _green : _accent).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                lengkap
                    ? Icons.verified_rounded
                    : Icons.rule_folder_rounded,
                size: 18,
                color: lengkap ? _green : _accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lengkap
                          ? '4 dokumen wajib lengkap \u00b7 ${c.total} berkas'
                          : 'Kelengkapan dokumen: '
                              '${4 - kurang.length}/4',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: lengkap ? _green : _accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Jumlah berkas bebas \u2014 satu file boleh memuat '
                      'beberapa dokumen, atau diunggah terpisah. Yang wajib '
                      'ada: SK, bukti pelanggaran, hasil investigasi SPI, dan '
                      'keputusan direksi. Di luar itu SDM boleh menambah '
                      'dokumen pendukung lain sebanyak yang diperlukan.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
        content: Column(
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
      withData: true,
      allowMultiple: true,
    );
    if (hasil == null || hasil.files.isEmpty) return;

    setState(() => _sedangUnggahTambahan = index);
    try {
      for (final file in hasil.files) {
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
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
                      const Icon(Icons.description_rounded,
                          size: 16, color: _accent),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: terisi
              ? _green.withValues(alpha: 0.35)
              : _red.withValues(alpha: 0.25),
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
                    const SizedBox(height: 2),
                    Text(
                      jenis.keterangan,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
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
                        const Icon(Icons.description_rounded,
                            size: 16, color: _accent),
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
