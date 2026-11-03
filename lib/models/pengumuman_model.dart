import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';
import '../services/notification_service.dart';
import '../services/onesignal_service.dart';
import '../services/audit_log_service.dart';
import '../services/api_service.dart';
// Diberi prefix karena file ini juga mengimpor `services/notification_service.dart`
// yang KEBETULAN punya nama kelas sama (NotificationService) tapi untuk hal
// berbeda (local push notification, dipakai sbg `NotificationService.instance`).
// NotificationService di pengaduan_service.dart adalah yang menyimpan
// notifikasi in-app ke tabel Supabase `notifikasi` -- inilah yang dibaca oleh
// tombol lonceng (NotificationBell) di semua dashboard.
import 'pengaduan_service.dart' as db_notif;

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
/// PengumumanService — akses data pengumuman (Supabase & Web API).
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

  static Stream<List<Pengumuman>> streamTayang(UserRole role) async* {
    autoNonaktifkanExpired();
    // 1. Langsung yield data dari REST API agar UI instan dan tidak blank
    try {
      final initial = await tayangSekali(role);
      yield initial;
    } catch (_) {}

    // 2. Hybrid Stream: Supabase Realtime + Polling Berkala
    // Menjamin pengumuman yang baru diinput dari web langsung muncul di HP
    final controller = StreamController<List<Pengumuman>>();
    Timer? pollingTimer;
    RealtimeChannel? realtimeChannel;

    void updateData() async {
      try {
        final list = await tayangSekali(role);
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (_) {}
    }

    // Polling setiap 4 detik untuk update langsung data dari web
    pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => updateData());

    // Listener Realtime Supabase
    try {
      realtimeChannel = _client.channel('public:pengumuman_channel_${role.name}');
      realtimeChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: _table,
        callback: (_) => updateData(),
      ).subscribe();
    } catch (_) {}

    controller.onCancel = () {
      pollingTimer?.cancel();
      if (realtimeChannel != null) {
        _client.removeChannel(realtimeChannel);
      }
      controller.close();
    };

    yield* controller.stream;
  }

  static Future<List<Pengumuman>> semua() async {
    await autoNonaktifkanExpired();
    final List<Pengumuman> list = [];
    final Set<int> seenIds = {};

    // 1. Ambil dari database Supabase (sumber utama)
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false);
      for (final r in (rows as List)) {
        final p = Pengumuman.fromRow(r as Map<String, dynamic>);
        if (p.id != 0 && !seenIds.contains(p.id)) {
          seenIds.add(p.id);
          list.add(p);
        }
      }
    } catch (e) {
      debugPrint('Error mengambil pengumuman dari Supabase: $e');
    }

    // 2. Ambil dari REST API Laravel (jika backend web aktif)
    try {
      final res = await ApiService.getPengumuman();
      if (res['success'] == true && res['data'] is List) {
        for (final r in (res['data'] as List)) {
          final p = Pengumuman.fromRow(r as Map<String, dynamic>);
          if (p.id != 0 && !seenIds.contains(p.id)) {
            seenIds.add(p.id);
            list.add(p);
          }
        }
      }
    } catch (_) {}

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
    try {
      final row = await _client.from(_table).select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Pengumuman.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  static Future<Set<int>> idSudahDibaca() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _client
        .from(_tableDibaca)
        .select('pengumuman_id')
        .eq('pegawai_id', uid);
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
        'pegawai_id': uid,
        'dibaca_pada': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'pengumuman_id,pegawai_id',
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
        pembuat is AppUser ? pembuat.nik : _client.auth.currentUser?.id;

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
          pengumumanId: p.id,
          judul: j,
          target: target.isEmpty ? roleTujuan : target);
    }

    AuditLogService.logAction(
      userNik: pembuatId?.toString() ?? 'SDM',
      userName: pembuatName,
      role: 'SDM',
      action: 'CREATE',
      module: 'Pengumuman',
      description: 'Membuat pengumuman baru ID #${p.id}: "$j"',
    );

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

    AuditLogService.logAction(
      userNik: _client.auth.currentUser?.id ?? 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'UPDATE',
      module: 'Pengumuman',
      description: 'Mengubah pengumuman ID #$id: "$j"',
    );

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

    AuditLogService.logAction(
      userNik: _client.auth.currentUser?.id ?? 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'UPDATE',
      module: 'Pengumuman',
      description: '${aktif ? 'Mengaktifkan' : 'Menonaktifkan'} pengumuman ID #$id',
    );

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
          await _kirimNotifikasi(
              pengumumanId: p.id, judul: p.judul, target: roleTujuan);
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

    // Ambil info judul sebelum dihapus untuk detail log
    String detailJudul = '';
    try {
      final res = await _client.from(_table).select('judul').eq('id', id).maybeSingle();
      if (res != null) detailJudul = ' ("${res['judul']}")';
    } catch (_) {}

    await _client.from(_table).delete().eq('id', id);

    AuditLogService.logAction(
      userNik: _client.auth.currentUser?.id ?? 'SDM',
      userName: 'Pengelola SDM',
      role: 'SDM',
      action: 'DELETE',
      module: 'Pengumuman',
      description: 'Menghapus pengumuman ID #$id$detailJudul',
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

  /// Mengirim notifikasi pengumuman baru ke SEMUA channel:
  /// 1) Push notification (FCM) -- notifikasi sistem/OS saat app di-background.
  /// 2) Notifikasi in-app ke tabel Supabase `notifikasi` -- INI yang tampil
  ///    di tombol lonceng (NotificationBell) pada semua dashboard. Sebelumnya
  ///    langkah ini TIDAK ADA, sehingga pengumuman yang dibuat/dipublikasikan
  ///    SDM tidak pernah muncul di daftar notifikasi walau push FCM terkirim.
  static Future<void> _kirimNotifikasi({
    required int pengumumanId,
    required String judul,
    required List<UserRole> target,
  }) async {
    // 1) Push notification via OneSignal (best-effort, tidak boleh menggagalkan alur utama).
    try {
      await OneSignalService.sendBroadcastNotification(
        title: 'Pengumuman Baru',
        body: judul,
        data: {'type': 'pengumuman', 'pengumuman_id': pengumumanId.toString()},
      );
    } catch (_) {}

    // 2) Simpan ke tabel `notifikasi` supaya masuk ke NotificationBell
    //    (in-app notification center) setiap pegawai pada role target.
    //    target kosong / == roleTujuan berarti "semua role". pengumumanId
    //    disertakan supaya notifikasi bisa DIPENCET dan langsung membuka
    //    pengumuman terkait (lihat NotificationBell & NotificationNavHelper).
    try {
      final semuaRole = target.isEmpty || target.length == roleTujuan.length;
      await db_notif.NotificationService.kirimKeBanyakRole(
        roles: semuaRole ? const [] : target,
        judul: 'Pengumuman Baru',
        pesan: judul,
        pengumumanId: pengumumanId,
      );
    } catch (_) {
      // Diamkan -- kegagalan simpan notifikasi in-app tidak boleh
      // menggagalkan proses publikasi pengumuman itu sendiri.
    }
  }
}