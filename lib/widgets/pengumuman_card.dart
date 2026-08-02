import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pengaduan_model.dart' show formatTanggalJam;
import '../models/pengumuman_model.dart';
import '../models/user_role.dart';

const Color _navy = Color(0xFF0D2C6E);
const Color _accent = Color(0xFF2E86AB);

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

/// Pop-up "Info Terbaru" bergaya bottom-sheet (meniru desain kartu info
/// modern): banner gambar/gradien di atas + tombol tutup (X), badge
/// "INFO TERBARU"/"PENTING", judul besar, ringkasan isi, lalu dua tombol
/// aksi: "Nanti" (tutup) & "Baca Detail" (buka detail lengkap).
/// Dipakai untuk pop-up otomatis saat dashboard dibuka.
Future<void> showPengumumanPopup(BuildContext context, Pengumuman p) async {
  // Tandai sudah dibaca (tidak blocking bila gagal).
  PengumumanService.tandaiDibaca(p.id);

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark ? const Color(0xFF1B2230) : Colors.white;
  final textColor = isDark ? Colors.white : const Color(0xFF15233A);
  final subColor = isDark ? const Color(0xFF9AA6B2) : const Color(0xFF6B7A90);

  final bool adaGambar = p.adaLampiran &&
      RegExp(r'\.(png|jpe?g|webp|gif)(\?.*)?$', caseSensitive: false)
          .hasMatch(p.lampiranNama ?? p.lampiranUrl ?? '');
  final penting = p.isPenting;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Banner atas (gambar lampiran atau gradien dekoratif) ----
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_navy, _accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      image: adaGambar
                          ? DecorationImage(
                              image: NetworkImage(p.lampiranUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: adaGambar
                        ? null
                        : Stack(
                            children: [
                              Positioned(
                                right: -20,
                                top: -20,
                                child: Icon(Icons.campaign_rounded,
                                    size: 160,
                                    color:
                                        Colors.white.withValues(alpha: 0.10)),
                              ),
                              Positioned(
                                left: 24,
                                bottom: 22,
                                child: Icon(Icons.water_drop_rounded,
                                    size: 46,
                                    color:
                                        Colors.white.withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                  ),
                ),
                // Tombol tutup (X) di pojok kanan atas banner.
                Positioned(
                  top: 12,
                  right: 12,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF15233A), size: 20),
                    ),
                  ),
                ),
              ],
            ),
            // ---- Konten putih ----
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge INFO TERBARU / PENTING
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: penting
                          ? const Color(0xFFFDECEA)
                          : const Color(0xFFE7F2FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          penting
                              ? Icons.priority_high_rounded
                              : Icons.auto_awesome_rounded,
                          size: 15,
                          color: penting
                              ? const Color(0xFFE74C3C)
                              : const Color(0xFF1E88C5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          penting ? 'PENTING' : 'INFO TERBARU',
                          style: TextStyle(
                            color: penting
                                ? const Color(0xFFE74C3C)
                                : const Color(0xFF1E88C5),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Judul besar
                  Text(
                    p.judul,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Ringkasan isi
                  Text(
                    p.ringkasan,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Tombol aksi: Nanti (tutup) & Baca Detail (detail lengkap)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: subColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Nanti',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          showPengumumanDetail(context, p);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88C5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Baca Detail',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  SizedBox(
                      height: MediaQuery.of(ctx).viewPadding.bottom + 6),
                ],
              ),
            ),
          ],
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

/// Kartu "Berita & Pengumuman" gaya banner untuk dashboard kelima role
/// (bukan SDM). Ditampilkan di bagian bawah Beranda.
///
/// - Memakai stream realtime -> otomatis ter-update saat SDM menambah/
///   mengubah/menghapus/(batal) publikasi.
/// - Hanya memfilter pengumuman yang SEDANG TAYANG untuk [role].
/// - Bila tidak ada, mengembalikan [SizedBox.shrink] (kartu tidak muncul).
/// - Menyentuh kartu membuka pop-up detail (showPengumumanDetail).
class PengumumanCard extends StatefulWidget {
  final UserRole role;
  final VoidCallback? onLihatSemua;

  const PengumumanCard({super.key, required this.role, this.onLihatSemua});

  @override
  State<PengumumanCard> createState() => _PengumumanCardState();
}

class _PengumumanCardState extends State<PengumumanCard> {
  final PageController _pc = PageController();
  int _current = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pengumuman>>(
      stream: PengumumanService.streamTayang(widget.role),
      builder: (context, snapshot) {
        final list = snapshot.data ?? const <Pengumuman>[];
        if (list.isEmpty) return const SizedBox.shrink();

        // Index halaman aktif untuk indikator titik, dijaga tetap valid
        // bila jumlah pengumuman berubah (mis. ada yang dihapus).
        final aktif = _current.clamp(0, list.length - 1);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Berita & Pengumuman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2733),
                      ),
                    ),
                  ),
                  if (widget.onLihatSemua != null)
                    InkWell(
                      onTap: widget.onLihatSemua,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text('Lihat semua',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _accent)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Satu pengumuman: kartu tunggal. Lebih dari satu: carousel
              // yang bisa DIGESER KE SAMPING, dengan indikator titik di bawah.
              if (list.length == 1)
                _banner(context, list.first)
              else ...[
                SizedBox(
                  height: 168,
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: list.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (context, i) => _banner(context, list[i]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(list.length, (i) {
                    final isAktif = i == aktif;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isAktif ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isAktif
                            ? _accent
                            : _accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Satu kartu banner pengumuman. Dipakai untuk kartu tunggal maupun tiap
  /// halaman carousel ketika pengumuman lebih dari satu (geser ke samping).
  Widget _banner(BuildContext context, Pengumuman p) {
    final penting = p.isPenting;
    final bool adaGambar = p.adaLampiran &&
        RegExp(r'\.(png|jpe?g|webp|gif)(\?.*)?$', caseSensitive: false)
            .hasMatch(p.lampiranNama ?? p.lampiranUrl ?? '');

    return InkWell(
      onTap: () => showPengumumanDetail(context, p),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 168,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2C6E), Color(0xFF123A85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: adaGambar
              ? DecorationImage(
                  image: NetworkImage(p.lampiranUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.35),
                    BlendMode.darken,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            if (!adaGambar)
              Positioned(
                right: -12,
                top: -12,
                child: Icon(
                  Icons.campaign_rounded,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            if (penting)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE74C3C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PENTING',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_rounded,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          formatTanggalJam(p.tanggalPublikasi),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
