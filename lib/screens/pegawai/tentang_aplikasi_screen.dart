import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../widgets/feature_scaffold.dart';

/// Halaman "Tentang Aplikasi" — versi & build diambil otomatis dari
/// `package_info_plus` (bukan lagi teks statis "v3.0.0" yang ditulis
/// manual di kode).
class TentangAplikasiScreen extends StatefulWidget {
  const TentangAplikasiScreen({super.key});

  @override
  State<TentangAplikasiScreen> createState() => _TentangAplikasiScreenState();
}

class _TentangAplikasiScreenState extends State<TentangAplikasiScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Tentang Aplikasi',
      subtitle: 'Informasi versi & pengembang',
      icon: Icons.info_outline_rounded,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.water_drop_rounded,
                          color: FeatureScaffold.accent,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SIMPEG Mobile',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: FeatureScaffold.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _info == null
                                ? 'Memuat versi...'
                                : 'Versi ${_info!.version} (build ${_info!.buildNumber})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B98A9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tentang SIMPEG Mobile',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: FeatureScaffold.navy,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'SIMPEG Mobile adalah aplikasi kepegawaian resmi PERUMDAM '
                  'Tirta Darma Ayu Kabupaten Indramayu. Aplikasi ini '
                  'memudahkan pegawai untuk mengakses data absensi, payroll, '
                  'THR, insentif, riwayat kepegawaian, hingga pengaduan — '
                  'langsung dari genggaman.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Color(0xFF5B6B7B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row('Pengembang', 'IT PERUMDAM Tirta Darma Ayu'),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
                _row('Kontak Dukungan', 'it@pdamindramayu.co.id'),
                const Divider(height: 1, color: Color(0xFFF0F2F5)),
                _row('Website Resmi', 'www.pdamindramayu.co.id'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '© ${DateTime.now().year} PERUMDAM Tirta Darma Ayu',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF8B98A9)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B2733),
              ),
            ),
          ),
        ],
      ),
    );
  }
}