import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

// Halaman riwayat Tunjangan Pendidikan pegawai (Regulasi 2026 & Histori Gaji ke-13)
// Terhubung langsung ke API Laravel dan Supabase.

class _TunjanganPendidikanRow {
  final String label;
  final String tahun;
  final int gapok;
  final int tunjanganIstri;
  final int tunjanganAnak;
  final int jumlahPendapatan;
  final int potonganKoperasi;
  final int potonganKas;
  final int jumlahPotongan;
  final int diterima;
  final String tanggalCair;
  final String status;
  final bool isRegulasi2026;

  const _TunjanganPendidikanRow({
    required this.label,
    required this.tahun,
    required this.gapok,
    required this.tunjanganIstri,
    required this.tunjanganAnak,
    required this.jumlahPendapatan,
    required this.potonganKoperasi,
    required this.potonganKas,
    required this.jumlahPotongan,
    required this.diterima,
    required this.tanggalCair,
    required this.status,
    required this.isRegulasi2026,
  });

  factory _TunjanganPendidikanRow.fromTpMap(Map<String, dynamic> row) {
    final gapok = (row['gapok'] ?? 0) as int;
    final istri = (row['tunjangan_istri'] ?? 0) as int;
    final anak = (row['tunjangan_anak'] ?? 0) as int;
    final pendapatan = gapok + istri + anak;
    final kop = (row['potongan_koperasi'] ?? 0) as int;
    final kas = (row['potongan_kas'] ?? 0) as int;
    final pot = kop + kas;
    final bersih = (row['diterima'] != null && (row['diterima'] as num) > 0)
        ? (row['diterima'] as num).toInt()
        : (pendapatan - pot);
    final bulanLabel = (row['bulan_label'] ?? 'JULI 2026').toString();

    return _TunjanganPendidikanRow(
      label: bulanLabel,
      tahun: bulanLabel.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty
          ? bulanLabel.replaceAll(RegExp(r'[^0-9]'), '')
          : '2026',
      gapok: gapok,
      tunjanganIstri: istri,
      tunjanganAnak: anak,
      jumlahPendapatan: pendapatan,
      potonganKoperasi: kop,
      potonganKas: kas,
      jumlahPotongan: pot,
      diterima: bersih > 0 ? bersih : 0,
      tanggalCair: (row['created_at'] != null)
          ? row['created_at'].toString().substring(0, 10)
          : '-',
      status: 'Terbit & Final',
      isRegulasi2026: true,
    );
  }

  factory _TunjanganPendidikanRow.fromGaji13Map(Map<String, dynamic> row) {
    final thn = row['tahun'].toString();
    final jml = (row['jumlah'] ?? row['gaji13_diterima'] ?? 0) as int;
    final gapok = (row['gapok'] ?? 0) as int;
    final istri = (row['tunjangan_istri'] ?? 0) as int;
    final anak = (row['tunjangan_anak'] ?? 0) as int;

    return _TunjanganPendidikanRow(
      label: 'Gaji 13 / Tunj. Pendidikan $thn',
      tahun: thn,
      gapok: gapok,
      tunjanganIstri: istri,
      tunjanganAnak: anak,
      jumlahPendapatan: (row['total_pendapatan'] ?? jml) as int,
      potonganKoperasi: (row['potongan_koperasi'] ?? 0) as int,
      potonganKas: (row['potongan_kas'] ?? 0) as int,
      jumlahPotongan: (row['total_potongan'] ?? 0) as int,
      diterima: jml,
      tanggalCair: (row['tanggal_cair'] ?? '-') as String,
      status: (row['status'] ?? '-') as String,
      isRegulasi2026: false,
    );
  }
}

