import 'package:flutter/material.dart';
import '../widgets/feature_scaffold.dart';

/// Halaman Pengaturan — preferensi aplikasi (notifikasi, tampilan, bahasa)
/// dan info aplikasi. Sebagian pengaturan masih dummy (belum tersambung ke
/// penyimpanan lokal/API) namun sudah interaktif secara UI.
class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  bool _notifAbsensi = true;
  bool _notifPengumuman = true;
  bool _modeGelap = false;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Pengaturan',
      subtitle: 'Preferensi aplikasi & akun',
      icon: Icons.settings_rounded,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionLabel('NOTIFIKASI'),
          const SizedBox(height: 10),
          InfoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.fact_check_rounded,
                  title: 'Pengingat Absensi',
                  subtitle: 'Notifikasi jam masuk & pulang',
                  value: _notifAbsensi,
                  onChanged: (v) => setState(() => _notifAbsensi = v),
                ),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
                _SwitchRow(
                  icon: Icons.campaign_rounded,
                  title: 'Pengumuman Kantor',
                  subtitle: 'Info & pengumuman dari PDAM',
                  value: _notifPengumuman,
                  onChanged: (v) => setState(() => _notifPengumuman = v),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('TAMPILAN'),
          const SizedBox(height: 10),
          InfoCard(
            padding: EdgeInsets.zero,
            child: _SwitchRow(
              icon: Icons.dark_mode_rounded,
              title: 'Mode Gelap',
              subtitle: 'Segera hadir',
              value: _modeGelap,
              onChanged: null,
              isLast: true,
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('LAINNYA'),
          const SizedBox(height: 10),
          InfoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _NavRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Ubah Kata Sandi',
                  onTap: () => _showComingSoon(context),
                ),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
                _NavRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Kebijakan Privasi',
                  onTap: () => _showComingSoon(context),
                ),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
                _NavRow(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang Aplikasi',
                  subtitle: 'SIMPEG Mobile V3',
                  onTap: () => _showComingSoon(context),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'SIMPEG Mobile · v3.0.0',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Fitur ini sedang dalam pengembangan.'),
        backgroundColor: FeatureScaffold.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
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
        color: Color(0xFF8B98A9),
        letterSpacing: 0.6,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLast;

  const _SwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FB),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: FeatureScaffold.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B2733),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B98A9)),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: FeatureScaffold.accent,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isLast ? Radius.zero : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FB),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: FeatureScaffold.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B2733),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B98A9)),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB9C2CC)),
          ],
        ),
      ),
    );
  }
}