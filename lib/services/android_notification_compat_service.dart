import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidNotificationDiagnostic {
  final bool notificationsEnabled;
  final bool ignoringBatteryOptimizations;
  final int sdkInt;
  final String manufacturer;
  final String model;
  final int urgentChannelImportance;

  const AndroidNotificationDiagnostic({
    required this.notificationsEnabled,
    required this.ignoringBatteryOptimizations,
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
    required this.urgentChannelImportance,
  });

  bool get needsAttention =>
      !notificationsEnabled || !ignoringBatteryOptimizations;

  bool get hasStrictOemPolicy {
    final m = manufacturer.toLowerCase();
    return m.contains('xiaomi') ||
        m.contains('redmi') ||
        m.contains('poco') ||
        m.contains('oppo') ||
        m.contains('realme') ||
        m.contains('oneplus') ||
        m.contains('vivo') ||
        m.contains('iqoo') ||
        m.contains('huawei') ||
        m.contains('honor') ||
        m.contains('samsung') ||
        m.contains('infinix') ||
        m.contains('tecno') ||
        m.contains('itel') ||
        m.contains('asus');
  }

  String get oemGuidance {
    final m = manufacturer.toLowerCase();
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return 'Aktifkan "Autostart" (Mulai Otomatis) & pilih "Tanpa pembatasan" di Penghemat Baterai MIUI/HyperOS.';
    }
    if (m.contains('oppo') || m.contains('realme') || m.contains('oneplus')) {
      return 'Izinkan "Peluncuran Otomatis" (Auto-launch) & aktivitas latar belakang di ColorOS.';
    }
    if (m.contains('vivo') || m.contains('iqoo')) {
      return 'Aktifkan izin "Autostart" & konsumsi daya latar belakang tinggi di FuntouchOS/OriginOS.';
    }
    if (m.contains('samsung')) {
      return 'Pastikan SIMPEG Mobile tidak masuk ke daftar "Aplikasi tidur / Sleeping apps" di One UI.';
    }
    if (m.contains('huawei') || m.contains('honor')) {
      return 'Atur Manajemen Peluncuran Aplikasi SIMPEG ke Manual (Izinkan peluncuran otomatis & sekunder).';
    }
    if (m.contains('infinix') || m.contains('tecno') || m.contains('itel')) {
      return 'Aktifkan Auto-start SIMPEG di Phone Master agar push notification tetap masuk saat aplikasi ditutup.';
    }
    return 'Pastikan izin notifikasi aktif dan aplikasi tidak dibatasi oleh Penghemat Baterai Android.';
  }
}

class AndroidNotificationCompatService {
  AndroidNotificationCompatService._();

  static const MethodChannel _channel =
      MethodChannel('com.simpeg.pdam/android_device_settings');

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static Future<AndroidNotificationDiagnostic?> getDiagnostic() async {
    if (!isAndroid) return null;
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('getNotificationDiagnostic');
      if (raw == null) return null;
      return AndroidNotificationDiagnostic(
        notificationsEnabled: raw['notificationsEnabled'] == true,
        ignoringBatteryOptimizations:
            raw['ignoringBatteryOptimizations'] == true,
        sdkInt: (raw['sdkInt'] as num?)?.toInt() ?? 0,
        manufacturer: (raw['manufacturer'] ?? '').toString(),
        model: (raw['model'] ?? '').toString(),
        urgentChannelImportance:
            (raw['urgentChannelImportance'] as num?)?.toInt() ?? -1000,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openNotificationSettings() async {
    if (!isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('openNotificationSettings')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openBatteryOptimizationSettings() async {
    if (!isAndroid) return false;
    try {
      return (await _channel
              .invokeMethod<bool>('openBatteryOptimizationSettings')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openOemAutostartSettings() async {
    if (!isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('openOemAutostartSettings')) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
