import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelAbsensi = AndroidNotificationDetails(
    'absensi_channel',
    'Pengingat Absensi',
    channelDescription: 'Pengingat jam masuk & pulang kerja',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _channelPengumuman = AndroidNotificationDetails(
    'pengumuman_channel',
    'Pengumuman Kantor',
    channelDescription: 'Info & pengumuman dari PDAM',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  Future<bool> requestPermission() async {
    bool granted = true;

    final AndroidFlutterLocalNotificationsPlugin? androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final result = await androidImpl.requestNotificationsPermission();
      granted = result ?? true;
    }

    final IOSFlutterLocalNotificationsPlugin? iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final result = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = result ?? true;
    }

    if (androidImpl == null && iosImpl == null) {
      final status = await Permission.notification.request();
      granted = status.isGranted;
    }

    return granted;
  }

  Future<void> enableAbsensiReminder() async {
    final granted = await requestPermission();
    if (!granted) return;

    await _scheduleDaily(
      id: 1,
      hour: 7,
      minute: 30,
      title: 'Waktunya Absen Masuk 🕖',
      body: 'Jangan lupa lakukan absensi masuk hari ini.',
      details: _channelAbsensi,
    );
    await _scheduleDaily(
      id: 2,
      hour: 16,
      minute: 30,
      title: 'Waktunya Absen Pulang 🕟',
      body: 'Jangan lupa lakukan absensi pulang sebelum meninggalkan kantor.',
      details: _channelAbsensi,
    );

    await _plugin.show(
      99,
      'Pengingat Absensi Diaktifkan ✅',
      'Kamu akan diingatkan absen masuk (07:30) & pulang (16:30) setiap hari kerja.',
      const NotificationDetails(android: _channelAbsensi),
    );
  }

  Future<void> disableAbsensiReminder() async {
    await _plugin.cancel(1);
    await _plugin.cancel(2);
  }

  Future<void> enablePengumumanNotif() async {
    final granted = await requestPermission();
    if (!granted) return;

    await _plugin.show(
      3,
      'Pengumuman Kantor Diaktifkan 📢',
      'Kamu akan menerima notifikasi setiap ada info/pengumuman baru dari PDAM.',
      const NotificationDetails(android: _channelPengumuman),
    );
  }

  Future<void> disablePengumumanNotif() async {
    await _plugin.cancel(3);
  }

  Future<void> showPengumuman({required String title, required String body}) {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: _channelPengumuman),
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details0 = NotificationDetails(android: details);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details0,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}