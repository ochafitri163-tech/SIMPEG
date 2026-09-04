/// Daftar role/aktor pada alur Pengaduan Pegawai.
///
/// Alur: Pegawai -> Kadiv (per divisi) -> Dirut (tahap 1) -> KSPI (pilih
/// eksekutor) -> Kadiv/TPDPK (investigasi) -> Direksi (tahap 2, akun Dirut
/// yang sama) -> Kadiv/TPDPK (tindak lanjut) -> SDM -> Selesai.
enum UserRole {
  pegawai,
  kadivKategori,
  kspi,
  tpdpk,
  direktur,
  sdm,
  keuangan,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.pegawai:
        return 'Pegawai';
      case UserRole.kadivKategori:
        return 'Kadiv Kategori';
      case UserRole.kspi:
        return 'KSPI';
      case UserRole.tpdpk:
        return 'TPDPK';
      case UserRole.direktur:
        return 'Direktur (DIRUT)';
      case UserRole.sdm:
        return 'SDM';
      case UserRole.keuangan:
        return 'Keuangan';
    }
  }

  String get kode {
    switch (this) {
      case UserRole.pegawai:
        return 'PEGAWAI';
      case UserRole.kadivKategori:
        return 'KADIV';
      case UserRole.kspi:
        return 'KSPI';
      case UserRole.tpdpk:
        return 'TPDPK';
      case UserRole.direktur:
        return 'DIRUT';
      case UserRole.sdm:
        return 'SDM';
      case UserRole.keuangan:
        return 'KEUANGAN';
    }
  }

  static UserRole fromKode(String kode) {
    switch (kode.trim().toLowerCase()) {
      case 'kadiv':
      case 'kadivkategori':
        return UserRole.kadivKategori;
      case 'dirut':
      case 'direktur':
        return UserRole.direktur;
      case 'kspi':
        return UserRole.kspi;
      case 'tpdpk':
        return UserRole.tpdpk;
      case 'sdm':
        return UserRole.sdm;
      case 'keuangan':
        return UserRole.keuangan;
      case 'kasir':
      case 'pegawai':
      default:
        return UserRole.pegawai;
    }
  }
}

/// Divisi Kadiv — menentukan Kadiv mana yang menerima notifikasi
/// pengaduan, berdasarkan kategori yang dipilih Pegawai saat submit
/// ("Pelanggaran Administrasi" -> administrasi, "Pelanggaran Teknik" ->
/// teknik).
enum DivisiKadiv { administrasi, teknik }

extension DivisiKadivX on DivisiKadiv {
  String get label {
    switch (this) {
      case DivisiKadiv.administrasi:
        return 'Kadiv Administrasi';
      case DivisiKadiv.teknik:
        return 'Kadiv Teknik';
    }
  }
}

enum KategoriDivisi { devAdmin, devTeknik }

extension KategoriDivisiX on KategoriDivisi {
  String get label {
    switch (this) {
      case KategoriDivisi.devAdmin:
        return 'Divisi Administrasi';
      case KategoriDivisi.devTeknik:
        return 'Divisi Teknik';
    }
  }
}

/// Memetakan kategori pengaduan (dipilih Pegawai di form) ke divisi Kadiv
/// yang berwenang menanganinya. Return null kalau kategori tidak dikenal.
DivisiKadiv? divisiKadivDariKategori(String kategori) {
  switch (kategori) {
    case 'Pelanggaran Administrasi':
      return DivisiKadiv.administrasi;
    case 'Pelanggaran Teknik':
      return DivisiKadiv.teknik;
    default:
      return null;
  }
}

/// Kebalikan dari [divisiKadivDariKategori]: memetakan divisi Kadiv ke
/// nama kategori pengaduan yang dipakai di form pegawai & kolom
/// `kategori` pada tabel `pengaduan_pegawai`.
String kategoriDariDivisiKadiv(DivisiKadiv divisi) {
  switch (divisi) {
    case DivisiKadiv.administrasi:
      return 'Pelanggaran Administrasi';
    case DivisiKadiv.teknik:
      return 'Pelanggaran Teknik';
  }
}

class AppUser {
  final String nik;
  final String name;
  final String gelar;
  final String jabatan;
  final String unitKerja;
  final String unitKerjaSingkat;
  final String golongan;
  final String? golonganDetail;
  final String status;
  final String tempatTanggalLahir;
  final String statusPernikahan;
  final String alamat;
  final String noTelp;
  final String? fotoUrl;
  final UserRole role;

  /// Hanya relevan kalau role == UserRole.kadivKategori. Menentukan
  /// pengaduan kategori apa yang muncul di kotak masuk Kadiv ini.
  final DivisiKadiv? divisiKadiv;

  const AppUser({
    required this.nik,
    required this.name,
    this.gelar = '',
    this.jabatan = 'Staf Unit Produksi Indramayu',
    this.unitKerja = 'Cabang Indramayu',
    this.unitKerjaSingkat = 'Cab. Indramayu',
    this.golongan = 'B.3 / Pelaksana',
    this.golonganDetail,
    this.status = 'Pegawai Tetap',
    this.tempatTanggalLahir = 'Indramayu, 25 Januari 1995',
    this.statusPernikahan = 'Sudah Menikah',
    this.alamat = 'Blok Panggang RT.03 RW.01, Tegalsembadra, Balongan',
    this.noTelp = '0877-2764-1009',
    this.fotoUrl,
    this.role = UserRole.pegawai,
    this.divisiKadiv,
  });

  String get id => nik;
  String get golonganUntukSlip => golonganDetail ?? 'GOL. $golongan';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// Serialisasi ke Map untuk disimpan di SharedPreferences
  Map<String, dynamic> toJson() => {
        'nik': nik,
        'name': name,
        'gelar': gelar,
        'jabatan': jabatan,
        'unitKerja': unitKerja,
        'unitKerjaSingkat': unitKerjaSingkat,
        'golongan': golongan,
        'golonganDetail': golonganDetail,
        'status': status,
        'tempatTanggalLahir': tempatTanggalLahir,
        'statusPernikahan': statusPernikahan,
        'alamat': alamat,
        'noTelp': noTelp,
        'fotoUrl': fotoUrl,
        'role': role.kode,
        'divisiKadiv': divisiKadiv?.name,
      };

  /// Deserialisasi dari Map yang disimpan di SharedPreferences
  factory AppUser.fromJson(Map<String, dynamic> json) {
    DivisiKadiv? divisi;
    final divisiStr = json['divisiKadiv'] as String?;
    if (divisiStr == 'administrasi') divisi = DivisiKadiv.administrasi;
    if (divisiStr == 'teknik') divisi = DivisiKadiv.teknik;

    return AppUser(
      nik: json['nik'] ?? '',
      name: json['name'] ?? '',
      gelar: json['gelar'] ?? '',
      jabatan: json['jabatan'] ?? 'Pegawai',
      unitKerja: json['unitKerja'] ?? 'Tirta Darma Ayu',
      unitKerjaSingkat: json['unitKerjaSingkat'] ?? 'TDA',
      golongan: json['golongan'] ?? 'III/a',
      golonganDetail: json['golonganDetail'] as String?,
      status: json['status'] ?? 'Pegawai Tetap',
      tempatTanggalLahir: json['tempatTanggalLahir'] ?? '',
      statusPernikahan: json['statusPernikahan'] ?? '',
      alamat: json['alamat'] ?? '',
      noTelp: json['noTelp'] ?? '',
      fotoUrl: json['fotoUrl'] as String?,
      role: UserRoleX.fromKode(json['role'] ?? 'PEGAWAI'),
      divisiKadiv: divisi,
    );
  }
}
