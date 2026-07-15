import 'package:flutter/material.dart';
import '../models/user_role.dart';
import 'golongan_screen.dart';
import 'keluarga_screen.dart';
import 'pendidikan_screen.dart';

/// Halaman Profil Pegawai (versi detail) — mengikuti referensi desain UI
/// "Profile.png" secara persis: header navy dengan avatar & indikator
/// online, kartu ringkasan mengambang (Golongan / Unit Kerja / Status),
/// tab segmented (Profile / Pendidikan / Keluarga / Golongan), lalu kartu
/// "Data Pribadi" dan "Kepegawaian", diakhiri tombol "Ubah Profil".
///
/// Dipakai khusus untuk tombol "Profil" di bottom navigation bar & menu
/// grid "Profile" di dashboard — BEDA dengan [ProfileScreen] (menu list
/// Keluarga/Pendidikan/Absensi/dll) yang dipakai saat avatar & nama di
/// header dashboard diklik.
class ProfileDetailScreen extends StatelessWidget {
  final AppUser user;

  /// Saat dipakai sebagai konten tab Bottom Navigation Bar (embedded via
  /// IndexedStack), tombol back disembunyikan karena tidak ada halaman
  /// untuk di-pop -- perpindahan cukup lewat Bottom Navigation Bar itu
  /// sendiri. Saat dipakai lewat Navigator.push biasa, tetap true.
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildHeader(context),
              Positioned(
                left: 20,
                right: 20,
                bottom: -46,
                child: _buildSummaryCard(),
              ),
            ],
          ),
          const SizedBox(height: 62),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildTabs(context),
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
                      ),
                      const _RowDivider(),
                      _DataRow(
                        icon: Icons.favorite_border_rounded,
                        label: 'Status Pernikahan',
                        value: user.statusPernikahan,
                      ),
                      const _RowDivider(),
                      _DataRow(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat Rumah',
                        value: user.alamat,
                      ),
                      const _RowDivider(),
                      _DataRow(
                        icon: Icons.phone_outlined,
                        label: 'No. Telp / HP',
                        value: user.noTelp,
                        isLast: true,
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
                      ),
                      const _RowDivider(),
                      _DataRow(
                        icon: Icons.work_outline_rounded,
                        label: 'Unit Kerja',
                        value: user.unitKerja,
                      ),
                      const _RowDivider(),
                      _DataRow(
                        icon: Icons.wb_sunny_outlined,
                        label: 'Golongan',
                        value: user.golongan,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _buildUbahProfilButton(context),
                const SizedBox(height: 24),
              ],
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
        56,
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
              if (showBackButton)
                _CircleIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => Navigator.pop(context),
                )
              else
                const SizedBox(width: 36),
              const Expanded(
                child: Text(
                  'Profil Pegawai',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 36),
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
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
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.jabatan,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NIK ${user.nik}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
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
          Expanded(
            child: _SummaryColumn(
              label: 'GOLONGAN',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  user.golongan,
                  style: const TextStyle(
                    color: accent,
                    fontSize: 11.5,
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
              child: Text(
                user.unitKerjaSingkat,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2733),
                ),
              ),
            ),
          ),
          Container(width: 1, height: 34, color: const Color(0xFFEDF1F5)),
          Expanded(
            child: _SummaryColumn(
              label: 'STATUS',
              child: Text(
                user.status,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
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

  Widget _buildTabs(BuildContext context) {
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
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Keluarga',
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KeluargaScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Golongan',
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GolonganScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUbahProfilButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Perubahan data profil dilakukan melalui HRD atau website resmi PERUMDAM.'),
              backgroundColor: accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        },
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text(
          'Ubah Profil',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final Widget child;

  const _SummaryColumn({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
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

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                selected ? null : Border.all(color: const Color(0xFFEDF1F5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF7F8C8D),
                ),
              ),
              // Ikon panah kecil menandakan chip ini akan membuka halaman
              // lain (bukan sekadar berganti tab di tempat) — memperjelas
              // ekspektasi pengguna sebelum tap.
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
            color: Colors.black.withOpacity(0.05),
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

  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 14, bottom: isLast ? 14 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ProfileDetailScreen.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: ProfileDetailScreen.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: ProfileDetailScreen.labelGrey,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B2733),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}