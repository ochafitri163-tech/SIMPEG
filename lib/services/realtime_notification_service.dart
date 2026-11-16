import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'notification_deduplicator.dart';
import 'web_notification_stub.dart'
    if (dart.library.js_interop) 'web_notification_web.dart';

/// Service Notifikasi Realtime / Polling lokal.
///
/// Berfungsi menampilkan notifikasi lokal pada Web/Android/iOS
/// saat ada event atau notifikasi baru dari backend.
class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final RealtimeNotificationService instance =
      RealtimeNotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Minta izin notifikasi browser saat pertama kali init di Web
    if (kIsWeb) {
      try {
        await requestWebNotificationPermission();
      } catch (_) {}
    }

    _initialized = true;
  }

  /// Menampilkan notifikasi — otomatis pilih metode yang sesuai platform.
  /// - Android/iOS: flutter_local_notifications (status bar)
  /// - Web: Web Notifications API (browser notification)
  void showNotification({required String title, required String body}) {
    if (!NotificationDeduplicator.shouldDisplay(title, body)) {
      if (kDebugMode) {
        print(
          '⛔ [RealtimeNotification] Notifikasi diabaikan (duplikat): "$title" | "$body"',
        );
      }
      return;
    }
    if (kIsWeb) {
      showWebNotification(title, body);
    } else {
      NotificationService.instance.showPengumuman(
        title: title,
        body: body,
      );
    }
  }
}
