/// Model data untuk pegawai (pilihan eksekutor) & tugas (task) eksekutor.
library;

class PegawaiOption {
  final String id; // UUID Supabase
  final String nik;
  final String name;
  final String jabatan;
  final String unitKerja;
  final String? role;
  final String? divisiKadiv;
  final String? fotoUrl;

  const PegawaiOption({
    required this.id,
    required this.nik,
    required this.name,
    required this.jabatan,
    required this.unitKerja,
    this.role,
    this.divisiKadiv,
    this.fotoUrl,
  });

  factory PegawaiOption.fromMap(Map<String, dynamic> map) {
    return PegawaiOption(
      id: map['id']?.toString() ?? '',
      nik: map['nik']?.toString() ?? '',
      name: map['name']?.toString() ?? map['nama']?.toString() ?? 'Pegawai',
      jabatan: map['jabatan']?.toString() ?? '-',
      unitKerja:
          map['unit_kerja']?.toString() ?? map['cabang']?.toString() ?? '-',
      role: map['role']?.toString(),
      divisiKadiv: map['divisi_kadiv']?.toString(),
      fotoUrl: map['foto_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nik': nik,
        'name': name,
        'jabatan': jabatan,
        'unit_kerja': unitKerja,
        'role': role,
        'divisi_kadiv': divisiKadiv,
        'foto_url': fotoUrl,
      };

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// Ringkasan format "Nama · NIK · Jabatan"
  String get ringkas => '$name ($jabatan - NIK: $nik)';
}

/// Status tugas eksekutor
enum TaskStatus {
  menunggu,
  diproses,
  selesai,
  dibatalkan,
}

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.menunggu:
        return 'Menunggu';
      case TaskStatus.diproses:
        return 'Diproses';
      case TaskStatus.selesai:
        return 'Selesai';
      case TaskStatus.dibatalkan:
        return 'Dibatalkan';
    }
  }

  static TaskStatus fromString(String? val) {
    switch ((val ?? '').toLowerCase()) {
      case 'diproses':
        return TaskStatus.diproses;
      case 'selesai':
        return TaskStatus.selesai;
      case 'dibatalkan':
        return TaskStatus.dibatalkan;
      case 'menunggu':
      default:
        return TaskStatus.menunggu;
    }
  }
}

/// Model untuk satu baris tugas eksekusi di tabel `tasks`
class TaskModel {
  final int id;
  final int pengaduanId;
  final String assignedTo;
  final String? assignedBy;
  final String? assignedByName;
  final String title;
  final String? category;
  final String? description;
  final TaskStatus status;
  final String? notes;
  final List<String> proofFiles;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Metadata opsional dari join pengaduan
  final String? nomorPengaduan;
  final String? pelaporNama;
  final String? pihakTerlapor;

  const TaskModel({
    required this.id,
    required this.pengaduanId,
    required this.assignedTo,
    this.assignedBy,
    this.assignedByName,
    required this.title,
    this.category,
    this.description,
    this.status = TaskStatus.menunggu,
    this.notes,
    this.proofFiles = const [],
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.nomorPengaduan,
    this.pelaporNama,
    this.pihakTerlapor,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    final pMap = map['pengaduan_pegawai'] as Map<String, dynamic>?;

    return TaskModel(
      id: (map['id'] as num).toInt(),
      pengaduanId: (map['pengaduan_id'] as num).toInt(),
      assignedTo: map['assigned_to']?.toString() ?? '',
      assignedBy: map['assigned_by']?.toString(),
      assignedByName: map['assigned_by_name']?.toString(),
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString(),
      description: map['description']?.toString(),
      status: TaskStatusX.fromString(map['status']?.toString()),
      notes: map['notes']?.toString(),
      proofFiles: map['proof_files'] != null
          ? List<String>.from(map['proof_files'])
          : const [],
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now(),
      nomorPengaduan: pMap?['nomor_pengaduan']?.toString(),
      pelaporNama: pMap?['nama_pegawai']?.toString(),
      pihakTerlapor: pMap?['pihak_terlapor']?.toString(),
    );
  }
}
