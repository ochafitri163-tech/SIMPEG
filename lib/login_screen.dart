import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_role.dart';
import 'screens/dirut/dashboard_dirut_screen.dart';
import 'screens/kadiv/dashboard_kadiv_screen.dart';
import 'screens/kspi/dashboard_kspi_screen.dart';
import 'screens/tpdpk/dashboard_tpdpk_screen.dart';
import 'screens/pegawai/pegawai_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _navy = Color(0xFF1B2733);

  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();

  bool _obscurePassword = true;
  late String _captchaCode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _captchaCode = _generateCaptcha();
  }

  String _generateCaptcha() {
    final rnd = Random();
    return List.generate(6, (_) => rnd.nextInt(10)).join();
  }

  void _refreshCaptcha() {
    setState(() {
      _captchaCode = _generateCaptcha();
      _captchaController.clear();
    });
  }

  /// Mengubah NIK menjadi email samaran, karena Supabase Auth
  /// mewajibkan format email untuk sign in.
  String _emailFromNik(String nik) => '$nik@gmail.com';

  Future<void> _login() async {
    if (_nikController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('NIK dan Kata Sandi wajib diisi', Colors.red);
      return;
    }
    if (_captchaController.text != _captchaCode) {
      _showSnackBar('Kode keamanan salah', Colors.red);
      _refreshCaptcha();
      return;
    }

    setState(() => _isLoading = true);

    final nik = _nikController.text.trim();

    try {
      // 1. Login ke Supabase Auth
      final authResponse =
          await Supabase.instance.client.auth.signInWithPassword(
        email: _emailFromNik(nik),
        password: _passwordController.text,
      );

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw const AuthException('Login gagal, silakan coba lagi');
      }

      // 2. Ambil data profil pegawai dari tabel 'pegawai'
      final data = await Supabase.instance.client
          .from('pegawai')
          .select()
          .eq('id', userId)
          .single();

      final user = AppUser(
        nik: data['nik'] as String,
        name: data['name'] as String,
        jabatan: data['jabatan'] as String,
        unitKerja: data['unit_kerja'] as String,
        unitKerjaSingkat: data['unit_kerja_singkat'] as String,
        golongan: data['golongan'] as String,
        golonganDetail: data['golongan_detail'] as String?,
        role: UserRole.values.byName(data['role'] as String),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _dashboardForRole(user)),
      );
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showSnackBar(_translateAuthError(e.message), Colors.red);
      _refreshCaptcha();
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan, silakan coba lagi', Colors.red);
      _refreshCaptcha();
    }
  }

  String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'NIK atau Kata Sandi salah';
    }
    return 'Login gagal: $message';
  }

  Widget _dashboardForRole(AppUser user) {
    switch (user.role) {
      case UserRole.pegawai:
        return PegawaiDashboard(user: user);
      case UserRole.kadivKategori:
        return DashboardKadivScreen(user: user);
      case UserRole.kspi:
        return DashboardKspiScreen(user: user);
      case UserRole.tpdpk:
        return DashboardTpdpkScreen(user: user);
      case UserRole.direktur:
        return DashboardDirutScreen(user: user);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/bg_air.jpg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 40,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(isSmallScreen),
                  const SizedBox(height: 26),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 20 : 26),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Login Untuk Melanjutkan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildLabeledField(
                          label: 'NIK',
                          controller: _nikController,
                          inputType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          label: 'Kata Sandi',
                          controller: _passwordController,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _refreshCaptcha,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F8),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE2E8ED)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _captchaCode,
                                  style: const TextStyle(
                                    color: _navy,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(Icons.refresh_rounded,
                                    color: Colors.grey[600], size: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          label: 'Kode Keamanan',
                          controller: _captchaController,
                          hint: 'Masukkan kode keamanan',
                          inputType: TextInputType.number,
                        ),
                        const SizedBox(height: 22),
                        _buildLoginButton(),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'Pendaftaran akun & lupa kata sandi dilakukan\nmelalui website resmi PERUMDAM Tirta Darma Ayu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '@copyright IT PERUMDAM Tirta Darma Ayu 2026',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Column(
      children: [
        Container(
          width: isSmallScreen ? 110 : 130,
          height: isSmallScreen ? 110 : 130,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4DB), _accent],
                  ),
                ),
                child: const Icon(Icons.water_drop_rounded,
                    color: Colors.white, size: 40),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Simpeg Mobile Ver.3',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _navy, fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          'PERUMDAM Tirta Darma Ayu',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: _accent.withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'MASUK',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    TextInputType? inputType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: _navy),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8ED)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: _navy, fontSize: 15),
            keyboardType: inputType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              suffixIcon: suffix,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}
