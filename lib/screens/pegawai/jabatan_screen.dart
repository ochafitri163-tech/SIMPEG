import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

class _JabatanRow {
  final String jabatan;
  final String unitKerja;
  final String tmt;
  final String noSk;

  const _JabatanRow({
    required this.jabatan,
    required this.unitKerja,
    required this.tmt,
    required this.noSk,
  });

  factory _JabatanRow.fromMap(Map<String, dynamic> row) {
    return _JabatanRow(
      jabatan: (row['jabatan'] ?? row['nama_jabatan'] ?? '-').toString(),
      unitKerja: (row['unit_kerja'] ?? row['unit'] ?? '-').toString(),
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

Future<List<_JabatanRow>> _fetchRiwayatJabatan(AppUser? user) async {
  final targetId = await _resolvePegawaiId(user);
  if (targetId == null) return [];

  try {
    final rows = await Supabase.instance.client
        .from('riwayat_jabatan')
        .select()
        .eq('pegawai_id', targetId)
        .order('tmt', ascending: false);

    return (rows as List)
        .map((r) => _JabatanRow.fromMap(r as Map<String, dynamic>))
        .toList();
  } catch (e) {
    return [];
  }
}

/// Halaman "Jabatan & Golongan" — menampilkan riwayat jabatan dan unit
/// kerja pegawai yang sedang login, diambil dari Supabase.
class JabatanScreen extends StatefulWidget {
  final AppUser? user;
  const JabatanScreen({super.key, this.user});

  @override
  State<JabatanScreen> createState() => _JabatanScreenState();
}

class _JabatanScreenState extends State<JabatanScreen> {
  late Future<List<_JabatanRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchRiwayatJabatan(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchRiwayatJabatan(widget.user));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Jabatan & Golongan',
      subtitle: 'Riwayat jabatan dan unit kerja',
      icon: Icons.work_rounded,
      child: FutureBuilder<List<_JabatanRow>>(
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
                  'Gagal memuat riwayat jabatan: ${snapshot.error}',
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
                  EmptyState(message: 'Belum ada data jabatan'),
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
                                color: const Color(0xFFFDECDC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.work_rounded,
                                  color: Color(0xFFE67E22), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.jabatan,
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
                        InfoRow(label: 'Unit Kerja', value: item.unitKerja),
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
