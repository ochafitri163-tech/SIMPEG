import 'package:supabase_flutter/supabase_flutter.dart';

/// =============================================================
/// FITUR PENGUMUMAN
///
/// Pengumuman dibuat & dikelola oleh role SDM, lalu dipublikasikan
/// (kolom `aktif`) sehingga otomatis tampil pada dashboard kelima role:
/// Pegawai, Kadiv, KSPI, TPDPK, dan Direktur.
///
/// SATU SUMBER DATA: seluruh role membaca dari tabel Supabase yang sama
/// (`pengumuman`), jadi informasi pasti konsisten di semua role.
///
/// SKEMA TABEL `pengumuman` (lihat file supabase/pengumuman.sql):
///   id           bigint  PK (identity)
///   judul        text    not null
///   isi          text    not null
///   aktif        bool    not null default true   -- dipublikasikan?
///   pembuat      text                            -- nama SDM pembuat
///   pembuat_id   uuid                             -- auth user id SDM
///   created_at   timestamptz not null default now()  -- tanggal publikasi
///   updated_at   timestamptz
/// =============================================================
class Pengumuman {
  final int id;
  final String judul;
  final String isi;
  final bool aktif;
  final String pembuat;
  final String? pembuatId;
  final DateTime tanggalPublikasi;
  final DateTime? tanggalUbah;

  const Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.aktif,
    required this.pembuat,
    required this.tanggalPublikasi,
    this.pembuatId,
    this.tanggalUbah,
  });

  /// Ringkasan isi untuk ditampilkan pada card dashboard (dipangkas rapi).
  String get ringkasan {
    final bersih = isi.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (bersih.length <= 140) return bersih;
    return '${bersih.substring(0, 140).trimRight()}…';
  }

  factory Pengumuman.fromRow(Map<String, dynamic> row) {
    DateTime parseTanggal(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString())?.toUtc() ?? DateTime.now();
    }

    return Pengumuman(
      id: (row['id'] as num).toInt(),
      judul: (row['judul'] ?? '') as String,
      isi: (row['isi'] ?? '') as String,
      aktif: (row['aktif'] ?? true) as bool,
      pembuat: (row['pembuat'] ?? 'SDM') as String,
      pembuatId: row['pembuat_id'] as String?,
      tanggalPublikasi: parseTanggal(row['created_at']),
      tanggalUbah:
          row['updated_at'] != null ? parseTanggal(row['updated_at']) : null,
    );
  }
}

/// =============================================================
/// PengumumanService — seluruh akses ke tabel `pengumuman` di Supabase.
/// Semua role membaca dari method yang sama sehingga data konsisten.
/// =============================================================
class PengumumanService {
  PengumumanService._();

  static final _client = Supabase.instance.client;
  static const _table = 'pengumuman';

  /// Stream realtime seluruh pengumuman AKTIF (dipublikasikan), terbaru
  /// di atas. Dipakai oleh Card Pengumuman di dashboard agar otomatis
  /// diperbarui ketika SDM menambah / mengubah / menghapus pengumuman.
  static Stream<List<Pengumuman>> streamAktif() {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map(Pengumuman.fromRow)
            .where((p) => p.aktif)
            .toList());
  }

  /// Ambil seluruh pengumuman AKTIF sekali jalan (fallback non-realtime).
  static Future<List<Pengumuman>> aktif() async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('aktif', true)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Pengumuman.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Ambil SELURUH pengumuman (aktif & non-aktif) untuk halaman riwayat
  /// "Berita Pengumuman". Terbaru di atas.
  static Future<List<Pengumuman>> semua() async {
    final rows =
        await _client.from(_table).select().order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Pengumuman.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// SDM — buat pengumuman baru. Default langsung dipublikasikan (aktif).
  /// Melempar [ArgumentError] bila judul atau isi kosong (validasi).
  static Future<void> buat({
    required String judul,
    required String isi,
    required String pembuat,
    bool aktif = true,
  }) async {
    final j = judul.trim();
    final i = isi.trim();
    if (j.isEmpty || i.isEmpty) {
      throw ArgumentError('Judul dan isi pengumuman wajib diisi.');
    }
    final pembuatId = _client.auth.currentUser?.id;
    await _client.from(_table).insert({
      'judul': j,
      'isi': i,
      'aktif': aktif,
      'pembuat': pembuat,
      'pembuat_id': pembuatId,
    });
  }

  /// SDM — ubah judul/isi pengumuman.
  static Future<void> ubah({
    required int id,
    required String judul,
    required String isi,
  }) async {
    final j = judul.trim();
    final i = isi.trim();
    if (j.isEmpty || i.isEmpty) {
      throw ArgumentError('Judul dan isi pengumuman wajib diisi.');
    }
    await _client.from(_table).update({
      'judul': j,
      'isi': i,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// SDM — publikasikan / batalkan publikasi (aktif = true/false).
  static Future<void> setAktif({required int id, required bool aktif}) async {
    await _client.from(_table).update({
      'aktif': aktif,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// SDM — hapus pengumuman permanen.
  static Future<void> hapus({required int id}) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
