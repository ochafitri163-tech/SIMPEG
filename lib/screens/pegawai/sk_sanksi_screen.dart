import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/pengaduan_model.dart';
import '../../models/sk_sanksi_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feature_scaffold.dart';

/// =============================================================
/// PEGAWAI — SK SANKSI SAYA
///
/// Menampilkan SK yang diterbitkan SDM untuk pegawai yang sedang login,
/// lengkap dengan empat dokumen wajibnya (SK, bukti pelanggaran, surat
/// hasil investigasi SPI, dan keputusan direksi) sehingga pegawai bisa
/// melihat dasar keputusannya secara utuh.
/// =============================================================
class SkSanksiScreen extends StatefulWidget {
  const SkSanksiScreen({super.key});

  @override
  State<SkSanksiScreen> createState() => _SkSanksiScreenState();
}

class _SkSanksiScreenState extends State<SkSanksiScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _red = Color(0xFFE74C3C);

  late Future<List<SkSanksi>> _future;

  @override
  void initState() {
    super.initState();
    _future = SkSanksiService.untukSaya();
  }

  Future<void> _refresh() async {
    setState(() => _future = SkSanksiService.untukSaya());
    await _future;
  }

  Future<void> _buka(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka dokumen.')),
      );
    }
  }

  String _namaFile(String url) {
    final tanpaQuery = url.split('?').first;
    var nama = tanpaQuery.split('/').last;
    final pisah = nama.split('_');
    if (pisah.length > 1 && int.tryParse(pisah.first) != null) {
      nama = pisah.sublist(1).join('_');
    }
    return nama;
  }

  String _rupiah(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'SK Sanksi',
      subtitle: 'Surat keputusan & dokumen pendukungnya',
      icon: Icons.gavel_rounded,
      child: FutureBuilder<List<SkSanksi>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'Gagal memuat SK: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 13),
                ),
              ),
            );
          }

          final data = snapshot.data ?? [];
          if (data.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  EmptyState(
                    message: 'Tidak ada SK sanksi atas nama Anda',
                    icon: Icons.verified_rounded,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: data.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _kartuSk(data[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kartuSk(SkSanksi sk) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sk.nomorSk,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                  ),
                ),
              ),
              StatusBadge.auto(sk.tingkat),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sk.jenisSanksi,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          if (sk.perubahanJabatan != null)
            _barisPerubahan(
                Icons.badge_rounded, 'Jabatan', sk.perubahanJabatan!),
          if (sk.perubahanGolongan != null)
            _barisPerubahan(
                Icons.grade_rounded, 'Golongan', sk.perubahanGolongan!),
          if (sk.nominalPenurunanGaji > 0)
            _barisPerubahan(
              Icons.trending_down_rounded,
              'Penyesuaian payment',
              '- ${_rupiah(sk.nominalPenurunanGaji)} / periode',
              warna: _red,
            ),
          const SizedBox(height: 4),
          InfoRow(
              label: 'Berlaku sejak',
              value: formatTanggalIndonesia(sk.tanggalBerlaku)),
          if ((sk.disetujuiOleh ?? '').isNotEmpty)
            InfoRow(label: 'Disetujui oleh', value: sk.disetujuiOleh!),
          if ((sk.diterbitkanOleh ?? '').isNotEmpty)
            InfoRow(label: 'Diterbitkan oleh', value: sk.diterbitkanOleh!),
          if ((sk.ringkasanPelanggaran ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sk.ringkasanPelanggaran!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.divider(context)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                sk.dokumenLengkap
                    ? Icons.folder_special_rounded
                    : Icons.folder_off_rounded,
                size: 16,
                color: _navy,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Dokumen pendukung \u00b7 ${sk.totalBerkas} berkas',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final jenis in JenisDokumenSk.values)
            _grupDokumen(jenis, sk.dokumen[jenis] ?? const []),
          // Dokumen pendukung lain yang ditambahkan SDM (opsional).
          for (final tambahan in sk.tambahan)
            _grupBerkas(tambahan.judul, tambahan.berkas, tambahan: true),
        ],
      ),
    );
  }

  Widget _barisPerubahan(IconData icon, String label, String nilai,
      {Color warna = _navy}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: warna),
          const SizedBox(width: 7),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary(context))),
          Expanded(
            child: Text(
              nilai,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: warna),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grupDokumen(JenisDokumenSk jenis, List<String> berkas) =>
      _grupBerkas(jenis.label, berkas);

  Widget _grupBerkas(String judul, List<String> berkas,
      {bool tambahan = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tambahan
                    ? Icons.attach_file_rounded
                    : berkas.isEmpty
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                size: 14,
                color: tambahan
                    ? _accent
                    : berkas.isEmpty
                        ? _red
                        : const Color(0xFF27AE60),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  judul,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          if (berkas.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 3),
              child: Text('Belum tersedia.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context))),
            )
          else
            for (final url in berkas)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 5),
                child: InkWell(
                  onTap: () => _buka(url),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.description_rounded,
                            size: 15, color: _accent),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _namaFile(url),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded,
                            size: 14,
                            color: AppColors.textSecondary(context)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
