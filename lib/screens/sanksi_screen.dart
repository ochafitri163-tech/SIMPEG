import 'package:flutter/material.dart';
import '../models/pegawai_data.dart';
import '../widgets/feature_scaffold.dart';

class SanksiScreen extends StatelessWidget {
  const SanksiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Riwayat Sanksi',
      subtitle: 'Catatan sanksi/disiplin pegawai',
      icon: Icons.gavel_rounded,
      child: dummySanksi.isEmpty
          ? const EmptyState(
              message: 'Alhamdulillah, tidak ada catatan sanksi',
              icon: Icons.verified_rounded,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: dummySanksi.length,
              itemBuilder: (context, index) {
                final item = dummySanksi[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.jenisSanksi,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: FeatureScaffold.navy,
                                ),
                              ),
                            ),
                            StatusBadge.auto(item.tingkat),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InfoRow(label: 'Tanggal', value: item.tanggal),
                        const SizedBox(height: 6),
                        Text(
                          item.keterangan,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF7F8C8D),
                          ),
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
