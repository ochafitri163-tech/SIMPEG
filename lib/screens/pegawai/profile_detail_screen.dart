import 'package:flutter/material.dart';
import '../../models/user_role.dart';
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildHeader(context, isSmallScreen),
              Positioned(
                left: 20,
                right: 20,
                bottom: -46,
                child: _buildSummaryCard(isSmallScreen),
              ),
            ],
          ),
          const SizedBox(height: 62),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildTabs(context, isSmallScreen),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 24),
              ],
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
        isSmallScreen ? 48.0 : 56.0,
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
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: isSmallScreen ? 52.0 : 64.0,
                    height: isSmallScreen ? 52.0 : 64.0,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF5B9BD5), Color(0xFF3873B8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: user.fotoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              user.fotoUrl!,
                              width: isSmallScreen ? 52.0 : 64.0,
                              height: isSmallScreen ? 52.0 : 64.0,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            user.initials,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 18.0 : 22.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: isSmallScreen ? 12.0 : 14.0,
                      height: isSmallScreen ? 12.0 : 14.0,
                      decoration: BoxDecoration(
                        color: green,
                        shape: BoxShape.circle,
                        border: Border.all(color: navy, width: 2.5),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14.0 : 16.5,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.jabatan,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: isSmallScreen ? 11.0 : 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NIK ${user.nik}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 10.5 : 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 12.0 : 16.0,
        horizontal: isSmallScreen ? 4.0 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryColumn(
              label: 'GOLONGAN',
              isSmallScreen: isSmallScreen,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.golongan,
                  style: TextStyle(
                    color: accent,
                    fontSize: isSmallScreen ? 10.0 : 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 34, color: const Color(0xFFEDF1F5)),
          Expanded(
            child: _SummaryColumn(
              label: 'UNIT KERJA',
              isSmallScreen: isSmallScreen,
              child: Text(
                user.unitKerjaSingkat,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11.0 : 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1B2733),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 34, color: const Color(0xFFEDF1F5)),
          Expanded(
            child: _SummaryColumn(
              label: 'STATUS',
              isSmallScreen: isSmallScreen,
              child: Text(
                user.status,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11.0 : 12.5,
                  fontWeight: FontWeight.bold,
                  color: green,
                ),
              ),
            ),
          ),
        ],
      ),
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
            color: ProfileDetailScreen.labelGrey,
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
      color: selected ? ProfileDetailScreen.navy : Colors.white,
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
                selected ? null : Border.all(color: const Color(0xFFEDF1F5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11.0 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF7F8C8D),
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
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: ProfileDetailScreen.labelGrey,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5));
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
              color: ProfileDetailScreen.iconBg,
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
                    color: ProfileDetailScreen.labelGrey,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.0 : 13.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B2733),
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
