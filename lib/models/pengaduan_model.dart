import 'package:flutter/material.dart';
import 'user_role.dart';

/// =============================================================
/// STATUS PENGADUAN — alur baru:
/// Pegawai submit -> Kadiv (terima/tolak) -> [otomatis via KSPI] ->
/// Dirut tahap 1 (terima/tolak, layak diinvestigasi?) -> KSPI pilih
/// eksekutor investigasi (Kadiv/TPDPK) -> investigasi berjalan -> hasil
/// investigasi + surat rekomendasi -> Direksi tahap 2 (terima/tolak,
/// hasil investigasi diterima?) -> pilih eksekutor tindak lanjut
/// (Kadiv/TPDPK) -> tindak lanjut berjalan -> diteruskan ke SDM -> Selesai.
///
/// Setiap titik "tolak" (Kadiv, Dirut tahap 1, Direksi tahap 2) berakhir
/// di status `arsip` (final, lihat field `arsipPadaTahap` & `alasanArsip`
/// pada [Pengaduan] untuk tahu di titik mana & kenapa diarsipkan).
/// =============================================================
enum PengaduanStatus {
  menungguKadiv,
  menungguDirutTahap1,
  menungguPilihEksekutor,
  investigasiBerjalan,
  menungguDirutTahap2,
  menungguPilihEksekutorTindakLanjut,
  tindakLanjutBerjalan,
  menungguSdm,
  selesai,
  arsip,
  menungguVerifikasiKadiv,
  tindakLanjut,
  reviewKspi,
  menungguReviewKspi,
  ditolakDirektur,
  peninjauanKembali,
  menungguInvestigasi,
  revisiInvestigasi,
}

extension PengaduanStatusX on PengaduanStatus {
  String get label {
    switch (this) {
      case PengaduanStatus.menungguKadiv:
        return 'Menunggu Kadiv';
      case PengaduanStatus.menungguVerifikasiKadiv:
        return 'Menunggu Verifikasi Kadiv';
      case PengaduanStatus.menungguDirutTahap1:
        return 'Menunggu Persetujuan Dirut (Tahap 1)';
      case PengaduanStatus.menungguPilihEksekutor:
        return 'Menunggu Pilih Eksekutor';
      case PengaduanStatus.reviewKspi:
        return 'Review KSPI';
      case PengaduanStatus.menungguReviewKspi:
        return 'Menunggu Review KSPI';
      case PengaduanStatus.menungguInvestigasi:
        return 'Menunggu Investigasi';
      case PengaduanStatus.investigasiBerjalan:
        return 'Investigasi Berjalan';
      case PengaduanStatus.revisiInvestigasi:
        return 'Revisi Investigasi';
      case PengaduanStatus.menungguDirutTahap2:
        return 'Menunggu Persetujuan Dirut (Tahap 2)';
      case PengaduanStatus.ditolakDirektur:
        return 'Ditolak Direktur';
      case PengaduanStatus.peninjauanKembali:
        return 'Peninjauan Kembali';
      case PengaduanStatus.menungguPilihEksekutorTindakLanjut:
        return 'Menunggu Pilih Eksekutor Tindak Lanjut';
      case PengaduanStatus.tindakLanjutBerjalan:
        return 'Tindak Lanjut Berjalan';
      case PengaduanStatus.tindakLanjut:
        return 'Tindak Lanjut';
      case PengaduanStatus.menungguSdm:
        return 'Menunggu SDM';
      case PengaduanStatus.selesai:
        return 'Selesai';
      case PengaduanStatus.arsip:
        return 'Diarsipkan';
    }
  }

