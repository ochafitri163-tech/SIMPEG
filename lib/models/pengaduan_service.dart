import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';
import 'pengaduan_model.dart';

/// Mengubah satu baris hasil query Supabase (Map) menjadi object
/// [Pengaduan] dari model lama, supaya seluruh UI yang sudah ada (yang
/// memakai getter seperti p.status.label, p.status.color, dst dari
/// enum PengaduanStatusX) tetap berfungsi tanpa perlu diubah sama sekali.
///
/// [riwayat] opsional -- kalau tidak diisi, riwayatStatus akan kosong
/// (dipakai untuk daftar/list, di mana riwayat detail belum diperlukan).
/// Untuk halaman detail, isi dengan hasil [PengaduanService.riwayatStatus].
Pengaduan pengaduanFromRow(
  Map<String, dynamic> row, {
  List<StatusHistoryEntry> riwayat = const [],
}) {
  PengaduanStatus parseStatus(String? s) {
    return PengaduanStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PengaduanStatus.draft,
    );
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
    return Eksekutor.values.firstWhere(
      (e) => e.name == s,
      orElse: () => Eksekutor.kadiv,
    );
  }

  KeputusanDirektur? parseKeputusan(String? s) {
    if (s == null) return null;
    return KeputusanDirektur.values.firstWhere(
      (e) => e.name == s,
      orElse: () => KeputusanDirektur.tindakLanjut,
    );
  }

  final pengaduan = Pengaduan(
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
    kategoriDivisi: parseKategoriDivisi(row['kategori_divisi'] as String?),
    catatanVerifikasiKadiv: row['catatan_verifikasi_kadiv'] as String?,
    catatanReviewKspi: row['catatan_review_kspi'] as String?,
    eksekutor: parseEksekutor(row['eksekutor'] as String?),
    petugasInvestigasi: row['petugas_investigasi'] as String?,
    hasilInvestigasi: row['hasil_investigasi'] as String?,
    suratRekomendasi: row['surat_rekomendasi'] as String?,
    tanggalHasilInvestigasi: row['tanggal_hasil_investigasi'] != null
        ? DateTime.parse(row['tanggal_hasil_investigasi'] as String)
        : null,
    catatanReviewHasilKspi: row['catatan_review_hasil_kspi'] as String?,
    hasilSesuaiMenurutKspi: row['hasil_sesuai_menurut_kspi'] as bool?,
    keputusanDirektur: parseKeputusan(row['keputusan_direktur'] as String?),
    alasanPenolakanDirektur: row['alasan_penolakan_direktur'] as String?,
    catatanPeninjauanKembali: row['catatan_peninjauan_kembali'] as String?,
    tindakLanjutDiminta: row['tindak_lanjut_diminta'] as String?,
    eksekutorTindakLanjut:
        parseEksekutor(row['eksekutor_tindak_lanjut'] as String?),
    keteranganSelesai: row['keterangan_selesai'] as String?,
  );

  // Simpan id baris Supabase supaya bisa dipakai lagi saat memanggil
  // PengaduanService (mis. untuk fetch riwayat / update status).
  // Ditempel lewat extension di bawah karena class Pengaduan asli tidak
  // punya field id (murni in-memory dulu).
  _pengaduanIdMap[pengaduan] = row['id'] as int;

  return pengaduan;
}

/// Menyimpan id baris Supabase per-object Pengaduan (workaround karena
/// class Pengaduan dari model lama tidak punya field id bawaan).
final Map<Pengaduan, int> _pengaduanIdMap = {};

extension PengaduanIdX on Pengaduan {
  /// id baris di tabel Supabase, hanya terisi kalau object ini dibuat
  /// lewat [pengaduanFromRow]. Null kalau object dibuat manual (mis. data
  /// dummy lama yang belum dihapus).
  int? get supabaseId => _pengaduanIdMap[this];
}

