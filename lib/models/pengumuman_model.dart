import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';
import 'pengaduan_service.dart' as pengaduan_notif;
import '../services/notification_service.dart';

/// =============================================================
/// FITUR PENGUMUMAN (versi lengkap)
///
/// Dibuat & dikelola oleh role SDM, dipublikasikan (kolom `aktif`) lalu
/// otomatis tampil pada dashboard kelima role: Pegawai, Kadiv, KSPI,
/// TPDPK, Direktur. SATU sumber data (tabel Supabase `pengumuman`).
///
/// Fitur tambahan:
/// - prioritas (penting/umum) + sematkan (pin)
/// - target role tertentu (default semua 5 role)
/// - jadwal terbit & tanggal kedaluwarsa (auto nonaktif)
/// - lampiran (gambar/PDF) via Supabase Storage
/// - penanda sudah dibaca (tabel `pengumuman_dibaca`) + badge "Baru"
/// - notifikasi otomatis ke role tujuan saat dipublikaslikan
///
/// Skema lihat: supabase/pengumuman.sql
/// =============================================================
class Pengumuman {
  final int id;
  final String judul;
  final String isi;
  final bool aktif;
  final String prioritas; // 'penting' | 'umum'
  final bool disematkan;
  final List<String> targetRoles; // kosong = semua 5 role (pakai UserRole.name)
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

