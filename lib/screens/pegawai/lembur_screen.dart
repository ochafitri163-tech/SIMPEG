import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

class _LemburRow {
  final String bulan;
  final int jamLembur;
  final int uangLembur;

  const _LemburRow({
    required this.bulan,
    required this.jamLembur,
    required this.uangLembur,
  });

  factory _LemburRow.fromMap(Map<String, dynamic> row) {
    return _LemburRow(
      bulan: row['bulan'] as String,
      jamLembur: (row['jam_lembur'] ?? 0) as int,
      uangLembur: (row['uang_lembur'] ?? 0) as int,
    );
  }
}

Future<String?> _resolvePegawaiId(AppUser? user) async {
  String? userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null && userId.isNotEmpty) return userId;

  String? nik = user?.nik;
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

  return null;
}

Future<List<_LemburRow>> _fetchLembur(AppUser? user) async {
  final userId = await _resolvePegawaiId(user);
  if (userId == null) return [];

  // 1. Coba ambil dari tabel lembur Supabase
  try {
    final rows = await Supabase.instance.client
        .from('lembur')
        .select()
        .eq('pegawai_id', userId)
        .order('created_at', ascending: false);

    if ((rows as List).isNotEmpty) {
      return (rows)
          .map((r) => _LemburRow.fromMap(r as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {}

  // 2. Fallback ambil dari tabel payroll di mana lembur > 0
  try {
    final payrollRows = await Supabase.instance.client
        .from('payroll')
        .select('periode, lembur, tahun, bulan')
        .eq('pegawai_id', userId)
        .gt('lembur', 0)
        .order('tahun', ascending: false)
        .order('bulan', ascending: false);

    if ((payrollRows as List).isNotEmpty) {
      return (payrollRows).map((r) {
        final uang = (r['lembur'] ?? 0) as int;
        return _LemburRow(
          bulan: (r['periode'] ?? '-') as String,
          jamLembur: max(1, (uang / 50000).round()),
          uangLembur: uang,
        );
      }).toList();
    }
  } catch (_) {}

  return [];
}

/// Halaman "Lembur" — menampilkan riwayat jam & uang lembur pegawai yang
/// sedang login, diambil dari Supabase.
class LemburScreen extends StatefulWidget {
  final AppUser? user;
  const LemburScreen({super.key, this.user});

  @override
  State<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends State<LemburScreen> {
  late Future<List<_LemburRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchLembur(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchLembur(widget.user));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Lembur',
      subtitle: 'Riwayat jam & uang lembur',
      icon: Icons.access_time_filled_rounded,
      child: FutureBuilder<List<_LemburRow>>(
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
                  'Gagal memuat data lembur: ${snapshot.error}',
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
                  EmptyState(message: 'Belum ada data lembur'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InfoCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FeatureScaffold.accent,
                                FeatureScaffold.navy,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.bulan,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: FeatureScaffold.navy,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F1F8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time_filled_rounded,
                                      size: 12,
                                      color: FeatureScaffold.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${item.jamLembur} jam',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: FeatureScaffold.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Uang Lembur',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF95A5A6),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatRupiah(item.uangLembur),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: FeatureScaffold.navy,
                              ),
                            ),
                          ],
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
