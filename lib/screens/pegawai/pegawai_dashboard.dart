import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pegawai_data.dart';
import '../../models/user_role.dart';
import '../../models/pengumuman_model.dart';
import '../../models/absensi_service.dart';
import '../../widgets/notification_bell.dart';
import '../dirut/dashboard_dirut_screen.dart';
import '../kadiv/dashboard_kadiv_screen.dart';
import '../kspi/dashboard_kspi_screen.dart';
import '../tpdpk/dashboard_tpdpk_screen.dart';
import '../sdm/dashboard_sdm_screen.dart';
import '../sdm/kelola_pengumuman_screen.dart';
import '../shared/pengumuman_list_screen.dart';
import '../../widgets/pengumuman_card.dart';
import 'tunjangan_pendidikan_screen.dart';
import 'insentif_screen.dart';
import 'lembur_screen.dart';
import 'pengaduan_pegawai_screen.dart';
import 'payroll_screen.dart';
import 'profile_detail_screen.dart';
import 'profile_screen.dart';
import 'status_pengaduan_screen.dart';
import 'thr_screen.dart';
import 'absensi_detail_screen.dart';
import '../../theme/app_colors.dart';


import '../../services/theme_controller.dart';
/// Ambil ringkasan kehadiran bulan berjalan milik pegawai yang sedang
/// login. Sumber utama adalah presensi harian nyata (tabel
/// `absensi_harian`); bila belum ada, jatuh ke agregat bulanan lama
/// (tabel `attendance`). Tidak lagi memakai data dummy dari API publik.
Future<AttendanceSummary> _fetchAttendanceBulanIni() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final now = DateTime.now();

  const bulanList = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final labelBulanIni = '${bulanList[now.month]} ${now.year}';

  if (userId == null) {
    return AttendanceSummary(
        bulanLabel: labelBulanIni, hadir: 0, telat: 0, izin: 0);
  }

  // Sumber utama: presensi harian nyata (absensi_harian).
  final harian = await AbsensiService.ringkasanBulan(
    tahun: now.year,
    bulan: now.month,
    bulanLabel: labelBulanIni,
  );
  if (harian.hadir + harian.telat + harian.izin > 0) {
    return harian;
  }

  // Fallback: agregat bulanan lama (attendance).
  final row = await Supabase.instance.client
      .from('attendance')
      .select()
      .eq('pegawai_id', userId)
      .eq('tahun', now.year)
      .eq('bulan', now.month)
      .maybeSingle();

  if (row == null) {
    return AttendanceSummary(
        bulanLabel: labelBulanIni, hadir: 0, telat: 0, izin: 0);
  }

  return AttendanceSummary(
    bulanLabel: (row['bulan_label'] ?? labelBulanIni) as String,
    hadir: (row['hadir'] ?? 0) as int,
    telat: (row['telat'] ?? 0) as int,
    izin: (row['izin'] ?? 0) as int,
  );
}

class PegawaiDashboard extends StatefulWidget {
  final AppUser user;
  const PegawaiDashboard({super.key, required this.user});

  @override
  State<PegawaiDashboard> createState() => _PegawaiDashboardState();
}

