import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

/// Model ringan untuk satu baris riwayat golongan, dipetakan langsung
/// dari database lokal via API Laravel.
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
      golongan: (row['golongan'] ?? row['pangkat'] ?? '-').toString(),
      pangkat: (row['pangkat'] ?? row['golongan'] ?? '-').toString(),
      tmt: (row['tmt'] ?? '-').toString(),
      noSk: (row['no_sk'] ?? row['nomor_sk'] ?? '-').toString(),
    );
  }
}

Future<List<_GolonganRow>> _fetchRiwayatGolongan(AppUser? user) async {
  try {
    final res = await ApiService.getProfile();
    if (res['success'] == true && res['data'] != null && res['data']['riwayat_golongan'] is List) {
      final list = res['data']['riwayat_golongan'] as List;
      return list.map((r) => _GolonganRow.fromMap(Map<String, dynamic>.from(r as Map))).toList();
    }
  } catch (e) {
    debugPrint('Error fetch riwayat golongan: $e');
  }
  return [];
}

/// Halaman "Riwayat Golongan" — menampilkan riwayat kenaikan
/// golongan/pangkat pegawai yang sedang login, diambil dari Supabase.
class GolonganScreen extends StatefulWidget {
  final AppUser? user;
  const GolonganScreen({super.key, this.user});

  @override
  State<GolonganScreen> createState() => _GolonganScreenState();
}

class _GolonganScreenState extends State<GolonganScreen> {
  late Future<List<_GolonganRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchRiwayatGolongan(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchRiwayatGolongan(widget.user));
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
