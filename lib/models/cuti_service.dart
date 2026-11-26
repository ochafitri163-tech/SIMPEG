import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/audit_log_service.dart';
import 'pengaduan_service.dart' as notif;
import 'user_role.dart';

/// =============================================================
/// PENGAJUAN & PERSETUJUAN CUTI PEGAWAI
/// Disinkronkan penuh dengan modul Web (`CutiController.php`,
/// `cuti/index.blade.php`, dan `cuti/surat.blade.php`).
/// =============================================================

class JenisCutiOption {
  final String value;
  final String subtitle;

  const JenisCutiOption({required this.value, required this.subtitle});
}

enum JenisCuti { cuti, izin, sakit }

extension JenisCutiX on JenisCuti {
  String get label {
    switch (this) {
      case JenisCuti.cuti:
        return 'Cuti Tahunan';
      case JenisCuti.izin:
        return 'Cuti Karena Alasan Penting';
      case JenisCuti.sakit:
        return 'Cuti Sakit';
    }
  }

  static JenisCuti fromName(String n) {
    final lower = n.trim().toLowerCase();
    if (lower.contains('sakit')) return JenisCuti.sakit;
    if (lower.contains('izin') || lower.contains('penting')) return JenisCuti.izin;
    return JenisCuti.cuti;
  }
}

enum StatusCuti { menunggu, disetujui, ditolak }

extension StatusCutiX on StatusCuti {
  String get label {
    switch (this) {
      case StatusCuti.menunggu:
        return 'PENDING';
      case StatusCuti.disetujui:
        return 'DISETUJUI';
      case StatusCuti.ditolak:
        return 'DITOLAK';
    }
  }

  String get displayLabel {
    switch (this) {
      case StatusCuti.menunggu:
        return 'Menunggu Verifikasi';
      case StatusCuti.disetujui:
        return 'Disetujui';
      case StatusCuti.ditolak:
        return 'Ditolak';
    }
  }

  String get serverValue {
    switch (this) {
      case StatusCuti.menunggu:
        return 'PENDING';
      case StatusCuti.disetujui:
        return 'DISETUJUI';
      case StatusCuti.ditolak:
        return 'DITOLAK';
    }
  }

  static StatusCuti fromName(String? n) {
    final clean = (n ?? '').trim().toUpperCase();
    if (clean == 'DISETUJUI' || clean == 'APPROVED') {
      return StatusCuti.disetujui;
    }
    if (clean == 'DITOLAK' || clean == 'REJECTED') {
      return StatusCuti.ditolak;
    }
    return StatusCuti.menunggu;
  }
}

class PejabatSlotCuti {
  final String label;
  final String jabatan;
  final String nama;
  final String nik;

  const PejabatSlotCuti({
    required this.label,
    required this.jabatan,
    required this.nama,
    required this.nik,
  });

  factory PejabatSlotCuti.fromMap(
    Map<String, dynamic>? map, {
    required String defaultLabel,
    required String defaultJabatan,
    required String defaultNama,
    required String defaultNik,
  }) {
    if (map == null) {
      return PejabatSlotCuti(
        label: defaultLabel,
        jabatan: defaultJabatan,
        nama: defaultNama,
        nik: defaultNik,
      );
    }
    String clean(dynamic v, String fb) {
      final s = (v ?? '').toString().trim();
      return s.isNotEmpty ? s : fb;
    }

    return PejabatSlotCuti(
      label: clean(map['label'], defaultLabel),
      jabatan: clean(map['jabatan'], defaultJabatan),
      nama: clean(map['nama'], defaultNama),
      nik: clean(map['nik'], defaultNik),
    );
  }
}

class PejabatTtdCuti {
  final String kota;
  final PejabatSlotCuti pembuat;

  const PejabatTtdCuti({
    this.kota = 'Indramayu',
    this.pembuat = const PejabatSlotCuti(
      label: 'MENGETAHUI / MENGESAHKAN,',
      jabatan: 'Manajer Bidang SDM',
      nama: 'HEDDY KELANA, S.H.',
      nik: '17 11 100',
    ),
  });

