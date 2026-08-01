import 'package:supabase_flutter/supabase_flutter.dart';
import 'pegawai_data.dart';

/// =============================================================
/// B7 — ABSENSI ASLI (check-in / check-out harian)
///
/// Menggantikan sumber data dummy (jsonplaceholder) dengan presensi
/// nyata yang disimpan ke tabel `absensi_harian` di Supabase.
/// Ringkasan bulanan (Hadir/Telat/Izin) dihitung langsung dari tabel ini.
///
/// Skema lihat: supabase/fitur_tambahan.sql
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

  static final _client = Supabase.instance.client;
  static const _table = 'absensi_harian';

  /// Batas jam masuk normal (07:00–08:00). Lebih dari ini dianggap telat.
  static const int jamBatasMasuk = 8;

  static String _tanggalKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Ambil record absensi hari ini milik user login (null jika belum absen).
  static Future<AbsensiHarian?> hariIni() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final wibNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    final row = await _client
        .from(_table)
        .select()
        .eq('pegawai_id', uid)
        .eq('tanggal', _tanggalKey(wibNow))
        .maybeSingle();
    return row == null ? null : AbsensiHarian.fromRow(row);
  }

  /// Check-in. Status otomatis 'telat' bila lewat jam batas (WIB).
  static Future<void> checkIn({
    String? fotoUrl,
    double? lat,
    double? lng,
    String? keterangan,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sesi tidak valid, silakan login ulang.');
    final nowUtc = DateTime.now().toUtc();
    final wibNow = nowUtc.add(const Duration(hours: 7));
    final status = wibNow.hour >= jamBatasMasuk ? 'telat' : 'hadir';
    await _client.from(_table).insert({
      'pegawai_id': uid,
      'tanggal': _tanggalKey(wibNow),
      'jam_masuk': nowUtc.toIso8601String(),
      'status': status,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (keterangan != null && keterangan.isNotEmpty) 'keterangan': keterangan,
    });
  }

  /// Check-out (isi jam pulang) untuk record hari ini.
  static Future<void> checkOut({required int id}) async {
    await _client.from(_table).update({
      'jam_pulang': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Ajukan izin cepat untuk hari ini (status 'izin').
  static Future<void> ajukanIzinHariIni({required String keterangan}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sesi tidak valid, silakan login ulang.');
    final wibNow = DateTime.now().toUtc().add(const Duration(hours: 7));
    await _client.from(_table).insert({
      'pegawai_id': uid,
      'tanggal': _tanggalKey(wibNow),
      'status': 'izin',
      'keterangan': keterangan,
    });
  }

  /// Riwayat absensi terbaru milik user login.
  static Future<List<AbsensiHarian>> riwayat({int limit = 30}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .eq('pegawai_id', uid)
        .order('tanggal', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => AbsensiHarian.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Ringkasan bulan berjalan (dihitung dari absensi_harian).
  static Future<AttendanceSummary> ringkasanBulan({
    required int tahun,
    required int bulan,
    required String bulanLabel,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return AttendanceSummary(
          bulanLabel: bulanLabel, hadir: 0, telat: 0, izin: 0);
    }
    final awal = '${tahun.toString().padLeft(4, '0')}-'
        '${bulan.toString().padLeft(2, '0')}-01';
    final akhirBulan = (bulan == 12)
        ? DateTime(tahun + 1, 1, 1)
        : DateTime(tahun, bulan + 1, 1);
    final akhir = _tanggalKey(akhirBulan);
    final rows = await _client
        .from(_table)
        .select('status')
        .eq('pegawai_id', uid)
        .gte('tanggal', awal)
        .lt('tanggal', akhir);
    int hadir = 0, telat = 0, izin = 0;
    for (final r in (rows as List)) {
      switch (r['status']) {
        case 'hadir':
          hadir++;
          break;
        case 'telat':
          telat++;
          break;
        case 'izin':
          izin++;
          break;
      }
    }
    return AttendanceSummary(
        bulanLabel: bulanLabel, hadir: hadir, telat: telat, izin: izin);
  }
}
