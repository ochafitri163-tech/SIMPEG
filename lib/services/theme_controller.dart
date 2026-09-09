import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UiVersion { v1, v2 }

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'mode_gelap';
  static const _versionPrefsKey = 'ui_version';

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  final ValueNotifier<UiVersion> uiVersion =
      ValueNotifier<UiVersion>(UiVersion.v2);

  bool get isDark => themeMode.value == ThemeMode.dark;
  bool get isV2 => uiVersion.value == UiVersion.v2;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDark = prefs.getBool(_prefsKey);
    if (savedDark != null) {
      themeMode.value = savedDark ? ThemeMode.dark : ThemeMode.light;
    }
    final savedVerStr = prefs.getString(_versionPrefsKey);
    if (savedVerStr != null) {
      uiVersion.value = savedVerStr == 'v1' ? UiVersion.v1 : UiVersion.v2;
    } else {
      // Default to V2 to give the user the requested fresh modern experience immediately
      uiVersion.value = UiVersion.v2;
    }
  }

  Future<void> setDark(bool dark) async {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, dark);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await Supabase.instance.client.from('preferensi_pegawai').upsert({
          'pegawai_id': userId,
          'mode_gelap': dark,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Preferensi lokal tetap tersimpan walau sinkron ke Supabase gagal.
      }
    }
  }

  Future<void> setUiVersion(UiVersion version) async {
    uiVersion.value = version;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionPrefsKey, version == UiVersion.v1 ? 'v1' : 'v2');

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await Supabase.instance.client.from('preferensi_pegawai').upsert({
          'pegawai_id': userId,
          'ui_version': version == UiVersion.v1 ? 'v1' : 'v2',
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Ignored fallback
      }
    }
  }
}