  factory PejabatTtdCuti.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PejabatTtdCuti();
    final kota = (map['kota'] ?? 'Indramayu').toString().trim();
    final pembuatMap = map['pembuat'] is Map
        ? Map<String, dynamic>.from(map['pembuat'] as Map)
        : null;
    return PejabatTtdCuti(
      kota: kota.isNotEmpty ? kota : 'Indramayu',
      pembuat: PejabatSlotCuti.fromMap(
        pembuatMap,
        defaultLabel: 'MENGETAHUI / MENGESAHKAN,',
        defaultJabatan: 'Manajer Bidang SDM',
        defaultNama: 'HEDDY KELANA, S.H.',
        defaultNik: '17 11 100',
      ),
    );
  }
}

class CutiSummary {
  final int tahun;
  final int kuotaTahunan;
  final int cutiTahunanTerpakai;
  final int sisaCutiTahunan;
  final int totalPengajuan;
  final int pending;
  final int disetujui;
  final int ditolak;

  const CutiSummary({
    required this.tahun,
    this.kuotaTahunan = 12,
    this.cutiTahunanTerpakai = 0,
    this.sisaCutiTahunan = 12,
    this.totalPengajuan = 0,
    this.pending = 0,
    this.disetujui = 0,
    this.ditolak = 0,
  });

  factory CutiSummary.fromMap(Map<String, dynamic> map) {
    int toInt(dynamic v, [int fb = 0]) =>
        v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? fb);
    return CutiSummary(
      tahun: toInt(map['tahun'], DateTime.now().year),
      kuotaTahunan: toInt(map['kuota_tahunan'], 12),
      cutiTahunanTerpakai: toInt(map['cuti_tahunan_terpakai'], 0),
      sisaCutiTahunan: toInt(map['sisa_cuti_tahunan'], 12),
      totalPengajuan: toInt(map['total_pengajuan'], 0),
      pending: toInt(map['pending'], 0),
      disetujui: toInt(map['disetujui'], 0),
      ditolak: toInt(map['ditolak'], 0),
    );
  }

  factory CutiSummary.fromList(List<PengajuanCuti> items, {int? tahun}) {
    final targetYear = tahun ?? DateTime.now().year;
    var used = 0;
    var pCount = 0;
    var aCount = 0;
    var rCount = 0;

    for (final c in items) {
      if (c.status == StatusCuti.menunggu) {
        pCount++;
      } else if (c.status == StatusCuti.disetujui) {
        aCount++;
        final j = c.jenis.toLowerCase();
        if ((j.contains('tahunan') || j == 'cuti') &&
            c.tanggalMulai.year == targetYear) {
          used += c.jumlahHari;
        }
      } else if (c.status == StatusCuti.ditolak) {
        rCount++;
      }
    }

    const kuota = 12;
    return CutiSummary(
      tahun: targetYear,
      kuotaTahunan: kuota,
      cutiTahunanTerpakai: used,
      sisaCutiTahunan: (kuota - used).clamp(0, kuota),
      totalPengajuan: items.length,
      pending: pCount,
      disetujui: aCount,
      ditolak: rCount,
    );
  }
}

class CutiFetchResult {
  final List<PengajuanCuti> items;
  final CutiSummary summary;
  final PejabatTtdCuti pejabatTtd;

  const CutiFetchResult({
    required this.items,
    required this.summary,
    this.pejabatTtd = const PejabatTtdCuti(),
  });
}

class PengajuanCuti {
  final int id;
  final String pegawaiId;
  final String nik;
  final String namaPegawai;
  final String unitKerja;
  final String jabatan;
  final String golongan;
  final String jenis;
  final String noSurat;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final int durasiHari;
  final String alasan;
  final String alamatCuti;
  final String noTelp;
  final StatusCuti status;
  final String? diputuskanOleh;
  final String? catatanApprover;
  final DateTime tanggalSurat;
  final DateTime dibuatPada;