  /// Sedang tayang: aktif, sudah melewati jadwal terbit, & belum kedaluwarsa.
  bool get sedangTayang {
    if (!aktif) return false;
    final now = DateTime.now().toUtc();
    if (terbitPada != null && now.isBefore(terbitPada!)) return false;
    if (kedaluwarsaPada != null && now.isAfter(kedaluwarsaPada!)) return false;
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
      // Kolom DB `prioritas` bertipe boolean (true = penting). Tetap
      // dipetakan ke String internal 'penting'/'umum'. Toleran juga bila
      // suatu saat kolom berisi teks.
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

  /// 5 role tujuan default (tanpa SDM, karena SDM adalah pengelola).
  /// 7 role tujuan pengumuman. SDM ikut dimasukkan supaya pengumuman
  /// juga tampil di dashboard SDM (bukan hanya sebagai pengelola).
  static const List<UserRole> roleTujuan = [
    UserRole.pegawai,
    UserRole.kadivKategori,
    UserRole.kspi,
    UserRole.tpdpk,
    UserRole.direktur,
    UserRole.sdm,
    UserRole.keuangan,
  ];

  /// Stream realtime pengumuman yang SEDANG TAYANG untuk [role] tertentu.
  /// Otomatis ter-update saat SDM menambah / mengubah / menghapus.
  /// Diurutkan: yang disematkan dulu, lalu terbaru.
  static Stream<List<Pengumuman>> streamTayang(UserRole role) {
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

  /// Seluruh pengumuman (untuk halaman riwayat / kelola). Terbaru di atas.
  static Future<List<Pengumuman>> semua() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Pengumuman.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Ambil (sekali/one-shot) daftar pengumuman yang SEDANG TAYANG untuk
  /// [role]. Dipakai untuk pop-up otomatis saat aplikasi dibuka. Urutan
  /// sama seperti [streamTayang]: yang disematkan dulu, lalu terbaru.
  static Future<List<Pengumuman>> tayangSekali(UserRole role) async {
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

  /// Set id pengumuman yang sudah dibaca oleh user yang sedang login.
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

  /// Tandai satu pengumuman sebagai sudah dibaca (idempoten via upsert).
  static Future<void> tandaiDibaca(int pengumumanId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from(_tableDibaca).upsert({
      'pengumuman_id': pengumumanId,
      'pegawai_id': uid,
    }, onConflict: 'pengumuman_id,pegawai_id');
  }

  /// Jumlah pengumuman tayang yang BELUM dibaca oleh [role] user login.
  static Future<int> jumlahBelumDibaca(UserRole role) async {
    final rows = await _client.from(_table).select().eq('aktif', true);
    final tayang = (rows as List)
        .map((r) => Pengumuman.fromRow(r as Map<String, dynamic>))
        .where((p) => p.sedangTayang && p.untukRole(role))
        .toList();
    if (tayang.isEmpty) return 0;
    final dibaca = await idSudahDibaca();
    return tayang.where((p) => !dibaca.contains(p.id)).length;
  }

  /// SDM — buat pengumuman. Melempar [ArgumentError] jika judul/isi kosong.
  /// Bila langsung tayang, kirim notifikasi otomatis ke role tujuan.
  static Future<void> buat({
    required String judul,
    required String isi,
    required String pembuat,
    bool aktif = true,
    String prioritas = 'umum',
    bool disematkan = false,
    List<UserRole>? target,
    DateTime? terbitPada,
    DateTime? kedaluwarsaPada,
    String? lampiranUrl,
    String? lampiranNama,
  }) async {
    final j = judul.trim();
    final i = isi.trim();
    if (j.isEmpty || i.isEmpty) {
      throw ArgumentError('Judul dan isi pengumuman wajib diisi.');
    }
    final targetNames = (target == null || target.isEmpty)
        ? roleTujuan.map((e) => e.name).toList()
        : target.map((e) => e.name).toList();

    await _client.from(_table).insert({
      'judul': j,
      'isi': i,
      'aktif': aktif,
      // Kolom DB boolean -> kirim true/false, bukan string.
      'prioritas': prioritas == 'penting',
      'disematkan': disematkan,
      'target_roles': targetNames,
      'pembuat': pembuat,
      'pembuat_id': _client.auth.currentUser?.id,
      if (terbitPada != null)
        'terbit_pada': terbitPada.toUtc().toIso8601String(),
      if (kedaluwarsaPada != null)
        'kedaluwarsa_pada': kedaluwarsaPada.toUtc().toIso8601String(),
      if (lampiranUrl != null) 'lampiran_url': lampiranUrl,
      if (lampiranNama != null) 'lampiran_nama': lampiranNama,
    });

    final langsungTayang = aktif &&
        (terbitPada == null ||
            !DateTime.now().toUtc().isBefore(terbitPada.toUtc()));
    if (langsungTayang) {
      await _kirimNotifikasi(judul: j, target: target ?? roleTujuan);
    }
  }

  /// SDM — ubah pengumuman.
  static Future<void> ubah({
    required int id,
    required String judul,
    required String isi,
    required String prioritas,
    required bool disematkan,
    List<UserRole>? target,
    DateTime? terbitPada,
    DateTime? kedaluwarsaPada,
    String? lampiranUrl,
    String? lampiranNama,
  }) async {
    final j = judul.trim();
    final i = isi.trim();
    if (j.isEmpty || i.isEmpty) {
      throw ArgumentError('Judul dan isi pengumuman wajib diisi.');
    }
    final targetNames = (target == null || target.isEmpty)
        ? roleTujuan.map((e) => e.name).toList()
        : target.map((e) => e.name).toList();
    await _client.from(_table).update({
      'judul': j,
      'isi': i,
      // Kolom DB boolean -> kirim true/false, bukan string.
      'prioritas': prioritas == 'penting',
      'disematkan': disematkan,
      'target_roles': targetNames,
      'terbit_pada': terbitPada?.toUtc().toIso8601String(),
      'kedaluwarsa_pada': kedaluwarsaPada?.toUtc().toIso8601String(),
      'lampiran_url': lampiranUrl,
      'lampiran_nama': lampiranNama,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// SDM — publikasikan / batalkan publikasi.
  static Future<void> setAktif({required int id, required bool aktif}) async {
    await _client.from(_table).update({
      'aktif': aktif,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// SDM — hapus permanen.
  static Future<void> hapus({required int id}) async {
    await _client.from(_table).delete().eq('id', id);
  }

  static Future<void> _kirimNotifikasi({
    required String judul,
    required List<UserRole> target,
  }) async {
    try {
      // Tampilkan notifikasi lokal untuk pembuat/pengirim pengumuman
      await NotificationService.instance.showPengumuman(
        title: '📢 Pengumuman Baru Terpublikasi',
        body: judul,
      );
    } catch (_) {}

    for (final r in target) {
      try {
        await pengaduan_notif.NotificationService.kirimKeRole(
          role: r,
          judul: '📢 Pengumuman Baru',
          pesan: judul,
        );
      } catch (_) {
        // Abaikan kegagalan notifikasi agar tidak membatalkan publikasi.
      }
    }
  }
}
