import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';
import 'pengaduan_model.dart';

/// Mengubah satu baris hasil query Supabase (Map) menjadi object
/// [Pengaduan], supaya UI yang sudah ada (getter status.label/.color/.icon,
/// dst) tetap berfungsi tanpa perlu diubah.
Pengaduan pengaduanFromRow(
  Map<String, dynamic> row, {
  List<StatusHistoryEntry> riwayat = const [],
}) {
  PengaduanStatus parseStatus(String? s) {
    return PengaduanStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PengaduanStatus.menungguKadiv,
    );
  }

  Keputusan? parseKeputusan(String? s) {
    if (s == null) return null;
    return Keputusan.values.firstWhere((e) => e.name == s);
  }

  KategoriDivisi? parseKategoriDivisi(String? s) {
    if (s == null) return null;
    return KategoriDivisi.values.firstWhere(
      (e) => e.name == s,
      orElse: () => KategoriDivisi.devAdmin,
    );
  }

  Eksekutor? parseEksekutor(String? s) {
    if (s == null) return null;
    return Eksekutor.values.firstWhere((e) => e.name == s);
  }

  final pengaduan = Pengaduan(
    tindakLanjutDiminta: row['tindak_lanjut_diminta'] as String?,
    alasanPenolakanDirektur: row['alasan_penolakan_direktur'] as String?,
    catatanPeninjauanKembali: row['catatan_peninjauan_kembali'] as String?,
    catatanReviewHasilKspi: row['catatan_review_hasil_kspi'] as String?,
    kategoriDivisi: parseKategoriDivisi(row['kategori_divisi'] as String?),
    nomorPengaduan: row['nomor_pengaduan'] as String,
    kategori: row['kategori'] as String,
    judul: row['judul'] as String,
    deskripsi: row['deskripsi'] as String,
    tanggalPengaduan: DateTime.parse(row['tanggal_pengaduan'] as String),
    namaPegawai: row['nama_pegawai'] as String,
    nik: row['nik'] as String,
    cabang: (row['cabang'] ?? '') as String,
    golongan: (row['golongan'] ?? '') as String,
    anonim: (row['anonim'] ?? false) as bool,
    status: parseStatus(row['status'] as String?),
    fotoBukti: List<String>.from(row['foto_bukti'] ?? const []),
    dokumenPendukung: List<String>.from(row['dokumen_pendukung'] ?? const []),
    riwayatStatus: riwayat,
    keputusanKadiv: parseKeputusan(row['keputusan_kadiv'] as String?),
    catatanKadiv: row['catatan_kadiv'] as String?,
    keputusanDirutTahap1:
        parseKeputusan(row['keputusan_dirut_tahap1'] as String?),
    catatanDirutTahap1: row['catatan_dirut_tahap1'] as String?,
    eksekutor: parseEksekutor(row['eksekutor'] as String?),
    petugasInvestigasi: row['petugas_investigasi'] as String?,
    hasilInvestigasi: row['hasil_investigasi'] as String?,
    suratRekomendasi: row['surat_rekomendasi'] as String?,
    tanggalHasilInvestigasi: row['tanggal_hasil_investigasi'] != null
        ? DateTime.parse(row['tanggal_hasil_investigasi'] as String)
        : null,
    keputusanDirutTahap2:
        parseKeputusan(row['keputusan_dirut_tahap2'] as String?),
    catatanDirutTahap2: row['catatan_dirut_tahap2'] as String?,
    eksekutorTindakLanjut:
        parseEksekutor(row['eksekutor_tindak_lanjut'] as String?),
    catatanTindakLanjutSelesai: row['catatan_tindak_lanjut_selesai'] as String?,
    catatanSdm: row['catatan_sdm'] as String?,
    arsipPadaTahap: row['arsip_pada_tahap'] as String?,
    alasanArsip: row['alasan_arsip'] as String?,
  );

  _pengaduanIdMap[pengaduan] = row['id'] as int;
  return pengaduan;
}

final Map<Pengaduan, int> _pengaduanIdMap = {};

extension PengaduanIdX on Pengaduan {
  int? get supabaseId => _pengaduanIdMap[this];
}

