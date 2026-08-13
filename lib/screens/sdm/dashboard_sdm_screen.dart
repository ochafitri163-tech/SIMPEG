import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_screen.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/notification_bell.dart';
import '../shared/detail_pengaduan_screen.dart';
import '../shared/riwayat_pengaduan_screen.dart';
import 'kelola_pengumuman_screen.dart';
import 'terbitkan_sk_screen.dart';

import '../../theme/app_colors.dart';
import '../../services/theme_controller.dart';
/// Dashboard untuk role SDM — titik akhir alur Pengaduan (tindak lanjut
/// administratif). Data & aksi terhubung ke Supabase lewat
/// [PengaduanService.untukRoleSebagaiObjek] & [PengaduanService.sdmSelesaikan].
class DashboardSdmScreen extends StatefulWidget {
  final AppUser user;
  const DashboardSdmScreen({super.key, required this.user});

  @override
  State<DashboardSdmScreen> createState() => _DashboardSdmScreenState();
}

class _DashboardSdmScreenState extends State<DashboardSdmScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengaduan>> _future;

  @override
  void initState() {
    super.initState();
    _future = PengaduanService.untukRoleSebagaiObjek(UserRole.sdm);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PengaduanService.untukRoleSebagaiObjek(UserRole.sdm);
    });
    await _future;
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<T?> _openSheet<T>(
      Widget Function(BuildContext, void Function(void Function())) builder) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: builder(ctx, setSheetState),
          ),
        ),
      ),
    );
  }

  Widget _grip() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: AppColors.divider(context), borderRadius: BorderRadius.circular(10)),
      );

  // ---------- Selesaikan tindak lanjut administratif (via SK Sanksi) ----------
  // Tombol "Selesaikan" pada kartu pengaduan langsung membuka form
  // Terbitkan SK Sanksi dengan data pengaduan (NIK, nama, golongan,
  // ringkasan) sudah terisi otomatis. Saat SK diterbitkan di sana,
  // [SkSanksiService.terbitkan] otomatis menandai pengaduan ini selesai
  // (lihat pengaduanId di dalamnya), jadi tidak perlu lagi menu terpisah
  // "Terbitkan SK Sanksi" di titik tiga.
  Future<void> _bukaTerbitkanSk(Pengaduan p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TerbitkanSkScreen(
          user: widget.user,
          pengaduan: p,
          pengaduanId: p.supabaseId,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  // ---------- (lama) Selesaikan tanpa SK — tidak lagi dipakai tombol utama,
  // tetap disimpan agar tidak menghapus fitur/logic yang sudah ada. ----------
  Future<void> _bukaSelesaikan(Pengaduan p) async {
    final catatanController = TextEditingController();
    final nikController = TextEditingController();
    final nominalController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            const Text('Selesaikan Tindak Lanjut Administratif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(p.nomorPengaduan,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF3C2C2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.trending_down_rounded,
                          size: 18, color: Color(0xFFC0392B)),
                      SizedBox(width: 6),
                      Text('Penurunan Gaji (Sanksi)',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC0392B))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opsional. Nominal akan langsung dipotong dari slip gaji '
                    'periode terbaru pegawai (terintegrasi payroll).',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nikController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'NIK pegawai',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nominalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nominal penurunan (Rp)',
                      prefixText: 'Rp ',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan SDM (opsional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Tandai Selesai'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok != true) return;
    final id = p.supabaseId;
    if (id == null) return;

    final nik = nikController.text.trim();
    final nominal = int.tryParse(
            nominalController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;

    // Kalau salah satu field penurunan gaji diisi, keduanya wajib benar.
    if ((nik.isNotEmpty && nominal <= 0) || (nik.isEmpty && nominal > 0)) {
      _showSnack(
          'Lengkapi NIK dan nominal penurunan gaji, atau kosongkan keduanya.',
          Colors.red);
      return;
    }

    try {
      await PengaduanService.sdmSelesaikan(
        pengaduanId: id,
        oleh: widget.user.name,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
        nikTerlapor: nik.isEmpty ? null : nik,
        nominalPenurunanGaji: nominal > 0 ? nominal : null,
      );

      if (!mounted) return;
      _showSnack(
        nominal > 0
            ? '${p.nomorPengaduan} selesai. Gaji NIK $nik diturunkan (Rp$nominal).'
            : '${p.nomorPengaduan} ditandai selesai.',
        const Color(0xFF27AE60),
      );
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.sdm],
      child: Material(
        color: AppColors.pageBackground(context),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: FutureBuilder<List<Pengaduan>>(
            future: _future,
            builder: (context, snapshot) {
              Widget content;

              if (snapshot.connectionState == ConnectionState.waiting) {
                content = const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                content = Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'Gagal memuat data: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                  ),
                );
              } else {
                final semua = snapshot.data ?? [];
                final menungguSdm = semua
                    .where((p) => p.status == PengaduanStatus.menungguSdm)
                    .toList();

                content = _buildSection(
                  'MENUNGGU TINDAK LANJUT SDM',
                  menungguSdm,
                  (p) => _bukaTerbitkanSk(p),
                  'Tidak ada pengaduan yang perlu ditindaklanjuti.',
                  'Selesaikan',
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopHeader(context),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -28),
                              child: _buildProfileCard(
                                snapshot.data
                                        ?.where((p) =>
                                            p.status ==
                                            PengaduanStatus.menungguSdm)
                                        .length ??
                                    0,
                              ),
                            ),
                            const SizedBox(height: 18),
                            content,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16.0 : 20.0,
        MediaQuery.of(context).padding.top + (isSmallScreen ? 10.0 : 14.0),
        isSmallScreen ? 12.0 : 16.0,
        isSmallScreen ? 40.0 : 56.0,
      ),
      decoration: BoxDecoration(
        // Gradien 3-titik yang sama persis dengan header dashboard pegawai
        // & role lain (Kadiv/KSPI/TPDPK/Dirut) agar temanya senada.
        gradient: LinearGradient(
          colors: [
            _navy,
            _navy.withValues(alpha: 0.85),
            const Color(0xFF123A85),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tindak Lanjut SDM',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18.0 : 21.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Header dibuat ringkas: hanya notifikasi + satu tombol menu.
              // Aksi lain (pengumuman, SK, riwayat, tema, muat ulang, keluar)
              // dipindah ke menu tiga titik supaya tidak terlihat penuh.
              const IconTheme(
                data: IconThemeData(color: Colors.white),
                child: NotificationBell(role: UserRole.sdm),
              ),
              _buildMenuAksi(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Selesaikan tindak lanjut administratif pegawai',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: isSmallScreen ? 11.0 : 12.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Menu ringkas berisi seluruh aksi header SDM.
  Widget _buildMenuAksi() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return PopupMenuButton<String>(
          tooltip: 'Menu',
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (nilai) {
            switch (nilai) {
              case 'pengumuman':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => KelolaPengumumanScreen(user: widget.user),
                  ),
                );
                break;
              case 'riwayat':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiwayatPengaduanScreen(user: widget.user),
                  ),
                );
                break;
              case 'tema':
                ThemeController.instance.setDark(!isDark);
                break;
              case 'refresh':
                _refresh();
                break;
              case 'logout':
                _logout();
                break;
            }
          },
          itemBuilder: (context) => [
            _itemMenu('pengumuman', Icons.campaign_rounded,
                'Kelola Pengumuman'),
            _itemMenu('riwayat', Icons.history_rounded, 'Riwayat Pengaduan'),
            const PopupMenuDivider(),
            _itemMenu(
              'tema',
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              isDark ? 'Mode Terang' : 'Mode Gelap',
            ),
            _itemMenu('refresh', Icons.refresh_rounded, 'Muat ulang'),
            const PopupMenuDivider(),
            _itemMenu('logout', Icons.logout_rounded, 'Keluar',
                warna: const Color(0xFFE74C3C)),
          ],
        );
      },
    );
  }

  PopupMenuItem<String> _itemMenu(
    String nilai,
    IconData ikon,
    String label, {
    Color? warna,
  }) {
    return PopupMenuItem<String>(
      value: nilai,
      height: 44,
      child: Row(
        children: [
          Icon(ikon, size: 18, color: warna ?? _navy),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Pengaduan> items,
    Future<void> Function(Pengaduan) onAksi,
    String emptyText,
    String tombolLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textSecondary(context))),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.centerLeft,
            child: Text(emptyText,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context))),
          )
        else
          ...items.map((p) => _buildPengaduanCard(p, onAksi, tombolLabel)),
        const SizedBox(height: 14),
      ],
    );
  }

  /// Kartu putih profil pengguna yang "mengambang" di atas header navy —
  /// ukuran, radius, dan bayangannya meniru persis kartu jadwal pada
  /// dashboard pegawai (dan halaman Kadiv/KSPI/TPDPK/Dirut), agar
  /// temanya konsisten di seluruh aplikasi.
  Widget _buildProfileCard(int jumlah) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
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
            width: isSmallScreen ? 42.0 : 46.0,
            height: isSmallScreen ? 42.0 : 46.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, _accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              image: widget.user.fotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.user.fotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.user.fotoUrl != null
                ? null
                : Text(
                    widget.user.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.5 : 14.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.user.role.label} · ${widget.user.jabatan}',
                  overflow: TextOverflow.ellipsis,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$jumlah',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context))),
                const Text('Perlu Aksi',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPengaduanCard(Pengaduan p,
      Future<void> Function(Pengaduan) onAksi, String tombolLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.nomorPengaduan,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accent)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: p.status.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(p.status.label,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: p.status.color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.judul,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final id = p.supabaseId;
                      if (id == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PengaduanDetailScreen(
                              user: widget.user, pengaduanId: id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Detail', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onAksi(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                    child:
                        Text(tombolLabel, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}