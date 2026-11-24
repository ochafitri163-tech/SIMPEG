import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

/// Model data untuk satu item riwayat prestasi pegawai
class _PrestasiRow {
  final int id;
  final String judul;
  final String tanggal;
  final String keterangan;
  final String tingkat;
  final int? jamLembur;
  final int? nominalLembur;
  final String? absensi;
  final String? karya;

  const _PrestasiRow({
    required this.id,
    required this.judul,
    required this.tanggal,
    required this.keterangan,
    required this.tingkat,
    this.jamLembur,
    this.nominalLembur,
    this.absensi,
    this.karya,
  });

  factory _PrestasiRow.fromMap(Map<String, dynamic> row) {
    int? parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    String cleanKeterangan = (row['keterangan_bersih'] ?? row['keterangan'] ?? '-').toString();
    int? jam;
    int? nominal;
    String? abs;
    String? kr;

    final rawKet = (row['keterangan'] ?? '').toString().trim();
    if (rawKet.startsWith('{')) {
      try {
        final decoded = jsonDecode(rawKet);
        if (decoded is Map) {
          if (decoded['desc'] != null && decoded['desc'].toString().isNotEmpty) {
            cleanKeterangan = decoded['desc'].toString();
          }
          jam = parseNum(decoded['jam_lembur']);
          nominal = parseNum(decoded['nominal_lembur']);
          abs = decoded['absensi']?.toString();
          kr = decoded['karya']?.toString();
        }
      } catch (_) {}
    }

    if (row['meta'] is Map) {
      final meta = row['meta'] as Map;
      jam = parseNum(meta['jam_lembur']) ?? jam;
      nominal = parseNum(meta['nominal_lembur']) ?? nominal;
      abs = meta['absensi']?.toString() ?? abs;
      kr = meta['karya']?.toString() ?? kr;
    }

    final rawTingkat = (row['tingkat'] ?? '').toString().trim();
    String formattedTingkat = rawTingkat;
    if (formattedTingkat.isEmpty) {
      formattedTingkat = 'Prestasi';
    } else if (int.tryParse(formattedTingkat) != null) {
      formattedTingkat = 'Nilai $formattedTingkat';
    }

    return _PrestasiRow(
      id: int.tryParse(row['id']?.toString() ?? '0') ?? 0,
      judul: (row['judul'] ?? kr ?? 'Prestasi Kerja').toString(),
      tanggal: (row['tanggal'] ?? '-').toString(),
      keterangan: cleanKeterangan,
      tingkat: formattedTingkat,
      jamLembur: jam,
      nominalLembur: nominal,
      absensi: abs,
      karya: kr,
    );
  }
}

Future<List<_PrestasiRow>> _fetchPrestasi(AppUser? user) async {
  try {
    final res = await ApiService.getPrestasi(nik: user?.nik);
    if (res['success'] == true && res['data'] is List) {
      final list = res['data'] as List;
      return list
          .map((r) => _PrestasiRow.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    }
  } catch (e) {
    debugPrint('Error fetch prestasi: $e');
  }
  return [];
}

/// Halaman "Prestasi Pegawai" — menampilkan riwayat prestasi, penghargaan,
/// dan karya kerja pegawai yang tersinkronisasi dari SIMPEG Web.
class PrestasiScreen extends StatefulWidget {
  final AppUser? user;
  const PrestasiScreen({super.key, this.user});

  @override
  State<PrestasiScreen> createState() => _PrestasiScreenState();
}

class _PrestasiScreenState extends State<PrestasiScreen> {
  late Future<List<_PrestasiRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchPrestasi(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchPrestasi(widget.user));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FeatureScaffold(
      title: 'Prestasi Pegawai',
      subtitle: widget.user != null
          ? 'Riwayat penghargaan & prestasi kerja ${widget.user!.name}'
          : 'Riwayat prestasi & penghargaan kerja',
      icon: Icons.emoji_events_rounded,
      child: FutureBuilder<List<_PrestasiRow>>(
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
                  'Gagal memuat prestasi: ${snapshot.error}',
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
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyState(
                    icon: Icons.emoji_events_outlined,
                    message: 'Belum ada data prestasi kerja.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF78350F).withValues(alpha: 0.35)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
                                ),
                              ),
                              child: const Icon(
                                Icons.emoji_events_rounded,
                                color: Color(0xFFD97706),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.judul,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: FeatureScaffold.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.tanggal,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              label: item.tingkat,
                              color: const Color(0xFFD97706),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        InfoRow(label: 'Keterangan', value: item.keterangan),
                        if (item.jamLembur != null && item.jamLembur! > 0)
                          InfoRow(
                            label: 'Lembur Dicatat',
                            value: '${item.jamLembur} jam (Rp ${formatRupiah(item.nominalLembur ?? 0)})',
                            bold: true,
                          ),
                        if (item.absensi != null && item.absensi!.isNotEmpty)
                          InfoRow(
                            label: 'Kehadiran',
                            value: '${item.absensi} hari',
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