/// =============================================================
/// PengaduanService — semua method query langsung ke tabel
/// `pengaduan_pegawai`, `riwayat_status_pengaduan`, dan `notifikasi` di
/// Supabase. Alur baru (lihat pengaduan_model.dart untuk detail status):
///
/// Pegawai submit -> Kadiv (terima/tolak) -> [otomatis] Dirut tahap 1
/// (terima/tolak) -> KSPI pilih eksekutor -> investigasi -> Direksi
/// tahap 2 (terima/tolak) -> pilih eksekutor tindak lanjut -> tindak
/// lanjut -> SDM -> selesai. Tolak di titik manapun -> arsip.
///
/// CATATAN SKEMA TABEL `pegawai`: perlu kolom `divisi_kadiv` (nilai
/// 'administrasi' / 'teknik', hanya diisi untuk role kadivKategori) agar
/// notifikasi pengaduan baru hanya terkirim ke Kadiv yang relevan.
/// =============================================================
class PengaduanService {
  PengaduanService._();

  static final _client = Supabase.instance.client;

  static Future<String> generateNomorPengaduan() async {
    final now = DateTime.now();
    final prefix = 'PGD-${now.year}${now.month.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('pengaduan_pegawai')
        .select('id')
        .like('nomor_pengaduan', '$prefix%');
    final urut = ((rows as List).length + 1).toString().padLeft(3, '0');
    return '$prefix-$urut';
  }

  /// KADIV — verifikasi & kategorisasi, teruskan ke KSPI.
  static Future<void> verifikasiKadiv({
    required int pengaduanId,
    required String oleh,
    required String kategoriDivisi,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguVerifikasiKadiv.name,
      statusBaru: PengaduanStatus.reviewKspi.name,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Verifikasi & kategorisasi, diteruskan ke KSPI',
      catatan: catatan,
      kolomTambahan: {'kategori_divisi': kategoriDivisi},
    );
  }

