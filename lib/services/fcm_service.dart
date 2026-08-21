import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  /// Topik FCM global untuk seluruh pengumuman SIMPEG
  static const String topicPengumuman = 'pengumuman';

  Future<void> init() async {
    if (_initialized) return;

    // Direct background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (kDebugMode) {
      print('User granted FCM permission: ${settings.authorizationStatus}');
    }

    // Auto-subscribe ke topik 'pengumuman' untuk SEMUA user
    try {
      await _fcm.subscribeToTopic(topicPengumuman);
      if (kDebugMode) {
        print('Berhasil subscribe ke FCM Topic: $topicPengumuman');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Gagal subscribe ke FCM Topic: $e');
      }
    }

    // 1. Handle Foreground Messages (Saat App Sedang Dilihat User)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Pesan FCM Diterima di Foreground: ${message.notification?.title}');
      }
      final notification = message.notification;
      if (notification != null) {
        NotificationService.instance.showPengumuman(
          title: notification.title ?? '📢 Pengumuman Baru',
          body: notification.body ?? 'Ada pengumuman terbaru dari PDAM.',
        );
      }
    });

    // 2. Handle saat Notifikasi diklik di System Tray
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Notifikasi FCM Diklik: ${message.notification?.title}');
      }
      // Tempat jika ingin menambahkan navigasi otomatis ke halaman pengumuman
    });

    _initialized = true;
  }

  /// Mendapatkan FCM Token milik device (berguna jika ingin notif per individu)
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      return null;
    }
  }
}
