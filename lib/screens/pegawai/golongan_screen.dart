import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/feature_scaffold.dart';

/// Model ringan untuk satu baris riwayat golongan, dipetakan langsung
/// dari row Supabase (menggantikan GolonganItem dari pegawai_data.dart
/// untuk kebutuhan halaman ini).
class _GolonganRow {
  final String golongan;
  final String pangkat;
  final String tmt;
  final String noSk;

  const _GolonganRow({
    required this.golongan,
    required this.pangkat,
    required this.tmt,
    required this.noSk,
  });

  factory _GolonganRow.fromMap(Map<String, dynamic> row) {
    return _GolonganRow(
      golongan: row['golongan'] as String,
      pangkat: row['pangkat'] as String,
      tmt: row['tmt'] as String,
      noSk: row['no_sk'] as String,
    );
  }
}

Future<List<_GolonganRow>> _fetchRiwayatGolongan() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await Supabase.instance.client
      .from('riwayat_golongan')
      .select()
      .eq('pegawai_id', userId)
      .order('tmt', ascending: false);

  return (rows as List)
      .map((r) => _GolonganRow.fromMap(r as Map<String, dynamic>))
      .toList();
}

/// Halaman "Riwayat Golongan" — menampilkan riwayat kenaikan
/// golongan/pangkat pegawai yang sedang login, diambil dari Supabase.
class GolonganScreen extends StatefulWidget {
  const GolonganScreen({super.key});

  @override
  State<GolonganScreen> createState() => _GolonganScreenState();
}

class _GolonganScreenState extends State<GolonganScreen> {
  late Future<List<_GolonganRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchRiwayatGolongan();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchRiwayatGolongan());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Riwayat Golongan',
      subtitle: 'Riwayat kenaikan golongan/pangkat',
      icon: Icons.military_tech_rounded,
      child: FutureBuilder<List<_GolonganRow>>(
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
                  'Gagal memuat riwayat golongan: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            );
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  EmptyState(message: 'Belum ada data golongan'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                final isLatest = index == 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCE6EF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.military_tech_rounded,
                                  color: Color(0xFFC2185B), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Golongan ${item.golongan}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: FeatureScaffold.navy,
                                ),
                              ),
                            ),
                            if (isLatest)
                              const StatusBadge(
                                  label: 'Saat Ini', color: Color(0xFF27AE60)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        InfoRow(label: 'Pangkat', value: item.pangkat),
                        InfoRow(label: 'TMT', value: item.tmt),
                        InfoRow(label: 'No. SK', value: item.noSk),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