  Color get color {
    switch (this) {
      case PengaduanStatus.menungguKadiv:
      case PengaduanStatus.menungguVerifikasiKadiv:
        return const Color(0xFF95A5A6);
      case PengaduanStatus.menungguDirutTahap1:
      case PengaduanStatus.menungguDirutTahap2:
        return const Color(0xFFE67E22);
      case PengaduanStatus.menungguPilihEksekutor:
      case PengaduanStatus.menungguPilihEksekutorTindakLanjut:
        return const Color(0xFF2E86AB);
      case PengaduanStatus.reviewKspi:
        return const Color(0xFF2E86AB);
      case PengaduanStatus.menungguReviewKspi:
        return const Color(0xFFE67E22);
      case PengaduanStatus.menungguInvestigasi:
        return const Color(0xFFE67E22);
      case PengaduanStatus.investigasiBerjalan:
      case PengaduanStatus.tindakLanjutBerjalan:
        return const Color(0xFF2E86AB);
      case PengaduanStatus.revisiInvestigasi:
        return const Color(0xFFD35400);
      case PengaduanStatus.ditolakDirektur:
        return const Color(0xFFE74C3C);
      case PengaduanStatus.peninjauanKembali:
        return const Color(0xFF8E44AD);
      case PengaduanStatus.tindakLanjut:
        return const Color(0xFF27AE60);
      case PengaduanStatus.menungguSdm:
        return const Color(0xFFE67E22);
      case PengaduanStatus.selesai:
        return const Color(0xFF27AE60);
      case PengaduanStatus.arsip:
        return const Color(0xFF7F8C8D);
    }
  }

  IconData get icon {
    switch (this) {
      case PengaduanStatus.menungguKadiv:
      case PengaduanStatus.menungguVerifikasiKadiv:
        return Icons.hourglass_top_rounded;
      case PengaduanStatus.menungguDirutTahap1:
      case PengaduanStatus.menungguDirutTahap2:
        return Icons.fact_check_rounded;
      case PengaduanStatus.menungguPilihEksekutor:
      case PengaduanStatus.menungguPilihEksekutorTindakLanjut:
        return Icons.person_search_rounded;
      case PengaduanStatus.reviewKspi:
        return Icons.rate_review_rounded;
      case PengaduanStatus.menungguReviewKspi:
        return Icons.fact_check_rounded;
      case PengaduanStatus.menungguInvestigasi:
        return Icons.search_rounded;
      case PengaduanStatus.investigasiBerjalan:
      case PengaduanStatus.tindakLanjutBerjalan:
        return Icons.autorenew_rounded;
      case PengaduanStatus.revisiInvestigasi:
        return Icons.autorenew_rounded;
      case PengaduanStatus.ditolakDirektur:
        return Icons.gpp_bad_rounded;
      case PengaduanStatus.peninjauanKembali:
        return Icons.replay_rounded;
      case PengaduanStatus.tindakLanjut:
        return Icons.flag_rounded;
      case PengaduanStatus.menungguSdm:
        return Icons.assignment_ind_rounded;
      case PengaduanStatus.selesai:
        return Icons.check_circle_rounded;
      case PengaduanStatus.arsip:
        return Icons.archive_rounded;
    }
  }

  int get stepOrder {
    switch (this) {
      case PengaduanStatus.menungguKadiv:
      case PengaduanStatus.menungguVerifikasiKadiv:
        return 1;
      case PengaduanStatus.menungguDirutTahap1:
        return 2;
      case PengaduanStatus.menungguPilihEksekutor:
      case PengaduanStatus.reviewKspi:
        return 3;
      case PengaduanStatus.menungguInvestigasi:
      case PengaduanStatus.investigasiBerjalan:
        return 4;
      case PengaduanStatus.menungguReviewKspi:
      case PengaduanStatus.revisiInvestigasi:
        return 5;
      case PengaduanStatus.menungguDirutTahap2:
      case PengaduanStatus.ditolakDirektur:
      case PengaduanStatus.peninjauanKembali:
        return 6;
      case PengaduanStatus.menungguPilihEksekutorTindakLanjut:
        return 7;
      case PengaduanStatus.tindakLanjutBerjalan:
      case PengaduanStatus.tindakLanjut:
        return 8;
      case PengaduanStatus.menungguSdm:
        return 9;
      case PengaduanStatus.selesai:
        return 10;
      case PengaduanStatus.arsip:
        return -1;
    }
  }

