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
      return PengaduanService.punyaSayaSebagaiObjek(nik: widget.user.nik);
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
      body: Column(
        children: [
          _buildHeader(context),
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
                        'Gagal memuat riwayat: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary(context), fontSize: 13),
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        color: _navy,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -40,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 14,
                left: 16,
                right: 16,
                bottom: 20,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Riwayat Pengaduan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(List<Pengaduan> semua) {
    int hitung(_FilterRiwayat f) => semua.where(f.cocok).length;
    IconData iconFor(_FilterRiwayat f) {
      switch (f) {
        case _FilterRiwayat.semua:
          return Icons.grid_view_rounded;
        case _FilterRiwayat.diproses:
          return Icons.autorenew_rounded;
        case _FilterRiwayat.selesai:
          return Icons.task_alt_rounded;
        case _FilterRiwayat.arsip:
          return Icons.archive_rounded;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _FilterRiwayat.values.map((f) {
            final isSelected = _filter == f;
            final count = hitung(f);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _filter = f),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? _navy : AppColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _navy : AppColors.divider(context),
                      width: 1.2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: _navy.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconFor(f),
                        size: 14,
                        color: isSelected ? Colors.white : AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : AppColors.surfaceMuted(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
          style: TextStyle(
              fontSize: 12.5, color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }

  bool _tampilkanInfoPelapor(Pengaduan p) {
    if (p.anonim) return false;

    final userNik = widget.user.nik.trim();
    final userName = widget.user.name.trim().toLowerCase();

    // Pihak yang dilaporkan (terlapor) tidak boleh melihat identitas pelapor
    final nikPelaku = (p.nikPelaku ?? '').trim();
    final namaPelaku = (p.pihakTerlapor ?? '').trim().toLowerCase();
    final isTerlapor = (nikPelaku.isNotEmpty && userNik == nikPelaku) ||
        (namaPelaku.isNotEmpty && userName == namaPelaku);
    if (isTerlapor) return false;

    // Hanya KSPI dan Kadiv Kategori (Administrasi & Teknik) yang bisa melihat pelapor
    final isKspi = widget.user.role == UserRole.kspi ||
        widget.user.nik == '1711161' ||
        widget.user.name.toLowerCase().contains('dodi');
    final isKadivKategori = widget.user.role == UserRole.kadivKategori;

    return isKspi || isKadivKategori;
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
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                      color: p.status.color.withValues(alpha: 0.12),
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
              if (_tampilkanInfoPelapor(p)) ...[
                Text(
                  'Pelapor: ${p.namaPegawai}',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: 2),
              ],
              const SizedBox(height: 2),
              Text(
                'Kategori: ${p.kategori} \u00b7 ${formatTanggalJam(p.tanggalPengaduan)}',
                style: TextStyle(
                    fontSize: 11.5, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 15, color: AppColors.textSecondary(context)),
                  const SizedBox(width: 4),
                  Text(
                    'Ketuk untuk lihat detail & alur status',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary(context)),
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
