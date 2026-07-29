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
            decoration: const BoxDecoration(
              color: Colors.white,
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
            color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
      );

  // ---------- Selesaikan tindak lanjut administratif ----------
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
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
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
                  const Text(
                    'Opsional. Nominal akan langsung dipotong dari slip gaji '
                    'periode terbaru pegawai (terintegrasi payroll).',
                    style: TextStyle(fontSize: 11.5, color: Colors.black54),
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F9),
        body: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: FutureBuilder<List<Pengaduan>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Gagal memuat data: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final semua = snapshot.data ?? [];
                  final menungguSdm = semua
                      .where((p) => p.status == PengaduanStatus.menungguSdm)
                      .toList();

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -22),
                          child: _buildHeaderCard(menungguSdm.length),
                        ),
                        const SizedBox(height: 6),
                        _buildSection(
                          'MENUNGGU TINDAK LANJUT SDM',
                          menungguSdm,
                          (p) => _bukaSelesaikan(p),
                          'Tidak ada pengaduan yang perlu ditindaklanjuti.',
                          'Selesaikan',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
        isSmallScreen ? 12.0 : 14.0,
        isSmallScreen ? 20.0 : 24.0,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                  'Tugas Tindak Lanjut SDM',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18.0 : 21.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white),
                tooltip: 'Riwayat Pengaduan',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiwayatPengaduanScreen(user: widget.user),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Muat ulang',
                onPressed: _refresh,
              ),
              const IconTheme(
                data: IconThemeData(color: Colors.white),
                child: NotificationBell(role: UserRole.sdm),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Keluar',
                onPressed: _logout,
              ),
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
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF7F8C8D))),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.centerLeft,
            child: Text(emptyText,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
          )
        else
          ...items.map((p) => _buildPengaduanCard(p, onAksi, tombolLabel)),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildHeaderCard(int jumlah) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [_navy, _accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            backgroundImage: widget.user.fotoUrl != null
                ? NetworkImage(widget.user.fotoUrl!)
                : null,
            child: widget.user.fotoUrl != null
                ? null
                : Text(widget.user.initials,
                    style: const TextStyle(
                        color: _navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text('${widget.user.role.label} · ${widget.user.jabatan}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text('$jumlah',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Text('Perlu Aksi',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
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
        color: Colors.white,
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