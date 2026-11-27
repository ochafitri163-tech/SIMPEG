import 'user_role.dart';
import '../services/api_service.dart';
import '../services/audit_log_service.dart';

/// =============================================================
/// B11 — KALENDER AGENDA / KEGIATAN
///
/// Agenda kantor (rapat, kegiatan, hari penting) yang dibuat oleh SDM /
/// role pengelola dan dapat dilihat seluruh role.
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

  static final List<Agenda> _localAgendas = [
    Agenda(
      id: 1,
      judul: 'Rapat Evaluasi Triwulan & Kinerja Pegawai',
      tanggal: DateTime.now().add(const Duration(days: 3)),
      waktu: '09:00 WIB',
      lokasi: 'Ruang Rapat Utama',
      dibuatOleh: 'SDM',
      dibuatPada: DateTime.now(),
    ),
    Agenda(
      id: 2,
      judul: 'Sosialisasi Program Kerja SIMPEG Baru',
      tanggal: DateTime.now().add(const Duration(days: 7)),
      waktu: '10:00 WIB',
      lokasi: 'Aula Serbaguna & Zoom',
      dibuatOleh: 'SDM',
      dibuatPada: DateTime.now(),
    ),
  ];

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
    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.getAgenda(tahun: tahun, bulan: bulan);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((r) => Agenda.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList()
          ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
        return list;
      }
    }
    final list = _localAgendas
        .where((a) => a.tanggal.year == tahun && a.tanggal.month == bulan)
        .toList();
    list.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return list;
  }

  /// Agenda mendatang (>= hari ini) untuk ringkasan.
  static Future<List<Agenda>> mendatang({int limit = 20}) async {
    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.getAgenda(upcoming: true, limit: limit);
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((r) => Agenda.fromRow(Map<String, dynamic>.from(r as Map)))
            .toList()
          ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
        return list.take(limit).toList();
      }
    }
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final list = _localAgendas
        .where((a) => !a.tanggal.isBefore(todayStart))
        .toList();
    list.sort((a, b) => a.tanggal.compareTo(b.tanggal));
    return list.take(limit).toList();
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
    Agenda newAgenda = Agenda(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      judul: judul.trim(),
      deskripsi: deskripsi,
      tanggal: tanggal,
      waktu: waktu,
      lokasi: lokasi,
      dibuatOleh: dibuatOleh,
      dibuatPada: DateTime.now(),
    );

    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.storeAgenda(
        judul: judul.trim(),
        tanggal: tanggal,
        deskripsi: deskripsi,
        waktu: waktu,
        lokasi: lokasi,
        dibuatOleh: dibuatOleh,
      );
      if (res['success'] != true) {
        throw Exception(
          res['message']?.toString() ?? 'Gagal menyimpan agenda ke server.',
        );
      }
      if (res['data'] is Map) {
        newAgenda = Agenda.fromRow(
          Map<String, dynamic>.from(res['data'] as Map),
        );
      }
    }

    _localAgendas.removeWhere((a) => a.id == newAgenda.id);
    _localAgendas.add(newAgenda);

    AuditLogService.logAction(
      userNik: dibuatOleh,
      userName: dibuatOleh,
      role: 'SDM',
      action: 'CREATE',
      module: 'Agenda',
      description: 'Menambah agenda "${judul.trim()}" pada ${_tgl(tanggal)}',
    );
  }

  static Future<void> hapus({required int id}) async {
    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.deleteAgenda(id);
      if (res['success'] != true) {
        throw Exception(
          res['message']?.toString() ?? 'Gagal menghapus agenda di server.',
        );
      }
    }
    _localAgendas.removeWhere((a) => a.id == id);
    AuditLogService.logAction(
      userNik: 'SDM',
      userName: 'Pengelola',
      role: 'SDM',
      action: 'DELETE',
      module: 'Agenda',
      description: 'Menghapus agenda ID #$id',
    );
  }
}
