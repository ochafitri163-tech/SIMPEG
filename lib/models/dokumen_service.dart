import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/audit_log_service.dart';

/// =============================================================
/// B9 — MANAJEMEN DOKUMEN KEPEGAWAIAN
///
/// SDM mengunggah dokumen (SK, kontrak, surat, dll). Dokumen bisa
/// ditujukan ke satu pegawai (pegawai_id) atau bersifat umum
/// (pegawai_id = null -> terlihat oleh semua). Pegawai dapat melihat &
/// mengunduh dokumen miliknya + dokumen umum.
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

  static const List<String> kategoriPilihan = [
    'SK',
    'Diklat',
    'Kontrak',
    'Sertifikat',
    'Surat',
    'Slip Gaji',
    'Umum',
  ];

  static const List<String> kategoriResmi = ['SK', 'Diklat', 'surat_kerja', 'surat_diklat', 'sk', 'diklat'];

  static final List<DokumenKepegawaian> _localCache = [];

  /// Dokumen yang bisa diakses user login: miliknya + dokumen umum.
  static Future<List<DokumenKepegawaian>> untukSaya({String? nik}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeNik = (nik != null && nik.isNotEmpty) ? nik : prefs.getString('user_nik');

      final apiRes = await ApiService.getDokumenResmi(nik: activeNik);
      if (apiRes['success'] == true && apiRes['data'] is List) {
        final rawList = apiRes['data'] as List;
        if (rawList.isNotEmpty) {
          final list = rawList.map((r) => DokumenKepegawaian.fromRow(Map<String, dynamic>.from(r as Map))).toList();
          for (final loc in _localCache) {
            if (!list.any((d) => d.id == loc.id)) {
              list.insert(0, loc);
            }
          }
          return list;
        }
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
    final resmiLower = kategoriResmi.map((k) => k.toLowerCase()).toSet();
    return semua.where((d) => resmiLower.contains(d.kategori.toLowerCase())).toList();
  }

  /// SDM — seluruh dokumen.
  static Future<List<DokumenKepegawaian>> semua() async {
    try {
      final apiRes = await ApiService.getDokumenResmi(scope: 'all');
      if (apiRes['success'] == true && apiRes['data'] is List) {
        final rawList = apiRes['data'] as List;
        final list = rawList
            .map((r) =>
                DokumenKepegawaian.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList();
        _localCache
          ..clear()
          ..addAll(list);
        return list;
      }
      return _localCache;
    } catch (_) {
      return _localCache;
    }
  }

  /// Upload biner file lalu kembalikan data URL.
  static Future<String> unggahFile({
    required String namaFile,
    required Uint8List bytes,
  }) async {
    try {
      if (bytes.isNotEmpty) {
        return 'data:application/pdf;base64,${base64Encode(bytes)}';
      }
      return '';
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

    DokumenKepegawaian newDoc = DokumenKepegawaian(
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

    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.storeDokumen(
        pegawaiId: pegawaiId,
        judul: judul.trim(),
        kategori: kategori,
        fileUrl: fileUrl,
        fileNama: fileNama,
        diunggahOleh: diunggahOleh,
        nomor: nomor,
        tglTerbit: tglTerbit,
      );
      if (res['success'] != true) {
        throw Exception(
          res['message']?.toString() ?? 'Gagal menyimpan dokumen ke server.',
        );
      }
      if (res['data'] is Map) {
        newDoc = DokumenKepegawaian.fromRow(
          Map<String, dynamic>.from(res['data'] as Map),
        );
      }
    }

    _localCache.removeWhere((d) => d.id == newDoc.id);
    _localCache.insert(0, newDoc);

    AuditLogService.logAction(
      userNik: diunggahOleh,
      userName: diunggahOleh,
      role: 'SDM',
      action: 'CREATE',
      module: 'Dokumen',
      description: 'Mengunggah dokumen "${judul.trim()}" (kategori: $kategori, file: $fileNama)',
    );
  }

  static Future<void> hapus({required int id}) async {
    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.deleteDokumen(id);
      if (res['success'] != true) {
        throw Exception(
          res['message']?.toString() ?? 'Gagal menghapus dokumen di server.',
        );
      }
    }
    _localCache.removeWhere((d) => d.id == id);
    AuditLogService.logAction(
      userNik: 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'DELETE',
      module: 'Dokumen',
      description: 'Menghapus dokumen kepegawaian ID #$id',
    );
  }
}