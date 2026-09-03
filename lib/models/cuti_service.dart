import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';
import 'pengaduan_service.dart' as notif;
import '../services/audit_log_service.dart';

/// =============================================================
/// B8 — PENGAJUAN CUTI / IZIN + ALUR PERSETUJUAN
///
/// Pegawai mengajukan cuti/izin/sakit -> notifikasi ke SDM & Direktur ->
/// approver menyetujui/menolak -> pegawai menerima notifikasi hasil.
///
/// Skema lihat: supabase/fitur_tambahan.sql
/// =============================================================
enum JenisCuti { cuti, izin, sakit }

extension JenisCutiX on JenisCuti {
  String get label {
    switch (this) {
      case JenisCuti.cuti:
        return 'Cuti';
      case JenisCuti.izin:
        return 'Izin';
      case JenisCuti.sakit:
        return 'Sakit';
    }
  }

  static JenisCuti fromName(String n) =>
      JenisCuti.values.firstWhere((e) => e.name == n, orElse: () => JenisCuti.izin);
}

enum StatusCuti { menunggu, disetujui, ditolak }

extension StatusCutiX on StatusCuti {
  String get label {
    switch (this) {
      case StatusCuti.menunggu:
        return 'Menunggu';
      case StatusCuti.disetujui:
        return 'Disetujui';
      case StatusCuti.ditolak:
        return 'Ditolak';
    }
  }

  static StatusCuti fromName(String n) => StatusCuti.values
      .firstWhere((e) => e.name == n, orElse: () => StatusCuti.menunggu);
}

class PengajuanCuti {
  final int id;
  final String pegawaiId;
  final String namaPegawai;
  final JenisCuti jenis;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String alasan;
  final StatusCuti status;
  final String? diputuskanOleh;
  final String? catatanApprover;
  final DateTime dibuatPada;

  const PengajuanCuti({
    required this.id,
    required this.pegawaiId,
    required this.namaPegawai,
    required this.jenis,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.alasan,
    required this.status,
    required this.dibuatPada,
    this.diputuskanOleh,
    this.catatanApprover,
  });

  int get jumlahHari => tanggalSelesai.difference(tanggalMulai).inDays + 1;

  factory PengajuanCuti.fromRow(Map<String, dynamic> row) {
    DateTime parse(dynamic v) =>
        DateTime.tryParse(v.toString()) ?? DateTime.now();
    return PengajuanCuti(
      id: (row['id'] as num).toInt(),
      pegawaiId: (row['pegawai_id'] ?? '') as String,
      namaPegawai: (row['nama_pegawai'] ?? 'Pegawai') as String,
      jenis: JenisCutiX.fromName((row['jenis'] ?? 'izin') as String),
      tanggalMulai: parse(row['tanggal_mulai']),
      tanggalSelesai: parse(row['tanggal_selesai']),
      alasan: (row['alasan'] ?? '') as String,
      status: StatusCutiX.fromName((row['status'] ?? 'menunggu') as String),
      diputuskanOleh: row['diputuskan_oleh'] as String?,
      catatanApprover: row['catatan_approver'] as String?,
      dibuatPada: parse(row['created_at']),
    );
  }
}

class CutiService {
  CutiService._();

  static final _client = Supabase.instance.client;
  static const _table = 'pengajuan_cuti';

  /// Role yang berwenang menyetujui/menolak pengajuan cuti.
  static const List<UserRole> roleApprover = [UserRole.sdm, UserRole.direktur];

  static String _tgl(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Pegawai — ajukan cuti/izin. Memvalidasi tanggal & alasan.
  static Future<void> ajukan({
    required String namaPegawai,
    required JenisCuti jenis,
    required DateTime mulai,
    required DateTime selesai,
    required String alasan,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sesi tidak valid, silakan login ulang.');
    if (alasan.trim().isEmpty) {
      throw ArgumentError('Alasan wajib diisi.');
    }
    if (selesai.isBefore(mulai)) {
      throw ArgumentError('Tanggal selesai tidak boleh sebelum tanggal mulai.');
    }
    await _client.from(_table).insert({
      'pegawai_id': uid,
      'nama_pegawai': namaPegawai,
      'jenis': jenis.name,
      'tanggal_mulai': _tgl(mulai),
      'tanggal_selesai': _tgl(selesai),
      'alasan': alasan.trim(),
      'status': StatusCuti.menunggu.name,
    });

    AuditLogService.logAction(
      userNik: uid,
      userName: namaPegawai,
      role: 'PEGAWAI',
      action: 'CREATE',
      module: 'Cuti',
      description: 'Mengajukan ${jenis.label} (${_tgl(mulai)} s/d ${_tgl(selesai)}): "${alasan.trim()}"',
    );

    for (final r in roleApprover) {
      try {
        await notif.NotificationService.kirimKeRole(
          role: r,
          judul: '📝 Pengajuan ${jenis.label} Baru',
          pesan: '$namaPegawai mengajukan ${jenis.label.toLowerCase()} '
              '(${_tgl(mulai)} s/d ${_tgl(selesai)}).',
        );
      } catch (_) {}
    }
  }

  /// Daftar pengajuan milik user login.
  static Future<List<PengajuanCuti>> milikSaya() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from(_table)
        .select()
        .eq('pegawai_id', uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => PengajuanCuti.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Approver — seluruh pengajuan (opsional filter status menunggu).
  static Future<List<PengajuanCuti>> semua({bool hanyaMenunggu = false}) async {
    var q = _client.from(_table).select();
    if (hanyaMenunggu) q = q.eq('status', StatusCuti.menunggu.name);
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => PengajuanCuti.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Approver — setujui / tolak pengajuan. Memberi notifikasi ke pegawai.
  static Future<void> putuskan({
    required PengajuanCuti pengajuan,
    required StatusCuti keputusan,
    required String namaApprover,
    String? catatan,
  }) async {
    await _client.from(_table).update({
      'status': keputusan.name,
      'diputuskan_oleh': namaApprover,
      'catatan_approver': catatan,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', pengajuan.id);

    AuditLogService.logAction(
      userNik: _client.auth.currentUser?.id ?? 'APPROVER',
      userName: namaApprover,
      role: 'SDM/DIREKTUR',
      action: 'UPDATE',
      module: 'Cuti',
      description: 'Memutuskan pengajuan ${pengajuan.jenis.label} #${pengajuan.id} milik ${pengajuan.namaPegawai} menjadi ${keputusan.label}',
    );

    try {
      await notif.NotificationService.kirimKePegawai(
        pegawaiId: pengajuan.pegawaiId,
        judul: keputusan == StatusCuti.disetujui
            ? '✅ ${pengajuan.jenis.label} Disetujui'
            : '❌ ${pengajuan.jenis.label} Ditolak',
        pesan: 'Pengajuan ${pengajuan.jenis.label.toLowerCase()} Anda '
            '(${_tgl(pengajuan.tanggalMulai)} s/d ${_tgl(pengajuan.tanggalSelesai)}) '
            '${keputusan.label.toLowerCase()} oleh $namaApprover.',
      );
    } catch (_) {}
  }
}
