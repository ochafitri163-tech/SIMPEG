import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Menampung URL hasil upload lampiran multi-media (foto, video, voice note,
/// dokumen). Dipakai bersama oleh form pengaduan pegawai & form hasil
/// investigasi TPDPK.
class MediaLampiranController {
  final List<String> foto = [];
  final List<String> video = [];
  final List<String> voice = [];
  final List<String> dokumen = [];

  bool get isEmpty =>
      foto.isEmpty && video.isEmpty && voice.isEmpty && dokumen.isEmpty;
}

/// Widget pemilih lampiran: Foto (galeri), Video, Voice Note (rekam langsung
/// via paket `record`), dan Dokumen (via `file_picker`). Setiap file langsung
/// diunggah ke Supabase Storage & URL publiknya disimpan di [controller].
class MediaLampiranPicker extends StatefulWidget {
  final MediaLampiranController controller;
  final String bucket;
  final String prefix;
  final bool includeFoto;
  const MediaLampiranPicker({
    super.key,
    required this.controller,
    required this.prefix,
    this.bucket = 'pengaduan-bukti',
    this.includeFoto = true,
  });

  @override
  State<MediaLampiranPicker> createState() => _MediaLampiranPickerState();
}

class _MediaLampiranPickerState extends State<MediaLampiranPicker> {
  static const Color accent = Color(0xFF2E86AB);
  static const Color navy = Color(0xFF0D2C6E);
  static const Color red = Color(0xFFE74C3C);
  static const Color hintGrey = Color(0xFF9AA5B1);

  final _client = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();

  bool _uploading = false;
  bool _isRecording = false;

  MediaLampiranController get c => widget.controller;

  Future<void> _uploadBytes(
      Uint8List bytes, String ext, List<String> target) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safePrefix =
        widget.prefix.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final filename = '${safePrefix}_$ts.$ext';
    await _client.storage.from(widget.bucket).uploadBinary(filename, bytes);
    final url = _client.storage.from(widget.bucket).getPublicUrl(filename);
    target.add(url);
  }

  Future<void> _jalankanUpload(Future<void> Function() aksi) async {
    setState(() => _uploading = true);
    try {
      await aksi();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal upload: $e'), backgroundColor: red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickFoto() async {
    final XFile? f = await _imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (f == null) return;
    await _jalankanUpload(() async {
      final bytes = await f.readAsBytes();
      await _uploadBytes(bytes, 'jpg', c.foto);
    });
  }

  Future<void> _pickVideo() async {
    final XFile? f =
        await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (f == null) return;
    await _jalankanUpload(() async {
      final bytes = await f.readAsBytes();
      final ext = f.name.contains('.') ? f.name.split('.').last : 'mp4';
      await _uploadBytes(bytes, ext, c.video);
    });
  }

  Future<void> _pickDokumen() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    await _jalankanUpload(() async {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final ext = file.extension ?? 'bin';
        await _uploadBytes(bytes, ext, c.dokumen);
      }
    });
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null) return;
      await _jalankanUpload(() async {
        final bytes = await File(path).readAsBytes();
        await _uploadBytes(bytes, 'm4a', c.voice);
      });
    } else {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin mikrofon ditolak.')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      if (mounted) setState(() => _isRecording = true);
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.includeFoto)
              _tombol(Icons.photo_camera_back_rounded, 'Foto',
                  _uploading ? null : _pickFoto),
            _tombol(Icons.videocam_rounded, 'Video',
                _uploading ? null : _pickVideo),
            _tombol(
              _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
              _isRecording ? 'Berhenti Rekam' : 'Voice Note',
              _uploading ? null : _toggleRecord,
              warna: _isRecording ? red : accent,
            ),
            _tombol(Icons.attach_file_rounded, 'Dokumen',
                _uploading ? null : _pickDokumen),
          ],
        ),
        if (_isRecording) ...[
          const SizedBox(height: 10),
          Row(
            children: const [
              Icon(Icons.fiber_manual_record, size: 12, color: red),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Sedang merekam... tekan "Berhenti Rekam" untuk menyimpan.',
                    style: TextStyle(fontSize: 11.5, color: red)),
              ),
            ],
          ),
        ],
        if (_uploading) ...[
          const SizedBox(height: 10),
          Row(
            children: const [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Mengunggah lampiran...',
                  style: TextStyle(fontSize: 12, color: hintGrey)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _lampiranPreview(),
      ],
    );
  }

  Widget _tombol(IconData icon, String label, VoidCallback? onTap,
      {Color warna = accent}) {
    return Material(
      color: warna.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: warna.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: onTap == null ? hintGrey : warna),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: onTap == null ? hintGrey : warna,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  /// Filename ringkas dari URL Supabase Storage (buang query string & path).
  String _namaFile(String url) {
    final withoutQuery = url.split('?').first;
    final segments = withoutQuery.split('/');
    return segments.isNotEmpty ? segments.last : url;
  }

  Future<void> _bukaUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka lampiran.')),
      );
    }
  }

  void _lihatFotoPenuh(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kombinasi semua lampiran yang sudah terunggah, ditampilkan visual:
  /// foto sebagai thumbnail nyata (bukan sekadar label teks), sementara
  /// video/voice note/dokumen sebagai baris dengan ikon, nama file, tombol
  /// buka, dan tombol hapus — sehingga hasil upload benar-benar terlihat
  /// dan bisa dicek langsung, bukan cuma ringkasan angka.
  Widget _lampiranPreview() {
    if (c.isEmpty) {
      return Row(
        children: const [
          Icon(Icons.attachment_rounded, size: 15, color: hintGrey),
          SizedBox(width: 6),
          Text('Belum ada lampiran.',
              style: TextStyle(fontSize: 11.5, color: hintGrey)),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.foto.isNotEmpty) ...[
            _labelKecil('Foto (${c.foto.length})'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < c.foto.length; i++)
                  _thumbnailFoto(c.foto[i], i),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (c.video.isNotEmpty) ...[
            _labelKecil('Video (${c.video.length})'),
            const SizedBox(height: 6),
            for (int i = 0; i < c.video.length; i++)
              _barisLampiran(
                icon: Icons.videocam_rounded,
                label: 'Video ${i + 1} · ${_namaFile(c.video[i])}',
                onTap: () => _bukaUrl(c.video[i]),
                onHapus: () => setState(() => c.video.removeAt(i)),
              ),
            const SizedBox(height: 6),
          ],
          if (c.voice.isNotEmpty) ...[
            _labelKecil('Voice Note (${c.voice.length})'),
            const SizedBox(height: 6),
            for (int i = 0; i < c.voice.length; i++)
              _barisLampiran(
                icon: Icons.graphic_eq_rounded,
                label: 'Voice Note ${i + 1}',
                onTap: () => _bukaUrl(c.voice[i]),
                onHapus: () => setState(() => c.voice.removeAt(i)),
              ),
            const SizedBox(height: 6),
          ],
          if (c.dokumen.isNotEmpty) ...[
            _labelKecil('Dokumen (${c.dokumen.length})'),
            const SizedBox(height: 6),
            for (int i = 0; i < c.dokumen.length; i++)
              _barisLampiran(
                icon: Icons.description_rounded,
                label: _namaFile(c.dokumen[i]),
                onTap: () => _bukaUrl(c.dokumen[i]),
                onHapus: () => setState(() => c.dokumen.removeAt(i)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _labelKecil(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: navy));

  Widget _thumbnailFoto(String url, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _lihatFotoPenuh(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 64,
                  height: 64,
                  color: accent.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stack) => Container(
                width: 64,
                height: 64,
                color: accent.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_rounded,
                    size: 20, color: hintGrey),
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => setState(() => c.foto.removeAt(index)),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: red,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded,
                  size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barisLampiran({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onHapus,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: navy),
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 15, color: hintGrey),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onHapus,
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}