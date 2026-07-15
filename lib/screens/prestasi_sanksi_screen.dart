import 'package:flutter/material.dart';
import '../models/pegawai_data.dart';
import '../widgets/feature_scaffold.dart';

/// Halaman Prestasi & Sanksi — gabungan riwayat penghargaan/prestasi
/// (belum ada data) dan catatan sanksi/disiplin pegawai, ditampilkan
/// dalam dua tab segmented di bawah header FeatureScaffold.
class PrestasiSanksiScreen extends StatefulWidget {
  const PrestasiSanksiScreen({super.key});

  @override
  State<PrestasiSanksiScreen> createState() => _PrestasiSanksiScreenState();
}

class _PrestasiSanksiScreenState extends State<PrestasiSanksiScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Prestasi & Sanksi',
      subtitle: 'Riwayat penghargaan dan catatan disiplin',
      icon: Icons.workspace_premium_rounded,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: _SegmentButton(
                    label: 'Prestasi',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SegmentButton(
                    label: 'Sanksi',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0 ? _buildPrestasi() : _buildSanksi(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrestasi() {
    return const EmptyState(
      message: 'Belum ada catatan prestasi/penghargaan',
      icon: Icons.emoji_events_rounded,
    );
  }

  Widget _buildSanksi() {
    if (dummySanksi.isEmpty) {
      return const EmptyState(
        message: 'Alhamdulillah, tidak ada catatan sanksi',
        icon: Icons.verified_rounded,
      );
    }
    return ListView.builder(
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
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF7F8C8D)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FeatureScaffold.navy : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected ? null : Border.all(color: const Color(0xFFEDF1F5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF7F8C8D),
            ),
          ),
        ),
      ),
    );
  }
}