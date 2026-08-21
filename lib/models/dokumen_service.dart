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
  final String? nomor;
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
    this.nomor,
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
      nomor: row['nomor'] as String?,
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
    'Diklat',
    'Kontrak',
    'Sertifikat',
    'Surat',
    'Slip Gaji',
    'Umum',
  ];

  /// Kategori resmi yang diterbitkan SDM & ditampilkan di kartu
  /// "Dokumen Resmi Pegawai" pada halaman Profil (Surat Kerja & Surat
  /// Diklat/Pelatihan).
  static const List<String> kategoriResmi = ['SK', 'Diklat'];

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

  /// Dokumen resmi (Surat Kerja/SK & Surat Diklat/Pelatihan) milik user
  /// login, untuk ditampilkan di kartu "Dokumen Resmi Pegawai (SDM)" pada
  /// halaman Profil. Hanya view & unduh — tanpa opsi unggah untuk pegawai.
  static Future<List<DokumenKepegawaian>> dokumenResmiSaya() async {
    final semua = await untukSaya();
    return semua.where((d) => kategoriResmi.contains(d.kategori)).toList();
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
    String? nomor,
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
      'nomor': (nomor == null || nomor.trim().isEmpty) ? null : nomor.trim(),
    });
  }

  static Future<void> hapus({required int id}) async {
    await _client.from(_table).delete().eq('id', id);
  }
}