class _PegawaiDashboardState extends State<PegawaiDashboard> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  int _bottomNavIndex = 0;
  late Future<AttendanceSummary> _attendanceFuture;

  /// True kalau user login sebagai role approval (Kadiv, KSPI, TPDPK,
  /// Direktur, SDM) — bukan Pegawai biasa. Role-role ini tetap punya
  /// dashboard pegawai standar (Beranda/Status Pengaduan/Profil), hanya
  /// ditambah satu tab khusus di footer untuk fitur verifikasi/approval
  /// pengaduan sesuai role masing-masing.
  bool get _hasRoleFeature => widget.user.role != UserRole.pegawai;

  /// Dashboard khusus role approval yang ditampilkan di tab tambahan
  /// footer. Kalau role-nya Pegawai biasa, tab ini tidak pernah dipakai.
  Widget _buildRoleDashboardTab() {
    switch (widget.user.role) {
      case UserRole.kadivKategori:
        return DashboardKadivScreen(user: widget.user);
      case UserRole.kspi:
        return DashboardKspiScreen(user: widget.user);
      case UserRole.tpdpk:
        return DashboardTpdpkScreen(user: widget.user);
      case UserRole.direktur:
        return DashboardDirutScreen(user: widget.user);
      case UserRole.sdm:
        return DashboardSdmScreen(user: widget.user);
      case UserRole.pegawai:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _fetchAttendanceBulanIni();
    // Pop-up pengumuman otomatis SETIAP KALI aplikasi/dashboard dibuka
    // (hanya untuk 5 role penerima, bukan SDM). Tidak memakai penanda
    // "sudah dibaca" agar pop-up selalu muncul tiap buka aplikasi.
    if (widget.user.role != UserRole.sdm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tampilkanPopupPengumuman();
      });
    }
  }

  /// Menampilkan pop-up detail pengumuman teratas yang sedang tayang.
  /// Dipanggil sekali setiap dashboard dibuka.
  Future<void> _tampilkanPopupPengumuman() async {
    try {
      final list = await PengumumanService.tayangSekali(widget.user.role);
      if (!mounted || list.isEmpty) return;
      await showPengumumanPopup(context, list.first);
    } catch (_) {
      // Diamkan error jaringan; kartu tetap tampil di Beranda.
    }
  }

  void _onBottomNavTap(int index) {
    setState(() => _bottomNavIndex = index);
  }

  Future<void> _refresh() async {
    setState(() {
      _attendanceFuture = _fetchAttendanceBulanIni();
    });
    await _attendanceFuture;
  }

  void _openAbsensiDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AbsensiDetailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10151C) : const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _bottomNavIndex,
          children: [
            _buildBerandaTab(),
            // Tab tengah: role approval (Kadiv, KSPI, TPDPK, Direktur, SDM)
            // menampilkan dashboard tugasnya sendiri (verifikasi/approval
            // pengaduan) di sini, karena tugas itu sudah menggantikan
            // "Status Pengaduan" milik Pegawai biasa.
            _hasRoleFeature
                ? _buildRoleDashboardTab()
                : StatusPengaduanScreen(user: widget.user, showBackButton: false),
            ProfileDetailScreen(user: widget.user, showBackButton: false),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ==================== TAB: BERANDA ====================
  Widget _buildBerandaTab() {
    final firstName = widget.user.name.split(' ').first;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    const crossAxisCount = 3;

    final menuItems = <_QuickMenuItem>[
      _QuickMenuItem(
          label: 'Payroll',
          icon: Icons.description_rounded,
          builder: (_) => PayrollScreen(user: widget.user)),
      _QuickMenuItem(
          label: 'THR',
          icon: Icons.card_travel_rounded,
          builder: (_) => ThrScreen(user: widget.user)),
      _QuickMenuItem(
          label: 'Pengaduan',
          icon: Icons.chat_bubble_rounded,
          builder: (_) => _hasRoleFeature
              ? _buildRoleDashboardTab()
              : PengaduanPegawaiScreen(user: widget.user)),
      _QuickMenuItem(
          label: 'Lembur',
          icon: Icons.access_time_filled_rounded,
          builder: (_) => const LemburScreen()),
      _QuickMenuItem(
          label: 'Tunjangan\nPendidikan',
          icon: Icons.description_rounded,
          builder: (_) => const TunjanganPendidikanScreen()),
      _QuickMenuItem(
          label: 'Insentif\nPendidikan',
          icon: Icons.star_rounded,
          builder: (_) => InsentifScreen(user: widget.user)),
      if (widget.user.role == UserRole.sdm)
        _QuickMenuItem(
            label: 'Kelola\nPengumuman',
            icon: Icons.edit_notifications_rounded,
            builder: (_) => KelolaPengumumanScreen(user: widget.user)),
    ];

    return FutureBuilder<AttendanceSummary>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data ??
            const AttendanceSummary(
                bulanLabel: '...', hadir: 0, telat: 0, izin: 0);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(firstName, isSmallScreen),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildScheduleCard(isSmallScreen),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'RINGKASAN KEHADIRAN · ${summary.bulanLabel.toUpperCase()}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: _openAbsensiDetail,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _accent,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded,
                                size: 14, color: _accent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _buildAttendanceSection(summary, isSmallScreen),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildInfoBanner(summary, isSmallScreen),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: Text(
                  'MENU UTAMA',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menuItems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: isSmallScreen ? 10 : 16,
                    crossAxisSpacing: isSmallScreen ? 10 : 16,
                    childAspectRatio: isSmallScreen ? 0.78 : 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return _QuickMenuCircle(
                      item: item,
                      index: index,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: item.builder),
                        );
                      },
                      isSmallScreen: isSmallScreen,
                    );
                  },
                ),
              ),
              // ============== BERITA & PENGUMUMAN (paling bawah) ==============
              // Tampil untuk 5 role (bukan SDM). Kartu banner + tap = pop-up
              // detail. Hanya muncul bila ada pengumuman aktif; otomatis
              // ter-update via stream realtime Supabase.
              if (widget.user.role != UserRole.sdm)
                PengumumanCard(
                  role: widget.user.role,
                  onLihatSemua: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PengumumanListScreen(role: widget.user.role),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(String firstName, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + (isSmallScreen ? 8.0 : 16.0),
        20,
        isSmallScreen ? 40.0 : 56.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _navy,
            _navy.withValues(alpha: 0.85),
            const Color(0xFF123A85)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.water_drop_rounded,
                    size: 11, color: Colors.white70),
                const SizedBox(width: 5),
                Text(
                  'PERUMDAM TIRTA DARMA AYU',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 7 : 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(user: widget.user),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: isSmallScreen ? 40.0 : 48.0,
                            height: isSmallScreen ? 40.0 : 48.0,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.white.withValues(alpha: 0.1)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 2),
                            ),
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 16.0 : 20.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Hai, $firstName! 👋',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 15.0 : 18.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'NIK ${widget.user.nik}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: isSmallScreen ? 10.0 : 12.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance.themeMode,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: Colors.white,
                    ),
                    tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                    onPressed: () => ThemeController.instance.setDark(!isDark),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Muat ulang',
                onPressed: _refresh,
              ),
              const IconTheme(
                data: IconThemeData(color: Colors.white),
                child: NotificationBell(role: UserRole.pegawai),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(bool isSmallScreen) {
    final now = DateTime.now();
    const hariList = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const bulanList = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    final hari = hariList[now.weekday - 1];
    final tanggal =
        '$hari, ${now.day.toString().padLeft(2, '0')} ${bulanList[now.month]}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 14.0 : 18.0,
        vertical: isSmallScreen ? 12.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _accent.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accent.withValues(alpha: 0.15),
                  _accent.withValues(alpha: 0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: _accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tanggal,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.0 : 14.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tidak ada jadwal hari ini',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Libur',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(
      AttendanceSummary summary, bool isSmallScreen) {
    if (isSmallScreen) {
      return Column(
        children: [
          _buildStatChips(summary),
          const SizedBox(height: 12),
          _buildBars(summary),
        ],
      );
    } else {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _buildBars(summary),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: _buildStatChips(summary),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBars(AttendanceSummary summary) {
    final maxVal = [summary.hadir, summary.telat, summary.izin]
        .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar('Hadir', summary.hadir, maxVal, const Color(0xFF27AE60),
              Icons.check_circle_rounded),
          _buildBar('Telat', summary.telat, maxVal, const Color(0xFFF39C12),
              Icons.warning_rounded),
          _buildBar('Izin', summary.izin, maxVal, const Color(0xFFE74C3C),
              Icons.cancel_rounded),
        ],
      ),
    );
  }

  Widget _buildBar(
      String label, int value, int maxVal, Color color, IconData icon) {
    final height = maxVal == 0 ? 8.0 : 12.0 + (value / maxVal) * 70.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 32,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.7), color],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (value > 0)
              Positioned(
                top: 2,
                child: Icon(icon,
                    color: Colors.white.withValues(alpha: 0.9), size: 12),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChips(AttendanceSummary summary) {
    return Column(
      children: [
        _buildStatChip('Hadir', '${summary.hadir} Hari',
            const Color(0xFF27AE60), Icons.check_circle_rounded),
        const SizedBox(height: 8),
        _buildStatChip('Telat', '${summary.telat} Hari',
            const Color(0xFFF39C12), Icons.warning_rounded),
        const SizedBox(height: 8),
        _buildStatChip('Izin', '${summary.izin} Hari', const Color(0xFFE74C3C),
            Icons.cancel_rounded),
      ],
    );
  }

  Widget _buildStatChip(
      String label, String value, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(AttendanceSummary summary, bool isSmallScreen) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAbsensiDetail,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12.0 : 16.0,
            vertical: isSmallScreen ? 12.0 : 14.0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.isDark(context)
                  ? [const Color(0xFF16283A), const Color(0xFF15303C)]
                  : [const Color(0xFFE4F1FB), const Color(0xFFEAF5FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 1),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent, _navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hanya ${summary.telat} kali Telat dan ${summary.izin} kali Izin bulan ini',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11.0 : 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Kehadiranmu sudah baik, pertahankan terus! ✨',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child:
                    Icon(Icons.chevron_right_rounded, color: _accent, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BOTTOM NAVIGATION BAR ====================
  Widget _buildBottomNav(BuildContext context) {
    final items = [
      (icon: Icons.home_rounded, index: 0),
      (
        icon: _hasRoleFeature
            ? Icons.admin_panel_settings_rounded
            : Icons.fact_check_rounded,
        index: 1
      ),
      (icon: Icons.person_rounded, index: 2),
    ];

    return SizedBox(
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Bar putih flat di bawah
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: items
                    .map((it) => Expanded(
                          child: _buildNavItem(
                            icon: it.icon,
                            index: it.index,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    final isActive = _bottomNavIndex == index;

    return Center(
      child: InkWell(
        onTap: () => _onBottomNavTap(index),
        customBorder: const CircleBorder(),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          offset: isActive ? const Offset(0, -0.28) : Offset.zero,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: isActive ? 52 : 44,
            height: isActive ? 52 : 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive
                  ? const LinearGradient(
                      colors: [_accent, _navy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF9AA5B1),
              size: isActive ? 24 : 22,
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Helper Classes ============ //

class _QuickMenuItem {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  const _QuickMenuItem({
    required this.label,
    required this.icon,
    required this.builder,
  });
}

class _QuickMenuCircle extends StatefulWidget {
  final _QuickMenuItem item;
  final VoidCallback onTap;
  final bool isSmallScreen;
  final int index;
  const _QuickMenuCircle({
    required this.item,
    required this.onTap,
    this.isSmallScreen = false,
    this.index = 0,
  });

  @override
  State<_QuickMenuCircle> createState() => _QuickMenuCircleState();
}

class _QuickMenuCircleState extends State<_QuickMenuCircle>
    with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _navy = Color(0xFF0D2C6E);

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    // Animasi masuk bertahap (staggered) berdasarkan posisi ikon di grid,
    // sehingga menu muncul satu-persatu alih-alih sekaligus.
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.isSmallScreen ? 18.0 : 26.0;
    final fontSize = widget.isSmallScreen ? 9.0 : 11.0;
    final containerSize = widget.isSmallScreen ? 42.0 : 60.0;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.93 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.all(widget.isSmallScreen ? 8 : 12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: _pressed ? 0.03 : 0.06),
                    blurRadius: _pressed ? 8 : 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: AppColors.divider(context),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Container(
                      width: containerSize,
                      height: containerSize,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_accent, _navy],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(widget.item.icon,
                          color: Colors.white, size: iconSize),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}