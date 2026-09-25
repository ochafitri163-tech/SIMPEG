import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

class _KeluargaRow {
  final int? id;
  final String nama;
  final String hubungan;
  final String tanggalLahir;
  final String pekerjaan;

  const _KeluargaRow({
    this.id,
    required this.nama,
    required this.hubungan,
    required this.tanggalLahir,
    required this.pekerjaan,
  });

  factory _KeluargaRow.fromMap(Map<String, dynamic> row) {
    return _KeluargaRow(
      id: row['id'] != null ? int.tryParse(row['id'].toString()) : null,
      nama: (row['nama'] ?? '') as String,
      hubungan: (row['hubungan'] ?? '') as String,
      tanggalLahir: (row['tanggal_lahir'] ?? row['tgl_lahir'] ?? '-') as String,
      pekerjaan: (row['pekerjaan'] ?? row['keterangan'] ?? '-') as String,
    );
  }
}

Future<String?> _resolvePegawaiId(AppUser? user) async {
  // 1. Prioritas: gunakan NIK dari AppUser (selalu ada setelah login)
  String? nik = user?.nik;

  // 2. Fallback: ambil dari SharedPreferences
  if (nik == null || nik.isEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      nik = prefs.getString('user_nik');
      if (nik == null || nik.isEmpty) {
        final sessionStr = prefs.getString('user_session_json');
        if (sessionStr != null && sessionStr.isNotEmpty) {
          final jsonMap = jsonDecode(sessionStr);
          nik = jsonMap['nik'] as String?;
        }
      }
    } catch (_) {}
  }

  // 3. Resolve NIK ke pegawai_id (UUID) dari tabel pegawai di Supabase
  if (nik != null && nik.isNotEmpty) {
    try {
      final peg = await Supabase.instance.client
          .from('pegawai')
          .select('id')
          .eq('nik', nik)
          .maybeSingle();
      if (peg != null && peg['id'] != null) {
        return peg['id'].toString();
      }
    } catch (_) {}
  }

  // 4. Last resort: coba Supabase Auth user ID (jarang berhasil karena login via Laravel)
  String? userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null && userId.isNotEmpty) return userId;

  return null;
}

Future<List<_KeluargaRow>> _fetchKeluarga(AppUser? user) async {
  final userId = await _resolvePegawaiId(user);
  if (userId == null) return [];

  try {
    final rows = await Supabase.instance.client
        .from('keluarga')
        .select()
        .eq('pegawai_id', userId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((r) => _KeluargaRow.fromMap(r as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Halaman "Data Keluarga" — menampilkan daftar anggota keluarga pegawai
/// yang sedang login, diambil dari Supabase (read-only, dikelola SDM via Web).
class KeluargaScreen extends StatefulWidget {
  final AppUser? user;
  const KeluargaScreen({super.key, this.user});

  @override
  State<KeluargaScreen> createState() => _KeluargaScreenState();
}

class _KeluargaScreenState extends State<KeluargaScreen> {
  late Future<List<_KeluargaRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchKeluarga(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchKeluarga(widget.user));
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
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF8E44AD),
                            size: 22,
                          ),
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
                                  Expanded(
                                    child: Text(
                                      item.nama,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: FeatureScaffold.navy,
                                      ),
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
