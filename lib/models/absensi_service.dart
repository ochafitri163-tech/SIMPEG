import 'package:flutter/foundation.dart';
import 'pegawai_data.dart';
import '../services/api_service.dart';
import '../services/audit_log_service.dart';

/// =============================================================
/// B7 — ABSENSI ASLI (check-in / check-out harian)
///
/// Menyimpan presensi ke tabel `absensi_harian` via Laravel API backend.
/// Ringkasan bulanan (Hadir/Telat/Izin) dihitung langsung dari tabel ini.
/// =============================================================
class AbsensiHarian {
  final int id;
  final String pegawaiId;
  final DateTime tanggal; // tanggal kerja (lokal)
  final DateTime? jamMasuk;
  final DateTime? jamPulang;
  final String status; // 'hadir' | 'telat' | 'izin'
  final String? keterangan;
  final String? fotoUrl;
  final double? lat;
  final double? lng;

  const AbsensiHarian({
    required this.id,
    required this.pegawaiId,
    required this.tanggal,
    required this.status,
    this.jamMasuk,
    this.jamPulang,
    this.keterangan,
    this.fotoUrl,
    this.lat,
    this.lng,
  });

  bool get sudahPulang => jamPulang != null;

  factory AbsensiHarian.fromRow(Map<String, dynamic> row) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return AbsensiHarian(
      id: (row['id'] as num).toInt(),
      pegawaiId: (row['pegawai_id'] ?? '') as String,
      tanggal: parse(row['tanggal']) ?? DateTime.now(),
      jamMasuk: parse(row['jam_masuk'])?.toUtc(),
      jamPulang: parse(row['jam_pulang'])?.toUtc(),
      status: (row['status'] ?? 'hadir') as String,
      keterangan: row['keterangan'] as String?,
      fotoUrl: row['foto_url'] as String?,
      lat: (row['lat'] as num?)?.toDouble(),
      lng: (row['lng'] as num?)?.toDouble(),
    );
  }
}

class AbsensiService {
  AbsensiService._();

  /// Batas jam masuk normal (07:00–08:00). Lebih dari ini dianggap telat.
  static const int jamBatasMasuk = 8;

  static String _tanggalKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Ambil record absensi hari ini milik user login (null jika belum absen).
  static Future<AbsensiHarian?> hariIni() async {
    try {
      final res = await ApiService.getAbsensi();
      if (res['success'] == true && res['data'] is List) {
        final list = res['data'] as List;
        final wibNow = DateTime.now().toUtc().add(const Duration(hours: 7));
        final todayStr = _tanggalKey(wibNow);
        for (final item in list) {
          final map = Map<String, dynamic>.from(item as Map);
          final tgl = (map['tanggal'] ?? '').toString();
          if (tgl.startsWith(todayStr)) {
            return AbsensiHarian.fromRow(map);
          }
        }
      }
    } catch (e) {
      debugPrint('Error get hariIni absensi: $e');
    }
    return null;
  }

  /// Check-in.
  static Future<void> checkIn({
    String? fotoUrl,
    double? lat,
    double? lng,
    String? keterangan,
  }) async {
    final res = await ApiService.checkinAbsensi(
      latitude: lat,
      longitude: lng,
      fotoUrl: fotoUrl,
      keterangan: keterangan,
    );
    if (res['success'] != true) {
      throw StateError(res['message']?.toString() ?? 'Gagal melakukan check-in.');
    }
    AuditLogService.logAction(
      userNik: 'PEGAWAI',
      userName: 'Pegawai',
      role: 'PEGAWAI',
      action: 'CREATE',
      module: 'Absensi',
      description: 'Check-in absensi hari ini',
    );
  }

  /// Check-out (isi jam pulang) untuk record hari ini.
  static Future<void> checkOut({required int id}) async {
    final res = await ApiService.checkoutAbsensi(id: id);
    if (res['success'] != true) {
      throw StateError(res['message']?.toString() ?? 'Gagal melakukan check-out.');
    }
    AuditLogService.logAction(
      userNik: 'PEGAWAI',
      userName: 'Pegawai',
      role: 'PEGAWAI',
      action: 'UPDATE',
      module: 'Absensi',
      description: 'Check-out absensi hari ini (ID: $id)',
    );
  }

  /// Ajukan izin cepat untuk hari ini (status 'izin').
  static Future<void> ajukanIzinHariIni({required String keterangan}) async {
    final res = await ApiService.checkinAbsensi(
      keterangan: 'Izin: $keterangan',
    );
    if (res['success'] != true) {
      throw StateError(res['message']?.toString() ?? 'Gagal mengajukan izin.');
    }
  }

  /// Riwayat absensi terbaru milik user login.
  static Future<List<AbsensiHarian>> riwayat({int limit = 30}) async {
    try {
      final res = await ApiService.getAbsensi();
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List)
            .take(limit)
            .map((r) => AbsensiHarian.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Ringkasan bulan berjalan (dihitung dari absensi_harian).
  static Future<AttendanceSummary> ringkasanBulan({
    required int tahun,
    required int bulan,
    required String bulanLabel,
  }) async {
    try {
      final res = await ApiService.getAbsensi();
      if (res['success'] == true) {
        if (res['summary'] is Map) {
          final s = res['summary'] as Map;
          return AttendanceSummary(
            bulanLabel: s['bulan_label']?.toString() ?? bulanLabel,
            hadir: (s['hadir'] ?? 0) as int,
            telat: (s['telat'] ?? 0) as int,
            izin: (s['izin'] ?? 0) as int,
          );
        }
      }
    } catch (_) {}
    return AttendanceSummary(
        bulanLabel: bulanLabel, hadir: 0, telat: 0, izin: 0);
  }
}
