import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'pengaduan_model.dart';
import 'pengaduan_service.dart';

/// =============================================================
/// B10 — SK SANKSI (Surat Keputusan)
///
/// Alur bisnis:
///   Pelanggaran terbukti -> SPI/KSPI input lampiran hasil investigasi ->
///   SDM validasi (lisan) ke DIRUT -> DIRUT setuju -> SDM menerbitkan SK
///   (mis. turun jabatan Asmen -> Staf) -> payroll otomatis menyesuaikan ->
///   pegawai terlapor menerima paket dokumen di aplikasinya.
///
/// EMPAT DOKUMEN WAJIB yang diterima pegawai terlapor:
///   1. SK (surat keputusan sanksi/turun jabatan)
///   2. Bukti pelanggaran
///   3. Surat hasil investigasi SPI (KSPI)
///   4. Surat keputusan direksi (DIRUT)
///
/// Jumlah FILE bebas — satu file boleh memuat empat dokumen sekaligus,
/// atau dipisah 4–5 file. Yang divalidasi adalah keempat JENIS dokumen
/// di atas minimal punya satu berkas.
///
/// Skema tabel: supabase/sk_sanksi.sql
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
  bool get dokumenLengkap => JenisDokumenSk.values
      .every((j) => (dokumen[j] ?? const []).isNotEmpty);

  /// Total berkas dari seluruh dokumen wajib + tambahan (jumlah file bebas).
  int get totalBerkas =>
      dokumen.values.fold<int>(0, (acc, list) => acc + list.length) +
      tambahan.fold<int>(0, (acc, d) => acc + d.berkas.length);

  /// True kalau SDM melampirkan dokumen pendukung di luar yang wajib.
  bool get adaDokumenTambahan =>
      tambahan.any((d) => d.berkas.isNotEmpty);

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
    final rawDokumen = (row['dokumen'] ?? const {}) as Map;
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
}

class SkSanksiService {
  SkSanksiService._();

  static final _client = Supabase.instance.client;
  static const _table = 'sk_sanksi';
  static const bucket = 'sk-sanksi';

  // ---------------------------------------------------------------
  // Pencarian pegawai terlapor
  // ---------------------------------------------------------------

  /// Mencari pegawai berdasarkan NIK (untuk mengisi jabatan & golongan
  /// lama secara otomatis pada form SK).
  static Future<PegawaiTerlapor?> cariPegawaiByNik(String nik) async {
    final rows = await _client
        .from('pegawai')
        .select('id, name, nik, jabatan, golongan')
        .eq('nik', nik.trim())
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final row = list.first as Map<String, dynamic>;
    return PegawaiTerlapor(
      id: row['id'] as String,
      nik: (row['nik'] ?? nik) as String,
      nama: (row['name'] ?? '-') as String,
      jabatan: (row['jabatan'] ?? '') as String,
      golongan: (row['golongan'] ?? '') as String,
    );
  }

  // ---------------------------------------------------------------
  // Upload berkas
  // ---------------------------------------------------------------

  /// Mengunggah satu berkas ke bucket `sk-sanksi` dan mengembalikan URL
  /// publiknya. Jumlah berkas per jenis dokumen tidak dibatasi.
  static Future<String> unggahBerkas({
    required String namaFile,
    required Uint8List bytes,
    required JenisDokumenSk jenis,
  }) async {
    return _unggah(namaFile: namaFile, bytes: bytes, folder: jenis.key);
  }

