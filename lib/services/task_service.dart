import '../models/task_model.dart';
import '../models/user_role.dart';
import '../models/pengaduan_model.dart';
import '../models/pengaduan_service.dart';

/// Service untuk mengelola Tugas (Task) Eksekutor Pengaduan
class TaskService {
  TaskService._();

  static final List<TaskModel> _localTasks = [];

  /// Mengambil daftar "Tugas Saya" (Task) untuk pegawai yang sedang login.
  static Future<List<TaskModel>> fetchTugasSaya() async {
    return _localTasks;
  }

  /// Mengambil detail 1 Task berdasarkan [taskId]
  static Future<TaskModel?> fetchTaskById(int taskId) async {
    for (final t in _localTasks) {
      if (t.id == taskId) return t;
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
        proofFiles: [...buktiFoto, ...buktiDokumen],
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        nomorPengaduan: old.nomorPengaduan,
        pelaporNama: old.pelaporNama,
        pihakTerlapor: old.pihakTerlapor,
      );
    }
  }
}