  bool get isFinal =>
      this == PengaduanStatus.selesai || this == PengaduanStatus.arsip;
}

/// Keputusan terima/tolak — dipakai berulang di 3 titik approval:
/// Kadiv, Dirut Tahap 1, dan Direksi Tahap 2.
enum Keputusan { terima, tolak }

extension KeputusanX on Keputusan {
  String get label => this == Keputusan.terima ? 'Terima' : 'Tolak';
}

/// Eksekutor yang dipilih KSPI (investigasi) atau Direktur (tindak
/// lanjut). KSPI sendiri tidak pernah menjadi eksekutor.
enum Eksekutor { kadiv, tpdpk }

extension EksekutorX on Eksekutor {
  String get label {
    switch (this) {
      case Eksekutor.kadiv:
        return 'Kadiv Kategori';
      case Eksekutor.tpdpk:
        return 'TPDPK';
    }
  }
}

/// Satu baris riwayat perubahan status pada sebuah pengaduan.
class StatusHistoryEntry {
  final PengaduanStatus status;
  final PengaduanStatus? statusLama;
  final DateTime tanggal;
  final String? keterangan;
  final String oleh;
  final UserRole? role;
  final String aksi;

  const StatusHistoryEntry({
    required this.status,
    required this.tanggal,
    this.statusLama,
    this.keterangan,
    this.oleh = 'Sistem',
    this.role,
    this.aksi = 'Perubahan status',
  });
}

/// Model utama satu pengaduan pegawai.
class Pengaduan {
  final String nomorPengaduan;
  final String
      kategori; // 'Pelanggaran Administrasi' / 'Pelanggaran Teknik', dipilih Pegawai
  final String judul;
  final String deskripsi;
  final DateTime tanggalPengaduan;
  final String namaPegawai;
  final String nik;
  final String cabang;
  final String golongan;
  final bool anonim;
  final List<String> fotoBukti;
  final List<String> dokumenPendukung;
  final List<StatusHistoryEntry> riwayatStatus;

  PengaduanStatus status;

  // --- Tahap Kadiv ---
  Keputusan? keputusanKadiv;
  String? catatanKadiv;

  // --- Tahap Dirut (approval tahap 1: layak diinvestigasi?) ---
  Keputusan? keputusanDirutTahap1;
  String? catatanDirutTahap1;

  // --- Tahap KSPI: pilih eksekutor investigasi ---
  Eksekutor? eksekutor;
  String? petugasInvestigasi;

  // --- Tahap Investigasi (eksekutor: Kadiv/TPDPK) ---
  String? hasilInvestigasi;
  String? suratRekomendasi;
  DateTime? tanggalHasilInvestigasi;

  // --- Tahap Direksi (approval tahap 2: hasil investigasi diterima?) ---
  Keputusan? keputusanDirutTahap2;
  String? catatanDirutTahap2;

  // --- Tahap tindak lanjut ---
  Eksekutor? eksekutorTindakLanjut;
  String? catatanTindakLanjutSelesai;

  // --- Tahap SDM (final) ---
  String? catatanSdm;

  // --- Arsip (kalau ditolak di salah satu dari 3 titik approval) ---
  /// 'kadiv' | 'dirutTahap1' | 'dirutTahap2'
  String? arsipPadaTahap;
  String? alasanArsip;
  String? tindakLanjutDiminta; // instruksi tindak lanjut dari Direktur
  String? alasanPenolakanDirektur; // alasan Direktur menolak
  String? catatanPeninjauanKembali; // catatan saat peninjauan kembali
  String? catatanReviewHasilKspi; // catatan revisi dari KSPI
  KategoriDivisi? kategoriDivisi; // hasil kategorisasi Kadiv

