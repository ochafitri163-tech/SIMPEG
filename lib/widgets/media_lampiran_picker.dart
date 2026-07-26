import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        const SizedBox(height: 10),
        _ringkasan(),
      ],
    );
  }

  Widget _tombol(IconData icon, String label, VoidCallback? onTap,
      {Color warna = accent}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: warna),
      label: Text(label, style: TextStyle(color: warna, fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: warna.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _ringkasan() {
    final items = <String>[];
    if (c.foto.isNotEmpty) items.add('${c.foto.length} foto');
    if (c.video.isNotEmpty) items.add('${c.video.length} video');
    if (c.voice.isNotEmpty) items.add('${c.voice.length} voice note');
    if (c.dokumen.isNotEmpty) items.add('${c.dokumen.length} dokumen');
    if (items.isEmpty) {
      return const Text('Belum ada lampiran.',
          style: TextStyle(fontSize: 11.5, color: hintGrey));
    }
    return Text('Terlampir: ${items.join(', ')}',
        style: const TextStyle(
            fontSize: 12, color: navy, fontWeight: FontWeight.w600));
  }
}
