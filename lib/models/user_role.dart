/// Daftar role/aktor yang berlaku pada alur Pengaduan Pegawai.
///
/// Urutan alur: Pegawai -> Kadiv Kategori -> KSPI -> TPDPK -> KSPI -> Direktur.
enum UserRole {
  pegawai,
  kadivKategori,
  kspi,
  tpdpk,
  direktur,
}

extension UserRoleX on UserRole {
  /// Label tampilan role (dipakai di header dashboard, badge, riwayat, dsb).
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
    }
  }

  /// Kode singkat role, dipakai pada riwayat status & log.
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
    }
  }

  /// Dipakai untuk menyimpan/membaca role dari string (mis. hasil API nanti).
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
      case 'PEGAWAI':
      default:
        return UserRole.pegawai;
    }
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
  // Teks golongan lengkap sesuai format resmi di slip Gaji/THR/Insentif,
  // mis. "GOL. B.1 - MASA KERJA 1 THN, 0 BLN / ISTRI 0 ANAK 0". Kalau null,
  // PDF akan jatuh ke "GOL. <golongan>" sebagai fallback.
  final String? golonganDetail;
  final String status;
  final String tempatTanggalLahir;
  final String statusPernikahan;
  final String alamat;
  final String noTelp;

  /// Role/aktor pengguna pada alur Pengaduan (dan sistem secara umum).
  /// Default `UserRole.pegawai` supaya kode lama yang belum menentukan role
  /// tetap kompatibel.
  final UserRole role;

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
    this.role = UserRole.pegawai,
  });

  /// Teks golongan lengkap untuk kop dokumen resmi (Gaji/THR/Insentif).
  String get golonganUntukSlip => golonganDetail ?? 'GOL. $golongan';

  /// Inisial nama untuk avatar (mis. "Bayu Aji" -> "BA").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

/// Model kredensial akun demo (belum terhubung ke API/database sungguhan).
/// Ganti/gabungkan dengan hasil autentikasi backend saat sudah tersedia.
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
  });
}

/// Daftar akun demo untuk masing-masing role.
/// TODO: hapus/nonaktifkan daftar ini setelah autentikasi API sungguhan siap.
/// Kop dokumen PDF (Gaji/THR/Insentif) selalu mengikuti identitas pegawai
/// yang sedang login di bawah ini — bukan data pegawai contoh dari PDF
/// resmi manapun.
final List<DemoAccount> demoAccounts = [
  DemoAccount(
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
  DemoAccount(
    nik: '4000000001',
    password: 'kadiv123',
    name: 'Siti Rahmawati',
    email: 'siti.rahmawati@pdam.co.id',
    jabatan: 'Kepala Divisi Produksi',
    unitKerja: 'Kantor Pusat',
    unitKerjaSingkat: 'Kantor Pusat',
    golongan: 'A.2 / Struktural',
    role: UserRole.kadivKategori,
  ),
  DemoAccount(
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
  DemoAccount(
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
  DemoAccount(
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
];

/// Mencari akun demo berdasarkan NIK & password. Mengembalikan null jika
/// tidak cocok.
DemoAccount? findDemoAccount(String nik, String password) {
  for (final acc in demoAccounts) {
    if (acc.nik == nik && acc.password == password) {
      return acc;
    }
  }
  return null;
}