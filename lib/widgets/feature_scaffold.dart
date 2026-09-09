import 'package:flutter/material.dart';
import '../services/theme_controller.dart';
import '../theme/app_colors.dart';

class FeatureScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  static const Color navy = Color(0xFF0D2C6E);
  static const Color accent = Color(0xFF2E86AB);

  static const Color _darkBackground = Color(0xFF090D16);

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
    return ValueListenableBuilder<UiVersion>(
      valueListenable: ThemeController.instance.uiVersion,
      builder: (context, version, _) {
        final isV2 = version == UiVersion.v2;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark
              ? (isV2 ? const Color(0xFF090D16) : _darkBackground)
              : (isV2 ? const Color(0xFFF1F5F9) : const Color(0xFFF3F6F9)),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + (isV2 ? 16 : 14),
                  left: 20,
                  right: 20,
                  bottom: isV2 ? 26 : 22,
                ),
                decoration: BoxDecoration(
                  gradient: isV2
                      ? (isDark
                          ? const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF1E3A8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF0A192F), Color(0xFF0D2C6E), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ))
                      : null,
                  color: isV2 ? null : navy,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(isV2 ? 32 : 28),
                    bottomRight: Radius.circular(isV2 ? 32 : 28),
                  ),
                  boxShadow: isV2 ? AppColors.cardShadow(context) : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: isV2
                                ? BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  )
                                : null,
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: isV2 ? 42 : 38,
                          height: isV2 ? 42 : 38,
                          decoration: BoxDecoration(
                            gradient: isV2
                                ? const LinearGradient(
                                    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                                  )
                                : null,
                            color: isV2 ? null : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(isV2 ? 14 : 12),
                            boxShadow: isV2
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Icon(icon, color: Colors.white, size: isV2 ? 22 : 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isV2 ? 18 : 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: isV2 ? 0.3 : 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                  fontWeight: isV2 ? FontWeight.w400 : FontWeight.normal,
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
      },
    );
  }
}

/// Badge status kecil berwarna (mis. "Sudah Dibayar", "Diproses").
/// Warna badge sendiri tetap sama di kedua mode (sudah cukup kontras
/// karena selalu memakai opacity di atas latar kartu), tidak perlu
/// disesuaikan.
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

/// Kartu dasar dengan shadow lembut, dipakai berulang di semua
/// halaman fitur. Warna permukaan mengikuti tema: putih di mode
/// terang, `0xFF1B2230` di mode gelap (selaras dengan cardColor di
/// darkTheme pada main.dart).
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF9AA6B2) : const Color(0xFF7F8C8D),
              ),
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
                color: isDark ? Colors.white : const Color(0xFF1B2733),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 40, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}