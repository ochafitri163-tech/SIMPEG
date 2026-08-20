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
  final Duration stepDelay;
  const _StaggerIn({
    required this.child,
    this.index = 0,
    this.stepDelay = const Duration(milliseconds: 70),
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
    Future.delayed(widget.stepDelay * widget.index, () {
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
  final adaGambar = _lampiranAdalahGambar(p);

  await showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.scale(scale: 0.85 + (0.15 * value), child: child),
          ),
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
                    padding: EdgeInsets.fromLTRB(adaGambar ? 0 : 20,
                        adaGambar ? 0 : 18, adaGambar ? 0 : 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (adaGambar) ...[
                          _LampiranGambarBanner(url: p.lampiranUrl!),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Text(p.isi,
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: textColor)),
                          ),
                        ] else ...[
                          Text(p.isi,
                              style: TextStyle(
                                  fontSize: 14,
                                  height: 1.55,
                                  color: textColor)),
                          if (p.adaLampiran) ...[
                            const SizedBox(height: 16),
                            _LampiranTile(
                                nama: p.lampiranNama ?? 'Lampiran',
                                url: p.lampiranUrl!),
                          ],
                        ],
                        Padding(
                          padding: EdgeInsets.fromLTRB(adaGambar ? 20 : 0, 18,
                              adaGambar ? 20 : 0, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(color: subColor.withValues(alpha: 0.25)),
                              const SizedBox(height: 8),
                              _metaRow(Icons.event_rounded, 'Dipublikasikan',
                                  formatTanggalJam(p.tanggalPublikasi),
                                  subColor, textColor),
                              const SizedBox(height: 8),
                              _metaRow(Icons.person_rounded, 'Pembuat',
                                  '${p.pembuat} (SDM)', subColor, textColor),
                              if (p.kedaluwarsaPada != null) ...[
                                const SizedBox(height: 8),
                                _metaRow(
                                    Icons.timer_off_rounded,
                                    'Berlaku s/d',
                                    formatTanggalJam(p.kedaluwarsaPada!),
                                    subColor,
                                    textColor),
                              ],
                              if (adaGambar) const SizedBox(height: 4),
                            ],
                          ),
                        ),
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
        ),
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

  final Color surface = isDark ? const Color(0xFF172033) : Colors.white;
  final Color textColor = isDark ? Colors.white : const Color(0xFF14213D);
  final Color subColor =
      isDark ? const Color(0xFFAAB4C3) : const Color(0xFF6C7A90);
  final Color badgeColor =
      penting ? const Color(0xFFFF4F4A) : const Color(0xFF1E88C5);

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup pengumuman',
    barrierColor: Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, secondaryAnim) {
      final Size screen = MediaQuery.of(ctx).size;
      final double popupWidth = screen.width < 360 ? screen.width - 42 : 300;

      return Material(
        type: MaterialType.transparency,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 58, 0, 28),
            child: SizedBox(
              width: popupWidth,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // ===========================================================
                  // BODY CARD
                  // ===========================================================
                  Container(
                    margin: const EdgeInsets.only(top: 72),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 92, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge + tanggal
                          _StaggerIn(
                            index: 0,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: badgeColor.withValues(alpha: 0.16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        penting
                                            ? Icons.priority_high_rounded
                                            : Icons.notifications_active_rounded,
                                        size: 15,
                                        color: badgeColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        penting ? 'PENTING' : 'INFO',
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.06)
                                            : const Color(0xFFF1F5FA),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule_rounded,
                                            size: 12,
                                            color: subColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              formatTanggalJam(
                                                p.tanggalPublikasi,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: subColor,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Judul
                          _StaggerIn(
                            index: 1,
                            child: Text(
                              p.judul.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 22,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Ringkasan
                          _StaggerIn(
                            index: 2,
                            child: Text(
                              p.ringkasan,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subColor,
                                fontSize: 13,
                                height: 1.38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Divider(
                            color: subColor.withValues(alpha: 0.16),
                            height: 1,
                          ),

                          const SizedBox(height: 16),

                          // Tombol aksi
                          _StaggerIn(
                            index: 3,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 74,
                                  height: 46,
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
                                                .withValues(alpha: 0.055)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              subColor.withValues(alpha: 0.25),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.045),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Nanti',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
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
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          color: _navy,
                                          boxShadow: [
                                            BoxShadow(
                                              color: _navy
                                                  .withValues(alpha: 0.32),
                                              blurRadius: 14,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Flexible(
                                                child: Text(
                                                  'Baca Detail',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  softWrap: false,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height: 2 + MediaQuery.of(ctx).padding.bottom,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===========================================================
                  // HERO IMAGE MENGAMBANG, VERSI MINIMALIS
                  // ===========================================================
                  Positioned(
                    top: 0,
                    left: 16,
                    right: 16,
                    child: _StaggerIn(
                      index: 0,
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0D2C6E),
                              Color(0xFF1565C0),
                              Color(0xFF2E86AB),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          image: adaGambar
                              ? DecorationImage(
                                  image: NetworkImage(p.lampiranUrl!),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.02),
                                      Colors.black.withValues(alpha: 0.10),
                                      Colors.black.withValues(alpha: 0.38),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            if (!adaGambar)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white
                                            .withValues(alpha: 0.16),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.32),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.campaign_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'PENGUMUMAN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            Positioned(
                              left: 14,
                              right: 14,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black.withValues(alpha: 0.32),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: const Text(
                                  'PENGUMUMAN TERBARU',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tombol close melayang minimalis
                  Positioned(
                    top: -10,
                    right: 6,
                    child: _TapScale(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF7D8796),
                          size: 21,
                        ),
                      ),
                    ),
                  ),
                ],
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
          scale: Tween<double>(begin: 0.70, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Banner foto lampiran pengumuman: gambar penuh lebar di bawah header,
/// dengan indikator memuat, fallback saat gagal, dan bisa ditekan untuk
/// dilihat penuh layar (pinch-to-zoom).
class _LampiranGambarBanner extends StatelessWidget {
  final String url;
  const _LampiranGambarBanner({required this.url});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _bukaGambarPenuh(context, url),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 160, maxHeight: 260),
            child: Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 200,
                  color: isDark
                      ? const Color(0xFF232B3B)
                      : const Color(0xFFEDEFF2),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: _accent),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stack) => Container(
                height: 160,
                color: isDark
                    ? const Color(0xFF232B3B)
                    : const Color(0xFFEDEFF2),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_rounded,
                          color: Colors.grey[500], size: 28),
                      const SizedBox(height: 6),
                      Text('Gambar gagal dimuat',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Lihat penuh',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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