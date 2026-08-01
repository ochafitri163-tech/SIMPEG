import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/pengumuman_model.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import '../../widgets/pengumuman_card.dart';

/// Halaman riwayat "Berita Pengumuman" — dapat diakses seluruh role
/// (Pegawai, Kadiv, KSPI, TPDPK, Direktur). Menampilkan pengumuman yang
/// ditujukan untuk role tersebut, mendukung pencarian judul, urut tanggal
/// terbaru, penanda "Baru" (belum dibaca), status, dan Lihat Detail.
class PengumumanListScreen extends StatefulWidget {
  final UserRole role;
  const PengumumanListScreen({super.key, required this.role});

  @override
  State<PengumumanListScreen> createState() => _PengumumanListScreenState();
}

class _PengumumanListScreenState extends State<PengumumanListScreen> {
  static const Color _accent = Color(0xFF2E86AB);

  late Future<_DataRiwayat> _future;
  final TextEditingController _cariController = TextEditingController();
  String _kueri = '';

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  @override
  void dispose() {
    _cariController.dispose();
    super.dispose();
  }

  Future<_DataRiwayat> _muat() async {
    final semua = await PengumumanService.semua();
    final dibaca = await PengumumanService.idSudahDibaca();
    final terlihat =
        semua.where((p) => p.untukRole(widget.role)).toList();
    return _DataRiwayat(items: terlihat, dibaca: dibaca);
  }

  Future<void> _refresh() async {
    setState(() => _future = _muat());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FeatureScaffold(
      title: 'Berita Pengumuman',
      subtitle: 'Riwayat pengumuman PERUMDAM Tirta Darma Ayu',
      icon: Icons.campaign_rounded,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              controller: _cariController,
              onChanged: (v) =>
                  setState(() => _kueri = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan judul…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _kueri.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _cariController.clear();
                          setState(() => _kueri = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF1B2230) : Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _accent, width: 1.4),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<_DataRiwayat>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Gagal memuat pengumuman:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ),
                  );
                }

                final data = snapshot.data ??
                    _DataRiwayat(items: const [], dibaca: const {});
                final items = _kueri.isEmpty
                    ? data.items
                    : data.items
                        .where((p) =>
                            p.judul.toLowerCase().contains(_kueri))
                        .toList();

                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        EmptyState(
                          icon: Icons.campaign_outlined,
                          message: _kueri.isEmpty
                              ? 'Belum ada pengumuman.'
                              : 'Tidak ada pengumuman berjudul "$_kueri".',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return _buildItem(
                          context, p, isDark, !data.dibaca.contains(p.id));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
      BuildContext context, Pengumuman p, bool isDark, bool belumDibaca) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2230) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: belumDibaca
            ? Border.all(color: const Color(0xFF2E86AB), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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
                if (p.disematkan)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.push_pin_rounded,
                        size: 15, color: Color(0xFFD35400)),
                  ),
                Icon(
                    p.isPenting
                        ? Icons.priority_high_rounded
                        : Icons.campaign_rounded,
                    size: 16,
                    color: p.isPenting
                        ? const Color(0xFFE74C3C)
                        : const Color(0xFFD35400)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1B2733))),
                ),
                const SizedBox(width: 8),
                if (belumDibaca)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E86AB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Baru',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                _statusBadge(p.sedangTayang),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.ringkasan,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark
                        ? const Color(0xFF9AA6B2)
                        : Colors.grey[700])),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF9AA6B2)
                        : Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(formatTanggalJam(p.tanggalPublikasi),
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF9AA6B2)
                              : Colors.grey[600])),
                ),
                if (p.adaLampiran)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.attach_file_rounded,
                        size: 14, color: Color(0xFF2E86AB)),
                  ),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await showPengumumanDetail(context, p);
                      _refresh();
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Lihat Detail',
                        style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _accent),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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

  Widget _statusBadge(bool aktif) {
    final color = aktif ? const Color(0xFF27AE60) : const Color(0xFF95A5A6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(aktif ? 'Aktif' : 'Nonaktif',
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _DataRiwayat {
  final List<Pengumuman> items;
  final Set<int> dibaca;
  const _DataRiwayat({required this.items, required this.dibaca});
}