Future<List<_TunjanganPendidikanRow>> _fetchData() async {
  final List<_TunjanganPendidikanRow> results = [];
  String? nik;
  String? userId = Supabase.instance.client.auth.currentUser?.id;

  try {
    final prefs = await SharedPreferences.getInstance();
    nik = prefs.getString('user_nik');
  } catch (_) {}

  // 1. Prioritas: Ambil via ApiService Laravel
  try {
    final apiRes = await ApiService.getTunjanganPendidikan(nik: nik);
    if (apiRes['success'] == true && apiRes['data'] != null) {
      final data = apiRes['data'];
      if (data['tunjangan_pendidikan'] is List) {
        for (final item in data['tunjangan_pendidikan']) {
          results.add(_TunjanganPendidikanRow.fromTpMap(
              Map<String, dynamic>.from(item as Map)));
        }
      }
      if (data['history_gaji_13'] is List) {
        for (final item in data['history_gaji_13']) {
          results.add(_TunjanganPendidikanRow.fromGaji13Map(
              Map<String, dynamic>.from(item as Map)));
        }
      }
      if (results.isNotEmpty) return results;
    }
  } catch (_) {}

  // 2. Fallback: Query langsung Supabase
  if (userId == null && nik != null && nik.isNotEmpty) {
    try {
      final peg = await Supabase.instance.client
          .from('pegawai')
          .select('id')
          .eq('nik', nik)
          .maybeSingle();
      if (peg != null && peg['id'] != null) {
        userId = peg['id'].toString();
      }
    } catch (_) {}
  }

  if (userId != null) {
    // 2a. Query tabel tunjangan_pendidikan (Regulasi 2026)
    try {
      final tpRows = await Supabase.instance.client
          .from('tunjangan_pendidikan')
          .select()
          .eq('pegawai_id', userId)
          .order('id', ascending: false);
      for (final r in (tpRows as List)) {
        results.add(_TunjanganPendidikanRow.fromTpMap(
            Map<String, dynamic>.from(r as Map)));
      }
    } catch (_) {}

    // 2b. Query tabel gaji_13 (Histori)
    try {
      final g13Rows = await Supabase.instance.client
          .from('gaji_13')
          .select()
          .eq('pegawai_id', userId)
          .order('tahun', ascending: false);
      for (final r in (g13Rows as List)) {
        results.add(_TunjanganPendidikanRow.fromGaji13Map(
            Map<String, dynamic>.from(r as Map)));
      }
    } catch (_) {}
  }

  return results;
}

class TunjanganPendidikanScreen extends StatefulWidget {
  const TunjanganPendidikanScreen({super.key});

  @override
  State<TunjanganPendidikanScreen> createState() =>
      _TunjanganPendidikanScreenState();
}

class _TunjanganPendidikanScreenState extends State<TunjanganPendidikanScreen> {
  late Future<List<_TunjanganPendidikanRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchData();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchData());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Tunjangan Pendidikan',
      subtitle: 'Riwayat pencairan tunjangan pendidikan resmi',
      icon: Icons.account_balance_wallet_rounded,
      child: FutureBuilder<List<_TunjanganPendidikanRow>>(
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
                  'Gagal memuat data: ${snapshot.error}',
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
                  EmptyState(message: 'Belum ada data Tunjangan Pendidikan'),
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
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDFF3EE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Color(0xFF16A085),
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: FeatureScaffold.navy,
                                    ),
                                  ),
                                  if (item.isRegulasi2026)
                                    const Text(
                                      'Format Resmi Regulasi 2026',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF16A085),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            StatusBadge.auto(item.status),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Rincian Komponen Sesuai Format Gambar 1
                        if (item.gapok > 0)
                          InfoRow(label: 'Gaji Pokok', value: formatRupiah(item.gapok)),
                        if (item.tunjanganIstri > 0)
                          InfoRow(label: 'Tunjangan Istri', value: formatRupiah(item.tunjanganIstri)),
                        if (item.tunjanganAnak > 0)
                          InfoRow(label: 'Tunjangan Anak', value: formatRupiah(item.tunjanganAnak)),
                        if (item.gapok > 0)
                          InfoRow(
                            label: 'Jumlah Pendapatan',
                            value: formatRupiah(item.jumlahPendapatan),
                            bold: true,
                          ),

                        if (item.potonganKoperasi > 0 || item.potonganKas > 0) ...[
                          const SizedBox(height: 6),
                          if (item.potonganKoperasi > 0)
                            InfoRow(label: 'Potongan Koperasi', value: formatRupiah(item.potonganKoperasi)),
                          if (item.potonganKas > 0)
                            InfoRow(label: 'Potongan Kas', value: formatRupiah(item.potonganKas)),
                          InfoRow(label: 'Jumlah Potongan', value: formatRupiah(item.jumlahPotongan)),
                        ],

                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Jumlah Diterima',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              Text(
                                formatRupiah(item.diterima),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        InfoRow(label: 'Tanggal Terbit', value: item.tanggalCair),
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
