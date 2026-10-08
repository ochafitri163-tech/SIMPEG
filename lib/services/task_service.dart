import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../models/user_role.dart';
import '../models/pengaduan_model.dart';
import '../models/pengaduan_service.dart';

/// Service untuk mengelola Tugas (Task) Eksekutor Pengaduan
class TaskService {
  TaskService._();

  static final _client = Supabase.instance.client;

  /// Mengambil daftar "Tugas Saya" (Task) untuk pegawai yang sedang login.
  static Future<List<TaskModel>> fetchTugasSaya() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // 1. Coba ambil dari tabel `tasks` jika tabel sudah ada di Supabase
    try {
      final rows = await _client
          .from('tasks')
          .select('*, pengaduan_pegawai(nomor_pengaduan, nama_pegawai, pihak_terlapor)')
          .eq('assigned_to', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (rows as List)
          .map((r) => TaskModel.fromMap(r as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) return list;
    } catch (_) {
      // Jika tabel `tasks` belum dimigrasikan/tersedia di Supabase, gunakan fallback
    }

    // 2. Fallback: Ambil data penugasan dari tabel `pengaduan_pegawai` langsung
    return await _fetchTugasSayaFallback(userId);
  }

  static Future<List<TaskModel>> _fetchTugasSayaFallback(String userId) async {
    try {
      // Ambil info pegawai logged-in (nama & NIK)
      final pegawaiData = await _client
          .from('pegawai')
          .select('name, nik')
          .eq('id', userId)
          .maybeSingle();

      final userName = pegawaiData?['name']?.toString();
      final userNik = pegawaiData?['nik']?.toString();

      final rows = await _client
          .from('pengaduan_pegawai')
          .select()
          .order('tanggal_pengaduan', ascending: false);

      final result = <TaskModel>[];
      for (final r in (rows as List)) {
        final executorId = r['executor_id']?.toString();
        final petugas = r['petugas_investigasi']?.toString() ?? '';
        final statusStr = r['status']?.toString() ?? '';

        bool isAssigned = (executorId == userId);
        if (!isAssigned && userName != null && userName.trim().isNotEmpty) {
          if (petugas.toLowerCase().contains(userName.toLowerCase())) {
            isAssigned = true;
          }
        }
        if (!isAssigned && userNik != null && userNik.trim().isNotEmpty) {
          if (petugas.toLowerCase().contains(userNik.toLowerCase())) {
            isAssigned = true;
          }
        }

        if (isAssigned) {
          TaskStatus taskStatus = TaskStatus.menunggu;
          if (statusStr == PengaduanStatus.investigasiBerjalan.name ||
              statusStr == PengaduanStatus.revisiInvestigasi.name) {
            taskStatus = TaskStatus.diproses;
          } else if (statusStr == PengaduanStatus.menungguReviewKspi.name ||
              statusStr == PengaduanStatus.menungguDirutTahap2.name ||
              statusStr == PengaduanStatus.selesai.name) {
            taskStatus = TaskStatus.selesai;
          }

          result.add(TaskModel(
            id: (r['id'] as num).toInt(),
            pengaduanId: (r['id'] as num).toInt(),
            assignedTo: userId,
            title: 'Investigasi: ${r['judul']} (${r['nomor_pengaduan']})',
            category: r['kategori']?.toString(),
            description: r['deskripsi']?.toString(),
            status: taskStatus,
            notes: r['catatan_kadiv']?.toString() ?? r['hasil_investigasi']?.toString(),
            proofFiles: List<String>.from(r['investigasi_foto'] ?? const []),
            createdAt: DateTime.tryParse(r['tanggal_pengaduan']?.toString() ?? '') ?? DateTime.now(),
            updatedAt: DateTime.now(),
            nomorPengaduan: r['nomor_pengaduan']?.toString(),
            pelaporNama: r['nama_pegawai']?.toString(),
            pihakTerlapor: r['pihak_terlapor']?.toString(),
          ));
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  /// Mengambil detail 1 Task berdasarkan [taskId]
  static Future<TaskModel?> fetchTaskById(int taskId) async {
    try {
      final row = await _client
          .from('tasks')
          .select('*, pengaduan_pegawai(nomor_pengaduan, nama_pegawai, pihak_terlapor)')
          .eq('id', taskId)
          .maybeSingle();

      if (row != null) return TaskModel.fromMap(row);
    } catch (_) {}
    return null;
  }

  /// Memperbarui status task (Diproses / Selesai) oleh eksekutor,
  /// serta menambahkan catatan atau bukti foto/dokumen.
  ///
  /// Perubahan status ini ikut memperbarui timeline status pengaduan di
  /// tabel `pengaduan_pegawai` & `riwayat_status_pengaduan`.
  static Future<void> updateTaskStatus({
    required int taskId,
    required int pengaduanId,
    required TaskStatus statusBaru,
    required AppUser user,
    String? catatan,
    List<String> buktiFoto = const [],
    List<String> buktiDokumen = const [],
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    // 1. Update baris di tabel `tasks` (jika tabel tasks ada)
    final updateData = <String, dynamic>{
      'status': statusBaru.label,
      'updated_at': nowIso,
    };

    if (catatan != null && catatan.trim().isNotEmpty) {
      updateData['notes'] = catatan.trim();
    }

    final allProofs = [...buktiFoto, ...buktiDokumen];
    if (allProofs.isNotEmpty) {
      updateData['proof_files'] = allProofs;
    }

    try {
      await _client.from('tasks').update(updateData).eq('id', taskId);
    } catch (_) {}

    // 2. Sinkronkan dengan timeline & status `pengaduan_pegawai`
    if (statusBaru == TaskStatus.diproses) {
      // Ubah status pengaduan / tambah riwayat "Investigasi diproses"
      await _client.from('riwayat_status_pengaduan').insert({
        'pengaduan_id': pengaduanId,
        'status': PengaduanStatus.investigasiBerjalan.name,
        'status_lama': PengaduanStatus.investigasiBerjalan.name,
        'tanggal': nowIso,
        'keterangan': catatan,
        'oleh': user.name,
        'role': user.role.name,
        'aksi': 'Investigasi mulai diproses oleh eksekutor ${user.name}',
      });

      await _client.from('pengaduan_pegawai').update({
        'status': PengaduanStatus.investigasiBerjalan.name,
      }).eq('id', pengaduanId);
    } else if (statusBaru == TaskStatus.selesai) {
      // Update pengaduan dengan hasil investigasi & teruskan ke KSPI
      final kolomPengaduan = <String, dynamic>{
        'hasil_investigasi': catatan ?? 'Investigasi selesai dilaksanakan.',
        'surat_rekomendasi': catatan ?? 'Rekomendasi tindak lanjut tersedia.',
        'tanggal_hasil_investigasi': nowIso,
        'status': PengaduanStatus.menungguReviewKspi.name,
      };

      if (buktiFoto.isNotEmpty) {
        kolomPengaduan['investigasi_foto'] = buktiFoto;
      }
      if (buktiDokumen.isNotEmpty) {
        kolomPengaduan['investigasi_dokumen'] = buktiDokumen;
      }

      await _client
          .from('pengaduan_pegawai')
          .update(kolomPengaduan)
          .eq('id', pengaduanId);

      // Tambah riwayat status
      await _client.from('riwayat_status_pengaduan').insert({
        'pengaduan_id': pengaduanId,
        'status': PengaduanStatus.menungguReviewKspi.name,
        'status_lama': PengaduanStatus.investigasiBerjalan.name,
        'tanggal': nowIso,
        'keterangan': catatan,
        'oleh': user.name,
        'role': user.role.name,
        'aksi': 'Eksekutor (${user.name}) menyelesaikan tugas investigasi',
      });

      // Kirim notifikasi ke KSPI bahwa hasil investigasi sudah dikirim
      await NotificationService.kirimKeRole(
        role: UserRole.kspi,
        judul: 'Hasil Investigasi Selesai 🚀',
        pesan: 'Tugas investigasi telah diselesaikan oleh ${user.name}. Silakan review hasilnya.',
        pengaduanId: pengaduanId,
      );
    }
  }
}
