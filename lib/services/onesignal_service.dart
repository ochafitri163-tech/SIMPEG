import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  static const String appId = 'b7556b90-2f97-44f2-93e2-bd94abe8229e';
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Set Level Log (hanya aktif saat debug)
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // 2. Inisialisasi OneSignal dengan App ID
      OneSignal.initialize(appId);

      // 3. Minta izin notifikasi (Pop-up permission Android 13+ & iOS)
      await OneSignal.Notifications.requestPermission(true);

      // 4. Listener saat notifikasi diklik user
      OneSignal.Notifications.addClickListener((event) {
        if (kDebugMode) {
          print('Notifikasi OneSignal Diklik: ${event.notification.title}');
        }
      });

      // 5. Listener saat notifikasi masuk di Foreground
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        if (kDebugMode) {
          print('Notifikasi OneSignal Masuk di Foreground: ${event.notification.title}');
        }
        // Biarkan notifikasi tetap tampil di status bar
        event.notification.display();
      });

      _initialized = true;
      if (kDebugMode) {
        print('OneSignal Berhasil Diinisialisasi.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal Init Error: $e');
      }
    }
  }

  /// Pasang Tag Role pengguna saat login agar bisa menerima notifikasi sesuai target role
  Future<void> setUserRoleTag(String role) async {
    try {
      await OneSignal.User.addTagWithKey('role', role.toLowerCase().trim());
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal set tag error: $e');
      }
    }
  }

  /// Login user NIK ke OneSignal
  Future<void> loginUser(String nik, {String? role}) async {
    try {
      await OneSignal.login(nik);
      if (role != null) {
        await setUserRoleTag(role);
      }
    } catch (e) {
      if (kDebugMode) {
        print('OneSignal login error: $e');
      }
    }
  }

  /// Logout user dari OneSignal
  Future<void> logoutUser() async {
    try {
      await OneSignal.logout();
    } catch (_) {}
  }
}
