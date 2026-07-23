import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';
import 'screens/splash_screen.dart';
// Ganti dengan URL & anon key project Supabase kamu
// Ambil di: Supabase Dashboard > Settings > API
const String supabaseUrl = 'https://jyywrknlkqwmiqokmcju.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp5eXdya25sa3F3bWlxb2ttY2p1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwNzQ3NTEsImV4cCI6MjA5ODY1MDc1MX0.54_KntZXHuOpMj9IQUqUb9rl1a_B4zJQAplNCIbgc9c';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Notifikasi lokal (pengingat absensi & pengumuman kantor) & preferensi
  // mode gelap harus siap SEBELUM UI pertama kali dirender.
  await NotificationService.instance.init();
  await ThemeController.instance.loadSaved();

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
          title: 'SIMPEG Mobile Ver.3',
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