/// =============================================================
/// PengaduanService — menggantikan PengaduanRepository in-memory lama.
/// Semua method di sini query langsung ke tabel `pengaduan_pegawai`,
/// `riwayat_status_pengaduan`, dan `notifikasi` di Supabase, sehingga
/// data tersimpan permanen & sinkron real-time antar user/role.
///
/// CATATAN: enum PengaduanStatus, KategoriDivisi, Eksekutor, dan
/// KeputusanDirektur tetap dipakai di sisi Flutter (untuk label, warna,
/// icon di UI) -- hanya *penyimpanan datanya* yang pindah ke Supabase.
/// Konversi enum <-> string database pakai `.name` (nama enum persis).
/// =============================================================
class PengaduanService {
  PengaduanService._();

  static final _client = Supabase.instance.client;

  /// Generate nomor pengaduan unik, format: PGD-YYYYMM-XXX
  static Future<String> generateNomorPengaduan() async {
    final now = DateTime.now();
    final prefix = 'PGD-${now.year}${now.month.toString().padLeft(2, '0')}';

    // Hitung berapa banyak pengaduan bulan ini untuk nomor urut.
    final rows = await _client
        .from('pengaduan_pegawai')
        .select('id')
        .like('nomor_pengaduan', '$prefix%');

    final urut = ((rows as List).length + 1).toString().padLeft(3, '0');
    return '$prefix-$urut';
  }