  const PengajuanCuti({
    required this.id,
    required this.pegawaiId,
    this.nik = '-',
    required this.namaPegawai,
    this.unitKerja = 'Kantor Pusat',
    this.jabatan = 'Staf',
    this.golongan = 'PT',
    required this.jenis,
    this.noSurat = '-',
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.durasiHari = 1,
    required this.alasan,
    this.alamatCuti = '-',
    this.noTelp = '-',
    required this.status,
    required this.dibuatPada,
    DateTime? tanggalSurat,
    this.diputuskanOleh,
    this.catatanApprover,
  }) : tanggalSurat = tanggalSurat ?? dibuatPada;

  int get jumlahHari => durasiHari > 0
      ? durasiHari
      : (tanggalSelesai.difference(tanggalMulai).inDays + 1).clamp(1, 365);

  static String formatJenisLabel(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return 'Cuti Tahunan';
    switch (clean.toLowerCase()) {
      case 'cuti':
        return 'Cuti Tahunan';
      case 'izin':
        return 'Cuti Karena Alasan Penting';
      case 'sakit':
        return 'Cuti Sakit';
      default:
        return clean;
    }
  }

  static String _bulanRomawi(int bulan) {
    const romawi = [
      '',
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
      'XI',
      'XII',
    ];
    if (bulan >= 1 && bulan <= 12) return romawi[bulan];
    return 'I';
  }

  factory PengajuanCuti.fromRow(Map<String, dynamic> row) {
    DateTime parseDate(dynamic v, [DateTime? fallback]) {
      if (v == null) return fallback ?? DateTime.now();
      return DateTime.tryParse(v.toString()) ?? (fallback ?? DateTime.now());
    }

    final created = parseDate(row['created_at']);
    final mulai = parseDate(row['tanggal_mulai'], created);
    final selesai = parseDate(row['tanggal_selesai'], mulai);
    final rawDurasi = row['durasi_hari'];
    final calcDurasi = (selesai.difference(mulai).inDays + 1).clamp(1, 365);
    final durasi = rawDurasi is num
        ? rawDurasi.toInt().clamp(1, 365)
        : (int.tryParse(rawDurasi?.toString() ?? '') ?? calcDurasi);

    final idVal = row['id'] is num
        ? (row['id'] as num).toInt()
        : (int.tryParse(row['id']?.toString() ?? '') ?? 0);

    final rawNoSurat = (row['no_surat'] ?? '').toString().trim();
    final noSurat = rawNoSurat.isNotEmpty
        ? rawNoSurat
        : '850/${idVal.toString().padLeft(3, '0')}/SDM/${_bulanRomawi(mulai.month)}/${mulai.year}';

    final rawCatatan = row['catatan_approver']?.toString().trim();
    final rawApprover = row['diputuskan_oleh']?.toString().trim();

    return PengajuanCuti(
      id: idVal,
      pegawaiId: (row['pegawai_id'] ?? '').toString(),
      nik: (row['nik'] ?? row['pegawai_nik'] ?? '-').toString(),
      namaPegawai: (row['nama_pegawai'] ?? row['nama'] ?? row['nama_lengkap'] ?? 'Pegawai')
          .toString(),
      unitKerja: (row['unit_kerja'] ?? 'Kantor Pusat').toString(),
      jabatan: (row['jabatan'] ?? 'Staf').toString(),
      golongan: (row['golongan'] ?? 'PT').toString(),
      jenis: formatJenisLabel((row['jenis'] ?? 'Cuti Tahunan').toString()),
      noSurat: noSurat,
      tanggalMulai: mulai,
      tanggalSelesai: selesai,
      durasiHari: durasi,
      alasan: (row['alasan'] ?? '-').toString(),
      alamatCuti: (row['alamat_cuti'] ?? '-').toString(),
      noTelp: (row['no_telp'] ?? '-').toString(),
      status: StatusCutiX.fromName(row['status']?.toString()),
      diputuskanOleh:
          (rawApprover == null || rawApprover.isEmpty || rawApprover == '-')
              ? null
              : rawApprover,
      catatanApprover:
          (rawCatatan == null || rawCatatan.isEmpty || rawCatatan == '-')
              ? null
              : rawCatatan,
      tanggalSurat: parseDate(row['tanggal_surat'], created),
      dibuatPada: created,
    );
  }
}

