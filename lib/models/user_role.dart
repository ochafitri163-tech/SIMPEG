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
      // Kadiv: DB menyimpan 'kadivKategori', kode lama mencari 'KADIV'
      case 'kadiv':
      case 'kadivkategori':
        return UserRole.kadivKategori;

      // Direktur: DB menyimpan 'direktur', kode lama mencari 'DIRUT'
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

      // 18 'kasir' di DB diperlakukan sebagai pegawai biasa.
      // JANGAN tambahkan kasir ke enum UserRole: ada 4 file dengan
      // switch exhaustive yang akan gagal compile.
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

class DemoAccount {
  final String nik;
  final String password;
  final String name;
  final String email;
  final String jabatan;
  final String unitKerja;
  final String unitKerjaSingkat;
  final String golongan;
  final String golonganDetail;
  final UserRole role;
  final DivisiKadiv? divisiKadiv;

  const DemoAccount({
    required this.nik,
    required this.password,
    required this.name,
    required this.email,
    this.jabatan = 'Staf Unit Produksi Indramayu',
    this.unitKerja = 'Cabang Indramayu',
    this.unitKerjaSingkat = 'Cab. Indramayu',
    this.golongan = 'B.3 / Pelaksana',
    this.golonganDetail = '',
    this.role = UserRole.pegawai,
    this.divisiKadiv,
  });
}

/// TODO: hapus/nonaktifkan setelah autentikasi API sungguhan siap.
final List<DemoAccount> demoAccounts = [
  const DemoAccount(
    nik: '2000000001',
    password: 'password',
    name: 'Mukti Kurniawan',
    email: 'mukti.kurniawan@pdam.co.id',
    jabatan: 'Staf SDM',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'III/a',
    role: UserRole.sdm,
  ),
  const DemoAccount(
    nik: '2000000002',
    password: 'password',
    name: 'Dewi Anggraini',
    email: 'dewi.anggraini@pdam.co.id',
    jabatan: 'Staf Keuangan',
    unitKerja: 'Divisi Keuangan',
    unitKerjaSingkat: 'Div. Keuangan',
    golongan: 'II/d',
    role: UserRole.pegawai,
  ),
  const DemoAccount(
    nik: '3000000003',
    password: 'pegawai123',
    name: 'Budi Santoso',
    email: 'budi.santoso@pdam.co.id',
    jabatan: 'Staf Unit Produksi Indramayu',
    unitKerja: 'Cabang Indramayu',
    unitKerjaSingkat: 'Cab. Indramayu',
    golongan: 'B.3 / Pelaksana',
    role: UserRole.pegawai,
  ),
  const DemoAccount(
    nik: '4000000001',
    password: 'kadiv123',
    name: 'Siti Rahmawati',
    email: 'siti.rahmawati@pdam.co.id',
    jabatan: 'Kepala Divisi Administrasi',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'A.2 / Struktural',
    role: UserRole.kadivKategori,
    divisiKadiv: DivisiKadiv.administrasi,
  ),
  const DemoAccount(
    nik: '4000000006',
    password: 'kadivteknik2025',
    name: 'Agus Setiawan',
    email: 'agus.setiawan@pdam.co.id',
    jabatan: 'Kepala Divisi Teknik',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'A.2 / Struktural',
    role: UserRole.kadivKategori,
    divisiKadiv: DivisiKadiv.teknik,
  ),
  const DemoAccount(
    nik: '4000000002',
    password: 'kspi123',
    name: 'Ahmad Fauzi',
    email: 'ahmad.fauzi@pdam.co.id',
    jabatan: 'Kepala Satuan Pengawas Internal',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'A.1 / Struktural',
    role: UserRole.kspi,
  ),
  const DemoAccount(
    nik: '4000000003',
    password: 'tpdpk123',
    name: 'Dedi Kurniawan',
    email: 'dedi.kurniawan@pdam.co.id',
    jabatan: 'Tim Penegak Disiplin Pegawai dan Kode Etik',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'A.2 / Struktural',
    role: UserRole.tpdpk,
  ),
  const DemoAccount(
    nik: '5000000001',
    password: 'dirut123',
    name: 'H. Dedi Supriadi',
    email: 'direktur@pdam.co.id',
    jabatan: 'Direktur Utama',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'A.1 / Struktural',
    role: UserRole.direktur,
  ),
  const DemoAccount(
    nik: '5000000002',
    password: 'sdm123',
    name: 'Victoria Usang',
    email: 'victoria.usang@pdam.co.id',
    jabatan: 'Staf SDM',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'PT',
    role: UserRole.sdm,
  ),
  const DemoAccount(
    nik: '6000000001',
    password: 'keuangan123',
    name: 'Antony Loyal',
    email: 'antony.loyal@pdam.co.id',
    jabatan: 'Staf Unit Produksi Indramayu',
    unitKerja: 'Cabang Indramayu',
    unitKerjaSingkat: 'Cabang Indramayu',
    golongan: 'B.1 / Pelaksana',
    role: UserRole.keuangan,
  ),
  const DemoAccount(
    nik: '4000000005',
    password: 'kadivadmin2025',
    name: 'Nur Aisyah Lestari',
    email: 'nur.aisyah@pdam.co.id',
    jabatan: 'Kepala Divisi Administrasi',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'A.2 / Struktural',
    role: UserRole.kadivKategori,
    divisiKadiv: DivisiKadiv.administrasi,
  ),
];

DemoAccount? findDemoAccount(String nik, String password) {
  for (final acc in demoAccounts) {
    if (acc.nik == nik && acc.password == password) {
      return acc;
    }
  }
  return null;
}
