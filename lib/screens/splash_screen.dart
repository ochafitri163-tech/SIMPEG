import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../models/user_role.dart';
import '../services/api_service.dart';
import '../screens/pegawai/pegawai_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  static const _animDuration = Duration(milliseconds: 900);
  static const _holdDuration = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _animDuration,
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _goToNextScreen();
  }

  Future<void> _goToNextScreen() async {
    await Future.delayed(_animDuration + _holdDuration);
    if (!mounted) return;

    // Cek apakah ada session user yang tersimpan
    final savedSession = await ApiService.getSavedUserSession();

    if (!mounted) return;

    Widget nextScreen;
    if (savedSession != null) {
      // Auto-login: langsung ke Dashboard tanpa perlu login ulang
      final user = AppUser.fromJson(savedSession);
      nextScreen = PegawaiDashboard(user: user);
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: SizedBox.expand(
            child: Image.asset(
              // Foto splash screen yang kamu lampirkan.
              'assets/images/splash_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}