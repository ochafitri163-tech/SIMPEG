import 'package:flutter/material.dart';
import '../../login_screen.dart';
import '../../models/user_role.dart';
import 'absensi_screen.dart';
import 'golongan_screen.dart';
import 'keluarga_screen.dart';
import 'pendidikan_screen.dart';
import 'pengaturan_screen.dart';
import 'prestasi_sanksi_screen.dart';

/// Halaman "Profil" versi menu-list — dibuka saat avatar bulat & nama di
/// header dashboard (tombol "B") diketuk. Menampilkan kartu identitas
/// pegawai di atas, lalu daftar menu pintasan (Golongan, Absensi,
/// Pendidikan, Keluarga, Prestasi & Sanksi, Pengaturan), dan tombol
/// Keluar di paling bawah.
///
/// BEDA dengan [ProfileDetailScreen] (tampilan tab "Profil" di bottom
/// navigation bar dengan kartu Data Pribadi & Kepegawaian lengkap).
class ProfileScreen extends StatelessWidget {
  final AppUser user;
  const ProfileScreen({super.key, required this.user});

  static const Color navy = Color(0xFF0D2C6E);
  static const Color accent = Color(0xFF2E86AB);
  static const Color labelDark = Color(0xFF1B2733);
  static const Color hintGrey = Color(0xFF9AA5B1);
  static const Color danger = Color(0xFFE74C3C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIdentityCard(),
                  const SizedBox(height: 22),
                  const _SectionLabel('INFORMASI SAYA'),
                  const SizedBox(height: 10),
                  _MenuCard(
                    children: [
                      _MenuTile(
                        icon: Icons.workspace_premium_rounded,
                        iconColor: accent,
                        title: 'Golongan & Jenjang Karier',
                        subtitle: user.golongan,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const GolonganScreen()),
                        ),
                      ),
                      const _TileDivider(),
                      _MenuTile(
                        icon: Icons.fact_check_rounded,
                        iconColor: accent,
                        title: 'Riwayat Absensi',
                        subtitle: 'Rekap kehadiran bulanan',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const AbsensiScreen()),
                        ),
                      ),
                      const _TileDivider(),
                      _MenuTile(
                        icon: Icons.school_rounded,
                        iconColor: accent,
                        title: 'Riwayat Pendidikan',
                        subtitle: 'Jenjang & sertifikasi',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PendidikanScreen()),
                        ),
                      ),
                      const _TileDivider(),
                      _MenuTile(
                        icon: Icons.diversity_3_rounded,
                        iconColor: accent,
                        title: 'Data Keluarga',
                        subtitle: 'Pasangan & tanggungan',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const KeluargaScreen()),
                        ),
                      ),
                      const _TileDivider(),
                      _MenuTile(
                        icon: Icons.emoji_events_rounded,
                        iconColor: accent,
                        title: 'Prestasi & Sanksi',
                        subtitle: 'Riwayat penghargaan & sanksi disiplin',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PrestasiSanksiScreen()),
                        ),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('LAINNYA'),
                  const SizedBox(height: 10),
                  _MenuCard(
                    children: [
                      _MenuTile(
                        icon: Icons.settings_rounded,
                        iconColor: hintGrey,
                        title: 'Pengaturan',
                        subtitle: 'Notifikasi & preferensi aplikasi',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PengaturanScreen()),
                        ),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _buildLogoutButton(context),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'PERUMDAM Tirta Darma Ayu • v1.0.0',
                      style: TextStyle(fontSize: 11, color: hintGrey),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        64,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [navy, navy.withOpacity(0.85), const Color(0xFF123A85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
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
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_left_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Profil Saya',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF5B9BD5), Color(0xFF3873B8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.name}${user.gelar.isNotEmpty ? ', ${user.gelar}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: labelDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.jabatan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: hintGrey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'NIK ${user.nik}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout_rounded, size: 18, color: danger),
        label: const Text(
          'Keluar',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: danger),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: danger, width: 1.2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  /// Menampilkan dialog konfirmasi sebelum benar-benar keluar, supaya
  /// pengguna tidak tidak sengaja ter-logout saat salah ketuk.
  Future<void> _confirmLogout(BuildContext context) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Keluar Akun?',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: labelDark),
          ),
          content: const Text(
            'Kamu akan keluar dari akun ini dan perlu login ulang untuk mengakses aplikasi.',
            style: TextStyle(fontSize: 13, color: hintGrey, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal',
                  style: TextStyle(color: hintGrey, fontSize: 13.5)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya, Keluar', style: TextStyle(fontSize: 13.5)),
            ),
          ],
        );
      },
    );

    if (konfirmasi == true && context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: ProfileScreen.hintGrey,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(16),
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: ProfileScreen.labelDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ProfileScreen.hintGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFFC5CCD3)),
            ],
          ),
        ),
      ),
    );
  }
}