  /// KSPI — review awal & pilih eksekutor investigasi.
  static Future<void> reviewDanPilihEksekutor({
    required int pengaduanId,
    required String oleh,
    required String eksekutor, // 'kadiv' | 'tpdpk'
    String? petugas,
    String? catatan,
  }) async {
    final statusBaru = eksekutor == 'tpdpk'
        ? PengaduanStatus.menungguInvestigasi.name
        : PengaduanStatus.investigasiBerjalan.name;
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.reviewKspi.name,
      statusBaru: statusBaru,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Review & memilih eksekutor: $eksekutor',
      catatan: catatan,
      kolomTambahan: {
        'eksekutor': eksekutor,
        'petugas_investigasi': petugas,
      },
    );
  }

  /// KSPI — review hasil investigasi. Sesuai -> Direktur, tidak -> revisi.
  static Future<void> reviewHasilInvestigasi({
    required int pengaduanId,
    required String oleh,
    required bool sesuai,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguReviewKspi.name,
      statusBaru: sesuai
          ? PengaduanStatus.menungguDirutTahap2.name
          : PengaduanStatus.revisiInvestigasi.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: sesuai
          ? 'Hasil investigasi sesuai, diteruskan ke Direktur'
          : 'Hasil investigasi dikembalikan untuk revisi',
      catatan: catatan,
      kolomTambahan: {'catatan_review_hasil_kspi': catatan},
    );
  }

  /// KSPI — kirim ulang setelah ditolak Direktur.
  static Future<void> kirimUlangSetelahRevisiKspi({
    required int pengaduanId,
    required String oleh,
    required String catatanRevisi,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.ditolakDirektur.name,
      statusBaru: PengaduanStatus.menungguDirutTahap2.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Revisi setelah penolakan Direktur, dikirim ulang',
      catatan: catatanRevisi,
    );
  }

  /// KSPI — kirim untuk investigasi ulang (peninjauan kembali).
  static Future<void> kirimUntukInvestigasiUlang({
    required int pengaduanId,
    required String oleh,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.peninjauanKembali.name,
      statusBaru: PengaduanStatus.revisiInvestigasi.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Dikirim untuk investigasi ulang (peninjauan kembali)',
      catatan: catatan,
    );
  }

  /// TPDPK — tetapkan petugas & mulai investigasi.
  static Future<void> tpdpkPilihPetugas({
    required int pengaduanId,
    required String oleh,
    required String petugas,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguInvestigasi.name,
      statusBaru: PengaduanStatus.investigasiBerjalan.name,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Menetapkan petugas investigasi',
      kolomTambahan: {'petugas_investigasi': petugas},
    );
  }

  /// TPDPK — kirim ulang hasil investigasi (revisi) ke KSPI.
  static Future<void> kirimRevisiInvestigasi({
    required int pengaduanId,
    required String oleh,
    required String hasil,
    required String rekomendasi,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.revisiInvestigasi.name,
      statusBaru: PengaduanStatus.menungguReviewKspi.name,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Mengirim ulang hasil investigasi (revisi)',
      kolomTambahan: {
        'hasil_investigasi': hasil,
        'surat_rekomendasi': rekomendasi,
        'tanggal_hasil_investigasi': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Submit pengaduan baru oleh pegawai. Kategori pengaduan (dipilih
  /// pegawai di form) menentukan Kadiv divisi mana yang diberi notifikasi.
  static Future<void> submit({
    required AppUser user,
    required String kategori,
    required String judul,
    required String deskripsi,
    List<String> fotoBukti = const [],
    bool anonim = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User belum login');
    }

    final nomor = await generateNomorPengaduan();

    final inserted = await _client
        .from('pengaduan_pegawai')
        .insert({
          'nomor_pengaduan': nomor,
          'pelapor_id': userId,
          'kategori': kategori,
          'judul': judul,
          'deskripsi': deskripsi,
          'nama_pegawai': user.name,
          'nik': user.nik,
          'cabang': user.unitKerja,
          'golongan': user.golongan,
          'anonim': anonim,
          'foto_bukti': fotoBukti,
          'status': PengaduanStatus.menungguVerifikasiKadiv.name,
        })
        .select()
        .single();

    final pengaduanId = inserted['id'] as int;

    await _client.from('riwayat_status_pengaduan').insert({
      'pengaduan_id': pengaduanId,
      'status': PengaduanStatus.menungguKadiv.name,
      'status_lama': null,
      'oleh': 'Sistem',
      'aksi': 'Pengaduan dibuat',
    });

    // Notifikasi hanya ke Kadiv divisi yang sesuai kategori.
    final divisi = divisiKadivDariKategori(kategori);
    var kadivQuery = _client
        .from('pegawai')
        .select('id')
        .eq('role', UserRole.kadivKategori.name);
    if (divisi != null) {
      kadivQuery = kadivQuery.eq('divisi_kadiv', divisi.name);
    }
    final kadivList = await kadivQuery;

    for (final kadiv in (kadivList as List)) {
      await _client.from('notifikasi').insert({
        'untuk_pegawai_id': kadiv['id'],
        'judul': 'Pengaduan baru masuk',
        'pesan': '${user.name} membuat pengaduan baru ($nomor).',
        'pengaduan_id': pengaduanId,
      });
    }
  }

  static Future<List<Map<String, dynamic>>> punyaSaya() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from('pengaduan_pegawai')
        .select()
        .eq('pelapor_id', userId)
        .order('tanggal_pengaduan', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<List<Map<String, dynamic>>> untukRole(
    UserRole role, {
    String? divisiKadiv,
  }) async {
    var query = _client.from('pengaduan_pegawai').select();

    switch (role) {
      case UserRole.kadivKategori:
        query = query.or(
          'status.eq.${PengaduanStatus.menungguVerifikasiKadiv.name},'
          'status.eq.${PengaduanStatus.tindakLanjut.name}',
        );
        break;
      default:
        break;
    }

    final rows = await query.order('tanggal_pengaduan', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<Map<String, dynamic>?> detail(int pengaduanId) async {
    final row = await _client
        .from('pengaduan_pegawai')
        .select()
        .eq('id', pengaduanId)
        .maybeSingle();
    return row;
  }

  static Future<List<Map<String, dynamic>>> riwayatStatus(
      int pengaduanId) async {
    final rows = await _client
        .from('riwayat_status_pengaduan')
        .select()
        .eq('pengaduan_id', pengaduanId)
        .order('tanggal', ascending: true);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<List<Pengaduan>> punyaSayaSebagaiObjek() async {
    final rows = await punyaSaya();
    return rows.map((row) => pengaduanFromRow(row)).toList();
  }

  static List<StatusHistoryEntry> _parseRiwayat(
      List<Map<String, dynamic>> riwayatRows) {
    return riwayatRows.map((r) {
      return StatusHistoryEntry(
        status: PengaduanStatus.values.firstWhere(
          (e) => e.name == r['status'],
          orElse: () => PengaduanStatus.menungguKadiv,
        ),
        statusLama: r['status_lama'] != null
            ? PengaduanStatus.values.firstWhere(
                (e) => e.name == r['status_lama'],
                orElse: () => PengaduanStatus.menungguKadiv,
              )
            : null,
        tanggal: DateTime.parse(r['tanggal'] as String),
        keterangan: r['keterangan'] as String?,
        oleh: r['oleh'] as String,
        role: r['role'] != null
            ? UserRole.values.firstWhere((e) => e.name == r['role'])
            : null,
        aksi: r['aksi'] as String,
      );
    }).toList();
  }

  static Future<Pengaduan?> detailLengkap(int pengaduanId) async {
    final row = await detail(pengaduanId);
    if (row == null) return null;
    final riwayatRows = await riwayatStatus(pengaduanId);
    return pengaduanFromRow(row, riwayat: _parseRiwayat(riwayatRows));
  }

  static Future<List<Pengaduan>> untukRoleSebagaiObjek(UserRole role) async {
    final rows = await untukRole(role);
    return rows.map((row) => pengaduanFromRow(row)).toList();
  }

  static Future<void> _ubahStatus({
    required int pengaduanId,
    required String statusLama,
    required String statusBaru,
    required String oleh,
    required UserRole role,
    required String aksi,
    String? catatan,
    Map<String, dynamic> kolomTambahan = const {},
  }) async {
    await _client.from('pengaduan_pegawai').update({
      'status': statusBaru,
      'updated_at': DateTime.now().toIso8601String(),
      ...kolomTambahan,
    }).eq('id', pengaduanId);

    await _client.from('riwayat_status_pengaduan').insert({
      'pengaduan_id': pengaduanId,
      'status': statusBaru,
      'status_lama': statusLama,
      'oleh': oleh,
      'role': role.name,
      'aksi': aksi,
      'keterangan': catatan,
    });
  }

  /// KADIV — terima/tolak. Tolak -> arsip. Terima -> otomatis diteruskan
  /// (lewat KSPI) ke Dirut tahap 1, & KSPI diberi notifikasi.
  static Future<void> kadivAksi({
    required int pengaduanId,
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
  }) async {
    if (keputusan == Keputusan.tolak) {
      await _ubahStatus(
        pengaduanId: pengaduanId,
        statusLama: PengaduanStatus.menungguKadiv.name,
        statusBaru: PengaduanStatus.arsip.name,
        oleh: oleh,
        role: UserRole.kadivKategori,
        aksi: 'Menolak, pengaduan diarsipkan',
        catatan: catatan,
        kolomTambahan: {
          'keputusan_kadiv': keputusan.name,
          'catatan_kadiv': catatan,
          'arsip_pada_tahap': 'kadiv',
          'alasan_arsip': catatan,
        },
      );
      return;
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguKadiv.name,
      statusBaru: PengaduanStatus.menungguDirutTahap1.name,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Menerima pengaduan, diteruskan otomatis (via KSPI) ke Dirut',
      catatan: catatan,
      kolomTambahan: {
        'keputusan_kadiv': keputusan.name,
        'catatan_kadiv': catatan,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.direktur,
      judul: 'Pengaduan menunggu persetujuan',
      pesan: 'Ada pengaduan yang perlu persetujuan tahap 1.',
      pengaduanId: pengaduanId,
    );
  }

  /// DIRUT — approval tahap 1 (layak diinvestigasi?). Tolak -> arsip.
  /// Terima -> balik ke KSPI untuk pilih eksekutor.
  static Future<void> dirutTahap1Aksi({
    required int pengaduanId,
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
  }) async {
    if (keputusan == Keputusan.tolak) {
      await _ubahStatus(
        pengaduanId: pengaduanId,
        statusLama: PengaduanStatus.menungguDirutTahap1.name,
        statusBaru: PengaduanStatus.arsip.name,
        oleh: oleh,
        role: UserRole.direktur,
        aksi: 'Menolak, pengaduan diarsipkan',
        catatan: catatan,
        kolomTambahan: {
          'keputusan_dirut_tahap1': keputusan.name,
          'catatan_dirut_tahap1': catatan,
          'arsip_pada_tahap': 'dirutTahap1',
          'alasan_arsip': catatan,
        },
      );
      return;
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguDirutTahap1.name,
      statusBaru: PengaduanStatus.menungguPilihEksekutor.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Menyetujui (layak diinvestigasi), dikembalikan ke KSPI',
      catatan: catatan,
      kolomTambahan: {
        'keputusan_dirut_tahap1': keputusan.name,
        'catatan_dirut_tahap1': catatan,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.kspi,
      judul: 'Pilih eksekutor investigasi',
      pesan: 'Dirut menyetujui pengaduan, silakan pilih eksekutor investigasi.',
      pengaduanId: pengaduanId,
    );
  }

  /// KSPI — pilih eksekutor investigasi (Kadiv/TPDPK).
  static Future<void> kspiPilihEksekutor({
    required int pengaduanId,
    required String oleh,
    required Eksekutor eksekutor,
    String? petugas,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguPilihEksekutor.name,
      statusBaru: PengaduanStatus.investigasiBerjalan.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Memilih eksekutor investigasi: ${eksekutor.label}'
          '${petugas != null ? ' (petugas: $petugas)' : ''}',
      catatan: catatan,
      kolomTambahan: {
        'eksekutor': eksekutor.name,
        'petugas_investigasi': petugas,
      },
    );

    final roleEksekutor =
        eksekutor == Eksekutor.kadiv ? UserRole.kadivKategori : UserRole.tpdpk;
    await NotificationService.kirimKeRole(
      role: roleEksekutor,
      judul: 'Ditunjuk sebagai eksekutor investigasi',
      pesan: 'Silakan lakukan investigasi & kirim hasilnya.',
      pengaduanId: pengaduanId,
    );
  }

  /// EKSEKUTOR (Kadiv/TPDPK) — kirim hasil investigasi & surat
  /// rekomendasi, otomatis diteruskan ke Direksi (tahap 2).
  static Future<void> kirimHasilInvestigasi({
    required int pengaduanId,
    required String oleh,
    required UserRole role,
    required String hasil,
    required String rekomendasi,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.investigasiBerjalan.name,
      statusBaru: PengaduanStatus.menungguReviewKspi.name,
      oleh: oleh,
      role: role,
      aksi: 'Mengirim hasil investigasi & surat rekomendasi, '
          'diteruskan otomatis ke Direksi',
      kolomTambahan: {
        'hasil_investigasi': hasil,
        'surat_rekomendasi': rekomendasi,
        'tanggal_hasil_investigasi': DateTime.now().toIso8601String(),
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.direktur,
      judul: 'Hasil investigasi menunggu persetujuan',
      pesan: 'Hasil investigasi & surat rekomendasi telah masuk.',
      pengaduanId: pengaduanId,
    );
  }

  /// DIREKSI (akun Dirut) — approval tahap 2 (hasil investigasi
  /// diterima?). Tolak -> arsip. Terima -> menunggu pilih eksekutor
  /// tindak lanjut.
  static Future<void> direksiTahap2Aksi({
    required int pengaduanId,
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
  }) async {
    if (keputusan == Keputusan.tolak) {
      await _ubahStatus(
        pengaduanId: pengaduanId,
        statusLama: PengaduanStatus.menungguDirutTahap2.name,
        statusBaru: PengaduanStatus.arsip.name,
        oleh: oleh,
        role: UserRole.direktur,
        aksi: 'Menolak hasil investigasi, pengaduan diarsipkan',
        catatan: catatan,
        kolomTambahan: {
          'keputusan_dirut_tahap2': keputusan.name,
          'catatan_dirut_tahap2': catatan,
          'arsip_pada_tahap': 'dirutTahap2',
          'alasan_arsip': catatan,
        },
      );
      return;
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguDirutTahap2.name,
      statusBaru: PengaduanStatus.menungguPilihEksekutorTindakLanjut.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Menerima hasil investigasi (ditindaklanjuti)',
      catatan: catatan,
      kolomTambahan: {
        'keputusan_dirut_tahap2': keputusan.name,
        'catatan_dirut_tahap2': catatan,
      },
    );
  }

  /// DIREKTUR — memilih eksekutor tindak lanjut (Kadiv/TPDPK).
  static Future<void> pilihEksekutorTindakLanjut({
    required int pengaduanId,
    required String oleh,
    required Eksekutor eksekutor,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguPilihEksekutorTindakLanjut.name,
      statusBaru: PengaduanStatus.tindakLanjut.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Memilih eksekutor tindak lanjut: ${eksekutor.label}',
      kolomTambahan: {'eksekutor_tindak_lanjut': eksekutor.name},
    );

    final roleEksekutor =
        eksekutor == Eksekutor.kadiv ? UserRole.kadivKategori : UserRole.tpdpk;
    await NotificationService.kirimKeRole(
      role: roleEksekutor,
      judul: 'Ditunjuk sebagai eksekutor tindak lanjut',
      pesan: 'Silakan jalankan tindak lanjut yang diminta Direktur.',
      pengaduanId: pengaduanId,
    );
  }

  /// EKSEKUTOR (Kadiv/TPDPK) — tindak lanjut selesai, diteruskan ke SDM.
  static Future<void> selesaikanTindakLanjut({
    required int pengaduanId,
    required String oleh,
    required UserRole role,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.tindakLanjutBerjalan.name,
      statusBaru: PengaduanStatus.menungguSdm.name,
      oleh: oleh,
      role: role,
      aksi: 'Tindak lanjut selesai dijalankan, diteruskan ke SDM',
      catatan: catatan,
      kolomTambahan: {'catatan_tindak_lanjut_selesai': catatan},
    );

    await NotificationService.kirimKeRole(
      role: UserRole.sdm,
      judul: 'Menunggu tindak lanjut administratif',
      pesan: 'Ada pengaduan yang perlu ditindaklanjuti secara administratif.',
      pengaduanId: pengaduanId,
    );
  }

  /// SDM — menandai tindak lanjut administratif selesai. Titik akhir alur,
  /// & memberi tahu pelapor asli bahwa pengaduannya selesai.
  static Future<void> sdmSelesaikan({
    required int pengaduanId,
    required String oleh,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguSdm.name,
      statusBaru: PengaduanStatus.selesai.name,
      oleh: oleh,
      role: UserRole.sdm,
      aksi: 'Menyelesaikan tindak lanjut administratif',
      catatan: catatan,
      kolomTambahan: {'catatan_sdm': catatan},
    );

    final row = await detail(pengaduanId);
    final pelaporId = row?['pelapor_id'] as String?;
    if (pelaporId != null) {
      await NotificationService.kirimKePegawai(
        pegawaiId: pelaporId,
        judul: 'Pengaduan selesai',
        pesan: 'Pengaduan Anda (${row?['nomor_pengaduan']}) telah selesai '
            'ditindaklanjuti.',
        pengaduanId: pengaduanId,
      );
    }
  }
}

/// =============================================================
/// NotificationService
/// =============================================================
class NotificationService {
  NotificationService._();

  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> untukSaya() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from('notifikasi')
        .select()
        .eq('untuk_pegawai_id', userId)
        .order('waktu', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<int> belumDibaca() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    final rows = await _client
        .from('notifikasi')
        .select('id')
        .eq('untuk_pegawai_id', userId)
        .eq('dibaca', false);
    return (rows as List).length;
  }

  static Future<void> tandaiSemuaDibaca() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifikasi')
        .update({'dibaca': true})
        .eq('untuk_pegawai_id', userId)
        .eq('dibaca', false);
  }

  static Future<void> kirimKeRole({
    required UserRole role,
    required String judul,
    required String pesan,
    int? pengaduanId,
  }) async {
    final daftarPegawai =
        await _client.from('pegawai').select('id').eq('role', role.name);

    for (final pegawai in (daftarPegawai as List)) {
      await _client.from('notifikasi').insert({
        'untuk_pegawai_id': pegawai['id'],
        'judul': judul,
        'pesan': pesan,
        if (pengaduanId != null) 'pengaduan_id': pengaduanId,
      });
    }
  }

  static Future<void> kirimKePegawai({
    required String pegawaiId,
    required String judul,
    required String pesan,
    int? pengaduanId,
  }) async {
    await _client.from('notifikasi').insert({
      'untuk_pegawai_id': pegawaiId,
      'judul': judul,
      'pesan': pesan,
      if (pengaduanId != null) 'pengaduan_id': pengaduanId,
    });
  }
}
