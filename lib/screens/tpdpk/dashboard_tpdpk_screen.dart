import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_screen.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/notification_bell.dart';
import '../shared/detail_pengaduan_screen.dart';

/// Dashboard untuk role TPDPK — Tahap 3 & Tahap 4 (fungsional).
/// Data & aksi sudah terhubung ke Supabase lewat [PengaduanService].
class DashboardTpdpkScreen extends StatefulWidget {
  final AppUser user;
  const DashboardTpdpkScreen({super.key, required this.user});

  @override
  State<DashboardTpdpkScreen> createState() => _DashboardTpdpkScreenState();
}

class _DashboardTpdpkScreenState extends State<DashboardTpdpkScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengaduan>> _future;

  @override
  void initState() {
    super.initState();
    _future = PengaduanService.untukRoleSebagaiObjek(UserRole.tpdpk);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PengaduanService.untukRoleSebagaiObjek(UserRole.tpdpk);
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

  Widget _judulSheet(String title, Pengaduan p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(p.nomorPengaduan,
              style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
          const SizedBox(height: 16),
        ],
      );

  // ---------- 1. Pilih petugas investigasi (eksekutor = TPDPK) ----------
  Future<void> _bukaPilihPetugas(Pengaduan p) async {
    final petugasController = TextEditingController();
    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Tetapkan Petugas Investigasi', p),
            TextField(
              controller: petugasController,
              decoration: InputDecoration(
                labelText: 'Nama petugas investigasi',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (petugasController.text.trim().isEmpty) {
                    _showSnack(
                        'Nama petugas wajib diisi.', const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.badge_rounded, size: 18),
                label: const Text('Tetapkan & Mulai Investigasi'),
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

    try {
      await PengaduanService.tpdpkPilihPetugas(
        pengaduanId: id,
        oleh: widget.user.name,
        petugas: petugasController.text.trim(),
      );

      if (!mounted) return;
      _showSnack('Petugas investigasi ditetapkan untuk ${p.nomorPengaduan}.',
          const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  // ---------- 2. Kirim hasil investigasi + surat rekomendasi ----------
  Future<void> _bukaKirimHasil(Pengaduan p, {required bool revisi}) async {
    final hasilController =
        TextEditingController(text: revisi ? (p.hasilInvestigasi ?? '') : '');
    final rekomendasiController =
        TextEditingController(text: revisi ? (p.suratRekomendasi ?? '') : '');

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet(
                revisi
                    ? 'Kirim Ulang Hasil Investigasi (Revisi)'
                    : 'Hasil Investigasi & Surat Rekomendasi',
                p),
            if (revisi && (p.catatanReviewHasilKspi ?? '').isNotEmpty) ...[
              _infoBlok('Catatan Revisi dari KSPI', p.catatanReviewHasilKspi!),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: hasilController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Hasil investigasi',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: rekomendasiController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Surat rekomendasi',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (hasilController.text.trim().isEmpty ||
                      rekomendasiController.text.trim().isEmpty) {
                    _showSnack(
                        'Hasil investigasi & surat rekomendasi wajib diisi.',
                        const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Kirim ke KSPI'),
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

    try {
      if (revisi) {
        await PengaduanService.kirimRevisiInvestigasi(
          pengaduanId: id,
          oleh: widget.user.name,
          hasil: hasilController.text.trim(),
          rekomendasi: rekomendasiController.text.trim(),
        );
      } else {
        await PengaduanService.kirimHasilInvestigasi(
          pengaduanId: id,
          oleh: widget.user.name,
          role: UserRole.tpdpk,
          hasil: hasilController.text.trim(),
          rekomendasi: rekomendasiController.text.trim(),
        );
      }

      await NotificationService.kirimKeRole(
        role: UserRole.kspi,
        judul: 'Hasil investigasi masuk',
        pesan: '${p.nomorPengaduan} sudah dikirim TPDPK, menunggu review KSPI.',
        pengaduanId: id,
      );

      if (!mounted) return;
      _showSnack('Hasil investigasi ${p.nomorPengaduan} dikirim ke KSPI.',
          const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  Widget _infoBlok(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F6F9),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7F8C8D))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  Future<void> _bukaSelesaikanTindakLanjut(Pengaduan p) async {
    final catatanController = TextEditingController();

    final konfirmasi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)),
                ),
                const Text('Selesaikan Tindak Lanjut',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(p.nomorPengaduan,
                    style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F6F9),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Instruksi Direktur',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7F8C8D))),
                      const SizedBox(height: 4),
                      Text(p.tindakLanjutDiminta ?? '-',
                          style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: catatanController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Keterangan penyelesaian (opsional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Tandai Selesai'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8449),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (konfirmasi != true) return;
    final id = p.supabaseId;
    if (id == null) return;

    try {
      await PengaduanService.selesaikanTindakLanjut(
        pengaduanId: id,
        oleh: widget.user.name,
        role: UserRole.tpdpk,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      final detail = await PengaduanService.detail(id);
      final pelaporId = detail?['pelapor_id'] as String?;
      if (pelaporId != null) {
        await NotificationService.kirimKePegawai(
          pegawaiId: pelaporId,
          judul: 'Pengaduan selesai',
          pesan:
              '${p.nomorPengaduan} — tindak lanjut telah dijalankan & dinyatakan selesai.',
          pengaduanId: id,
        );
      }

      if (!mounted) return;
      _showSnack(
          '${p.nomorPengaduan} ditandai selesai.', const Color(0xFF27AE60));
      await _refresh();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.tpdpk],
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F9),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('Dashboard TPDPK'),
          actions: [
            const NotificationBell(role: UserRole.tpdpk),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Keluar',
              onPressed: _logout,
            ),
          ],
        ),
        body: FutureBuilder<List<Pengaduan>>(
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
            final menungguPetugas = semua
                .where((p) => p.status == PengaduanStatus.menungguInvestigasi)
                .toList();
            final berjalan = semua
                .where((p) =>
                    p.status == PengaduanStatus.investigasiBerjalan &&
                    p.eksekutor == Eksekutor.tpdpk)
                .toList();
            final revisi = semua
                .where((p) =>
                    p.status == PengaduanStatus.revisiInvestigasi &&
                    p.eksekutor == Eksekutor.tpdpk)
                .toList();
            final tindakLanjut = semua
                .where((p) =>
                    p.status == PengaduanStatus.tindakLanjutBerjalan &&
                    p.eksekutorTindakLanjut == Eksekutor.tpdpk)
                .toList();

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildHeaderCard(semua.length),
                  const SizedBox(height: 20),
                  _buildSection(
                    'MENUNGGU PENUGASAN PETUGAS',
                    menungguPetugas,
                    (p) => _bukaPilihPetugas(p),
                    'Tidak ada tugas baru.',
                    'Tetapkan Petugas',
                  ),
                  _buildSection(
                    'INVESTIGASI BERJALAN',
                    berjalan,
                    (p) => _bukaKirimHasil(p, revisi: false),
                    'Tidak ada investigasi berjalan.',
                    'Kirim Hasil',
                  ),
                  _buildSection(
                    'PERLU REVISI (DIKEMBALIKAN KSPI)',
                    revisi,
                    (p) => _bukaKirimHasil(p, revisi: true),
                    'Tidak ada revisi yang diminta.',
                    'Kirim Ulang',
                  ),
                  _buildSection(
                    'TINDAK LANJUT DARI DIREKTUR',
                    tindakLanjut,
                    (p) => _bukaSelesaikanTindakLanjut(p),
                    'Tidak ada tindak lanjut yang ditugaskan.',
                    'Selesaikan',
                  ),
                ],
              ),
            );
          },
        ),
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
        borderRadius: BorderRadius.circular(16),
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
            const SizedBox(height: 4),
            Text('Petugas: ${p.petugasInvestigasi ?? '-'}',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
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
