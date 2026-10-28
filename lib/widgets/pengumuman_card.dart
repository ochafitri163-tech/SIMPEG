import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pengaduan_model.dart' show formatTanggalJam;
import '../models/pengumuman_model.dart';
import '../models/user_role.dart';

const Color _navy = Color(0xFF0D2C6E);
const Color _accent = Color(0xFF2E86AB);

/// Widget bantu untuk animasi masuk bertahap (staggered fade + slide-up).
/// Dipakai agar elemen-elemen pop-up (badge, judul, ringkasan, tombol)
/// muncul satu demi satu, bukan sekaligus, memberi kesan lebih hidup.
class _StaggerIn extends StatefulWidget {
  final Widget child;
  final int index;
  const _StaggerIn({
    required this.child,
    this.index = 0,
  });

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 70) * widget.index, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Mengecek apakah lampiran pengumuman berupa berkas gambar (berdasarkan
/// ekstensi nama file / URL), sehingga bisa ditampilkan sebagai banner foto
/// alih-alih tautan unduhan biasa.
bool _lampiranAdalahGambar(Pengumuman p) {
  if (!p.adaLampiran) return false;
  final sumber = p.lampiranNama ?? p.lampiranUrl ?? '';
  return RegExp(r'\.(png|jpe?g|webp|gif|heic)(\?.*)?$', caseSensitive: false)
      .hasMatch(sumber);
}

/// Menampilkan gambar penuh layar dengan dukungan pinch-to-zoom, dibuka
/// dengan menekan banner lampiran pada detail pengumuman.
Future<void> _bukaGambarPenuh(BuildContext context, String url) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      pageBuilder: (context, animation, __) {
        return FadeTransition(
          opacity: animation,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 5,
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white70),
                          );
                        },
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: Colors.white54, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: SafeArea(
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
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

/// Modal/pop-up detail pengumuman: topbar solid, badge PENTING, kartu info
/// (tanggal publikasi, pembuat, kedaluwarsa), kartu isi pengumuman,
/// lampiran (bila ada), dan tombol Tutup. Membuka detail sekaligus
/// menandai pengumuman sebagai sudah dibaca.
/// Modal/pop-up detail pengumuman: topbar solid, gambar rounded (bila ada),
/// badge PENTING, kartu info mini (tanggal publikasi, pembuat, kedaluwarsa),
/// kartu isi pengumuman, lampiran (bila ada), dan tombol Tutup. Membuka
/// detail sekaligus menandai pengumuman sebagai sudah dibaca.
Future<void> showPengumumanDetail(BuildContext context, Pengumuman p) async {
  // Berlaku untuk seluruh role karena semua dashboard memakai fungsi bersama ini.
  PengumumanService.tandaiDibaca(p.id).catchError((_) {});

  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final bool adaGambar = _lampiranAdalahGambar(p);
  final String isiTampil = p.isi.trim().isNotEmpty ? p.isi : p.ringkasan;

  final Color surface = isDark ? const Color(0xFF172033) : Colors.white;
  final Color textColor = isDark ? Colors.white : const Color(0xFF171A21);
  final Color subColor =
      isDark ? const Color(0xFFB3BBC8) : const Color(0xFF7B818C);
  final Color dividerColor =
      isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE9EBEF);
  final Color chipColor =
      isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEDF8FC);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        // Saat dibuka hanya tampil sekitar setengah layar seperti referensi.
        initialChildSize: 0.62,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        expand: false,
        snap: true,
        snapSizes: const [0.62, 0.94],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(top: 12, bottom: 18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.22)
                            : const Color(0xFFD8DADF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    24 + MediaQuery.paddingOf(sheetContext).bottom,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      if (adaGambar) ...[
                        Hero(
                          tag: 'pengumuman-image-${p.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _bukaGambarPenuh(
                                context,
                                p.lampiranUrl!,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: AspectRatio(
                                  aspectRatio: 16 / 10,
                                  child: Image.network(
                                    p.lampiranUrl!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return ColoredBox(
                                        color: chipColor,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: _accent,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) {
                                      return ColoredBox(
                                        color: chipColor,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: _accent,
                                            size: 42,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Informasi ringkas tanpa label "Dipublikasikan",
                      // "Pembuat", atau "Berlaku s/d".
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: _accent,
                                  size: 17,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatTanggalJam(p.tanggalTayang),
                                  style: const TextStyle(
                                    color: _accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  color: subColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    p.pembuat,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),

                      // Judul utama besar dan tebal seperti referensi.
                      Text(
                        p.judul,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 30,
                          height: 1.18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(height: 1, thickness: 1, color: dividerColor),
                      const SizedBox(height: 28),

                      // Isi langsung ditampilkan tanpa heading "Isi Pengumuman".
                      // Font normal/tipis agar nyaman dibaca.
                      SelectableText(
                        isiTampil,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 17,
                          height: 1.72,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.05,
                        ),
                      ),

                      if (p.adaLampiran && !adaGambar) ...[
                        const SizedBox(height: 28),
                        Material(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final uri = Uri.tryParse(p.lampiranUrl!);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.attach_file_rounded,
                                    color: _accent,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      p.lampiranNama ?? 'Buka lampiran',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.open_in_new_rounded,
                                    color: _accent,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Pop-up "Info Terbaru" versi minimalis: hero-image mengambang lebih
/// ringkas (150px) di atas body card, tombol tutup (X) melayang lebih
/// kecil, badge PENTING/INFO + chip tanggal ringkas, judul kapital, dan
/// dua tombol aksi: "Nanti" (ukuran tetap agar tidak overflow di layar
/// sempit) & "Baca Detail" (fleksibel, buka detail lengkap). Dipakai untuk
/// pop-up otomatis saat dashboard dibuka.
Future<void> showPengumumanPopup(BuildContext context, Pengumuman p) async {
  // Tandai sudah dibaca, tetapi jangan sampai error mengganggu UI.
  PengumumanService.tandaiDibaca(p.id).catchError((_) {});

  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final bool adaGambar = _lampiranAdalahGambar(p);
  final bool penting = p.isPenting;

  final Color surface = isDark ? const Color(0xFF161F2E) : Colors.white;
  final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
  final Color subColor =
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  final Color badgeColor =
      penting ? const Color(0xFFEF4444) : const Color(0xFF0284C7);

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup pengumuman',
    barrierColor: Colors.black.withValues(alpha: 0.60),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, secondaryAnim) {
      final Size screen = MediaQuery.of(ctx).size;
      final double horizontalPad = screen.width < 360 ? 12.0 : 20.0;
      final double popupWidth = (screen.width - (horizontalPad * 2)).clamp(280.0, 390.0);

      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 24),
            child: Container(
              width: popupWidth,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: (penting ? const Color(0xFFEF4444) : _navy)
                        .withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // =======================================================
                    // HEADER ELEGAN / HERO BANNER
                    // =======================================================
                    Stack(
                      children: [
                        Container(
                          height: adaGambar ? 175 : 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: adaGambar
                                ? null
                                : LinearGradient(
                                    colors: penting
                                        ? const [
                                            Color(0xFF8B0000),
                                            Color(0xFFDC2626),
                                            Color(0xFFEF4444),
                                          ]
                                        : const [
                                            Color(0xFF071938),
                                            Color(0xFF0D2C6E),
                                            Color(0xFF1E5BB0),
                                          ],
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
                          child: Stack(
                            children: [
                              if (!adaGambar) ...[
                                Positioned(
                                  right: -25,
                                  top: -25,
                                  child: Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.07),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: -35,
                                  bottom: -35,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.05),
                                    ),
                                  ),
                                ),
                              ],
                              if (adaGambar)
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.35),
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.60),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              Center(
                                child: _StaggerIn(
                                  index: 0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white
                                              .withValues(alpha: 0.16),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.30),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.18),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          penting
                                              ? Icons.campaign_rounded
                                              : Icons
                                                  .notifications_active_rounded,
                                          color: Colors.white,
                                          size: 27,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.28),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          penting
                                              ? 'PENGUMUMAN PENTING'
                                              : 'PENGUMUMAN TERBARU',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tombol Close terintegrasi rapi
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _TapScale(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.32),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // =======================================================
                    // BODY DETAIL
                    // =======================================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge status & Waktu
                          _StaggerIn(
                            index: 1,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(
                                      alpha: isDark ? 0.20 : 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: badgeColor.withValues(
                                        alpha: isDark ? 0.35 : 0.20,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        penting
                                            ? Icons.priority_high_rounded
                                            : Icons.campaign_rounded,
                                        size: 14,
                                        color: badgeColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        penting ? 'PENTING' : 'INFO',
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 13,
                                        color: subColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          formatTanggalJam(p.tanggalTayang),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Judul Pengumuman
                          _StaggerIn(
                            index: 2,
                            child: Text(
                              p.judul,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Ringkasan dalam Card Preview
                          _StaggerIn(
                            index: 3,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : const Color(0xFFEDF2F7),
                                ),
                              ),
                              child: Text(
                                p.ringkasan,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF475569),
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),

                          if (p.adaLampiran) ...[
                            const SizedBox(height: 10),
                            _StaggerIn(
                              index: 4,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.attach_file_rounded,
                                    size: 14,
                                    color: _accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      p.lampiranNama ??
                                          'Memiliki berkas lampiran',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: _accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Tombol Aksi
                          _StaggerIn(
                            index: 5,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 44,
                                    child: _TapScale(
                                      onTap: () {
                                        if (Navigator.of(ctx).canPop()) {
                                          Navigator.of(ctx).pop();
                                        }
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.06)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.08)
                                                : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          'Nanti',
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 44,
                                    child: _TapScale(
                                      onTap: () {
                                        if (Navigator.of(ctx).canPop()) {
                                          Navigator.of(ctx).pop();
                                        }
                                        showPengumumanDetail(context, p);
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: penting
                                                ? const [
                                                    Color(0xFFDC2626),
                                                    Color(0xFFB91C1C),
                                                  ]
                                                : const [
                                                    _navy,
                                                    Color(0xFF1E5BB0),
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (penting
                                                      ? const Color(0xFFDC2626)
                                                      : _navy)
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Baca Detail',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
      );

      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
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
  List<Pengumuman>? _cachedList;

  @override
  void initState() {
    super.initState();
    _muatAwal();
  }

  Future<void> _muatAwal() async {
    try {
      final res = await PengumumanService.tayangSekali(widget.role);
      if (mounted && res.isNotEmpty) {
        setState(() => _cachedList = res);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Pengumuman>>(
      initialData: _cachedList,
      stream: PengumumanService.streamTayang(widget.role),
      builder: (context, snapshot) {
        final list = snapshot.data ?? _cachedList ?? const <Pengumuman>[];
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
    final bool adaGambar = _lampiranAdalahGambar(p);

    return _StaggerIn(
      index: 0,
      child: _TapScale(
        onTap: () => showPengumumanDetail(context, p),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
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
                            formatTanggalJam(p.tanggalTayang),
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
      ),
    );
  }
}

/// Wrapper interaksi sederhana: memberi efek mengecil (scale-down) saat
/// ditekan dan kembali membesar saat dilepas, memberi umpan balik sentuhan
/// yang terasa hidup pada kartu/tombol yang dibungkusnya.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}