  /// Submit pengaduan baru oleh pegawai yang sedang login.
  /// [user] dipakai untuk snapshot identitas pelapor (nama, nik, dst).
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
          'status': 'menungguVerifikasiKadiv',
        })
        .select()
        .single();

    final pengaduanId = inserted['id'] as int;

    // Catat riwayat status awal.
    await _client.from('riwayat_status_pengaduan').insert({
      'pengaduan_id': pengaduanId,
      'status': 'menungguVerifikasiKadiv',
      'status_lama': null,
      'oleh': 'Sistem',
      'aksi': 'Pengaduan dibuat',
    });

    // Beri notifikasi ke semua Kadiv (siapapun dengan role kadivKategori).
    // Catatan: ini query dari client, sehingga bergantung pada RLS yang
    // mengizinkan SELECT id pegawai ber-role kadiv. Kalau RLS ketat,
    // sebaiknya langkah ini dipindah ke Supabase Edge Function/trigger.
    final kadivList =
        await _client.from('pegawai').select('id').eq('role', 'kadivKategori');

    for (final kadiv in (kadivList as List)) {
      await _client.from('notifikasi').insert({
        'untuk_pegawai_id': kadiv['id'],
        'judul': 'Pengaduan baru masuk',
        'pesan': '${user.name} membuat pengaduan baru ($nomor).',
        'pengaduan_id': pengaduanId,
      });
    }
  }

  /// Ambil daftar pengaduan milik pegawai yang sedang login (riwayat
  /// pengaduan yang pernah dia buat sendiri).
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

  /// Ambil daftar pengaduan yang perlu ditindaklanjuti oleh role tertentu
  /// (Kadiv/KSPI/TPDPK/Direktur) sesuai status saat ini. RLS di Supabase
  /// sudah membatasi baris yang boleh dilihat masing-masing role, jadi
  /// query di sini cukup select semua & filter status di sisi klien
  /// sebagai lapisan tambahan (bukan pengganti RLS).
  static Future<List<Map<String, dynamic>>> untukRole(UserRole role) async {
    final rows = await _client
        .from('pengaduan_pegawai')
        .select()
        .order('tanggal_pengaduan', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Ambil detail satu pengaduan + riwayat statusnya.
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

  /// Ambil daftar pengaduan milik pegawai yang sedang login (riwayat
  /// pengaduan yang pernah dia buat sendiri), sudah dalam bentuk object
  /// [Pengaduan] siap pakai oleh UI lama (StatusPengaduanScreen, dst).
  /// Riwayat status TIDAK ikut di-fetch di sini (kosong) supaya list
  /// tetap ringan -- untuk detail lengkap, panggil [detailLengkap].
  static Future<List<Pengaduan>> punyaSayaSebagaiObjek() async {
    final rows = await punyaSaya();
    return rows.map((row) => pengaduanFromRow(row)).toList();
  }

  /// Ambil satu pengaduan lengkap dengan riwayat statusnya, dalam bentuk
  /// object [Pengaduan] siap pakai (dipakai oleh halaman detail).
  static Future<Pengaduan?> detailLengkap(int pengaduanId) async {
    final row = await detail(pengaduanId);
    if (row == null) return null;

    final riwayatRows = await riwayatStatus(pengaduanId);
    final riwayat = riwayatRows.map((r) {
      return StatusHistoryEntry(
        status: PengaduanStatus.values.firstWhere(
          (e) => e.name == r['status'],
          orElse: () => PengaduanStatus.draft,
        ),
        statusLama: r['status_lama'] != null
            ? PengaduanStatus.values.firstWhere(
                (e) => e.name == r['status_lama'],
                orElse: () => PengaduanStatus.draft,
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

    return pengaduanFromRow(row, riwayat: riwayat);
  }

  /// Ambil daftar pengaduan untuk role tertentu (Kadiv/KSPI/dst) dalam
  /// bentuk object [Pengaduan] siap pakai. RLS Supabase sudah membatasi
  /// baris yang dikembalikan sesuai role & status yang relevan.
  static Future<List<Pengaduan>> untukRoleSebagaiObjek(UserRole role) async {
    final rows = await untukRole(role);
    return rows.map((row) => pengaduanFromRow(row)).toList();
  }

  /// sekaligus, supaya konsisten (dipanggil oleh semua aksi role di bawah).
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

  /// KADIV — verifikasi & tentukan kategori divisi, otomatis diteruskan
  /// ke KSPI.
  static Future<void> verifikasiKadiv({
    required int pengaduanId,
    required String oleh,
    required String kategoriDivisi, // 'devAdmin' atau 'devTeknis'
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: 'menungguVerifikasiKadiv',
      statusBaru: 'reviewKspi',
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Verifikasi & kategorisasi ($kategoriDivisi), diteruskan ke KSPI',
      catatan: catatan,
      kolomTambahan: {
        'kategori_divisi': kategoriDivisi,
        'catatan_verifikasi_kadiv': catatan,
      },
    );
  }

  /// KSPI — review lalu pilih eksekutor (Kadiv atau TPDPK).
  static Future<void> reviewDanPilihEksekutor({
    required int pengaduanId,
    required String oleh,
    required String eksekutor, // 'kadiv' atau 'tpdpk'
    String? petugas,
    String? catatan,
  }) async {
    final statusBaru =
        eksekutor == 'kadiv' ? 'investigasiBerjalan' : 'menungguInvestigasi';
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: 'reviewKspi',
      statusBaru: statusBaru,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Review KSPI, eksekutor: $eksekutor',
      catatan: catatan,
      kolomTambahan: {
        'eksekutor': eksekutor,
        'petugas_investigasi': petugas,
        'catatan_review_kspi': catatan,
      },
    );
  }

  /// TPDPK — kirim hasil investigasi & surat rekomendasi ke KSPI.
  static Future<void> kirimHasilInvestigasi({
    required int pengaduanId,
    required String oleh,
    required String hasil,
    required String rekomendasi,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: 'investigasiBerjalan',
      statusBaru: 'menungguReviewKspi',
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Mengirim hasil investigasi & surat rekomendasi ke KSPI',
      kolomTambahan: {
        'hasil_investigasi': hasil,
        'surat_rekomendasi': rekomendasi,
        'tanggal_hasil_investigasi': DateTime.now().toIso8601String(),
      },
    );
  }

  /// KSPI — review hasil investigasi: sesuai -> Direktur, tidak -> revisi.
  static Future<void> reviewHasilInvestigasi({
    required int pengaduanId,
    required String oleh,
    required bool sesuai,
    String? catatan,
  }) async {
    final statusBaru =
        sesuai ? 'menungguPersetujuanDirektur' : 'revisiInvestigasi';
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: 'menungguReviewKspi',
      statusBaru: statusBaru,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: sesuai
          ? 'Hasil investigasi disetujui, dikirim ke Direktur'
          : 'Hasil investigasi dikembalikan untuk revisi',
      catatan: catatan,
      kolomTambahan: {
        'hasil_sesuai_menurut_kspi': sesuai,
        'catatan_review_hasil_kspi': catatan,
      },
    );
  }

  /// DIREKTUR — keputusan akhir: setuju/tolak/peninjauan kembali/tindak lanjut.
  static Future<void> keputusanDirektur({
    required int pengaduanId,
    required String oleh,
    required String
        keputusan, // 'setuju'|'tolak'|'peninjauanKembali'|'tindakLanjut'
    String? catatan,
  }) async {
    late String statusBaru;
    final kolom = <String, dynamic>{'keputusan_direktur': keputusan};

    switch (keputusan) {
      case 'setuju':
        statusBaru = 'selesai';
        kolom['keterangan_selesai'] = catatan ?? 'Disetujui oleh Direktur.';
        break;
      case 'tolak':
        statusBaru = 'ditolakDirektur';
        kolom['alasan_penolakan_direktur'] = catatan;
        break;
      case 'peninjauanKembali':
        statusBaru = 'peninjauanKembali';
        kolom['catatan_peninjauan_kembali'] = catatan;
        break;
      case 'tindakLanjut':
        statusBaru = 'tindakLanjut';
        kolom['tindak_lanjut_diminta'] = catatan;
        break;
      default:
        throw ArgumentError('Keputusan tidak dikenal: $keputusan');
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: 'menungguPersetujuanDirektur',
      statusBaru: statusBaru,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Keputusan Direktur: $keputusan',
      catatan: catatan,
      kolomTambahan: kolom,
    );
  }

  /// Eksekutor (Kadiv/TPDPK) menandai tindak lanjut selesai.
  static Future<void> selesaikanTindakLanjut({
    required int pengaduanId,
    required String oleh,
    required UserRole role,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: 'tindakLanjut',
      statusBaru: 'selesai',
      oleh: oleh,
      role: role,
      aksi: 'Menyelesaikan tindak lanjut',
      catatan: catatan,
      kolomTambahan: {
        'keterangan_selesai': catatan ?? 'Tindak lanjut telah dijalankan.',
      },
    );
  }

  // Method aksi lain (tpdpkPilihPetugas, kirimRevisiInvestigasi,
  // kirimUlangSetelahRevisiKspi, kirimUntukInvestigasiUlang,
  // pilihEksekutorTindakLanjut) mengikuti pola yang sama persis dengan
  // method di atas -- tinggal disalin & disesuaikan status lama/barunya
  // saat dashboard Kadiv/KSPI/TPDPK/Direktur mulai dibuat.
}

/// =============================================================
/// NotificationService — menggantikan NotificationCenter in-memory.
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

  /// Kirim notifikasi yang sama ke SEMUA pegawai dengan role tertentu
  /// (mis. semua KSPI, semua Direktur). Dipakai saat aksi satu role perlu
  /// memberi tahu role berikutnya dalam alur (Kadiv -> KSPI, KSPI ->
  /// Direktur, dst).
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

  /// Kirim notifikasi ke SATU pegawai spesifik berdasarkan id-nya. Dipakai
  /// saat aksi perlu memberi tahu pelapor asli (bukan semua orang di satu
  /// role), mis. saat pengaduan pegawai dinyatakan selesai.
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
