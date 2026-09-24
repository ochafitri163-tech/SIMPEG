import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
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
      golongan: (row['golongan'] ?? row['pangkat'] ?? '-').toString(),
      pangkat: (row['pangkat'] ?? row['golongan'] ?? '-').toString(),
      tmt: (row['tmt'] ?? '-').toString(),
      noSk: (row['no_sk'] ?? row['nomor_sk'] ?? '-').toString(),
    );
  }
}

Future<String?> _resolvePegawaiId(AppUser? user) async {
  final authId = Supabase.instance.client.auth.currentUser?.id;
  if (authId != null && authId.isNotEmpty) return authId;

  String nik = user?.nik ?? '';
  if (nik.isEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      nik = prefs.getString('user_nik') ?? '';
    } catch (_) {}
  }
  if (nik.isNotEmpty) {
    try {
      final res = await Supabase.instance.client
          .from('pegawai')
          .select('id')
          .eq('nik', nik)
          .maybeSingle();
      if (res != null && res['id'] != null) {
        return res['id'].toString();
      }
    } catch (_) {}
  }
  return null;
}

Future<List<_GolonganRow>> _fetchRiwayatGolongan(AppUser? user) async {
  final targetId = await _resolvePegawaiId(user);
  if (targetId == null) return [];

  try {
    final rows = await Supabase.instance.client
        .from('riwayat_golongan')
        .select()
        .eq('pegawai_id', targetId)
        .order('tmt', ascending: false);

    return (rows as List)
        .map((r) => _GolonganRow.fromMap(r as Map<String, dynamic>))
        .toList();
  } catch (e) {
    return [];
  }
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
