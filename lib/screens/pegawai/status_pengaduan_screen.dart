import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import '../shared/detail_pengaduan_screen.dart';
import '../shared/riwayat_pengaduan_screen.dart';
import '../../theme/app_colors.dart';

class StatusPengaduanScreen extends StatefulWidget {
  final AppUser user;
  final bool showBackButton;
  const StatusPengaduanScreen({
    super.key,
    required this.user,
    this.showBackButton = true,
  });

  @override
  State<StatusPengaduanScreen> createState() => _StatusPengaduanScreenState();
}

class _StatusPengaduanScreenState extends State<StatusPengaduanScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color navyDark = Color(0xFF0A2257);
  static const Color accent = Color(0xFF2E86AB);
  Color get labelDark => AppColors.textPrimary(context);
  Color get hintGrey => AppColors.textSecondary(context);

  final _searchController = TextEditingController();
  String _query = '';

  Set<PengaduanStatus> _filterStatus = {};
  String? _filterCabang;
  DateTimeRange? _filterTanggal;

  /// ID pengaduan yang riwayatnya sedang ditampilkan (expand) di kartu.
  final Set<int> _riwayatTerbuka = {};

  /// Cache riwayat status per pengaduan supaya tidak fetch ulang setiap
  /// kali kartu di-expand/collapse.
  final Map<int, Future<Pengaduan?>> _riwayatCache = {};

  late Future<List<Pengaduan>> _pengaduanFuture;

  @override
  void initState() {
    super.initState();
    _pengaduanFuture =
        PengaduanService.punyaSayaSebagaiObjek(nik: widget.user.nik);
  }

  Future<void> _refresh() async {
    setState(() {
      _pengaduanFuture =
          PengaduanService.punyaSayaSebagaiObjek(nik: widget.user.nik);
    });
    await _pengaduanFuture;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Pengaduan> _filter(List<Pengaduan> semua) {
    return semua.where((p) {
      final q = _query.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          p.nomorPengaduan.toLowerCase().contains(q) ||
          p.judul.toLowerCase().contains(q) ||
          p.kategori.toLowerCase().contains(q);

      final matchStatus =
          _filterStatus.isEmpty || _filterStatus.contains(p.status);

      final matchCabang = _filterCabang == null || p.cabang == _filterCabang;

      final matchTanggal = _filterTanggal == null ||
          (!p.tanggalPengaduan.isBefore(_filterTanggal!.start) &&
              !p.tanggalPengaduan
                  .isAfter(_filterTanggal!.end.add(const Duration(days: 1))));

      return matchQuery && matchStatus && matchCabang && matchTanggal;
    }).toList()
      ..sort((a, b) => b.tanggalPengaduan.compareTo(a.tanggalPengaduan));
  }

  List<String> _daftarCabang(List<Pengaduan> semua) {
    final set = semua.map((p) => p.cabang).toSet();
    return set.toList()..sort();
  }

  bool get _adaFilterAktif =>
      _filterStatus.isNotEmpty ||
      _filterCabang != null ||
      _filterTanggal != null;

  Future<void> _openFilterSheet(List<Pengaduan> semua) async {
    var tempStatus = {..._filterStatus};
    var tempCabang = _filterCabang;
    var tempTanggal = _filterTanggal;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isSmallScreen = MediaQuery.of(context).size.width < 400;
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: isSmallScreen ? 16.0 : 20.0,
                    right: isSmallScreen ? 16.0 : 20.0,
                    top: 10,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E4E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter Pengaduan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: navy,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempStatus = {};
                                tempCabang = null;
                                tempTanggal = null;
                              });
                            },
                            child: Text('Reset',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: hintGrey,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Status',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: labelDark)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: PengaduanStatus.values.map((s) {
                          final selected = tempStatus.contains(s);
                          return FilterChip(
                            label: Text(s.label,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10.5 : 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : s.color,
                                )),
                            selected: selected,
                            onSelected: (v) {
                              setSheetState(() {
                                if (v) {
                                  tempStatus.add(s);
                                } else {
                                  tempStatus.remove(s);
                                }
                              });
                            },
                            selectedColor: s.color,
                            backgroundColor: s.color.withValues(alpha: 0.1),
                            checkmarkColor: Colors.white,
                            side: BorderSide(
                                color: s.color.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Text('Cabang',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: labelDark)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _daftarCabang(semua).map((c) {
                          final selected = tempCabang == c;
                          return ChoiceChip(
                            label: Text(c,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10.5 : 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : labelDark,
                                )),
                            selected: selected,
                            onSelected: (v) {
                              setSheetState(() {
                                tempCabang = v ? c : null;
                              });
                            },
                            selectedColor: accent,
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF10151C)
                                    : const Color(0xFFF3F6F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      Text('Rentang Tanggal',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: labelDark)),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final now = DateTime.now();
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 2),
                            lastDate: DateTime(now.year + 1),
                            initialDateRange: tempTanggal,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: accent,
                                    onPrimary: Colors.white,
                                    onSurface: labelDark,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (range != null) {
                            setSheetState(() => tempTanggal = range);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.pageBackground(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range_rounded,
                                  size: 18, color: accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tempTanggal == null
                                      ? 'Pilih rentang tanggal'
                                      : '${formatTanggalIndonesia(tempTanggal!.start)}  —  ${formatTanggalIndonesia(tempTanggal!.end)}',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 11.0 : 12.0,
                                    fontWeight: FontWeight.w600,
                                    color: tempTanggal == null
                                        ? hintGrey
                                        : labelDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _filterStatus = tempStatus;
                              _filterCabang = tempCabang;
                              _filterTanggal = tempTanggal;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Terapkan Filter',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF10151C)
          : const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<List<Pengaduan>>(
        future: _pengaduanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(isSmallScreen)),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(isSmallScreen)),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Gagal memuat pengaduan: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: hintGrey, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final semua = snapshot.data ?? [];
          final items = _filter(semua);

          return RefreshIndicator(
            color: accent,
            onRefresh: _refresh,
            child: CustomScrollView(
              // Header & ringkasan ikut scroll bersama konten (tidak sticky),
              // sesuai permintaan — cukup taruh di dalam CustomScrollView
              // sebagai sliver biasa, bukan lagi Column tetap di luar list.
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(isSmallScreen)),
                SliverToBoxAdapter(
                  child: _buildRingkasanBar(items.length, semua, isSmallScreen),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      message: _adaFilterAktif
                          ? 'Tidak ada pengaduan yang cocok dengan filter ini.'
                          : 'Belum ada pengaduan yang cocok dengan pencarian.',
                      icon: Icons.fact_check_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isSmallScreen ? 16.0 : 20.0,
                      4,
                      isSmallScreen ? 16.0 : 20.0,
                      24,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index.isOdd) {
                            return const SizedBox(height: 12);
                          }
                          final itemIndex = index ~/ 2;
                          return _buildPengaduanCard(
                              items[itemIndex], isSmallScreen);
                        },
                        childCount: items.isEmpty ? 0 : items.length * 2 - 1,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRingkasanBar(
      int jumlah, List<Pengaduan> semua, bool isSmallScreen) {
    return Container(
      color: AppColors.pageBackground(context),
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 16 : 20,
        _adaFilterAktif ? 8 : 14,
      ),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: isSmallScreen ? 42 : 46,
                  height: isSmallScreen ? 42 : 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.16),
                        accent.withValues(alpha: 0.07),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$jumlah pengaduan',
                        style: TextStyle(
                          color: labelDark,
                          fontSize: isSmallScreen ? 14 : 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _adaFilterAktif
                            ? 'Hasil berdasarkan filter aktif'
                            : 'Ditemukan pada riwayatmu',
                        style: TextStyle(
                          color: hintGrey,
                          fontSize: isSmallScreen ? 10.5 : 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_adaFilterAktif)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _filterStatus = {};
                      _filterCabang = null;
                      _filterTanggal = null;
                    }),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (_adaFilterAktif) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.divider(context)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _filterStatus)
                      _buildFilterChipAktif(
                        label: s.label,
                        color: s.color,
                        onRemove: () =>
                            setState(() => _filterStatus.remove(s)),
                      ),
                    if (_filterCabang != null)
                      _buildFilterChipAktif(
                        label: _filterCabang!,
                        color: accent,
                        onRemove: () =>
                            setState(() => _filterCabang = null),
                      ),
                    if (_filterTanggal != null)
                      _buildFilterChipAktif(
                        label:
                            '${formatTanggalIndonesia(_filterTanggal!.start)} — ${formatTanggalIndonesia(_filterTanggal!.end)}',
                        color: navy,
                        onRemove: () =>
                            setState(() => _filterTanggal = null),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipAktif({
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    Widget actionButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      bool active = false,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: isSmallScreen ? 40 : 44,
              height: isSmallScreen ? 40 : 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? accent
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isSmallScreen ? 19 : 21,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 16 : 20,
        MediaQuery.of(context).padding.top + (isSmallScreen ? 10 : 14),
        isSmallScreen ? 16 : 20,
        isSmallScreen ? 18 : 22,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            navy,
            navy.withValues(alpha: 0.88),
            const Color(0xFF123A85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.showBackButton) ...[
                actionButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Kembali',
                  onTap: () => Navigator.maybePop(context),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.water_drop_rounded,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'PERUMDAM TIRTA DARMA AYU',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: isSmallScreen ? 8 : 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              actionButton(
                icon: Icons.history_rounded,
                tooltip: 'Riwayat Pengaduan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RiwayatPengaduanScreen(user: widget.user),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 20 : 24),
          Text(
            'Status Pengaduan',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 25 : 29,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Pantau perkembangan dan riwayat pengaduanmu',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: isSmallScreen ? 11.5 : 13,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: isSmallScreen ? 18 : 22),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: isSmallScreen ? 46 : 50,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.09),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: hintGrey, size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _query = value),
                          style: TextStyle(
                            color: labelDark,
                            fontSize: isSmallScreen ? 12.5 : 13.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari nomor, judul, atau kategori',
                            hintStyle: TextStyle(
                              color: hintGrey,
                              fontSize: isSmallScreen ? 11.5 : 12.5,
                            ),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        InkWell(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: hintGrey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              actionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Muat ulang',
                onTap: () async {
                  await _refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Status pengaduan dimuat ulang.'),
                        backgroundColor: accent,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 9),
              FutureBuilder<List<Pengaduan>>(
                future: _pengaduanFuture,
                builder: (context, snapshot) {
                  return actionButton(
                    icon: Icons.tune_rounded,
                    tooltip: 'Filter pengaduan',
                    active: _adaFilterAktif,
                    onTap: () =>
                        _openFilterSheet(snapshot.data ?? const <Pengaduan>[]),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ringkasan riwayat status pengaduan (timeline sederhana) yang
  /// ditampilkan inline di kartu Status Pengaduan pelapor — supaya
  /// pelapor bisa melihat perjalanan pengaduannya tanpa perlu membuka
  /// halaman detail.
  Widget _buildRiwayatRingkas(
      List<StatusHistoryEntry> riwayat, bool isSmallScreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < riwayat.length; i++)
            Padding(
              padding:
                  EdgeInsets.only(bottom: i == riwayat.length - 1 ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: riwayat[i].status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i != riwayat.length - 1)
                        Container(
                          width: 2,
                          height: 34,
                          color: AppColors.divider(context),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          riwayat[i].aksi,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: labelDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${riwayat[i].oleh} · ${formatTanggalJam(riwayat[i].tanggal)}',
                          style: TextStyle(fontSize: 10.5, color: hintGrey),
                        ),
                        if ((riwayat[i].keterangan ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            riwayat[i].keterangan!.trim(),
                            style: TextStyle(
                                fontSize: 11, color: labelDark, height: 1.3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForKategori(String kategori) {
    final k = kategori.toLowerCase();
    if (k.contains('fasilitas')) return Icons.build_circle_rounded;
    if (k.contains('rekan')) return Icons.groups_rounded;
    if (k.contains('atasan')) return Icons.supervisor_account_rounded;
    if (k.contains('gaji') ||
        k.contains('tunjangan') ||
        k.contains('insentif')) {
      return Icons.payments_rounded;
    }
    if (k.contains('kekerasan') || k.contains('pelecehan')) {
      return Icons.shield_rounded;
    }
    if (k.contains('disiplin')) return Icons.gavel_rounded;
    if (k.contains('lingkungan')) return Icons.eco_rounded;
    return Icons.report_gmailerrorred_rounded;
  }

  Widget _buildPengaduanCard(Pengaduan p, bool isSmallScreen) {
    final int? id = p.supabaseId;
    final bool riwayatTerbuka = id != null && _riwayatTerbuka.contains(id);

    void bukaDetail() {
      if (id == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PengaduanDetailScreen(
            user: widget.user,
            pengaduanId: id,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    p.status.color,
                    p.status.color.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: bukaDetail,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isSmallScreen ? 14 : 17,
                  isSmallScreen ? 14 : 17,
                  isSmallScreen ? 14 : 17,
                  13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: p.status.color.withValues(alpha: 0.11),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: p.status.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                p.status.label,
                                style: TextStyle(
                                  color: p.status.color,
                                  fontSize: isSmallScreen ? 10.5 : 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            p.nomorPengaduan,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: hintGrey,
                              fontSize: isSmallScreen ? 9.5 : 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isSmallScreen ? 46 : 50,
                          height: isSmallScreen ? 46 : 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.status.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _iconForKategori(p.kategori),
                            color: p.status.color,
                            size: isSmallScreen ? 21 : 23,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.judul,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: labelDark,
                                  fontSize: isSmallScreen ? 15 : 16.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  p.kategori,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: isSmallScreen ? 10 : 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted(context),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                            color: hintGrey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formatTanggalIndonesia(p.tanggalPengaduan),
                              style: TextStyle(
                                color: hintGrey,
                                fontSize: isSmallScreen ? 10.5 : 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.divider(context)),
            InkWell(
              onTap: () {
                if (id == null) return;
                setState(() {
                  if (riwayatTerbuka) {
                    _riwayatTerbuka.remove(id);
                  } else {
                    _riwayatTerbuka.add(id);
                    _riwayatCache.putIfAbsent(
                      id,
                      () => PengaduanService.detailLengkap(id),
                    );
                  }
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 14 : 17,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: accent,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        riwayatTerbuka
                            ? 'Sembunyikan riwayat'
                            : 'Lihat riwayat pengaduan',
                        style: TextStyle(
                          color: accent,
                          fontSize: isSmallScreen ? 11.5 : 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: riwayatTerbuka ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: id != null && riwayatTerbuka
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(
                        isSmallScreen ? 14 : 17,
                        0,
                        isSmallScreen ? 14 : 17,
                        14,
                      ),
                      child: FutureBuilder<Pengaduan?>(
                        future: _riwayatCache[id],
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Gagal memuat riwayat: ${snapshot.error}',
                                style: TextStyle(
                                  color: hintGrey,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }
                          final riwayat =
                              snapshot.data?.riwayatStatus ?? const [];
                          if (riwayat.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Belum ada riwayat status.',
                                style: TextStyle(
                                  color: hintGrey,
                                  fontSize: 11.5,
                                ),
                              ),
                            );
                          }
                          return _buildRiwayatRingkas(
                            riwayat,
                            isSmallScreen,
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 14 : 17,
                0,
                isSmallScreen ? 14 : 17,
                isSmallScreen ? 14 : 17,
              ),
              child: SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 43 : 47,
                child: ElevatedButton.icon(
                  onPressed: bukaDetail,
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('Lihat Detail'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: navy,
                    elevation: 0,
                    textStyle: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
