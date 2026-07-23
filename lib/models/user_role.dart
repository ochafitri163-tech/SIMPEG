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
    }
  }

  static UserRole fromKode(String kode) {
    switch (kode.toUpperCase()) {
      case 'KADIV':
        return UserRole.kadivKategori;
      case 'KSPI':
        return UserRole.kspi;
      case 'TPDPK':
        return UserRole.tpdpk;
      case 'DIRUT':
        return UserRole.direktur;
      case 'SDM':
        return UserRole.sdm;
      case 'PEGAWAI':
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

  String get golonganUntukSlip => golonganDetail ?? 'GOL. $golongan';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
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
    password: 'kadivadmin123',
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
    nik: '4000000004',
    password: 'kadivteknik123',
    name: 'Bambang Wijaya',
    email: 'bambang.wijaya@pdam.co.id',
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
    nik: '6000000001',
    password: 'sdm123',
    name: 'Rina Amelia',
    email: 'rina.amelia@pdam.co.id',
    jabatan: 'Staf SDM',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'B.1 / Pelaksana',
    role: UserRole.sdm,
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