class CutiSuratResult {
  final PengajuanCuti cuti;
  final PejabatTtdCuti pejabatTtd;

  const CutiSuratResult({
    required this.cuti,
    this.pejabatTtd = const PejabatTtdCuti(),
  });
}

class CutiService {
  CutiService._();

  /// Pilihan Jenis Izin Cuti sesuai Web (`cuti/index.blade.php`)
  static const List<JenisCutiOption> jenisOptions = [
    JenisCutiOption(
      value: 'Cuti Tahunan',
      subtitle: 'Maksimal 12 Hari Kerja per tahun',
    ),
    JenisCutiOption(
      value: 'Cuti Sakit',
      subtitle: 'Disertai Surat Keterangan Dokter',
    ),
    JenisCutiOption(
      value: 'Cuti Bersalin',
      subtitle: 'Hamil / Melahirkan',
    ),
    JenisCutiOption(
      value: 'Cuti Karena Alasan Penting',
      subtitle: 'Keluarga Sakit Keras / Meninggal / Menikah',
    ),
    JenisCutiOption(
      value: 'Cuti Besar',
      subtitle: 'Masa Kerja Lebih Dari 5 Tahun',
    ),
  ];

  /// Role yang berwenang menyetujui/menolak/mengelola cuti pegawai (sama dengan Web Role 1 & 7).
  static const List<UserRole> roleApprover = [UserRole.sdm, UserRole.direktur];

  static bool canApprove(AppUser user) {
    return user.role == UserRole.sdm ||
        user.role == UserRole.direktur ||
        user.isManajerSdm;
  }

  /// Hook uji coba agar widget test berjalan cepat & deterministik tanpa server hidup.
  @visibleForTesting
  static Future<CutiFetchResult> Function({
    String? nik,
    bool all,
    int? tahun,
    String? status,
  })? fetchOverride;

  @visibleForTesting
  static Future<void> Function({
    required PengajuanCuti pengajuan,
    required StatusCuti keputusan,
    required String namaApprover,
    String? catatan,
  })? statusOverride;

  @visibleForTesting
  static Future<CutiSuratResult> Function(dynamic id, {PengajuanCuti? fallback})?
      suratOverride;

  @visibleForTesting
  static void resetForTest() {
    fetchOverride = null;
    statusOverride = null;
    suratOverride = null;
  }

