import 'package:flutter/material.dart';
import '../../models/pegawai_data.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

class TunjanganPendidikanScreen extends StatelessWidget {
  const TunjanganPendidikanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Tunjangan Pendidikan',
      subtitle: 'Riwayat pencairan tunjangan pendidikan',
      icon: Icons.account_balance_wallet_rounded,
      child: dummyGaji13.isEmpty
          ? const EmptyState(message: 'Belum ada data Tunjangan Pendidikan')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: dummyGaji13.length,
              itemBuilder: (context, index) {
                final item = dummyGaji13[index];
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
  }
}