import 'package:flutter/material.dart';
import '../../widgets/feature_scaffold.dart';

/// Halaman Kebijakan Privasi — konten nyata (bukan snackbar "coming
/// soon"), menjelaskan data apa saja yang dikumpulkan aplikasi & untuk
/// apa, sesuai fitur yang benar-benar ada di SIMPEG Mobile.
class KebijakanPrivasiScreen extends StatelessWidget {
  const KebijakanPrivasiScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'Data yang Kami Kumpulkan',
      'SIMPEG Mobile menyimpan data kepegawaian Anda (NIK, nama, jabatan, '
          'unit kerja, golongan, data keluarga & pendidikan), data absensi, '
          'serta data payroll/THR/insentif yang diinput oleh bagian '
          'kepegawaian PERUMDAM Tirta Darma Ayu.',
    ),
    (
      'Notifikasi',
      'Jika Anda mengaktifkan "Pengingat Absensi" atau "Pengumuman '
          'Kantor" di menu Pengaturan, aplikasi akan mengirim notifikasi '
          'lokal ke perangkat Anda. Anda dapat menonaktifkannya kapan saja '
          'lewat menu yang sama.',
    ),
    (
      'Penyimpanan Data',
      'Seluruh data disimpan pada infrastruktur database Supabase yang '
          'dikelola oleh PERUMDAM Tirta Darma Ayu, dan hanya dapat diakses '
          'oleh pegawai yang bersangkutan setelah login menggunakan NIK & '
          'kata sandi.',
    ),
    (
      'Penggunaan Data',
      'Data yang dikumpulkan hanya digunakan untuk keperluan administrasi '
          'kepegawaian internal (absensi, penggajian, riwayat jabatan/'
          'golongan, dan penanganan pengaduan) dan tidak dibagikan ke pihak '
          'ketiga di luar keperluan tersebut.',
    ),
    (
      'Hak Anda',
      'Anda berhak meminta koreksi data kepegawaian yang tidak akurat '
          'dengan menghubungi bagian kepegawaian atau IT PERUMDAM Tirta '
          'Darma Ayu.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Kebijakan Privasi',
      subtitle: 'Bagaimana data Anda digunakan',
      icon: Icons.privacy_tip_outlined,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final section in _sections) ...[
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: FeatureScaffold.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.$2,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Color(0xFF5B6B7B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Center(
            child: Text(
              'Terakhir diperbarui: Juli 2026',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}