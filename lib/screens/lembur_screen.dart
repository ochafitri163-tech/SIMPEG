import 'package:flutter/material.dart';
import '../models/pegawai_data.dart';
import '../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

class LemburScreen extends StatelessWidget {
  const LemburScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Lembur',
      subtitle: 'Riwayat jam & uang lembur',
      icon: Icons.access_time_filled_rounded,
      child: dummyLembur.isEmpty
          ? const EmptyState(message: 'Belum ada data lembur')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              itemCount: dummyLembur.length,
              itemBuilder: (context, index) {
                final item = dummyLembur[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InfoCard(
                    padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // NO — badge bulat bernomor urut, senada dengan
                        // kolom "NO" pada tabel web.
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
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
                        // PERIODE + JAM LEMBUR
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
                        // UANG LEMBUR
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
  }
}