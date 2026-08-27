import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/onesignal_service.dart';
import 'services/notification_nav_helper.dart';
import 'services/theme_controller.dart';
import 'models/pengumuman_model.dart';

// Ganti dengan URL & anon key project Supabase kamu
// Ambil di: Supabase Dashboard > Settings > API
const String supabaseUrl = 'https://jyywrknlkqwmiqokmcju.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp5eXdya25sa3F3bWlxb2ttY2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNzQ3NTEsImV4cCI6MjA5ODY1MDc1MX0.54_KntZXHuOpMj9IQUqUb9rl1a_B4zJQAplNCIbgc9c';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Supabase Database
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 2. Inisialisasi Sistem Notifikasi Lokal (Status Bar & Alarm Jam Terbit)
  await NotificationService.instance.init();

  // 3. Inisialisasi OneSignal Push Notification Cloud
  await OneSignalService.instance.init();

  // 4. Inisialisasi Firebase
  try {
    await Firebase.initializeApp();
    await FcmService.instance.init();
  } catch (e) {
    debugPrint('Firebase init error: $e');
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

// Shortcut biar gampang akses Supabase client dari mana aja
final supabase = Supabase.instance.client;

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