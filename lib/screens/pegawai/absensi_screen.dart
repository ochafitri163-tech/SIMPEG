import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pegawai_data.dart';
import '../../widgets/feature_scaffold.dart';

/// Ambil ringkasan kehadiran bulan berjalan milik pegawai yang sedang
/// login dari tabel `attendance` di Supabase. Kalau belum ada data untuk
/// bulan ini, kembalikan ringkasan kosong (0/0/0) supaya UI tetap tampil
/// rapi tanpa error.
Future<AttendanceSummary> _fetchAttendanceBulanIni() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final now = DateTime.now();

  const bulanList = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final labelBulanIni = '${bulanList[now.month]} ${now.year}';

  if (userId == null) {
    return AttendanceSummary(
        bulanLabel: labelBulanIni, hadir: 0, telat: 0, izin: 0);
  }

  final row = await Supabase.instance.client
      .from('attendance')
      .select()
      .eq('pegawai_id', userId)
      .eq('tahun', now.year)
      .eq('bulan', now.month)
      .maybeSingle();

  if (row == null) {
    return AttendanceSummary(
        bulanLabel: labelBulanIni, hadir: 0, telat: 0, izin: 0);
  }

  return AttendanceSummary(
    bulanLabel: (row['bulan_label'] ?? labelBulanIni) as String,
    hadir: (row['hadir'] ?? 0) as int,
    telat: (row['telat'] ?? 0) as int,
    izin: (row['izin'] ?? 0) as int,
  );
}

/// Halaman Absensi — ringkasan kehadiran bulan berjalan (Hadir / Telat /
/// Izin) dalam bentuk kartu statistik, mengikuti palet & pola desain
/// halaman fitur lain (FeatureScaffold + InfoCard).
class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({super.key});

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  late Future<AttendanceSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAttendanceBulanIni();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchAttendanceBulanIni());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Absensi',
      subtitle: 'Rekap kehadiran bulan ini',
      icon: Icons.fact_check_rounded,
      child: FutureBuilder<AttendanceSummary>(
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
                  'Gagal memuat data absensi: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            );
          }

          final summary = snapshot.data!;
          final totalHariKerja = summary.hadir + summary.telat + summary.izin;
          final persenHadir = totalHariKerja == 0
              ? 0
              : ((summary.hadir / totalHariKerja) * 100).round();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                InfoCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tingkat Kehadiran',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7F8C8D),
                            ),
                          ),
                          Text(
                            '$persenHadir%',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: FeatureScaffold.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: totalHariKerja == 0
                              ? 0
                              : summary.hadir / totalHariKerja,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFEDF1F5),
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF27AE60)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Hadir',
                        value: '${summary.hadir}',
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF27AE60),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Telat',
                        value: '${summary.telat}',
                        icon: Icons.watch_later_rounded,
                        color: const Color(0xFFE67E22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Izin',
                        value: '${summary.izin}',
                        icon: Icons.event_busy_rounded,
                        color: const Color(0xFF2E86AB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'CATATAN',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B98A9),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                InfoCard(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: FeatureScaffold.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          totalHariKerja == 0
                              ? 'Belum ada data absensi untuk bulan ini.'
                              : 'Data absensi harian rinci akan tampil di sini setelah '
                                  'terhubung dengan sistem presensi (mesin fingerprint/API).',
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B2733),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