  static String _tgl(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Mengambil daftar cuti + ringkasan kuota + pejabat TTD dari backend Laravel.
  static Future<CutiFetchResult> fetchCuti({
    String? nik,
    bool all = false,
    int? tahun,
    String? status,
  }) async {
    if (fetchOverride != null) {
      return fetchOverride!(nik: nik, all: all, tahun: tahun, status: status);
    }

    try {
      final res = await ApiService.getCuti(
        nik: nik,
        all: all,
        tahun: tahun,
        status: status,
      );
      if (res['success'] == true && res['data'] is List) {
        final items = (res['data'] as List)
            .map((r) => PengajuanCuti.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList();

        final meta = res['meta'] is Map
            ? Map<String, dynamic>.from(res['meta'] as Map)
            : const <String, dynamic>{};

        final summary = meta['summary'] is Map
            ? CutiSummary.fromMap(Map<String, dynamic>.from(meta['summary'] as Map))
            : CutiSummary.fromList(items, tahun: tahun);

        final pejabat = meta['pejabat_ttd'] is Map
            ? PejabatTtdCuti.fromMap(
                Map<String, dynamic>.from(meta['pejabat_ttd'] as Map))
            : const PejabatTtdCuti();

        return CutiFetchResult(
          items: items,
          summary: summary,
          pejabatTtd: pejabat,
        );
      }
    } catch (e) {
      debugPrint('Error fetchCuti: $e');
    }

    return CutiFetchResult(
      items: const [],
      summary: CutiSummary.fromList(const [], tahun: tahun),
    );
  }

  /// Mengambil detail resmi Surat Izin Cuti + pejabat TTD dinamis.
  static Future<CutiSuratResult> fetchSurat(
    dynamic id, {
    PengajuanCuti? fallback,
  }) async {
    if (suratOverride != null) {
      return suratOverride!(id, fallback: fallback);
    }

    try {
      final res = await ApiService.getCutiSurat(id);
      if (res['success'] == true && res['data'] is Map) {
        final map = Map<String, dynamic>.from(res['data'] as Map);
        final cuti = PengajuanCuti.fromRow(map);
        final pejabat = map['pejabat_ttd'] is Map
            ? PejabatTtdCuti.fromMap(
                Map<String, dynamic>.from(map['pejabat_ttd'] as Map))
            : const PejabatTtdCuti();
        return CutiSuratResult(cuti: cuti, pejabatTtd: pejabat);
      }
    } catch (e) {
      debugPrint('Error fetchSurat: $e');
    }

    if (fallback != null) {
      return CutiSuratResult(cuti: fallback);
    }
    throw Exception('Data surat cuti tidak ditemukan.');
  }

  /// Daftar pengajuan milik user login.
  static Future<List<PengajuanCuti>> milikSaya({
    String? nik,
    int? tahun,
    String? status,
  }) async {
    final res = await fetchCuti(nik: nik, tahun: tahun, status: status);
    return res.items;
  }

  /// Approver — seluruh pengajuan (opsional filter status/tahun).
  static Future<List<PengajuanCuti>> semua({
    bool hanyaMenunggu = false,
    int? tahun,
    String? status,
  }) async {
    final res = await fetchCuti(
      all: true,
      tahun: tahun,
      status: hanyaMenunggu ? 'PENDING' : status,
    );
    if (hanyaMenunggu) {
      return res.items.where((c) => c.status == StatusCuti.menunggu).toList();
    }
    return res.items;
  }

  /// Approver — setujui / tolak / edit status pengajuan + catatan approver.
  static Future<void> putuskan({
    required PengajuanCuti pengajuan,
    required StatusCuti keputusan,
    required String namaApprover,
    String? catatan,
  }) async {
    if (statusOverride != null) {
      return statusOverride!(
        pengajuan: pengajuan,
        keputusan: keputusan,
        namaApprover: namaApprover,
        catatan: catatan,
      );
    }

    final statusStr = keputusan.serverValue;
    final res = await ApiService.updateStatusCuti(
      pengajuan.id,
      statusStr,
      catatan: catatan,
    );

    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Gagal memperbarui status cuti.');
    }

    AuditLogService.logAction(
      userNik: 'APPROVER',
      userName: namaApprover,
      role: 'SDM/DIREKTUR',
      action: 'UPDATE',
      module: 'Cuti',
      description:
          'Memutuskan pengajuan ${pengajuan.jenis} #${pengajuan.id} milik ${pengajuan.namaPegawai} menjadi ${keputusan.displayLabel}',
    );

    try {
      await notif.NotificationService.kirimKePegawai(
        pegawaiId: pengajuan.pegawaiId,
        judul: keputusan == StatusCuti.disetujui
            ? '${pengajuan.jenis} Disetujui'
            : '${pengajuan.jenis} Ditolak',
        pesan: 'Pengajuan ${pengajuan.jenis.toLowerCase()} Anda '
            '(${_tgl(pengajuan.tanggalMulai)} s/d ${_tgl(pengajuan.tanggalSelesai)}) '
            '${keputusan.displayLabel.toLowerCase()} oleh $namaApprover.',
      );
    } catch (_) {}
  }
}
