import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_role.dart';
import 'screens/dirut/dashboard_dirut_screen.dart';
import 'screens/kadiv/dashboard_kadiv_screen.dart';
import 'screens/kspi/dashboard_kspi_screen.dart';
import 'screens/tpdpk/dashboard_tpdpk_screen.dart';
import 'screens/sdm/dashboard_sdm_screen.dart';
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
      final authResponse =
          await Supabase.instance.client.auth.signInWithPassword(
        email: _emailFromNik(nik),
        password: _passwordController.text,
      );

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw const AuthException('Login gagal, silakan coba lagi');
      }

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
      case UserRole.sdm:
        return DashboardSdmScreen(user: user);
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

  // ================== REDESIGNED UI (dengan background air) ==================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return Scaffold(
      body: Stack(
        children: [
          // Background air tetap dipertahankan
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_air.jpg',
              fit: BoxFit.cover,
            ),
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
                  const SizedBox(height: 30),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat Datang',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masuk dengan NIK dan Kata Sandi Anda',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildLabeledField(
                          label: 'NIK',
                          controller: _nikController,
                          icon: Icons.badge_outlined,
                          inputType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildLabeledField(
                          label: 'Kata Sandi',
                          controller: _passwordController,
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildCaptchaRow(),
                        const SizedBox(height: 12),
                        _buildLabeledField(
                          label: 'Kode Keamanan',
                          controller: _captchaController,
                          icon: Icons.shield_outlined,
                          hint: 'Masukkan 6 angka di atas',
                          inputType: TextInputType.number,
                        ),
                        const SizedBox(height: 28),
                        _buildLoginButton(),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Pendaftaran akun & lupa kata sandi dilakukan\nmelalui website resmi PERUMDAM Tirta Darma Ayu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '@copyright IT PERUMDAM Tirta Darma Ayu 2026',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11.5,
                    ),
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
          width: isSmallScreen ? 100 : 120,
          height: isSmallScreen ? 100 : 120,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A2E86AB),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: _accent,
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Simpeg Mobile Ver.3',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _navy,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PERUMDAM Tirta Darma Ayu',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E7EE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _captchaCode,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
                GestureDetector(
                  onTap: _refreshCaptcha,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: _accent,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBackgroundColor: _accent.withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'MASUK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E7EE)),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                const SizedBox(width: 14),
                Icon(icon, color: _accent.withOpacity(0.7), size: 20),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 15,
                  ),
                  keyboardType: inputType,
                  inputFormatters: inputFormatters,
                  decoration: InputDecoration(
                    suffixIcon: suffix,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: icon != null ? 10 : 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}