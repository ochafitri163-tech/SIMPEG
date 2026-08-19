import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/dokumen_service.dart';
import '../../models/pengaduan_model.dart' show formatTanggalIndonesia;
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

/// B9 — MANAJEMEN DOKUMEN KEPEGAWAIAN.
/// - SDM: melihat semua dokumen, mengunggah, & menghapus.
/// - Role lain: melihat & mengunduh dokumen miliknya + dokumen umum.
class DokumenKepegawaianScreen extends StatefulWidget {
  final AppUser user;
  const DokumenKepegawaianScreen({super.key, required this.user});

  @override
  State<DokumenKepegawaianScreen> createState() =>
      _DokumenKepegawaianScreenState();
}

class _DokumenKepegawaianScreenState
    extends State<DokumenKepegawaianScreen> {
  static const Color _accent = Color(0xFF2E86AB);

  bool get _isSdm => widget.user.role == UserRole.sdm;
  late Future<List<DokumenKepegawaian>> _future;

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  Future<List<DokumenKepegawaian>> _muat() =>
      _isSdm ? DokumenService.semua() : DokumenService.untukSaya();

  void _refresh() => setState(() => _future = _muat());

  Future<void> _buka(DokumenKepegawaian d) async {
    final uri = Uri.tryParse(d.fileUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _pesan('Tidak dapat membuka dokumen.');
    }
  }

  Future<void> _unggah() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormDokumenSheet(user: widget.user),
    );
    if (ok == true) _refresh();
  }

  Future<void> _hapus(DokumenKepegawaian d) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dokumen'),
        content: Text('Hapus "${d.judul}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await DokumenService.hapus(id: d.id);
      _refresh();
    } catch (e) {
      _pesan('Gagal menghapus: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Dokumen Kepegawaian',
      subtitle: _isSdm
          ? 'Kelola & unggah dokumen pegawai'
          : 'Dokumen pribadi & umum Anda',
      icon: Icons.folder_shared_rounded,
      trailing: _isSdm
          ? IconButton(
              onPressed: _unggah,
              icon: const Icon(Icons.upload_file_rounded,
                  color: Colors.white),
            )
          : null,
      child: FutureBuilder<List<DokumenKepegawaian>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const <DokumenKepegawaian>[];
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open_rounded,
              message: _isSdm
                  ? 'Belum ada dokumen. Tekan ikon unggah.'
                  : 'Belum ada dokumen untuk Anda.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              itemCount: items.length,
              itemBuilder: (context, i) => _tile(items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(DokumenKepegawaian d) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ikon = d.fileNama.toLowerCase().endsWith('.pdf')
        ? Icons.picture_as_pdf_rounded
        : (d.fileNama.toLowerCase().endsWith('.png') ||
                d.fileNama.toLowerCase().endsWith('.jpg') ||
                d.fileNama.toLowerCase().endsWith('.jpeg'))
            ? Icons.image_rounded
            : Icons.insert_drive_file_rounded;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2230) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ikon, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (d.umum
                                ? const Color(0xFF27AE60)
                                : _accent)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d.umum ? 'Umum' : d.kategori,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: d.umum
                                  ? const Color(0xFF27AE60)
                                  : _accent)),
                    ),
                    const SizedBox(width: 6),
                    Text(formatTanggalIndonesia(d.dibuatPada),
                        style: TextStyle(
                            fontSize: 10.5, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Buka / Unduh',
            onPressed: () => _buka(d),
            icon: const Icon(Icons.download_rounded, color: _accent),
          ),
          if (_isSdm)
            IconButton(
              tooltip: 'Hapus',
              onPressed: () => _hapus(d),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFE74C3C)),
            ),
        ],
      ),
    );
  }
}

class _FormDokumenSheet extends StatefulWidget {
  final AppUser user;
  const _FormDokumenSheet({required this.user});

  @override
  State<_FormDokumenSheet> createState() => _FormDokumenSheetState();
}

class _FormDokumenSheetState extends State<_FormDokumenSheet> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  final _judulC = TextEditingController();
  final _pegawaiIdC = TextEditingController();
  final _nomorC = TextEditingController();
  String _kategori = 'Umum';
  String? _fileUrl;
  String? _fileNama;
  bool _uploading = false;
  bool _simpan = false;

  @override
  void dispose() {
    _judulC.dispose();
    _pegawaiIdC.dispose();
    _nomorC.dispose();
    super.dispose();
  }

  Future<void> _pilihFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      if (f.bytes == null) {
        _pesan('Tidak dapat membaca file.');
        return;
      }
      setState(() => _uploading = true);
      final url = await DokumenService.unggahFile(
          namaFile: f.name, bytes: f.bytes!);
      setState(() {
        _fileUrl = url;
        _fileNama = f.name;
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      _pesan('Gagal mengunggah: $e');
    }
  }

  Future<void> _submit() async {
    if (_fileUrl == null) {
      _pesan('Pilih file terlebih dahulu.');
      return;
    }
    setState(() => _simpan = true);
    try {
      await DokumenService.simpan(
        pegawaiId: _pegawaiIdC.text.trim().isEmpty
            ? null
            : _pegawaiIdC.text.trim(),
        judul: _judulC.text,
        kategori: _kategori,
        fileUrl: _fileUrl!,
        fileNama: _fileNama ?? 'dokumen',
        diunggahOleh: widget.user.name,
        nomor: _nomorC.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (e) {
      setState(() => _simpan = false);
      _pesan(e.message.toString());
    } catch (e) {
      setState(() => _simpan = false);
      _pesan('Gagal menyimpan: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2230) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Unggah Dokumen',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _judulC,
              decoration: InputDecoration(
                labelText: 'Judul Dokumen *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nomorC,
              decoration: InputDecoration(
                labelText: 'Nomor Surat (opsional)',
                hintText: 'Mis. SK/SDM/2024/001',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _kategori,
              decoration: InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: DokumenService.kategoriPilihan
                  .map((k) =>
                      DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) => setState(() => _kategori = v ?? 'Umum'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pegawaiIdC,
              decoration: InputDecoration(
                labelText: 'ID Pegawai tujuan (kosongkan = umum)',
                hintText: 'UUID pegawai',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pilihFile,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(_fileNama ??
                  (_uploading ? 'Mengunggah…' : 'Pilih File')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _simpan ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _simpan
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Dokumen',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}