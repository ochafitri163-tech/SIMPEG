import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import 'pengaduan_detail_screen.dart';

/// Dashboard "kotak masuk" pengaduan, dipakai oleh SEMUA role.
/// - Pegawai: melihat seluruh pengaduan yang pernah dia buat sendiri.
/// - Role lain (Kadiv/KSPI/TPDPK/Direktur/SDM): melihat pengaduan yang
///   PERLU ditindaklanjuti olehnya saat ini (sesuai status & role).
class PengaduanListScreen extends StatefulWidget {
  final AppUser user;
  const PengaduanListScreen({super.key, required this.user});

  @override
  State<PengaduanListScreen> createState() => _PengaduanListScreenState();
}

class _PengaduanListScreenState extends State<PengaduanListScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color navyDark = Color(0xFF0A2257);
  static const Color labelDark = Color(0xFF1B2733);
  static const Color hintGrey = Color(0xFF9AA5B1);

  late Future<List<Pengaduan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Pengaduan>> _load() async {
    final user = widget.user;
    if (user.role == UserRole.pegawai) {
      return PengaduanService.punyaSayaSebagaiObjek();
    }
    final semua = await PengaduanService.untukRoleSebagaiObjek(user.role);
    return semua.where((p) => _perluDitindaklanjuti(p, user)).toList();
  }

  /// Filter client-side tambahan (di luar RLS Supabase) untuk menentukan
  /// apakah [p] muncul di kotak masuk [user] saat ini.
  bool _perluDitindaklanjuti(Pengaduan p, AppUser user) {
    switch (user.role) {
      case UserRole.pegawai:
        return true; // tidak dipakai, sudah ditangani di atas.
      case UserRole.kadivKategori:
        final kategoriCocok = user.divisiKadiv == null ||
            _kategoriCocokDivisi(p.kategori, user.divisiKadiv!);
        final sebagaiVerifikator =
            p.status == PengaduanStatus.menungguKadiv && kategoriCocok;
        final sebagaiEksekutorInvestigasi =
            p.status == PengaduanStatus.investigasiBerjalan &&
                p.eksekutor == Eksekutor.kadiv;
        final sebagaiEksekutorTindakLanjut =
            p.status == PengaduanStatus.tindakLanjutBerjalan &&
                p.eksekutorTindakLanjut == Eksekutor.kadiv;
        return sebagaiVerifikator ||
            sebagaiEksekutorInvestigasi ||
            sebagaiEksekutorTindakLanjut;
      case UserRole.kspi:
        return p.status == PengaduanStatus.menungguPilihEksekutor;
      case UserRole.tpdpk:
        final sebagaiEksekutorInvestigasi =
            p.status == PengaduanStatus.investigasiBerjalan &&
                p.eksekutor == Eksekutor.tpdpk;
        final sebagaiEksekutorTindakLanjut =
            p.status == PengaduanStatus.tindakLanjutBerjalan &&
                p.eksekutorTindakLanjut == Eksekutor.tpdpk;
        return sebagaiEksekutorInvestigasi || sebagaiEksekutorTindakLanjut;
      case UserRole.direktur:
        return p.status == PengaduanStatus.menungguDirutTahap1 ||
            p.status == PengaduanStatus.menungguDirutTahap2 ||
            p.status == PengaduanStatus.menungguPilihEksekutorTindakLanjut;
      case UserRole.sdm:
        return p.status == PengaduanStatus.menungguSdm;
    }
  }

  bool _kategoriCocokDivisi(String kategori, DivisiKadiv divisi) {
    final divisiKategori = divisiKadivDariKategori(kategori);
    return divisiKategori == null || divisiKategori == divisi;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Pengaduan>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            'Gagal memuat data: ${snapshot.error}',
                            style: const TextStyle(color: hintGrey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }
                  final data = snapshot.data ?? [];
                  if (data.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'Tidak ada pengaduan saat ini.',
                            style: TextStyle(color: hintGrey, fontSize: 13.5),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    itemCount: data.length,
                    itemBuilder: (context, i) => _buildCard(data[i]),
                  );
                },
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
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navyDark, navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.role == UserRole.pegawai
                      ? 'Pengaduan Saya'
                      : 'Kotak Masuk Pengaduan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.role.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Pengaduan p) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        final id = p.supabaseId;
        if (id == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PengaduanDetailScreen(user: widget.user, pengaduanId: id),
          ),
        ).then((_) => _refresh());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                    p.nomorPengaduan,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hintGrey,
                    ),
                  ),
                ),
                _statusBadge(p.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              p.judul,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: labelDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              p.kategori,
              style: const TextStyle(fontSize: 12, color: hintGrey),
            ),
            const SizedBox(height: 8),
            Text(
              formatTanggalJam(p.tanggalPengaduan),
              style: const TextStyle(fontSize: 11, color: hintGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(PengaduanStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
