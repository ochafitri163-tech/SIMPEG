import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../services/api_service.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

class _LemburRow {
  final String bulan;
  final num jamLembur;
  final int uangLembur;
  final String? keterangan;
  final String? tanggal;

  const _LemburRow({
    required this.bulan,
    required this.jamLembur,
    required this.uangLembur,
    this.keterangan,
    this.tanggal,
  });

  factory _LemburRow.fromMap(Map<String, dynamic> row) {
    return _LemburRow(
      bulan: (row['bulan'] ?? '-') as String,
      jamLembur: _lemburToNum(row['jam_lembur']),
      uangLembur: _lemburToInt(row['uang_lembur']),
      keterangan: row['keterangan']?.toString(),
      tanggal: row['tanggal']?.toString(),
    );
  }
}

/// Helper: konversi value ke int secara aman.
int _lemburToInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? 0;
  return 0;
}

/// Helper: konversi value jam (bisa 9 atau 9.5) secara aman.
num _lemburToNum(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val;
  if (val is String) return num.tryParse(val) ?? 0;
  return 0;
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

  // 4. Last resort: coba Supabase Auth user ID
  String? userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null && userId.isNotEmpty) return userId;

  return null;
}

Future<List<_LemburRow>> _fetchLembur(AppUser? user) async {
  // 1. Prioritas Utama: Ambil dari API Laravel (ApiService.getLembur)
  // Backend menyatukan data input manual Set Prestasi SDM, tabel lembur, & payroll.
  try {
    final res = await ApiService.getLembur(nik: user?.nik);
    if (res['success'] == true && res['data'] is List) {
      final list = res['data'] as List;
      if (list.isNotEmpty) {
        return list
            .map((r) => _LemburRow.fromMap(r as Map<String, dynamic>))
            .toList();
      }
    }
  } catch (e) {
    debugPrint('Gagal fetch lembur via ApiService: $e');
  }

  // 2. Fallback: Query langsung ke Supabase
  final userId = await _resolvePegawaiId(user);
  if (userId == null) return [];

  // 2a. Dari tabel prestasi (input manual SDM)
  try {
    final prestasiRows = await Supabase.instance.client
        .from('prestasi')
        .select()
        .eq('pegawai_id', userId)
        .order('created_at', ascending: false);

    final List<_LemburRow> fromPrestasi = [];
    for (final r in (prestasiRows as List)) {
      Map<String, dynamic> meta = {};
      if (r['keterangan'] != null) {
        try {
          meta = jsonDecode(r['keterangan'].toString()) as Map<String, dynamic>;
        } catch (_) {}
      }
      final jam = _lemburToNum(meta['jam_lembur'] ?? r['jam_lembur']);
      final uang = _lemburToInt(meta['nominal_lembur'] ?? (jam * 9375).round());
      if (jam > 0 || uang > 0) {
        String bulanStr = '-';
        if (r['tanggal'] != null) {
          final tglStr = r['tanggal'].toString();
          try {
            final dt = DateTime.parse(tglStr);
            const bNames = [
              '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
              'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
            ];
            bulanStr = '${bNames[dt.month]} ${dt.year}';
          } catch (_) {
            bulanStr = tglStr;
          }
        }
        fromPrestasi.add(_LemburRow(
          bulan: bulanStr,
          jamLembur: jam,
          uangLembur: uang,
          keterangan: meta['desc']?.toString() ?? r['judul']?.toString(),
          tanggal: r['tanggal']?.toString(),
        ));
      }
    }
    if (fromPrestasi.isNotEmpty) {
      return fromPrestasi;
    }
  } catch (_) {}

  // 2b. Dari tabel lembur
  try {
    final List<Map<String, dynamic>> rows = await Supabase.instance.client
        .from('lembur')
        .select()
        .eq('pegawai_id', userId)
        .order('created_at', ascending: false);

    if (rows.isNotEmpty) {
      return rows
          .map((r) => _LemburRow.fromMap(r))
          .toList();
    }
  } catch (_) {}

  // 2c. Fallback dari tabel payroll di mana lembur > 0
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
        final uang = _lemburToInt(r['lembur']);
        // Standard rate PDAM Rp 9.375 / jam (BUKAN 50.000)
        final jam = max(1.0, (uang / 9375.0));
        return _LemburRow(
          bulan: (r['periode'] ?? '-') as String,
          jamLembur: double.parse(jam.toStringAsFixed(1)),
          uangLembur: uang,
        );
      }).toList();
    }
  } catch (_) {}

  return [];
}

/// Halaman "Lembur" — menampilkan riwayat jam & uang lembur pegawai yang
/// sedang login.
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
                                      '${item.jamLembur % 1 == 0 ? item.jamLembur.toInt() : item.jamLembur} jam',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: FeatureScaffold.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.keterangan != null && item.keterangan!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.keterangan!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
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
