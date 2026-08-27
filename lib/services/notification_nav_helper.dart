import 'package:flutter/material.dart';
import '../models/pengumuman_model.dart';
import '../models/user_role.dart';
import '../screens/shared/pengumuman_list_screen.dart';
import 'api_service.dart';

/// Global navigator key agar notifikasi bisa membuka halaman dari mana saja
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationNavHelper {
  NotificationNavHelper._();

  /// Langsung navigasikan aplikasi ke fitur Pengumuman dan tampilkan pop-up detail saat notifikasi diklik
  static Future<void> openPengumuman({int? pengumumanId}) async {
    // Beri jeda singkat agar root navigator siap
    await Future.delayed(const Duration(milliseconds: 300));

    final navState = navigatorKey.currentState;
    if (navState == null) return;

    // 1. Dapatkan role user yang sedang aktif
    UserRole role = UserRole.pegawai;
    try {
      final session = await ApiService.getSavedUserSession();
      if (session != null && session['role'] != null) {
        final roleVal = session['role'];
        if (roleVal is int && roleVal >= 0 && roleVal < UserRole.values.length) {
          role = UserRole.values[roleVal];
        } else if (roleVal is String) {
          role = UserRoleX.fromKode(roleVal);
        }
      }
    } catch (_) {}

    // 2. Ambil data pengumuman yang sesuai ID atau pengumuman terbaru
    Pengumuman? targetPengumuman;
    if (pengumumanId != null) {
      try {
        targetPengumuman = await PengumumanService.ambilById(pengumumanId);
      } catch (_) {}
    }

    if (targetPengumuman == null) {
      try {
        final list = await PengumumanService.tayangSekali(role);
        if (list.isNotEmpty) {
          targetPengumuman = list.first;
        }
      } catch (_) {}
    }

    // 3. Masuk ke halaman daftar pengumuman & otomatis trigger pop-up modal detail
    navState.push(
      MaterialPageRoute(
        builder: (_) => PengumumanListScreen(
          role: role,
          initialPengumuman: targetPengumuman,
          initialPengumumanId: pengumumanId,
        ),
      ),
    );
  }
}
