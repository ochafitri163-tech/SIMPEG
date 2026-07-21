import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'mode_gelap';

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  bool get isDark => themeMode.value == ThemeMode.dark;

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefsKey);
    if (saved != null) {
      themeMode.value = saved ? ThemeMode.dark : ThemeMode.light;
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
}