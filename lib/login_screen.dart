import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/user_role.dart';
import 'screens/pegawai/pegawai_dashboard.dart';
import 'services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Warna biru tua yang sama dengan navbar dashboard.
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _navyLight = Color(0xFF123A85);

  /// Warna teks & permukaan.
  static const Color _textDark = Color(0xFF16233A);
  static const Color _textMuted = Color(0xFF6B7789);
  static const Color _fieldBg = Color(0xFFF6F8FC);
  static const Color _borderColor = Color(0xFFE3E8F0);

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
      final apiResult = await ApiService.login(nik, _passwordController.text);

      if (apiResult['success'] == true) {
        final userData = apiResult['data']['user'];
        final roleStr = userData['role'] ?? 'PEGAWAI';
        final userRole = UserRoleX.fromKode(roleStr);

        final user = AppUser(
          nik: userData['nik'] ?? nik,
          name: userData['nama'] ?? 'Pegawai',
          gelar: '',
          jabatan: userData['jabatan'] ?? 'Pegawai',
          unitKerja: 'Tirta Darma Ayu',
          unitKerjaSingkat: 'TDA',
          golongan: 'III/a',
          status: 'Pegawai Tetap',
          role: userRole,
        );

        // Simpan session user agar tidak perlu login ulang
        await ApiService.saveUserSession(user.toJson());

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => _dashboardForRole(user)),
        );
      } else {
        final demoAcc = findDemoAccount(nik, _passwordController.text);
        if (demoAcc != null) {
          final user = AppUser(
            nik: demoAcc.nik,
            name: demoAcc.name,
            gelar: '',
            jabatan: demoAcc.jabatan,
            unitKerja: demoAcc.unitKerja,
            unitKerjaSingkat: demoAcc.unitKerjaSingkat,
            golongan: demoAcc.golongan,
            status: 'Pegawai Tetap',
            role: demoAcc.role,
            divisiKadiv: demoAcc.divisiKadiv,
          );
          // Simpan session user
          await ApiService.saveUserSession(user.toJson());
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => _dashboardForRole(user)),
          );
          return;
        }

        final errorMsg = apiResult['message'] ?? 'NIK atau Kata Sandi salah';
        _showSnackBar(errorMsg, Colors.red);
        _refreshCaptcha();
      }
    } catch (e) {
      final demoAcc = findDemoAccount(nik, _passwordController.text);
      if (demoAcc != null) {
        final user = AppUser(
          nik: demoAcc.nik,
          name: demoAcc.name,
          gelar: '',
          jabatan: demoAcc.jabatan,
          unitKerja: demoAcc.unitKerja,
          unitKerjaSingkat: demoAcc.unitKerjaSingkat,
          golongan: demoAcc.golongan,
          status: 'Pegawai Tetap',
          role: demoAcc.role,
          divisiKadiv: demoAcc.divisiKadiv,
        );
        // Simpan session user
        await ApiService.saveUserSession(user.toJson());
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => _dashboardForRole(user)),
          );
        }
        return;
      }

      _showSnackBar('Terjadi kesalahan koneksi: $e', Colors.red);
      _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          // Background air (TIDAK diubah)
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_air.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ==== PONI BIRU: dari atas sampai hampir tengah, sudut bawah melengkung ====
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: size.height * (isVerySmallScreen ? 0.42 : 0.46),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _navy,
                    _navy.withValues(alpha: 0.94),
                    _navyLight.withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(46),
                  bottomRight: Radius.circular(46),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
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
                    horizontal: isSmallScreen ? 20 : 28,
                    vertical: isVerySmallScreen ? 12 : 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo -> Selamat Datang -> SIMPEG Mobile -> subjudul
                        _buildHeader(
                          isSmallScreen: isSmallScreen,
                          isVerySmallScreen: isVerySmallScreen,
                        ),
                        SizedBox(height: isVerySmallScreen ? 18 : 26),

                        // ==== KARTU PUTIH: hanya input NIK, Kata Sandi, Captcha ====
                        Container(
                          constraints: const BoxConstraints(maxWidth: 340),
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 18 : 22,
                            vertical: isSmallScreen ? 20 : 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: _navy.withValues(alpha: 0.18),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabeledField(
                                label: 'NIK',
                                controller: _nikController,
                                icon: Icons.badge_outlined,
                                hint: 'Masukkan NIK',
                                inputType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(20),
                                ],
                                isSmall: isSmallScreen,
                              ),
                              const SizedBox(height: 12),
                              _buildLabeledField(
                                label: 'Kata Sandi',
                                controller: _passwordController,
                                icon: Icons.lock_outline_rounded,
                                hint: 'Masukkan kata sandi',
                                obscure: _obscurePassword,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: _navy.withValues(alpha: 0.55),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setState(() =>
                                        _obscurePassword = !_obscurePassword);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  splashRadius: 18,
                                ),
                                isSmall: isSmallScreen,
                              ),
                              const SizedBox(height: 12),
                              _buildCaptchaRow(isSmallScreen),
                              const SizedBox(height: 10),
                              _buildLabeledField(
                                label: 'Kode Keamanan',
                                controller: _captchaController,
                                icon: Icons.verified_user_outlined,
                                hint: 'Masukkan 6 angka di atas',
                                inputType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                isSmall: isSmallScreen,
                              ),
                              const SizedBox(height: 20),
                              _buildLoginButton(isSmallScreen),
                              const SizedBox(height: 14),
                              const Text(
                                'Pendaftaran & lupa kata sandi melalui website resmi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 10.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: isVerySmallScreen ? 14 : 18),
                        Text(
                          '\u00A9 IT PERUMDAM Tirta Darma Ayu 2026',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _navy.withValues(alpha: 0.75),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
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

  /// Header tanpa kotak: logo, Selamat Datang, SIMPEG Mobile, lalu subjudul.
  Widget _buildHeader({
    required bool isSmallScreen,
    required bool isVerySmallScreen,
  }) {
    final double logoSize = isSmallScreen ? 74 : 84;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Logo
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_navy, _navyLight],
                    ),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 14 : 20),

        // 2. Selamat Datang
        Text(
          'Selamat Datang',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 24 : 27,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.2,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),

        // 3. SIMPEG Mobile + nama perusahaan (tanpa kotak)
        Text(
          'SIMPEG Mobile',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 17.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'PERUMDAM TIRTA DARMA AYU',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 10.5 : 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
            letterSpacing: 1.3,
            height: 1.3,
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 8 : 12),

        // 4. Subjudul
        Text(
          'Masuk dengan NIK dan Kata Sandi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 12.5 : 13,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.80),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaRow(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _captchaCode,
              style: TextStyle(
                color: _navy,
                fontSize: isSmallScreen ? 17 : 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                fontFamily: 'monospace',
              ),
            ),
          ),
          GestureDetector(
            onTap: _refreshCaptcha,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _navy.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: _navy,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(bool isSmallScreen) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 46 : 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_navy, _navyLight],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: _isLoading ? 0.10 : 0.30),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'MASUK',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: Colors.white,
                  ),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1.2),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                const SizedBox(width: 12),
                Icon(
                  icon,
                  color: _navy.withValues(alpha: 0.65),
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  cursorColor: _navy,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: isSmall ? 13.5 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                  keyboardType: inputType,
                  inputFormatters: inputFormatters,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixIcon: suffix,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 20,
                    ),
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFFA3AEBF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isSmall ? 11 : 12,
                      horizontal: icon != null ? 4 : 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ],
    );
  }
}