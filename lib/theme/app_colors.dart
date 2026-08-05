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

  /// Latar belakang utama halaman (Scaffold).
  static Color pageBackground(BuildContext context) =>
      isDark(context) ? const Color(0xFF10151C) : const Color(0xFFF3F6F9);

  /// Latar kartu/permukaan (menggantikan `Colors.white` yang di-hardcode).
  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF1B2230) : Colors.white;

  /// Latar elemen sekunder di dalam kartu (chip ikon dsb).
  static Color surfaceMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF242C3B) : const Color(0xFFF3F6F9);

  /// Teks judul/nilai utama (menggantikan Color(0xFF1B2733)).
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFEDEFF2) : const Color(0xFF1B2733);

  /// Teks label/hint sekunder (menggantikan Color(0xFF8B98A9)/0xFF9AA5B1).
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFF9AA6B2) : const Color(0xFF8B98A9);

  /// Garis pemisah tipis (menggantikan Color(0xFFF0F2F5)/0xFFEDF1F5).
  static Color divider(BuildContext context) =>
      isDark(context) ? const Color(0xFF2A3242) : const Color(0xFFF0F2F5);

  /// Bayangan kartu, dikurangi opacity-nya di mode gelap supaya tidak
  /// terlihat aneh di atas latar yang sudah gelap.
  static List<BoxShadow> cardShadow(BuildContext context) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark(context) ? 0.28 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}