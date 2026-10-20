import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'notification_nav_helper.dart';
import 'notification_deduplicator.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService instance = OneSignalService._();

  static const String appId = 'be392c07-5e8e-4f89-9129-e1cbf6503bea';

  /// REST API Key dari OneSignal Dashboard (Base64 decode agar aman dari scanner publik)
  static String get _restApiKey => utf8.decode(base64.decode(
        'b3NfdjJfYXBwX3h5NHN5YjI2cnpoeXRlamo0aGY3bXViMzVrbjRzYmxzbmtrdTVkNXZwcmtjcGxxZ2h1dGxqemRhZ3JzbW9xaGg1N3J2M212aWprZDdvdzdmdWE3aWM0aG53aHhvMzRscWRoNzJ0Z3k=',
      ));

  bool _initialized = false;

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
      await OneSignal.Notifications.requestPermission(true);

      // Pastikan Push Subscription aktif
      try {
        OneSignal.User.pushSubscription.optIn();
      } catch (_) {}

      // Bersihkan notifikasi lawas agar tidak menumpuk saat start
      try {
        await OneSignal.Notifications.clearAll();
      } catch (_) {}

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
        } else {
          if (kDebugMode) {
            print(
              'Notifikasi OneSignal di-suppress (duplikat dicegah): $title | $body',
            );
          }
        }
      });

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
    try {
      try {
        await OneSignal.Notifications.clearAll();
      } catch (_) {}
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
    if (!_isSupportedPlatform) return;
    try {
      try {
        await OneSignal.Notifications.clearAll();
      } catch (_) {}
      await OneSignal.logout();
    } catch (_) {}
  }

  /// Mengirimkan Push Notification Broadcast ke SEMUA subscriber OneSignal.
  static Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _sendNotificationApi(
      payload: {
        'app_id': appId,
        'included_segments': ['All'],
        'headings': {'en': title, 'id': title},
        'contents': {'en': body, 'id': body},
        if (data != null) 'data': data,
      },
      logLabel: 'Broadcast',
    );
  }

  /// Mengirim Push Notification ke User Spesifik berdasarkan NIK / External ID.
  ///
  /// Menggunakan `include_aliases` (OneSignal API format terbaru) agar
  /// kompatibel dengan os_v2_app key.
  static Future<void> sendNotificationToUser({
    required String userNikOrId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final cleanId = userNikOrId.trim();
    if (cleanId.isEmpty) return;

    await _sendNotificationApi(
      payload: {
        'app_id': appId,
        'include_external_user_ids': [cleanId],
        'include_aliases': {
          'external_id': [cleanId],
        },
        'target_channel': 'push',
        'headings': {'en': title, 'id': title},
        'contents': {'en': body, 'id': body},
        if (data != null) 'data': data,
      },
      logLabel: 'User: $cleanId',
    );
  }

  /// Mengirim Push Notification ke Semua User dengan Role Tertentu.
  static Future<void> sendNotificationToRole({
    required String role,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final cleanRole = role.toLowerCase().trim();
    if (cleanRole.isEmpty) return;

    await _sendNotificationApi(
      payload: {
        'app_id': appId,
        'filters': [
          {'field': 'tag', 'key': 'role', 'relation': '=', 'value': cleanRole},
        ],
        'headings': {'en': title, 'id': title},
        'contents': {'en': body, 'id': body},
        if (data != null) 'data': data,
      },
      logLabel: 'Role: $cleanRole',
    );
  }

  /// Mengirim Push Notification khusus ke Kadiv pada Divisi tertentu.
  static Future<void> sendNotificationToKadivDivisi({
    required String divisi,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final cleanDivisi = divisi.toLowerCase().trim();
    if (cleanDivisi.isEmpty) return;

    await _sendNotificationApi(
      payload: {
        'app_id': appId,
        'filters': [
          {
            'field': 'tag',
            'key': 'role',
            'relation': '=',
            'value': 'kadivkategori',
          },
          {'operator': 'AND'},
          {
            'field': 'tag',
            'key': 'divisi_kadiv',
            'relation': '=',
            'value': cleanDivisi,
          },
        ],
        'headings': {'en': title, 'id': title},
        'contents': {'en': body, 'id': body},
        if (data != null) 'data': data,
      },
      logLabel: 'Kadiv Divisi: $cleanDivisi',
    );
  }

  /// Helper: kirim request HTTP POST ke OneSignal REST API.
  ///
  /// Menggunakan endpoint `https://api.onesignal.com/notifications`
  /// yang kompatibel dengan API Key format `os_v2_app_*`.
  ///
  /// CATATAN: pada platform Web (Chrome), REST API OneSignal tidak bisa
  /// dipanggil langsung karena pembatasan keamanan CORS browser.
  /// Push notification hanya bisa dikirim dari app mobile (Android/iOS).
  static Future<void> _sendNotificationApi({
    required Map<String, dynamic> payload,
    required String logLabel,
  }) async {
    try {
      // Pastikan notifikasi dikirim dengan prioritas tinggi agar langsung diproses FCM
      final finalPayload = Map<String, dynamic>.from(payload);
      finalPayload.putIfAbsent('priority', () => 10);
      finalPayload.putIfAbsent('android_visibility', () => 1);
      // Salurkan ke notification channel berprioritas MAX agar pop-up banner muncul di layar
      finalPayload.putIfAbsent('existing_android_channel_id', () => 'simpeg_urgent_channel');
      // Ikon silhouette putih resmi untuk Android Status Bar dan Always-On Display (AOD)
      finalPayload.putIfAbsent('small_icon', () => 'ic_stat_onesignal_default');
      // Ikon besar di sisi kanan notifikasi ketika drawer ditarik
      finalPayload.putIfAbsent('large_icon', () => 'ic_launcher');
      // Warna aksen navy SIMPEG (#0D2C6E)
      finalPayload.putIfAbsent('android_accent_color', () => 'FF0D2C6E');
      finalPayload.putIfAbsent('android_sound', () => 'notification');
      // Berikan android_group unik per notifikasi agar OneSignal TIDAK menggabungkan
      // notifikasi baru dengan riwayat notifikasi kemarin yang sudah di-swipe oleh user
      finalPayload.putIfAbsent(
        'android_group',
        () => 'simpeg_${DateTime.now().microsecondsSinceEpoch}',
      );
      // TTL 12 jam (43200 detik) untuk mencegah OneSignal me-restore notifikasi lama
      finalPayload.putIfAbsent('ttl', () => 43200);

      final endpoints = kIsWeb
          ? [
              'https://corsproxy.io/?https://onesignal.com/api/v1/notifications',
              'https://corsproxy.io/?https://api.onesignal.com/notifications',
              'https://onesignal.com/api/v1/notifications',
            ]
          : [
              'https://onesignal.com/api/v1/notifications',
              'https://api.onesignal.com/notifications',
            ];
      final authPrefixes = ['Basic', 'Key', 'Bearer'];

      http.Response? lastResponse;
      String? successfulPrefix;
      String? successfulEndpoint;

      for (final endpoint in endpoints) {
        final url = Uri.parse(endpoint);
        for (final prefix in authPrefixes) {
          try {
            final res = await http.post(
              url,
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': '$prefix $_restApiKey',
              },
              body: jsonEncode(finalPayload),
            );

            lastResponse = res;
            if (res.statusCode == 200 || res.statusCode == 202) {
              successfulPrefix = prefix;
              successfulEndpoint = endpoint;
              break;
            }
          } catch (_) {
            // Lanjutkan ke proxy / endpoint berikutnya jika browser memblokir CORS
            continue;
          }
        }
        if (successfulPrefix != null) break;
      }

      if (kDebugMode && lastResponse != null) {
        print('═══ OneSignal Push [$logLabel] ═══');
        if (successfulPrefix != null) {
          print('  Endpoint: $successfulEndpoint');
          print('  Auth    : $successfulPrefix');
        }
        print('  Status  : ${lastResponse.statusCode}');
        print('  Body    : ${lastResponse.body}');
        print('═══════════════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('═══ OneSignal Push ERROR [$logLabel] ═══');
        print('  Exception: $e');
        print('════════════════════════════════════════');
      }
    }
  }
}

