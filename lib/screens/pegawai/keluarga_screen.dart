import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/feature_scaffold.dart';

class _KeluargaRow {
  final String nama;
  final String hubungan;
  final String tanggalLahir;
  final String pekerjaan;

  const _KeluargaRow({
    required this.nama,
    required this.hubungan,
    required this.tanggalLahir,
    required this.pekerjaan,
  });

  factory _KeluargaRow.fromMap(Map<String, dynamic> row) {
    return _KeluargaRow(
      nama: row['nama'] as String,
      hubungan: row['hubungan'] as String,
      tanggalLahir: (row['tanggal_lahir'] ?? '-') as String,
      pekerjaan: (row['pekerjaan'] ?? '-') as String,
    );
  }
}

Future<List<_KeluargaRow>> _fetchKeluarga() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await Supabase.instance.client
      .from('keluarga')
      .select()
      .eq('pegawai_id', userId)
      .order('created_at', ascending: true);

  return (rows as List)
      .map((r) => _KeluargaRow.fromMap(r as Map<String, dynamic>))
      .toList();
}

/// Halaman "Data Keluarga" — menampilkan daftar anggota keluarga pegawai
/// yang sedang login, diambil dari Supabase.
class KeluargaScreen extends StatefulWidget {
  const KeluargaScreen({super.key});

  @override
  State<KeluargaScreen> createState() => _KeluargaScreenState();
}

class _KeluargaScreenState extends State<KeluargaScreen> {
  late Future<List<_KeluargaRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchKeluarga();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchKeluarga());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Data Keluarga',
      subtitle: 'Daftar anggota keluarga pegawai',
      icon: Icons.family_restroom_rounded,
      child: FutureBuilder<List<_KeluargaRow>>(
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
                  'Gagal memuat data keluarga: ${snapshot.error}',
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
                  EmptyState(message: 'Belum ada data keluarga'),
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
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1E7F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Color(0xFF8E44AD), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.nama,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: FeatureScaffold.navy,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: item.hubungan,
                                    color: const Color(0xFF8E44AD),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Lahir: ${item.tanggalLahir}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              Text(
                                'Pekerjaan: ${item.pekerjaan}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                            ],
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
