import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'notification_nav_helper.dart';
import 'notification_deduplicator.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  static const String appId = 'be392c07-5e8e-4f89-9129-e1cbf6503bea';

  bool _initialized = false;
  bool _permissionRequestedOnce = false;
  static VoidCallback? onForegroundNotification;
  static final ValueNotifier<int> foregroundVersion = ValueNotifier<int>(0);
  String? _lastLoginNik;
  String? _lastRole;
  String? _lastDivisi;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> init() async {
    if (!_isSupportedPlatform || _initialized) return;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      OneSignal.initialize(appId);

      // Daftarkan listener secara sinkron TEPAT setelah initialize()
      // agar tap notifikasi saat cold-start tidak pernah terlewat.
      OneSignal.Notifications.addClickListener((event) {
        if (kDebugMode) {
          print('Notifikasi OneSignal Diklik: ${event.notification.title}');
        }
        final data = event.notification.additionalData;
        NotificationNavHelper.handleNotificationClick(data);
      });

      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        final title = event.notification.title ?? '';
        final body = event.notification.body ?? '';
        if (kDebugMode) {
          print('Notifikasi OneSignal Masuk di Foreground: $title');
        }
        if (NotificationDeduplicator.shouldDisplay(title, body)) {
          event.notification.display();
          foregroundVersion.value++;
          onForegroundNotification?.call();
        } else {
          // OneSignal SDK v5 wajib memanggil preventDefault() agar notifikasi duplikat tidak muncul.
          event.preventDefault();
          if (kDebugMode) {
            print(
              'Notifikasi OneSignal di-suppress (duplikat dicegah): $title | $body',
            );
          }
        }
      });

      OneSignal.Notifications.addPermissionObserver((granted) {
        if (granted) {
          try {
            OneSignal.User.pushSubscription.optIn();
          } catch (_) {}
          _resyncLastUserIfNeeded();
        }
      });

      OneSignal.User.pushSubscription.addObserver((state) {
        if (state.current.id != null && state.current.id!.isNotEmpty) {
          _resyncLastUserIfNeeded();
        }
      });

      // Pastikan Push Subscription aktif tanpa memblokir Activity startup sebelum UI ter-mount.
      try {
        OneSignal.User.pushSubscription.optIn();
      } catch (_) {}

      _initialized = true;
      if (kDebugMode) {
        print('OneSignal Berhasil Diinisialisasi.');
        print('OneSignal Push Subscribed: ${OneSignal.User.pushSubscription.optedIn}');
        print('OneSignal Subscription ID: ${OneSignal.User.pushSubscription.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal Init Error: $e');
      }
    }
  }

  Future<void> _resyncLastUserIfNeeded() async {
    final nik = _lastLoginNik;
    if (nik == null || nik.isEmpty) return;
    try {
      await OneSignal.login(nik);
      if (_lastRole != null && _lastRole!.isNotEmpty) {
        await OneSignal.User.addTagWithKey('role', _lastRole!.toLowerCase().trim());
      }
      if (_lastDivisi != null && _lastDivisi!.isNotEmpty) {
        await OneSignal.User.addTagWithKey('divisi_kadiv', _lastDivisi!.toLowerCase().trim());
      }
    } catch (_) {}
  }

  /// Dipanggil setelah Dashboard / UI utama aktif (aman di Android 13–15 & semua OEM)
  /// untuk memastikan runtime permission POST_NOTIFICATIONS diminta dan sesi OneSignal tersinkron.
  Future<void> ensurePermissionAndSync(
    String nik, {
    String? role,
    String? divisiKadiv,
  }) async {
    if (!_isSupportedPlatform) return;
    if (!_initialized) {
      await init();
    }
    try {
      final hasPermission = OneSignal.Notifications.permission;
      if (!hasPermission && !_permissionRequestedOnce) {
        _permissionRequestedOnce = true;
        await OneSignal.Notifications.requestPermission(true);
      }
      await loginUser(nik, role: role, divisiKadiv: divisiKadiv);
    } catch (_) {}
  }

  /// Pasang Tag Role pengguna saat login
  Future<void> setUserRoleTag(String role) async {
    if (!_isSupportedPlatform) return;
    try {
      await OneSignal.User.addTagWithKey('role', role.toLowerCase().trim());
      if (kDebugMode) {
        print('OneSignal Tag role="${role.toLowerCase().trim()}" berhasil dipasang.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal set tag error: $e');
      }
    }
  }

  /// Pasang Tag Divisi Kadiv (administrasi / teknik)
  Future<void> setDivisiKadivTag(String divisi) async {
    if (!_isSupportedPlatform) return;
    try {
      await OneSignal.User.addTagWithKey(
        'divisi_kadiv',
        divisi.toLowerCase().trim(),
      );
      if (kDebugMode) {
        print('OneSignal Tag divisi_kadiv="${divisi.toLowerCase().trim()}" berhasil dipasang.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal set divisi tag error: $e');
      }
    }
  }

  /// Login user NIK ke OneSignal sebagai External ID
  Future<void> loginUser(
    String nik, {
    String? role,
    String? divisiKadiv,
  }) async {
    if (!_isSupportedPlatform) return;
    _lastLoginNik = nik.trim();
    _lastRole = role;
    _lastDivisi = divisiKadiv;
    try {
      await OneSignal.login(nik.trim());
      try {
        OneSignal.User.pushSubscription.optIn();
      } catch (_) {}
      if (kDebugMode) {
        print('OneSignal login berhasil. External ID = "${nik.trim()}"');
      }
      if (role != null) {
        await setUserRoleTag(role);
      }
      if (divisiKadiv != null && divisiKadiv.trim().isNotEmpty) {
        await setDivisiKadivTag(divisiKadiv);
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal login error: $e');
      }
    }
  }

  /// Logout user dari OneSignal
  Future<void> logoutUser() async {
    _lastLoginNik = null;
    _lastRole = null;
    _lastDivisi = null;
    if (!_isSupportedPlatform) return;
    try {
      try {
        await OneSignal.Notifications.clearAll();
      } catch (_) {}
      await OneSignal.logout();
    } catch (_) {}
  }

  /// Mengirimkan Push Notification Broadcast (ditangani server-side oleh backend Laravel).
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    _logServerDispatchedPush('Broadcast', title);
  }

  /// Mengirim Push Notification ke User Spesifik berdasarkan NIK / External ID (via backend Laravel).
  static Future<void> sendNotificationToUser({
    required String userNikOrId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final cleanId = userNikOrId.trim();
    if (cleanId.isEmpty) return;
    _logServerDispatchedPush('User: $cleanId', title);
  }

  /// Mengirim Push Notification ke Semua User dengan Role Tertentu (via backend Laravel).
  static Future<void> sendNotificationToRole({
    required String role,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final cleanRole = role.toLowerCase().trim();
    if (cleanRole.isEmpty) return;
    _logServerDispatchedPush('Role: $cleanRole', title);
  }

  /// Mengirim Push Notification khusus ke Kadiv pada Divisi tertentu (via backend Laravel).
  static Future<void> sendNotificationToKadivDivisi({
    required String divisi,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final cleanDivisi = divisi.toLowerCase().trim();
    if (cleanDivisi.isEmpty) return;
    _logServerDispatchedPush('Kadiv Divisi: $cleanDivisi', title);
  }

  static void _logServerDispatchedPush(String target, String title) {
    if (kDebugMode) {
      debugPrint(
        'OneSignal client REST push dinonaktifkan demi keamanan [$target]: "$title" (dikirim via server Laravel).',
      );
    }
  }
}

