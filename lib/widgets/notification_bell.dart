import 'package:flutter/material.dart';
import '../models/pengaduan_model.dart';
import '../models/pengaduan_service.dart';
import '../models/pengumuman_model.dart';
import '../models/user_role.dart';
import '../screens/shared/detail_pengaduan_screen.dart';
import 'pengumuman_card.dart' show showPengumumanDetail;

/// Ikon lonceng notifikasi yang dipasang di AppBar tiap dashboard.
/// Menampilkan badge jumlah notifikasi belum dibaca milik user yang
/// sedang login, dan saat ditekan membuka daftar notifikasinya
/// (menggantikan NotificationCenter in-memory lama dengan
/// [NotificationService] yang query ke Supabase).
///
/// CATATAN: parameter [role] dipertahankan supaya seluruh pemanggilan
/// lama (mis. `NotificationBell(role: UserRole.pegawai)` di setiap
/// dashboard) tidak perlu diubah, tapi sudah tidak dipakai untuk query --
/// notifikasi di Supabase sudah per-user (`untuk_pegawai_id`), jadi
/// otomatis hanya menampilkan notifikasi milik user yang sedang login,
/// apapun role-nya.
class NotificationBell extends StatefulWidget {
  final UserRole role;
  final AppUser user;
  const NotificationBell({super.key, required this.role, required this.user});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  static const Color _navy = Color(0xFF0D2C6E);

  int _belumDibaca = 0;

  @override
  void initState() {
    super.initState();
    _muatJumlahBelumDibaca();
  }

  Future<void> _muatJumlahBelumDibaca() async {
    try {
      final jumlah = await NotificationService.belumDibaca();
      if (mounted) setState(() => _belumDibaca = jumlah);
    } catch (_) {
      // Diamkan -- badge tetap 0 kalau gagal fetch, tidak mengganggu UI.
    }
  }

  /// Dipanggil saat satu item notifikasi ditekan/di-tap.
  /// 1. Tandai notifikasi itu sudah dibaca.
  /// 2. Tutup bottom sheet daftar notifikasi.
  /// 3. Arahkan ke tujuan sesuai jenis notifikasinya:
  ///    - punya `pengumuman_id` ATAU judulnya "Pengumuman Baru" -> langsung
  ///      munculkan POPUP detail pengumuman DI ATAS layar yang sedang
  ///      dibuka (mis. Beranda) -- TIDAK pindah halaman, sama seperti saat
  ///      kartu "Berita & Pengumuman" di dashboard ditekan. Kalau
  ///      `pengumuman_id` belum ada (mis. notifikasi lama / migrasi kolom
  ///      belum dijalankan), fallback ke pengumuman TERBARU yang tayang
  ///      untuk role user ini.
  ///    - punya `pengaduan_id`   -> buka halaman detail Pengaduan.
  ///    - selain itu             -> tidak ada tujuan, cukup ditandai dibaca.
  Future<void> _bukaNotifikasi(Map<String, dynamic> n) async {
    final notifId = (n['id'] as num?)?.toInt();
    if (notifId != null) {
      await NotificationService.tandaiDibaca(notifId);
      await _muatJumlahBelumDibaca();
    }

    final pengumumanId = (n['pengumuman_id'] as num?)?.toInt();
    final pengaduanId = (n['pengaduan_id'] as num?)?.toInt();
    final judul = (n['judul'] as String?) ?? '';
    final adalahNotifPengumuman =
        pengumumanId != null || judul.toLowerCase().contains('pengumuman');

    if (!mounted) return;
    Navigator.of(context).pop(); // tutup bottom sheet daftar notifikasi

    if (adalahNotifPengumuman) {
      Pengumuman? p;
      try {
        if (pengumumanId != null) {
          p = await PengumumanService.ambilById(pengumumanId);
        }
        if (p == null) {
          // Fallback: pengumuman TERBARU yang tayang untuk role user ini.
          final list = await PengumumanService.tayangSekali(widget.role);
          if (list.isNotEmpty) p = list.first;
        }
      } catch (_) {}

      if (p != null && mounted) {
        // Popup langsung di atas layar saat ini, tanpa berpindah halaman.
        showPengumumanDetail(context, p);
      }
      return;
    }

    if (pengaduanId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PengaduanDetailScreen(
            user: widget.user,
            pengaduanId: pengaduanId,
          ),
        ),
      );
    }
  }

  void _bukaDaftarNotifikasi() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: NotificationService.untukSaya(),
              builder: (context, snapshot) {
                final notif = snapshot.data ?? [];
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting;

                return Container(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.75),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Notifikasi',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () async {
                              await NotificationService.tandaiSemuaDibaca();
                              setSheetState(() {});
                              await _muatJumlahBelumDibaca();
                            },
                            child: const Text('Tandai semua dibaca',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: isLoading
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : notif.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 30),
                                    child: Center(
                                      child: Text('Belum ada notifikasi.',
                                          style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.grey[500])),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: notif.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 18),
                                    itemBuilder: (_, i) {
                                      final n = notif[i];
                                      final dibaca =
                                          (n['dibaca'] ?? false) as bool;
                                      final waktu =
                                          DateTime.parse(n['waktu'] as String);
                                      final adaTujuan =
                                          n['pengumuman_id'] != null ||
                                              n['pengaduan_id'] != null ||
                                              (n['judul'] as String? ?? '')
                                                  .toLowerCase()
                                                  .contains('pengumuman');
                                      return InkWell(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        onTap: () => _bukaNotifikasi(n),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    top: 4, right: 10),
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: dibaca
                                                      ? Colors.transparent
                                                      : _navy,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(n['judul'] as String,
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700)),
                                                    const SizedBox(height: 2),
                                                    Text(n['pesan'] as String,
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.grey)),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                        formatTanggalJam(waktu),
                                                        style: const TextStyle(
                                                            fontSize: 10.5,
                                                            color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                              if (adaTujuan)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4, left: 4),
                                                  child: Icon(
                                                      Icons
                                                          .chevron_right_rounded,
                                                      size: 18,
                                                      color: Colors.grey[400]),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() => _muatJumlahBelumDibaca());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded),
          tooltip: 'Notifikasi',
          onPressed: _bukaDaftarNotifikasi,
        ),
        if (_belumDibaca > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: Color(0xFFE74C3C), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _belumDibaca > 9 ? '9+' : '$_belumDibaca',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}