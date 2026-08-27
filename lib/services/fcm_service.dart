import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'notification_nav_helper.dart';

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
      NotificationNavHelper.openPengumuman();
    });

    // 3. Supabase Realtime Listener untuk Pengumuman Baru & Update
    try {
      Supabase.instance.client
          .channel('public:pengumuman')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'pengumuman',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              final eventType = payload.eventType;

              if (eventType == PostgresChangeEvent.delete) {
                final oldId = (oldRecord['id'] as num?)?.toInt();
                if (oldId != null) {
                  NotificationService.instance.cancelPengumuman(oldId);
                }
                return;
              }

              if (newRecord.isEmpty) return;

              final id = (newRecord['id'] as num?)?.toInt() ??
                  (DateTime.now().millisecondsSinceEpoch ~/ 1000);
              final aktif = newRecord['aktif'] as bool? ?? true;

              // Jika dinonaktifkan, batalkan notifikasi terjadwal
              if (!aktif) {
                NotificationService.instance.cancelPengumuman(id);
                return;
              }

              final judul = newRecord['judul'] as String? ?? 'Pengumuman Baru';
              final isi = newRecord['isi'] as String? ?? 'Ada pengumuman terbaru dari PDAM.';
              final title = '📢 Pengumuman Baru';
              final body = judul.isNotEmpty ? judul : isi;

              final terbitStr = newRecord['terbit_pada'] as String?;
              final kedaluwarsaStr = newRecord['kedaluwarsa_pada'] as String?;
              final now = DateTime.now().toUtc();

              DateTime? terbitPada = terbitStr != null
                  ? DateTime.tryParse(terbitStr)?.toUtc()
                  : null;
              DateTime? kedaluwarsaPada = kedaluwarsaStr != null
                  ? DateTime.tryParse(kedaluwarsaStr)?.toUtc()
                  : null;

              // Jika sudah kedaluwarsa, batalkan & abaikan
              if (kedaluwarsaPada != null && kedaluwarsaPada.isBefore(now)) {
                NotificationService.instance.cancelPengumuman(id);
                return;
              }

              // Jika dijadwalkan di masa depan, jadwalkan notifikasi lokal
              if (terbitPada != null && terbitPada.isAfter(now)) {
                if (kDebugMode) {
                  print('Pengumuman terjadwal diterima: $judul untuk $terbitPada');
                }
                NotificationService.instance.schedulePengumuman(
                  id: id,
                  title: title,
                  body: body,
                  scheduledDate: terbitPada.toLocal(),
                );
                return;
              }

              // Jika baru di-insert dan langsung tayang (tidak di masa depan)
              if (eventType == PostgresChangeEvent.insert) {
                if (kDebugMode) {
                  print('Supabase Realtime Insert Langsung Tayang: $judul');
                }
                NotificationService.instance.showPengumuman(
                  title: title,
                  body: body,
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) {
        print('Supabase Realtime subscription error: $e');
      }
    }

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

  /// Mengirimkan Notifikasi Push Broadcast saat Pengumuman baru dibuat
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
  }) async {
    try {
      // 1. Tampilkan notifikasi lokal di perangkat pengirim
      await NotificationService.instance.showPengumuman(
        title: title,
        body: body,
      );

      // 2. Kirim pesan HTTP ke FCM endpoint (Legacy & HTTP v1 bridge)
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      const serverKey = 'AIzaSyBelknoNku3tnAqPupRbWNK2UwVSyFuNNY'; // Web / API key

      final payload = {
        'to': '/topics/$topicPengumuman',
        'priority': 'high',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'data': {
          'title': title,
          'body': body,
          'type': 'pengumuman',
        },
      };

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sending FCM broadcast: $e');
      }
    }
  }
}
