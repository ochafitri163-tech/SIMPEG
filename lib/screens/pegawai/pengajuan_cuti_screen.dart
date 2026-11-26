import 'package:flutter/material.dart';
import '../../models/cuti_service.dart';
import '../../models/pengaduan_model.dart' show formatTanggalIndonesia;
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feature_scaffold.dart';
import 'surat_cuti_screen.dart';

/// Halaman **Data & Surat Izin Cuti Pegawai** (View dari inputan Web).
/// Menampilkan data permohonan cuti yang diinput melalui web `/cuti`:
/// - Ringkasan hak cuti tahunan (maksimal 12 hari kerja) & rekap status
/// - Banner "Status Pengajuan Cuti Terkini" + tombol cepat Cetak Surat Cuti
/// - Filter Tahun & Status (`Semua`, `PENDING`, `DISETUJUI`, `DITOLAK`)
/// - Tab **Kelola & Verifikasi** khusus SDM & Direksi (Setujui / Tolak / Edit Status
///   dengan catatan approver + cari pegawai + cetak surat dinas)
class PengajuanCutiScreen extends StatefulWidget {
  final AppUser user;
  final int initialTabIndex;

  const PengajuanCutiScreen({
    super.key,
    required this.user,
    this.initialTabIndex = 0,
  });

  @override
  State<PengajuanCutiScreen> createState() => _PengajuanCutiScreenState();
}

class _PengajuanCutiScreenState extends State<PengajuanCutiScreen>
    with SingleTickerProviderStateMixin {
  static const Color _navy = Color(0xFF0D2C6E);

  late final bool _isApprover;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _isApprover = CutiService.canApprove(widget.user);
    if (_isApprover) {
      _tabController = TabController(
        length: 2,
        vsync: this,
        initialIndex: widget.initialTabIndex.clamp(0, 1),
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Cuti Pegawai',
      subtitle: _isApprover
          ? 'Pantau data, verifikasi & cetak surat izin cuti'
          : 'Pantau data cuti dari web & cetak surat izin cuti',
      icon: Icons.event_available_rounded,
      child: _isApprover && _tabController != null
          ? Column(
              children: [
                Container(
                  color: AppColors.card(context),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: _navy,
                    unselectedLabelColor: AppColors.textSecondary(context),
                    indicatorColor: _navy,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Cuti Saya'),
                      Tab(text: 'Kelola & Verifikasi'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      CutiTabView(user: widget.user, manageAll: false),
                      CutiTabView(user: widget.user, manageAll: true),
                    ],
                  ),
                ),
              ],
            )
          : CutiTabView(user: widget.user, manageAll: false),
    );
  }
}

/// View konten cuti yang digunakan bersama oleh [PengajuanCutiScreen]
/// (baik mode pribadi maupun mode manajemen SDM/Direksi) dan [PersetujuanCutiScreen].
class CutiTabView extends StatefulWidget {
  final AppUser user;
  final bool manageAll;
  final String initialStatusFilter;

  const CutiTabView({
    super.key,
    required this.user,
    required this.manageAll,
    this.initialStatusFilter = 'all',
  });

  @override
  State<CutiTabView> createState() => _CutiTabViewState();
}

