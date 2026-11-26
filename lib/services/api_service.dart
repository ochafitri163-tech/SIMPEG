import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'audit_log_service.dart';
import 'notification_nav_helper.dart';
import 'onesignal_service.dart';

class ApiService {
  static const String _envApiHost = String.fromEnvironment('API_HOST');
  static const String _prefHostOverrideKey = 'api_host_override';
  static String? _runtimeHostOverride;

  /// Dynamic Host URL per platform:
  /// - Bisa di-override saat build/run via `--dart-define=API_HOST=http://...`
  /// - Web / Windows / macOS / iOS: http://127.0.0.1:8000/api/v1
  /// - Android Emulator: http://10.0.2.2:8000/api/v1
  /// - HP Android fisik via `adb reverse tcp:8000 tcp:8000`: http://127.0.0.1:8000/api/v1
  static String get baseUrl => '$rootHost/api/v1';

  /// Host dasar server (tanpa /api/v1) untuk memuat asset & file storage
  static String get rootHost {
    final envHost = _envApiHost.trim().replaceAll(RegExp(r'/+$'), '');
    if (envHost.isNotEmpty) {
      return envHost;
    }
    if (_runtimeHostOverride != null && _runtimeHostOverride!.isNotEmpty) {
      return _runtimeHostOverride!;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  /// Menyesuaikan URL gambar/lampiran agar valid di seluruh platform (Web, Android, iOS, Windows)
  static String? resolveUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    var trimmed = rawUrl.trim();

    if (trimmed.startsWith('data:')) {
      return trimmed;
    }

    // Reroute path /storage/ lokal ke endpoint API v1 storage yang didukung CORS lengkap
    // (kecuali URL eksternal seperti Supabase /storage/v1/object/).
    if (trimmed.contains('/storage/') &&
        !trimmed.contains('/api/v1/storage/') &&
        !trimmed.contains('/storage/v1/object/')) {
      trimmed = trimmed.replaceFirst('/storage/', '/api/v1/storage/');
    } else if (trimmed.startsWith('storage/')) {
      trimmed = '/api/v1/$trimmed';
    }

    // Android host resolution: mapping 127.0.0.1 / localhost ke rootHost aktif
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      if (trimmed.startsWith('http://127.0.0.1:8000')) {
        trimmed = trimmed.replaceFirst('http://127.0.0.1:8000', rootHost);
      } else if (trimmed.startsWith('http://localhost:8000')) {
        trimmed = trimmed.replaceFirst('http://localhost:8000', rootHost);
      }
    }

    // Resolusi path relatif (/storage/...) ke URL lengkap
    if (trimmed.startsWith('/')) {
      return '$rootHost$trimmed';
    }

    return trimmed;
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

    final deviceInfo = await AuditLogService.getDeviceInfo();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-NIK': nik,
      'X-Device-Info': deviceInfo,
    };
  }

  /// 1. Login Pegawai
  static Future<Map<String, dynamic>> login(String nik, String password) async {
    final envHost = _envApiHost.trim().replaceAll(RegExp(r'/+$'), '');
    final candidates = <String>[
      if (envHost.isNotEmpty)
        envHost
      else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
        if (_runtimeHostOverride != null && _runtimeHostOverride!.isNotEmpty)
          _runtimeHostOverride!,
        'http://127.0.0.1:8000',
        'http://10.0.2.2:8000',
      ] else
        rootHost,
    ];
    final uniqueHosts = candidates.toSet().toList();

    Object? lastError;
    final deviceInfo = await AuditLogService.getDeviceInfo();

    for (final host in uniqueHosts) {
      final url = Uri.parse('$host/api/v1/login');
      try {
        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-Device-Info': deviceInfo,
              },
              body: jsonEncode({'nik': nik, 'password': password}),
            )
            .timeout(const Duration(seconds: 12));

        if (!kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            envHost.isEmpty) {
          _runtimeHostOverride = host;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefHostOverrideKey, host);
          } catch (_) {}
        }

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
        lastError = e;
      }
    }

    return {'success': false, 'message': 'Gagal terhubung ke server Laravel: $lastError'};
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
    final savedHost = prefs.getString(_prefHostOverrideKey);
    if (savedHost != null && savedHost.isNotEmpty) {
      _runtimeHostOverride = savedHost;
    }
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
      final response = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 10));
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
  static Future<Map<String, dynamic>> getCuti({
    String? nik,
    bool all = false,
    int? tahun,
    String? status,
  }) async {
    final params = <String, String>{};
    if (nik != null && nik.isNotEmpty) params['nik'] = nik;
    if (all) params['all'] = '1';
    if (tahun != null) params['tahun'] = tahun.toString();
    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
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

  /// 11a. Detail Surat Izin Cuti Resmi (+ Pejabat Penandatangan dinamis)
  static Future<Map<String, dynamic>> getCutiSurat(dynamic id) async {
    final uri = Uri.parse('$baseUrl/cuti/$id/surat');
    try {
      final response = await http.get(uri, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 11b. Update Status Cuti Pegawai (Persetujuan oleh SDM / Direktur)
  static Future<Map<String, dynamic>> updateStatusCuti(
    int id,
    String status, {
    String? catatan,
  }) async {
    final url = Uri.parse('$baseUrl/cuti/$id/status');
    try {
      final response = await http.put(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'status': status,
          if (catatan != null) 'catatan_approver': catatan,
        }),
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
    String? alamatCuti,
    String? noTelp,
    bool autoApprove = false,
  }) async {
    final url = Uri.parse('$baseUrl/cuti');
    final prefs = await SharedPreferences.getInstance();
    final activeNik = (nik != null && nik.isNotEmpty)
        ? nik
        : (prefs.getString('user_nik') ?? '');

    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'nik': activeNik,
          'pegawai_nik': activeNik,
          'jenis': jenis,
          'jenis_cuti': jenis,
          'tanggal_mulai': tglMulai,
          'tgl_mulai': tglMulai,
          'tanggal_selesai': tglSelesai,
          'tgl_selesai': tglSelesai,
          'alasan': alasan,
          if (alamatCuti != null && alamatCuti.trim().isNotEmpty)
            'alamat_cuti': alamatCuti.trim(),
          if (noTelp != null && noTelp.trim().isNotEmpty)
            'no_telp': noTelp.trim(),
          if (autoApprove) 'auto_approve': true,
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

  static Future<Map<String, dynamic>> getPengaduanDetail(int id) async {
    final uri = Uri.parse('$baseUrl/pengaduan/$id');
    try {
      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(const Duration(seconds: 10));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> storePengaduan({
    required String subjek,
    required String pesan,
    String? nik,
    String? kategori,
    String? pihakTerlapor,
    String? nikPelaku,
    String? jabatanPelaku,
    List<String>? fotoBukti,
    List<String>? dokumenPendukung,
    List<String>? videoBukti,
    List<String>? voiceNote,
    bool? anonim,
    String? status,
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
          'kategori': kategori ?? 'Pelanggaran Administrasi',
          'pihak_terlapor': pihakTerlapor,
          'nik_pelaku': nikPelaku,
          'jabatan_pelaku': jabatanPelaku,
          'foto_bukti': fotoBukti,
          'dokumen_pendukung': dokumenPendukung,
          if (videoBukti != null && videoBukti.isNotEmpty) 'video_bukti': videoBukti,
          if (voiceNote != null && voiceNote.isNotEmpty) 'voice_note': voiceNote,
          'anonim': anonim ?? false,
          'status': status ?? 'menungguKadiv',
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateStatusPengaduan({
    required int id,
    String? status,
    String? kategori,
    String? catatan,
    String? aksi,
    String? keputusanKadiv,
    String? catatanKadiv,
    Map<String, dynamic>? extra,
  }) async {
    final url = Uri.parse('$baseUrl/pengaduan/$id/status');
    try {
      final payload = <String, dynamic>{
        'status': status,
        'kategori': kategori,
        'catatan': catatan,
        'aksi': aksi,
        'keputusan_kadiv': keputusanKadiv,
        'catatan_kadiv': catatanKadiv,
      };
      if (extra != null) {
        payload.addAll(extra);
      }
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(payload),
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

  /// 16. SK Sanksi (Penerbitan SK & Berkas Dokumen SDM)
  static Future<List<dynamic>> getSkSanksi({int? pengaduanId, String? nik}) async {
    final params = <String, String>{};
    if (pengaduanId != null) params['pengaduan_id'] = pengaduanId.toString();
    if (nik != null && nik.isNotEmpty) params['nik'] = nik;
    final uri = Uri.parse('$baseUrl/sk-sanksi').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders(explicitNik: nik));
      final res = jsonDecode(response.body);
      if (res['success'] == true && res['data'] is List) {
        return res['data'] as List<dynamic>;
      }
    } catch (_) {}
    return const [];
  }

  static Future<Map<String, dynamic>> storeSkSanksi(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/sk-sanksi');
    try {
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 17. Pusat Notifikasi Mobile (sinkron PostgreSQL `notifikasi`)
  static Future<Map<String, dynamic>> getNotifikasi({int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/notifikasi').replace(
      queryParameters: {'limit': limit.toString()},
    );
    try {
      final response = await http.get(uri, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e', 'data': []};
    }
  }

  static Future<Map<String, dynamic>> markNotifikasiRead(int id) async {
    final uri = Uri.parse('$baseUrl/notifikasi/$id/read');
    try {
      final response = await http.post(uri, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotifikasiRead() async {
    final uri = Uri.parse('$baseUrl/notifikasi/read-all');
    try {
      final response = await http.post(uri, headers: await _getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// 18. Logout - membersihkan seluruh sesi aktif, OneSignal, dan SharedPreferences
  static Future<void> logout() async {
    NotificationNavHelper.resetNavigationState();
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
