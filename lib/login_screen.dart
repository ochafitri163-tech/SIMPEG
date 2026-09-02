import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/user_role.dart';
import 'screens/pegawai/pegawai_dashboard.dart';
import 'services/api_service.dart';
import 'services/remembered_account_service.dart';
import 'services/onesignal_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/dirut/dashboard_dirut_screen.dart';
import 'screens/kadiv/dashboard_kadiv_screen.dart';
import 'screens/kspi/dashboard_kspi_screen.dart';
import 'screens/sdm/dashboard_sdm_screen.dart';
import 'screens/tpdpk/dashboard_tpdpk_screen.dart';

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

  /// Status checkbox "Ingat saya".
  bool _ingatSaya = false;

  /// Akun yang pernah login di perangkat ini (kredensial terenkripsi).
  List<AkunTersimpan> _akunTersimpan = const [];

  /// NIK akun tersimpan yang sedang dipilih (untuk highlight kartu).
  String? _nikDipilih;

  @override
  void initState() {
    super.initState();
    _captchaCode = _generateCaptcha();
    _muatAkunTersimpan();
  }

  /// Ambil daftar akun tersimpan lalu isi otomatis akun terakhir dipakai.
  Future<void> _muatAkunTersimpan() async {
    final list = await RememberedAccountService.semua();
    if (!mounted) return;
    setState(() {
      _akunTersimpan = list;
      if (list.isNotEmpty) {
        _ingatSaya = true;
        _pakaiAkun(list.first, setStatePanggil: false);
      }
    });
  }

  /// Isi form dari akun tersimpan. User cukup isi captcha lalu tekan Login.
  void _pakaiAkun(AkunTersimpan akun, {bool setStatePanggil = true}) {
    _nikController.text = akun.nik;
    _passwordController.text = akun.password;
    _nikDipilih = akun.nik;
    _ingatSaya = true;
    if (setStatePanggil) setState(() {});
  }

  /// Hapus satu akun tersimpan dari perangkat (dengan konfirmasi).
  Future<void> _hapusAkun(AkunTersimpan akun) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus akun tersimpan?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text(
          'Kredensial ${akun.nama} (${akun.nik}) akan dihapus dari '
          'perangkat ini. Sesi login yang sedang berjalan tidak terpengaruh.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;

    await RememberedAccountService.hapus(akun.nik);
    final list = await RememberedAccountService.semua();
    if (!mounted) return;
    setState(() {
      _akunTersimpan = list;
      if (_nikDipilih == akun.nik) {
        _nikDipilih = null;
        _nikController.clear();
        _passwordController.clear();
        _ingatSaya = list.isNotEmpty;
      }
    });
    _showSnackBar('Akun tersimpan dihapus', _navy);
  }

  /// Simpan / lupakan kredensial lalu masuk ke dashboard.
  /// Dipanggil hanya setelah autentikasi BERHASIL.
  Future<void> _selesaikanLogin(AppUser user) async {
    if (_ingatSaya) {
      await RememberedAccountService.simpan(
        nik: user.nik,
        nama: user.name,
        password: _passwordController.text,
      );
      // Beri tahu OS/browser agar Password Manager menawarkan simpan.
      TextInput.finishAutofillContext();
    } else {
      await RememberedAccountService.lupakanJikaAda(user.nik);
      TextInput.finishAutofillContext(shouldSave: false);
    }

    // Registrasi User NIK & Role ke OneSignal untuk Target Push Notification
    await OneSignalService.instance.loginUser(user.nik, role: user.role.name);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _dashboardForRole(user)),
    );
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
    final sb = Supabase.instance.client;

    try {
      // 1. Cari email terdaftar berdasarkan NIK — jangan ditebak.
      //    Email bisa berubah, NIK tidak.
      String? emailLogin;
      try {
        final hasil = await sb.rpc('cari_email_by_nik', params: {'p_nik': nik});
        emailLogin = hasil as String?;
      } catch (_) {
        emailLogin = null;
      }

      // Cadangan: pola lama, untuk akun yang belum punya kolom email.
      emailLogin ??= '${nik.toLowerCase()}@tirtadarmaayu.local';

      if (emailLogin.isEmpty) {
        _showSnackBar('NIK tidak terdaftar. Hubungi SDM.', Colors.red);
        _refreshCaptcha();
        return;
      }

      // 2. Login ke Supabase Auth — WAJIB, karena 30+ layar memakai
      //    auth.currentUser?.id untuk mengambil data.
      final res = await sb.auth.signInWithPassword(
        email: emailLogin,
        password: _passwordController.text,
      );

      if (res.user == null) {
        _showSnackBar('NIK atau Kata Sandi salah', Colors.red);
        _refreshCaptcha();
        return;
      }

      // 3. Ambil profil ASLI dari tabel pegawai.
      final profil = await sb
          .from('pegawai')
          .select()
          .eq('id', res.user!.id)
          .maybeSingle();

      if (profil == null) {
        await sb.auth.signOut();
        _showSnackBar('Data pegawai tidak ditemukan. Hubungi SDM.', Colors.red);
        _refreshCaptcha();
        return;
      }

      // 4. Parse divisi kadiv
      final divisiStr = (profil['divisi_kadiv'] ?? '').toString();
      final divisi = divisiStr == 'administrasi'
          ? DivisiKadiv.administrasi
          : divisiStr == 'teknik'
              ? DivisiKadiv.teknik
              : null;

      final user = AppUser(
        nik: profil['nik']?.toString() ?? nik,
        name: profil['name']?.toString() ?? 'Pegawai',
        gelar: profil['gelar']?.toString() ?? '',
        jabatan: profil['jabatan']?.toString() ?? '-',
        unitKerja: profil['unit_kerja']?.toString() ?? '-',
        unitKerjaSingkat: profil['unit_kerja_singkat']?.toString() ?? '-',
        golongan: profil['golongan']?.toString() ?? '-',
        status: profil['status']?.toString() ?? 'Pegawai Tetap',
        role: UserRoleX.fromKode(profil['role']?.toString() ?? 'pegawai'),
        divisiKadiv: divisi,
      );

      await ApiService.saveUserSession(user.toJson());

      // 5. Password awal masih = NIK -> ingatkan untuk ganti.
      if (profil['must_change_password'] == true) {
        if (!mounted) return;
        _showSnackBar(
          'Silakan ganti kata sandi Anda terlebih dahulu',
          Colors.orange,
        );
      }

      if (!mounted) return;
      await _selesaikanLogin(user);
    } on AuthException catch (e) {
      _showSnackBar(
        e.message.toLowerCase().contains('invalid login')
            ? 'NIK atau Kata Sandi salah'
            : 'Gagal masuk: ${e.message}',
        Colors.red,
      );
      _refreshCaptcha();
    } catch (e) {
      _showSnackBar('Terjadi kesalahan koneksi: $e', Colors.red);
      _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _dashboardForRole(AppUser user) {
    switch (user.role) {
      case UserRole.direktur:
        return DashboardDirutScreen(user: user);
      case UserRole.kadivKategori:
        return DashboardKadivScreen(user: user);
      case UserRole.kspi:
        return DashboardKspiScreen(user: user);
      case UserRole.tpdpk:
        return DashboardTpdpkScreen(user: user);
      case UserRole.sdm:
        return DashboardSdmScreen(user: user);
      case UserRole.pegawai:
      case UserRole.keuangan:
        return PegawaiDashboard(user: user);
    }
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
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildLabeledField(
                                  label: 'NIK',
                                  controller: _nikController,
                                  icon: Icons.badge_outlined,
                                  hint: 'Masukkan NIK',
                                  inputType: TextInputType.number,
                                  autofillHints: const [
                                    AutofillHints.username,
                                  ],
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
                                  autofillHints: const [
                                    AutofillHints.password,
                                  ],
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
                                const SizedBox(height: 14),
                                _buildIngatSaya(isSmallScreen),
                                if (_akunTersimpan.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildDaftarAkunTersimpan(isSmallScreen),
                                ],
                                const SizedBox(height: 18),
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

  /// Checkbox "Ingat saya" + tombol hapus seluruh kredensial.
  Widget _buildIngatSaya(bool isSmall) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _ingatSaya,
            activeColor: _navy,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            onChanged: (v) => setState(() => _ingatSaya = v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _ingatSaya = !_ingatSaya),
            child: Text(
              'Ingat saya di perangkat ini',
              style: TextStyle(
                fontSize: isSmall ? 12 : 12.5,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ),
        ),
        if (_akunTersimpan.isNotEmpty)
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    await RememberedAccountService.hapusSemua();
                    if (!mounted) return;
                    setState(() {
                      _akunTersimpan = const [];
                      _nikDipilih = null;
                      _ingatSaya = false;
                      _nikController.clear();
                      _passwordController.clear();
                    });
                    _showSnackBar('Semua akun tersimpan dihapus', _navy);
                  },
            style: TextButton.styleFrom(
              foregroundColor: _textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Hapus semua',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  /// Daftar akun tersimpan. Ketuk kartu -> form terisi otomatis.
  Widget _buildDaftarAkunTersimpan(bool isSmall) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.switch_account_rounded,
                  size: 15, color: _navy.withValues(alpha: 0.65)),
              const SizedBox(width: 6),
              Text(
                'Akun tersimpan (${_akunTersimpan.length})',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._akunTersimpan.map((akun) {
            final terpilih = _nikDipilih == akun.nik;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _isLoading ? null : () => _pakaiAkun(akun),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        terpilih ? _navy.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: terpilih
                          ? _navy.withValues(alpha: 0.45)
                          : _borderColor,
                      width: terpilih ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _navyLight,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          akun.inisial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              akun.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isSmall ? 12 : 12.5,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'NIK ${akun.nik} \u00b7 \u2022\u2022\u2022\u2022\u2022\u2022',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (terpilih)
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: _navy),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 17, color: Color(0xFFE74C3C)),
                        tooltip: 'Hapus akun tersimpan',
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        splashRadius: 16,
                        onPressed: _isLoading ? null : () => _hapusAkun(akun),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Text(
            'Kredensial disimpan terenkripsi di perangkat ini saja, '
            'tidak dikirim ke server.',
            style: const TextStyle(
              fontSize: 9.8,
              color: _textMuted,
              height: 1.4,
            ),
          ),
        ],
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
    List<String>? autofillHints,
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
                  autofillHints: autofillHints,
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
