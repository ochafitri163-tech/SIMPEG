import 'package:flutter/material.dart';

/// Palet warna terpusat yang otomatis menyesuaikan mode gelap/terang
/// berdasarkan `Theme.of(context).brightness`. Dipakai di seluruh
/// halaman (bukan cuma Pengaturan) supaya Mode Gelap benar-benar
/// konsisten di semua layar, tanpa mengubah warna brand/aksen yang
/// sudah ada.
///
/// Nilai gelap diselaraskan dengan `darkTheme` di main.dart
/// (scaffoldBackgroundColor: 0xFF10151C, cardColor: 0xFF1B2230).
class AppColors {
  AppColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Modern Luxury V2 Color Tokens
  static const Color primaryNavy = Color(0xFF0D2C6E);
  static const Color v2AccentTeal = Color(0xFF0EA5E9);
  static const Color v2AccentPurple = Color(0xFF6366F1);
  static const Color v2AccentEmerald = Color(0xFF10B981);
  static const Color v2AccentGold = Color(0xFFF59E0B);

  static const LinearGradient primaryGradientV2 = LinearGradient(
    colors: [Color(0xFF0A192F), Color(0xFF0D2C6E), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradientV2 = LinearGradient(
    colors: [Color(0xFF0A192F), Color(0xFF0D2C6E), Color(0xFF1E3A8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradientV2 = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Alias getters
  static LinearGradient get v2PrimaryGradient => primaryGradientV2;
  static LinearGradient get v2HeroGradient => heroGradientV2;
  static LinearGradient get v2AccentGradient => accentGradientV2;

  /// Latar belakang utama halaman (Scaffold).
  static Color pageBackground(BuildContext context) =>
      isDark(context) ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);

  /// Latar kartu/permukaan (menggantikan `Colors.white` yang di-hardcode).
  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF131C2E) : Colors.white;

  /// Latar elemen sekunder di dalam kartu (chip ikon dsb).
  static Color surfaceMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

  /// Teks judul/nilai utama (menggantikan Color(0xFF1B2733)).
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

  /// Teks label/hint sekunder (menggantikan Color(0xFF8B98A9)/0xFF9AA5B1).
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  /// Garis pemisah tipis (menggantikan Color(0xFFF0F2F5)/0xFFEDF1F5).
  static Color divider(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  /// Bayangan kartu, dikurangi opacity-nya di mode gelap supaya tidak
  /// terlihat aneh di atas latar yang sudah gelap.
  static List<BoxShadow> cardShadow(BuildContext context) => [
        BoxShadow(
          color: isDark(context)
              ? Colors.black.withValues(alpha: 0.4)
              : const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> v2FloatingShadow(BuildContext context) => [
        BoxShadow(
          color: isDark(context)
              ? const Color(0xFF000000).withValues(alpha: 0.5)
              : const Color(0xFF1E3A8A).withValues(alpha: 0.12),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 10),
        ),
      ];
}