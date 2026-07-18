import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

// =====================================================================
// CATATAN PENTING: kode ASLI halaman ini berjudul "Tunjangan Pendidikan"
// tapi datanya diambil dari `dummyGaji13` (data Gaji ke-13), BUKAN dari
// tunjangan pendidikan yang sebenarnya. Ini kemungkinan bug/salah
// copy-paste di kode original.
//
// Supaya perilaku aplikasi tidak berubah tiba-tiba, versi dinamis ini
// TETAP mengikuti kode asli (fetch dari tabel `gaji_13`). Kalau kamu mau
// dibenerin supaya benar-benar menampilkan data tunjangan pendidikan,
// bilang saja -- tinggal ganti _fetchData() untuk query ke tabel
// `tunjangan_pendidikan` sebagai gantinya.
// =====================================================================

class _Gaji13Row {
  final String tahun;
  final int jumlah;
  final String tanggalCair;
  final String status;

  const _Gaji13Row({
    required this.tahun,
    required this.jumlah,
    required this.tanggalCair,
    required this.status,
  });

  factory _Gaji13Row.fromMap(Map<String, dynamic> row) {
    return _Gaji13Row(
      tahun: row['tahun'] as String,
      jumlah: (row['jumlah'] ?? 0) as int,
      tanggalCair: (row['tanggal_cair'] ?? '-') as String,
      status: (row['status'] ?? '-') as String,
    );
  }
}

Future<List<_Gaji13Row>> _fetchData() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await Supabase.instance.client
      .from('gaji_13')
      .select()
      .eq('pegawai_id', userId)
      .order('tahun', ascending: false);

  return (rows as List)
      .map((r) => _Gaji13Row.fromMap(r as Map<String, dynamic>))
      .toList();
}

class TunjanganPendidikanScreen extends StatefulWidget {
  const TunjanganPendidikanScreen({super.key});

  @override
  State<TunjanganPendidikanScreen> createState() =>
      _TunjanganPendidikanScreenState();
}

class _TunjanganPendidikanScreenState extends State<TunjanganPendidikanScreen> {
  late Future<List<_Gaji13Row>> _future;

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
      subtitle: 'Riwayat pencairan tunjangan pendidikan',
      icon: Icons.account_balance_wallet_rounded,
      child: FutureBuilder<List<_Gaji13Row>>(
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
                              child: Text(
                                'Tunjangan Pendidikan Tahun ${item.tahun}',
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
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        InfoRow(
                            label: 'Jumlah',
                            value: formatRupiah(item.jumlah),
                            bold: true),
                        InfoRow(label: 'Tanggal Cair', value: item.tanggalCair),
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
