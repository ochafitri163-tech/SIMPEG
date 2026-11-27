import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'audit_log_service.dart';
import 'notification_nav_helper.dart';
import 'onesignal_service.dart';

class ApiService {
  static const String _envApiHost = String.fromEnvironment('API_HOST');
  static const String _prefHostOverrideKey = 'api_host_override';
  static const String _secureTokenKey = 'auth_token';
  static const String _prefHasSecureTokenKey = 'has_secure_auth_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String? _runtimeHostOverride;
  static String? _cachedAuthToken;

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

  /// Simpan token JWT secara terenkripsi via FlutterSecureStorage.
  /// Token lama yang masih berada di SharedPreferences akan dibersihkan otomatis.
  static Future<void> _saveAuthToken(String token) async {
    _cachedAuthToken = token;
    try {
      await _secureStorage.write(key: _secureTokenKey, value: token);
    } catch (_) {
      // Abaikan jika plugin channel belum tersedia (mis. lingkungan widget test).
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefHasSecureTokenKey, token.isNotEmpty);
      await prefs.remove(_secureTokenKey);
    } catch (_) {}
  }

  /// Ambil token JWT aktif dari cache memori, FlutterSecureStorage,
  /// atau migrasi satu kali dari SharedPreferences versi lama.
  static Future<String> getAuthToken() async {
    if (_cachedAuthToken != null && _cachedAuthToken!.isNotEmpty) {
      return _cachedAuthToken!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString(_secureTokenKey) ?? '';
      if (legacyToken.isNotEmpty) {
        await _saveAuthToken(legacyToken);
        return legacyToken;
      }
      final hasSecure = prefs.getBool(_prefHasSecureTokenKey) ?? false;
      if (!hasSecure) {
        return '';
      }
    } catch (_) {}
    try {
      final secureVal = await _secureStorage.read(key: _secureTokenKey);
      if (secureVal != null && secureVal.isNotEmpty) {
        _cachedAuthToken = secureVal;
        return secureVal;
      }
    } catch (_) {
      // Plugin secure storage tidak tersedia di headless test.
    }
    return '';
  }

  /// Cek apakah token otentikasi server tersedia.
  static Future<bool> hasAuthToken() async {
    return (await getAuthToken()).isNotEmpty;
  }

  static Future<void> _clearAuthToken() async {
    _cachedAuthToken = null;
    try {
      await _secureStorage.delete(key: _secureTokenKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefHasSecureTokenKey);
      await prefs.remove(_secureTokenKey);
    } catch (_) {}
  }

  /// Reset token in-memory untuk pengujian unit/widget.
  @visibleForTesting
  static void resetAuthCacheForTest() {
    _cachedAuthToken = null;
  }

  static Future<Map<String, String>> _getHeaders({String? explicitNik}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getAuthToken();
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

  /// Helper HTTP JSON terpusat dengan timeout, validasi status HTTP,
  /// penguraian JSON aman, serta sanitasi pesan kesalahan.
  static Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    String? explicitNik,
    Duration timeout = const Duration(seconds: 15),
    String fallbackError = 'Gagal terhubung ke server. Silakan coba lagi.',
    Map<String, dynamic> extraFailureFields = const {},
  }) async {
    try {
      final headers = await _getHeaders(explicitNik: explicitNik);
      final encodedBody = body != null ? jsonEncode(body) : null;
      late final http.Response response;

      switch (method.toUpperCase()) {
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: encodedBody)
              .timeout(timeout);
          break;
        case 'GET':
        default:
          response = await http.get(uri, headers: headers).timeout(timeout);
          break;
      }

      Map<String, dynamic>? decoded;
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded != null) return decoded;
        return {
          'success': false,
          'message': 'Respons server tidak valid.',
          ...extraFailureFields,
        };
      }

      if (decoded != null && decoded['message'] is String) {
        final msg = (decoded['message'] as String).trim();
        return {
          'success': false,
          'status_code': response.statusCode,
          'message': response.statusCode >= 500
              ? 'Terjadi gangguan pada server (${response.statusCode}). Silakan coba lagi nanti.'
              : (msg.isNotEmpty ? msg : fallbackError),
          if (decoded.containsKey('data')) 'data': decoded['data'],
          ...extraFailureFields,
        };
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'status_code': 401,
          'message': 'Sesi Anda telah berakhir. Silakan login kembali.',
          ...extraFailureFields,
        };
      }
      if (response.statusCode == 403) {
        return {
          'success': false,
          'status_code': 403,
          'message': 'Akses ditolak.',
          ...extraFailureFields,
        };
      }
      if (response.statusCode == 429) {
        return {
          'success': false,
          'status_code': 429,
          'message': 'Terlalu banyak permintaan. Tunggu beberapa saat sebelum mencoba lagi.',
          ...extraFailureFields,
        };
      }

      return {
        'success': false,
        'status_code': response.statusCode,
        'message': response.statusCode >= 500
            ? 'Terjadi gangguan pada server (${response.statusCode}). Silakan coba lagi nanti.'
            : fallbackError,
        ...extraFailureFields,
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Koneksi ke server melebihi batas waktu. Periksa jaringan Anda.',
        ...extraFailureFields,
      };
    } catch (_) {
      return {
        'success': false,
        'message': fallbackError,
        ...extraFailureFields,
      };
    }
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

    bool hadTimeout = false;
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

        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic>
            ? decoded
            : Map<String, dynamic>.from(decoded as Map);

        if (response.statusCode == 200 && data['success'] == true) {
          final token = (data['data']?['token'] ?? '').toString();
          if (token.isNotEmpty) {
            await _saveAuthToken(token);
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_nik', (data['data']?['user']?['nik'] ?? '').toString());
          await prefs.setString('user_nama', (data['data']?['user']?['nama'] ?? '').toString());
          await prefs.setString('user_jabatan', (data['data']?['user']?['jabatan'] ?? '').toString());
        }
        return data;
      } on TimeoutException {
        hadTimeout = true;
      } catch (_) {}
    }

    return {
      'success': false,
      'message': hadTimeout
          ? 'Koneksi ke server login melebihi batas waktu. Periksa koneksi jaringan Anda.'
          : 'Gagal terhubung ke server autentikasi. Pastikan server aktif dan jaringan terhubung.',
    };
  }

  /// 2. Get Profil Pegawai
  static Future<Map<String, dynamic>> getProfile() => _requestJson(
        'GET',
        Uri.parse('$baseUrl/profile'),
        fallbackError: 'Gagal mengambil profil pegawai.',
      );

  /// 3. Get Slip Gaji Bulanan
  static Future<Map<String, dynamic>> getSlipGaji() => _requestJson(
        'GET',
        Uri.parse('$baseUrl/payroll/slip-gaji'),
        fallbackError: 'Gagal mengambil data slip gaji.',
      );

  /// 4. Get Slip THR
  static Future<Map<String, dynamic>> getSlipThr() => _requestJson(
        'GET',
        Uri.parse('$baseUrl/payroll/thr'),
        fallbackError: 'Gagal mengambil data THR.',
      );

  /// 5. Get Gaji 13
  static Future<Map<String, dynamic>> getGaji13() => _requestJson(
        'GET',
        Uri.parse('$baseUrl/payroll/gaji-13'),
        fallbackError: 'Gagal mengambil data gaji 13.',
      );

  /// 5a. Get Tunjangan Pendidikan (Regulasi 2026)
  static Future<Map<String, dynamic>> getTunjanganPendidikan({String? nik}) {
    final uri = Uri.parse('$baseUrl/payroll/tunjangan-pendidikan').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    return _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      fallbackError: 'Gagal mengambil data tunjangan pendidikan.',
    );
  }

  /// 5b. Get Insentif Pegawai
  static Future<Map<String, dynamic>> getInsentif({String? nik}) {
    final uri = Uri.parse('$baseUrl/payroll/insentif').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    return _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      fallbackError: 'Gagal mengambil data insentif.',
    );
  }

  /// 5c. Get Lembur Pegawai
  static Future<Map<String, dynamic>> getLembur({String? nik}) {
    final q = (nik != null && nik.isNotEmpty) ? '?nik=$nik' : '';
    return _requestJson(
      'GET',
      Uri.parse('$baseUrl/lembur$q'),
      explicitNik: nik,
      timeout: const Duration(seconds: 6),
      fallbackError: 'Gagal mengambil data lembur dari server.',
    );
  }

  /// 6. Get Absensi
  static Future<Map<String, dynamic>> getAbsensi() => _requestJson(
        'GET',
        Uri.parse('$baseUrl/absensi'),
        fallbackError: 'Gagal mengambil data absensi.',
      );

  /// 7. Daftar Pegawai (Master Data dari PostgreSQL lokal)
  static Future<List<Map<String, dynamic>>> listPegawai({String? search, int perPage = 200}) async {
    final query = search != null && search.isNotEmpty
        ? '?search=${Uri.encodeComponent(search)}&per_page=$perPage'
        : '?per_page=$perPage';
    final res = await _requestJson(
      'GET',
      Uri.parse('$baseUrl/pegawai$query'),
      fallbackError: 'Gagal memuat daftar pegawai.',
    );
    if (res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data']);
    }
    return [];
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
  static Future<Map<String, dynamic>> getDokumenResmi({
    String? nik,
    String? scope,
  }) {
    final params = <String, String>{};
    if (nik != null && nik.isNotEmpty) params['nik'] = nik;
    if (scope != null && scope.isNotEmpty) params['scope'] = scope;
    final uri = Uri.parse('$baseUrl/dokumen').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    return _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      timeout: const Duration(seconds: 6),
      fallbackError: 'Gagal mengambil data dokumen dari server.',
    );
  }

  static Future<Map<String, dynamic>> storeDokumen({
    String? pegawaiId,
    required String judul,
    required String kategori,
    required String fileUrl,
    required String fileNama,
    required String diunggahOleh,
    String? nomor,
    DateTime? tglTerbit,
  }) =>
      _requestJson(
        'POST',
        Uri.parse('$baseUrl/dokumen'),
        body: {
          if (pegawaiId != null && pegawaiId.trim().isNotEmpty)
            'pegawai_id': pegawaiId.trim(),
          'judul': judul.trim(),
          'kategori': kategori.trim(),
          'file_url': fileUrl,
          'file_nama': fileNama.trim(),
          'diunggah_oleh': diunggahOleh.trim(),
          if (nomor != null && nomor.trim().isNotEmpty) 'nomor': nomor.trim(),
          if (tglTerbit != null) 'tgl_terbit': tglTerbit.toIso8601String(),
        },
        fallbackError: 'Gagal menyimpan dokumen ke server.',
      );

  static Future<Map<String, dynamic>> deleteDokumen(int id) => _requestJson(
        'DELETE',
        Uri.parse('$baseUrl/dokumen/$id'),
        fallbackError: 'Gagal menghapus dokumen di server.',
      );

  /// 9. Get Pengumuman Perusahaan
  static Future<Map<String, dynamic>> getPengumuman({String? scope}) {
    final uri = (scope != null && scope.isNotEmpty)
        ? Uri.parse('$baseUrl/pengumuman').replace(queryParameters: {'scope': scope})
        : Uri.parse('$baseUrl/pengumuman');
    return _requestJson(
      'GET',
      uri,
      timeout: const Duration(seconds: 10),
      fallbackError: 'Gagal mengambil data pengumuman.',
    );
  }

  static Future<Map<String, dynamic>> storePengumuman({
    required String judul,
    required String isi,
    required String prioritas,
    required bool disematkan,
    required bool aktif,
    required List<String> targetRoles,
    DateTime? terbitPada,
    DateTime? kedaluwarsaPada,
    String? lampiranUrl,
    String? lampiranNama,
  }) =>
      _requestJson(
        'POST',
        Uri.parse('$baseUrl/pengumuman'),
        body: {
          'judul': judul.trim(),
          'isi': isi.trim(),
          'prioritas': prioritas,
          'disematkan': disematkan,
          'aktif': aktif,
          'target_roles': targetRoles,
          if (terbitPada != null) 'terbit_pada': terbitPada.toIso8601String(),
          if (kedaluwarsaPada != null)
            'kedaluwarsa_pada': kedaluwarsaPada.toIso8601String(),
          if (lampiranUrl != null) 'lampiran_url': lampiranUrl,
          if (lampiranNama != null) 'lampiran_nama': lampiranNama,
        },
        fallbackError: 'Gagal menyimpan pengumuman ke server.',
      );

  static Future<Map<String, dynamic>> updatePengumuman({
    required int id,
    required String judul,
    required String isi,
    required String prioritas,
    required bool disematkan,
    required List<String> targetRoles,
    DateTime? terbitPada,
    DateTime? kedaluwarsaPada,
    String? lampiranUrl,
    String? lampiranNama,
  }) =>
      _requestJson(
        'PUT',
        Uri.parse('$baseUrl/pengumuman/$id'),
        body: {
          'judul': judul.trim(),
          'isi': isi.trim(),
          'prioritas': prioritas,
          'disematkan': disematkan,
          'target_roles': targetRoles,
          if (terbitPada != null) 'terbit_pada': terbitPada.toIso8601String(),
          if (kedaluwarsaPada != null)
            'kedaluwarsa_pada': kedaluwarsaPada.toIso8601String(),
          if (lampiranUrl != null) 'lampiran_url': lampiranUrl,
          if (lampiranNama != null) 'lampiran_nama': lampiranNama,
        },
        fallbackError: 'Gagal memperbarui pengumuman di server.',
      );

  static Future<Map<String, dynamic>> togglePengumumanStatus(
    int id, {
    required bool aktif,
  }) =>
      _requestJson(
        'PATCH',
        Uri.parse('$baseUrl/pengumuman/$id/status'),
        body: {'aktif': aktif},
        fallbackError: 'Gagal mengubah status pengumuman di server.',
      );

  static Future<Map<String, dynamic>> deletePengumuman(int id) => _requestJson(
        'DELETE',
        Uri.parse('$baseUrl/pengumuman/$id'),
        fallbackError: 'Gagal menghapus pengumuman di server.',
      );

  /// 10. Tandai Pengumuman Dibaca
  static Future<Map<String, dynamic>> markPengumumanRead(int id) => _requestJson(
        'POST',
        Uri.parse('$baseUrl/pengumuman/$id/baca'),
        fallbackError: 'Gagal menandai pengumuman telah dibaca.',
      );

  /// 11. Cuti Pegawai
  static Future<Map<String, dynamic>> getCuti({
    String? nik,
    bool all = false,
    int? tahun,
    String? status,
  }) {
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
    return _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      fallbackError: 'Gagal mengambil data cuti.',
    );
  }

  /// 11a. Detail Surat Izin Cuti Resmi (+ Pejabat Penandatangan dinamis)
  static Future<Map<String, dynamic>> getCutiSurat(dynamic id) => _requestJson(
        'GET',
        Uri.parse('$baseUrl/cuti/$id/surat'),
        fallbackError: 'Gagal mengambil detail surat cuti.',
      );

  /// 11b. Update Status Cuti Pegawai (Persetujuan oleh SDM / Direktur)
  static Future<Map<String, dynamic>> updateStatusCuti(
    int id,
    String status, {
    String? catatan,
  }) =>
      _requestJson(
        'PUT',
        Uri.parse('$baseUrl/cuti/$id/status'),
        body: {
          'status': status,
          if (catatan != null) 'catatan_approver': catatan,
        },
        fallbackError: 'Gagal memperbarui status pengajuan cuti.',
      );

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
    final prefs = await SharedPreferences.getInstance();
    final activeNik = (nik != null && nik.isNotEmpty)
        ? nik
        : (prefs.getString('user_nik') ?? '');

    return _requestJson(
      'POST',
      Uri.parse('$baseUrl/cuti'),
      body: {
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
      },
      fallbackError: 'Gagal mengirim pengajuan cuti.',
    );
  }

  /// 12. Pengaduan Pegawai
  static Future<Map<String, dynamic>> getPengaduan({String? nik, String? scope, String? tab}) {
    final params = <String, String>{};
    if (nik != null && nik.isNotEmpty) params['nik'] = nik;
    if (scope != null && scope.isNotEmpty) params['scope'] = scope;
    if (tab != null && tab.isNotEmpty) params['tab'] = tab;
    final uri = Uri.parse('$baseUrl/pengaduan').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    return _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      fallbackError: 'Gagal mengambil data pengaduan.',
    );
  }

  static Future<Map<String, dynamic>> getPengaduanDetail(int id) => _requestJson(
        'GET',
        Uri.parse('$baseUrl/pengaduan/$id'),
        timeout: const Duration(seconds: 10),
        fallbackError: 'Gagal mengambil detail pengaduan.',
      );

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
    final prefs = await SharedPreferences.getInstance();
    final activeNik = nik ?? prefs.getString('user_nik') ?? '';

    return _requestJson(
      'POST',
      Uri.parse('$baseUrl/pengaduan'),
      explicitNik: activeNik,
      timeout: const Duration(seconds: 30),
      body: {
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
      },
      fallbackError: 'Gagal mengirim pengaduan.',
    );
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
  }) {
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
    return _requestJson(
      'POST',
      Uri.parse('$baseUrl/pengaduan/$id/status'),
      timeout: const Duration(seconds: 35),
      body: payload,
      fallbackError: 'Gagal memperbarui status pengaduan.',
    );
  }

  /// 13. Sanksi & Prestasi
  static Future<Map<String, dynamic>> getSanksi({String? nik}) {
    final uri = Uri.parse('$baseUrl/sanksi').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    return _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      fallbackError: 'Gagal mengambil data sanksi.',
    );
  }

  static Future<Map<String, dynamic>> getPrestasi({String? nik}) {
    final uri = Uri.parse('$baseUrl/prestasi').replace(
      queryParameters: nik != null && nik.isNotEmpty ? {'nik': nik} : null,
    );
    return _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      fallbackError: 'Gagal mengambil data prestasi.',
    );
  }

  /// 14. Ganti Password
  static Future<Map<String, dynamic>> gantiPassword({
    required String oldPassword,
    required String newPassword,
    String? nik,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final activeNik = nik ?? prefs.getString('user_nik') ?? '';

    return _requestJson(
      'POST',
      Uri.parse('$baseUrl/ganti-password'),
      explicitNik: activeNik,
      body: {
        'nik': activeNik,
        'old_password': oldPassword,
        'new_password': newPassword,
      },
      fallbackError: 'Gagal mengubah password.',
    );
  }

  /// 15. Checkin & Checkout Absensi
  static Future<Map<String, dynamic>> checkinAbsensi({
    String? nik,
    double? latitude,
    double? longitude,
    String? fotoUrl,
    String? keterangan,
  }) =>
      _requestJson(
        'POST',
        Uri.parse('$baseUrl/absensi/checkin'),
        explicitNik: nik,
        body: {
          if (nik != null) 'nik': nik,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (fotoUrl != null) 'foto_url': fotoUrl,
          if (keterangan != null) 'keterangan': keterangan,
        },
        fallbackError: 'Gagal melakukan absensi masuk.',
      );

  static Future<Map<String, dynamic>> checkoutAbsensi({
    String? nik,
    int? id,
  }) =>
      _requestJson(
        'POST',
        Uri.parse('$baseUrl/absensi/checkout'),
        explicitNik: nik,
        body: {
          if (nik != null) 'nik': nik,
          if (id != null) 'id': id,
        },
        fallbackError: 'Gagal melakukan absensi pulang.',
      );

  /// 16. SK Sanksi (Penerbitan SK & Berkas Dokumen SDM)
  static Future<List<dynamic>> getSkSanksi({int? pengaduanId, String? nik}) async {
    final params = <String, String>{};
    if (pengaduanId != null) params['pengaduan_id'] = pengaduanId.toString();
    if (nik != null && nik.isNotEmpty) params['nik'] = nik;
    final uri = Uri.parse('$baseUrl/sk-sanksi').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final res = await _requestJson(
      'GET',
      uri,
      explicitNik: nik,
      fallbackError: 'Gagal mengambil daftar SK sanksi.',
    );
    if (res['success'] == true && res['data'] is List) {
      return res['data'] as List<dynamic>;
    }
    return const [];
  }

  static Future<Map<String, dynamic>> storeSkSanksi(Map<String, dynamic> data) =>
      _requestJson(
        'POST',
        Uri.parse('$baseUrl/sk-sanksi'),
        timeout: const Duration(seconds: 45),
        body: data,
        fallbackError: 'Gagal menyimpan SK sanksi.',
      );

  /// 17. Pusat Notifikasi Mobile (sinkron PostgreSQL `notifikasi`)
  static Future<Map<String, dynamic>> getNotifikasi({int limit = 50}) {
    final uri = Uri.parse('$baseUrl/notifikasi').replace(
      queryParameters: {'limit': limit.toString()},
    );
    return _requestJson(
      'GET',
      uri,
      fallbackError: 'Gagal mengambil daftar notifikasi.',
      extraFailureFields: const {'data': []},
    );
  }

  static Future<Map<String, dynamic>> markNotifikasiRead(int id) => _requestJson(
        'POST',
        Uri.parse('$baseUrl/notifikasi/$id/read'),
        fallbackError: 'Gagal menandai notifikasi telah dibaca.',
      );

  static Future<Map<String, dynamic>> markAllNotifikasiRead() => _requestJson(
        'POST',
        Uri.parse('$baseUrl/notifikasi/read-all'),
        fallbackError: 'Gagal menandai seluruh notifikasi telah dibaca.',
      );

  /// 16. Agenda Kantor
  static Future<Map<String, dynamic>> getAgenda({
    int? tahun,
    int? bulan,
    bool upcoming = false,
    int limit = 20,
  }) {
    final params = <String, String>{};
    if (tahun != null) params['tahun'] = tahun.toString();
    if (bulan != null) params['bulan'] = bulan.toString();
    if (upcoming) {
      params['upcoming'] = '1';
      params['limit'] = limit.toString();
    }
    final uri = Uri.parse('$baseUrl/agenda').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    return _requestJson(
      'GET',
      uri,
      fallbackError: 'Gagal mengambil data agenda dari server.',
    );
  }

  static Future<Map<String, dynamic>> storeAgenda({
    required String judul,
    required DateTime tanggal,
    String? deskripsi,
    String? waktu,
    String? lokasi,
    required String dibuatOleh,
  }) =>
      _requestJson(
        'POST',
        Uri.parse('$baseUrl/agenda'),
        body: {
          'judul': judul.trim(),
          'tanggal':
              '${tanggal.year.toString().padLeft(4, '0')}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}',
          if (deskripsi != null && deskripsi.trim().isNotEmpty)
            'deskripsi': deskripsi.trim(),
          if (waktu != null && waktu.trim().isNotEmpty) 'waktu': waktu.trim(),
          if (lokasi != null && lokasi.trim().isNotEmpty)
            'lokasi': lokasi.trim(),
          'dibuat_oleh': dibuatOleh.trim(),
        },
        fallbackError: 'Gagal menyimpan agenda ke server.',
      );

  static Future<Map<String, dynamic>> deleteAgenda(int id) => _requestJson(
        'DELETE',
        Uri.parse('$baseUrl/agenda/$id'),
        fallbackError: 'Gagal menghapus agenda di server.',
      );

  /// 17. Tugas Eksekutor Pengaduan (Tasks)
  static Future<Map<String, dynamic>> getTasks() => _requestJson(
        'GET',
        Uri.parse('$baseUrl/tasks'),
        fallbackError: 'Gagal mengambil daftar tugas dari server.',
      );

  static Future<Map<String, dynamic>> updateTaskStatus({
    required int id,
    required String status,
    String? notes,
    List<String> proofFiles = const [],
  }) =>
      _requestJson(
        'POST',
        Uri.parse('$baseUrl/tasks/$id/status'),
        body: {
          'status': status,
          if (notes != null) 'notes': notes,
          'proof_files': proofFiles,
        },
        fallbackError: 'Gagal memperbarui status tugas di server.',
      );

  /// 18. Logout - membersihkan seluruh sesi aktif, OneSignal, SecureStorage, dan SharedPreferences
  static Future<void> logout() async {
    NotificationNavHelper.resetNavigationState();
    try {
      await OneSignalService.instance.logoutUser();
    } catch (_) {}
    await _clearAuthToken();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_nik');
      await prefs.remove('user_nama');
      await prefs.remove('user_jabatan');
      await prefs.remove('user_session_json');
    } catch (_) {}
  }
}
