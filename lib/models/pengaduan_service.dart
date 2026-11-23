// =============================================================
// PENGADUAN SERVICE (PostgreSQL / Local API Architecture)
// SIMPEG Mobile - Decoupled from Supabase
// =============================================================
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_role.dart';
import 'pengaduan_model.dart';
import 'task_model.dart';
import '../services/audit_log_service.dart';
import '../services/onesignal_service.dart';
import '../services/api_service.dart';

/// Mengubah satu baris hasil query (Map) menjadi object
/// [Pengaduan], supaya UI yang sudah ada (getter status.label/.color/.icon,
/// dst) tetap berfungsi tanpa perlu diubah.
Pengaduan pengaduanFromRow(
  Map<String, dynamic> row, {
  List<StatusHistoryEntry> riwayat = const [],
}) {
  PengaduanStatus parseStatus(String? s) {
    return PengaduanStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PengaduanStatus.menungguKadiv,
    );
  }

  Keputusan? parseKeputusan(String? s) {
    if (s == null) return null;
    return Keputusan.values.firstWhere(
      (e) => e.name == s,
      orElse: () => Keputusan.terima,
    );
  }

  KategoriDivisi? parseKategoriDivisi(String? s) {
    if (s == null) return null;
    return KategoriDivisi.values.firstWhere(
      (e) => e.name == s,
      orElse: () => KategoriDivisi.devAdmin,
    );
  }

  Eksekutor? parseEksekutor(String? s) {
    if (s == null) return null;
    return Eksekutor.values.firstWhere(
      (e) => e.name == s,
      orElse: () => Eksekutor.tpdpk,
    );
  }

  DivisiKadiv? parseDivisiKadiv(String? s) {
    if (s == null) return null;
    return DivisiKadiv.values.firstWhere(
      (e) => e.name == s,
      orElse: () => DivisiKadiv.administrasi,
    );
  }

  DateTime parseTgl(dynamic val) {
    if (val == null) return DateTime.now();
    return DateTime.tryParse(val.toString()) ?? DateTime.now();
  }

  List<String> parseList(dynamic val) {
    if (val == null) return const [];
    if (val is List) {
      return val.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (val is String) {
      final str = val.trim();
      if (str.isEmpty || str == '{}' || str == '[]' || str == 'null') {
        return const [];
      }
      if (str.startsWith('[') && str.endsWith(']')) {
        try {
          final decoded = jsonDecode(str);
          if (decoded is List) {
            return decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          }
        } catch (_) {}
      }
      if (str.startsWith('{') && str.endsWith('}')) {
        final inner = str.substring(1, str.length - 1).trim();
        if (inner.isEmpty) return const [];
        return inner
            .split(',')
            .map((s) => s.trim().replaceAll(RegExp(r'^"|"$'), ''))
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [str];
    }
    return const [];
  }

  final pengaduan = Pengaduan(
    tindakLanjutDiminta: row['tindak_lanjut_diminta'] as String?,
    alasanPenolakanDirektur: row['alasan_penolakan_direktur'] as String?,
    catatanPeninjauanKembali: row['catatan_peninjauan_kembali'] as String?,
    catatanReviewHasilKspi: row['catatan_review_hasil_kspi'] as String?,
    kategoriDivisi: parseKategoriDivisi(row['kategori_divisi'] as String?),
    nomorPengaduan: (row['nomor_pengaduan'] ?? 'PGD-000') as String,
    kategori: (row['kategori'] ?? 'Umum') as String,
    judul: (row['judul'] ?? 'Pengaduan') as String,
    deskripsi: (row['deskripsi'] ?? '-') as String,
    tanggalPengaduan: parseTgl(row['tanggal_pengaduan'] ?? row['created_at']),
    namaPegawai: (row['nama_pegawai'] ?? 'Pegawai') as String,
    nik: (row['nik'] ?? '') as String,
    cabang: (row['cabang'] ?? '') as String,
    golongan: (row['golongan'] ?? '') as String,
    pihakTerlapor: row['pihak_terlapor'] as String?,
    nikPelaku: row['nik_pelaku'] as String?,
    jabatanPelaku: row['jabatan_pelaku'] as String?,
    anonim: (row['anonim'] ?? false) as bool,
    status: parseStatus(row['status'] as String?),
    fotoBukti: parseList(row['foto_bukti']),
    dokumenPendukung: parseList(row['dokumen_pendukung']),
    videoBukti: parseList(row['video_bukti']),
    voiceNote: parseList(row['voice_note']),
    investigasiFoto: parseList(row['investigasi_foto']),
    investigasiVideo: parseList(row['investigasi_video']),
    investigasiVoice: parseList(row['investigasi_voice']),
    investigasiDokumen: parseList(row['investigasi_dokumen']),
    riwayatStatus: riwayat,
    keputusanKadiv: parseKeputusan(row['keputusan_kadiv'] as String?),
    catatanKadiv: row['catatan_kadiv'] as String?,
    keputusanDirutTahap1:
        parseKeputusan(row['keputusan_dirut_tahap1'] as String?),
    catatanDirutTahap1: row['catatan_dirut_tahap1'] as String?,
    eksekutor: parseEksekutor(row['eksekutor'] as String?),
    executorId: row['executor_id']?.toString(),
    petugasInvestigasi: row['petugas_investigasi'] as String?,
    eksekutorDivisiKadiv:
        parseDivisiKadiv(row['eksekutor_divisi_kadiv'] as String?),
    kesimpulanInvestigasi: row['kesimpulan_investigasi'] as String?,
    hasilInvestigasi: row['hasil_investigasi'] as String?,
    suratRekomendasi: row['suratRekomendasi'] as String? ?? row['surat_rekomendasi'] as String?,
    tanggalHasilInvestigasi: row['tanggal_hasil_investigasi'] != null
        ? DateTime.tryParse(row['tanggal_hasil_investigasi'].toString())
        : null,
    keputusanDirutTahap2:
        parseKeputusan(row['keputusan_dirut_tahap2'] as String?),
    catatanDirutTahap2: row['catatan_dirut_tahap2'] as String?,
    eksekutorTindakLanjut:
        parseEksekutor(row['eksekutor_tindak_lanjut'] as String?),
    eksekutorTindakLanjutDivisiKadiv: parseDivisiKadiv(
        row['eksekutor_tindak_lanjut_divisi_kadiv'] as String?),
    catatanTindakLanjutSelesai: row['catatan_tindak_lanjut_selesai'] as String?,
    catatanSdm: row['catatan_sdm'] as String?,
    nomorSuratPutusan: row['nomor_surat_putusan'] as String?,
    jenisSanksi: row['jenis_sanksi'] as String?,
    fileSuratPutusan: row['file_surat_putusan'] as String?,
    tanggalSuratPutusan: row['tanggal_surat_putusan'] != null
        ? DateTime.tryParse(row['tanggal_surat_putusan'].toString())
        : null,
    arsipPadaTahap: row['arsip_pada_tahap'] as String?,
    alasanArsip: row['alasan_arsip'] as String?,
  );

  final dynamic rawId = row['id'];
  if (rawId != null) {
    _pengaduanIdMap[pengaduan] = (rawId as num).toInt();
  }
  return pengaduan;
}

final Map<Pengaduan, int> _pengaduanIdMap = {};

extension PengaduanIdX on Pengaduan {
  int? get supabaseId => _pengaduanIdMap[this];
}

/// =============================================================
/// PengaduanService
/// =============================================================
class PengaduanService {
  PengaduanService._();

  static final List<Map<String, dynamic>> _localPengaduan = [];
  static final List<Map<String, dynamic>> _localRiwayat = [];
  static int _autoIdPengaduan = 200;
  static int _autoIdRiwayat = 200;

  static String _resolveEksekutorCategory(String? category, String? role) {
    final candidate = (category ?? role ?? '').toLowerCase();
    if (candidate == 'kadiv' || candidate == 'kadivkategori') return 'kadiv';
    if (candidate == 'tpdpk' || candidate == 'kspi') return 'tpdpk';
    return 'tpdpk';
  }

  /// Membuat nomor pengaduan berformat PGD-YYYYMM-NNN.
  static Future<String> generateNomorPengaduan() async {
    final now = DateTime.now();
    final prefix = 'PGD-${now.year}${now.month.toString().padLeft(2, '0')}';
    var maxUrut = 0;
    for (final r in _localPengaduan) {
      final nomor = (r['nomor_pengaduan'] ?? '').toString();
      final bagian = nomor.split('-');
      if (bagian.length >= 3) {
        final n = int.tryParse(bagian[2]);
        if (n != null && n > maxUrut) maxUrut = n;
      }
    }
    final urut = (maxUrut + 1).toString().padLeft(3, '0');
    return '$prefix-$urut';
  }

  /// Mengambil seluruh data pegawai untuk keperluan pemilihan eksekutor
  static Future<List<PegawaiOption>> fetchDaftarPegawai() async {
    try {
      final rows = await ApiService.listPegawai(perPage: 200);
      return rows.map((r) => PegawaiOption.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// KADIV — verifikasi & kategorisasi, teruskan ke KSPI.
  static Future<void> verifikasiKadiv({
    required int pengaduanId,
    required String oleh,
    required String kategoriDivisi,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguVerifikasiKadiv.name,
      statusBaru: PengaduanStatus.reviewKspi.name,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Verifikasi & kategorisasi, diteruskan ke KSPI',
      catatan: catatan,
      kolomTambahan: {'kategori_divisi': kategoriDivisi},
    );
  }

  /// KSPI — review awal & pilih eksekutor investigasi.
  static Future<void> reviewDanPilihEksekutor({
    required int pengaduanId,
    required String oleh,
    List<PegawaiOption>? selectedExecutors,
    String? executorPegawaiId,
    PegawaiOption? executorPegawai,
    String? eksekutorCategory,
    String? divisiKadiv,
    String? catatan,
  }) async {
    final executors = (selectedExecutors != null && selectedExecutors.isNotEmpty)
        ? selectedExecutors
        : (executorPegawai != null ? [executorPegawai] : <PegawaiOption>[]);

    if (executors.isEmpty) {
      throw 'Harap pilih minimal 1 eksekutor pegawai.';
    }

    final executorNames = executors.map((e) => e.name).join(', ');
    final primaryExecutorId = executors.first.id;

    final pData = await detail(pengaduanId) ?? {
      'judul': 'Pengaduan',
      'nomor_pengaduan': 'PGD-$pengaduanId',
      'kategori': 'Umum',
    };

    final statusBaru = PengaduanStatus.investigasiBerjalan.name;
    final infoEksekutorLabel = executors.length == 1
        ? executors.first.ringkas
        : '${executors.length} Eksekutor ($executorNames)';

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguPilihEksekutor.name,
      statusBaru: statusBaru,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Review & menetapkan eksekutor: $infoEksekutorLabel',
      catatan: catatan,
      kolomTambahan: {
        'executor_id': primaryExecutorId,
        'eksekutor': _resolveEksekutorCategory(
          eksekutorCategory,
          executors.first.role,
        ),
        'eksekutor_divisi_kadiv': divisiKadiv ?? executors.first.divisiKadiv,
        'petugas_investigasi': executorNames,
      },
    );

    for (final executor in executors) {
      await NotificationService.kirimKePegawai(
        pegawaiId: executor.id,
        judul: 'Penugasan Investigasi Baru',
        pesan:
            'Pengaduan: ${pData['judul']} | Tim: $executorNames | Ditugaskan oleh: $oleh',
        pengaduanId: pengaduanId,
      );
    }
  }

  /// KSPI — review hasil investigasi.
  static Future<void> reviewHasilInvestigasi({
    required int pengaduanId,
    required String oleh,
    required bool sesuai,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguReviewKspi.name,
      statusBaru: sesuai
          ? PengaduanStatus.menungguDirutTahap2.name
          : PengaduanStatus.revisiInvestigasi.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: sesuai
          ? 'Hasil investigasi sesuai, diteruskan ke Direktur'
          : 'Hasil investigasi dikembalikan untuk revisi',
      catatan: catatan,
      kolomTambahan: {'catatan_review_hasil_kspi': catatan},
    );
  }

  /// KSPI — kirim ulang setelah ditolak Direktur.
  static Future<void> kirimUlangSetelahRevisiKspi({
    required int pengaduanId,
    required String oleh,
    required String catatanRevisi,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.ditolakDirektur.name,
      statusBaru: PengaduanStatus.menungguDirutTahap2.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Revisi setelah penolakan Direktur, dikirim ulang',
      catatan: catatanRevisi,
    );
  }

  /// KSPI — kirim untuk investigasi ulang.
  static Future<void> kirimUntukInvestigasiUlang({
    required int pengaduanId,
    required String oleh,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.peninjauanKembali.name,
      statusBaru: PengaduanStatus.revisiInvestigasi.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Dikirim untuk investigasi ulang (peninjauan kembali)',
      catatan: catatan,
    );
  }

  /// TPDPK — tetapkan petugas & mulai investigasi.
  static Future<void> tpdpkPilihPetugas({
    required int pengaduanId,
    required String oleh,
    required String petugas,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguInvestigasi.name,
      statusBaru: PengaduanStatus.investigasiBerjalan.name,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Menetapkan petugas investigasi',
      kolomTambahan: {'petugas_investigasi': petugas},
    );
  }

  /// TPDPK — kirim ulang hasil investigasi (revisi) ke KSPI.
  static Future<void> kirimRevisiInvestigasi({
    required int pengaduanId,
    required String oleh,
    required String hasil,
    required String rekomendasi,
    List<String> foto = const [],
    List<String> video = const [],
    List<String> voice = const [],
    List<String> dokumen = const [],
  }) async {
    final kolom = <String, dynamic>{
      'hasil_investigasi': hasil,
      'surat_rekomendasi': rekomendasi,
      'tanggal_hasil_investigasi': DateTime.now().toIso8601String(),
    };
    if (foto.isNotEmpty) kolom['investigasi_foto'] = foto;
    if (video.isNotEmpty) kolom['investigasi_video'] = video;
    if (voice.isNotEmpty) kolom['investigasi_voice'] = voice;
    if (dokumen.isNotEmpty) kolom['investigasi_dokumen'] = dokumen;

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.revisiInvestigasi.name,
      statusBaru: PengaduanStatus.menungguReviewKspi.name,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Mengirim ulang hasil investigasi (revisi)',
      kolomTambahan: kolom,
    );
  }

  /// Submit pengaduan baru oleh pegawai.
  static Future<void> submit({
    required AppUser user,
    required String kategori,
    required String judul,
    required String deskripsi,
    required String pihakTerlapor,
    required String nikPelaku,
    required String jabatanPelaku,
    List<String> fotoBukti = const [],
    List<String> videoBukti = const [],
    List<String> voiceNote = const [],
    List<String> dokumenPendukung = const [],
    bool anonim = false,
  }) async {
    if (user.nik.trim().isEmpty) {
      throw Exception('NIK pegawai tidak tersedia.');
    }
    if (deskripsi.trim().length < 30) {
      throw Exception(
          'Deskripsi pengaduan minimal 30 karakter agar informasi jelas.');
    }

    final nomor = await generateNomorPengaduan();
    final pengaduanId = ++_autoIdPengaduan;
    final now = DateTime.now();

    final row = <String, dynamic>{
      'id': pengaduanId,
      'nomor_pengaduan': nomor,
      'pelapor_id': user.id.isNotEmpty ? user.id : user.nik,
      'kategori': kategori,
      'judul': judul,
      'deskripsi': deskripsi,
      'nama_pegawai': user.name,
      'nik': user.nik,
      'cabang': user.unitKerja,
      'golongan': user.golongan,
      'pihak_terlapor': pihakTerlapor.trim(),
      'nik_pelaku': nikPelaku.trim(),
      'jabatan_pelaku': jabatanPelaku.trim(),
      'anonim': anonim,
      'foto_bukti': fotoBukti,
      'video_bukti': videoBukti,
      'voice_note': voiceNote,
      'dokumen_pendukung': dokumenPendukung,
      'status': PengaduanStatus.menungguKadiv.name,
      'tanggal_pengaduan': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    _localPengaduan.insert(0, row);

    // Sync ke PostgreSQL via Laravel backend jika server aktif
    try {
      await ApiService.storePengaduan(
        nik: user.nik,
        subjek: judul,
        pesan: deskripsi,
        kategori: kategori,
        pihakTerlapor: pihakTerlapor.trim(),
        nikPelaku: nikPelaku.trim(),
        jabatanPelaku: jabatanPelaku.trim(),
        fotoBukti: fotoBukti,
        dokumenPendukung: dokumenPendukung,
        anonim: anonim,
        status: PengaduanStatus.menungguKadiv.name,
      );
    } catch (_) {}

    AuditLogService.logAction(
      userNik: user.nik,
      userName: user.name,
      role: 'PEGAWAI',
      action: 'CREATE',
      module: 'Pengaduan',
      description:
          'Mengajukan pengaduan baru $nomor: "$judul" terhadap ${pihakTerlapor.trim()}',
    );

    _localRiwayat.add({
      'id': ++_autoIdRiwayat,
      'pengaduan_id': pengaduanId,
      'status': PengaduanStatus.menungguKadiv.name,
      'status_lama': null,
      'oleh': 'Sistem',
      'aksi': 'Pengaduan dibuat',
      'keterangan': 'Pengaduan berhasil diajukan oleh pelapor',
      'tanggal': now.toIso8601String(),
    });

    await NotificationService.kirimKeRole(
      role: UserRole.kadivKategori,
      judul: 'Pengaduan baru masuk',
      pesan: '${user.name} membuat pengaduan baru ($nomor).',
      pengaduanId: pengaduanId,
    );
  }

  /// Daftar pengaduan milik pegawai.
  static Future<List<Map<String, dynamic>>> punyaSaya({String? nik}) async {
    // Sinkronisasi dengan database PostgreSQL lokal via API
    try {
      final res = await ApiService.getPengaduan(nik: nik);
      if (res['success'] == true && res['data'] is List) {
        final serverList = List<Map<String, dynamic>>.from(res['data']);
        for (final s in serverList) {
          final sId = (s['id'] as num?)?.toInt() ?? 0;
          final idx = _localPengaduan.indexWhere((lp) => (lp['id'] as num?)?.toInt() == sId);
          final map = Map<String, dynamic>.from(s);
          map['id'] = sId;
          map['nomor_pengaduan'] = s['nomor_pengaduan'] ?? 'PGD-$sId';
          map['status'] = s['status'] ?? PengaduanStatus.menungguKadiv.name;
          if (idx == -1) {
            _localPengaduan.add(map);
          } else {
            _localPengaduan[idx] = map;
          }
        }
      }
    } catch (_) {}

    int compareDateDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
      final tglA = DateTime.tryParse((a['tanggal_pengaduan'] ?? a['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tglB = DateTime.tryParse((b['tanggal_pengaduan'] ?? b['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tglB.compareTo(tglA);
    }

    final result = (nik != null && nik.trim().isNotEmpty)
        ? _localPengaduan
            .where((r) => (r['nik'] ?? '').toString() == nik.trim())
            .toList()
        : List<Map<String, dynamic>>.from(_localPengaduan);
    result.sort(compareDateDesc);
    return result;
  }

  /// Mengambil daftar pengaduan untuk sebuah role.
  static Future<List<Map<String, dynamic>>> untukRole(
    UserRole role, {
    String? divisiKadiv,
  }) async {
    // Sinkronisasi data kotak masuk pengaduan dari backend PostgreSQL
    try {
      final res = await ApiService.getPengaduan(scope: 'role');
      if (res['success'] == true && res['data'] is List) {
        final serverList = List<Map<String, dynamic>>.from(res['data']);
        for (final s in serverList) {
          final sId = (s['id'] as num?)?.toInt() ?? 0;
          final idx = _localPengaduan.indexWhere((lp) => (lp['id'] as num?)?.toInt() == sId);
          final map = Map<String, dynamic>.from(s);
          map['id'] = sId;
          map['nomor_pengaduan'] = s['nomor_pengaduan'] ?? 'PGD-$sId';
          map['status'] = s['status'] ?? PengaduanStatus.menungguKadiv.name;
          if (idx == -1) {
            _localPengaduan.add(map);
          } else {
            _localPengaduan[idx] = map;
          }
        }
      }
    } catch (_) {}

    int compareDateDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
      final tglA = DateTime.tryParse((a['tanggal_pengaduan'] ?? a['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tglB = DateTime.tryParse((b['tanggal_pengaduan'] ?? b['created_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tglB.compareTo(tglA);
    }

    final semua = List<Map<String, dynamic>>.from(_localPengaduan)..sort(compareDateDesc);

    if (role == UserRole.sdm) {
      return semua.where((row) {
        final status = row['status'] as String?;
        final kesimpulan =
            (row['kesimpulan_investigasi'] ?? '').toString().toLowerCase();
        final isTerbukti = kesimpulan == 'terbukti';
        return isTerbukti &&
            (status == PengaduanStatus.menungguSdm.name ||
                status == PengaduanStatus.selesai.name);
      }).toList()..sort(compareDateDesc);
    }

    if (role != UserRole.kadivKategori || divisiKadiv == null) {
      return semua;
    }

    return semua.where((row) {
      final status = row['status'] as String?;

      final belumDiverifikasi = status == PengaduanStatus.menungguKadiv.name ||
          status == PengaduanStatus.menungguVerifikasiKadiv.name;
      if (belumDiverifikasi) {
        final divisi =
            divisiKadivDariKategori((row['kategori'] ?? '') as String);
        if (divisi == null) return true;
        return divisi.name == divisiKadiv;
      }

      final eksekutorNama = row['eksekutor'] as String?;
      final sedangDiinvestigasiOlehKadiv =
          status == PengaduanStatus.investigasiBerjalan.name &&
              eksekutorNama == Eksekutor.kadiv.name;
      if (sedangDiinvestigasiOlehKadiv) {
        final divisi = row['eksekutor_divisi_kadiv'] as String?;
        if (divisi == null) return true;
        return divisi == divisiKadiv;
      }

      final eksekutorTLNama = row['eksekutor_tindak_lanjut'] as String?;
      final sedangTindakLanjutOlehKadiv =
          status == PengaduanStatus.tindakLanjutBerjalan.name &&
              eksekutorTLNama == Eksekutor.kadiv.name;
      if (sedangTindakLanjutOlehKadiv) {
        final divisi = row['eksekutor_tindak_lanjut_divisi_kadiv'] as String?;
        if (divisi == null) return true;
        return divisi == divisiKadiv;
      }

      return true;
    }).toList()..sort(compareDateDesc);
  }

  /// KADIV — alihkan kategori pelanggaran
  static Future<void> alihkanKategoriKadiv({
    required int pengaduanId,
    required String oleh,
    required String kategoriBaru,
    String? nomorPengaduan,
    String? catatan,
  }) async {
    final divisiBaru = divisiKadivDariKategori(kategoriBaru);
    if (divisiBaru == null) {
      throw Exception('Kategori "$kategoriBaru" tidak dikenal.');
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguKadiv.name,
      statusBaru: PengaduanStatus.menungguKadiv.name,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Jenis pelanggaran diubah ke "$kategoriBaru" '
          '- dialihkan ke ${divisiBaru.label}',
      catatan: catatan,
      kolomTambahan: {
        'kategori': kategoriBaru,
        'kategori_divisi': divisiBaru == DivisiKadiv.administrasi
            ? KategoriDivisi.devAdmin.name
            : KategoriDivisi.devTeknik.name,
      },
    );

    await NotificationService.kirimKeKadivDivisi(
      divisi: divisiBaru,
      judul: 'Pengaduan dialihkan ke divisi Anda',
      pesan: '${nomorPengaduan ?? 'Sebuah pengaduan'} dialihkan oleh $oleh '
          'karena termasuk $kategoriBaru.',
      pengaduanId: pengaduanId,
    );
  }

  static Future<Map<String, dynamic>?> detail(int pengaduanId) async {
    for (final p in _localPengaduan) {
      if ((p['id'] as num?)?.toInt() == pengaduanId) return p;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> riwayatStatus(
      int pengaduanId) async {
    return _localRiwayat
        .where((r) => (r['pengaduan_id'] as num?)?.toInt() == pengaduanId)
        .toList();
  }

  static Future<List<Pengaduan>> punyaSayaSebagaiObjek({String? nik}) async {
    final rows = await punyaSaya(nik: nik);
    final list = rows.map((row) => pengaduanFromRow(row)).toList();
    list.sort((a, b) => b.tanggalPengaduan.compareTo(a.tanggalPengaduan));
    return list;
  }

  static List<StatusHistoryEntry> _parseRiwayat(
      List<Map<String, dynamic>> riwayatRows) {
    return riwayatRows.map((r) {
      return StatusHistoryEntry(
        status: PengaduanStatus.values.firstWhere(
          (e) => e.name == r['status'],
          orElse: () => PengaduanStatus.menungguKadiv,
        ),
        statusLama: r['status_lama'] != null
            ? PengaduanStatus.values.firstWhere(
                (e) => e.name == r['status_lama'],
                orElse: () => PengaduanStatus.menungguKadiv,
              )
            : null,
        tanggal: DateTime.tryParse(r['tanggal'].toString()) ?? DateTime.now(),
        keterangan: r['keterangan'] as String?,
        oleh: (r['oleh'] ?? 'Sistem') as String,
        role: r['role'] != null
            ? UserRole.values.firstWhere(
                (e) => e.name == r['role'],
                orElse: () => UserRole.pegawai,
              )
            : null,
        aksi: (r['aksi'] ?? '-') as String,
      );
    }).toList();
  }

  static Future<Pengaduan?> detailLengkap(int pengaduanId) async {
    final row = await detail(pengaduanId);
    if (row == null) return null;
    final riwayatRows = await riwayatStatus(pengaduanId);
    return pengaduanFromRow(row, riwayat: _parseRiwayat(riwayatRows));
  }

  static Future<List<Pengaduan>> untukRoleSebagaiObjek(
    UserRole role, {
    String? divisiKadiv,
  }) async {
    final rows = await untukRole(role, divisiKadiv: divisiKadiv);
    final list = rows.map((row) => pengaduanFromRow(row)).toList();
    list.sort((a, b) => b.tanggalPengaduan.compareTo(a.tanggalPengaduan));
    return list;
  }

  static Future<void> _ubahStatus({
    required int pengaduanId,
    required String statusLama,
    required String statusBaru,
    required String oleh,
    required UserRole role,
    required String aksi,
    String? catatan,
    Map<String, dynamic> kolomTambahan = const {},
  }) async {
    final idx = _localPengaduan
        .indexWhere((p) => (p['id'] as num?)?.toInt() == pengaduanId);
    if (idx != -1) {
      final updated = Map<String, dynamic>.from(_localPengaduan[idx]);
      updated['status'] = statusBaru;
      updated['updated_at'] = DateTime.now().toIso8601String();
      kolomTambahan.forEach((k, v) => updated[k] = v);
      _localPengaduan[idx] = updated;
    }

    _localRiwayat.add({
      'id': ++_autoIdRiwayat,
      'pengaduan_id': pengaduanId,
      'status': statusBaru,
      'status_lama': statusLama,
      'oleh': oleh,
      'role': role.name,
      'aksi': aksi,
      'keterangan': catatan,
      'tanggal': DateTime.now().toIso8601String(),
    });

    AuditLogService.logAction(
      userNik: oleh,
      userName: oleh,
      role: role.label,
      action: 'UPDATE',
      module: 'Pengaduan',
      description:
          '$aksi pada Pengaduan ID #$pengaduanId (status: $statusLama -> $statusBaru)',
    );

    // Sinkronisasi pembaruan status ke backend PostgreSQL
    try {
      await ApiService.updateStatusPengaduan(
        id: pengaduanId,
        status: statusBaru,
        catatan: catatan,
        aksi: aksi,
        kategori: kolomTambahan['kategori'] as String?,
        keputusanKadiv: kolomTambahan['keputusan_kadiv'] as String?,
        catatanKadiv: kolomTambahan['catatan_kadiv'] as String?,
      );
    } catch (_) {}
  }

  /// KADIV — terima/tolak aksi
  static Future<void> kadivAksi({
    required int pengaduanId,
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
    String? kategoriBaru,
  }) async {
    final kolom = <String, dynamic>{
      'keputusan_kadiv': keputusan.name,
      'catatan_kadiv': catatan,
    };
    if (kategoriBaru != null && kategoriBaru.isNotEmpty) {
      kolom['kategori'] = kategoriBaru;
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguKadiv.name,
      statusBaru: PengaduanStatus.reviewKspi.name,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: keputusan == Keputusan.terima
          ? 'Verifikasi (Terima), diteruskan ke KSPI'
              '${kategoriBaru != null ? ' - kategori diubah ke $kategoriBaru' : ''}'
          : 'Verifikasi (Tolak dicatat), tetap diteruskan ke KSPI'
              '${kategoriBaru != null ? ' - kategori diubah ke $kategoriBaru' : ''}',
      catatan: catatan,
      kolomTambahan: kolom,
    );

    await NotificationService.kirimKeRole(
      role: UserRole.kspi,
      judul: 'Pengaduan siap diteruskan ke Dirut',
      pesan: 'Ada pengaduan terverifikasi Kadiv yang perlu diteruskan ke Dirut.',
      pengaduanId: pengaduanId,
    );
  }

  /// KSPI — tolak pengaduan
  static Future<void> kspiTolak({
    required int pengaduanId,
    required String oleh,
    required String catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.reviewKspi.name,
      statusBaru: PengaduanStatus.arsip.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'KSPI menolak pengaduan, diarsipkan',
      catatan: catatan,
      kolomTambahan: {
        'arsip_pada_tahap': 'kspi',
        'alasan_arsip': catatan,
      },
    );

    final row = await detail(pengaduanId);
    final pelaporId = row?['pelapor_id'] as String?;
    final nomor = row?['nomor_pengaduan'];
    if (pelaporId != null) {
      await NotificationService.kirimKePegawai(
        pegawaiId: pelaporId,
        judul: 'Pengaduan ditolak KSPI',
        pesan: 'Pengaduan Anda ($nomor) ditolak oleh KSPI setelah ditinjau. '
            'Alasan: $catatan',
        pengaduanId: pengaduanId,
      );
    }
  }

  /// KSPI — teruskan ke Dirut
  static Future<void> kspiTeruskanKeDirut({
    required int pengaduanId,
    required String oleh,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.reviewKspi.name,
      statusBaru: PengaduanStatus.menungguDirutTahap1.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Meneruskan pengaduan ke Dirut',
      catatan: catatan,
    );

    await NotificationService.kirimKeRole(
      role: UserRole.direktur,
      judul: 'Pengaduan menunggu persetujuan',
      pesan: 'Ada pengaduan yang perlu persetujuan tahap 1.',
      pengaduanId: pengaduanId,
    );
  }

  /// DIRUT — approval tahap 1
  static Future<void> dirutTahap1Aksi({
    required int pengaduanId,
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
  }) async {
    if (keputusan == Keputusan.tolak) {
      await _ubahStatus(
        pengaduanId: pengaduanId,
        statusLama: PengaduanStatus.menungguDirutTahap1.name,
        statusBaru: PengaduanStatus.arsip.name,
        oleh: oleh,
        role: UserRole.direktur,
        aksi: 'Menolak, pengaduan diarsipkan',
        catatan: catatan,
        kolomTambahan: {
          'keputusan_dirut_tahap1': keputusan.name,
          'catatan_dirut_tahap1': catatan,
          'arsip_pada_tahap': 'dirutTahap1',
          'alasan_arsip': catatan,
        },
      );
      return;
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguDirutTahap1.name,
      statusBaru: PengaduanStatus.menungguPilihEksekutor.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi:
          'Menyetujui (layak diinvestigasi), diteruskan ke KSPI untuk pilih eksekutor',
      catatan: catatan,
      kolomTambahan: {
        'keputusan_dirut_tahap1': keputusan.name,
        'catatan_dirut_tahap1': catatan,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.kspi,
      judul: 'Pilih eksekutor investigasi',
      pesan:
          'Dirut menyetujui pengaduan, silakan pilih eksekutor investigasi (TPDPK atau Kadiv).',
      pengaduanId: pengaduanId,
    );
  }

  /// KSPI — pilih eksekutor investigasi
  static Future<void> kspiPilihEksekutor({
    required int pengaduanId,
    required String oleh,
    required Eksekutor eksekutor,
    String? petugas,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguPilihEksekutor.name,
      statusBaru: PengaduanStatus.investigasiBerjalan.name,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Memilih eksekutor investigasi: ${eksekutor.label}'
          '${petugas != null ? ' (petugas: $petugas)' : ''}',
      catatan: catatan,
      kolomTambahan: {
        'eksekutor': eksekutor.name,
        'petugas_investigasi': petugas,
      },
    );

    final roleEksekutor =
        eksekutor == Eksekutor.kadiv ? UserRole.kadivKategori : UserRole.tpdpk;
    await NotificationService.kirimKeRole(
      role: roleEksekutor,
      judul: 'Ditunjuk sebagai eksekutor investigasi',
      pesan: 'Silakan lakukan investigasi & kirim hasilnya.',
      pengaduanId: pengaduanId,
    );
  }

  /// EKSEKUTOR — kirim hasil investigasi
  static Future<void> kirimHasilInvestigasi({
    required int pengaduanId,
    required String oleh,
    required UserRole role,
    String? kesimpulan,
    String? kesimpulanInvestigasi,
    String? hasilInvestigasi,
    String? hasil,
    String? suratRekomendasi,
    String? rekomendasi,
    String? catatan,
    List<String> buktiFoto = const [],
    List<String> foto = const [],
    List<String> buktiVideo = const [],
    List<String> video = const [],
    List<String> buktiVoice = const [],
    List<String> voice = const [],
    List<String> buktiDokumen = const [],
    List<String> dokumen = const [],
  }) async {
    final rawKesimpulan = kesimpulan ?? kesimpulanInvestigasi ?? 'Terbukti';
    final kesimpulanLabel =
        rawKesimpulan.toLowerCase().contains('terbukti') &&
                !rawKesimpulan.toLowerCase().contains('tidak')
            ? 'Terbukti'
            : 'Tidak Terbukti';
    final finalHasil = hasilInvestigasi ?? hasil ?? '-';
    final finalRekomendasi = suratRekomendasi ?? rekomendasi ?? '-';
    final finalFoto = buktiFoto.isNotEmpty ? buktiFoto : foto;
    final finalVideo = buktiVideo.isNotEmpty ? buktiVideo : video;
    final finalVoice = buktiVoice.isNotEmpty ? buktiVoice : voice;
    final finalDokumen = buktiDokumen.isNotEmpty ? buktiDokumen : dokumen;

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.investigasiBerjalan.name,
      statusBaru: PengaduanStatus.menungguDirutTahap2.name,
      oleh: oleh,
      role: role,
      aksi: 'Hasil investigasi dikirim ($kesimpulanLabel)',
      catatan: catatan,
      kolomTambahan: {
        'kesimpulan_investigasi': kesimpulanLabel,
        'hasil_investigasi': finalHasil,
        'surat_rekomendasi': finalRekomendasi,
        'tanggal_hasil_investigasi': DateTime.now().toIso8601String(),
        'investigasi_foto': finalFoto,
        'investigasi_video': finalVideo,
        'investigasi_voice': finalVoice,
        'investigasi_dokumen': finalDokumen,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.direktur,
      judul: 'Hasil investigasi & rekomendasi masuk ($kesimpulanLabel)',
      pesan: 'Hasil investigasi & surat rekomendasi telah masuk langsung ke Dirut.',
      pengaduanId: pengaduanId,
    );
  }

  /// DIREKSI — approval tahap 2
  static Future<void> direksiTahap2Aksi({
    required int pengaduanId,
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
    String? kesimpulanInvestigasi,
  }) async {
    if (keputusan == Keputusan.tolak) {
      await _ubahStatus(
        pengaduanId: pengaduanId,
        statusLama: PengaduanStatus.menungguDirutTahap2.name,
        statusBaru: PengaduanStatus.arsip.name,
        oleh: oleh,
        role: UserRole.direktur,
        aksi: 'Menolak hasil investigasi, pengaduan diarsipkan',
        catatan: catatan,
        kolomTambahan: {
          'keputusan_dirut_tahap2': keputusan.name,
          'catatan_dirut_tahap2': catatan,
          'arsip_pada_tahap': 'dirutTahap2',
          'alasan_arsip': catatan,
        },
      );
      return;
    }

    var kesimpulan = kesimpulanInvestigasi?.toLowerCase();
    if (kesimpulan == null) {
      final row = await detail(pengaduanId);
      kesimpulan = (row?['kesimpulan_investigasi'] ?? '').toString().toLowerCase();
    }

    if (kesimpulan == 'tidak_terbukti' || kesimpulan == 'tidak terbukti') {
      await _ubahStatus(
        pengaduanId: pengaduanId,
        statusLama: PengaduanStatus.menungguDirutTahap2.name,
        statusBaru: PengaduanStatus.arsip.name,
        oleh: oleh,
        role: UserRole.direktur,
        aksi:
            'Menerima hasil investigasi: TIDAK TERBUKTI (Diarsipkan & nama baik terlapor dipulihkan)',
        catatan: catatan,
        kolomTambahan: {
          'keputusan_dirut_tahap2': keputusan.name,
          'catatan_dirut_tahap2': catatan,
          'arsip_pada_tahap': 'dirutTahap2',
          'alasan_arsip': catatan ??
              'Hasil investigasi menyatakan tidak terbukti dan diarsipkan.',
        },
      );

      final row = await detail(pengaduanId);
      final pelaporId = row?['pelapor_id'] as String?;
      if (pelaporId != null) {
        await NotificationService.kirimKePegawai(
          pegawaiId: pelaporId,
          judul: 'Pengaduan selesai (Tidak Terbukti)',
          pesan:
              'Pengaduan (${row?['nomor_pengaduan']}) telah selesai ditindaklanjuti dan dinyatakan tidak terbukti.',
          pengaduanId: pengaduanId,
        );
      }
    } else {
      await _ubahStatus(
        pengaduanId: pengaduanId,
        statusLama: PengaduanStatus.menungguDirutTahap2.name,
        statusBaru: PengaduanStatus.menungguSdm.name,
        oleh: oleh,
        role: UserRole.direktur,
        aksi:
            'Menerima hasil investigasi: TERBUKTI, diteruskan ke SDM untuk surat putusan sanksi',
        catatan: catatan,
        kolomTambahan: {
          'keputusan_dirut_tahap2': keputusan.name,
          'catatan_dirut_tahap2': catatan,
        },
      );

      await NotificationService.kirimKeRole(
        role: UserRole.sdm,
        judul: 'Menunggu Surat Putusan Sanksi',
        pesan:
            'Pengaduan terbukti telah disetujui Direktur Utama. Menunggu penetapan sanksi SDM.',
        pengaduanId: pengaduanId,
      );
    }
  }

  /// DIREKSI — tahap 2 minta peninjauan kembali
  static Future<void> direksiTahap2PeninjauanKembali({
    required int pengaduanId,
    required String oleh,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguDirutTahap2.name,
      statusBaru: PengaduanStatus.menungguPilihEksekutor.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Meminta peninjauan kembali, dikembalikan ke KSPI untuk '
          'memilih eksekutor investigasi ulang',
      catatan: catatan,
      kolomTambahan: {
        'catatan_peninjauan_kembali': catatan,
      },
    );

    await NotificationService.kirimKeRole(
      role: UserRole.kspi,
      judul: 'Peninjauan kembali diminta Direktur',
      pesan: 'Direktur meminta peninjauan kembali atas hasil investigasi. '
          'Silakan pilih eksekutor investigasi ulang.',
      pengaduanId: pengaduanId,
    );
  }

  /// DIREKTUR — memilih eksekutor tindak lanjut
  static Future<void> pilihEksekutorTindakLanjut({
    required int pengaduanId,
    required String oleh,
    required Eksekutor eksekutor,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguPilihEksekutorTindakLanjut.name,
      statusBaru: PengaduanStatus.tindakLanjutBerjalan.name,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Memilih eksekutor tindak lanjut: ${eksekutor.label}',
      kolomTambahan: {'eksekutor_tindak_lanjut': eksekutor.name},
    );

    final roleEksekutor = eksekutor == Eksekutor.kadiv
        ? UserRole.kadivKategori
        : eksekutor == Eksekutor.kspi
            ? UserRole.kspi
            : UserRole.tpdpk;
    await NotificationService.kirimKeRole(
      role: roleEksekutor,
      judul: 'Ditunjuk sebagai eksekutor tindak lanjut',
      pesan: 'Silakan jalankan tindak lanjut yang diminta Direktur.',
      pengaduanId: pengaduanId,
    );
  }

  /// EKSEKUTOR — tindak lanjut selesai
  static Future<void> selesaikanTindakLanjut({
    required int pengaduanId,
    required String oleh,
    required UserRole role,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.tindakLanjutBerjalan.name,
      statusBaru: PengaduanStatus.menungguSdm.name,
      oleh: oleh,
      role: role,
      aksi: 'Tindak lanjut selesai dijalankan, diteruskan ke SDM',
      catatan: catatan,
      kolomTambahan: {'catatan_tindak_lanjut_selesai': catatan},
    );

    await NotificationService.kirimKeRole(
      role: UserRole.sdm,
      judul: 'Menunggu tindak lanjut administratif',
      pesan: 'Ada pengaduan yang perlu ditindaklanjuti secara administratif.',
      pengaduanId: pengaduanId,
    );
  }

  static String _formatRibuan(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return (n < 0 ? '-' : '') + buf.toString();
  }

  /// SDM — menurunkan gaji pegawai (sanksi)
  static Future<void> turunkanGajiPayroll({
    required String nik,
    required int nominal,
    int? pengaduanId,
  }) async {
    AuditLogService.logAction(
      userNik: nik,
      userName: 'Pegawai',
      role: 'SDM',
      action: 'UPDATE',
      module: 'Payroll',
      description:
          'Menurunkan gaji pegawai NIK $nik sebesar Rp${_formatRibuan(nominal)} terkait sanksi pengaduan #$pengaduanId',
    );

    await NotificationService.kirimKePegawai(
      pegawaiId: nik,
      judul: 'Penyesuaian gaji (sanksi)',
      pesan: 'Gaji Anda dikenai potongan sanksi sebesar '
          'Rp${_formatRibuan(nominal)} pada slip gaji periode terbaru.',
      pengaduanId: pengaduanId,
    );
  }

  /// SDM — menyelesaikan tindak lanjut administratif
  static Future<void> sdmSelesaikan({
    required int pengaduanId,
    required String oleh,
    String? catatan,
    String? nikTerlapor,
    int? nominalPenurunanGaji,
  }) async {
    final adaPenurunan = nikTerlapor != null &&
        nikTerlapor.trim().isNotEmpty &&
        nominalPenurunanGaji != null &&
        nominalPenurunanGaji > 0;
    if (adaPenurunan) {
      await turunkanGajiPayroll(
        nik: nikTerlapor.trim(),
        nominal: nominalPenurunanGaji,
        pengaduanId: pengaduanId,
      );
    }

    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguSdm.name,
      statusBaru: PengaduanStatus.selesai.name,
      oleh: oleh,
      role: UserRole.sdm,
      aksi: adaPenurunan
          ? 'Menyelesaikan tindak lanjut administratif — penurunan gaji '
              'Rp${_formatRibuan(nominalPenurunanGaji)} (NIK ${nikTerlapor.trim()})'
          : 'Menyelesaikan tindak lanjut administratif',
      catatan: catatan,
      kolomTambahan: {'catatan_sdm': catatan},
    );

    final row = await detail(pengaduanId);
    final pelaporId = row?['pelapor_id'] as String?;
    if (pelaporId != null) {
      await NotificationService.kirimKePegawai(
        pegawaiId: pelaporId,
        judul: 'Pengaduan selesai',
        pesan: 'Pengaduan Anda (${row?['nomor_pengaduan']}) telah selesai '
            'ditindaklanjuti.',
        pengaduanId: pengaduanId,
      );
    }
  }

  /// SDM — Menerbitkan Surat Putusan Sanksi Resmi
  static Future<void> sdmPutusanSanksi({
    required int pengaduanId,
    required String oleh,
    required String nomorSuratPutusan,
    required String jenisSanksi,
    required String fileSuratPutusan,
    String? catatan,
  }) async {
    await _ubahStatus(
      pengaduanId: pengaduanId,
      statusLama: PengaduanStatus.menungguSdm.name,
      statusBaru: PengaduanStatus.selesai.name,
      oleh: oleh,
      role: UserRole.sdm,
      aksi:
          'Menerbitkan Surat Putusan Sanksi No. $nomorSuratPutusan ($jenisSanksi)',
      catatan: catatan,
      kolomTambahan: {
        'nomor_surat_putusan': nomorSuratPutusan,
        'jenis_sanksi': jenisSanksi,
        'file_surat_putusan': fileSuratPutusan,
        'tanggal_surat_putusan': DateTime.now().toIso8601String(),
        'catatan_sdm': catatan,
      },
    );

    final row = await detail(pengaduanId);
    final pelaporId = row?['pelapor_id'] as String?;
    if (pelaporId != null) {
      await NotificationService.kirimKePegawai(
        pegawaiId: pelaporId,
        judul: 'Surat Putusan Sanksi Diterbitkan',
        pesan:
            'Pengaduan Anda (${row?['nomor_pengaduan']}) telah selesai dengan diterbitkannya Surat Putusan No. $nomorSuratPutusan ($jenisSanksi).',
        pengaduanId: pengaduanId,
      );
    }
  }
}

/// =============================================================
/// NotificationService (In-App Notification & Push Notification)
/// =============================================================
class NotificationService {
  NotificationService._();

  static final List<Map<String, dynamic>> _localNotif = [];
  static int _notifAutoId = 100;

  static Future<List<Map<String, dynamic>>> untukSaya() async {
    final prefs = await SharedPreferences.getInstance();
    final currentNik = prefs.getString('user_nik') ?? '';
    return _localNotif.where((n) {
      final target = (n['untuk_pegawai_id'] ?? '').toString();
      return target.isEmpty || target == currentNik;
    }).toList();
  }

  static Future<int> belumDibaca() async {
    final list = await untukSaya();
    return list.where((n) => n['dibaca'] != true).length;
  }

  static Future<void> tandaiSemuaDibaca() async {
    final prefs = await SharedPreferences.getInstance();
    final currentNik = prefs.getString('user_nik') ?? '';
    for (final n in _localNotif) {
      final target = (n['untuk_pegawai_id'] ?? '').toString();
      if (target.isEmpty || target == currentNik) {
        n['dibaca'] = true;
      }
    }
  }

  static Future<void> kirimKeRole({
    required UserRole role,
    required String judul,
    required String pesan,
    int? pengaduanId,
  }) async {
    _localNotif.insert(0, {
      'id': ++_notifAutoId,
      'untuk_pegawai_id': '',
      'role': role.name,
      'judul': judul,
      'pesan': pesan,
      'dibaca': false,
      'waktu': DateTime.now().toIso8601String(),
      if (pengaduanId != null) 'pengaduan_id': pengaduanId,
    });

    try {
      final payloadData = <String, dynamic>{
        'type': 'pengaduan',
        if (pengaduanId != null) 'pengaduan_id': pengaduanId,
      };
      await OneSignalService.sendNotificationToRole(
        role: role.name,
        title: judul,
        body: pesan,
        data: payloadData,
      );
    } catch (_) {}
  }

  static Future<void> kirimKeKadivDivisi({
    required DivisiKadiv divisi,
    required String judul,
    required String pesan,
    int? pengaduanId,
  }) async {
    _localNotif.insert(0, {
      'id': ++_notifAutoId,
      'untuk_pegawai_id': '',
      'divisi_kadiv': divisi.name,
      'judul': judul,
      'pesan': pesan,
      'dibaca': false,
      'waktu': DateTime.now().toIso8601String(),
      if (pengaduanId != null) 'pengaduan_id': pengaduanId,
    });

    try {
      final payloadData = <String, dynamic>{
        'type': 'pengaduan',
        if (pengaduanId != null) 'pengaduan_id': pengaduanId,
      };
      await OneSignalService.sendNotificationToKadivDivisi(
        divisi: divisi.name,
        title: judul,
        body: pesan,
        data: payloadData,
      );
    } catch (_) {}
  }

  static Future<void> kirimKePegawai({
    required String pegawaiId,
    required String judul,
    required String pesan,
    int? pengaduanId,
    int? pengumumanId,
    int? taskId,
  }) async {
    _localNotif.insert(0, {
      'id': ++_notifAutoId,
      'untuk_pegawai_id': pegawaiId,
      'judul': judul,
      'pesan': pesan,
      'dibaca': false,
      'waktu': DateTime.now().toIso8601String(),
      if (pengaduanId != null) 'pengaduan_id': pengaduanId,
      if (pengumumanId != null) 'pengumuman_id': pengumumanId,
      if (taskId != null) 'task_id': taskId,
    });

    try {
      final payloadData = <String, dynamic>{
        if (pengaduanId != null) ...{
          'type': 'pengaduan',
          'pengaduan_id': pengaduanId
        },
        if (pengumumanId != null) ...{
          'type': 'pengumuman',
          'pengumuman_id': pengumumanId
        },
        if (taskId != null) ...{'type': 'task', 'task_id': taskId},
      };

      await OneSignalService.sendNotificationToUser(
        userNikOrId: pegawaiId,
        title: judul,
        body: pesan,
        data: payloadData,
      );
    } catch (_) {}
  }

  static Future<void> kirimKeBanyakRole({
    required List<UserRole> roles,
    required String judul,
    required String pesan,
    int? pengaduanId,
    int? pengumumanId,
  }) async {
    _localNotif.insert(0, {
      'id': ++_notifAutoId,
      'untuk_pegawai_id': '',
      'roles': roles.map((r) => r.name).toList(),
      'judul': judul,
      'pesan': pesan,
      'dibaca': false,
      'waktu': DateTime.now().toIso8601String(),
      if (pengaduanId != null) 'pengaduan_id': pengaduanId,
      if (pengumumanId != null) 'pengumuman_id': pengumumanId,
    });

    try {
      final payloadData = <String, dynamic>{
        if (pengaduanId != null) ...{
          'type': 'pengaduan',
          'pengaduan_id': pengaduanId
        },
        if (pengumumanId != null) ...{
          'type': 'pengumuman',
          'pengumuman_id': pengumumanId
        },
      };

      if (roles.isEmpty) {
        await OneSignalService.sendBroadcastNotification(
          title: judul,
          body: pesan,
          data: payloadData,
        );
      } else {
        for (final r in roles) {
          await OneSignalService.sendNotificationToRole(
            role: r.name,
            title: judul,
            body: pesan,
            data: payloadData,
          );
        }
      }
    } catch (_) {}
  }

  static Future<void> tandaiDibaca(int notifikasiId) async {
    for (final n in _localNotif) {
      if ((n['id'] as num?)?.toInt() == notifikasiId) {
        n['dibaca'] = true;
        break;
      }
    }
  }
}
