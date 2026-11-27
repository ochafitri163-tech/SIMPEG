import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pengumuman_model.dart';
import '../models/user_role.dart';
import '../screens/pegawai/absensi_screen.dart';
import '../screens/pegawai/dokumen_resmi_screen.dart';
import '../screens/pegawai/golongan_screen.dart';
import '../screens/pegawai/insentif_screen.dart';
import '../screens/pegawai/jabatan_screen.dart';
import '../screens/pegawai/keluarga_screen.dart';
import '../screens/pegawai/lembur_screen.dart';
import '../screens/pegawai/payroll_screen.dart';
import '../screens/pegawai/pendidikan_screen.dart';
import '../screens/pegawai/pengajuan_cuti_screen.dart';
import '../screens/pegawai/prestasi_screen.dart';
import '../screens/pegawai/sanksi_screen.dart';
import '../screens/pegawai/status_pengaduan_screen.dart';
import '../screens/pegawai/thr_screen.dart';
import '../screens/pegawai/tunjangan_pendidikan_screen.dart';
import '../screens/kadiv/dashboard_kadiv_screen.dart';
import '../screens/tpdpk/dashboard_tpdpk_screen.dart';
import '../screens/shared/detail_pengaduan_screen.dart';
import '../screens/shared/pengumuman_list_screen.dart';
import '../screens/shared/persetujuan_cuti_screen.dart';
import 'api_service.dart';

/// Global navigator key agar notifikasi bisa membuka halaman dari mana saja
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationNavHelper {
  NotificationNavHelper._();

  static bool _dashboardReady = false;
  static Map<String, dynamic>? _pendingNotificationData;

  /// Tandai bahwa Dashboard telah terpasang dan jalankan navigasi notifikasi cold-start bila ada.
  static Future<void> markDashboardReadyAndFlush() async {
    _dashboardReady = true;
    final pending = _pendingNotificationData;
    _pendingNotificationData = null;
    if (pending != null) {
      await handleNotificationClick(pending);
    }
  }

  /// Reset kesiapan navigasi saat user logout.
  static void resetNavigationState() {
    _dashboardReady = false;
    _pendingNotificationData = null;
  }

  /// Ambil AppUser aktif lengkap (termasuk divisiKadiv, unitKerja, golongan) dari sesi tersimpan.
  static Future<AppUser?> _getActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    final nik = prefs.getString('user_nik') ?? '';
    if (nik.isEmpty) return null;

    try {
      final session = await ApiService.getSavedUserSession();
      if (session != null && session.isNotEmpty) {
        return AppUser.fromJson(session);
      }
    } catch (_) {}

    final nama = prefs.getString('user_nama') ?? 'Pegawai';
    final jabatan = prefs.getString('user_jabatan') ?? '-';
    return AppUser(
      nik: nik,
      name: nama,
      jabatan: jabatan,
      role: UserRole.pegawai,
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
    if (!_dashboardReady || navigatorKey.currentState == null) {
      final activeUser = await _getActiveUser();
      if (activeUser == null || !_dashboardReady) {
        _pendingNotificationData = data ?? const {'type': 'pengumuman'};
        return;
      }
    }

    if (data == null) {
      await openPengumuman();
      return;
    }
    final type = data['type']?.toString().toLowerCase().trim() ?? '';

    switch (type) {
      case 'task':
      case 'tugas':
      case 'penugasan':
        final pId = int.tryParse(data['pengaduan_id']?.toString() ?? '');
        if (pId != null) {
          await openPengaduan(pengaduanId: pId);
        } else {
          await openTugasSaya();
        }
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
        await openPayroll();
        break;
      case 'insentif':
        await openInsentif();
        break;
      case 'tunjangan_pendidikan':
        await openTunjanganPendidikan();
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
      case 'sanksi':
        await openSanksi();
        break;
      case 'golongan':
        await openGolongan();
        break;
      case 'jabatan_riwayat':
      case 'jabatan':
        await openJabatan();
        break;
      case 'pendidikan':
        await openPendidikan();
        break;
      case 'keluarga':
        await openKeluarga();
        break;
      case 'prestasi':
        await openPrestasi();
        break;
      default:
        if (data.containsKey('pengaduan_id')) {
          final pId = int.tryParse(data['pengaduan_id'].toString());
          await openPengaduan(pengaduanId: pId);
        } else if (data.containsKey('task_id')) {
          await openTugasSaya();
        } else if (data.containsKey('pengumuman_id')) {
          final pId = int.tryParse(data['pengumuman_id'].toString());
          await openPengumuman(pengumumanId: pId);
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
  static Future<void> openPayroll() =>
      _openUserScreen((user) => PayrollScreen(user: user));

  /// Navigasi ke Rincian Insentif
  static Future<void> openInsentif() =>
      _openUserScreen((user) => InsentifScreen(user: user));

  /// Navigasi ke Tunjangan Pendidikan
  static Future<void> openTunjanganPendidikan() =>
      _openUserScreen((user) => TunjanganPendidikanScreen(user: user));

  /// Navigasi ke Sanksi
  static Future<void> openSanksi() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;
    navState.push(MaterialPageRoute(builder: (_) => const SanksiScreen()));
  }

  /// Navigasi ke Riwayat Golongan
  static Future<void> openGolongan() =>
      _openUserScreen((user) => GolonganScreen(user: user));

  /// Navigasi ke Riwayat Jabatan
  static Future<void> openJabatan() =>
      _openUserScreen((user) => JabatanScreen(user: user));

  /// Navigasi ke Riwayat Pendidikan
  static Future<void> openPendidikan() =>
      _openUserScreen((user) => PendidikanScreen(user: user));

  /// Navigasi ke Data Keluarga
  static Future<void> openKeluarga() =>
      _openUserScreen((user) => KeluargaScreen(user: user));

  /// Navigasi ke Riwayat Prestasi
  static Future<void> openPrestasi() =>
      _openUserScreen((user) => PrestasiScreen(user: user));

  static Future<void> _openUserScreen(Widget Function(AppUser user) builder) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      navState.push(MaterialPageRoute(builder: (_) => builder(user)));
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
              showAction: true,
            ),
          ),
        );
      } else if (user.role == UserRole.kadivKategori) {
        navState.push(MaterialPageRoute(builder: (_) => DashboardKadivScreen(user: user, showBackButton: true)));
      } else if (user.role == UserRole.tpdpk) {
        navState.push(MaterialPageRoute(builder: (_) => DashboardTpdpkScreen(user: user, showBackButton: true)));
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
      if (user.role == UserRole.sdm ||
          user.role == UserRole.direktur ||
          user.isManajerSdm) {
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

  /// Navigasi ke Tugas Saya untuk Eksekutor (Kadiv SPI & TPDPK)
  static Future<void> openTugasSaya() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final user = await _getActiveUser();
    if (user != null) {
      if (user.role == UserRole.kadivKategori) {
        navState.push(MaterialPageRoute(builder: (_) => DashboardKadivScreen(user: user, showBackButton: true)));
      } else if (user.role == UserRole.tpdpk) {
        navState.push(MaterialPageRoute(builder: (_) => DashboardTpdpkScreen(user: user, showBackButton: true)));
      } else {
        navState.push(MaterialPageRoute(builder: (_) => StatusPengaduanScreen(user: user)));
      }
    }
  }
}
