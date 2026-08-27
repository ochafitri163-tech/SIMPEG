import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../screens/shared/pengumuman_list_screen.dart';
import 'api_service.dart';

/// Global navigator key agar notifikasi bisa membuka halaman dari mana saja
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationNavHelper {
  NotificationNavHelper._();

  /// Langsung navigasikan aplikasi ke fitur Pengumuman saat notifikasi diklik
  static Future<void> openPengumuman() async {
    // Beri jeda sangat singkat agar root widget / context navigator siap
    await Future.delayed(const Duration(milliseconds: 300));

    final navState = navigatorKey.currentState;
    if (navState == null) return;

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

    navState.push(
      MaterialPageRoute(
        builder: (_) => PengumumanListScreen(role: role),
      ),
    );
  }
}
