import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import 'pengaduan_service.dart';
import '../services/api_service.dart';
import '../services/audit_log_service.dart';

/// =============================================================
/// B10 — SK SANKSI (Surat Keputusan)
/// =============================================================

/// Empat jenis dokumen wajib pada satu penerbitan SK.
enum JenisDokumenSk {
  sk,
  buktiPelanggaran,
  hasilInvestigasiSpi,
  keputusanDireksi,
}

extension JenisDokumenSkX on JenisDokumenSk {
  /// Kunci penyimpanan di kolom `dokumen` (jsonb).
  String get key {
    switch (this) {
      case JenisDokumenSk.sk:
        return 'sk';
      case JenisDokumenSk.buktiPelanggaran:
        return 'bukti_pelanggaran';
      case JenisDokumenSk.hasilInvestigasiSpi:
        return 'hasil_investigasi_spi';
      case JenisDokumenSk.keputusanDireksi:
        return 'keputusan_direksi';
    }
  }

  String get label {
    switch (this) {
      case JenisDokumenSk.sk:
        return 'SK (Surat Keputusan)';
      case JenisDokumenSk.buktiPelanggaran:
        return 'Bukti Pelanggaran';
      case JenisDokumenSk.hasilInvestigasiSpi:
        return 'Surat Hasil Investigasi';
      case JenisDokumenSk.keputusanDireksi:
        return 'Keputusan Direksi';
    }
  }

  static JenisDokumenSk? fromKey(String key) {
    for (final j in JenisDokumenSk.values) {
      if (j.key == key) return j;
    }
    return null;
  }
}

/// Kunci penyimpanan dokumen tambahan di dalam kolom `dokumen` (jsonb).
/// Kunci ini di luar empat kunci wajib sehingga tidak mengganggu CHECK
/// constraint kelengkapan dokumen.
const String kunciDokumenTambahan = 'tambahan';

/// Dokumen tambahan di luar empat dokumen wajib.
///
/// Empat dokumen wajib tetap harus ada, tetapi SDM BEBAS menambahkan berapa
/// pun dokumen pendukung lain (mis. berita acara pemeriksaan, notulen,
/// surat panggilan, foto lapangan) dengan judul yang diisi sendiri.
class DokumenTambahan {
  final String judul;
  final List<String> berkas;

  const DokumenTambahan({required this.judul, required this.berkas});

  Map<String, dynamic> toJson() => {'judul': judul, 'berkas': berkas};

  factory DokumenTambahan.fromJson(Map raw) => DokumenTambahan(
        judul: '${raw['judul'] ?? 'Dokumen Tambahan'}',
        berkas: raw['berkas'] is List
            ? (raw['berkas'] as List).map((e) => e.toString()).toList()
            : <String>[],
      );
}

/// Pilihan jenis sanksi yang bisa dipilih SDM saat menerbitkan SK.
const List<String> jenisSanksiPilihan = [
  'Penurunan Jabatan',
  'Penurunan Golongan',
  'Teguran Tertulis',
  'Pemotongan Tunjangan',
  'Skorsing',
  'Pemberhentian',
];

const List<String> tingkatSanksiPilihan = ['Ringan', 'Sedang', 'Berat'];

/// Data ringkas pegawai terlapor hasil pencarian NIK.
class PegawaiTerlapor {
  final String id;
  final String nik;
  final String nama;
  final String jabatan;
  final String golongan;

  const PegawaiTerlapor({
    required this.id,
    required this.nik,
    required this.nama,
    required this.jabatan,
    required this.golongan,
  });
}

/// Satu SK sanksi yang sudah diterbitkan.
class SkSanksi {
  final int id;
  final String nomorSk;
  final int? pengaduanId;
  final String? pegawaiId;
  final String nik;
  final String namaPegawai;
  final String jenisSanksi;
  final String tingkat;
  final String? jabatanLama;
  final String? jabatanBaru;
  final String? golonganLama;
  final String? golonganBaru;
  final int nominalPenurunanGaji;
  final DateTime tanggalBerlaku;
  final String? ringkasanPelanggaran;
  final bool validasiLisanDirut;
  final String? disetujuiOleh;
  final DateTime? tanggalPersetujuanDirut;
  final Map<JenisDokumenSk, List<String>> dokumen;

  /// Dokumen pendukung lain di luar empat dokumen wajib (opsional).
  final List<DokumenTambahan> tambahan;
  final String? diterbitkanOleh;
  final DateTime dibuatPada;

