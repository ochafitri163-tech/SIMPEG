import 'package:flutter/material.dart';
import '../../models/pegawai_data.dart';
import '../../widgets/feature_scaffold.dart';

class GolonganScreen extends StatelessWidget {
  const GolonganScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Riwayat Golongan',
      subtitle: 'Riwayat kenaikan golongan/pangkat',
      icon: Icons.military_tech_rounded,
      child: dummyGolongan.isEmpty
          ? const EmptyState(message: 'Belum ada data golongan')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: dummyGolongan.length,
              itemBuilder: (context, index) {
                final item = dummyGolongan[index];
                final isLatest = index == 0;
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
                                color: const Color(0xFFFCE6EF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.military_tech_rounded,
                                  color: Color(0xFFC2185B), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Golongan ${item.golongan}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: FeatureScaffold.navy,
                                ),
                              ),
                            ),
                            if (isLatest)
                              const StatusBadge(
                                  label: 'Saat Ini', color: Color(0xFF27AE60)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        InfoRow(label: 'Pangkat', value: item.pangkat),
                        InfoRow(label: 'TMT', value: item.tmt),
                        InfoRow(label: 'No. SK', value: item.noSk),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
