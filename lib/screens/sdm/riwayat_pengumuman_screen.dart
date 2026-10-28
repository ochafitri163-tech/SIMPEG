import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/pengumuman_model.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../widgets/pengumuman_card.dart';
import '../../widgets/role_guard.dart';

/// Kategori filter riwayat pengumuman (Semua / Aktif / Kedaluwarsa / Penting / Nonaktif)
enum _FilterRiwayatPengumuman { semua, aktif, kedaluwarsa, penting, nonaktif }

extension _FilterRiwayatPengumumanX on _FilterRiwayatPengumuman {
  String get label {
    switch (this) {
      case _FilterRiwayatPengumuman.semua:
        return 'Semua';
      case _FilterRiwayatPengumuman.aktif:
        return 'Aktif';
      case _FilterRiwayatPengumuman.kedaluwarsa:
        return 'Kedaluwarsa';
      case _FilterRiwayatPengumuman.penting:
        return 'Penting';
      case _FilterRiwayatPengumuman.nonaktif:
        return 'Nonaktif';
    }
  }

  bool cocok(Pengumuman p) {
    switch (this) {
      case _FilterRiwayatPengumuman.semua:
        return true;
      case _FilterRiwayatPengumuman.aktif:
        return p.sedangTayang;
      case _FilterRiwayatPengumuman.kedaluwarsa:
        return p.sudahKedaluwarsa;
      case _FilterRiwayatPengumuman.penting:
        return p.isPenting;
      case _FilterRiwayatPengumuman.nonaktif:
        return !p.aktif;
    }
  }
}

/// Layar Riwayat Pengumuman yang dibuat oleh SDM.
/// Didesain dengan tata letak & gaya identik dengan Riwayat Pengaduan:
/// - Topbar navy melengkung dengan tombol kembali
/// - Filter chip dengan penghitung jumlah item
/// - Kolom pencarian judul/isi pengumuman
/// - Kartu riwayat elegan dengan status badge (Aktif, Kedaluwarsa, dsb.)
/// - Ketuk kartu langsung membuka pop-up / lembar detail pengumuman
class RiwayatPengumumanScreen extends StatefulWidget {
  final AppUser user;
  const RiwayatPengumumanScreen({super.key, required this.user});

  @override
  State<RiwayatPengumumanScreen> createState() =>
      _RiwayatPengumumanScreenState();
}

class _RiwayatPengumumanScreenState extends State<RiwayatPengumumanScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengumuman>> _future;
  _FilterRiwayatPengumuman _filter = _FilterRiwayatPengumuman.semua;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _muatData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Pengumuman>> _muatData() {
    return PengumumanService.semua();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _muatData();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.sdm],
      child: Scaffold(
        backgroundColor: AppColors.pageBackground(context),
        body: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(context),
            Expanded(
              child: FutureBuilder<List<Pengumuman>>(
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
                          'Gagal memuat riwayat pengumuman: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }

                  final semua = snapshot.data ?? [];
                  final q = _query.trim().toLowerCase();
                  final terfilter = semua.where((p) {
                    if (!_filter.cocok(p)) return false;
                    if (q.isEmpty) return true;
                    return p.judul.toLowerCase().contains(q) ||
                        p.isi.toLowerCase().contains(q) ||
                        p.pembuat.toLowerCase().contains(q);
                  }).toList();

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: _navy,
                    child: Column(
                      children: [
                        _buildFilterBar(semua),
                        Expanded(
                          child: terfilter.isEmpty
                              ? ListView(
                                  children: [
                                    const SizedBox(height: 70),
                                    _buildEmptyState(),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 4, 16, 24),
                                  itemCount: terfilter.length,
                                  itemBuilder: (_, i) =>
                                      _buildCard(terfilter[i]),
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riwayat Pengumuman',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Arsip & riwayat seluruh pengumuman SDM',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: Colors.white,
                      size: 20,
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

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.divider(context),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: 'Cari judul atau isi pengumuman...',
            hintStyle: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary(context),
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: _accent,
            ),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(List<Pengumuman> semua) {
    int hitung(_FilterRiwayatPengumuman f) => semua.where(f.cocok).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _FilterRiwayatPengumuman.values.map((f) {
            final selected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${f.label} (${hitung(f)})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors.textPrimary(context),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inbox_rounded,
          size: 52,
          color: AppColors.divider(context),
        ),
        const SizedBox(height: 12),
        Text(
          _query.isNotEmpty
              ? 'Tidak ada pengumuman yang sesuai kata kunci.'
              : 'Belum ada riwayat pengumuman.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Seluruh pengumuman yang dibuat oleh SDM akan tersimpan di sini.',
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Pengumuman p) {
    // Penentuan badge status
    final Color statusColor;
    final String statusLabel;
    if (p.sudahKedaluwarsa) {
      statusColor = const Color(0xFFE74C3C);
      statusLabel = 'Kedaluwarsa';
    } else if (p.sedangTerjadwal) {
      statusColor = const Color(0xFFF39C12);
      statusLabel = 'Terjadwal';
    } else if (p.sedangTayang) {
      statusColor = const Color(0xFF27AE60);
      statusLabel = 'Aktif';
    } else {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'Nonaktif';
    }

    final String targetLabel = p.targetRoles.isEmpty
        ? 'Semua Role'
        : p.targetRoles.map((r) => r.toUpperCase()).join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showPengumumanDetail(context, p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.divider(context),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
              // Baris atas: Tag prioritas/sematkan & Badge Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (p.isPenting)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PENTING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        if (p.disematkan)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: _navy.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded,
                                    size: 11, color: _navy),
                                SizedBox(width: 3),
                                Text(
                                  'Semat',
                                  style: TextStyle(
                                    color: _navy,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          constraints: const BoxConstraints(maxWidth: 160),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            targetLabel,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: _accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Judul pengumuman
              Text(
                p.judul,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 5),

              // Ringkasan isi
              Text(
                p.ringkasan,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),

              // Tanggal & info pembuat
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dibuat: ${formatTanggalJam(p.tanggalPublikasi)} · Oleh: ${p.pembuat}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (p.kedaluwarsaPada != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Berakhir: ${formatTanggalJam(p.kedaluwarsaPada!)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              if (p.adaLampiran) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.divider(context),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 13,
                        color: _accent,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          p.lampiranNama ?? 'Lampiran tersedia',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider(context),
              ),
              const SizedBox(height: 8),

              // Footer: instruksi ketuk untuk detail
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 14,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Ketuk untuk lihat detail lengkap pengumuman',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: _accent,
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
