import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_role.dart';
import '../services/notification_service.dart';
import '../services/onesignal_service.dart';
import '../services/audit_log_service.dart';
import '../services/api_service.dart';
import 'pengaduan_service.dart' as db_notif;

/// =============================================================
/// FITUR PENGUMUMAN (versi lengkap)
///
/// Dibuat & dikelola oleh role SDM, dipublikasikan (kolom `aktif`) lalu
/// otomatis tampil pada dashboard kelima role: Pegawai, Kadiv, KSPI,
/// TPDPK, Direktur. SATU sumber data (tabel `pengumuman`).
/// =============================================================
class Pengumuman {
  final int id;
  final String judul;
  final String isi;
  final bool aktif;
  final String prioritas; // 'penting' | 'umum'
  final bool disematkan;
  final List<String> targetRoles; // kosong = semua role
  final String pembuat;
  final String? pembuatId;
  final DateTime tanggalPublikasi; // created_at
  final DateTime? terbitPada; // jadwal terbit (null = langsung)
  final DateTime? kedaluwarsaPada; // auto nonaktif setelah ini
  final String? lampiranUrl;
  final String? lampiranNama;
  final DateTime? tanggalUbah;

  const Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.aktif,
    required this.prioritas,
    required this.disematkan,
    required this.targetRoles,
    required this.pembuat,
    required this.tanggalPublikasi,
    this.pembuatId,
    this.terbitPada,
    this.kedaluwarsaPada,
    this.lampiranUrl,
    this.lampiranNama,
    this.tanggalUbah,
  });

  bool get isPenting => prioritas == 'penting';
  bool get adaLampiran => (lampiranUrl != null && lampiranUrl!.isNotEmpty);
  DateTime get dibuatPada => tanggalPublikasi;
  DateTime? get diubahPada => tanggalUbah;

  /// Ringkasan isi untuk card dashboard (dipangkas rapi).
  String get ringkasan {
    final bersih = isi.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (bersih.length <= 140) return bersih;
    return '${bersih.substring(0, 140).trimRight()}…';
  }

  /// Tanggal / jam efektif tayang pengumuman (jika dijadwalkan, gunakan jadwal terbit).
  DateTime get tanggalTayang => terbitPada ?? tanggalPublikasi;

  /// Cek apakah pengumuman sudah melewati batas waktu kedaluwarsa.
  bool get sudahKedaluwarsa {
    if (kedaluwarsaPada == null) return false;
    return DateTime.now().toUtc().isAfter(kedaluwarsaPada!);
  }

  /// Cek apakah pengumuman masih menunggu jam jadwal terbit.
  bool get sedangTerjadwal {
    if (!aktif || sudahKedaluwarsa) return false;
    if (terbitPada == null) return false;
    final now = DateTime.now().toUtc();
    return now.isBefore(terbitPada!);
  }

  /// Sedang tayang: aktif, sudah memasuki/melewati jadwal terbit, & belum kedaluwarsa.
  bool get sedangTayang {
    if (!aktif || sudahKedaluwarsa) return false;
    if (terbitPada != null) {
      final now = DateTime.now().toUtc();
      // Toleransi 1 menit jika jam terbit disetel ke menit berjalan pada server web
      if (now.isBefore(terbitPada!.subtract(const Duration(minutes: 1)))) {
        return false;
      }
    }
    return true;
  }

  bool untukRole(UserRole role) {
    if (targetRoles.isEmpty) return true;
    final rName = role.name.toLowerCase().trim();
    final rKode = role.kode.toLowerCase().trim();
    return targetRoles.any((t) {
      final clean = t
          .toLowerCase()
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('[', '')
          .replaceAll(']', '')
          .trim();
      return clean == rName ||
          clean == rKode ||
          clean == 'semua' ||
          clean == 'all' ||
          clean.contains(rName) ||
          clean.contains(rKode) ||
          (clean.contains('kadiv') && rName.contains('kadiv')) ||
          (clean.contains('dirut') && (rName.contains('direktur') || rKode.contains('dirut'))) ||
          (clean.contains('direktur') && (rName.contains('direktur') || rKode.contains('dirut')));
    });
  }

  factory Pengumuman.fromRow(Map<String, dynamic> row) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();

    bool parseBool(dynamic v, {bool fallback = false}) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 't' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'f' || s == 'no') return false;
      return fallback;
    }

    int parseId(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    List<String> parseRoles(dynamic v) {
      if (v == null) return const [];
      if (v is List) {
        return v
            .map((e) => e.toString().replaceAll('"', '').replaceAll("'", '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (v is String) {
        final trimmed = v
            .replaceAll('{', '')
            .replaceAll('}', '')
            .replaceAll('"', '')
            .replaceAll("'", '')
            .trim();
        if (trimmed.isEmpty) return const [];
        return trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    final isPenting = row['prioritas'] == true ||
        row['prioritas'] == 'penting' ||
        row['prioritas'] == 1 ||
        row['prioritas'] == '1';

    return Pengumuman(
      id: parseId(row['id']),
      judul: (row['judul'] ?? '').toString(),
      isi: (row['isi'] ?? '').toString(),
      aktif: parseBool(row['aktif'], fallback: true),
      prioritas: isPenting ? 'penting' : 'umum',
      disematkan: parseBool(row['disematkan'] ?? row['is_pinned']),
      targetRoles: parseRoles(row['target_roles']),
      pembuat: (row['pembuat'] ?? row['penulis'] ?? 'SDM').toString(),
      pembuatId: row['pembuat_id']?.toString(),
      tanggalPublikasi: parse(row['created_at']) ?? DateTime.now().toUtc(),
      terbitPada: parse(row['terbit_pada']),
      kedaluwarsaPada: parse(row['kedaluwarsa_pada']),
      lampiranUrl: row['lampiran_url']?.toString(),
      lampiranNama: row['lampiran_nama']?.toString(),
      tanggalUbah: parse(row['updated_at']),
    );
  }
}

/// =============================================================
/// PengumumanService — akses data pengumuman via Laravel API & lokal.
/// =============================================================
class PengumumanService {
  PengumumanService._();

  static final Map<int, Timer> _activeTimers = {};
  static final Map<int, Timer> _activeExpiryTimers = {};
  static final List<Pengumuman> _localCache = [];

  static const List<UserRole> roleTujuan = [
    UserRole.pegawai,
    UserRole.kadivKategori,
    UserRole.kspi,
    UserRole.tpdpk,
    UserRole.direktur,
    UserRole.sdm,
    UserRole.keuangan,
  ];

  static Future<void> autoNonaktifkanExpired() async {}

  static Stream<List<Pengumuman>> streamTayang(UserRole role) async* {
    try {
      final initial = await tayangSekali(role);
      yield initial;
    } catch (_) {}

    final controller = StreamController<List<Pengumuman>>();
    final pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final list = await tayangSekali(role);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (_) {}
    });

    controller.onCancel = () {
      pollingTimer.cancel();
      controller.close();
    };

    yield* controller.stream;
  }

  static Future<List<Pengumuman>> semua() async {
    final List<Pengumuman> list = [];
    final Set<int> seenIds = {};

    try {
      final res = await ApiService.getPengumuman();
      if (res['success'] == true && res['data'] is List) {
        for (final r in (res['data'] as List)) {
          final p = Pengumuman.fromRow(Map<String, dynamic>.from(r as Map));
          if (p.id != 0 && !seenIds.contains(p.id)) {
            seenIds.add(p.id);
            list.add(p);
          }
        }
      }
    } catch (_) {}

    for (final loc in _localCache) {
      if (!seenIds.contains(loc.id)) {
        seenIds.add(loc.id);
        list.add(loc);
      }
    }

    list.sort((a, b) {
      if (a.disematkan != b.disematkan) return a.disematkan ? -1 : 1;
      return b.tanggalTayang.compareTo(a.tanggalTayang);
    });
    return list;
  }

  static Future<List<Pengumuman>> tayangSekali(UserRole role) async {
    final list = await semua();
    return list.where((p) => p.sedangTayang && p.untukRole(role)).toList();
  }

  static Future<Pengumuman?> ambilById(int id) async {
    final list = await semua();
    for (final p in list) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Future<Set<int>> idSudahDibaca() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pengumuman_dibaca_ids') ?? [];
      return list.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> tandaiDibaca(int pengumumanId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('pengumuman_dibaca_ids') ?? [];
      final idStr = pengumumanId.toString();
      if (!list.contains(idStr)) {
        list.add(idStr);
        await prefs.setStringList('pengumuman_dibaca_ids', list);
      }
      await ApiService.markPengumumanRead(pengumumanId);
    } catch (_) {}
  }

  static Future<String> uploadLampiran({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    try {
      if (bytes.isNotEmpty) {
        return 'data:${contentType ?? 'application/octet-stream'};base64,${base64Encode(bytes)}';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  static Future<Pengumuman> buat({
    required String judul,
    required String isi,
    required String prioritas,
    required bool disematkan,
    required List<UserRole> target,
    bool aktif = true,
    DateTime? terbitPada,
    DateTime? kedaluwarsaPada,
    String? lampiranUrl,
    String? lampiranNama,
    required dynamic pembuat,
  }) async {
    final j = judul.trim();
    final i = isi.trim();
    if (j.isEmpty || i.isEmpty) {
      throw ArgumentError('Judul dan isi pengumuman wajib diisi.');
    }
    final targetNames = target.map((r) => r.name).toList();
    final pembuatName =
        pembuat is AppUser ? pembuat.name : pembuat.toString();
    final pembuatId =
        pembuat is AppUser ? pembuat.nik : 'SDM';

    final newP = Pengumuman(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      judul: j,
      isi: i,
      prioritas: prioritas,
      disematkan: disematkan,
      aktif: aktif,
      targetRoles: targetNames,
      pembuat: pembuatName,
      pembuatId: pembuatId?.toString(),
      tanggalPublikasi: DateTime.now(),
      terbitPada: terbitPada,
      kedaluwarsaPada: kedaluwarsaPada,
      lampiranUrl: lampiranUrl,
      lampiranNama: lampiranNama,
      tanggalUbah: DateTime.now(),
    );

    _localCache.insert(0, newP);
    _jadwalkanTimerPengumuman(newP);

    if (newP.sedangTayang) {
      await _kirimNotifikasi(
          pengumumanId: newP.id,
          judul: j,
          target: target.isEmpty ? roleTujuan : target);
    }

    AuditLogService.logAction(
      userNik: pembuatId?.toString() ?? 'SDM',
      userName: pembuatName,
      role: 'SDM',
      action: 'CREATE',
      module: 'Pengumuman',
      description: 'Membuat pengumuman baru ID #${newP.id}: "$j"',
    );

    return newP;
  }

  static Future<void> ubah({
    required int id,
    required String judul,
    required String isi,
    required String prioritas,
    required bool disematkan,
    required List<UserRole> target,
    DateTime? terbitPada,
    DateTime? kedaluwarsaPada,
    String? lampiranUrl,
    String? lampiranNama,
  }) async {
    final j = judul.trim();
    final i = isi.trim();
    final targetNames = target.map((r) => r.name).toList();

    final idx = _localCache.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final old = _localCache[idx];
      final updated = Pengumuman(
        id: old.id,
        judul: j,
        isi: i,
        prioritas: prioritas,
        disematkan: disematkan,
        aktif: old.aktif,
        targetRoles: targetNames,
        pembuat: old.pembuat,
        pembuatId: old.pembuatId,
        tanggalPublikasi: old.tanggalPublikasi,
        terbitPada: terbitPada ?? old.terbitPada,
        kedaluwarsaPada: kedaluwarsaPada ?? old.kedaluwarsaPada,
        lampiranUrl: lampiranUrl ?? old.lampiranUrl,
        lampiranNama: lampiranNama ?? old.lampiranNama,
        tanggalUbah: DateTime.now(),
      );
      _localCache[idx] = updated;
      _jadwalkanTimerPengumuman(updated);
    }

    AuditLogService.logAction(
      userNik: 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'UPDATE',
      module: 'Pengumuman',
      description: 'Mengubah pengumuman ID #$id: "$j"',
    );
  }

  static Future<void> setAktif({required int id, required bool aktif}) async {
    final idx = _localCache.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final old = _localCache[idx];
      final updated = Pengumuman(
        id: old.id,
        judul: old.judul,
        isi: old.isi,
        prioritas: old.prioritas,
        disematkan: old.disematkan,
        aktif: aktif,
        targetRoles: old.targetRoles,
        pembuat: old.pembuat,
        pembuatId: old.pembuatId,
        tanggalPublikasi: old.tanggalPublikasi,
        terbitPada: old.terbitPada,
        kedaluwarsaPada: old.kedaluwarsaPada,
        lampiranUrl: old.lampiranUrl,
        lampiranNama: old.lampiranNama,
        tanggalUbah: DateTime.now(),
      );
      _localCache[idx] = updated;
      if (aktif) {
        _jadwalkanTimerPengumuman(updated);
        if (updated.sedangTayang) {
          await _kirimNotifikasi(
              pengumumanId: updated.id, judul: updated.judul, target: roleTujuan);
        }
      } else {
        _batalkanTimerPengumuman(id);
        await NotificationService.instance.cancelPengumuman(id);
      }
    }

    AuditLogService.logAction(
      userNik: 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'UPDATE',
      module: 'Pengumuman',
      description: '${aktif ? 'Mengaktifkan' : 'Menonaktifkan'} pengumuman ID #$id',
    );
  }

  static Future<void> hapus({required int id}) async {
    _batalkanTimerPengumuman(id);
    await NotificationService.instance.cancelPengumuman(id);
    _localCache.removeWhere((p) => p.id == id);

    AuditLogService.logAction(
      userNik: 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'DELETE',
      module: 'Pengumuman',
      description: 'Menghapus pengumuman ID #$id',
    );
  }

  static void _jadwalkanTimerPengumuman(Pengumuman p) {
    _batalkanTimerPengumuman(p.id);

    if (!p.aktif || p.sudahKedaluwarsa) {
      NotificationService.instance.cancelPengumuman(p.id);
      return;
    }

    final nowUtc = DateTime.now().toUtc();

    if (p.terbitPada != null && p.terbitPada!.isAfter(nowUtc)) {
      NotificationService.instance.schedulePengumuman(
        id: p.id,
        title: 'Pengumuman Baru',
        body: p.judul,
        scheduledDate: p.terbitPada!.toLocal(),
      );

      final delay = p.terbitPada!.difference(nowUtc);
      if (delay > Duration.zero) {
        _activeTimers[p.id] = Timer(delay, () async {
          _activeTimers.remove(p.id);
          NotificationService.instance.showPengumuman(
            title: 'Pengumuman Baru',
            body: p.judul,
          );
          await _kirimNotifikasi(
              pengumumanId: p.id, judul: p.judul, target: roleTujuan);
        });
      }
    }

    if (p.kedaluwarsaPada != null && p.kedaluwarsaPada!.isAfter(nowUtc)) {
      final expiryDelay = p.kedaluwarsaPada!.difference(nowUtc);
      if (expiryDelay > Duration.zero) {
        _activeExpiryTimers[p.id] = Timer(expiryDelay, () async {
          _activeExpiryTimers.remove(p.id);
          NotificationService.instance.cancelPengumuman(p.id);
          await setAktif(id: p.id, aktif: false);
        });
      }
    }
  }

  static void _batalkanTimerPengumuman(int id) {
    _activeTimers[id]?.cancel();
    _activeTimers.remove(id);
    _activeExpiryTimers[id]?.cancel();
    _activeExpiryTimers.remove(id);
  }

  static Future<void> sinkronkanJadwalPengumuman() async {
    try {
      final list = await semua();
      for (final p in list.where((x) => x.aktif)) {
        _jadwalkanTimerPengumuman(p);
      }
    } catch (_) {}
  }

  /// Mengirim notifikasi pengumuman baru:
  /// 1) Push notification (OneSignal).
  /// 2) Notifikasi in-app ke notification bell.
  static Future<void> _kirimNotifikasi({
    required int pengumumanId,
    required String judul,
    required List<UserRole> target,
  }) async {
    try {
      await OneSignalService.sendBroadcastNotification(
        title: 'Pengumuman Baru',
        body: judul,
        data: {'type': 'pengumuman', 'pengumuman_id': pengumumanId.toString()},
      );
    } catch (_) {}

    try {
      final semuaRole = target.isEmpty || target.length == roleTujuan.length;
      await db_notif.NotificationService.kirimKeBanyakRole(
        roles: semuaRole ? const [] : target,
        judul: 'Pengumuman Baru',
        pesan: judul,
        pengumumanId: pengumumanId,
      );
    } catch (_) {}
  }
}