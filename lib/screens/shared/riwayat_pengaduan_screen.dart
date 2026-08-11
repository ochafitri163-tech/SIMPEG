import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import 'detail_pengaduan_screen.dart';
import '../../theme/app_colors.dart';

/// Layar Riwayat Pengaduan yang dipakai bersama oleh SEMUA role
/// (Kadiv, KSPI, TPDPK, SDM, dan bisa juga Direktur). Menampilkan seluruh
/// pengaduan yang relevan dengan role tersebut, lengkap dengan filter
/// status (Semua / Diproses / Selesai / Diarsipkan) & pencarian ke halaman
/// detail.
///
/// Sumber data: [PengaduanService.untukRoleSebagaiObjek], sehingga tiap
/// role melihat daftar sesuai kewenangannya. Layar ini sengaja read-only —
/// aksi (verifikasi/approval/investigasi) tetap dilakukan dari dashboard
/// masing-masing role.
class RiwayatPengaduanScreen extends StatefulWidget {
  final AppUser user;
  const RiwayatPengaduanScreen({super.key, required this.user});

  @override
  State<RiwayatPengaduanScreen> createState() => _RiwayatPengaduanScreenState();
}

/// Kategori filter yang ditampilkan sebagai chip di bagian atas.
enum _FilterRiwayat { semua, diproses, selesai, arsip }

extension _FilterRiwayatX on _FilterRiwayat {
  String get label {
    switch (this) {
      case _FilterRiwayat.semua:
        return 'Semua';
      case _FilterRiwayat.diproses:
        return 'Diproses';
      case _FilterRiwayat.selesai:
        return 'Selesai';
      case _FilterRiwayat.arsip:
        return 'Diarsipkan';
    }
  }

  bool cocok(Pengaduan p) {
    switch (this) {
      case _FilterRiwayat.semua:
        return true;
      case _FilterRiwayat.selesai:
        return p.status == PengaduanStatus.selesai;
      case _FilterRiwayat.arsip:
        return p.status == PengaduanStatus.arsip;
      case _FilterRiwayat.diproses:
        return p.status != PengaduanStatus.selesai &&
            p.status != PengaduanStatus.arsip;
    }
  }
}

class _RiwayatPengaduanScreenState extends State<RiwayatPengaduanScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengaduan>> _future;
  _FilterRiwayat _filter = _FilterRiwayat.semua;

  /// Sumber data disesuaikan per role:
  /// - Pegawai (pelapor) HANYA melihat pengaduan miliknya sendiri (bukan
  ///   seluruh pengaduan semua orang).
  /// - Kadiv dibatasi sesuai divisinya (administrasi/teknik), sama seperti
  ///   di dashboard Kadiv, supaya tidak bocor ke divisi lain.
  /// - Role lain (KSPI, TPDPK, Direktur, SDM) melihat semua pengaduan
  ///   sesuai kewenangannya seperti sebelumnya.
  Future<List<Pengaduan>> _muatData() {
    if (widget.user.role == UserRole.pegawai) {
      return PengaduanService.punyaSayaSebagaiObjek();
    }
    return PengaduanService.untukRoleSebagaiObjek(
      widget.user.role,
      divisiKadiv: widget.user.divisiKadiv?.name,
    );
  }

  @override
  void initState() {
    super.initState();
    _future = _muatData();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _muatData();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground(context),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Riwayat Pengaduan'),
        elevation: 0,
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
                  'Gagal memuat riwayat: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                ),
              ),
            );
          }

          final semua = snapshot.data ?? [];
          final terfilter = semua.where(_filter.cocok).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                _buildFilterBar(semua),
                Expanded(
                  child: terfilter.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            _buildEmptyState(),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: terfilter.length,
                          itemBuilder: (_, i) => _buildCard(terfilter[i]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(List<Pengaduan> semua) {
    int hitung(_FilterRiwayat f) => semua.where(f.cocok).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: AppColors.card(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _FilterRiwayat.values.map((f) {
            final selected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${f.label} (${hitung(f)})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary(context),
                  ),
                ),
                selected: selected,
                selectedColor: _accent,
                backgroundColor: AppColors.surfaceMuted(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: selected ? _accent : AppColors.divider(context),
                  ),
                ),
                onSelected: (_) => setState(() => _filter = f),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(Icons.inbox_rounded, size: 48, color: AppColors.divider(context)),
        const SizedBox(height: 10),
        Text(
          'Belum ada riwayat pengaduan.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildCard(Pengaduan p) {
    final pelapor = p.anonim ? 'Anonim' : p.namaPegawai;
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
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
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
                    child: Text(
                      p.nomorPengaduan,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.status.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.status.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                p.judul,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context)),
              ),
              const SizedBox(height: 4),
              Text(
                'Pelapor: $pelapor',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 2),
              Text(
                'Kategori: ${p.kategori} \u00b7 ${formatTanggalJam(p.tanggalPengaduan)}',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 15, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 4),
                  Text(
                    'Ketuk untuk lihat detail & alur status',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}