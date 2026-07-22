import 'package:flutter/material.dart';
import '../models/user_role.dart';

/// Middleware/Guard sederhana untuk otorisasi halaman & tombol berdasarkan
/// role yang sedang login.
///
/// Karena project ini tidak memakai named routing (navigasi memakai
/// `Navigator.push(MaterialPageRoute(...))` langsung), guard diterapkan
/// dengan cara membungkus setiap halaman yang butuh proteksi role dengan
/// widget [RoleGuard]. Kalau role user tidak termasuk `allowedRoles`,
/// user akan melihat halaman "Akses Ditolak" alih-alih konten asli.
///
/// Contoh pemakaian pada sebuah screen:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return RoleGuard(
///     user: widget.user,
///     allowedRoles: const [UserRole.kspi],
///     child: Scaffold(...),
///   );
/// }
/// ```
class RoleGuard extends StatelessWidget {
  final AppUser user;
  final List<UserRole> allowedRoles;
  final Widget child;

  const RoleGuard({
    super.key,
    required this.user,
    required this.allowedRoles,
    required this.child,
  });

  bool get _diizinkan => allowedRoles.contains(user.role);

  @override
  Widget build(BuildContext context) {
    if (_diizinkan) return child;
    return AccessDeniedScreen(user: user);
  }
}

/// Halaman standar yang ditampilkan ketika role user tidak berwenang
/// mengakses suatu halaman.
class AccessDeniedScreen extends StatelessWidget {
  final AppUser user;
  const AccessDeniedScreen({super.key, required this.user});

  static const Color _navy = Color(0xFF0D2C6E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Akses Ditolak'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Anda tidak memiliki hak akses\nuntuk membuka halaman ini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
              ),
              const SizedBox(height: 6),
              Text(
                'Role Anda saat ini: ${user.role.label}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kumpulan helper otorisasi tingkat-menu/tombol (dipakai di dalam
/// dashboard/screen untuk menyembunyikan atau menonaktifkan aksi yang
/// bukan kewenangan role yang sedang login).
class Authz {
  Authz._();

  /// Menu utama Pengaduan yang boleh dilihat tiap role pada dashboard
  /// masing-masing (dipakai Tahap 3 saat membangun isi dashboard).
  static List<String> menuPengaduan(UserRole role) {
    switch (role) {
      case UserRole.pegawai:
        return const [
          'Buat Pengaduan',
          'Riwayat Pengaduan',
          'Detail Pengaduan',
          'Status Pengaduan',
        ];
      case UserRole.kadivKategori:
        return const [
          'Pengaduan Masuk',
          'Pengaduan Berdasarkan Kategori',
          'Verifikasi Pengaduan',
          'Disposisi ke KSPI',
        ];
      case UserRole.kspi:
        return const [
          'Pengaduan dari Kadiv',
          'Review Pengaduan',
          'Pilih Eksekutor',
          'Pilih Petugas Investigasi',
          'Kirim ke TPDPK',
          'Terima Hasil Investigasi',
          'Review Hasil Investigasi',
          'Kembalikan untuk Revisi',
          'Kirim ke Direktur',
        ];
      case UserRole.tpdpk:
        return const [
          'Daftar Investigasi',
          'Tugas Investigasi',
          'Hasil Investigasi',
          'Surat Rekomendasi',
        ];
      case UserRole.direktur:
        return const [
          'Pengaduan Menunggu Persetujuan',
          'Detail Pengaduan',
          'Detail Investigasi',
          'Surat Rekomendasi',
          'Riwayat',
        ];
      case UserRole.sdm:
        return const [
          'Menunggu Tindak Lanjut SDM',
          'Detail Pengaduan',
          'Selesaikan Tindak Lanjut',
          'Riwayat',
        ];
    }
  }

  /// Apakah role boleh MEMBUAT laporan pengaduan baru.
  static bool bolehMembuatLaporan(UserRole role) => role == UserRole.pegawai;

  /// Apakah role boleh melakukan verifikasi & kategorisasi awal.
  static bool bolehVerifikasiKadiv(UserRole role) =>
      role == UserRole.kadivKategori;

  /// Apakah role boleh melakukan review & memilih eksekutor/petugas di KSPI.
  static bool bolehReviewKspi(UserRole role) => role == UserRole.kspi;

  /// Apakah role boleh melakukan investigasi & membuat surat rekomendasi.
  static bool bolehInvestigasiTpdpk(UserRole role) => role == UserRole.tpdpk;

  /// Apakah role boleh memutuskan (setuju/tolak/tinjau ulang/tindak lanjut).
  static bool bolehMemutuskanDirektur(UserRole role) =>
      role == UserRole.direktur;

  /// Apakah role boleh melihat riwayat lengkap semua pengaduan (bukan hanya
  /// miliknya sendiri).
  static bool bolehLihatSemuaRiwayat(UserRole role) =>
      role != UserRole.pegawai;
}