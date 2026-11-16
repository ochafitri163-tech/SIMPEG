import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/realtime_notification_service.dart';
import 'services/onesignal_service.dart';
import 'services/notification_nav_helper.dart';
import 'services/theme_controller.dart';
import 'models/pengumuman_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Sistem Notifikasi Lokal (Status Bar & Alarm Jam Terbit)
  await NotificationService.instance.init();

  // 2. Inisialisasi OneSignal Push Notification Cloud
  try {
    await OneSignalService.instance.init();
  } catch (e) {
    debugPrint('OneSignal init error: $e');
  }

  // 3. Inisialisasi Realtime Notification Service Lokal
  try {
    await RealtimeNotificationService.instance.init();
  } catch (e) {
    debugPrint('Realtime notification init error: $e');
  }

  await ThemeController.instance.loadSaved();

  // 4. Sinkronkan pengumuman terjadwal agar notifikasi lokal terpasang
  try {
    await PengumumanService.sinkronkanJadwalPengumuman();
  } catch (e) {
    debugPrint('Sinkronisasi jadwal pengumuman error: $e');
  }

  runApp(const SimpegApp());
}

class SimpegApp extends StatelessWidget {
  const SimpegApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'SIMPEG Mobile',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF0D2C6E),
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF2E86AB),
            scaffoldBackgroundColor: const Color(0xFF10151C),
            cardColor: const Color(0xFF1B2230),
            fontFamily: 'Roboto',
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E86AB),
              brightness: Brightness.dark,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
