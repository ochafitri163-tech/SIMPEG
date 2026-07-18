import 'package:flutter/material.dart';
import '../models/pengaduan_model.dart';
import '../models/pengaduan_service.dart';
import '../models/user_role.dart';

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
  const NotificationBell({super.key, required this.role});

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
                                      return Row(
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
                                                Text(formatTanggalJam(waktu),
                                                    style: const TextStyle(
                                                        fontSize: 10.5,
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                        ],
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
