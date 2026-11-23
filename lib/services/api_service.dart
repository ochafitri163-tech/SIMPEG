import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onesignal_service.dart';

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

  static Future<Map<String, String>> _getHeaders({String? explicitNik}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    var nik = explicitNik ?? prefs.getString('user_nik') ?? '';

    if (nik.isEmpty) {
      final session = await getSavedUserSession();
      if (session != null && session['nik'] != null) {
        nik = session['nik'].toString();
        await prefs.setString('user_nik', nik);
      }
    }

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

  /// 5a. Get Tunjangan Pendidikan (Regulasi 2026)
  static Future<Map<String, dynamic>> getTunjanganPendidikan({String? nik}) async {
    final uri = Uri.parse('$baseUrl/payroll/tunjangan-pendidikan').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders(explicitNik: nik));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 5b. Get Insentif Pegawai
  static Future<Map<String, dynamic>> getInsentif({String? nik}) async {
    final uri = Uri.parse('$baseUrl/payroll/insentif').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders(explicitNik: nik));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 5c. Get Lembur Pegawai
  static Future<Map<String, dynamic>> getLembur({String? nik}) async {
    final q = (nik != null && nik.isNotEmpty) ? '?nik=$nik' : '';
    final url = '$baseUrl/lembur$q';
    try {
      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders(explicitNik: nik))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
    } catch (_) {}
    return {'success': false, 'message': 'Gagal mengambil data lembur dari server.'};
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

  /// 7. Daftar Pegawai (Master Data dari PostgreSQL lokal)
  static Future<List<Map<String, dynamic>>> listPegawai({String? search, int perPage = 200}) async {
    final query = search != null && search.isNotEmpty
        ? '?search=${Uri.encodeComponent(search)}&per_page=$perPage'
        : '?per_page=$perPage';
    final url = Uri.parse('$baseUrl/pegawai$query');
    try {
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Simpan session pengguna ke SharedPreferences
  static Future<void> saveUserSession(Map<String, dynamic> userMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_session_json', jsonEncode(userMap));
    if (userMap['nik'] != null && userMap['nik'].toString().isNotEmpty) {
      await prefs.setString('user_nik', userMap['nik'].toString());
    }
    if (userMap['name'] != null && userMap['name'].toString().isNotEmpty) {
      await prefs.setString('user_nama', userMap['name'].toString());
    }
    if (userMap['jabatan'] != null && userMap['jabatan'].toString().isNotEmpty) {
      await prefs.setString('user_jabatan', userMap['jabatan'].toString());
    }
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
  static Future<Map<String, dynamic>> getDokumenResmi({String? nik}) async {
    final q = (nik != null && nik.isNotEmpty) ? '?nik=$nik' : '';
    final url = '$baseUrl/dokumen$q';
    try {
      final response = await http
          .get(Uri.parse(url), headers: await _getHeaders(explicitNik: nik))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
    } catch (_) {}
    return {'success': false, 'message': 'Gagal mengambil data dokumen dari server.'};
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

  /// 11. Cuti Pegawai
  static Future<Map<String, dynamic>> getCuti({String? nik, bool all = false}) async {
    final params = <String, String>{};
    if (nik != null && nik.isNotEmpty) params['nik'] = nik;
    if (all) params['all'] = '1';
    final uri = Uri.parse('$baseUrl/cuti').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders(explicitNik: nik));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 11b. Update Status Cuti Pegawai (Persetujuan oleh SDM / Direktur)
  static Future<Map<String, dynamic>> updateStatusCuti(int id, String status) async {
    final url = Uri.parse('$baseUrl/cuti/$id/status');
    try {
      final response = await http.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'status': status}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> storeCuti({
    required String jenis,
    required String tglMulai,
    required String tglSelesai,
    required String alasan,
    String? nik,
  }) async {
    final url = Uri.parse('$baseUrl/cuti');
    final prefs = await SharedPreferences.getInstance();
    final activeNik = nik ?? prefs.getString('user_nik') ?? '';

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(explicitNik: activeNik),
        body: jsonEncode({
          'nik': activeNik,
          'jenis_cuti': jenis,
          'tgl_mulai': tglMulai,
          'tgl_selesai': tglSelesai,
          'alasan': alasan,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 12. Pengaduan Pegawai
  static Future<Map<String, dynamic>> getPengaduan({String? nik, String? scope, String? tab}) async {
    final params = <String, String>{};
    if (nik != null && nik.isNotEmpty) params['nik'] = nik;
    if (scope != null && scope.isNotEmpty) params['scope'] = scope;
    if (tab != null && tab.isNotEmpty) params['tab'] = tab;
    final uri = Uri.parse('$baseUrl/pengaduan').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders(explicitNik: nik));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> storePengaduan({
    required String subjek,
    required String pesan,
    String? nik,
  }) async {
    final url = Uri.parse('$baseUrl/pengaduan');
    final prefs = await SharedPreferences.getInstance();
    final activeNik = nik ?? prefs.getString('user_nik') ?? '';

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(explicitNik: activeNik),
        body: jsonEncode({
          'nik': activeNik,
          'subjek': subjek,
          'pesan': pesan,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 13. Sanksi & Prestasi
  static Future<Map<String, dynamic>> getSanksi({String? nik}) async {
    final uri = Uri.parse('$baseUrl/sanksi').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders(explicitNik: nik));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getPrestasi({String? nik}) async {
    final uri = Uri.parse('$baseUrl/prestasi').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders(explicitNik: nik));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 14. Ganti Password
  static Future<Map<String, dynamic>> gantiPassword({
    required String oldPassword,
    required String newPassword,
    String? nik,
  }) async {
    final url = Uri.parse('$baseUrl/ganti-password');
    final prefs = await SharedPreferences.getInstance();
    final activeNik = nik ?? prefs.getString('user_nik') ?? '';

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(explicitNik: activeNik),
        body: jsonEncode({
          'nik': activeNik,
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 15. Checkin & Checkout Absensi
  static Future<Map<String, dynamic>> checkinAbsensi({
    String? nik,
    double? latitude,
    double? longitude,
    String? fotoUrl,
    String? keterangan,
  }) async {
    final url = Uri.parse('$baseUrl/absensi/checkin');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(explicitNik: nik),
        body: jsonEncode({
          if (nik != null) 'nik': nik,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (fotoUrl != null) 'foto_url': fotoUrl,
          if (keterangan != null) 'keterangan': keterangan,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> checkoutAbsensi({
    String? nik,
    int? id,
  }) async {
    final url = Uri.parse('$baseUrl/absensi/checkout');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(explicitNik: nik),
        body: jsonEncode({
          if (nik != null) 'nik': nik,
          if (id != null) 'id': id,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 16. Logout - membersihkan seluruh sesi aktif, OneSignal, dan SharedPreferences
  static Future<void> logout() async {
    try {
      await OneSignalService.instance.logoutUser();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_nik');
      await prefs.remove('user_nama');
      await prefs.remove('user_jabatan');
      await prefs.remove('user_session_json');
    } catch (_) {}
  }
}