  const SkSanksi({
    required this.id,
    required this.nomorSk,
    required this.nik,
    required this.namaPegawai,
    required this.jenisSanksi,
    required this.tingkat,
    required this.nominalPenurunanGaji,
    required this.tanggalBerlaku,
    required this.validasiLisanDirut,
    required this.dokumen,
    required this.dibuatPada,
    this.pengaduanId,
    this.pegawaiId,
    this.jabatanLama,
    this.jabatanBaru,
    this.golonganLama,
    this.golonganBaru,
    this.ringkasanPelanggaran,
    this.disetujuiOleh,
    this.tanggalPersetujuanDirut,
    this.diterbitkanOleh,
    this.tambahan = const [],
  });

  /// True kalau keempat jenis dokumen wajib tersedia.
  bool get dokumenLengkap =>
      JenisDokumenSk.values.every((j) => (dokumen[j] ?? const []).isNotEmpty);

  /// Total berkas dari seluruh dokumen wajib + tambahan (jumlah file bebas).
  int get totalBerkas =>
      dokumen.values.fold<int>(0, (acc, list) => acc + list.length) +
      tambahan.fold<int>(0, (acc, d) => acc + d.berkas.length);

  /// True kalau SDM melampirkan dokumen pendukung di luar yang wajib.
  bool get adaDokumenTambahan => tambahan.any((d) => d.berkas.isNotEmpty);

  /// Ringkasan perubahan jabatan, mis. "Asmen → Staf".
  String? get perubahanJabatan {
    if ((jabatanLama ?? '').isEmpty && (jabatanBaru ?? '').isEmpty) return null;
    return '${jabatanLama ?? '-'} \u2192 ${jabatanBaru ?? '-'}';
  }

  String? get perubahanGolongan {
    if ((golonganLama ?? '').isEmpty && (golonganBaru ?? '').isEmpty) {
      return null;
    }
    return '${golonganLama ?? '-'} \u2192 ${golonganBaru ?? '-'}';
  }

