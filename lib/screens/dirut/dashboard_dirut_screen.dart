import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login_screen.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/notification_bell.dart';
import '../shared/detail_pengaduan_screen.dart';

/// Dashboard untuk role Direktur (DIRUT). Direktur menangani 3 titik dalam
/// alur:
/// 1. Approval Tahap 1 (menungguDirutTahap1) — layak diinvestigasi?
/// 2. Approval Tahap 2 (menungguDirutTahap2) — hasil investigasi diterima?
/// 3. Pilih eksekutor tindak lanjut (menungguPilihEksekutorTindakLanjut)
class DashboardDirutScreen extends StatefulWidget {
  final AppUser user;
  const DashboardDirutScreen({super.key, required this.user});

  @override
  State<DashboardDirutScreen> createState() => _DashboardDirutScreenState();
}

class _DashboardDirutScreenState extends State<DashboardDirutScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _green = Color(0xFF27AE60);
  static const Color _red = Color(0xFFE74C3C);

  late Future<List<Pengaduan>> _menungguFuture;
  late Future<List<Pengaduan>> _riwayatFuture;

  @override
  void initState() {
    super.initState();
    _menungguFuture = PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
    _riwayatFuture = PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
  }

  Future<void> _refreshMenunggu() async {
    setState(() {
      _menungguFuture =
          PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
    });
    await _menungguFuture;
  }

  Future<void> _refreshSemua() async {
    setState(() {
      _menungguFuture =
          PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
      _riwayatFuture =
          PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
    });
    await Future.wait([_menungguFuture, _riwayatFuture]);
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

  Widget _infoBlok(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
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

  Widget _pilihanTerimaTolak(
    Keputusan current,
    void Function(void Function()) setSheetState,
    void Function(Keputusan) onPick,
  ) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: Text('Terima',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: current == Keputusan.terima ? Colors.white : _navy)),
            selected: current == Keputusan.terima,
            selectedColor: _green,
            onSelected: (_) => setSheetState(() => onPick(Keputusan.terima)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: Text('Tolak',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: current == Keputusan.tolak ? Colors.white : _navy)),
            selected: current == Keputusan.tolak,
            selectedColor: _red,
            onSelected: (_) => setSheetState(() => onPick(Keputusan.tolak)),
          ),
        ),
      ],
    );
  }

  // ---------- Approval Tahap 1: layak diinvestigasi? ----------
  Future<void> _bukaKeputusanTahap1(Pengaduan p) async {
    Keputusan keputusan = Keputusan.terima;
    final catatanController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            const Text('Persetujuan Tahap 1',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Apakah pengaduan ini layak diinvestigasi?',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(p.nomorPengaduan,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(height: 14),
            _infoBlok('Judul', p.judul),
            _infoBlok('Deskripsi', p.deskripsi),
            const SizedBox(height: 6),
            _pilihanTerimaTolak(keputusan, setSheetState, (v) => keputusan = v),
            const SizedBox(height: 16),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: keputusan == Keputusan.tolak
                    ? 'Alasan penolakan (wajib)'
                    : 'Catatan (opsional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (keputusan == Keputusan.tolak &&
                      catatanController.text.trim().isEmpty) {
                    _showSnack('Alasan penolakan wajib diisi.', _red);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('Simpan Keputusan'),
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
      await PengaduanService.dirutTahap1Aksi(
        pengaduanId: id,
        oleh: widget.user.name,
        keputusan: keputusan,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      if (!mounted) return;
      _showSnack(
        keputusan == Keputusan.terima
            ? '${p.nomorPengaduan} disetujui, dikembalikan ke KSPI.'
            : '${p.nomorPengaduan} ditolak & diarsipkan.',
        keputusan == Keputusan.terima ? _green : _red,
      );
      await _refreshSemua();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  // ---------- Approval Tahap 2: hasil investigasi diterima? ----------
  Future<void> _bukaKeputusanTahap2(Pengaduan p) async {
    Keputusan keputusan = Keputusan.terima;
    final catatanController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            const Text('Persetujuan Tahap 2',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Apakah hasil investigasi ini diterima?',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(p.nomorPengaduan,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(height: 14),
            _infoBlok('Hasil Investigasi', p.hasilInvestigasi ?? '-'),
            _infoBlok('Surat Rekomendasi', p.suratRekomendasi ?? '-'),
            const SizedBox(height: 6),
            _pilihanTerimaTolak(keputusan, setSheetState, (v) => keputusan = v),
            const SizedBox(height: 16),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: keputusan == Keputusan.tolak
                    ? 'Alasan penolakan (wajib)'
                    : 'Catatan (opsional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (keputusan == Keputusan.tolak &&
                      catatanController.text.trim().isEmpty) {
                    _showSnack('Alasan penolakan wajib diisi.', _red);
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('Simpan Keputusan'),
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
      await PengaduanService.direksiTahap2Aksi(
        pengaduanId: id,
        oleh: widget.user.name,
        keputusan: keputusan,
        catatan: catatanController.text.trim().isEmpty
            ? null
            : catatanController.text.trim(),
      );

      if (!mounted) return;
      _showSnack(
        keputusan == Keputusan.terima
            ? '${p.nomorPengaduan} diterima, silakan pilih eksekutor tindak lanjut.'
            : '${p.nomorPengaduan} ditolak & diarsipkan.',
        keputusan == Keputusan.terima ? _green : _red,
      );

      if (keputusan == Keputusan.terima) {
        await _bukaPilihEksekutorTindakLanjut(p);
      }

      await _refreshSemua();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  // ---------- Pilih eksekutor tindak lanjut ----------
  Future<void> _bukaPilihEksekutorTindakLanjut(Pengaduan p) async {
    Eksekutor eksekutorDipilih = Eksekutor.kadiv;
    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            const Text('Pilih Eksekutor Tindak Lanjut',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(p.nomorPengaduan,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: Eksekutor.values.map((e) {
                final selected = eksekutorDipilih == e;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.label,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : _navy,
                              fontWeight: FontWeight.w600)),
                      selected: selected,
                      selectedColor: _accent,
                      onSelected: (_) =>
                          setSheetState(() => eksekutorDipilih = e),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('Tetapkan Eksekutor'),
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
      await PengaduanService.pilihEksekutorTindakLanjut(
        pengaduanId: id,
        oleh: widget.user.name,
        eksekutor: eksekutorDipilih,
      );

      if (!mounted) return;
      _showSnack(
          'Eksekutor tindak lanjut ditetapkan: ${eksekutorDipilih.label}.',
          _green);
      await _refreshSemua();
    } catch (e) {
      if (mounted) _showSnack('Gagal memproses: $e', Colors.red);
    }
  }

  /// Menentukan aksi utama yang perlu dilakukan Direktur untuk [p], sesuai
  /// status pengaduan saat ini. Return null kalau tidak ada aksi (seharusnya
  /// tidak terjadi karena list sudah difilter, tapi dijaga untuk keamanan).
  void Function()? _aksiUntuk(Pengaduan p) {
    switch (p.status) {
      case PengaduanStatus.menungguDirutTahap1:
        return () => _bukaKeputusanTahap1(p);
      case PengaduanStatus.menungguDirutTahap2:
        return () => _bukaKeputusanTahap2(p);
      case PengaduanStatus.menungguPilihEksekutorTindakLanjut:
        return () => _bukaPilihEksekutorTindakLanjut(p);
      default:
        return null;
    }
  }

  String _labelAksi(Pengaduan p) {
    switch (p.status) {
      case PengaduanStatus.menungguDirutTahap1:
        return 'Putuskan (Tahap 1)';
      case PengaduanStatus.menungguDirutTahap2:
        return 'Putuskan (Tahap 2)';
      case PengaduanStatus.menungguPilihEksekutorTindakLanjut:
        return 'Pilih Eksekutor';
      default:
        return 'Proses';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.direktur],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F6F9),
          appBar: AppBar(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            title: const Text('Dashboard Direktur (DIRUT)'),
            actions: [
              const NotificationBell(role: UserRole.direktur),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Keluar',
                onPressed: _logout,
              ),
            ],
            bottom: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Menunggu Persetujuan'),
                Tab(text: 'Riwayat'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              FutureBuilder<List<Pengaduan>>(
                future: _menungguFuture,
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
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final menunggu = snapshot.data ?? [];

                  return RefreshIndicator(
                    onRefresh: _refreshMenunggu,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildHeaderCard(menunggu.length),
                        const SizedBox(height: 20),
                        if (menunggu.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(Icons.inbox_rounded,
                                    size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                Text(
                                    'Tidak ada pengaduan yang menunggu persetujuan.',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey[500])),
                              ],
                            ),
                          )
                        else
                          ...menunggu.map((p) => _buildPengaduanCard(p)),
                      ],
                    ),
                  );
                },
              ),
              FutureBuilder<List<Pengaduan>>(
                future: _riwayatFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Gagal memuat riwayat: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final riwayat = snapshot.data ?? [];

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _riwayatFuture = PengaduanService.untukRoleSebagaiObjek(
                            UserRole.direktur);
                      });
                      await _riwayatFuture;
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: riwayat.isEmpty
                          ? [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                alignment: Alignment.center,
                                child: Text('Belum ada riwayat keputusan.',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey[500])),
                              ),
                            ]
                          : riwayat.map((p) => _buildRiwayatCard(p)).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
            child: Text(widget.user.initials,
                style: const TextStyle(
                    color: _navy, fontWeight: FontWeight.bold, fontSize: 16)),
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
                const Text('Menunggu',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPengaduanCard(Pengaduan p) {
    final aksi = _aksiUntuk(p);
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
            Text(
              p.status == PengaduanStatus.menungguDirutTahap2
                  ? 'Rekomendasi: ${p.suratRekomendasi ?? '-'}'
                  : p.deskripsi,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
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
                  child: ElevatedButton.icon(
                    onPressed: aksi,
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: Text(_labelAksi(p),
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatCard(Pengaduan p) {
    final riwayatDirektur =
        p.riwayatStatus.where((h) => h.role == UserRole.direktur).toList();
    final terakhirDirektur =
        riwayatDirektur.isNotEmpty ? riwayatDirektur.last : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              if (terakhirDirektur != null)
                Text(formatTanggalJam(terakhirDirektur.tanggal),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(p.judul,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(terakhirDirektur?.aksi ?? '-',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    );
  }
}
