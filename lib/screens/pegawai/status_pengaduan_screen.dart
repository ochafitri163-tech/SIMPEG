import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../widgets/feature_scaffold.dart';
import '../shared/detail_pengaduan_screen.dart';

/// Halaman "Status Pengaduan" — menampilkan riwayat seluruh pengaduan
/// milik pegawai yang sedang login (query difilter pelapor_id = user
/// yang login, BUKAN semua pengaduan seperti versi lama yang memakai
/// PengaduanRepository.semua), lengkap dengan pencarian & filter.
class StatusPengaduanScreen extends StatefulWidget {
  final bool showBackButton;
  const StatusPengaduanScreen({super.key, this.showBackButton = true});

  @override
  State<StatusPengaduanScreen> createState() => _StatusPengaduanScreenState();
}

class _StatusPengaduanScreenState extends State<StatusPengaduanScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color navyDark = Color(0xFF0A2257);
  static const Color accent = Color(0xFF2E86AB);
  static const Color labelDark = Color(0xFF1B2733);
  static const Color hintGrey = Color(0xFF9AA5B1);

  final _searchController = TextEditingController();
  String _query = '';

  Set<PengaduanStatus> _filterStatus = {};
  String? _filterCabang;
  DateTimeRange? _filterTanggal;

  late Future<List<Pengaduan>> _pengaduanFuture;

  @override
  void initState() {
    super.initState();
    _pengaduanFuture = PengaduanService.punyaSayaSebagaiObjek();
  }

  Future<void> _refresh() async {
    setState(() {
      _pengaduanFuture = PengaduanService.punyaSayaSebagaiObjek();
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
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
                          child: const Text('Reset',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: hintGrey,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Status',
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
                                fontSize: 11.5,
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
                          backgroundColor: s.color.withOpacity(0.1),
                          checkmarkColor: Colors.white,
                          side: BorderSide(color: s.color.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text('Cabang',
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
                                fontSize: 11.5,
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
                          backgroundColor: const Color(0xFFF3F6F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    const Text('Rentang Tanggal',
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
                                colorScheme: const ColorScheme.light(
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
                          color: const Color(0xFFF3F6F9),
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
                                  fontSize: 12,
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<List<Pengaduan>>(
        future: _pengaduanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Gagal memuat pengaduan: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: hintGrey, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final semua = snapshot.data ?? [];
          final items = _filter(semua);

          return Column(
            children: [
              _buildHeader(),
              _buildRingkasanBar(items.length, semua),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        message: _adaFilterAktif
                            ? 'Tidak ada pengaduan yang cocok dengan filter ini.'
                            : 'Belum ada pengaduan yang cocok dengan pencarian.',
                        icon: Icons.fact_check_outlined,
                      )
                    : RefreshIndicator(
                        color: accent,
                        onRefresh: _refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _buildPengaduanCard(items[index]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRingkasanBar(int jumlah, List<Pengaduan> semua) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F6F9),
      padding: EdgeInsets.fromLTRB(20, 14, 20, _adaFilterAktif ? 4 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_rounded, size: 14, color: hintGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$jumlah pengaduan ditemukan',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hintGrey,
                  ),
                ),
              ),
              if (_adaFilterAktif)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() {
                    _filterStatus = {};
                    _filterCabang = null;
                    _filterTanggal = null;
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      'Hapus semua filter',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_adaFilterAktif) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _filterStatus)
                  _buildFilterChipAktif(
                    label: s.label,
                    color: s.color,
                    onRemove: () => setState(() => _filterStatus.remove(s)),
                  ),
                if (_filterCabang != null)
                  _buildFilterChipAktif(
                    label: _filterCabang!,
                    color: accent,
                    onRemove: () => setState(() => _filterCabang = null),
                  ),
                if (_filterTanggal != null)
                  _buildFilterChipAktif(
                    label:
                        '${formatTanggalIndonesia(_filterTanggal!.start)} — ${formatTanggalIndonesia(_filterTanggal!.end)}',
                    color: navy,
                    onRemove: () => setState(() => _filterTanggal = null),
                  ),
              ],
            ),
          ],
        ],
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [navy, navy.withOpacity(0.85), const Color(0xFF123A85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        size: 11, color: Colors.white70),
                    const SizedBox(width: 5),
                    Text(
                      'PERUMDAM TIRTA DARMA AYU',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.showBackButton) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              const Expanded(
                child: Text(
                  'Status Pengaduan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(left: widget.showBackButton ? 50 : 0),
            child: const Text(
              'Riwayat seluruh pengaduan yang pernah kamu buat',
              style: TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: hintGrey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _query = v),
                          style:
                              const TextStyle(fontSize: 13, color: labelDark),
                          decoration: const InputDecoration(
                            hintText: 'Cari nomor / judul pengaduan',
                            hintStyle:
                                TextStyle(fontSize: 12.5, color: hintGrey),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FutureBuilder<List<Pengaduan>>(
                future: _pengaduanFuture,
                builder: (context, snapshot) {
                  final semua = snapshot.data ?? [];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openFilterSheet(semua),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _adaFilterAktif ? accent : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: _adaFilterAktif ? Colors.white : navy,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ],
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

  Widget _buildPengaduanCard(Pengaduan p) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailPengaduanScreen(pengaduan: p),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: p.status.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                _iconForKategori(p.kategori),
                                size: 18,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.nomorPengaduan,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: hintGrey,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    p.judul,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: labelDark,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    p.kategori,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: accent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 13, color: hintGrey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                formatTanggalIndonesia(p.tanggalPengaduan),
                                style: const TextStyle(
                                    fontSize: 11.5, color: hintGrey),
                              ),
                            ),
                            StatusBadge(
                                label: p.status.label, color: p.status.color),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DetailPengaduanScreen(pengaduan: p),
                                ),
                              );
                            },
                            icon:
                                const Icon(Icons.visibility_outlined, size: 16),
                            label: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Lihat Detail',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, size: 16),
                              ],
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: navy,
                              backgroundColor: navy.withOpacity(0.06),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
