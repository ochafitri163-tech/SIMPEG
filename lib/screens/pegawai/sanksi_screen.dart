import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/feature_scaffold.dart';

class _SanksiRow {
  final String jenisSanksi;
  final String tanggal;
  final String keterangan;
  final String status;

  const _SanksiRow({
    required this.jenisSanksi,
    required this.tanggal,
    required this.keterangan,
    required this.status,
  });

  factory _SanksiRow.fromMap(Map<String, dynamic> row) {
    return _SanksiRow(
      jenisSanksi: (row['jenis_sanksi'] ?? 'Sanksi Disiplin') as String,
      tanggal: (row['tanggal'] ?? '-') as String,
      keterangan: (row['keterangan'] ?? '-') as String,
      status: (row['status'] ?? 'Aktif') as String,
    );
  }
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

class SanksiScreen extends StatefulWidget {
  const SanksiScreen({super.key});

  @override
  State<SanksiScreen> createState() => _SanksiScreenState();
}

class _SanksiScreenState extends State<SanksiScreen> {
  late Future<List<_SanksiRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSanksi();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchSanksi());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Riwayat Sanksi',
      subtitle: 'Catatan sanksi/disiplin pegawai',
      icon: Icons.gavel_rounded,
      child: FutureBuilder<List<_SanksiRow>>(
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
              onRefresh: _refresh,
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
            onRefresh: _refresh,
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
                            StatusBadge.auto(item.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InfoRow(label: 'Tanggal', value: item.tanggal),
                        const SizedBox(height: 6),
                        Text(
                          item.keterangan,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF7F8C8D),
                          ),
                        ),
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
