import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Dynamic Host URL per platform:
  // - Web / Windows / macOS / iOS: http://127.0.0.1:8000/api/v1
  // - Android Emulator: http://10.0.2.2:8000/api/v1
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    } else {
      return 'http://127.0.0.1:8000/api/v1';
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final nik = prefs.getString('user_nik') ?? '';

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-NIK': nik,
    };
  }

  /// 1. Login Pegawai
  static Future<Map<String, dynamic>> login(String nik, String password) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'nik': nik, 'password': password}),
      ).timeout(const Duration(seconds: 3));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['data']['token']);
        await prefs.setString('user_nik', data['data']['user']['nik']);
        await prefs.setString('user_nama', data['data']['user']['nama']);
        await prefs.setString('user_jabatan', data['data']['user']['jabatan']);
      }
      return data;
    } catch (e) {
      return {'success': false, 'message': 'Gagal terhubung ke server Laravel: $e'};
    }
  }

  /// 2. Get Profil Pegawai
  static Future<Map<String, dynamic>> getProfile() async {
    final url = Uri.parse('$baseUrl/profile');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 3. Get Slip Gaji Bulanan
  static Future<Map<String, dynamic>> getSlipGaji() async {
    final url = Uri.parse('$baseUrl/payroll/slip-gaji');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 4. Get Slip THR
  static Future<Map<String, dynamic>> getSlipThr() async {
    final url = Uri.parse('$baseUrl/payroll/thr');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 5. Get Gaji 13
  static Future<Map<String, dynamic>> getGaji13() async {
    final url = Uri.parse('$baseUrl/payroll/gaji-13');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 6. Get Absensi
  static Future<Map<String, dynamic>> getAbsensi() async {
    final url = Uri.parse('$baseUrl/absensi');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 7. Check-In Absensi
  static Future<Map<String, dynamic>> checkinAbsensi(double? lat, double? lng) async {
    final url = Uri.parse('$baseUrl/absensi/checkin');
    final prefs = await SharedPreferences.getInstance();
    final nik = prefs.getString('user_nik') ?? '';

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'nik': nik, 'latitude': lat, 'longitude': lng}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Simpan session pengguna ke SharedPreferences
  static Future<void> saveUserSession(Map<String, dynamic> userMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_session_json', jsonEncode(userMap));
  }

  /// Ambil data session pengguna yang tersimpan (jika ada)
  static Future<Map<String, dynamic>?> getSavedUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('user_session_json');
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 8. Get Dokumen Resmi Pegawai (SK & Diklat)
  static Future<Map<String, dynamic>> getDokumenResmi() async {
    final url = Uri.parse('$baseUrl/dokumen');
    try {
      final response = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 3));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 9. Get Pengumuman Perusahaan
  static Future<Map<String, dynamic>> getPengumuman() async {
    final url = Uri.parse('$baseUrl/pengumuman');
    try {
      final response = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 3));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 10. Tandai Pengumuman Dibaca
  static Future<Map<String, dynamic>> markPengumumanRead(int id) async {
    final url = Uri.parse('$baseUrl/pengumuman/$id/baca');
    try {
      final response = await http.post(url, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 11. Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_nik');
    await prefs.remove('user_nama');
    await prefs.remove('user_jabatan');
    await prefs.remove('user_session_json');
  }
}
