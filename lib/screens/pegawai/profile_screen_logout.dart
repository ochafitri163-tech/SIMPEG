// =====================================================================
// PATCH untuk profile_screen.dart — HANYA bagian _confirmLogout() yang
// berubah. Seluruh bagian lain file (header, identity card, menu list,
// dst) TIDAK perlu diubah karena sudah 100% dinamis (murni menampilkan
// field dari `user` yang didapat dari Supabase saat login).
//
// CARA PAKAI: di profile_screen.dart, ganti isi method _confirmLogout()
// dengan versi di bawah ini. Tambahkan juga import supabase_flutter di
// bagian atas file.
// =====================================================================

// Tambahkan import ini di bagian atas profile_screen.dart:
// import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:simpeg_mobile/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Menampilkan dialog konfirmasi sebelum benar-benar keluar, lalu
/// memanggil Supabase signOut() supaya sesi login benar-benar berakhir
/// (bukan cuma pindah halaman doang seperti versi lama).
Future<void> confirmLogoutPatched(context) async {
  const danger = Color(0xFFE74C3C);
  const labelDark = Color(0xFF1B2733);
  const hintGrey = Color(0xFF9AA5B1);

  final konfirmasi = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar Akun?',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: labelDark),
        ),
        content: const Text(
          'Kamu akan keluar dari akun ini dan perlu login ulang untuk mengakses aplikasi.',
          style: TextStyle(fontSize: 13, color: hintGrey, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal',
                style: TextStyle(color: hintGrey, fontSize: 13.5)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Keluar', style: TextStyle(fontSize: 13.5)),
          ),
        ],
      );
    },
  );

  if (konfirmasi == true && context.mounted) {
    // PENTING: signOut dari Supabase dulu, baru pindah halaman.
    // Tanpa ini, token sesi tetap tersimpan & auth.currentUser masih
    // terisi walau UI sudah "kelihatan" logout.
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