class _CutiTabViewState extends State<CutiTabView>
    with AutomaticKeepAliveClientMixin {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF0284C7);

  late int? _selectedTahun;
  late String _statusFilter;
  String _searchQuery = '';
  final _searchC = TextEditingController();
  late Future<CutiFetchResult> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedTahun = DateTime.now().year;
    _statusFilter = widget.initialStatusFilter;
    _future = _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<CutiFetchResult> _load() {
    return CutiService.fetchCuti(
      nik: widget.manageAll ? null : widget.user.nik,
      all: widget.manageAll,
      tahun: _selectedTahun,
      status: _statusFilter,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _bukaVerifikasi(PengajuanCuti c, {StatusCuti? initial}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerifikasiCutiSheet(
        pengajuan: c,
        approver: widget.user,
        initialDecision: initial ??
            (c.status == StatusCuti.ditolak
                ? StatusCuti.ditolak
                : StatusCuti.disetujui),
      ),
    );
    if (ok == true && mounted) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status pengajuan cuti diperbarui & notifikasi dikirim.'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _bukaSurat(PengajuanCuti c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SuratCutiScreen(cuti: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentYear = DateTime.now().year;
    final years = <int?>[
      currentYear,
      currentYear - 1,
      currentYear - 2,
      currentYear - 3,
      null, // Semua Tahun
    ];

    return Column(
      children: [
        Expanded(
          child: FutureBuilder<CutiFetchResult>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gagal memuat data cuti: ${snapshot.error}',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _refresh,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final result = snapshot.data ??
                  CutiFetchResult(
                    items: const [],
                    summary: CutiSummary.fromList(const []),
                  );
              final allItems = result.items;
              final q = _searchQuery.trim().toLowerCase();
              final filteredItems = q.isEmpty
                  ? allItems
                  : allItems.where((c) {
                      return c.namaPegawai.toLowerCase().contains(q) ||
                          c.nik.toLowerCase().contains(q) ||
                          c.unitKerja.toLowerCase().contains(q) ||
                          c.noSurat.toLowerCase().contains(q) ||
                          c.jenis.toLowerCase().contains(q);
                    }).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    // 1. Kartu Ringkasan Kuota & Rekap
                    _buildSummaryCard(result.summary),
                    const SizedBox(height: 12),

                    // 2. Status Tracking Banner Khusus Pengajuan Pribadi Terbaru
                    if (!widget.manageAll && allItems.isNotEmpty) ...[
                      _buildLatestStatusCard(allItems.first),
                      const SizedBox(height: 12),
                    ],

                    // 3. Baris Filter Tahun & Status (sesuai Web cuti/index)
                    _buildFilterSection(years, filteredItems.length),
                    const SizedBox(height: 12),

                    // 4. Daftar Pengajuan Cuti
                    if (filteredItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 34),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.event_busy_rounded,
                                size: 44,
                                color: AppColors.textSecondary(context)
                                    .withValues(alpha: 0.55)),
                            const SizedBox(height: 10),
                            Text(
                              'Belum ada data cuti${_selectedTahun != null ? ' untuk tahun $_selectedTahun' : ''}.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.manageAll
                                  ? 'Belum ada permohonan cuti sesuai filter saat ini.'
                                  : 'Belum ada data cuti yang diinput melalui web untuk periode ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final item in filteredItems) _buildCutiCard(item),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(CutiSummary s) {
    final progress = s.kuotaTahunan > 0
        ? (s.cutiTahunanTerpakai / s.kuotaTahunan).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.date_range_rounded,
                    color: _accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.manageAll
                          ? 'Rekap Cuti Pegawai (${_selectedTahun ?? 'Semua Tahun'})'
                          : 'Hak Cuti Tahunan ${s.tahun}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      widget.manageAll
                          ? '${s.totalPengajuan} pengajuan tercatat'
                          : 'Sisa ${s.sisaCutiTahunan} dari ${s.kuotaTahunan} hari kerja (terpakai ${s.cutiTahunanTerpakai} hari)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!widget.manageAll) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: _accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  s.sisaCutiTahunan <= 2
                      ? const Color(0xFFE67E22)
                      : _accent,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _statPill('Total', s.totalPengajuan, _navy),
              const SizedBox(width: 6),
              _statPill('Pending', s.pending, const Color(0xFFD97706)),
              const SizedBox(width: 6),
              _statPill('Disetujui', s.disetujui, const Color(0xFF16A34A)),
              const SizedBox(width: 6),
              _statPill('Ditolak', s.ditolak, const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestStatusCard(PengajuanCuti latest) {
    final isApproved = latest.status == StatusCuti.disetujui;
    final isRejected = latest.status == StatusCuti.ditolak;
    final borderColor = isApproved
        ? const Color(0xFF86EFAC)
        : (isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D));
    final badgeBg = isApproved
        ? const Color(0xFFDCFCE7)
        : (isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    final badgeText = isApproved
        ? const Color(0xFF15803D)
        : (isRejected ? const Color(0xFFB91C1C) : const Color(0xFFB45309));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isApproved
                      ? Icons.check_circle_outline_rounded
                      : (isRejected
                          ? Icons.cancel_outlined
                          : Icons.schedule_rounded),
                  color: badgeText,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS PENGAJUAN TERKINI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${latest.jenis} — ${latest.jumlahHari} Hari Kerja',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  latest.status.displayLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatTanggalIndonesia(latest.tanggalMulai)} s/d ${formatTanggalIndonesia(latest.tanggalSelesai)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          if (isApproved) ...[
            Text(
              'Surat Keputusan Izin Cuti Resmi No: ${latest.noSurat} telah diterbitkan oleh Bagian SDM.',
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
            if (latest.catatanApprover != null) ...[
              const SizedBox(height: 4),
              Text(
                'Catatan Approver: "${latest.catatanApprover}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _bukaSurat(latest),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Cetak Surat Izin Cuti Resmi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else if (latest.status == StatusCuti.menunggu) ...[
            Text(
              'Permohonan cuti Anda telah diterima oleh sistem dan sedang menunggu pemeriksaan Pejabat Bagian SDM.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
                height: 1.35,
              ),
            ),
          ] else ...[
            Text(
              'Pengajuan tidak disetujui. Alasan: "${latest.catatanApprover ?? 'Pertimbangan operasional kedinasan.'}"',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterSection(List<int?> years, int visibleCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.manageAll) ...[
            TextField(
              controller: _searchC,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cari nama pegawai, NIK, unit kerja, atau no. surat...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchC.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tahun:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int?>(
                      value: _selectedTahun,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      items: years
                          .map(
                            (y) => DropdownMenuItem<int?>(
                              value: y,
                              child: Text(
                                y == null ? 'Semua Tahun' : '$y',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedTahun = val);
                        _refresh();
                      },
                    ),
                  ],
                ),
                Text(
                  'Ditampilkan: $visibleCount',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'Semua Status'),
                  ('PENDING', 'Pending'),
                  ('DISETUJUI', 'Disetujui'),
                  ('DITOLAK', 'Ditolak'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(entry.$2,
                          style: const TextStyle(fontSize: 11.5)),
                      selected: _statusFilter == entry.$1,
                      selectedColor: _accent.withValues(alpha: 0.18),
                      onSelected: (_) {
                        if (_statusFilter == entry.$1) return;
                        setState(() => _statusFilter = entry.$1);
                        _refresh();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCutiCard(PengajuanCuti c) {
    final isApproved = c.status == StatusCuti.disetujui;
    final isRejected = c.status == StatusCuti.ditolak;
    final statusColor = isApproved
        ? const Color(0xFF16A34A)
        : (isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.manageAll) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: _accent.withValues(alpha: 0.14),
                  child: Text(
                    c.namaPegawai.isNotEmpty
                        ? c.namaPegawai[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.namaPegawai,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'NIK ${c.nik} • ${c.unitKerja}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: c.status.label, color: statusColor),
              ],
            ),
            const Divider(height: 18),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.event_note_rounded, size: 18, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.jenis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
                ),
                StatusBadge(label: c.status.label, color: statusColor),
              ],
            ),
            const SizedBox(height: 4),
          ],

          if (widget.manageAll)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                c.jenis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ),

          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.noSurat,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ),
              Text(
                '${c.jumlahHari} hari kerja',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatTanggalIndonesia(c.tanggalMulai)} s/d ${formatTanggalIndonesia(c.tanggalSelesai)}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            c.alasan,
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
          if (c.alamatCuti.isNotEmpty && c.alamatCuti != '-') ...[
            const SizedBox(height: 4),
            Text(
              'Lokasi Cuti: ${c.alamatCuti} • Telp: ${c.noTelp}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
          if (c.catatanApprover != null || c.diputuskanOleh != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${c.catatanApprover ?? 'Keputusan diproses'}${c.diputuskanOleh != null ? ' — Oleh: ${c.diputuskanOleh}' : ''}',
                style: TextStyle(fontSize: 11.5, color: statusColor),
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Tombol Cetak / Lihat Surat Cuti + Tombol Verifikasi/Edit untuk Approver
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _bukaSurat(c),
                icon: const Icon(Icons.description_outlined, size: 15),
                label: Text(
                  isApproved ? 'Cetak Surat Cuti' : 'Pratinjau Surat',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              if (widget.manageAll) ...[
                if (c.status == StatusCuti.menunggu) ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        _bukaVerifikasi(c, initial: StatusCuti.disetujui),
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Setujui',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _bukaVerifikasi(c, initial: StatusCuti.ditolak),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('Tolak',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () => _bukaVerifikasi(c),
                    icon: const Icon(Icons.edit_note_rounded, size: 15),
                    label: const Text('Edit Status',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal Verifikasi / Edit Status Cuti (SDM / Direktur) selaras dengan
/// `modalVerifikasiCuti` di website (`cuti/index.blade.php`).
class VerifikasiCutiSheet extends StatefulWidget {
  final PengajuanCuti pengajuan;
  final AppUser approver;
  final StatusCuti initialDecision;

  const VerifikasiCutiSheet({
    super.key,
    required this.pengajuan,
    required this.approver,
    required this.initialDecision,
  });

  @override
  State<VerifikasiCutiSheet> createState() => _VerifikasiCutiSheetState();
}

class _VerifikasiCutiSheetState extends State<VerifikasiCutiSheet> {
  late StatusCuti _decision;
  late final TextEditingController _catatanC;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decision = widget.initialDecision;
    _catatanC =
        TextEditingController(text: widget.pengajuan.catatanApprover ?? '');
  }

  @override
  void dispose() {
    _catatanC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CutiService.putuskan(
        pengajuan: widget.pengajuan,
        keputusan: _decision,
        namaApprover: widget.approver.name,
        catatan: _catatanC.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isApprove = _decision == StatusCuti.disetujui;
    final btnColor =
        isApprove ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2230) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Verifikasi Keputusan Cuti',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
              ),
              Text(
                'Bagian Sumber Daya Manusia / Direksi',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pengajuan.namaPegawai,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      '${widget.pengajuan.jenis} • ${widget.pengajuan.jumlahHari} hari kerja',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Keputusan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('✓ Setujui'),
                      selected: isApprove,
                      selectedColor:
                          const Color(0xFF16A34A).withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _decision = StatusCuti.disetujui),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('✕ Tolak'),
                      selected: !isApprove,
                      selectedColor:
                          const Color(0xFFDC2626).withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _decision = StatusCuti.ditolak),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _catatanC,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Catatan Approver / Alasan',
                  hintText: isApprove
                      ? 'Disetujui sesuai hak cuti tahunan kedinasan...'
                      : 'Tuliskan alasan kedinasan penolakan cuti...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isApprove
                              ? 'Setujui & Kirim Notifikasi'
                              : 'Tolak & Kirim Notifikasi',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
