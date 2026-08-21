import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Satu akun yang "diingat" di perangkat ini.
///
/// Password TIDAK pernah dikirim/disimpan ke database Supabase maupun
/// Laravel. Nilainya hanya berada di penyimpanan terenkripsi milik OS:
///   • Android  -> EncryptedSharedPreferences (AES, Android Keystore)
///   • iOS/macOS-> Keychain (accessible setelah unlock pertama)
///   • Web      -> localStorage TERENKRIPSI WebCrypto AES-GCM oleh plugin
///                 (kunci disimpan di IndexedDB, bukan plaintext)
///   • Windows  -> DPAPI
class AkunTersimpan {
  final String nik;
  final String nama;
  final String password;
  final DateTime terakhirLogin;

  const AkunTersimpan({
    required this.nik,
    required this.nama,
    required this.password,
    required this.terakhirLogin,
  });

  /// Inisial untuk avatar bulat di daftar akun.
  String get inisial {
    final bagian =
        nama.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (bagian.isEmpty) return nik.isEmpty ? '?' : nik.substring(0, 1);
    if (bagian.length == 1) return bagian.first.substring(0, 1).toUpperCase();
    return (bagian.first.substring(0, 1) + bagian[1].substring(0, 1))
        .toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'nik': nik,
        'nama': nama,
        'password': password,
        'terakhir_login': terakhirLogin.toIso8601String(),
      };

  static AkunTersimpan fromJson(Map<String, dynamic> j) => AkunTersimpan(
        nik: (j['nik'] ?? '') as String,
        nama: (j['nama'] ?? 'Pegawai') as String,
        password: (j['password'] ?? '') as String,
        terakhirLogin:
            DateTime.tryParse('${j['terakhir_login']}') ?? DateTime.now(),
      );
}

/// Pengelola fitur "Ingat Saya".
///
/// CATATAN PENTING: service ini HANYA untuk autofill form login. Ia tidak
/// membuat sesi, tidak menyimpan token, dan tidak menyentuh alur
/// autentikasi/logout yang sudah ada. Jadi setelah user logout, sesi tetap
/// berakhir — yang tersisa hanya isian form yang bisa dipakai ulang.
class RememberedAccountService {
  RememberedAccountService._();

  static const String _key = 'simpeg_akun_tersimpan_v1';

  /// Batas akun yang diingat per perangkat.
  static const int maksAkun = 5;

  static final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Semua akun tersimpan, terbaru di atas. Aman dari exception —
  /// bila data korup, penyimpanan dibersihkan dan mengembalikan list kosong.
  static Future<List<AkunTersimpan>> semua() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const [];
      final list = (jsonDecode(raw) as List)
          .map((e) => AkunTersimpan.fromJson(e as Map<String, dynamic>))
          .where((a) => a.nik.isNotEmpty && a.password.isNotEmpty)
          .toList();
      list.sort((a, b) => b.terakhirLogin.compareTo(a.terakhirLogin));
      return list;
    } catch (_) {
      await hapusSemua();
      return const [];
    }
  }

  /// Simpan / perbarui satu akun. Dipanggil HANYA saat login sukses dan
  /// checkbox "Ingat saya" dicentang.
  static Future<void> simpan({
    required String nik,
    required String nama,
    required String password,
  }) async {
    final bersihNik = nik.trim();
    if (bersihNik.isEmpty || password.isEmpty) return;

    final list = (await semua()).where((a) => a.nik != bersihNik).toList();
    list.insert(
      0,
      AkunTersimpan(
        nik: bersihNik,
        nama: nama.trim().isEmpty ? 'Pegawai' : nama.trim(),
        password: password,
        terakhirLogin: DateTime.now(),
      ),
    );
    if (list.length > maksAkun) list.removeRange(maksAkun, list.length);
    await _tulis(list);
  }

  /// Hapus satu akun tersimpan (tombol "Hapus akun tersimpan").
  static Future<void> hapus(String nik) async {
    final list = (await semua()).where((a) => a.nik != nik.trim()).toList();
    await _tulis(list);
  }

  /// Hapus SEMUA kredensial dari perangkat ini.
  static Future<void> hapusSemua() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Abaikan: penyimpanan mungkin belum pernah dibuat.
    }
  }

  /// Dipanggil saat "Ingat saya" TIDAK dicentang: pastikan kredensial NIK
  /// tersebut tidak tertinggal dari sesi login sebelumnya.
  static Future<void> lupakanJikaAda(String nik) => hapus(nik);

  static Future<void> _tulis(List<AkunTersimpan> list) async {
    if (list.isEmpty) {
      await hapusSemua();
      return;
    }
    await _storage.write(
      key: _key,
      value: jsonEncode(list.map((a) => a.toJson()).toList()),
    );
  }
}
