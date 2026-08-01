import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_role.dart';

/// =============================================================
/// B11 — KALENDER AGENDA / KEGIATAN
///
/// Agenda kantor (rapat, kegiatan, hari penting) yang dibuat oleh SDM /
/// role pengelola dan dapat dilihat seluruh role. Sumber data tunggal:
/// tabel `agenda` di Supabase.
///
/// Skema lihat: supabase/fitur_tambahan.sql
/// =============================================================
class Agenda {
  final int id;
  final String judul;
  final String? deskripsi;
  final DateTime tanggal; // tanggal kegiatan (lokal)
  final String? waktu; // mis. "09:00 WIB"
  final String? lokasi;
  final String? dibuatOleh;
  final DateTime dibuatPada;

  const Agenda({
    required this.id,
    required this.judul,
    required this.tanggal,
    required this.dibuatPada,
    this.deskripsi,
    this.waktu,
    this.lokasi,
    this.dibuatOleh,
  });

  factory Agenda.fromRow(Map<String, dynamic> row) {
    return Agenda(
      id: (row['id'] as num).toInt(),
      judul: (row['judul'] ?? '') as String,
      deskripsi: row['deskripsi'] as String?,
      tanggal:
          DateTime.tryParse(row['tanggal'].toString()) ?? DateTime.now(),
      waktu: row['waktu'] as String?,
      lokasi: row['lokasi'] as String?,
      dibuatOleh: row['dibuat_oleh'] as String?,
      dibuatPada:
          DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
    );
  }
}

class AgendaService {
  AgendaService._();

  static final _client = Supabase.instance.client;
  static const _table = 'agenda';

  /// Role yang boleh menambah/menghapus agenda.
  static const List<UserRole> rolePengelola = [
    UserRole.sdm,
    UserRole.direktur,
    UserRole.kadivKategori,
    UserRole.kspi,
    UserRole.tpdpk,
  ];

  static bool bolehKelola(UserRole role) => rolePengelola.contains(role);

  static String _tgl(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Semua agenda pada bulan tertentu, diurut tanggal menaik.
  static Future<List<Agenda>> bulan({
    required int tahun,
    required int bulan,
  }) async {
    final awal = '${tahun.toString().padLeft(4, '0')}-'
        '${bulan.toString().padLeft(2, '0')}-01';
    final akhirBulan =
        (bulan == 12) ? DateTime(tahun + 1, 1, 1) : DateTime(tahun, bulan + 1, 1);
    final rows = await _client
        .from(_table)
        .select()
        .gte('tanggal', awal)
        .lt('tanggal', _tgl(akhirBulan))
        .order('tanggal', ascending: true);
    return (rows as List)
        .map((r) => Agenda.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Agenda mendatang (>= hari ini) untuk ringkasan.
  static Future<List<Agenda>> mendatang({int limit = 20}) async {
    final rows = await _client
        .from(_table)
        .select()
        .gte('tanggal', _tgl(DateTime.now()))
        .order('tanggal', ascending: true)
        .limit(limit);
    return (rows as List)
        .map((r) => Agenda.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  static Future<void> tambah({
    required String judul,
    required DateTime tanggal,
    String? deskripsi,
    String? waktu,
    String? lokasi,
    required String dibuatOleh,
  }) async {
    if (judul.trim().isEmpty) {
      throw ArgumentError('Judul agenda wajib diisi.');
    }
    await _client.from(_table).insert({
      'judul': judul.trim(),
      'deskripsi': deskripsi,
      'tanggal': _tgl(tanggal),
      'waktu': waktu,
      'lokasi': lokasi,
      'dibuat_oleh': dibuatOleh,
    });
  }

  static Future<void> hapus({required int id}) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
