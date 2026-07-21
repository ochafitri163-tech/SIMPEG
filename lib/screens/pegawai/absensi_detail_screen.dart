import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/feature_scaffold.dart';

/// ==========================================================================
/// MODEL
/// ==========================================================================

/// Rekap bucket jam kedatangan untuk satu bulan.
class MonthlyArrivalBucket {
  final String label; // contoh: "Juni 2026"
  final int year;
  final int month;
  final int bucket0731_0800; // hadir tepat waktu
  final int bucket0801_0830;
  final int bucket0831_0900;
  final int bucketAfter0901; // telat
  final int pulangSebelum1600;

  MonthlyArrivalBucket({
    required this.label,
    required this.year,
    required this.month,
    required this.bucket0731_0800,
    required this.bucket0801_0830,
    required this.bucket0831_0900,
    required this.bucketAfter0901,
    required this.pulangSebelum1600,
  });

  /// Total hari yang tercatat telat (dipakai buat cek "tidak ada
  /// keterlambatan").
  int get totalTelat => bucketAfter0901;

  factory MonthlyArrivalBucket.empty(String label, int year, int month) {
    return MonthlyArrivalBucket(
      label: label,
      year: year,
      month: month,
      bucket0731_0800: 0,
      bucket0801_0830: 0,
      bucket0831_0900: 0,
      bucketAfter0901: 0,
      pulangSebelum1600: 0,
    );
  }
}

const _bulanList = [
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

/// ==========================================================================
/// FETCH LOGIC
/// ==========================================================================
///
/// Asumsi: tabel `attendance_log` di Supabase punya kolom per-hari:
///   - pegawai_id (uuid)
///   - tanggal    (date)
///   - jam_masuk  (time / text "HH:mm:ss", nullable kalau absen)
///   - jam_pulang (time / text "HH:mm:ss", nullable)
///
/// Kalau nama tabel/kolom di database lo beda, tinggal sesuaikan bagian
/// `.from('attendance_log')` dan nama kolomnya saja — logika bucket-nya
/// tidak perlu diubah.
Future<List<MonthlyArrivalBucket>> fetchRincianAbsensi3Bulan() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final now = DateTime.now();

  // Susun 3 periode bulan terakhir (bulan berjalan + 2 bulan sebelumnya),
  // urutan terbaru dulu, sesuai tampilan di gambar.
  final periods = List.generate(3, (i) {
    final d = DateTime(now.year, now.month - i, 1);
    return _MonthKey(d.year, d.month);
  });

  if (userId == null) {
    return periods
        .map((p) => MonthlyArrivalBucket.empty(
            '${_bulanList[p.month]} ${p.year}', p.year, p.month))
        .toList();
  }

  final earliest = periods.last; // bulan paling lama dalam rentang
  final startDate =
      DateTime(earliest.year, earliest.month, 1).toIso8601String();
  final endDate = DateTime(now.year, now.month + 1, 1)
      .subtract(const Duration(days: 1))
      .toIso8601String();

  List<Map<String, dynamic>> rows = [];
  try {
    final result = await Supabase.instance.client
        .from('attendance_log')
        .select('tanggal, jam_masuk, jam_pulang')
        .eq('pegawai_id', userId)
        .gte('tanggal', startDate.split('T').first)
        .lte('tanggal', endDate.split('T').first)
        .order('tanggal');
    rows = List<Map<String, dynamic>>.from(result as List);
  } catch (_) {
    // Kalau query gagal (misal tabel belum ada / kolom beda), tampilkan
    // rekap kosong supaya UI tetap rapi tanpa crash.
    rows = [];
  }

  // Siapkan map kosong untuk tiap periode.
  final Map<String, MonthlyArrivalBucket> result = {
    for (final p in periods)
      '${p.year}-${p.month}':
          MonthlyArrivalBucket.empty('${_bulanList[p.month]} ${p.year}', p.year, p.month)
  };

  for (final row in rows) {
    final tanggalRaw = row['tanggal'];
    if (tanggalRaw == null) continue;
    final tanggal = DateTime.tryParse(tanggalRaw.toString());
    if (tanggal == null) continue;

    final key = '${tanggal.year}-${tanggal.month}';
    final current = result[key];
    if (current == null) continue; // di luar 3 periode yang diminta

    final jamMasuk = _parseJam(row['jam_masuk']);
    final jamPulang = _parseJam(row['jam_pulang']);

    int b0731_0800 = current.bucket0731_0800;
    int b0801_0830 = current.bucket0801_0830;
    int b0831_0900 = current.bucket0831_0900;
    int bAfter0901 = current.bucketAfter0901;
    int pulangAwal = current.pulangSebelum1600;

    if (jamMasuk != null) {
      final menit = jamMasuk.hour * 60 + jamMasuk.minute;
      if (menit <= 8 * 60) {
        // <= 08.00 (mencakup 07.31–08.00)
        b0731_0800++;
      } else if (menit <= 8 * 60 + 30) {
        b0801_0830++;
      } else if (menit <= 9 * 60) {
        b0831_0900++;
      } else {
        bAfter0901++;
      }
    }

    if (jamPulang != null) {
      final menit = jamPulang.hour * 60 + jamPulang.minute;
      if (menit < 16 * 60) {
        pulangAwal++;
      }
    }

    result[key] = MonthlyArrivalBucket(
      label: current.label,
      year: current.year,
      month: current.month,
      bucket0731_0800: b0731_0800,
      bucket0801_0830: b0801_0830,
      bucket0831_0900: b0831_0900,
      bucketAfter0901: bAfter0901,
      pulangSebelum1600: pulangAwal,
    );
  }

  return periods.map((p) => result['${p.year}-${p.month}']!).toList();
}