  Pengaduan({
    required this.nomorPengaduan,
    required this.kategori,
    required this.judul,
    required this.deskripsi,
    required this.tanggalPengaduan,
    required this.namaPegawai,
    required this.nik,
    required this.cabang,
    required this.golongan,
    required this.status,
    this.anonim = false,
    List<String>? fotoBukti,
    List<String>? dokumenPendukung,
    List<StatusHistoryEntry>? riwayatStatus,
    this.keputusanKadiv,
    this.catatanKadiv,
    this.keputusanDirutTahap1,
    this.catatanDirutTahap1,
    this.eksekutor,
    this.petugasInvestigasi,
    this.hasilInvestigasi,
    this.suratRekomendasi,
    this.tanggalHasilInvestigasi,
    this.keputusanDirutTahap2,
    this.catatanDirutTahap2,
    this.eksekutorTindakLanjut,
    this.catatanTindakLanjutSelesai,
    this.catatanSdm,
    this.arsipPadaTahap,
    this.alasanArsip,
    this.tindakLanjutDiminta,
    this.alasanPenolakanDirektur,
    this.catatanPeninjauanKembali,
    this.catatanReviewHasilKspi,
    this.kategoriDivisi,
  })  : fotoBukti = fotoBukti ?? [],
        dokumenPendukung = dokumenPendukung ?? [],
        riwayatStatus = riwayatStatus ?? [];

  /// Keterangan/catatan terakhir dari riwayat status.
  String? get keteranganTerakhir {
    for (final h in riwayatStatus.reversed) {
      if (h.keterangan != null && h.keterangan!.trim().isNotEmpty) {
        return h.keterangan;
      }
    }
    return null;
  }

  void _ubahStatus({
    required PengaduanStatus statusBaru,
    required String oleh,
    required UserRole role,
    required String aksi,
    String? catatan,
  }) {
    final statusLama = status;
    status = statusBaru;
    riwayatStatus.add(
      StatusHistoryEntry(
        status: statusBaru,
        statusLama: statusLama,
        tanggal: DateTime.now(),
        keterangan: catatan,
        oleh: oleh,
        role: role,
        aksi: aksi,
      ),
    );
  }

  void _arsipkan({
    required String oleh,
    required UserRole role,
    required String tahap, // 'kadiv' | 'dirutTahap1' | 'dirutTahap2'
    String? catatan,
  }) {
    arsipPadaTahap = tahap;
    alasanArsip = catatan;
    _ubahStatus(
      statusBaru: PengaduanStatus.arsip,
      oleh: oleh,
      role: role,
      aksi: 'Ditolak, pengaduan diarsipkan',
      catatan: catatan,
    );
  }

