import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pengumuman_model.dart';
import '../models/user_role.dart';
import '../screens/pegawai/absensi_screen.dart';
import '../screens/pegawai/dokumen_resmi_screen.dart';
import '../screens/pegawai/lembur_screen.dart';
import '../screens/pegawai/payroll_screen.dart';
import '../screens/pegawai/pengajuan_cuti_screen.dart';
import '../screens/pegawai/status_pengaduan_screen.dart';
import '../screens/pegawai/thr_screen.dart';
import '../screens/pegawai/tugas_saya_screen.dart';
import '../screens/shared/detail_pengaduan_screen.dart';
import '../screens/shared/pengumuman_list_screen.dart';
import '../screens/shared/persetujuan_cuti_screen.dart';
import 'api_service.dart';

/// Global navigator key agar notifikasi bisa membuka halaman dari mana saja
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationNavHelper {
  NotificationNavHelper._();

  /// Ambil AppUser aktif dari shared preferences / session untuk navigasi
  static Future<AppUser?> _getActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    final nik = prefs.getString('user_nik') ?? '';
    if (nik.isEmpty) return null;
    final nama = prefs.getString('user_nama') ?? 'Pegawai';
    final jabatan = prefs.getString('user_jabatan') ?? '-';

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

    return AppUser(
      nik: nik,
      name: nama,
      jabatan: jabatan,
      role: role,
    );
  }

  /// Handler saat payload berupa String diterima dari notifikasi lokal (flutter_local_notifications)
  static Future<void> handlePayloadString(String? payload) async {
    if (payload == null || payload.trim().isEmpty) {
      await openPengumuman();
      return;
    }

    try {
      if (payload.trim().startsWith('{')) {
        final Map<String, dynamic> data = jsonDecode(payload);
        await handleNotificationClick(data);
        return;
      }
    } catch (_) {}

    // Fallback jika payload berupa string tipe langsung (mis. 'absensi', 'gaji')
    await handleNotificationClick({'type': payload.trim()});
  }

  /// Dispatcher utama saat notifikasi OneSignal atau Local Notification diklik
  static Future<void> handleNotificationClick(Map<String, dynamic>? data) async {
    if (data == null) {
      await openPengumuman();
      return;
    }
    final type = data['type']?.toString().toLowerCase().trim() ?? '';

    switch (type) {
      case 'task':
      case 'tugas':
      case 'penugasan':
        await openTugasSaya();
        break;
      case 'pengumuman':
        final pId = int.tryParse(data['pengumuman_id']?.toString() ?? data['id']?.toString() ?? '');
        await openPengumuman(pengumumanId: pId);
        break;
      case 'absensi':
        await openAbsensi();
        break;
      case 'gaji':
      case 'payroll':
      case 'gaji_13':
      case 'insentif':
        await openPayroll();
        break;
      case 'thr':
        await openThr();
        break;
      case 'pengaduan':
        final pId = int.tryParse(data['pengaduan_id']?.toString() ?? data['id']?.toString() ?? '');
        await openPengaduan(pengaduanId: pId);
        break;
      case 'cuti':
        await openCuti();
        break;
      case 'lembur':
        await openLembur();
        break;
      case 'dokumen':
      case 'sk':
        await openDokumen();
        break;
      default:
        if (data.containsKey('task_id')) {
          await openTugasSaya();
        } else if (data.containsKey('pengumuman_id')) {
          final pId = int.tryParse(data['pengumuman_id'].toString());
          await openPengumuman(pengumumanId: pId);
        } else if (data.containsKey('pengaduan_id')) {
          final pId = int.tryParse(data['pengaduan_id'].toString());
          await openPengaduan(pengaduanId: pId);
        } else {
          await openPengumuman();
        }
        break;
    }
  }

  /// Langsung navigasikan aplikasi ke fitur Pengumuman dan tampilkan pop-up detail saat notifikasi diklik
  static Future<void> openPengumuman({int? pengumumanId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    final role = user?.role ?? UserRole.pegawai;

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

  /// Navigasi ke Pengingat / Halaman Absensi
  static Future<void> openAbsensi() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    navState.push(MaterialPageRoute(builder: (_) => const AbsensiScreen()));
  }

  /// Navigasi ke Slip Gaji / Payroll
  static Future<void> openPayroll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      navState.push(MaterialPageRoute(builder: (_) => PayrollScreen(user: user)));
    }
  }

  /// Navigasi ke THR
  static Future<void> openThr() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      navState.push(MaterialPageRoute(builder: (_) => ThrScreen(user: user)));
    }
  }

  /// Navigasi ke Pengaduan Pegawai (atau Detail Pengaduan jika ID diberikan)
  static Future<void> openPengaduan({int? pengaduanId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      if (pengaduanId != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => PengaduanDetailScreen(
              user: user,
              pengaduanId: pengaduanId,
            ),
          ),
        );
      } else {
        navState.push(MaterialPageRoute(builder: (_) => StatusPengaduanScreen(user: user)));
      }
    }
  }

  /// Navigasi ke Cuti (Persetujuan Cuti untuk SDM/Direktur, Pengajuan Cuti untuk Pegawai)
  static Future<void> openCuti() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      if (user.role == UserRole.sdm || user.role == UserRole.direktur) {
        navState.push(MaterialPageRoute(builder: (_) => PersetujuanCutiScreen(user: user)));
      } else {
        navState.push(MaterialPageRoute(builder: (_) => PengajuanCutiScreen(user: user)));
      }
    }
  }

  /// Navigasi ke Lembur
  static Future<void> openLembur() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      navState.push(MaterialPageRoute(builder: (_) => LemburScreen(user: user)));
    }
  }

  /// Navigasi ke Dokumen Resmi SDM
  static Future<void> openDokumen() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      navState.push(MaterialPageRoute(builder: (_) => DokumenResmiScreen(user: user)));
    }
  }

  /// Navigasi ke Tugas Saya untuk Eksekutor
  static Future<void> openTugasSaya() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      navState.push(MaterialPageRoute(builder: (_) => TugasSayaScreen(user: user)));
    }
  }
}
