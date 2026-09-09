import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../services/theme_controller.dart';
import '../../widgets/feature_scaffold.dart';
import 'kebijakan_privasi_screen.dart';
import 'tentang_aplikasi_screen.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  bool _notifAbsensi = true;
  bool _notifPengumuman = true;
  bool _isLoadingPref = true;
  bool _isSavingAbsensi = false;
  bool _isSavingPengumuman = false;

  @override
  void initState() {
    super.initState();
    _muatPreferensi();
  }

  Future<void> _muatPreferensi() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoadingPref = false);
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('preferensi_pegawai')
          .select()
          .eq('pegawai_id', userId)
          .maybeSingle();

      if (row != null && mounted) {
        setState(() {
          _notifAbsensi = (row['notif_absensi'] as bool?) ?? true;
          _notifPengumuman = (row['notif_pengumuman'] as bool?) ?? true;
        });
      }
    } catch (_) {
      // Kalau gagal fetch, tetap pakai default (true/true) tanpa error UI.
    } finally {
      if (mounted) setState(() => _isLoadingPref = false);
    }
  }

  Future<void> _simpanPreferensiNotif() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('preferensi_pegawai').upsert({
        'pegawai_id': userId,
        'notif_absensi': _notifAbsensi,
        'notif_pengumuman': _notifPengumuman,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan preferensi: $e')),
        );
      }
    }
  }

  Future<void> _onToggleAbsensi(bool value) async {
    setState(() {
      _notifAbsensi = value;
      _isSavingAbsensi = true;
    });

    if (value) {
      await NotificationService.instance.enableAbsensiReminder();
    } else {
      await NotificationService.instance.disableAbsensiReminder();
    }
    await _simpanPreferensiNotif();

    if (mounted) setState(() => _isSavingAbsensi = false);
  }

  Future<void> _onTogglePengumuman(bool value) async {
    setState(() {
      _notifPengumuman = value;
      _isSavingPengumuman = true;
    });

    if (value) {
      await NotificationService.instance.enablePengumumanNotif();
    } else {
      await NotificationService.instance.disablePengumumanNotif();
    }
    await _simpanPreferensiNotif();

    if (mounted) setState(() => _isSavingPengumuman = false);
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Pengaturan',
      subtitle: 'Preferensi aplikasi & akun',
      icon: Icons.settings_rounded,
      child: _isLoadingPref
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                        isBusy: _isSavingAbsensi,
                        onChanged: _onToggleAbsensi,
                      ),
                      _ThemedDivider(),
                      _SwitchRow(
                        icon: Icons.campaign_rounded,
                        title: 'Pengumuman Kantor',
                        subtitle: 'Info & pengumuman dari PDAM',
                        value: _notifPengumuman,
                        isBusy: _isSavingPengumuman,
                        onChanged: _onTogglePengumuman,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionLabel('TAMPILAN'),
                const SizedBox(height: 10),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.themeMode,
                  builder: (context, mode, _) {
                    return ValueListenableBuilder<UiVersion>(
                      valueListenable: ThemeController.instance.uiVersion,
                      builder: (context, version, _) {
                        final isV2 = version == UiVersion.v2;
                        return InfoCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _SwitchRow(
                                icon: Icons.dark_mode_rounded,
                                title: 'Mode Gelap',
                                subtitle: mode == ThemeMode.dark ? 'Aktif' : 'Nonaktif',
                                value: mode == ThemeMode.dark,
                                onChanged: (v) => ThemeController.instance.setDark(v),
                              ),
                              _ThemedDivider(),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.style_rounded,
                                          color: Color(0xFF2563EB),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Gaya Desain Aplikasi',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                isV2
                                                    ? 'V2 Modern Luxury (Gradasi & Glassmorphism)'
                                                    : 'V1 Klasik (Desain Standar SIMPEG)',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => ThemeController.instance
                                                .setUiVersion(UiVersion.v1),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 10, horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: !isV2
                                                    ? const Color(0xFF0D2C6E)
                                                        .withValues(alpha: 0.12)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: !isV2
                                                      ? const Color(0xFF0D2C6E)
                                                      : Colors.grey.withValues(alpha: 0.3),
                                                  width: !isV2 ? 1.8 : 1.0,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.grid_view_rounded,
                                                    color: !isV2
                                                        ? const Color(0xFF0D2C6E)
                                                        : Colors.grey,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'V1 Klasik',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: !isV2
                                                          ? FontWeight.bold
                                                          : FontWeight.w500,
                                                      color: !isV2
                                                          ? const Color(0xFF0D2C6E)
                                                          : Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => ThemeController.instance
                                                .setUiVersion(UiVersion.v2),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 10, horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: isV2
                                                    ? const Color(0xFF0284C7)
                                                        .withValues(alpha: 0.14)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isV2
                                                      ? const Color(0xFF0284C7)
                                                      : Colors.grey.withValues(alpha: 0.3),
                                                  width: isV2 ? 1.8 : 1.0,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.auto_awesome_rounded,
                                                    color: isV2
                                                        ? const Color(0xFF0284C7)
                                                        : Colors.grey,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'V2 Luxury',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: isV2
                                                          ? FontWeight.bold
                                                          : FontWeight.w500,
                                                      color: isV2
                                                          ? const Color(0xFF0284C7)
                                                          : Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 22),
                const _SectionLabel('LAINNYA'),
                const SizedBox(height: 10),
                InfoCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Kebijakan Privasi',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const KebijakanPrivasiScreen(),
                          ),
                        ),
                      ),
                      _ThemedDivider(),
                      _NavRow(
                        icon: Icons.info_outline_rounded,
                        title: 'Tentang Aplikasi',
                        subtitle: 'SIMPEG Mobile V3',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TentangAplikasiScreen(),
                          ),
                        ),
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
}

/// Divider tipis yang otomatis menyesuaikan warna dengan tema aktif,
/// dipakai sebagai pemisah antar baris di dalam InfoCard.
class _ThemedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF2A3342) : const Color(0xFFF0F2F5),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFF6D7A8A) : const Color(0xFF8B98A9),
        letterSpacing: 0.6,
      ),
    );
  }
}

/// Baris switch yang responsif: judul & subjudul boleh membungkus lebih
/// dari 1 baris (mis. di layar sempit) tanpa membuat ikon/switch
/// kehilangan posisi, karena `Row` disejajarkan ke atas (bukan tengah).
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLast;
  final bool isBusy;

  const _SwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? FeatureScaffold.accent.withOpacity(0.18)
                  : const Color(0xFFEAF2FB),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: FeatureScaffold.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1B2733),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF9AA6B2)
                          : const Color(0xFF8B98A9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          isBusy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Switch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: FeatureScaffold.accent,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
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
                color: isDark
                    ? FeatureScaffold.accent.withOpacity(0.18)
                    : const Color(0xFFEAF2FB),
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
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1B2733),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFF9AA6B2)
                            : const Color(0xFF8B98A9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFF4A5568) : const Color(0xFFB9C2CC),
            ),
          ],
        ),
      ),
    );
  }
}