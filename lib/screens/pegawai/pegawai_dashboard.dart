import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pegawai_data.dart';
import '../../models/user_role.dart';
import '../../widgets/notification_bell.dart';
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

/// Ambil ringkasan kehadiran bulan berjalan milik pegawai yang sedang
/// login dari tabel `attendance` di Supabase (sama seperti di
/// absensi_screen.dart). Kalau belum ada data, kembalikan ringkasan
/// kosong (0/0/0) supaya UI tetap tampil rapi tanpa error.
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

  @override
  void initState() {
    super.initState();
    _attendanceFuture = _fetchAttendanceBulanIni();
  }

  void _onBottomNavTap(int index) {
    setState(() => _bottomNavIndex = index);
  }

  void _openAbsensiDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AbsensiDetailScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _bottomNavIndex,
          children: [
            _buildBerandaTab(),
            const StatusPengaduanScreen(showBackButton: false),
            ProfileDetailScreen(user: widget.user, showBackButton: false),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ==================== TAB: BERANDA ====================
  Widget _buildBerandaTab() {
    final firstName = widget.user.name.split(' ').first;

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
          builder: (_) => PengaduanPegawaiScreen(user: widget.user)),
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
              _buildHeader(firstName),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildScheduleCard(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RINGKASAN KEHADIRAN · ${summary.bulanLabel.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF7F8C8D),
                      ),
                    ),
                    InkWell(
                      onTap: _openAbsensiDetail,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
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
                    : _buildAttendanceSection(summary),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildInfoBanner(summary),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: const Text(
                  'MENU UTAMA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menuItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return _QuickMenuCircle(
                      item: item,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: item.builder),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(String firstName) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        56,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _navy.withOpacity(0.85), const Color(0xFF123A85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.2),
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
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
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
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.75),
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
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.white.withOpacity(0.1)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2),
                            ),
                            child: Text(
                              firstName.isNotEmpty
                                  ? firstName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'NIK ${widget.user.nik}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: NotificationBell(role: UserRole.pegawai),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _accent.withOpacity(0.04),
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
                colors: [_accent.withOpacity(0.15), _accent.withOpacity(0.05)],
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tidak ada jadwal hari ini',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF95A5A6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
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

  Widget _buildAttendanceSection(AttendanceSummary summary) {
    final maxVal = [summary.hadir, summary.telat, summary.izin]
        .reduce((a, b) => a > b ? a : b);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBar('Hadir', summary.hadir, maxVal,
                      const Color(0xFF27AE60), Icons.check_circle_rounded),
                  _buildBar('Telat', summary.telat, maxVal,
                      const Color(0xFFF39C12), Icons.warning_rounded),
                  _buildBar('Izin', summary.izin, maxVal,
                      const Color(0xFFE74C3C), Icons.cancel_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _buildStatChip('Hadir', '${summary.hadir} Hari',
                    const Color(0xFF27AE60), Icons.check_circle_rounded),
                const SizedBox(height: 8),
                _buildStatChip('Telat', '${summary.telat} Hari',
                    const Color(0xFFF39C12), Icons.warning_rounded),
                const SizedBox(height: 8),
                _buildStatChip('Izin', '${summary.izin} Hari',
                    const Color(0xFFE74C3C), Icons.cancel_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(
      String label, int value, int maxVal, Color color, IconData icon) {
    final height = maxVal == 0 ? 8.0 : 12 + (value / maxVal) * 70;
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
                  colors: [color.withOpacity(0.7), color],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (value > 0)
              Positioned(
                top: 2,
                child:
                    Icon(icon, color: Colors.white.withOpacity(0.9), size: 12),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7F8C8D),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(
      String label, String value, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF95A5A6),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(AttendanceSummary summary) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAbsensiDetail,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFE4F1FB), const Color(0xFFEAF5FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.05),
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
                decoration: BoxDecoration(
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
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _navy,
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
                child: Icon(Icons.chevron_right_rounded,
                    color: _accent, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BOTTOM NAVIGATION BAR ====================
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _buildNavItem(Icons.home_rounded, 'Beranda', 0),
              _buildNavItem(Icons.fact_check_rounded, 'Pengaduan', 1),
              _buildNavItem(Icons.person_outline_rounded, 'Profil', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _bottomNavIndex == index;
    final color = isActive ? _accent : const Color(0xFF95A5A6);
    return Expanded(
      child: InkWell(
        onTap: () => _onBottomNavTap(index),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? _accent.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              if (isActive) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ],
            ],
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

class _QuickMenuCircle extends StatelessWidget {
  final _QuickMenuItem item;
  final VoidCallback onTap;
  const _QuickMenuCircle({required this.item, required this.onTap});

  static const Color _accent = Color(0xFF2E86AB);
  static const Color _navy = Color(0xFF0D2C6E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: _accent.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent, _navy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(item.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}