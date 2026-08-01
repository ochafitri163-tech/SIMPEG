import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pengaduan_model.dart' show formatTanggalJam;
import '../models/pengumuman_model.dart';
import '../models/user_role.dart';

const Color _navy = Color(0xFF0D2C6E);
const Color _accent = Color(0xFF2E86AB);
const Color _danger = Color(0xFFD35400);

/// Modal/pop-up detail pengumuman: judul, isi lengkap, prioritas, tanggal &
/// waktu publikasi, nama pembuat (SDM), lampiran (bila ada), tombol Tutup.
/// Membuka detail sekaligus menandai pengumuman sebagai sudah dibaca.
Future<void> showPengumumanDetail(BuildContext context, Pengumuman p) async {
  // Tandai sudah dibaca (tidak blocking bila gagal).
  PengumumanService.tandaiDibaca(p.id);

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark ? const Color(0xFF1B2230) : Colors.white;
  final textColor = isDark ? Colors.white : const Color(0xFF1B2733);
  final subColor = isDark ? const Color(0xFF9AA6B2) : const Color(0xFF7F8C8D);

  await showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_navy, _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Pengumuman',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                              if (p.isPenting) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE74C3C),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('PENTING',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(p.judul,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.isi,
                          style: TextStyle(
                              fontSize: 14, height: 1.55, color: textColor)),
                      if (p.adaLampiran) ...[
                        const SizedBox(height: 16),
                        _LampiranTile(
                            nama: p.lampiranNama ?? 'Lampiran',
                            url: p.lampiranUrl!),
                      ],
                      const SizedBox(height: 18),
                      Divider(color: subColor.withValues(alpha: 0.25)),
                      const SizedBox(height: 8),
                      _metaRow(Icons.event_rounded, 'Dipublikasikan',
                          formatTanggalJam(p.tanggalPublikasi), subColor,
                          textColor),
                      const SizedBox(height: 8),
                      _metaRow(Icons.person_rounded, 'Pembuat',
                          '${p.pembuat} (SDM)', subColor, textColor),
                      if (p.kedaluwarsaPada != null) ...[
                        const SizedBox(height: 8),
                        _metaRow(Icons.timer_off_rounded, 'Berlaku s/d',
                            formatTanggalJam(p.kedaluwarsaPada!), subColor,
                            textColor),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tutup',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LampiranTile extends StatelessWidget {
  final String nama;
  final String url;
  const _LampiranTile({required this.nama, required this.url});

  Future<void> _buka(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka lampiran.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _buka(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 18, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _accent)),
            ),
            const Icon(Icons.open_in_new_rounded, size: 15, color: _accent),
          ],
        ),
      ),
    );
  }
}

Widget _metaRow(IconData icon, String label, String value, Color subColor,
    Color textColor) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: _accent),
      const SizedBox(width: 8),
      Text('$label: ', style: TextStyle(fontSize: 12.5, color: subColor)),
      Expanded(
        child: Text(value,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textColor)),
      ),
    ],
  );
}

/// Card Pengumuman untuk dashboard kelima role (bukan SDM).
///
/// - Memakai stream realtime -> otomatis ter-update saat SDM menambah/
///   mengubah/menghapus/(batal) publikasi.
/// - Hanya memfilter pengumuman yang SEDANG TAYANG untuk [role].
/// - Bila tidak ada, mengembalikan [SizedBox.shrink] (card tidak muncul).
class PengumumanCard extends StatelessWidget {
  final UserRole role;
  final VoidCallback? onLihatSemua;

  const PengumumanCard({super.key, required this.role, this.onLihatSemua});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pengumuman>>(
      stream: PengumumanService.streamTayang(role),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Pengumuman>[];
        if (list.isEmpty) return const SizedBox.shrink();

        final utama = list.first;
        final sisa = list.length - 1;
        final penting = utama.isPenting;
        final baseColor = penting ? const Color(0xFFE74C3C) : _danger;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: penting
                    ? const [Color(0xFFFDECEA), Color(0xFFFAD7D2)]
                    : const [Color(0xFFFFF6E9), Color(0xFFFDEFDA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: penting
                      ? const Color(0xFFF1B0A8)
                      : const Color(0xFFF3D9B0)),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: baseColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                            utama.disematkan
                                ? Icons.push_pin_rounded
                                : Icons.campaign_rounded,
                            color: baseColor,
                            size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          penting ? 'PENGUMUMAN PENTING' : 'PENGUMUMAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: penting
                                ? const Color(0xFFC0392B)
                                : const Color(0xFFB9611A),
                          ),
                        ),
                      ),
                      if (onLihatSemua != null)
                        InkWell(
                          onTap: onLihatSemua,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text('Lihat semua',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: penting
                                        ? const Color(0xFFC0392B)
                                        : const Color(0xFFB9611A))),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(utama.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7A431A))),
                  const SizedBox(height: 4),
                  Text(utama.ringkasan,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Color(0xFF6B4B2A))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.event_rounded,
                          size: 13, color: baseColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(formatTanggalJam(utama.tanggalPublikasi),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: baseColor)),
                      ),
                      if (utama.adaLampiran)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.attach_file_rounded,
                              size: 14, color: baseColor),
                        ),
                      if (sisa > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('+$sisa lainnya',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: baseColor)),
                        ),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              showPengumumanDetail(context, utama),
                          icon: const Icon(Icons.visibility_rounded, size: 15),
                          label: const Text('Lihat Detail',
                              style: TextStyle(fontSize: 11.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: baseColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
