import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/pengumuman_model.dart';
import '../../widgets/feature_scaffold.dart';

/// Halaman Penuh (Full Screen) untuk Detail Pengumuman
class PengumumanDetailScreen extends StatefulWidget {
  final Pengumuman pengumuman;

  const PengumumanDetailScreen({
    super.key,
    required this.pengumuman,
  });

  @override
  State<PengumumanDetailScreen> createState() => _PengumumanDetailScreenState();
}

class _PengumumanDetailScreenState extends State<PengumumanDetailScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  @override
  void initState() {
    super.initState();
    // Otomatis tandai pengumuman sebagai sudah dibaca
    PengumumanService.tandaiDibaca(widget.pengumuman.id).catchError((_) {});
  }

  bool _isGambar(String url, String nama) {
    final lower = '${url.toLowerCase()} ${nama.toLowerCase()}';
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif');
  }

  Future<void> _bukaLampiran(String url) async {
    if (url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pengumuman;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1B2230) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF14213D);
    final subColor = isDark ? const Color(0xFFAAB4C3) : const Color(0xFF6C7A90);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    final bool adaLampiran = (p.lampiranUrl != null && p.lampiranUrl!.trim().isNotEmpty);
    final bool adaGambar = adaLampiran && _isGambar(p.lampiranUrl!, p.lampiranNama ?? '');
    final String isiTampil = p.isi.trim().isNotEmpty ? p.isi : p.ringkasan;

    return FeatureScaffold(
      title: 'Detail Pengumuman',
      subtitle: 'Informasi dan Berita Resmi PDAM',
      icon: Icons.campaign_rounded,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // KARTU UTAMA PENGUMUMAN
            // ==========================================
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges & Prioritas
                  Row(
                    children: [
                      if (p.isPenting) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE74C3C).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.priority_high_rounded, size: 14, color: Color(0xFFE74C3C)),
                              SizedBox(width: 4),
                              Text(
                                'PENTING',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE74C3C),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.pembuat.trim().isNotEmpty ? p.pembuat : 'SDM & Umum',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatTanggalJam(p.tanggalPublikasi),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Judul Pengumuman
                  Text(
                    p.judul,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: 16),

                  // Gambar Utama (bila ada)
                  if (adaGambar) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        width: double.infinity,
                        color: Colors.black.withValues(alpha: 0.04),
                        child: Image.network(
                          p.lampiranUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Isi Pengumuman
                  Text(
                    isiTampil,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: textColor,
                      height: 1.65,
                    ),
                  ),

                  // Lampiran Dokumen / PDF (bila bukan gambar)
                  if (adaLampiran && !adaGambar) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242E40) : const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _navy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.attach_file_rounded, color: _navy, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.lampiranNama ?? 'Dokumen Lampiran',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Ketuk tombol untuk membuka/mengunduh berkas',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6C7A90),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _bukaLampiran(p.lampiranUrl!),
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: const Text('Buka'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