  factory SkSanksi.fromRow(Map<String, dynamic> row) {
    dynamic rawDok = row['dokumen'] ?? const {};
    if (rawDok is String) {
      try {
        rawDok = jsonDecode(rawDok);
      } catch (_) {
        rawDok = const {};
      }
    }
    final rawDokumen = rawDok is Map ? rawDok : const {};
    final dokumen = <JenisDokumenSk, List<String>>{};
    for (final jenis in JenisDokumenSk.values) {
      final list = rawDokumen[jenis.key];
      dokumen[jenis] =
          list is List ? list.map((e) => e.toString()).toList() : <String>[];
    }

    final rawTambahan = rawDokumen[kunciDokumenTambahan];
    final tambahan = rawTambahan is List
        ? rawTambahan
            .whereType<Map>()
            .map(DokumenTambahan.fromJson)
            .where((d) => d.berkas.isNotEmpty)
            .toList()
        : <DokumenTambahan>[];

    return SkSanksi(
      id: (row['id'] as num).toInt(),
      nomorSk: (row['nomor_sk'] ?? '-') as String,
      pengaduanId: (row['pengaduan_id'] as num?)?.toInt(),
      pegawaiId: row['pegawai_id'] as String?,
      nik: (row['nik'] ?? '-') as String,
      namaPegawai: (row['nama_pegawai'] ?? '-') as String,
      jenisSanksi: (row['jenis_sanksi'] ?? '-') as String,
      tingkat: (row['tingkat'] ?? 'Sedang') as String,
      jabatanLama: row['jabatan_lama'] as String?,
      jabatanBaru: row['jabatan_baru'] as String?,
      golonganLama: row['golongan_lama'] as String?,
      golonganBaru: row['golongan_baru'] as String?,
      nominalPenurunanGaji:
          ((row['nominal_penurunan_gaji'] ?? 0) as num).toInt(),
      tanggalBerlaku:
          DateTime.tryParse('${row['tanggal_berlaku']}') ?? DateTime.now(),
      ringkasanPelanggaran: row['ringkasan_pelanggaran'] as String?,
      validasiLisanDirut: (row['validasi_lisan_dirut'] ?? false) as bool,
      disetujuiOleh: row['disetujui_oleh'] as String?,
      tanggalPersetujuanDirut:
          DateTime.tryParse('${row['tanggal_persetujuan_dirut']}'),
      dokumen: dokumen,
      tambahan: tambahan,
      diterbitkanOleh: row['diterbitkan_oleh'] as String?,
      dibuatPada: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() {
    final dokumenMap = <String, dynamic>{
      for (final j in JenisDokumenSk.values) j.key: dokumen[j] ?? const [],
      kunciDokumenTambahan: tambahan.map((d) => d.toJson()).toList(),
    };

    return {
      'id': id,
      'nomor_sk': nomorSk,
      'pengaduan_id': pengaduanId,
      'pegawai_id': pegawaiId,
      'nik': nik,
      'nama_pegawai': namaPegawai,
      'jenis_sanksi': jenisSanksi,
      'tingkat': tingkat,
      'jabatan_lama': jabatanLama,
      'jabatan_baru': jabatanBaru,
      'golongan_lama': golonganLama,
      'golongan_baru': golonganBaru,
      'nominal_penurunan_gaji': nominalPenurunanGaji,
      'tanggal_berlaku': tanggalBerlaku.toIso8601String(),
      'ringkasan_pelanggaran': ringkasanPelanggaran,
      'validasi_lisan_dirut': validasiLisanDirut,
      'disetujui_oleh': disetujuiOleh,
      'tanggal_persetujuan_dirut': tanggalPersetujuanDirut?.toIso8601String(),
      'dokumen': dokumenMap,
      'diterbitkan_oleh': diterbitkanOleh,
      'created_at': dibuatPada.toIso8601String(),
    };
  }
}

class SkSanksiService {
  SkSanksiService._();

  static const bucket = 'sk-sanksi';
  static final List<SkSanksi> _localSkList = [];
  static bool _hasLoadedFromPrefs = false;
  static const String _prefsKey = 'simpeg_sk_sanksi_v2';

  static Future<void> _ensureLoaded() async {
    if (_hasLoadedFromPrefs) return;
    _hasLoadedFromPrefs = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefsKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final sk = SkSanksi.fromRow(Map<String, dynamic>.from(item));
              if (!_localSkList.any((s) => s.nomorSk == sk.nomorSk || s.id == sk.id)) {
                _localSkList.add(sk);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  static Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_localSkList.map((s) => s.toRow()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // Pencarian pegawai terlapor
  // ---------------------------------------------------------------

  /// Mencari pegawai berdasarkan NIK (untuk mengisi jabatan & golongan
  /// lama secara otomatis pada form SK).
  static Future<PegawaiTerlapor?> cariPegawaiByNik(String nik) async {
    try {
      final list = await ApiService.listPegawai(search: nik.trim(), perPage: 1);
      if (list.isNotEmpty) {
        final row = list.first;
        return PegawaiTerlapor(
          id: (row['id'] ?? '').toString(),
          nik: (row['nik'] ?? nik).toString(),
          nama: (row['name'] ?? row['nama'] ?? '-').toString(),
          jabatan: (row['jabatan'] ?? '').toString(),
          golongan: (row['golongan'] ?? '').toString(),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Mencari pegawai berdasarkan nama terlapor (apabila NIK belum terdata di pengaduan).
  static Future<PegawaiTerlapor?> cariPegawaiByNama(String nama) async {
    final clean = nama.trim();
    if (clean.isEmpty) return null;
    try {
      final list = await ApiService.listPegawai(search: clean, perPage: 1);
      if (list.isNotEmpty) {
        final row = list.first;
        return PegawaiTerlapor(
          id: (row['id'] ?? '').toString(),
          nik: (row['nik'] ?? '').toString(),
          nama: (row['name'] ?? row['nama'] ?? clean).toString(),
          jabatan: (row['jabatan'] ?? '').toString(),
          golongan: (row['golongan'] ?? '').toString(),
        );
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------
  // Upload berkas
  // ---------------------------------------------------------------

  /// Mengunggah satu berkas ke bucket dan mengembalikan URL publik/data URI.
  static Future<String> unggahBerkas({
    required String namaFile,
    required Uint8List bytes,
    required JenisDokumenSk jenis,
  }) async {
    return _unggah(namaFile: namaFile, bytes: bytes, folder: jenis.key);
  }

  static Future<String> unggahBerkasTambahan({
    required String namaFile,
    required Uint8List bytes,
  }) async {
    return _unggah(
      namaFile: namaFile,
      bytes: bytes,
      folder: kunciDokumenTambahan,
    );
  }

  static Future<String> _unggah({
    required String namaFile,
    required Uint8List bytes,
    required String folder,
  }) async {
    if (bytes.isNotEmpty) {
      final ext = namaFile.contains('.')
          ? namaFile.split('.').last.toLowerCase()
          : 'pdf';
      String mime = 'application/pdf';
      if (ext == 'doc') {
        mime = 'application/msword';
      } else if (ext == 'docx') {
        mime =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (ext == 'xls') {
        mime = 'application/vnd.ms-excel';
      } else if (ext == 'xlsx') {
        mime =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }
      final safeName = namaFile.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      return 'data:$mime;name=$safeName;base64,${base64Encode(bytes)}';
    }
    return '';
  }

  // ---------------------------------------------------------------
  // Nomor SK
  // ---------------------------------------------------------------

  static Future<String> generateNomorSk() async {
    final now = DateTime.now();
    final prefix = 'SK-${now.year}${now.month.toString().padLeft(2, '0')}';
    return '$prefix-${(DateTime.now().millisecond % 900 + 100)}';
  }

  // ---------------------------------------------------------------
  // Penerbitan SK
  // ---------------------------------------------------------------

  static List<JenisDokumenSk> dokumenBelumLengkap(
    Map<JenisDokumenSk, List<String>> dokumen,
  ) {
    return JenisDokumenSk.values
        .where((j) => (dokumen[j] ?? const []).isEmpty)
        .toList();
  }

  static Future<SkSanksi> terbitkan({
    required String nik,
    required String namaPegawai,
    required String jenisSanksi,
    required String tingkat,
    required Map<JenisDokumenSk, List<String>> dokumen,
    required String diterbitkanOleh,
    List<DokumenTambahan> dokumenTambahan = const [],
    String? pegawaiId,
    int? pengaduanId,
    String? jabatanLama,
    String? jabatanBaru,
    String? golonganLama,
    String? golonganBaru,
    int nominalPenurunanGaji = 0,
    DateTime? tanggalBerlaku,
    String? ringkasanPelanggaran,
    bool validasiLisanDirut = false,
    String? disetujuiOleh,
    DateTime? tanggalPersetujuanDirut,
  }) async {
    final kurang = dokumenBelumLengkap(dokumen);
    if (kurang.isNotEmpty) {
      throw 'Dokumen wajib belum lengkap: '
          '${kurang.map((j) => j.label).join(', ')}.';
    }
    if (nik.trim().isEmpty) {
      throw 'NIK pegawai terlapor wajib diisi.';
    }

    var idPegawai = pegawaiId;
    var jabatanSebelum = jabatanLama;
    var golonganSebelum = golonganLama;
    final pegawai = await cariPegawaiByNik(nik);
    if (pegawai != null) {
      idPegawai ??= pegawai.id;
      if ((jabatanSebelum ?? '').isEmpty) jabatanSebelum = pegawai.jabatan;
      if ((golonganSebelum ?? '').isEmpty) golonganSebelum = pegawai.golongan;
    }

    final berlaku = tanggalBerlaku ?? DateTime.now();
    final tambahanBerisi =
        dokumenTambahan.where((d) => d.berkas.isNotEmpty).toList();

    final nomor = await generateNomorSk();

    final sk = SkSanksi(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      nomorSk: nomor,
      pengaduanId: pengaduanId,
      pegawaiId: idPegawai,
      nik: nik.trim(),
      namaPegawai: namaPegawai,
      jenisSanksi: jenisSanksi,
      tingkat: tingkat,
      jabatanLama: jabatanSebelum,
      jabatanBaru: jabatanBaru,
      golonganLama: golonganSebelum,
      golonganBaru: golonganBaru,
      nominalPenurunanGaji: nominalPenurunanGaji,
      tanggalBerlaku: berlaku,
      ringkasanPelanggaran: ringkasanPelanggaran,
      validasiLisanDirut: validasiLisanDirut,
      disetujuiOleh: disetujuiOleh ?? 'Direktur Utama',
      tanggalPersetujuanDirut: tanggalPersetujuanDirut,
      dokumen: dokumen,
      tambahan: tambahanBerisi,
      diterbitkanOleh: diterbitkanOleh,
      dibuatPada: DateTime.now(),
    );

    await _ensureLoaded();
    _localSkList.removeWhere((s) => s.nomorSk == sk.nomorSk || (pengaduanId != null && s.pengaduanId == pengaduanId));
    _localSkList.insert(0, sk);
    await _saveToPrefs();

    // Simpan juga ke database via API
    try {
      await ApiService.storeSkSanksi(sk.toRow());
    } catch (_) {}

    AuditLogService.logAction(
      userNik: diterbitkanOleh,
      userName: diterbitkanOleh,
      role: 'SDM',
      action: 'CREATE',
      module: 'SK Sanksi',
      description: 'Menerbitkan SK Sanksi ${sk.nomorSk} untuk $namaPegawai (NIK: $nik) — $jenisSanksi $tingkat',
    );

    if (idPegawai != null) {
      await NotificationService.kirimKePegawai(
        pegawaiId: idPegawai,
        judul: 'SK Sanksi diterbitkan',
        pesan: '${sk.nomorSk} — $jenisSanksi'
            '${sk.perubahanJabatan != null ? ' (${sk.perubahanJabatan})' : ''}. '
            'Silakan buka menu Prestasi & Sanksi untuk melihat '
            '${sk.totalBerkas} berkas dokumen pendukung.',
        pengaduanId: pengaduanId,
      );
    }

    if (pengaduanId != null) {
      try {
        final skDocs = dokumen[JenisDokumenSk.sk] ?? const [];
        final fileUtama = skDocs.isNotEmpty ? skDocs.first : '';
        await PengaduanService.sdmSelesaikan(
          pengaduanId: pengaduanId,
          oleh: diterbitkanOleh,
          catatan: 'SK ${sk.nomorSk} diterbitkan — $jenisSanksi'
              '${sk.perubahanJabatan != null ? ' (${sk.perubahanJabatan})' : ''}.',
          nikTerlapor: nik,
          nominalPenurunanGaji:
              nominalPenurunanGaji > 0 ? nominalPenurunanGaji : null,
          nomorSuratPutusan: sk.nomorSk,
          jenisSanksi: jenisSanksi,
          fileSuratPutusan: fileUtama,
          tanggalSuratPutusan: berlaku,
        );
      } catch (_) {}
    }

    return sk;
  }

  // ---------------------------------------------------------------
  // Pembacaan
  // ---------------------------------------------------------------

  static Future<List<SkSanksi>> untukSaya({String? nik}) async {
    await _ensureLoaded();
    try {
      final rows = await ApiService.getSkSanksi(nik: nik);
      if (rows.isNotEmpty) {
        final fetched = rows
            .map((r) => SkSanksi.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList();
        for (final item in fetched) {
          _localSkList.removeWhere(
              (s) => s.id == item.id || s.nomorSk == item.nomorSk);
          _localSkList.insert(0, item);
        }
        await _saveToPrefs();
      }
    } catch (_) {}
    if (nik != null && nik.trim().isNotEmpty) {
      return _localSkList.where((s) => s.nik == nik.trim()).toList();
    }
    return _localSkList;
  }

  static Future<List<SkSanksi>> semua() async {
    await _ensureLoaded();
    try {
      final rows = await ApiService.getSkSanksi();
      if (rows.isNotEmpty) {
        final fetched = rows
            .map((r) => SkSanksi.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList();
        for (final item in fetched) {
          _localSkList.removeWhere(
              (s) => s.id == item.id || s.nomorSk == item.nomorSk);
          _localSkList.insert(0, item);
        }
        await _saveToPrefs();
      }
    } catch (_) {}
    return _localSkList;
  }

  static Future<List<SkSanksi>> untukPengaduan(int pengaduanId) async {
    await _ensureLoaded();
    final localMatches =
        _localSkList.where((s) => s.pengaduanId == pengaduanId).toList();
    if (localMatches.isNotEmpty) {
      return localMatches;
    }

    try {
      final rows = await ApiService.getSkSanksi(pengaduanId: pengaduanId);
      if (rows.isNotEmpty) {
        final fetched = rows
            .map((r) => SkSanksi.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList();
        for (final item in fetched) {
          _localSkList.removeWhere(
              (s) => s.id == item.id || s.nomorSk == item.nomorSk);
          _localSkList.insert(0, item);
        }
        await _saveToPrefs();
        return _localSkList.where((s) => s.pengaduanId == pengaduanId).toList();
      }
    } catch (_) {}

    return localMatches;
  }

  static Future<void> hapus(int id) async {
    await _ensureLoaded();
    _localSkList.removeWhere((s) => s.id == id);
    await _saveToPrefs();
    AuditLogService.logAction(
      userNik: 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'DELETE',
      module: 'SK Sanksi',
      description: 'Menghapus SK Sanksi ID #$id',
    );
  }
}
