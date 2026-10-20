import 'package:flutter/foundation.dart';

/// Service untuk mencegah duplikasi notifikasi (Double Notification)
/// yang terjadi saat aplikasi terbuka di mana OneSignal foreground handler
/// dan Supabase Realtime listener aktif secara bersamaan.
class NotificationDeduplicator {
  NotificationDeduplicator._();

  static final Map<String, DateTime> _history = {};

  /// Mengembalikan `true` jika notifikasi ini BARU dan BOLEH ditampilkan.
  /// Mengembalikan `false` jika notifikasi dengan judul & pesan serupa
  /// sudah pernah ditampilkan dalam kurun waktu [windowSeconds] detik.
  static bool shouldDisplay(
    String title,
    String body, {
    int windowSeconds = 8,
  }) {
    final now = DateTime.now();

    // Bersihkan entri lama (> 60 detik) untuk menghemat memori
    _history.removeWhere((_, time) => now.difference(time).inSeconds > 60);

    final cleanTitle = title.trim().toLowerCase();
    final cleanBody = body.trim().toLowerCase();
    final key = '$cleanTitle|$cleanBody';

    // Jika kosong, jangan blokir
    if (key == '|') return true;

    final lastShown = _history[key];
    if (lastShown != null &&
        now.difference(lastShown).inSeconds < windowSeconds) {
      if (kDebugMode) {
        print(
          '⛔ [NotificationDeduplicator] Notifikasi duplikat dicegah: "$title" | "$body"',
        );
      }
      return false;
    }

    _history[key] = now;
    return true;
  }
}
