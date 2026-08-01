import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// =============================================================
/// B9 — MANAJEMEN DOKUMEN KEPEGAWAIAN
///
/// SDM mengunggah dokumen (SK, kontrak, surat, dll). Dokumen bisa
/// ditujukan ke satu pegawai (pegawai_id) atau bersifat umum
/// (pegawai_id = null -> terlihat oleh semua). Pegawai dapat melihat &
/// mengunduh dokumen miliknya + dokumen umum.
///
/// File disimpan di Supabase Storage bucket `dokumen`.
/// Skema lihat: supabase/fitur_tambahan.sql
/// =============================================================
class DokumenKepegawaian {
  final int id;
  final String? pegawaiId; // null = dokumen umum
  final String judul;
  final String kategori;
  final String fileUrl;
  final String fileNama;
  final String? diunggahOleh;
  final DateTime dibuatPada;

  const DokumenKepegawaian({
    required this.id,
    required this.judul,
    required this.kategori,
    required this.fileUrl,
    required this.fileNama,
    required this.dibuatPada,
    this.pegawaiId,
    this.diunggahOleh,
  });

  bool get umum => pegawaiId == null;

  factory DokumenKepegawaian.fromRow(Map<String, dynamic> row) {
    return DokumenKepegawaian(
      id: (row['id'] as num).toInt(),
      pegawaiId: row['pegawai_id'] as String?,
      judul: (row['judul'] ?? '') as String,
      kategori: (row['kategori'] ?? 'Umum') as String,
      fileUrl: (row['file_url'] ?? '') as String,
      fileNama: (row['file_nama'] ?? 'dokumen') as String,
      diunggahOleh: row['diunggah_oleh'] as String?,
      dibuatPada: DateTime.tryParse(row['created_at'].toString()) ??
          DateTime.now(),
    );
  }
}

class DokumenService {
  DokumenService._();

  static final _client = Supabase.instance.client;
  static const _table = 'dokumen_pegawai';
  static const bucket = 'dokumen';

  static const List<String> kategoriPilihan = [
    'SK',
    'Kontrak',
    'Sertifikat',
    'Surat',
    'Slip Gaji',
    'Umum',
  ];

  /// Dokumen yang bisa diakses user login: miliknya + dokumen umum.
  static Future<List<DokumenKepegawaian>> untukSaya() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .or('pegawai_id.eq.$uid,pegawai_id.is.null')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => DokumenKepegawaian.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// SDM — seluruh dokumen.
  static Future<List<DokumenKepegawaian>> semua() async {
    final rows =
        await _client.from(_table).select().order('created_at', ascending: false);
    return (rows as List)
        .map((r) => DokumenKepegawaian.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Upload biner file ke storage lalu kembalikan URL publiknya.
  static Future<String> unggahFile({
    required String namaFile,
    required Uint8List bytes,
  }) async {
    final path =
        '${DateTime.now().millisecondsSinceEpoch}_$namaFile'.replaceAll(' ', '_');
    await _client.storage.from(bucket).uploadBinary(path, bytes);
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// SDM — simpan metadata dokumen.
  static Future<void> simpan({
    String? pegawaiId,
    required String judul,
    required String kategori,
    required String fileUrl,
    required String fileNama,
    required String diunggahOleh,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul dokumen wajib diisi.');
    }
    await _client.from(_table).insert({
      'pegawai_id': pegawaiId,
      'judul': judul.trim(),
      'kategori': kategori,
      'file_url': fileUrl,
      'file_nama': fileNama,
      'diunggah_oleh': diunggahOleh,
    });
  }

  static Future<void> hapus({required int id}) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
