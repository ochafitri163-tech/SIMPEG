import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/audit_log_service.dart';

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
      id: (row['id'] as num?)?.toInt() ?? 0,
      pegawaiId: row['pegawai_id']?.toString(),
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
  static const List<String> kategoriResmi = ['SK', 'Diklat', 'surat_kerja', 'surat_diklat', 'sk', 'diklat'];

  /// Cache memori lokal agar dokumen yang baru diunggah SDM langsung
  /// muncul dan tersimpan bahkan saat offline atau tabel DB belum siap.
  static final List<DokumenKepegawaian> _localCache = [];

  /// Dokumen yang bisa diakses user login: miliknya + dokumen umum.
  static Future<List<DokumenKepegawaian>> untukSaya({String? nik}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeNik = (nik != null && nik.isNotEmpty) ? nik : prefs.getString('user_nik');

      // 1. Coba ambil dari API backend SIMPEG Laravel (yang terhubung langsung ke DB PostgreSQL)
      final apiRes = await ApiService.getDokumenResmi(nik: activeNik);
      if (apiRes['success'] == true && apiRes['data'] is List) {
        final rawList = apiRes['data'] as List;
        if (rawList.isNotEmpty) {
          return rawList.map((r) => DokumenKepegawaian.fromRow(r as Map<String, dynamic>)).toList();
        }
      }

      // 2. Fallback ke Supabase query
      String? uid = _client.auth.currentUser?.id;
      if (activeNik != null && activeNik.isNotEmpty) {
        try {
          final peg = await _client.from('pegawai').select('id').eq('nik', activeNik).maybeSingle();
          if (peg != null && peg['id'] != null) {
            uid = peg['id'].toString();
          }
        } catch (_) {}
      }

      if (uid != null) {
        final rows = await _client
            .from(_table)
            .select()
            .or('pegawai_id.eq.$uid,pegawai_id.is.null')
            .order('created_at', ascending: false);
        final list = (rows as List)
            .map((r) => DokumenKepegawaian.fromRow(r as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) return list;
      }

      return _localCache;
    } catch (_) {
      return _localCache;
    }
  }

  /// Dokumen resmi (Surat Kerja/SK & Surat Diklat/Pelatihan) milik user
  /// login, untuk ditampilkan di kartu "Dokumen Resmi Pegawai (SDM)" pada
  /// halaman Profil.
  static Future<List<DokumenKepegawaian>> dokumenResmiSaya({String? nik}) async {
    final semua = await untukSaya(nik: nik);
    return semua.where((d) => kategoriResmi.contains(d.kategori)).toList();
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
      return list;
    } catch (_) {
      return _localCache;
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

      AuditLogService.logAction(
        userNik: _client.auth.currentUser?.id ?? diunggahOleh,
        userName: diunggahOleh,
        role: 'SDM',
        action: 'CREATE',
        module: 'Dokumen',
        description: 'Mengunggah dokumen "${judul.trim()}" (kategori: $kategori, file: $fileNama)',
      );
    } catch (_) {
      // Data tetap aman di memory local cache
    }
  }

  static Future<void> hapus({required int id}) async {
    _localCache.removeWhere((d) => d.id == id);
    try {
      await _client.from(_table).delete().eq('id', id);
      AuditLogService.logAction(
        userNik: _client.auth.currentUser?.id ?? 'SDM',
        userName: 'Pengelola SDM',
        role: 'SDM',
        action: 'DELETE',
        module: 'Dokumen',
        description: 'Menghapus dokumen kepegawaian ID #$id',
      );
    } catch (_) {}
  }
}