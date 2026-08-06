import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_role.dart';
import 'screens/pegawai/pegawai_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _navy = Color(0xFF1B2733);
  static const Color _lightBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE2E8F0);

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
        gelar: (data['gelar'] as String?) ?? '',
        jabatan: data['jabatan'] as String,
        unitKerja: data['unit_kerja'] as String,
        unitKerjaSingkat: data['unit_kerja_singkat'] as String,
        golongan: data['golongan'] as String,
        golonganDetail: data['golongan_detail'] as String?,
        status: (data['status'] as String?) ?? 'Pegawai Tetap',
        tempatTanggalLahir: (data['tempat_tanggal_lahir'] as String?) ?? '-',
        statusPernikahan: (data['status_pernikahan'] as String?) ?? '-',
        alamat: (data['alamat'] as String?) ?? '-',
        noTelp: (data['no_telp'] as String?) ?? '-',
        fotoUrl: data['foto_url'] as String?,
        role: UserRole.values.byName(data['role'] as String),
        divisiKadiv: data['divisi_kadiv'] != null
            ? DivisiKadiv.values.byName(data['divisi_kadiv'] as String)
            : null,
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
    return PegawaiDashboard(user: user);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;
    final isVerySmallScreen = size.height < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient overlay for better readability
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_air.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.10),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 32,
                    vertical: isVerySmallScreen ? 12 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(
                          isSmallScreen: isSmallScreen,
                          isVerySmallScreen: isVerySmallScreen,
                        ),
                        SizedBox(height: isVerySmallScreen ? 16 : 28),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          width: double.infinity,
                          padding: EdgeInsets.all(
                            isSmallScreen ? 20 : 28,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 40,
                                offset: const Offset(0, 12),
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Selamat Datang',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: _navy,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Masuk dengan NIK dan Kata Sandi',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.security_rounded,
                                      color: _accent,
                                      size: 24,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildLabeledField(
                                label: 'NIK',
                                controller: _nikController,
                                icon: Icons.badge_outlined,
                                inputType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(20),
                                ],
                                isSmall: isSmallScreen,
                              ),
                              const SizedBox(height: 16),
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
                                    setState(() =>
                                        _obscurePassword = !_obscurePassword);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                isSmall: isSmallScreen,
                              ),
                              const SizedBox(height: 16),
                              _buildCaptchaRow(isSmallScreen),
                              const SizedBox(height: 12),
                              _buildLabeledField(
                                label: 'Kode Keamanan',
                                controller: _captchaController,
                                icon: Icons.shield_outlined,
                                hint: 'Masukkan 6 angka di atas',
                                inputType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                isSmall: isSmallScreen,
                              ),
                              const SizedBox(height: 24),
                              _buildLoginButton(isSmallScreen),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  'Pendaftaran & lupa kata sandi melalui website resmi',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                    height: 1.4,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '© IT PERUMDAM Tirta Darma Ayu 2026',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required bool isSmallScreen,
    required bool isVerySmallScreen,
  }) {
    final double logoSize = isSmallScreen ? 80 : 100;
    final double titleSize = isSmallScreen ? 18 : 22;

    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E86AB).withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_accent, _accent.withOpacity(0.7)],
                    ),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 8 : 14),
        Text(
          'SIMPEG Mobile',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'PERUMDAM Tirta Darma Ayu',
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaRow(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _lightBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderColor, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _captchaCode,
                  style: TextStyle(
                    color: _navy,
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                  ),
                ),
                GestureDetector(
                  onTap: _refreshCaptcha,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _accent.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: _accent,
                      size: 20,
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

  Widget _buildLoginButton(bool isSmallScreen) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 48 : 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: _accent.withOpacity(0.4),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'MASUK',
                style: TextStyle(
                  fontSize: 15,
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
    required bool isSmall,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _navy,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _lightBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                const SizedBox(width: 12),
                Icon(
                  icon,
                  color: _accent.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  style: TextStyle(
                    color: _navy,
                    fontSize: isSmall ? 14 : 15,
                    fontWeight: FontWeight.w400,
                  ),
                  keyboardType: inputType,
                  inputFormatters: inputFormatters,
                  decoration: InputDecoration(
                    suffixIcon: suffix,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: isSmall ? 13 : 14,
                      fontWeight: FontWeight.w300,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isSmall ? 12 : 14,
                      horizontal: icon != null ? 8 : 14,
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
