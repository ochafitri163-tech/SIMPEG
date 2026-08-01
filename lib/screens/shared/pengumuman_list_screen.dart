import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/pengumuman_model.dart';
import '../../widgets/feature_scaffold.dart';
import '../../widgets/pengumuman_card.dart';

/// Halaman riwayat "Berita Pengumuman" — dapat diakses seluruh role
/// (Pegawai, Kadiv, KSPI, TPDPK, Direktur). Read-only: menampilkan
/// seluruh pengumuman, mendukung pencarian berdasarkan judul, urut
/// tanggal terbaru, dan tombol Lihat Detail (pop-up) pada tiap item.
class PengumumanListScreen extends StatefulWidget {
  const PengumumanListScreen({super.key});

  @override
  State<PengumumanListScreen> createState() => _PengumumanListScreenState();
}

class _PengumumanListScreenState extends State<PengumumanListScreen> {
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengumuman>> _future;
  final TextEditingController _cariController = TextEditingController();
  String _kueri = '';

  @override
  void initState() {
    super.initState();
    _future = PengumumanService.semua();
  }

  @override
  void dispose() {
    _cariController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = PengumumanService.semua());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FeatureScaffold(
      title: 'Berita Pengumuman',
      subtitle: 'Riwayat seluruh pengumuman PERUMDAM Tirta Darma Ayu',
      icon: Icons.campaign_rounded,
      child: Column(
        children: [
          // Kolom pencarian berdasarkan judul.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: TextField(
              controller: _cariController,
              onChanged: (v) => setState(() => _kueri = v.trim().toLowerCase()),
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
            child: FutureBuilder<List<Pengumuman>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Gagal memuat pengumuman:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  );
                }

                final semua = snapshot.data ?? const <Pengumuman>[];
                // Sudah terurut tanggal terbaru dari service; filter judul.
                final items = _kueri.isEmpty
                    ? semua
                    : semua
                        .where((p) => p.judul.toLowerCase().contains(_kueri))
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
                    itemBuilder: (context, i) =>
                        _buildItem(context, items[i], isDark),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, Pengumuman p, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2230) : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                const Icon(Icons.campaign_rounded,
                    size: 16, color: Color(0xFFD35400)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1B2733),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(p.aktif),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.ringkasan,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? const Color(0xFF9AA6B2) : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF9AA6B2) : Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    formatTanggalJam(p.tanggalPublikasi),
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? const Color(0xFF9AA6B2) : Colors.grey[600],
                    ),
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => showPengumumanDetail(context, p),
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
      child: Text(
        aktif ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
