import 'package:flutter/material.dart';

/// Scaffold seragam untuk seluruh halaman fitur (Pendidikan, Keluarga,
/// Golongan, Jabatan, Payroll, THR, Sanksi, Pengaduan Warga) —
/// header gradasi navy->teal dengan tombol kembali & judul, isi berupa
/// daftar kartu putih di atas latar abu muda.
class FeatureScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  static const Color navy = Color(0xFF0D2C6E);
  static const Color accent = Color(0xFF2E86AB);

  const FeatureScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 14,
              left: 20,
              right: 20,
              bottom: 22,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [navy, accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Badge status kecil berwarna (mis. "Sudah Dibayar", "Diproses").
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.auto(String label) {
    Color color;
    final lower = label.toLowerCase();
    if (lower.contains('selesai') ||
        lower.contains('dibayar') ||
        lower.contains('cair')) {
      color = const Color(0xFF27AE60);
    } else if (lower.contains('proses')) {
      color = const Color(0xFFE67E22);
    } else if (lower.contains('baru')) {
      color = const Color(0xFF2E86AB);
    } else if (lower.contains('berat')) {
      color = const Color(0xFFE74C3C);
    } else if (lower.contains('sedang')) {
      color = const Color(0xFFE67E22);
    } else if (lower.contains('ringan')) {
      color = const Color(0xFFF39C12);
    } else {
      color = const Color(0xFF7F8C8D);
    }
    return StatusBadge(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// Kartu putih dasar dengan shadow lembut, dipakai berulang di semua
/// halaman fitur.
class InfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const InfoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Baris label-nilai sederhana dipakai di dalam InfoCard.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7F8C8D)),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF1B2733),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tampilan kosong seragam saat daftar data belum ada isinya.
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
