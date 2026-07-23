import 'package:flutter/material.dart';
import 'package:simpeg_mobile/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> confirmLogoutPatched(context) async {
  const danger = Color(0xFFE74C3C);
  const labelDark = Color(0xFF1B2733);
  const hintGrey = Color(0xFF9AA5B1);

  final konfirmasi = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 24,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Text(
              'Keluar Akun?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: labelDark,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: const Text(
          'Kamu akan keluar dari akun ini dan perlu login ulang untuk mengakses aplikasi.',
          style: TextStyle(
            fontSize: 14,
            color: hintGrey,
            height: 1.5,
            letterSpacing: 0.1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: hintGrey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: danger.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (konfirmasi == true && context.mounted) {
    await Supabase.instance.client.auth.signOut();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}