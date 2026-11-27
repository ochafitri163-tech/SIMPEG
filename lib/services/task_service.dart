import '../models/task_model.dart';
import '../models/user_role.dart';
import 'api_service.dart';

/// Service untuk mengelola Tugas (Task) Eksekutor Pengaduan
class TaskService {
  TaskService._();

  static final List<TaskModel> _localTasks = [];

  /// Mengambil daftar "Tugas Saya" (Task) untuk pegawai yang sedang login.
  static Future<List<TaskModel>> fetchTugasSaya() async {
    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.getTasks();
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => TaskModel.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _localTasks
          ..clear()
          ..addAll(list);
        return list;
      }
    }
    return _localTasks;
  }

  /// Mengambil detail 1 Task berdasarkan [taskId]
  static Future<TaskModel?> fetchTaskById(int taskId) async {
    for (final t in _localTasks) {
      if (t.id == taskId) return t;
    }
    if (await ApiService.hasAuthToken()) {
      final list = await fetchTugasSaya();
      for (final t in list) {
        if (t.id == taskId) return t;
      }
    }
    return null;
  }

  /// Memperbarui status task (Diproses / Selesai) oleh eksekutor,
  /// serta menambahkan catatan atau bukti foto/dokumen.
  static Future<void> updateTaskStatus({
    required int taskId,
    required int pengaduanId,
    required TaskStatus statusBaru,
    required AppUser user,
    String? catatan,
    List<String> buktiFoto = const [],
    List<String> buktiDokumen = const [],
  }) async {
    final proof = [...buktiFoto, ...buktiDokumen];
    if (await ApiService.hasAuthToken()) {
      final res = await ApiService.updateTaskStatus(
        id: taskId,
        status: statusBaru.label,
        notes: catatan,
        proofFiles: proof,
      );
      if (res['success'] != true) {
        throw Exception(
          res['message']?.toString() ?? 'Gagal memperbarui status tugas.',
        );
      }
    }

    final idx = _localTasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final old = _localTasks[idx];
      _localTasks[idx] = TaskModel(
        id: old.id,
        pengaduanId: old.pengaduanId,
        assignedTo: old.assignedTo,
        title: old.title,
        category: old.category,
        description: old.description,
        status: statusBaru,
        notes: catatan ?? old.notes,
        proofFiles: proof,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        nomorPengaduan: old.nomorPengaduan,
        pelaporNama: old.pelaporNama,
        pihakTerlapor: old.pihakTerlapor,
      );
    }
  }
}
