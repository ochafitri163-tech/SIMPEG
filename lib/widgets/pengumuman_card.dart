import 'package:flutter/material.dart';
import '../models/pengaduan_model.dart' show formatTanggalJam;
import '../models/pengumuman_model.dart';

const Color _navy = Color(0xFF0D2C6E);
const Color _accent = Color(0xFF2E86AB);

/// Menampilkan modal/pop-up detail sebuah pengumuman: judul, isi lengkap,
/// tanggal & waktu publikasi, nama pembuat (SDM), dan tombol Tutup.
///
/// Dipakai bersama oleh Card Pengumuman di dashboard maupun halaman
/// riwayat "Berita Pengumuman" agar tampilannya konsisten.
Future<void> showPengumumanDetail(BuildContext context, Pengumuman p) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark ? const Color(0xFF1B2230) : Colors.white;
  final textColor = isDark ? Colors.white : const Color(0xFF1B2733);
  final subColor = isDark ? const Color(0xFF9AA6B2) : const Color(0xFF7F8C8D);

  return showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header gradasi + ikon megafon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_navy, _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
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
                          const Text(
                            'Pengumuman',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.judul,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!p.aktif)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Nonaktif',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              // Isi lengkap
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.isi,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Divider(color: subColor.withValues(alpha: 0.25)),
                      const SizedBox(height: 8),
                      _metaRow(Icons.event_rounded, 'Dipublikasikan',
                          formatTanggalJam(p.tanggalPublikasi), subColor,
                          textColor),
                      const SizedBox(height: 8),
                      _metaRow(Icons.person_rounded, 'Pembuat',
                          '${p.pembuat} (SDM)', subColor, textColor),
                    ],
                  ),
                ),
              ),
              // Tombol Tutup
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

Widget _metaRow(IconData icon, String label, String value, Color subColor,
    Color textColor) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: _accent),
      const SizedBox(width: 8),
      Text('$label: ',
          style: TextStyle(fontSize: 12.5, color: subColor)),
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

/// Card Pengumuman untuk dashboard kelima role (Pegawai, Kadiv, KSPI,
/// TPDPK, Direktur).
///
/// Ketentuan:
/// - Memakai stream realtime, jadi otomatis ter-update saat SDM
///   menambah / mengubah / menghapus / (batal) publikasi pengumuman.
/// - Card HANYA muncul bila ada minimal satu pengumuman aktif. Bila tidak
///   ada, mengembalikan [SizedBox.shrink] sehingga card tidak tampil sama
///   sekali (bukan sekadar kosong).
/// - Menampilkan judul, ringkasan 2–3 baris, tanggal publikasi, dan tombol
///   "Lihat Detail" yang membuka pop-up detail.
class PengumumanCard extends StatelessWidget {
  /// Dipanggil saat menekan "Lihat semua" untuk membuka halaman riwayat
  /// Berita Pengumuman. Bila null, tautan "Lihat semua" disembunyikan.
  final VoidCallback? onLihatSemua;

  const PengumumanCard({super.key, this.onLihatSemua});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pengumuman>>(
      stream: PengumumanService.streamAktif(),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Pengumuman>[];
        // Tidak ada pengumuman aktif -> card tidak ditampilkan sama sekali.
        if (list.isEmpty) return const SizedBox.shrink();

        final utama = list.first;
        final sisa = list.length - 1;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF6E9), Color(0xFFFDEFDA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFF3D9B0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE67E22).withValues(alpha: 0.10),
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
                          color: const Color(0xFFE67E22)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.campaign_rounded,
                            color: Color(0xFFD35400), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'PENGUMUMAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Color(0xFFB9611A),
                          ),
                        ),
                      ),
                      if (onLihatSemua != null)
                        InkWell(
                          onTap: onLihatSemua,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text('Lihat semua',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB9611A))),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    utama.judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A431A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    utama.ringkasan,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFF6B4B2A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 13, color: Color(0xFFB9611A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          formatTanggalJam(utama.tanggalPublikasi),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB9611A)),
                        ),
                      ),
                      if (sisa > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('+$sisa lainnya',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB9611A))),
                        ),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              showPengumumanDetail(context, utama),
                          icon: const Icon(Icons.visibility_rounded,
                              size: 15),
                          label: const Text('Lihat Detail',
                              style: TextStyle(fontSize: 11.5)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD35400),
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
