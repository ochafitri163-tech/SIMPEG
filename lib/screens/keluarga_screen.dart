import 'package:flutter/material.dart';
import '../models/pegawai_data.dart';
import '../widgets/feature_scaffold.dart';

class KeluargaScreen extends StatelessWidget {
  const KeluargaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Data Keluarga',
      subtitle: 'Daftar anggota keluarga pegawai',
      icon: Icons.family_restroom_rounded,
      child: dummyKeluarga.isEmpty
          ? const EmptyState(message: 'Belum ada data keluarga')
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: dummyKeluarga.length,
              itemBuilder: (context, index) {
                final item = dummyKeluarga[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InfoCard(
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1E7F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Color(0xFF8E44AD), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.nama,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: FeatureScaffold.navy,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: item.hubungan,
                                    color: const Color(0xFF8E44AD),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Lahir: ${item.tanggalLahir}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              Text(
                                'Pekerjaan: ${item.pekerjaan}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                            ],
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
