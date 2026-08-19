import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/dokumen_service.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';

/// Kartu "Dokumen Resmi Pegawai (SDM)" pada halaman Profil — menampilkan
/// Surat Kerja (SK) & Surat Diklat/Pelatihan resmi milik pegawai yang
/// diterbitkan & diunggah oleh SDM. Untuk pegawai/role lain, halaman ini
/// hanya bersifat lihat (view) & unduh — tidak ada opsi unggah/hapus di
/// sini; pengunggahan tetap dilakukan SDM lewat menu Dokumen Kepegawaian.
class DokumenResmiScreen extends StatefulWidget {
  final AppUser user;
  const DokumenResmiScreen({super.key, required this.user});

  @override
  State<DokumenResmiScreen> createState() => _DokumenResmiScreenState();
}

class _DokumenResmiScreenState extends State<DokumenResmiScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color accent = Color(0xFF2E86AB);

  late Future<List<DokumenKepegawaian>> _future;

  @override
  void initState() {
    super.initState();
    _future = DokumenService.dokumenResmiSaya();
  }

  void _refresh() => setState(() => _future = DokumenService.dokumenResmiSaya());

  Future<void> _buka(DokumenKepegawaian d) async {
    final uri = Uri.tryParse(d.fileUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tidak dapat membuka dokumen.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.pageBackground(context),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 14,
              left: 20,
              right: 20,
              bottom: 22,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF081A45), Color(0xFF1F5F79)]
                    : const [navy, accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chevron_left_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Dokumen Resmi Pegawai',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Surat Kerja & Surat Diklat dari SDM',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DokumenKepegawaian>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Gagal memuat: ${snapshot.error}'));
                }
                final items = snapshot.data ?? const <DokumenKepegawaian>[];
                final sk = items.where((d) => d.kategori == 'SK').toList();
                final diklat =
                    items.where((d) => d.kategori == 'Diklat').toList();

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.cardShadow(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dokumen Resmi Pegawai (SDM)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Surat Kerja & Surat Diklat resmi yang diterbitkan dan diunggah oleh SDM.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _KategoriCard(
                              badgeLabel: 'Surat Kerja (SK)',
                              badgeColor: const Color(0xFF27AE60),
                              badgeIcon: Icons.description_rounded,
                              defaultTitle: 'Surat Keputusan',
                              dokumen: sk.isNotEmpty ? sk.first : null,
                              onBuka: _buka,
                            ),
                            const SizedBox(height: 14),
                            _KategoriCard(
                              badgeLabel: 'Surat Diklat / Pelatihan',
                              badgeColor: const Color(0xFF8E44AD),
                              badgeIcon: Icons.school_rounded,
                              defaultTitle: 'Sertifikat Diklat & Pelatihan',
                              dokumen:
                                  diklat.isNotEmpty ? diklat.first : null,
                              onBuka: _buka,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KategoriCard extends StatelessWidget {
  final String badgeLabel;
  final Color badgeColor;
  final IconData badgeIcon;
  final String defaultTitle;
  final DokumenKepegawaian? dokumen;
  final Future<void> Function(DokumenKepegawaian) onBuka;

  const _KategoriCard({
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeIcon,
    required this.defaultTitle,
    required this.dokumen,
    required this.onBuka,
  });

  static const Color navy = Color(0xFF0D2C6E);
  static const Color accent = Color(0xFF2E86AB);

  @override
  Widget build(BuildContext context) {
    final d = dokumen;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 13, color: badgeColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          badgeLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (d != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 11, color: AppColors.textSecondary(context)),
                    const SizedBox(width: 4),
                    Text(
                      _formatTanggalSingkat(d.dibuatPada),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d?.judul ?? defaultTitle,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            d == null
                ? 'Belum ada dokumen yang diunggah SDM.'
                : 'No: ${d.nomor?.trim().isNotEmpty == true ? d.nomor : '-'}',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: d == null ? null : () => onBuka(d),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View File'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary(context),
                    side: BorderSide(color: AppColors.divider(context)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: d == null ? null : () => onBuka(d),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    disabledBackgroundColor:
                        accent.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTanggalSingkat(DateTime d) {
    // yyyy-MM-dd, selaras dengan format tanggal pada contoh tampilan.
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}