import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

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

  runApp(const SimpegApp());
}

// Shortcut biar gampang akses Supabase client dari mana aja
final supabase = Supabase.instance.client;

class SimpegApp extends StatelessWidget {
  const SimpegApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIMPEG Mobile Ver.3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF0D2C6E),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}