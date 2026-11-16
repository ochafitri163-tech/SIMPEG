import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

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

  /// Catat aktivitas secara otomatis (Append-Only)
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
      debugPrint('AuditLog: [$action] $module - $description (User: $userNik, Device: $deviceInfo)');
    } catch (e) {
      debugPrint('AuditLogService error: $e');
    }
  }
}
