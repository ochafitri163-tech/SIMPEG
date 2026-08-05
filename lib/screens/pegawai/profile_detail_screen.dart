import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_screen.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import 'golongan_screen.dart';
import 'keluarga_screen.dart';
import 'pendidikan_screen.dart';

class ProfileDetailScreen extends StatelessWidget {
  final AppUser user;
  final bool showBackButton;

  const ProfileDetailScreen({
    super.key,
    required this.user,
    this.showBackButton = true,
  });

  static const Color navy = Color(0xFF0D2C6E);
  static const Color navyDark = Color(0xFF0A2257);
  static const Color accent = Color(0xFF2E86AB);
  static const Color green = Color(0xFF27AE60);
  static const Color iconBg = Color(0xFFEAF2FB);
  static const Color labelGrey = Color(0xFF8B98A9);
  static const Color labelDark = Color(0xFF1B2733);
  static const Color danger = Color(0xFFE74C3C);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10151C) : const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(context, isSmallScreen),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(context, isSmallScreen),
                  const SizedBox(height: 22),
                  _buildTabs(context, isSmallScreen),
                  const SizedBox(height: 20),
                  const _SectionLabel('DATA PRIBADI'),
                  const SizedBox(height: 10),
                  _CardContainer(
                    child: Column(
                      children: [
                        _DataRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Tempat & Tgl. Lahir',
                          value: user.tempatTanggalLahir,
                          isSmallScreen: isSmallScreen,
                        ),
                        const _RowDivider(),
                        _DataRow(
                          icon: Icons.favorite_border_rounded,
                          label: 'Status Pernikahan',
                          value: user.statusPernikahan,
                          isSmallScreen: isSmallScreen,
                        ),
                        const _RowDivider(),
                        _DataRow(
                          icon: Icons.location_on_outlined,
                          label: 'Alamat Rumah',
                          value: user.alamat,
                          isSmallScreen: isSmallScreen,
                        ),
                        const _RowDivider(),
                        _DataRow(
                          icon: Icons.phone_outlined,
                          label: 'No. Telp / HP',
                          value: user.noTelp,
                          isLast: true,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('KEPEGAWAIAN'),
                  const SizedBox(height: 10),
                  _CardContainer(
                    child: Column(
                      children: [
                        _DataRow(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Jabatan',
                          value: user.jabatan,
                          isSmallScreen: isSmallScreen,
                        ),
                        const _RowDivider(),
                        _DataRow(
                          icon: Icons.work_outline_rounded,
                          label: 'Unit Kerja',
                          value: user.unitKerja,
                          isSmallScreen: isSmallScreen,
                        ),
                        const _RowDivider(),
                        _DataRow(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Golongan',
                          value: user.golongan,
                          isLast: true,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildLogoutButton(context, isSmallScreen),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + (isSmallScreen ? 8.0 : 12.0),
        20,
        isSmallScreen ? 44.0 : 50.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [navy, navy.withValues(alpha: 0.85), const Color(0xFF123A85)],
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
                      fontSize: isSmallScreen ? 7.0 : 9.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75),
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
              if (showBackButton)
                _CircleIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => Navigator.pop(context),
                  isSmallScreen: isSmallScreen,
                )
              else
                SizedBox(width: isSmallScreen ? 28.0 : 36.0),
              Expanded(
                child: Text(
                  'Profil Pegawai',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 28.0 : 36.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool isSmallScreen) {
    final avatarSize = isSmallScreen ? 68.0 : 78.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: avatarSize / 2),
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 14.0 : 18.0,
            avatarSize / 2 + (isSmallScreen ? 10.0 : 14.0),
            isSmallScreen ? 14.0 : 18.0,
            isSmallScreen ? 14.0 : 18.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            children: [
              Text(
                '${user.name}${user.gelar.isNotEmpty ? ', ${user.gelar}' : ''}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14.5 : 16.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                user.jabatan,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11.0 : 12.0,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NIK ${user.nik}',
                  style: TextStyle(
                    color: accent,
                    fontSize: isSmallScreen ? 10.0 : 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 14.0 : 18.0),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SummaryColumn(
                        label: 'GOLONGAN',
                        isSmallScreen: isSmallScreen,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6.0 : 8.0,
                              vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user.golongan,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent,
                              fontSize: isSmallScreen ? 9.5 : 11.0,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: AppColors.divider(context)),
                    Expanded(
                      child: _SummaryColumn(
                        label: 'UNIT KERJA',
                        isSmallScreen: isSmallScreen,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            user.unitKerjaSingkat,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.0 : 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: AppColors.divider(context)),
                    Expanded(
                      child: _SummaryColumn(
                        label: 'STATUS',
                        isSmallScreen: isSmallScreen,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            user.status,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.0 : 11.5,
                              fontWeight: FontWeight.bold,
                              color: green,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 16.0 : 20.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _QuickAction(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Golongan',
                    isSmallScreen: isSmallScreen,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const GolonganScreen()),
                    ),
                  ),
                  _QuickAction(
                    icon: Icons.school_rounded,
                    label: 'Pendidikan',
                    isSmallScreen: isSmallScreen,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PendidikanScreen()),
                    ),
                  ),
                  _QuickAction(
                    icon: Icons.diversity_3_rounded,
                    label: 'Keluarga',
                    isSmallScreen: isSmallScreen,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const KeluargaScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B9BD5), Color(0xFF3873B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: user.fotoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        user.fotoUrl!,
                        width: avatarSize - 6,
                        height: avatarSize - 6,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      user.initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 19.0 : 22.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: isSmallScreen ? 12.0 : 14.0,
                height: isSmallScreen ? 12.0 : 14.0,
                decoration: BoxDecoration(
                  color: green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context, bool isSmallScreen) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const _TabChip(label: 'Profile', selected: true, onTap: null),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Pendidikan',
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PendidikanScreen()),
            ),
            isSmallScreen: isSmallScreen,
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Keluarga',
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KeluargaScreen()),
            ),
            isSmallScreen: isSmallScreen,
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Golongan',
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GolonganScreen()),
            ),
            isSmallScreen: isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isSmallScreen) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 44.0 : 50.0,
      child: OutlinedButton.icon(
        onPressed: () => _confirmLogout(context),
        icon: Icon(Icons.logout_rounded,
            size: isSmallScreen ? 16.0 : 18.0, color: danger),
        label: Text(
          'Keluar',
          style: TextStyle(
              fontSize: isSmallScreen ? 13.0 : 14.0,
              fontWeight: FontWeight.w700,
              color: danger),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: danger, width: 1.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          backgroundColor: AppColors.card(context).withValues(alpha: 0.97),
          titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Keluar Akun?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          content: Text(
            'Kamu akan keluar dari akun ini dan perlu login ulang untuk mengakses aplikasi.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
              height: 1.5,
              letterSpacing: 0.1,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: danger.withValues(alpha: 0.3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Ya, Keluar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (konfirmasi == true && context.mounted) {
      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: isSmallScreen ? 28.0 : 36.0,
        height: isSmallScreen ? 28.0 : 36.0,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Icon(icon, color: Colors.white, size: isSmallScreen ? 18.0 : 22.0),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isSmallScreen;

  const _SummaryColumn({
    required this.label,
    required this.child,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 8.5 : 9.5,
            color: AppColors.textSecondary(context),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmallScreen ? 42.0 : 46.0,
            height: isSmallScreen ? 42.0 : 46.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon,
                size: isSmallScreen ? 18.0 : 20.0,
                color: ProfileDetailScreen.accent),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 9.5 : 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool isSmallScreen;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ProfileDetailScreen.navy : AppColors.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12.0 : 16.0,
            vertical: isSmallScreen ? 9.0 : 11.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                selected ? null : Border.all(color: AppColors.divider(context)),
            boxShadow: selected ? null : AppColors.cardShadow(context),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11.0 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary(context),
                ),
              ),
              if (!selected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 15, color: Color(0xFFAEB7C2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary(context),
        letterSpacing: 0.6,
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;

  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: child,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppColors.divider(context));
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  final bool isSmallScreen;

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 14, bottom: isLast ? 14 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSmallScreen ? 32.0 : 38.0,
            height: isSmallScreen ? 32.0 : 38.0,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted(context),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon,
                size: isSmallScreen ? 16.0 : 18.0,
                color: ProfileDetailScreen.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10.5 : 11.5,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.0 : 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}