  /// KADIV — terima/tolak. Tolak -> arsip. Terima -> otomatis diteruskan
  /// ke Dirut (lewat KSPI).
  void kadivAksi({
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
  }) {
    keputusanKadiv = keputusan;
    catatanKadiv = catatan;
    if (keputusan == Keputusan.tolak) {
      _arsipkan(
          oleh: oleh,
          role: UserRole.kadivKategori,
          tahap: 'kadiv',
          catatan: catatan);
      return;
    }
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguDirutTahap1,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Menerima pengaduan',
      catatan: catatan,
    );
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguDirutTahap1,
      oleh: 'Sistem',
      role: UserRole.kadivKategori,
      aksi: 'Diteruskan otomatis via KSPI ke Dirut',
    );
  }

  /// DIRUT — approval tahap 1 (layak diinvestigasi?). Tolak -> arsip.
  /// Terima -> balik ke KSPI untuk pilih eksekutor.
  void dirutTahap1Aksi({
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
  }) {
    keputusanDirutTahap1 = keputusan;
    catatanDirutTahap1 = catatan;
    if (keputusan == Keputusan.tolak) {
      _arsipkan(
          oleh: oleh,
          role: UserRole.direktur,
          tahap: 'dirutTahap1',
          catatan: catatan);
      return;
    }
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguPilihEksekutor,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Menyetujui (layak diinvestigasi), dikembalikan ke KSPI',
      catatan: catatan,
    );
  }

  /// KSPI — pilih eksekutor investigasi (Kadiv/TPDPK).
  void kspiPilihEksekutor({
    required String oleh,
    required Eksekutor eksekutorBaru,
    String? petugas,
    String? catatan,
  }) {
    eksekutor = eksekutorBaru;
    petugasInvestigasi = petugas;
    _ubahStatus(
      statusBaru: PengaduanStatus.investigasiBerjalan,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Memilih eksekutor investigasi: ${eksekutorBaru.label}'
          '${petugas != null ? ' (petugas: $petugas)' : ''}',
      catatan: catatan,
    );
  }

  /// EKSEKUTOR (Kadiv/TPDPK) — kirim hasil investigasi + surat
  /// rekomendasi, langsung diteruskan otomatis ke Direksi (tahap 2).
  void kirimHasilInvestigasi({
    required String oleh,
    required UserRole role,
    required String hasil,
    required String rekomendasi,
  }) {
    hasilInvestigasi = hasil;
    suratRekomendasi = rekomendasi;
    tanggalHasilInvestigasi = DateTime.now();
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguDirutTahap2,
      oleh: oleh,
      role: role,
      aksi: 'Mengirim hasil investigasi & surat rekomendasi',
    );
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguDirutTahap2,
      oleh: 'Sistem',
      role: role,
      aksi: 'Diteruskan otomatis ke Direksi untuk persetujuan tahap 2',
    );
  }

  /// DIREKSI (akun Dirut) — approval tahap 2 (hasil investigasi
  /// diterima?). Tolak -> arsip. Terima -> menunggu pilih eksekutor
  /// tindak lanjut.
  void direksiTahap2Aksi({
    required String oleh,
    required Keputusan keputusan,
    String? catatan,
  }) {
    keputusanDirutTahap2 = keputusan;
    catatanDirutTahap2 = catatan;
    if (keputusan == Keputusan.tolak) {
      _arsipkan(
          oleh: oleh,
          role: UserRole.direktur,
          tahap: 'dirutTahap2',
          catatan: catatan);
      return;
    }
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguPilihEksekutorTindakLanjut,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Menerima hasil investigasi (ditindaklanjuti)',
      catatan: catatan,
    );
  }

  /// DIREKTUR — memilih eksekutor tindak lanjut (Kadiv/TPDPK).
  void pilihEksekutorTindakLanjut({
    required String oleh,
    required Eksekutor eksekutorBaru,
  }) {
    eksekutorTindakLanjut = eksekutorBaru;
    _ubahStatus(
      statusBaru: PengaduanStatus.tindakLanjutBerjalan,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Memilih eksekutor tindak lanjut: ${eksekutorBaru.label}',
    );
  }

  /// EKSEKUTOR (Kadiv/TPDPK) — tindak lanjut selesai dijalankan,
  /// diteruskan ke SDM.
  void selesaikanTindakLanjut({
    required String oleh,
    required UserRole role,
    String? catatan,
  }) {
    catatanTindakLanjutSelesai = catatan;
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguSdm,
      oleh: oleh,
      role: role,
      aksi: 'Tindak lanjut selesai dijalankan, diteruskan ke SDM',
      catatan: catatan,
    );
  }

  /// SDM — menandai tindak lanjut administratif selesai. Titik akhir alur.
  void sdmSelesaikan({
    required String oleh,
    String? catatan,
  }) {
    catatanSdm = catatan;
    _ubahStatus(
      statusBaru: PengaduanStatus.selesai,
      oleh: oleh,
      role: UserRole.sdm,
      aksi: 'Menyelesaikan tindak lanjut administratif',
      catatan: catatan,
    );
  }
}

String formatTanggalIndonesia(DateTime date) {
  const hari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    "Jum'at",
    'Sabtu',
    'Minggu'
  ];
  const bulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${hari[date.weekday - 1]}, ${date.day} ${bulan[date.month - 1]} ${date.year}';
}

String formatTanggalJam(DateTime date) {
  const bulanSingkat = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final jam = date.hour.toString().padLeft(2, '0');
  final menit = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${bulanSingkat[date.month - 1]} ${date.year}, $jam:$menit';
}