  /// Mengunggah berkas untuk dokumen TAMBAHAN (di luar empat dokumen wajib).
  /// SDM bebas menambahkan berapa pun dokumen pendukung lain.
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
    final aman = namaFile.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}_$aman';
    await _client.storage.from(bucket).uploadBinary(path, bytes);
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  // ---------------------------------------------------------------
  // Nomor SK
  // ---------------------------------------------------------------

  /// Nomor SK berformat SK-YYYYMM-NNN, urut dari nomor terbesar bulan ini.
  static Future<String> generateNomorSk() async {
    final now = DateTime.now();
    final prefix = 'SK-${now.year}${now.month.toString().padLeft(2, '0')}';
    final rows = await _client
        .from(_table)
        .select('nomor_sk')
        .like('nomor_sk', '$prefix%');
    var maks = 0;
    for (final r in (rows as List)) {
      final bagian = '${r['nomor_sk']}'.split('-');
      if (bagian.length >= 3) {
        final n = int.tryParse(bagian[2]);
        if (n != null && n > maks) maks = n;
      }
    }
    return '$prefix-${(maks + 1).toString().padLeft(3, '0')}';
  }

  // ---------------------------------------------------------------
  // Penerbitan SK
  // ---------------------------------------------------------------

  /// Validasi kelengkapan empat jenis dokumen wajib. Mengembalikan daftar
  /// jenis dokumen yang masih kosong (kosong berarti sudah lengkap).
  static List<JenisDokumenSk> dokumenBelumLengkap(
    Map<JenisDokumenSk, List<String>> dokumen,
  ) {
    return JenisDokumenSk.values
        .where((j) => (dokumen[j] ?? const []).isEmpty)
        .toList();
  }

  /// SDM — menerbitkan SK sanksi.
  ///
  /// Rangkaian efeknya:
  /// 1. Validasi keempat jenis dokumen wajib.
  /// 2. Simpan SK + seluruh lampiran (jumlah file bebas).
  /// 3. Perbarui jabatan/golongan pegawai bila SK berisi penurunan.
  /// 4. Terapkan penurunan gaji ke payroll periode terbaru.
  /// 5. Catat di riwayat `sanksi` pegawai.
  /// 6. Kirim notifikasi ke pegawai terlapor.
  /// 7. Bila SK berasal dari sebuah pengaduan, pengaduan ditandai selesai.
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
    // 1. Validasi dokumen wajib.
    final kurang = dokumenBelumLengkap(dokumen);
    if (kurang.isNotEmpty) {
      throw 'Dokumen wajib belum lengkap: '
          '${kurang.map((j) => j.label).join(', ')}.';
    }
    if (nik.trim().isEmpty) {
      throw 'NIK pegawai terlapor wajib diisi.';
    }

    // Lengkapi identitas pegawai dari tabel `pegawai` bila belum ada.
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
    // Empat kunci wajib + daftar dokumen tambahan (boleh kosong).
    final tambahanBerisi =
        dokumenTambahan.where((d) => d.berkas.isNotEmpty).toList();
    final dokumenJson = <String, dynamic>{
      for (final j in JenisDokumenSk.values) j.key: dokumen[j] ?? const [],
      kunciDokumenTambahan:
          tambahanBerisi.map((d) => d.toJson()).toList(growable: false),
    };

    // 2. Simpan SK (nomor diulang bila bentrok unique constraint).
    Map<String, dynamic>? inserted;
    var nomor = await generateNomorSk();
    for (var percobaan = 0; percobaan < 5; percobaan++) {
      try {
        inserted = await _client
            .from(_table)
            .insert({
              'nomor_sk': nomor,
              'pengaduan_id': pengaduanId,
              'pegawai_id': idPegawai,
              'nik': nik.trim(),
              'nama_pegawai': namaPegawai,
              'jenis_sanksi': jenisSanksi,
              'tingkat': tingkat,
              'jabatan_lama': jabatanSebelum,
              'jabatan_baru': jabatanBaru,
              'golongan_lama': golonganSebelum,
              'golongan_baru': golonganBaru,
              'nominal_penurunan_gaji': nominalPenurunanGaji,
              'tanggal_berlaku': berlaku.toIso8601String().substring(0, 10),
              'ringkasan_pelanggaran': ringkasanPelanggaran,
              'validasi_lisan_dirut': validasiLisanDirut,
              'disetujui_oleh': disetujuiOleh,
              'tanggal_persetujuan_dirut':
                  tanggalPersetujuanDirut?.toIso8601String(),
              'dokumen': dokumenJson,
              'diterbitkan_oleh': diterbitkanOleh,
            })
            .select()
            .single();
        break;
      } on PostgrestException catch (e) {
        final bentrok = e.code == '23505' && '${e.message}'.contains('nomor_sk');
        if (!bentrok || percobaan == 4) rethrow;
        nomor = await generateNomorSk();
        if (percobaan >= 1) {
          nomor =
              '$nomor-${100 + (DateTime.now().microsecondsSinceEpoch % 900)}';
        }
      }
    }
    if (inserted == null) {
      throw 'Gagal membuat nomor SK yang unik.';
    }
    final sk = SkSanksi.fromRow(inserted);

    // 3. Perbarui jabatan/golongan pegawai (turun jabatan).
    if (idPegawai != null &&
        ((jabatanBaru ?? '').isNotEmpty || (golonganBaru ?? '').isNotEmpty)) {
      try {
        await _client.from('pegawai').update({
          if ((jabatanBaru ?? '').isNotEmpty) 'jabatan': jabatanBaru,
          if ((golonganBaru ?? '').isNotEmpty) 'golongan': golonganBaru,
        }).eq('id', idPegawai);
      } catch (_) {
        // Kolom jabatan/golongan belum tersedia di skema — SK tetap terbit.
      }
    }

    // 4. Penurunan jabatan berarti payment ikut berkurang.
    if (nominalPenurunanGaji > 0) {
      try {
        await PengaduanService.turunkanGajiPayroll(
          nik: nik.trim(),
          nominal: nominalPenurunanGaji,
          pengaduanId: pengaduanId,
        );
      } catch (_) {
        // Data payroll belum ada — SK tetap terbit, penyesuaian menyusul.
      }
    }

    // 5. Catat di riwayat sanksi pegawai.
    if (idPegawai != null) {
      try {
        await _client.from('sanksi').insert({
          'pegawai_id': idPegawai,
          'jenis_sanksi': jenisSanksi,
          'tanggal': formatTanggalIndonesia(berlaku),
          'tingkat': tingkat,
          'keterangan': [
            'SK ${sk.nomorSk}',
            if (sk.perubahanJabatan != null) 'Jabatan: ${sk.perubahanJabatan}',
            if ((ringkasanPelanggaran ?? '').isNotEmpty) ringkasanPelanggaran,
          ].whereType<String>().join(' \u00b7 '),
          'sk_sanksi_id': sk.id,
        });
      } catch (_) {
        // Tabel `sanksi` opsional.
      }
    }

    // 6. Beri tahu pegawai terlapor bahwa SK & dokumennya sudah terbit.
    if (idPegawai != null) {
      await NotificationService.kirimKePegawai(
        pegawaiId: idPegawai,
        judul: 'SK Sanksi diterbitkan',
        pesan: '${sk.nomorSk} \u2014 $jenisSanksi'
            '${sk.perubahanJabatan != null ? ' (${sk.perubahanJabatan})' : ''}. '
            'Silakan buka menu Prestasi & Sanksi untuk melihat '
            '${sk.totalBerkas} berkas dokumen pendukung.',
        pengaduanId: pengaduanId,
      );
    }

    // 7. Tutup pengaduan asal bila ada.
    if (pengaduanId != null) {
      try {
        await PengaduanService.sdmSelesaikan(
          pengaduanId: pengaduanId,
          oleh: diterbitkanOleh,
          catatan: 'SK ${sk.nomorSk} diterbitkan \u2014 $jenisSanksi'
              '${sk.perubahanJabatan != null ? ' (${sk.perubahanJabatan})' : ''}.',
        );
      } catch (_) {
        // Pengaduan mungkin sudah berstatus selesai.
      }
    }

    return sk;
  }

  // ---------------------------------------------------------------
  // Pembacaan
  // ---------------------------------------------------------------

  /// SK milik pegawai yang sedang login.
  static Future<List<SkSanksi>> untukSaya() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .eq('pegawai_id', uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SkSanksi.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Seluruh SK (SDM/KSPI/DIRUT).
  static Future<List<SkSanksi>> semua() async {
    final rows =
        await _client.from(_table).select().order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SkSanksi.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// SK yang terbit dari satu pengaduan tertentu.
  static Future<List<SkSanksi>> untukPengaduan(int pengaduanId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('pengaduan_id', pengaduanId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SkSanksi.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> hapus(int id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}