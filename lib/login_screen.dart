import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/user_role.dart';
import 'screens/pegawai/pegawai_dashboard.dart';
import 'services/api_service.dart';
import 'services/remembered_account_service.dart';
import 'services/onesignal_service.dart';
import 'services/audit_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Konfigurasi batas percobaan login & waktu penguncian
  static const int _maxFailedAttempts = 5;
  static const int _lockoutMinutes = 5;
  static const String _keyFailedAttempts = 'login_failed_attempts';
  static const String _keyLockoutUntil = 'login_lockout_until';

  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();

  bool _obscurePassword = true;
  late String _captchaCode;
  bool _isLoading = false;

  /// Status batas percobaan gagal & penguncian (lockout)
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Duration _remainingLockout = Duration.zero;
  Timer? _lockoutTimer;

  bool get _isLockedOut =>
      _lockoutUntil != null && _remainingLockout.inSeconds > 0;

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
    _checkLockoutStatus();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _nikController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  /// Cek apakah akun sedang dalam masa penguncian (lockout 5 menit)
  Future<void> _checkLockoutStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutMs = prefs.getInt(_keyLockoutUntil) ?? 0;
      final attempts = prefs.getInt(_keyFailedAttempts) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (lockoutMs > nowMs) {
        final until = DateTime.fromMillisecondsSinceEpoch(lockoutMs);
        if (!mounted) return;
        setState(() {
          _failedAttempts = attempts;
          _lockoutUntil = until;
          _remainingLockout = Duration(milliseconds: lockoutMs - nowMs);
        });
        _startLockoutCountdown();
      } else if (lockoutMs > 0 && lockoutMs <= nowMs) {
        // Durasi 5 menit sudah habis saat aplikasi tertutup
        await prefs.remove(_keyLockoutUntil);
        await prefs.setInt(_keyFailedAttempts, 0);
        if (!mounted) return;
        setState(() {
          _failedAttempts = 0;
          _lockoutUntil = null;
          _remainingLockout = Duration.zero;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _failedAttempts = attempts;
        });
      }
    } catch (_) {}
  }

  /// Menjalankan hitung mundur per detik saat akun terkunci
  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_lockoutUntil == null) {
        timer.cancel();
        return;
      }
      final remaining = _lockoutUntil!.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        timer.cancel();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_keyLockoutUntil);
          await prefs.setInt(_keyFailedAttempts, 0);
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _failedAttempts = 0;
          _lockoutUntil = null;
          _remainingLockout = Duration.zero;
        });
        _showSnackBar(
          'Waktu kunci habis. Anda dapat mencoba login kembali.',
          const Color(0xFF27AE60),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _remainingLockout = remaining;
        });
      }
    });
  }

  /// Format durasi sisa waktu lockout (contoh: 04:59)
  String _formatLockoutTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Catat percobaan gagal. Bila mencapai 5x, kunci akun selama 5 menit.
  Future<void> _recordFailedAttempt({required String reason}) async {
    _refreshCaptcha();
    try {
      final prefs = await SharedPreferences.getInstance();
      final newAttempts = _failedAttempts + 1;

      if (newAttempts >= _maxFailedAttempts) {
        final lockoutEnd =
            DateTime.now().add(const Duration(minutes: _lockoutMinutes));
        await prefs.setInt(_keyFailedAttempts, newAttempts);
        await prefs.setInt(
            _keyLockoutUntil, lockoutEnd.millisecondsSinceEpoch);
        if (!mounted) return;
        setState(() {
          _failedAttempts = newAttempts;
          _lockoutUntil = lockoutEnd;
          _remainingLockout = const Duration(minutes: _lockoutMinutes);
        });
        _startLockoutCountdown();
        _showSnackBar(
          'Gagal masuk 5 kali! Akses login dikunci selama 5 menit demi keamanan.',
          Colors.red,
        );
      } else {
        await prefs.setInt(_keyFailedAttempts, newAttempts);
        if (!mounted) return;
        setState(() {
          _failedAttempts = newAttempts;
        });
        final sisa = _maxFailedAttempts - newAttempts;
        _showSnackBar(
          '$reason (Percobaan $newAttempts/$_maxFailedAttempts, sisa $sisa kesempatan)',
          Colors.red,
        );
      }
    } catch (_) {
      _showSnackBar(reason, Colors.red);
    }
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
    // Reset status failed attempts & lockout saat login berhasil
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFailedAttempts);
      await prefs.remove(_keyLockoutUntil);
    } catch (_) {}
    _lockoutTimer?.cancel();
    _failedAttempts = 0;
    _lockoutUntil = null;
    _remainingLockout = Duration.zero;

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

    // Simpan data NIK pengguna ke SharedPreferences agar semua request API sinkron
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_nik', user.nik);
    await prefs.setString('user_nama', user.name);
    await prefs.setString('user_jabatan', user.jabatan);

    // Registrasi User NIK, Role & Divisi ke OneSignal untuk Target Push Notification
    await OneSignalService.instance.loginUser(
      user.nik,
      role: user.role.name,
      divisiKadiv: user.divisiKadiv?.name,
    );

    // Catat log aktivitas login secara silent ke Supabase
    AuditLogService.logAction(
      userNik: user.nik,
      userName: user.name,
      role: user.role.label,
      action: 'LOGIN',
      module: 'Autentikasi',
      description: 'Pengguna berhasil login ke sistem',
    );

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
    // Cek apakah sistem sedang terkunci karena 5x percobaan gagal
    if (_isLockedOut) {
      _showSnackBar(
        'Akses login terkunci. Silakan tunggu ${_formatLockoutTime(_remainingLockout)} lagi.',
        Colors.red,
      );
      return;
    }

    if (_nikController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('NIK dan Kata Sandi wajib diisi', Colors.red);
      return;
    }
    if (_captchaController.text != _captchaCode) {
      await _recordFailedAttempt(reason: 'Kode keamanan salah');
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
        await _recordFailedAttempt(reason: 'NIK tidak terdaftar. Hubungi SDM.');
        return;
      }

      // 2. Login ke Supabase Auth — coba emailLogin atau @gmail.com
      AuthResponse? res;
      try {
        res = await sb.auth.signInWithPassword(
          email: emailLogin,
          password: _passwordController.text,
        );
      } catch (e) {
        if (emailLogin != '${nik.toLowerCase()}@gmail.com') {
          try {
            res = await sb.auth.signInWithPassword(
              email: '${nik.toLowerCase()}@gmail.com',
              password: _passwordController.text,
            );
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      if (res.user == null) {
        await _recordFailedAttempt(reason: 'NIK atau Kata Sandi salah');
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
        await _recordFailedAttempt(
            reason: 'Data pegawai tidak ditemukan. Hubungi SDM.');
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
        tempatTanggalLahir: (profil['tempat_tanggal_lahir'] ?? '').toString().isNotEmpty ? profil['tempat_tanggal_lahir'].toString() : '-',
        statusPernikahan: (profil['status_pernikahan'] ?? '').toString().isNotEmpty ? profil['status_pernikahan'].toString() : '-',
        alamat: (profil['alamat'] ?? '').toString().isNotEmpty ? profil['alamat'].toString() : '-',
        noTelp: (profil['no_telp'] ?? '').toString().isNotEmpty ? profil['no_telp'].toString() : '-',
        fotoUrl: profil['foto_url']?.toString(),
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
      final isWrongCreds = e.message.toLowerCase().contains('invalid login') ||
          e.message.toLowerCase().contains('invalid_credentials');
      final msg = isWrongCreds
          ? 'NIK atau Kata Sandi salah'
          : 'Gagal masuk: ${e.message}';
      await _recordFailedAttempt(reason: msg);
    } catch (e) {
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
    const bool isV2 = false;

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

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isVerySmallScreen ? 10 : 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo & Header ringkas
                          _buildHeader(
                            isSmallScreen: isSmallScreen,
                            isVerySmallScreen: isVerySmallScreen,
                            isV2: isV2,
                          ),
                          SizedBox(height: isVerySmallScreen ? 12 : 16),

                          // KARTU LOGIN RINGKAS (TIDAK MEMANJANG KE BAWAH)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 350),
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 18 : 22,
                              vertical: isSmallScreen ? 18 : 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _navy.withValues(alpha: 0.16),
                                  blurRadius: 26,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
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
                                    isV2: isV2,
                                  ),
                                  const SizedBox(height: 10),
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
                                    isV2: isV2,
                                  ),
                                  const SizedBox(height: 10),
                                  // Kode Keamanan + Captcha terintegrasi dalam 1 baris compact
                                  _buildCaptchaSection(isSmallScreen, isV2),
                                  const SizedBox(height: 10),
                                  _buildIngatSaya(isSmallScreen),
                                  if (_akunTersimpan.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildDaftarAkunTersimpan(isSmallScreen),
                                  ],
                                  if (_isLockedOut) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius:
                                            BorderRadius.circular(9),
                                        border: Border.all(
                                          color: const Color(0xFFFCA5A5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.lock_clock_rounded,
                                            color: Color(0xFFDC2626),
                                            size: 17,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Akun dikunci sementara (${_formatLockoutTime(_remainingLockout)})',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF991B1B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (_failedAttempts > 0) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                            color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Color(0xFFD97706),
                                            size: 15,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Gagal: $_failedAttempts/$_maxFailedAttempts (Sisa ${_maxFailedAttempts - _failedAttempts}x)',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: Color(0xFF92400E),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  _buildLoginButton(isSmallScreen, isV2),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Pendaftaran & lupa kata sandi melalui website resmi',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '\u00A9 IT PERUMDAM Tirta Darma Ayu 2026',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _navy.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
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



  /// Header tanpa kotak: logo ringkas, SIMPEG Mobile, lalu nama perusahaan.
  Widget _buildHeader({
    required bool isSmallScreen,
    required bool isVerySmallScreen,
    bool isV2 = false,
  }) {
    final double logoSize = isSmallScreen ? 48 : 54;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Logo
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: isV2
                ? Border.all(color: const Color(0xFF38BDF8), width: 2)
                : Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 5),
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
                    size: 26,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 2. SIMPEG Mobile
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SIMPEG Mobile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 17 : 19,
                fontWeight: FontWeight.w800,
                color: isV2 ? const Color(0xFF0F172A) : _navy,
                letterSpacing: 0.2,
              ),
            ),
            if (isV2) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'V2',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'PERUMDAM TIRTA DARMA AYU',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmallScreen ? 9.5 : 10.5,
            fontWeight: FontWeight.w700,
            color: isV2 ? const Color(0xFF64748B) : const Color(0xFF475569),
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  /// Kode Keamanan + Captcha terintegrasi dalam 1 baris hemat ruang
  Widget _buildCaptchaSection(bool isSmallScreen, [bool isV2 = false]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kode Keamanan',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: _textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Kotak kode captcha dengan tombol refresh
            Container(
              height: 40,
              padding: const EdgeInsets.only(left: 10, right: 4),
              decoration: BoxDecoration(
                color: isV2 ? const Color(0xFFF8FAFC) : _fieldBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isV2 ? const Color(0xFFCBD5E1) : _borderColor,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _captchaCode,
                    style: TextStyle(
                      color: isV2 ? const Color(0xFF0F172A) : _navy,
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _refreshCaptcha,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: isV2 ? const Color(0xFF0284C7) : _navy,
                      size: 16,
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                    splashRadius: 14,
                    tooltip: 'Acak kode',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Input 6 angka
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isV2 ? const Color(0xFFF8FAFC) : _fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isV2 ? const Color(0xFFCBD5E1) : _borderColor,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(
                      Icons.verified_user_outlined,
                      color: isV2
                          ? const Color(0xFF0284C7)
                          : _navy.withValues(alpha: 0.65),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _captchaController,
                        cursorColor: isV2 ? const Color(0xFF0284C7) : _navy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        style: TextStyle(
                          color: _textDark,
                          fontSize: isSmallScreen ? 13 : 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '6 angka',
                          hintStyle: TextStyle(
                            color: Color(0xFFA3AEBF),
                            fontSize: 11.5,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 9,
                            horizontal: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool isSmallScreen, [bool isV2 = false]) {
    final locked = _isLockedOut;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: locked
              ? const LinearGradient(
                  colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                )
              : isV2
                  ? const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                    )
                  : const LinearGradient(
                      colors: [_navy, _navyLight],
                    ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: locked
                  ? Colors.black.withValues(alpha: 0.12)
                  : _navy.withValues(alpha: _isLoading ? 0.08 : 0.24),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (_isLoading || locked) ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (locked) ...[
                      const Icon(Icons.lock_clock_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      locked
                          ? 'TERKUNCI (${_formatLockoutTime(_remainingLockout)})'
                          : isV2
                              ? 'MASUK KE SIMPEG V2'
                              : 'MASUK',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
          width: 20,
          height: 20,
          child: Checkbox(
            value: _ingatSaya,
            activeColor: _navy,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                fontSize: isSmall ? 11.5 : 12,
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Hapus semua',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  /// Daftar akun tersimpan ringkas. Ketuk kartu -> form terisi otomatis.
  Widget _buildDaftarAkunTersimpan(bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.switch_account_rounded,
                  size: 13, color: _navy.withValues(alpha: 0.70)),
              const SizedBox(width: 5),
              Text(
                'Akun tersimpan (${_akunTersimpan.length})',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._akunTersimpan.map((akun) {
            final terpilih = _nikDipilih == akun.nik;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _isLoading ? null : () => _pakaiAkun(akun),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: terpilih ? _navy.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: terpilih
                          ? _navy.withValues(alpha: 0.45)
                          : _borderColor,
                      width: terpilih ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: _navyLight,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          akun.inisial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              akun.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isSmall ? 11 : 11.5,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            Text(
                              'NIK ${akun.nik}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (terpilih)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.check_circle_rounded,
                              size: 14, color: _navy),
                        ),
                      InkWell(
                        onTap: _isLoading ? null : () => _hapusAkun(akun),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 15, color: Color(0xFFE74C3C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
    bool isV2 = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isV2 ? const Color(0xFF0F172A) : _textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: isV2 ? const Color(0xFFF8FAFC) : _fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isV2 ? const Color(0xFFCBD5E1) : _borderColor,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(
                  icon,
                  color: isV2
                      ? const Color(0xFF0284C7)
                      : _navy.withValues(alpha: 0.65),
                  size: 17,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  cursorColor: isV2 ? const Color(0xFF0284C7) : _navy,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: isSmall ? 13 : 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  keyboardType: inputType,
                  inputFormatters: inputFormatters,
                  autofillHints: autofillHints,
                  decoration: InputDecoration(
                    isDense: true,
                    suffixIcon: suffix,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 20,
                    ),
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFFA3AEBF),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: icon != null ? 2 : 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }
}
