import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';

/// =============================================================
/// FITUR PENGUMUMAN (versi lengkap)
///
/// Dibuat & dikelola oleh role SDM, dipublikasikan (kolom `aktif`) lalu
/// otomatis tampil pada dashboard kelima role: Pegawai, Kadiv, KSPI,
/// TPDPK, Direktur. SATU sumber data (tabel Supabase `pengumuman`).
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

  /// Ringkasan isi untuk card dashboard (dipangkas rapi).
  String get ringkasan {
    final bersih = isi.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (bersih.length <= 140) return bersih;
    return '${bersih.substring(0, 140).trimRight()}…';
  }

  /// Cek apakah pengumuman sudah melewati batas waktu kedaluwarsa.
  bool get sudahKedaluwarsa {
    if (kedaluwarsaPada == null) return false;
    return DateTime.now().toUtc().isAfter(kedaluwarsaPada!);
  }

  /// Cek apakah pengumuman masih menunggu jam jadwal terbit.
  bool get sedangTerjadwal {
    if (!aktif || sudahKedaluwarsa) return false;
    if (terbitPada == null) return false;
    return DateTime.now().toUtc().isBefore(terbitPada!);
  }

  /// Sedang tayang: aktif, sudah melewati jadwal terbit, & belum kedaluwarsa.
  bool get sedangTayang {
    if (!aktif || sudahKedaluwarsa) return false;
    final now = DateTime.now().toUtc();
    if (terbitPada != null && now.isBefore(terbitPada!)) return false;
    return true;
  }

  bool untukRole(UserRole role) =>
      targetRoles.isEmpty || targetRoles.contains(role.name);

  factory Pengumuman.fromRow(Map<String, dynamic> row) {
    DateTime? parse(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
    return Pengumuman(
      id: (row['id'] as num).toInt(),
      judul: (row['judul'] ?? '') as String,
      isi: (row['isi'] ?? '') as String,
      aktif: (row['aktif'] ?? true) as bool,
      prioritas: (row['prioritas'] == true || row['prioritas'] == 'penting')
          ? 'penting'
          : 'umum',
      disematkan: (row['disematkan'] ?? false) as bool,
      targetRoles:
          (row['target_roles'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      pembuat: (row['pembuat'] ?? 'SDM') as String,
      pembuatId: row['pembuat_id'] as String?,
      tanggalPublikasi: parse(row['created_at']) ?? DateTime.now().toUtc(),
      terbitPada: parse(row['terbit_pada']),
      kedaluwarsaPada: parse(row['kedaluwarsa_pada']),
      lampiranUrl: row['lampiran_url'] as String?,
      lampiranNama: row['lampiran_nama'] as String?,
      tanggalUbah: parse(row['updated_at']),
    );
  }
}

/// =============================================================
/// PengumumanService — akses tunggal ke tabel `pengumuman`.
/// =============================================================
class PengumumanService {
  PengumumanService._();

  static final _client = Supabase.instance.client;
  static const _table = 'pengumuman';
  static const _tableDibaca = 'pengumuman_dibaca';
  static const _bucket = 'pengumuman';

  static final Map<int, Timer> _activeTimers = {};
  static final Map<int, Timer> _activeExpiryTimers = {};

  static const List<UserRole> roleTujuan = [
    UserRole.pegawai,
    UserRole.kadivKategori,
    UserRole.kspi,
    UserRole.tpdpk,
    UserRole.direktur,
    UserRole.sdm,
    UserRole.keuangan,
  ];

  static Future<void> autoNonaktifkanExpired() async {
    try {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      await _client
          .from(_table)
          .update({'aktif': false, 'updated_at': nowStr})
          .eq('aktif', true)
          .not('kedaluwarsa_pada', 'is', null)
          .lte('kedaluwarsa_pada', nowStr);
    } catch (_) {}
  }

  static Stream<List<Pengumuman>> streamTayang(UserRole role) {
    autoNonaktifkanExpired();
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
          final list = rows
              .map(Pengumuman.fromRow)
              .where((p) => p.sedangTayang && p.untukRole(role))
              .toList();
          list.sort((a, b) {
            if (a.disematkan != b.disematkan) return a.disematkan ? -1 : 1;
            return b.tanggalPublikasi.compareTo(a.tanggalPublikasi);
          });
          return list;
        });
  }

  static Future<List<Pengumuman>> semua() async {
    await autoNonaktifkanExpired();
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Pengumuman.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Pengumuman>> tayangSekali(UserRole role) async {
    await autoNonaktifkanExpired();
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    final list = (rows as List)
        .map((r) => Pengumuman.fromRow(r as Map<String, dynamic>))
        .where((p) => p.sedangTayang && p.untukRole(role))
        .toList();
    list.sort((a, b) {
      if (a.disematkan != b.disematkan) return a.disematkan ? -1 : 1;
      return b.tanggalPublikasi.compareTo(a.tanggalPublikasi);
    });
    return list;
  }

  static Future<Set<int>> idSudahDibaca() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _client
        .from(_tableDibaca)
        .select('pengumuman_id')
        .eq('user_id', uid);
    return (rows as List)
        .map((r) => (r['pengumuman_id'] as num).toInt())
        .toSet();
  }

  static Future<void> tandaiDibaca(int pengumumanId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from(_tableDibaca).upsert(
      {
        'pengumuman_id': pengumumanId,
        'user_id': uid,
        'dibaca_pada': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'pengumuman_id,user_id',
    );
  }

  static Future<String> uploadLampiran({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    final uniqueName =
        '${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}.$ext';
    final path = 'lampiran/$uniqueName';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
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
        pembuat is AppUser ? pembuat.id : _client.auth.currentUser?.id;

    final res = await _client
        .from(_table)
        .insert({
          'judul': j,
          'isi': i,
          'aktif': aktif,
          'prioritas': prioritas == 'penting',
          'disematkan': disematkan,
          'target_roles': targetNames,
          'pembuat': pembuatName,
          'pembuat_id': pembuatId,
          'terbit_pada': terbitPada?.toUtc().toIso8601String(),
          'kedaluwarsa_pada': kedaluwarsaPada?.toUtc().toIso8601String(),
          'lampiran_url': lampiranUrl,
          'lampiran_nama': lampiranNama,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    final p = Pengumuman.fromRow(res);
    _jadwalkanTimerPengumuman(p);

    if (p.sedangTayang) {
      await _kirimNotifikasi(
          judul: j, target: target.isEmpty ? roleTujuan : target);
    }

    return p;
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

    await _client.from(_table).update({
      'judul': j,
      'isi': i,
      'prioritas': prioritas == 'penting',
      'disematkan': disematkan,
      'target_roles': targetNames,
      'terbit_pada': terbitPada?.toUtc().toIso8601String(),
      'kedaluwarsa_pada': kedaluwarsaPada?.toUtc().toIso8601String(),
      'lampiran_url': lampiranUrl,
      'lampiran_nama': lampiranNama,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);

    try {
      final res = await _client.from(_table).select().eq('id', id).single();
      final p = Pengumuman.fromRow(res);
      _jadwalkanTimerPengumuman(p);
    } catch (_) {}
  }

  static Future<void> setAktif({required int id, required bool aktif}) async {
    await _client.from(_table).update({
      'aktif': aktif,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);

    if (aktif) {
      try {
        final res = await _client
            .from(_table)
            .select()
            .eq('id', id)
            .single();
        final p = Pengumuman.fromRow(res);
        _jadwalkanTimerPengumuman(p);

        if (p.sedangTayang) {
          await _kirimNotifikasi(judul: p.judul, target: roleTujuan);
        }
      } catch (_) {}
    } else {
      _batalkanTimerPengumuman(id);
      await NotificationService.instance.cancelPengumuman(id);
    }
  }

  static Future<void> hapus({required int id}) async {
    _batalkanTimerPengumuman(id);
    await NotificationService.instance.cancelPengumuman(id);
    await _client.from(_table).delete().eq('id', id);
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
        title: '📢 Pengumuman Baru',
        body: p.judul,
        scheduledDate: p.terbitPada!.toLocal(),
      );

      final delay = p.terbitPada!.difference(nowUtc);
      if (delay > Duration.zero) {
        _activeTimers[p.id] = Timer(delay, () async {
          _activeTimers.remove(p.id);
          NotificationService.instance.showPengumuman(
            title: '📢 Pengumuman Baru',
            body: p.judul,
          );
          await _kirimNotifikasi(judul: p.judul, target: roleTujuan);
        });
      }
    }

    if (p.kedaluwarsaPada != null && p.kedaluwarsaPada!.isAfter(nowUtc)) {
      final expiryDelay = p.kedaluwarsaPada!.difference(nowUtc);
      if (expiryDelay > Duration.zero) {
        _activeExpiryTimers[p.id] = Timer(expiryDelay, () async {
          _activeExpiryTimers.remove(p.id);
          NotificationService.instance.cancelPengumuman(p.id);
          try {
            await _client
                .from(_table)
                .update({
                  'aktif': false,
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('id', p.id);
          } catch (_) {}
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
      await autoNonaktifkanExpired();
      final rows = await _client
          .from(_table)
          .select()
          .eq('aktif', true);
      for (final r in (rows as List)) {
        final p = Pengumuman.fromRow(r as Map<String, dynamic>);
        _jadwalkanTimerPengumuman(p);
      }
    } catch (_) {}
  }

  static Future<void> _kirimNotifikasi({
    required String judul,
    required List<UserRole> target,
  }) async {
    try {
      await FcmService.sendBroadcastNotification(
        title: '📢 Pengumuman Baru',
        body: judul,
      );
    } catch (_) {}
  }
}
