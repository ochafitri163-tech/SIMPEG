import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Tampilkan browser notification menggunakan Web Notifications API.
void showWebNotification(String title, String body) {
  try {
    if (web.Notification.permission == 'granted') {
      web.Notification(
        title,
        web.NotificationOptions(body: body),
      );
    } else if (web.Notification.permission != 'denied') {
      // Minta izin dulu, baru tampilkan
      web.Notification.requestPermission().toDart.then((permission) {
        if (permission.toDart == 'granted') {
          web.Notification(
            title,
            web.NotificationOptions(body: body),
          );
        }
      });
    }
  } catch (_) {}
}

/// Minta izin notifikasi browser — dipanggil saat login atau saat
/// user mengaktifkan notifikasi di pengaturan.
Future<bool> requestWebNotificationPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}