class _MonthKey {
  final int year;
  final int month;
  _MonthKey(int rawYear, int rawMonth) : year = _fixYear(rawYear, rawMonth), month = _fixMonth(rawMonth);

  static int _fixMonth(int m) {
    var mm = m;
    while (mm <= 0) {
      mm += 12;
    }
    while (mm > 12) {
      mm -= 12;
    }
    return mm;
  }

  static int _fixYear(int y, int m) {
    if (m <= 0) return y - 1;
    if (m > 12) return y + 1;
    return y;
  }
}

DateTime? _parseJam(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  // Dukung format "HH:mm:ss" atau "HH:mm"
  final parts = s.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(2000, 1, 1, h, m);
}

/// ==========================================================================
/// SCREEN
/// ==========================================================================

class AbsensiDetailScreen extends StatefulWidget {
  const AbsensiDetailScreen({super.key});

  @override
  State<AbsensiDetailScreen> createState() => _AbsensiDetailScreenState();
}

class _AbsensiDetailScreenState extends State<AbsensiDetailScreen> {
  late Future<List<MonthlyArrivalBucket>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchRincianAbsensi3Bulan();
  }

  Future<void> _refresh() async {
    setState(() => _future = fetchRincianAbsensi3Bulan());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return FeatureScaffold(
      title: 'Absensi',
      subtitle: 'Rincian jam kedatangan',
      icon: Icons.fact_check_rounded,
      child: FutureBuilder<List<MonthlyArrivalBucket>>(
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

          final periods = snapshot.data!;
          final totalTelat3Bulan =
              periods.fold<int>(0, (sum, p) => sum + p.totalTelat);
          final tidakAdaTelat = totalTelat3Bulan == 0;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
              children: [
                _StatusBanner(
                  positif: tidakAdaTelat,
                  title: tidakAdaTelat
                      ? 'Tidak ada keterlambatan 3 bulan terakhir'
                      : 'Ada keterlambatan dalam 3 bulan terakhir',
                  subtitle: tidakAdaTelat
                      ? 'Kehadiranmu konsisten tepat waktu'
                      : 'Total $totalTelat3Bulan hari tercatat masuk setelah 09.01',
                ),
                const SizedBox(height: 24),
                Text(
                  'RINCIAN JAM KEDATANGAN PER PERIODE',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10.5 : 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8B98A9),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 12),
                for (final periode in periods) ...[
                  _PeriodeCard(data: periode, isSmallScreen: isSmallScreen),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool positif;
  final String title;
  final String subtitle;

  const _StatusBanner({
    required this.positif,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = positif ? const Color(0xFF27AE60) : const Color(0xFFE67E22);
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14.0 : 18.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 34.0 : 40.0,
            height: isSmallScreen ? 34.0 : 40.0,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(
              positif ? Icons.check_rounded : Icons.priority_high_rounded,
              color: Colors.white,
              size: isSmallScreen ? 18.0 : 22.0,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 12.5 : 14.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: isSmallScreen ? 11.0 : 12.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodeCard extends StatelessWidget {
  final MonthlyArrivalBucket data;
  final bool isSmallScreen;

  const _PeriodeCard({required this.data, this.isSmallScreen = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: TextStyle(
              fontSize: isSmallScreen ? 13.0 : 15.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1B2733),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BucketTile(
                  label: '07.31 – 08.00',
                  value: data.bucket0731_0800,
                  color: const Color(0xFF27AE60),
                  isSmallScreen: isSmallScreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BucketTile(
                  label: '08.01 – 08.30',
                  value: data.bucket0801_0830,
                  color: const Color(0xFF27AE60),
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BucketTile(
                  label: '08.31 – 09.00',
                  value: data.bucket0831_0900,
                  color: const Color(0xFFE67E22),
                  isSmallScreen: isSmallScreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BucketTile(
                  label: '> 09.01',
                  value: data.bucketAfter0901,
                  color: const Color(0xFFE74C3C),
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _BucketTile(
            label: 'Pulang Sblm 16.00',
            value: data.pulangSebelum1600,
            color: const Color(0xFF27AE60),
            fullWidth: true,
            isSmallScreen: isSmallScreen,
          ),
        ],
      ),
    );
  }
}

class _BucketTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool fullWidth;
  final bool isSmallScreen;

  const _BucketTile({
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10.0 : 12.0,
        vertical: isSmallScreen ? 8.0 : 10.0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 10.5 : 11.5,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value hr',
            style: TextStyle(
              fontSize: isSmallScreen ? 12.5 : 14.0,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}