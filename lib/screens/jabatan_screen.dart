import 'package:flutter/material.dart';
import '../models/pegawai_data.dart';
import '../widgets/feature_scaffold.dart';

class JabatanScreen extends StatelessWidget {
  const JabatanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Jabatan & Golongan',
      subtitle: 'Riwayat jabatan dan unit kerja',
      icon: Icons.work_rounded,
      child: dummyJabatan.isEmpty
          ? const EmptyState(message: 'Belum ada data jabatan')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: dummyJabatan.length,
              itemBuilder: (context, index) {
                final item = dummyJabatan[index];
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
                                color: const Color(0xFFFDECDC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.work_rounded,
                                  color: Color(0xFFE67E22), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.jabatan,
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
                        InfoRow(label: 'Unit Kerja', value: item.unitKerja),
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
