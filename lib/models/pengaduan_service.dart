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

  DivisiKadiv? parseDivisiKadiv(String? s) {
    if (s == null) return null;
    return DivisiKadiv.values.firstWhere(
      (e) => e.name == s,
      orElse: () => DivisiKadiv.administrasi,
    );
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
    pihakTerlapor: row['pihak_terlapor'] as String?,
    nikPelaku: row['nik_pelaku'] as String?,
    jabatanPelaku: row['jabatan_pelaku'] as String?,
    anonim: (row['anonim'] ?? false) as bool,
    status: parseStatus(row['status'] as String?),
    fotoBukti: List<String>.from(row['foto_bukti'] ?? const []),
    dokumenPendukung: List<String>.from(row['dokumen_pendukung'] ?? const []),
    videoBukti: List<String>.from(row['video_bukti'] ?? const []),
    voiceNote: List<String>.from(row['voice_note'] ?? const []),
    investigasiFoto: List<String>.from(row['investigasi_foto'] ?? const []),
    investigasiVideo: List<String>.from(row['investigasi_video'] ?? const []),
    investigasiVoice: List<String>.from(row['investigasi_voice'] ?? const []),
    investigasiDokumen:
        List<String>.from(row['investigasi_dokumen'] ?? const []),
    riwayatStatus: riwayat,
    keputusanKadiv: parseKeputusan(row['keputusan_kadiv'] as String?),
    catatanKadiv: row['catatan_kadiv'] as String?,
    keputusanDirutTahap1:
        parseKeputusan(row['keputusan_dirut_tahap1'] as String?),
    catatanDirutTahap1: row['catatan_dirut_tahap1'] as String?,
    eksekutor: parseEksekutor(row['eksekutor'] as String?),
    petugasInvestigasi: row['petugas_investigasi'] as String?,
    eksekutorDivisiKadiv:
        parseDivisiKadiv(row['eksekutor_divisi_kadiv'] as String?),
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
    eksekutorTindakLanjutDivisiKadiv: parseDivisiKadiv(
        row['eksekutor_tindak_lanjut_divisi_kadiv'] as String?),
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
///
/// CATATAN SKEMA TABEL `pengaduan_pegawai`: perlu 2 kolom tambahan
/// bertipe text agar penugasan eksekutor ke Kadiv Administrasi/Teknik
/// tersimpan per divisi (bukan cuma 'kadiv' generik):
///   - `eksekutor_divisi_kadiv` (tahap investigasi)
///   - `eksekutor_tindak_lanjut_divisi_kadiv` (tahap tindak lanjut)
/// =============================================================
class PengaduanService {
  PengaduanService._();

  static final _client = Supabase.instance.client;

  /// Membuat nomor pengaduan berformat PGD-YYYYMM-NNN.
  ///
  /// Nomor urut diambil dari NOMOR TERBESAR yang sudah ada pada bulan
  /// berjalan lalu ditambah 1 — BUKAN dari jumlah baris. Ini penting agar
  /// tidak menghasilkan nomor yang sudah dipakai ketika ada pengaduan lama
  /// yang terhapus (dulu memakai jumlah baris sehingga bisa bentrok dan
  /// memicu error "duplicate key ... nomor_pengaduan").
  static Future<String> generateNomorPengaduan() async {
    final now = DateTime.now();
    final prefix = 'PGD-${now.year}${now.month.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('pengaduan_pegawai')
        .select('nomor_pengaduan')
        .like('nomor_pengaduan', '$prefix%');
    var maxUrut = 0;
    for (final r in (rows as List)) {
      final nomor = (r['nomor_pengaduan'] ?? '').toString();
      // Ambil bagian angka urut (segmen ke-3, sebelum kemungkinan sufiks acak).
      final bagian = nomor.split('-');
      if (bagian.length >= 3) {
        final n = int.tryParse(bagian[2]);
        if (n != null && n > maxUrut) maxUrut = n;
      }
    }
    final urut = (maxUrut + 1).toString().padLeft(3, '0');
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

  /// KSPI — review awal & pilih eksekutor investigasi. Eksekutor bisa
  /// TPDPK, atau salah satu dari 2 Kadiv (Administrasi/Teknik) — kalau
  /// eksekutor == 'kadiv', [divisiKadiv] WAJIB diisi ('administrasi' |
  /// 'teknik') supaya tugas hanya masuk ke kotak masuk Kadiv yang dipilih.
  static Future<void> reviewDanPilihEksekutor({
    required int pengaduanId,
    required String oleh,
    required String eksekutor, // 'kadiv' | 'tpdpk'
    String?
        divisiKadiv, // 'administrasi' | 'teknik', wajib bila eksekutor == 'kadiv'
    String? petugas,
    String? catatan,
  }) async {
    final statusBaru = PengaduanStatus.investigasiBerjalan.name;
    final divisi = divisiKadiv != null
        ? DivisiKadiv.values.firstWhere((e) => e.name == divisiKadiv)
        : null;
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguPilihEksekutor.name,
      statusBaru: statusBaru,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Review & memilih eksekutor: '
          '${eksekutor == 'kadiv' ? divisi?.label ?? 'Kadiv Kategori' : 'TPDPK'}',
      catatan: catatan,
      kolomTambahan: {
        'eksekutor': eksekutor,
        'eksekutor_divisi_kadiv': divisiKadiv,
        'petugas_investigasi': petugas,
      },
    );

    if (eksekutor == 'kadiv' && divisi != null) {
      await NotificationService.kirimKeKadivDivisi(
        divisi: divisi,
        judul: 'Penugasan investigasi baru',
        pesan: 'Silakan lakukan investigasi & kirim hasilnya.',
        pengaduanId: pengaduanId,
      );
    } else {
      await NotificationService.kirimKeRole(
        role: UserRole.tpdpk,
        judul: 'Penugasan investigasi baru',
        pesan: 'Silakan lakukan investigasi & kirim hasilnya.',
        pengaduanId: pengaduanId,
      );
    }
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
    List<String> foto = const [],
    List<String> video = const [],
    List<String> voice = const [],
    List<String> dokumen = const [],
  }) async {
    // Kolom media hanya ditulis bila ada isinya, agar update tidak gagal
    // ketika kolom array media belum tersedia di skema tabel.
    final kolom = <String, dynamic>{
      'hasil_investigasi': hasil,
      'surat_rekomendasi': rekomendasi,
      'tanggal_hasil_investigasi': DateTime.now().toIso8601String(),
    };
    if (foto.isNotEmpty) kolom['investigasi_foto'] = foto;
    if (video.isNotEmpty) kolom['investigasi_video'] = video;
    if (voice.isNotEmpty) kolom['investigasi_voice'] = voice;
    if (dokumen.isNotEmpty) kolom['investigasi_dokumen'] = dokumen;

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.revisiInvestigasi.name,
      statusBaru: PengaduanStatus.menungguReviewKspi.name,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Mengirim ulang hasil investigasi (revisi)',
      kolomTambahan: kolom,
    );
  }

  /// Submit pengaduan baru oleh pegawai. Kategori pengaduan (dipilih
  /// pegawai di form) menentukan Kadiv divisi mana yang diberi notifikasi.
  ///
  /// CATATAN SKEMA TABEL `pengaduan_pegawai`: perlu 2 kolom tambahan
  /// bertipe text agar data pelaku/pihak yang diadukan (NIK & jabatan)
  /// tersimpan dan bisa ditampilkan di semua riwayat/status pengaduan
  /// di semua role:
  ///   - `nik_pelaku`
  ///   - `jabatan_pelaku`
  /// (kolom `pihak_terlapor` yang sudah ada dipakai untuk nama pelaku.)
  static Future<void> submit({
    required AppUser user,
    required String kategori,
    required String judul,
    required String deskripsi,
    required String pihakTerlapor,
    required String nikPelaku,
    required String jabatanPelaku,
    List<String> fotoBukti = const [],
    List<String> videoBukti = const [],
    List<String> voiceNote = const [],
    List<String> dokumenPendukung = const [],
    bool anonim = false,
  }) async {
    // Tidak wajib ada sesi Supabase Auth. Identitas pelapor memakai NIK
// karena login aplikasi lewat NIK, bukan Supabase Auth.
    final userId = _client.auth.currentUser?.id;
    if (user.nik.trim().isEmpty) {
      throw Exception('NIK pegawai tidak tersedia.');
    }

    // Buat pengaduan dengan nomor unik. Bila terjadi bentrok nomor
    // (unique constraint `nomor_pengaduan`) karena ada pengaduan lain yang
    // dibuat bersamaan atau data lama, nomor otomatis dibuat ulang dan insert
    // dicoba lagi. Dengan begitu pegawai selalu bisa mengirim pengaduan
    // berkali-kali tanpa batas dan tanpa error "duplicate key".
    Map<String, dynamic>? inserted;
    var nomor = await generateNomorPengaduan();
    for (var percobaan = 0; percobaan < 8; percobaan++) {
      try {
        inserted = await _client
            .from('pengaduan_pegawai')
            .insert({
              'nomor_pengaduan': nomor,
              if (userId != null) 'pelapor_id': userId,
              'kategori': kategori,
              'judul': judul,
              'deskripsi': deskripsi,
              'nama_pegawai': user.name,
              'nik': user.nik,
              'cabang': user.unitKerja,
              'golongan': user.golongan,
              'pihak_terlapor': pihakTerlapor.trim(),
              'nik_pelaku': nikPelaku.trim(),
              'jabatan_pelaku': jabatanPelaku.trim(),
              'anonim': anonim,
              'foto_bukti': fotoBukti,
              'video_bukti': videoBukti,
              'voice_note': voiceNote,
              'dokumen_pendukung': dokumenPendukung,
              'status': PengaduanStatus.menungguKadiv.name,
            })
            .select()
            .single();
        break;
      } on PostgrestException catch (e) {
        final pesan = '${e.code} ${e.message} ${e.details ?? ''}';
        final bentrokNomor =
            e.code == '23505' && pesan.contains('nomor_pengaduan');
        if (!bentrokNomor || percobaan == 7) rethrow;
        // Regenerasi nomor. Setelah percobaan pertama, tambahkan komponen
        // acak agar dijamin unik walau ada insert paralel.
        nomor = await generateNomorPengaduan();
        if (percobaan >= 1) {
          final acak =
              (100 + (DateTime.now().microsecondsSinceEpoch % 900)).toString();
          nomor = '$nomor-$acak';
        }
      }
    }
    if (inserted == null) {
      throw Exception('Gagal membuat nomor pengaduan yang unik.');
    }

    final pengaduanId = inserted['id'] as int;

    await _client.from('riwayat_status_pengaduan').insert({
      'pengaduan_id': pengaduanId,
      'status': PengaduanStatus.menungguKadiv.name,
      'status_lama': null,
      'oleh': 'Sistem',
      'aksi': 'Pengaduan dibuat',
      // Keterangan awal berisi info pelaku (nama/NIK/jabatan) supaya
      // langsung terlihat di riwayat paling atas untuk semua role.
      'keterangan': 'Pelaku diadukan: ${pihakTerlapor.trim()} · '
          'NIK ${nikPelaku.trim()} · ${jabatanPelaku.trim()}',
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
        'pesan':
            '${user.name} membuat pengaduan baru ($nomor).', // ignore: unnecessary_brace_in_string_interps
        'pengaduan_id': pengaduanId,
      });
    }
  }

  /// Daftar pengaduan milik pegawai. Prioritas filter memakai [nik] karena
  /// login aplikasi berbasis NIK; `pelapor_id` hanya dipakai bila memang
  /// ada sesi Supabase Auth.
  static Future<List<Map<String, dynamic>>> punyaSaya({String? nik}) async {
    final userId = _client.auth.currentUser?.id;
    var query = _client.from('pengaduan_pegawai').select();

    if (nik != null && nik.trim().isNotEmpty) {
      query = query.eq('nik', nik.trim());
    } else if (userId != null) {
      query = query.eq('pelapor_id', userId);
    } else {
      return [];
    }

    final rows = await query.order('tanggal_pengaduan', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Mengambil daftar pengaduan untuk sebuah role.
  ///
  /// Khusus role Kadiv: bila [divisiKadiv] diisi, dua hal disaring sesuai
  /// divisi:
  /// 1. Pengaduan yang masih berstatus `menungguKadiv` HANYA dikembalikan
  ///    bila kategorinya cocok dengan divisi Kadiv tersebut.
  /// 2. Pengaduan yang sudah ditugaskan sebagai eksekutor investigasi
  ///    atau eksekutor tindak lanjut ke Kadiv HANYA dikembalikan bila
  ///    Kadiv yang ditugaskan (`eksekutor_divisi_kadiv` /
  ///    `eksekutor_tindak_lanjut_divisi_kadiv`) adalah divisi Kadiv ini.
  /// Jadi pengaduan "Pelanggaran Administrasi" atau tugas investigasi ke
  /// Kadiv Administrasi tidak akan pernah muncul di kotak masuk Kadiv
  /// Teknik, dan sebaliknya.
  static Future<List<Map<String, dynamic>>> untukRole(
    UserRole role, {
    String? divisiKadiv,
  }) async {
    final rows = await _client
        .from('pengaduan_pegawai')
        .select()
        .order('tanggal_pengaduan', ascending: false);
    final semua = List<Map<String, dynamic>>.from(rows as List);

    if (role != UserRole.kadivKategori || divisiKadiv == null) {
      return semua;
    }

    return semua.where((row) {
      final status = row['status'] as String?;

      final belumDiverifikasi = status == PengaduanStatus.menungguKadiv.name ||
          status == PengaduanStatus.menungguVerifikasiKadiv.name;
      if (belumDiverifikasi) {
        final divisi =
            divisiKadivDariKategori((row['kategori'] ?? '') as String);
        // Kategori tak dikenal -> tampilkan ke semua Kadiv supaya tidak
        // ada pengaduan yang "nyangkut" tanpa penanggung jawab.
        if (divisi == null) return true;
        return divisi.name == divisiKadiv;
      }

      final eksekutorNama = row['eksekutor'] as String?;
      final sedangDiinvestigasiOlehKadiv =
          status == PengaduanStatus.investigasiBerjalan.name &&
              eksekutorNama == Eksekutor.kadiv.name;
      if (sedangDiinvestigasiOlehKadiv) {
        final divisi = row['eksekutor_divisi_kadiv'] as String?;
        // Belum ada divisi tercatat (data lama) -> tetap tampilkan agar
        // tidak hilang, alih-alih menyembunyikannya dari semua Kadiv.
        if (divisi == null) return true;
        return divisi == divisiKadiv;
      }

      final eksekutorTLNama = row['eksekutor_tindak_lanjut'] as String?;
      final sedangTindakLanjutOlehKadiv =
          status == PengaduanStatus.tindakLanjutBerjalan.name &&
              eksekutorTLNama == Eksekutor.kadiv.name;
      if (sedangTindakLanjutOlehKadiv) {
        final divisi = row['eksekutor_tindak_lanjut_divisi_kadiv'] as String?;
        if (divisi == null) return true;
        return divisi == divisiKadiv;
      }

      return true;
    }).toList();
  }

  /// KADIV — mengoreksi jenis/kategori pelanggaran dan MELEMPAR pengaduan
  /// ke Kadiv divisi lain.
  ///
  /// Dipakai ketika pengaduan masuk ke Kadiv Administrasi padahal isinya
  /// pelanggaran teknik (atau sebaliknya). Status tetap
  /// [PengaduanStatus.menungguKadiv] — pengaduan TIDAK diteruskan ke KSPI,
  /// melainkan pindah kotak masuk ke Kadiv divisi baru. Karena filter
  /// kotak masuk Kadiv memakai kategori, pengaduan otomatis hilang dari
  /// daftar Kadiv lama dan muncul di daftar Kadiv baru.
  static Future<void> alihkanKategoriKadiv({
    required int pengaduanId,
    required String oleh,
    required String kategoriBaru,
    String? nomorPengaduan,
    String? catatan,
  }) async {
    final divisiBaru = divisiKadivDariKategori(kategoriBaru);
    if (divisiBaru == null) {
      throw Exception('Kategori "$kategoriBaru" tidak dikenal.');
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguKadiv.name,
      statusBaru: PengaduanStatus.menungguKadiv.name,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Jenis pelanggaran diubah ke "$kategoriBaru" '
          '• dialihkan ke ${divisiBaru.label}',
      catatan: catatan,
      kolomTambahan: {
        'kategori': kategoriBaru,
        'kategori_divisi': divisiBaru == DivisiKadiv.administrasi
            ? KategoriDivisi.devAdmin.name
            : KategoriDivisi.devTeknik.name,
      },
    );

    await NotificationService.kirimKeKadivDivisi(
      divisi: divisiBaru,
      judul: 'Pengaduan dialihkan ke divisi Anda',
      pesan: '${nomorPengaduan ?? 'Sebuah pengaduan'} dialihkan oleh $oleh '
          'karena termasuk $kategoriBaru.',
      pengaduanId: pengaduanId,
    );
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

  static Future<List<Pengaduan>> punyaSayaSebagaiObjek({String? nik}) async {
    final rows = await punyaSaya(nik: nik);
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

  /// [divisiKadiv] diisi nama enum [DivisiKadiv] ('administrasi'/'teknik')
  /// untuk membatasi kotak masuk Kadiv sesuai divisinya.
  static Future<List<Pengaduan>> untukRoleSebagaiObjek(
    UserRole role, {
    String? divisiKadiv,
  }) async {
    final rows = await untukRole(role, divisiKadiv: divisiKadiv);
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
  ///
  /// Perubahan alur: baik keputusan Terima maupun Tolak SAMA-SAMA diteruskan
  /// ke KSPI (keputusan tetap dicatat, tidak ada pengarsipan di tahap Kadiv).
  /// Kadiv juga dapat mengoreksi kategori pelanggaran (administrasi/teknik)
  /// bila pegawai salah menempatkan kategori.
  static Future<void> kadivAksi({
    required int pengaduanId,
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
    String? kategoriBaru,
  }) async {
    final kolom = <String, dynamic>{
      'keputusan_kadiv': keputusan.name,
      'catatan_kadiv': catatan,
    };
    if (kategoriBaru != null && kategoriBaru.isNotEmpty) {
      kolom['kategori'] = kategoriBaru;
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguKadiv.name,
      statusBaru: PengaduanStatus.reviewKspi.name,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: keputusan == Keputusan.terima
          ? 'Verifikasi (Terima), diteruskan ke KSPI'
              '${kategoriBaru != null ? ' • kategori diubah ke $kategoriBaru' : ''}'
          : 'Verifikasi (Tolak dicatat), tetap diteruskan ke KSPI'
              '${kategoriBaru != null ? ' • kategori diubah ke $kategoriBaru' : ''}',
      catatan: catatan,
      kolomTambahan: kolom,
    );

    await NotificationService.kirimKeRole(
      role: UserRole.kspi,
      judul: 'Pengaduan siap diteruskan ke Dirut',
      pesan:
          'Ada pengaduan terverifikasi Kadiv yang perlu diteruskan ke Dirut.',
      pengaduanId: pengaduanId,
    );
  }

  /// KSPI — menolak pengaduan pada tahap review awal (status `reviewKspi`,
  /// setelah ditinjau Kadiv — baik yang tadinya diterima maupun ditolak
  /// Kadiv). KSPI WAJIB mengisi catatan/alasan penolakan. Alur berhenti di
  /// sini: pengaduan langsung diarsipkan (TIDAK diteruskan ke Dirut), dan
  /// alasan penolakan disampaikan ke pelapor lewat notifikasi.
  static Future<void> kspiTolak({
    required int pengaduanId,
    required String oleh,
    required String catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.reviewKspi.name,
      statusBaru: PengaduanStatus.arsip.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'KSPI menolak pengaduan, diarsipkan',
      catatan: catatan,
      kolomTambahan: {
        'arsip_pada_tahap': 'kspi',
        'alasan_arsip': catatan,
      },
    );

    final row = await detail(pengaduanId);
    final pelaporId = row?['pelapor_id'] as String?;
    final nomor = row?['nomor_pengaduan'];
    if (pelaporId != null) {
      await NotificationService.kirimKePegawai(
        pegawaiId: pelaporId,
        judul: 'Pengaduan ditolak KSPI',
        pesan: 'Pengaduan Anda ($nomor) ditolak oleh KSPI setelah ditinjau. '
            'Alasan: $catatan',
        pengaduanId: pengaduanId,
      );
    }
  }

  /// KSPI — meneruskan pengaduan ke Dirut (tombol "Teruskan ke Dirut").
  static Future<void> kspiTeruskanKeDirut({
    required int pengaduanId,
    required String oleh,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.reviewKspi.name,
      statusBaru: PengaduanStatus.menungguDirutTahap1.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Meneruskan pengaduan ke Dirut',
      catatan: catatan,
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
      aksi:
          'Menyetujui (layak diinvestigasi), diteruskan ke KSPI untuk pilih eksekutor',
      catatan: catatan,
      kolomTambahan: {
        'keputusan_dirut_tahap1': keputusan.name,
        'catatan_dirut_tahap1': catatan,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.kspi,
      judul: 'Pilih eksekutor investigasi',
      pesan:
          'Dirut menyetujui pengaduan, silakan pilih eksekutor investigasi (TPDPK atau Kadiv).',
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
    List<String> foto = const [],
    List<String> video = const [],
    List<String> voice = const [],
    List<String> dokumen = const [],
  }) async {
    // Kolom media hanya ditulis bila ada isinya, agar update tidak gagal
    // ketika kolom array media belum tersedia di skema tabel.
    final kolom = <String, dynamic>{
      'hasil_investigasi': hasil,
      'surat_rekomendasi': rekomendasi,
      'tanggal_hasil_investigasi': DateTime.now().toIso8601String(),
    };
    if (foto.isNotEmpty) kolom['investigasi_foto'] = foto;
    if (video.isNotEmpty) kolom['investigasi_video'] = video;
    if (voice.isNotEmpty) kolom['investigasi_voice'] = voice;
    if (dokumen.isNotEmpty) kolom['investigasi_dokumen'] = dokumen;

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.investigasiBerjalan.name,
      statusBaru: PengaduanStatus.menungguDirutTahap2.name,
      oleh: oleh,
      role: role,
      aksi: 'Mengirim hasil investigasi & surat rekomendasi, '
          'diteruskan langsung ke Dirut',
      kolomTambahan: kolom,
    );

    await NotificationService.kirimKeRole(
      role: UserRole.direktur,
      judul: 'Hasil investigasi menunggu persetujuan',
      pesan: 'Hasil investigasi & surat rekomendasi telah masuk.',
      pengaduanId: pengaduanId,
    );
  }

  /// DIREKSI (akun Dirut) — approval tahap 2 (hasil investigasi
  /// diterima?). Tolak -> arsip (pelapor diberi notifikasi template
  /// otomatis). Terima -> menunggu pilih eksekutor tindak lanjut.
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

      // Pelapor diberi tahu dengan pesan template otomatis, agar mereka
      // tahu pengaduannya sudah diproses tuntas meski hasilnya diarsipkan.
      final row = await detail(pengaduanId);
      final pelaporId = row?['pelapor_id'] as String?;
      if (pelaporId != null) {
        await NotificationService.kirimKePegawai(
          pegawaiId: pelaporId,
          judul: 'Pengaduan telah ditindaklanjuti',
          pesan: 'Terimakasih, pengaduan Anda '
              '(${row?['nomor_pengaduan']}) sudah kami tindaklanjuti.',
          pengaduanId: pengaduanId,
        );
      }
      return;
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguDirutTahap2.name,
      statusBaru: PengaduanStatus.menungguSdm.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Menerima hasil investigasi, diteruskan langsung ke SDM',
      catatan: catatan,
      kolomTambahan: {
        'keputusan_dirut_tahap2': keputusan.name,
        'catatan_dirut_tahap2': catatan,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.sdm,
      judul: 'Menunggu tindak lanjut administratif',
      pesan: 'Ada pengaduan yang perlu ditindaklanjuti (penurunan gaji).',
      pengaduanId: pengaduanId,
    );
  }

  /// DIREKSI (akun Dirut) — tahap 2: minta peninjauan kembali. Hasil
  /// investigasi dianggap belum cukup, sehingga pengaduan dikembalikan ke
  /// KSPI untuk memilih eksekutor investigasi lagi — alurnya sama persis
  /// seperti siklus investigasi yang pertama (KSPI pilih eksekutor ->
  /// investigasi berjalan -> hasil investigasi -> Dirut tahap 2).
  static Future<void> direksiTahap2PeninjauanKembali({
    required int pengaduanId,
    required String oleh,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguDirutTahap2.name,
      statusBaru: PengaduanStatus.menungguPilihEksekutor.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Meminta peninjauan kembali, dikembalikan ke KSPI untuk '
          'memilih eksekutor investigasi ulang',
      catatan: catatan,
      kolomTambahan: {
        'catatan_peninjauan_kembali': catatan,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.kspi,
      judul: 'Peninjauan kembali diminta Direktur',
      pesan: 'Direktur meminta peninjauan kembali atas hasil investigasi. '
          'Silakan pilih eksekutor investigasi ulang.',
      pengaduanId: pengaduanId,
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
      statusBaru: PengaduanStatus.tindakLanjutBerjalan.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Memilih eksekutor tindak lanjut: ${eksekutor.label}',
      kolomTambahan: {'eksekutor_tindak_lanjut': eksekutor.name},
    );

    final roleEksekutor = eksekutor == Eksekutor.kadiv
        ? UserRole.kadivKategori
        : eksekutor == Eksekutor.kspi
            ? UserRole.kspi
            : UserRole.tpdpk;
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
  /// Format angka menjadi ribuan dengan pemisah titik, mis. 150000 -> 150.000
  static String _formatRibuan(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return (n < 0 ? '-' : '') + buf.toString();
  }

  /// SDM — menurunkan gaji pegawai (sanksi) dan LANGSUNG terintegrasi ke
  /// payroll. Nominal ditambahkan ke kolom `potongan_sanksi_perusahaan` pada
  /// slip gaji periode terbaru milik pegawai dengan [nik] terkait.
  static Future<void> turunkanGajiPayroll({
    required String nik,
    required int nominal,
    int? pengaduanId,
  }) async {
    // 1. Cari pegawai berdasarkan NIK.
    final pegawaiRows = await _client
        .from('pegawai')
        .select('id, name')
        .eq('nik', nik)
        .limit(1);
    final pegawaiList = pegawaiRows as List;
    if (pegawaiList.isEmpty) {
      throw 'Pegawai dengan NIK $nik tidak ditemukan.';
    }
    final pegawaiId = pegawaiList.first['id'] as String;
    final namaPegawai = (pegawaiList.first['name'] ?? '-') as String;

    // 2. Ambil slip gaji periode terbaru milik pegawai tersebut.
    final payrollRows = await _client
        .from('payroll')
        .select('id, potongan_sanksi_perusahaan')
        .eq('pegawai_id', pegawaiId)
        .order('tahun', ascending: false)
        .order('bulan', ascending: false)
        .limit(1);
    final payrollList = payrollRows as List;
    if (payrollList.isEmpty) {
      throw 'Data payroll untuk $namaPegawai (NIK $nik) belum tersedia.';
    }
    final payrollRow = payrollList.first;

    // 3. Tambahkan nominal ke potongan sanksi perusahaan (turunkan gaji).
    final potonganLama = (payrollRow['potongan_sanksi_perusahaan'] ?? 0) as int;
    final potonganBaru = potonganLama + nominal;
    await _client
        .from('payroll')
        .update({'potongan_sanksi_perusahaan': potonganBaru}).eq(
            'id', payrollRow['id']);

    // 4. Beri tahu pegawai yang gajinya diturunkan.
    await NotificationService.kirimKePegawai(
      pegawaiId: pegawaiId,
      judul: 'Penyesuaian gaji (sanksi)',
      pesan: 'Gaji Anda dikenai potongan sanksi sebesar '
          'Rp${_formatRibuan(nominal)} pada slip gaji periode terbaru.',
      pengaduanId: pengaduanId,
    );
  }

  static Future<void> sdmSelesaikan({
    required int pengaduanId,
    required String oleh,
    String? catatan,
    String? nikTerlapor,
    int? nominalPenurunanGaji,
  }) async {
    // Jika SDM memutuskan menurunkan gaji (sanksi), terapkan langsung ke
    // payroll pegawai terkait sebelum pengaduan ditandai selesai.
    final adaPenurunan = nikTerlapor != null &&
        nikTerlapor.trim().isNotEmpty &&
        nominalPenurunanGaji != null &&
        nominalPenurunanGaji > 0;
    if (adaPenurunan) {
      await turunkanGajiPayroll(
        nik: nikTerlapor!.trim(),
        nominal: nominalPenurunanGaji!,
        pengaduanId: pengaduanId,
      );
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguSdm.name,
      statusBaru: PengaduanStatus.selesai.name,
      oleh: oleh,
      role: UserRole.sdm,
      aksi: adaPenurunan
          ? 'Menyelesaikan tindak lanjut administratif — penurunan gaji '
              'Rp${_formatRibuan(nominalPenurunanGaji!)} (NIK ${nikTerlapor!.trim()})'
          : 'Menyelesaikan tindak lanjut administratif',
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

  /// Mengirim notifikasi HANYA ke Kadiv pada divisi tertentu
  /// (administrasi / teknik), bukan ke semua Kadiv.
  static Future<void> kirimKeKadivDivisi({
    required DivisiKadiv divisi,
    required String judul,
    required String pesan,
    int? pengaduanId,
  }) async {
    final daftarKadiv = await _client
        .from('pegawai')
        .select('id')
        .eq('role', UserRole.kadivKategori.name)
        .eq('divisi_kadiv', divisi.name);

    for (final kadiv in (daftarKadiv as List)) {
      await _client.from('notifikasi').insert({
        'untuk_pegawai_id': kadiv['id'],
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
