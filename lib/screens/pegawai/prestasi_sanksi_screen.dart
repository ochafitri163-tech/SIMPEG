import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/feature_scaffold.dart';

class _PrestasiRow {
  final String judul;
  final String tanggal;
  final String? keterangan;
  final String? tingkat;

  const _PrestasiRow({
    required this.judul,
    required this.tanggal,
    this.keterangan,
    this.tingkat,
  });

  factory _PrestasiRow.fromMap(Map<String, dynamic> row) {
    return _PrestasiRow(
      judul: row['judul'] as String,
      tanggal: row['tanggal'] as String,
      keterangan: row['keterangan'] as String?,
      tingkat: row['tingkat'] as String?,
    );
  }
}

class _SanksiRow {
  final String jenisSanksi;
  final String tanggal;
  final String keterangan;
  final String tingkat;

  const _SanksiRow({
    required this.jenisSanksi,
    required this.tanggal,
    required this.keterangan,
    required this.tingkat,
  });

  factory _SanksiRow.fromMap(Map<String, dynamic> row) {
    return _SanksiRow(
      jenisSanksi: row['jenis_sanksi'] as String,
      tanggal: row['tanggal'] as String,
      keterangan: (row['keterangan'] ?? '') as String,
      tingkat: (row['tingkat'] ?? '') as String,
    );
  }
}

Future<List<_PrestasiRow>> _fetchPrestasi() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await Supabase.instance.client
      .from('prestasi')
      .select()
      .eq('pegawai_id', userId)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => _PrestasiRow.fromMap(r as Map<String, dynamic>))
      .toList();
}

Future<List<_SanksiRow>> _fetchSanksi() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await Supabase.instance.client
      .from('sanksi')
      .select()
      .eq('pegawai_id', userId)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => _SanksiRow.fromMap(r as Map<String, dynamic>))
      .toList();
}

/// Halaman Prestasi & Sanksi — gabungan riwayat penghargaan/prestasi dan
/// catatan sanksi/disiplin pegawai yang sedang login, diambil dari
/// Supabase (tabel `prestasi` dan `sanksi`).
class PrestasiSanksiScreen extends StatefulWidget {
  const PrestasiSanksiScreen({super.key});

  @override
  State<PrestasiSanksiScreen> createState() => _PrestasiSanksiScreenState();
}

class _PrestasiSanksiScreenState extends State<PrestasiSanksiScreen> {
  int _tab = 0;
  late Future<List<_PrestasiRow>> _prestasiFuture;
  late Future<List<_SanksiRow>> _sanksiFuture;

  @override
  void initState() {
    super.initState();
    _prestasiFuture = _fetchPrestasi();
    _sanksiFuture = _fetchSanksi();
  }

  Future<void> _refreshPrestasi() async {
    setState(() => _prestasiFuture = _fetchPrestasi());
    await _prestasiFuture;
  }

  Future<void> _refreshSanksi() async {
    setState(() => _sanksiFuture = _fetchSanksi());
    await _sanksiFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Prestasi & Sanksi',
      subtitle: 'Riwayat penghargaan dan catatan disiplin',
      icon: Icons.workspace_premium_rounded,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentButton(
                    label: 'Prestasi',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SegmentButton(
                    label: 'Sanksi',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0 ? _buildPrestasi() : _buildSanksi(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrestasi() {
    return FutureBuilder<List<_PrestasiRow>>(
      future: _prestasiFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'Gagal memuat data prestasi: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          );
        }

        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshPrestasi,
            child: ListView(
              children: const [
                EmptyState(
                  message: 'Belum ada catatan prestasi/penghargaan',
                  icon: Icons.emoji_events_rounded,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshPrestasi,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.judul,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: FeatureScaffold.navy,
                              ),
                            ),
                          ),
                          if (item.tingkat != null)
                            StatusBadge.auto(item.tingkat!),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InfoRow(label: 'Tanggal', value: item.tanggal),
                      if (item.keterangan != null &&
                          item.keterangan!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.keterangan!,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF7F8C8D)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSanksi() {
    return FutureBuilder<List<_SanksiRow>>(
      future: _sanksiFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'Gagal memuat data sanksi: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          );
        }

        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshSanksi,
            child: ListView(
              children: const [
                EmptyState(
                  message: 'Alhamdulillah, tidak ada catatan sanksi',
                  icon: Icons.verified_rounded,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshSanksi,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.jenisSanksi,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: FeatureScaffold.navy,
                              ),
                            ),
                          ),
                          StatusBadge.auto(item.tingkat),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InfoRow(label: 'Tanggal', value: item.tanggal),
                      const SizedBox(height: 6),
                      Text(
                        item.keterangan,
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF7F8C8D)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FeatureScaffold.navy : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                selected ? null : Border.all(color: const Color(0xFFEDF1F5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF7F8C8D),
            ),
          ),
        ),
      ),
    );
  }
}
