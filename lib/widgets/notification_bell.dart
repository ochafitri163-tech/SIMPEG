import 'package:flutter/material.dart';
import '../models/pengaduan_model.dart';
import '../models/user_role.dart';

/// Ikon lonceng notifikasi yang dipasang di AppBar tiap dashboard.
/// Menampilkan badge jumlah notifikasi belum dibaca untuk [role], dan saat
/// ditekan membuka daftar notifikasi milik role tersebut (Tahap 7).
class NotificationBell extends StatefulWidget {
  final UserRole role;
  const NotificationBell({super.key, required this.role});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  static const Color _navy = Color(0xFF0D2C6E);

  void _bukaDaftarNotifikasi() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final notif = NotificationCenter.untukRole(widget.role);
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Notifikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () {
                        NotificationCenter.tandaiSemuaDibaca(widget.role);
                        setSheetState(() {});
                        setState(() {});
                      },
                      child: const Text('Tandai semua dibaca', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: notif.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text('Belum ada notifikasi.',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: notif.length,
                          separatorBuilder: (_, __) => const Divider(height: 18),
                          itemBuilder: (_, i) {
                            final n = notif[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4, right: 10),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: n.dibaca ? Colors.transparent : _navy,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.judul,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(n.pesan, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(formatTanggalJam(n.waktu),
                                          style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
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
      ),
    ).whenComplete(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final belumDibaca = NotificationCenter.belumDibaca(widget.role);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded),
          tooltip: 'Notifikasi',
          onPressed: _bukaDaftarNotifikasi,
        ),
        if (belumDibaca > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Color(0xFFE74C3C), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                belumDibaca > 9 ? '9+' : '$belumDibaca',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
