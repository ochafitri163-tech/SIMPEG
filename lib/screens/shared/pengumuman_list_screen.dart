import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/pengumuman_model.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import '../../widgets/pengumuman_card.dart';

/// Halaman riwayat "Berita Pengumuman" — dapat diakses seluruh role
/// (Pegawai, Kadiv, KSPI, TPDPK, Direktur). Menampilkan pengumuman yang
/// ditujukan untuk role tersebut, mendukung pencarian judul, urut tanggal
/// terbaru, penanda "Baru" (belum dibaca), status, dan Lihat Detail.
class PengumumanListScreen extends StatefulWidget {
  final UserRole role;
  const PengumumanListScreen({super.key, required this.role});

  @override
  State<PengumumanListScreen> createState() => _PengumumanListScreenState();
}

class _PengumumanListScreenState extends State<PengumumanListScreen> {
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _accentDark = Color(0xFF1F5F7A);
  static const Color _warning = Color(0xFFD35400);
  static const Color _danger = Color(0xFFE74C3C);
  static const Color _success = Color(0xFF27AE60);
  static const Color _muted = Color(0xFF95A5A6);

  late Future<_DataRiwayat> _future;
  final TextEditingController _cariController = TextEditingController();
  final FocusNode _cariFocus = FocusNode();
  String _kueri = '';

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  @override
  void dispose() {
    _cariController.dispose();
    _cariFocus.dispose();
    super.dispose();
  }

  Future<_DataRiwayat> _muat() async {
    final semua = await PengumumanService.semua();
    final dibaca = await PengumumanService.idSudahDibaca();
    final terlihat = semua.where((p) => p.untukRole(widget.role)).toList();
    return _DataRiwayat(items: terlihat, dibaca: dibaca);
  }

  Future<void> _refresh() async {
    setState(() => _future = _muat());
    await _future;
  }

