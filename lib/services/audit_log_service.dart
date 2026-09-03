import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service khusus untuk mencatat log aktivitas (Audit Trail) secara silent
/// beserta informasi merk/tipe perangkat yang digunakan.
class AuditLogService {
  static String? _cachedDeviceInfo;

  /// Mengambil informasi detail tipe HP / Laptop pelakunya.
  static Future<String> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    final deviceInfoPlugin = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        _cachedDeviceInfo = 'Web Browser (${webInfo.browserName.name})';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfoPlugin.androidInfo;
        final brand = android.brand.toUpperCase();
        final model = android.model;
        final version = android.version.release;
        _cachedDeviceInfo = '$brand $model (Android $version)';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfoPlugin.iosInfo;
        final name = ios.name;
        final model = ios.model;
        final version = ios.systemVersion;
        _cachedDeviceInfo = '$name ($model, iOS $version)';
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final win = await deviceInfoPlugin.windowsInfo;
        _cachedDeviceInfo = 'Windows PC (${win.computerName})';
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final mac = await deviceInfoPlugin.macOsInfo;
        _cachedDeviceInfo = 'macOS (${mac.computerName})';
      } else {
        _cachedDeviceInfo = 'Perangkat (${defaultTargetPlatform.name})';
      }
    } catch (e) {
      _cachedDeviceInfo = 'Perangkat Tidak Terdeteksi';
      debugPrint('AuditLogService getDeviceInfo Error: $e');
    }

    return _cachedDeviceInfo!;
  }

  /// Catat aktivitas secara otomatis ke database Supabase (Append-Only)
  static Future<void> logAction({
    required String userNik,
    required String userName,
    required String role,
    required String action,
    required String module,
    required String description,
  }) async {
    try {
      final deviceInfo = await getDeviceInfo();
      final supabase = Supabase.instance.client;

      await supabase.from('activity_logs').insert({
        'user_nik': userNik,
        'user_name': userName,
        'role': role,
        'action': action.toUpperCase(),
        'module': module,
        'description': description,
        'device_info': deviceInfo,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint(' AuditLog tersimpan: [$action] $description ($deviceInfo)');
    } catch (e) {
      // Dibuat silent agar jika ada kendala koneksi, pengguna tidak terganggu
      debugPrint('⚠️ AuditLogService insert log error: $e');
    }
  }
}
