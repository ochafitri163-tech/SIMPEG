import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'notification_nav_helper.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  static const String appId = 'b7556b90-2f97-44f2-93e2-bd94abe8229e';

  /// REST API Key dari OneSignal Dashboard > Settings > Keys & IDs
  /// Ganti dengan REST API Key project OneSignal Anda.
  static const String _restApiKey = 'os_v2_app_w5kwxebps5cpfe7cxwkkx2bctyt34xy5qooehvv63djfl4za6mlx266vbxeborrxadrxpw2t67lhtljxszzsaphrkivaqqeqmrl5pxa';

  bool _initialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> init() async {
    if (!_isSupportedPlatform || _initialized) return;

    try {
      // 1. Set Level Log (hanya aktif saat debug)
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }

      // 2. Inisialisasi OneSignal dengan App ID
      OneSignal.initialize(appId);

      // 3. Minta izin notifikasi (Pop-up permission Android 13+ & iOS)
      await OneSignal.Notifications.requestPermission(true);

      // 4. Listener saat notifikasi diklik user (Navigasi ke fitur terkait)
      OneSignal.Notifications.addClickListener((event) {
        if (kDebugMode) {
          print('Notifikasi OneSignal Diklik: ${event.notification.title}');
        }
        final data = event.notification.additionalData;
        NotificationNavHelper.handleNotificationClick(data);
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
    if (!_isSupportedPlatform) return;
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
    if (!_isSupportedPlatform) return;
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
    if (!_isSupportedPlatform) return;
    try {
      await OneSignal.logout();
    } catch (_) {}
  }

  /// Mengirimkan Push Notification Broadcast ke SEMUA subscriber OneSignal.
  /// Ini menggantikan FcmService.sendBroadcastNotification() yang sudah dihapus.
  ///
  /// Menggunakan OneSignal REST API (Create Notification):
  /// https://documentation.onesignal.com/reference/create-notification
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');

      final payload = {
        'app_id': appId,
        'included_segments': ['All'],
        'headings': {'en': title},
        'contents': {'en': body},
        if (data != null) 'data': data,
      };

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('OneSignal broadcast sent: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending OneSignal broadcast: $e');
      }
    }
  }
}
