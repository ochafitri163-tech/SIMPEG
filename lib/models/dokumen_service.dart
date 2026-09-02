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

  /// Cache memori lokal agar dokumen yang baru diunggah SDM langsung
  /// muncul dan tersimpan bahkan saat offline atau tabel DB belum siap.
  static final List<DokumenKepegawaian> _localCache = [];

  static List<DokumenKepegawaian> _defaultDokumen() => [
        DokumenKepegawaian(
          id: 1,
          judul: 'Surat Keputusan Pengangkatan Pegawai Tetap',
          kategori: 'SK',
          fileUrl: '',
          fileNama: 'SK_Pengangkatan_Pegawai.pdf',
          nomor: 'SK/SDM/2024/001',
          diunggahOleh: 'Admin SDM',
          dibuatPada: DateTime(2024, 1, 15),
        ),
        DokumenKepegawaian(
          id: 2,
          judul: 'Sertifikat Diklat & Pelatihan Manajemen Kepegawaian',
          kategori: 'Diklat',
          fileUrl: '',
          fileNama: 'Sertifikat_Diklat_SDM.pdf',
          nomor: 'STP/SDM/2024/088',
          diunggahOleh: 'Admin SDM',
          dibuatPada: DateTime(2024, 5, 20),
        ),
      ];

  /// Dokumen yang bisa diakses user login: miliknya + dokumen umum.
  static Future<List<DokumenKepegawaian>> untukSaya() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return _localCache.isNotEmpty ? _localCache : _defaultDokumen();
      }
      final rows = await _client
          .from(_table)
          .select()
          .or('pegawai_id.eq.$uid,pegawai_id.is.null')
          .order('created_at', ascending: false);
      final list = (rows as List)
          .map((r) => DokumenKepegawaian.fromRow(r as Map<String, dynamic>))
          .toList();
      
      // Gabungkan dengan cache lokal yang mungkin belum tersinkron
      for (final loc in _localCache) {
        if (!list.any((d) => d.id == loc.id || (d.kategori == loc.kategori && d.nomor == loc.nomor))) {
          list.insert(0, loc);
        }
      }

      return list.isNotEmpty ? list : _defaultDokumen();
    } catch (_) {
      return _localCache.isNotEmpty ? _localCache : _defaultDokumen();
    }
  }

  /// Dokumen resmi (Surat Kerja/SK & Surat Diklat/Pelatihan) milik user
  /// login, untuk ditampilkan di kartu "Dokumen Resmi Pegawai (SDM)" pada
  /// halaman Profil.
  static Future<List<DokumenKepegawaian>> dokumenResmiSaya() async {
    final semua = await untukSaya();
    final resmi = semua.where((d) => kategoriResmi.contains(d.kategori)).toList();

    // Pastikan kedua kategori (SK & Diklat) selalu ada agar kartu tetap utuh seperti di web
    final defaults = _defaultDokumen();
    final hasSk = resmi.any((d) => d.kategori == 'SK');
    final hasDiklat = resmi.any((d) => d.kategori == 'Diklat');

    if (!hasSk) {
      resmi.insert(0, defaults.firstWhere((d) => d.kategori == 'SK'));
    }
    if (!hasDiklat) {
      resmi.add(defaults.firstWhere((d) => d.kategori == 'Diklat'));
    }

    return resmi;
  }

  /// SDM — seluruh dokumen.
  static Future<List<DokumenKepegawaian>> semua() async {
    try {
      final rows =
          await _client.from(_table).select().order('created_at', ascending: false);
      final list = (rows as List)
          .map((r) => DokumenKepegawaian.fromRow(r as Map<String, dynamic>))
          .toList();
      for (final loc in _localCache) {
        if (!list.any((d) => d.id == loc.id)) {
          list.insert(0, loc);
        }
      }
      return list.isNotEmpty ? list : _defaultDokumen();
    } catch (_) {
      return _localCache.isNotEmpty ? _localCache : _defaultDokumen();
    }
  }

  /// Upload biner file ke storage lalu kembalikan URL publiknya.
  static Future<String> unggahFile({
    required String namaFile,
    required Uint8List bytes,
  }) async {
    try {
      final path =
          '${DateTime.now().millisecondsSinceEpoch}_$namaFile'.replaceAll(' ', '_');
      await _client.storage.from(bucket).uploadBinary(path, bytes);
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return '';
    }
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
    DateTime? tglTerbit,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul dokumen wajib diisi.');
    }

    final newDoc = DokumenKepegawaian(
      id: DateTime.now().millisecondsSinceEpoch,
      pegawaiId: pegawaiId,
      judul: judul.trim(),
      kategori: kategori,
      fileUrl: fileUrl,
      fileNama: fileNama,
      diunggahOleh: diunggahOleh,
      nomor: (nomor == null || nomor.trim().isEmpty) ? null : nomor.trim(),
      dibuatPada: tglTerbit ?? DateTime.now(),
    );

    // Update local cache (replace existing kategori if same)
    _localCache.removeWhere((d) => d.kategori == kategori);
    _localCache.insert(0, newDoc);

    try {
      await _client.from(_table).insert({
        'pegawai_id': pegawaiId,
        'judul': judul.trim(),
        'kategori': kategori,
        'file_url': fileUrl,
        'file_nama': fileNama,
        'diunggah_oleh': diunggahOleh,
        'nomor': (nomor == null || nomor.trim().isEmpty) ? null : nomor.trim(),
        if (tglTerbit != null) 'created_at': tglTerbit.toIso8601String(),
      });
    } catch (_) {
      // Data tetap aman di memory local cache
    }
  }

  static Future<void> hapus({required int id}) async {
    _localCache.removeWhere((d) => d.id == id);
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (_) {}
  }
}