  /// Mengecek apakah lampiran pengumuman berupa berkas gambar (berdasarkan
  /// ekstensi nama file / URL), dipakai untuk menampilkan thumbnail kecil
  /// pada kartu list agar terlihat dari luar tanpa perlu membuka detail.
  bool _lampiranAdalahGambar(Pengumuman p) {
    if (!p.adaLampiran) return false;
    final sumber = p.lampiranNama ?? p.lampiranUrl ?? '';
    return RegExp(r'\.(png|jpe?g|webp|gif|heic)(\?.*)?$', caseSensitive: false)
        .hasMatch(sumber);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FeatureScaffold(
      title: 'Berita Pengumuman',
      subtitle: 'Riwayat pengumuman PERUMDAM Tirta Darma Ayu',
      icon: Icons.campaign_rounded,
      child: Column(
        children: [
          _buildSearchBar(isDark),
          Expanded(
            child: FutureBuilder<_DataRiwayat>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoading(isDark);
                }
                if (snapshot.hasError) {
                  return _buildError(isDark, snapshot.error.toString());
                }

                final data = snapshot.data ??
                    _DataRiwayat(items: const [], dibaca: const {});
                final items = _kueri.isEmpty
                    ? data.items
                    : data.items
                        .where((p) => p.judul.toLowerCase().contains(_kueri))
                        .toList();

                if (items.isEmpty) {
                  return RefreshIndicator(
                    color: _accent,
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height:
                              MediaQuery.of(context).size.height * 0.62,
                          child: EmptyState(
                            icon: Icons.campaign_outlined,
                            message: _kueri.isEmpty
                                ? 'Belum ada pengumuman.'
                                : 'Tidak ada pengumuman berjudul "$_kueri".',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: _accent,
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return _AnimatedEntry(
                        index: i,
                        child: _buildItem(
                            context, p, isDark, !data.dibaca.contains(p.id)),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2230) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _cariFocus.hasFocus
                ? _accent.withValues(alpha: 0.55)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            width: 1.2,
          ),
        ),
        child: TextField(
          controller: _cariController,
          focusNode: _cariFocus,
          onChanged: (v) => setState(() => _kueri = v.trim().toLowerCase()),
          onTapOutside: (_) => _cariFocus.unfocus(),
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white : const Color(0xFF1B2733),
          ),
          decoration: InputDecoration(
            hintText: 'Cari berdasarkan judul…',
            hintStyle: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
            prefixIcon: Icon(Icons.search_rounded,
                size: 20,
                color: _cariFocus.hasFocus ? _accent : Colors.grey[500]),
            suffixIcon: _kueri.isEmpty
                ? null
                : IconButton(
                    splashRadius: 18,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _cariController.clear();
                      setState(() => _kueri = '');
                    },
                  ),
            isDense: true,
            filled: false,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: List.generate(4, (i) => _SkeletonCard(isDark: isDark)),
    );
  }

  Widget _buildError(bool isDark, String message) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _danger.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_off_rounded,
                          color: _danger, size: 26),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal memuat pengumuman',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1B2733),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Coba Lagi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        side: const BorderSide(color: _accent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(
      BuildContext context, Pengumuman p, bool isDark, bool belumDibaca) {
    final bool adaGambar = _lampiranAdalahGambar(p);
    final Color surface = isDark ? const Color(0xFF1B2230) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1B2733);
    final Color subColor =
        isDark ? const Color(0xFF9AA6B2) : const Color(0xFF6F7C8A);
    final Color lineColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE8EDF3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: _accent.withValues(alpha: 0.08),
        highlightColor: _accent.withValues(alpha: 0.04),
        onTap: () async {
          await showPengumumanDetail(context, p);
          _refresh();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: belumDibaca
                  ? _accent.withValues(alpha: 0.22)
                  : lineColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            // IntrinsicHeight WAJIB di sini: Row dengan
            // CrossAxisAlignment.stretch butuh tinggi pasti untuk bisa
            // meregangkan Container aksen (width:5, tanpa height) ke
            // tinggi konten di sebelahnya. Tanpa ini, layout jadi
            // sirkular dan menyebabkan RenderBox gagal (muncul sebagai
            // "mouse_tracker assertion" di console, layar jadi kosong).
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Garis biru di kiri sebagai aksen, bukan emoji/icon
                  // tambahan.
                  Container(
                    width: 5,
                    color: belumDibaca
                        ? _accent
                        : _accent.withValues(alpha: 0.30),
                  ),

                  Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header kecil: badge + status baru
                        Row(
                          children: [
                            _typeBadge(p.isPenting),
                            if (belumDibaca) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Baru',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ikon biru clean, bukan emoji.
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                p.isPenting
                                    ? Icons.notifications_active_rounded
                                    : Icons.campaign_rounded,
                                color: _accent,
                                size: 21,
                              ),
                            ),

                            const SizedBox(width: 11),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.judul,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      height: 1.22,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    p.ringkasan,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.42,
                                      color: subColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (adaGambar) ...[
                              const SizedBox(width: 10),
                              _ThumbnailGambar(
                                url: p.lampiranUrl!,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 13),

                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _statusBadge(p.sedangTayang),
                            if (p.adaLampiran)
                              _lampiranBadge(isDark, adaGambar),
                          ],
                        ),

                        const SizedBox(height: 13),

                        Divider(
                          height: 1,
                          color: lineColor,
                        ),

                        const SizedBox(height: 11),

                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                Icons.event_rounded,
                                size: 15,
                                color: _accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formatTanggalJam(p.tanggalPublikasi),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: subColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await showPengumumanDetail(context, p);
                                _refresh();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _accent.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Lihat Detail',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w900,
                                        color: _accentDark,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: _accentDark,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Badge jenis pengumuman: PENTING (merah) atau INFO (biru), bentuk pil
  /// rata (flat), tanpa dekorasi berlebih.
  Widget _typeBadge(bool penting) {
    final color = penting ? _danger : _accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        penting ? 'PENTING' : 'INFO',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }

  Widget _pillBadge(String text, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }

  Widget _statusBadge(bool aktif) {
    final color = aktif ? _success : _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            aktif ? 'Aktif' : 'Nonaktif',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  /// Badge kecil penanda lampiran: ikon foto (biru) bila gambar, ikon
  /// klip (abu-abu) bila berkas lain — sehingga jenis lampiran terlihat
  /// jelas langsung dari daftar tanpa membuka detail.
  Widget _lampiranBadge(bool isDark, bool adaGambar) {
    final color = adaGambar ? _accent : Colors.grey[500]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(adaGambar ? Icons.image_rounded : Icons.attach_file_rounded,
              size: 11.5, color: color),
          const SizedBox(width: 4),
          Text(
            adaGambar ? 'Foto' : 'Lampiran',
            style: TextStyle(
                fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail kecil bergambar bulat-persegi yang muncul di pojok kartu list
/// bila pengumuman memiliki lampiran foto, lengkap dengan lencana ikon
/// kamera kecil di sudutnya sebagai penanda visual yang jelas.
class _ThumbnailGambar extends StatelessWidget {
  final String url;
  final bool isDark;
  const _ThumbnailGambar({required this.url, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 44,
                height: 44,
                color:
                    isDark ? const Color(0xFF232B3B) : const Color(0xFFEDEFF2),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF2E86AB)),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stack) => Container(
              width: 44,
              height: 44,
              color:
                  isDark ? const Color(0xFF232B3B) : const Color(0xFFEDEFF2),
              child: Icon(Icons.broken_image_rounded,
                  size: 17, color: Colors.grey[500]),
            ),
          ),
        ),
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF2E86AB),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF1B2230) : Colors.white,
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.photo_camera_rounded,
                size: 9, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Membungkus setiap item list dengan animasi masuk (fade + slide) yang
/// tertunda sesuai index, memberi kesan halus tanpa mengubah tampilan
/// dasar kartu.
class _AnimatedEntry extends StatelessWidget {
  final int index;
  final Widget child;
  const _AnimatedEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8)) * 45;
    return TweenAnimationBuilder<double>(
      key: ValueKey('entry_$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Kartu placeholder saat data sedang dimuat, memberi kesan responsif
/// dibanding hanya menampilkan indikator putar di tengah layar.
class _SkeletonCard extends StatefulWidget {
  final bool isDark;
  const _SkeletonCard({required this.isDark});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.isDark ? const Color(0xFF232B3B) : const Color(0xFFEDEFF2);
    final highlight =
        widget.isDark ? const Color(0xFF2B3547) : const Color(0xFFF7F8FA);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        Color c(Color a, Color b) => Color.lerp(a, b, t)!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1B2230) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c(base, highlight),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 13,
                      decoration: BoxDecoration(
                        color: c(base, highlight),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 11,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c(base, highlight),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 11,
                width: 180,
                decoration: BoxDecoration(
                  color: c(base, highlight),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    height: 20,
                    width: 60,
                    decoration: BoxDecoration(
                      color: c(base, highlight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 28,
                    width: 96,
                    decoration: BoxDecoration(
                      color: c(base, highlight),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DataRiwayat {
  final List<Pengumuman> items;
  final Set<int> dibaca;
  const _DataRiwayat({required this.items, required this.dibaca});
}