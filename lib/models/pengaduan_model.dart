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
  menungguDirutTahap3,
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
      case PengaduanStatus.menungguDirutTahap3:
        return 'Menunggu Persetujuan Dirut (Tahap 3)';
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
      case PengaduanStatus.menungguDirutTahap3:
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
        return const Color(0xFF0284C7);
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
      case PengaduanStatus.menungguDirutTahap3:
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
      case PengaduanStatus.menungguDirutTahap3:
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
enum Eksekutor { kadiv, kspi, tpdpk }

extension EksekutorX on Eksekutor {
  String get label {
    switch (this) {
      case Eksekutor.kadiv:
        return 'Kadiv Kategori';
      case Eksekutor.kspi:
        return 'KSPI';
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

/// Satu putaran hasil investigasi (awal, peninjauan kembali, atau revisi)
/// beserta seluruh bukti media yang diunggah pada putaran tersebut.
class InvestigasiHistoryEntry {
  final int? id;
  final int tahapKe;
  final String jenisTahap;
  final String labelTahap;
  final String? eksekutor;
  final String? eksekutorDivisiKadiv;
  final String? petugasInvestigasi;
  final String? oleh;
  final String? role;
  final String? kesimpulanInvestigasi;
  final String? hasilInvestigasi;
  final String? suratRekomendasi;
  final String? catatanPeninjauanKembali;
  final List<String> investigasiFoto;
  final List<String> investigasiVideo;
  final List<String> investigasiVoice;
  final List<String> investigasiDokumen;
  final DateTime? tanggal;

  const InvestigasiHistoryEntry({
    this.id,
    required this.tahapKe,
    required this.jenisTahap,
    required this.labelTahap,
    this.eksekutor,
    this.eksekutorDivisiKadiv,
    this.petugasInvestigasi,
    this.oleh,
    this.role,
    this.kesimpulanInvestigasi,
    this.hasilInvestigasi,
    this.suratRekomendasi,
    this.catatanPeninjauanKembali,
    this.investigasiFoto = const [],
    this.investigasiVideo = const [],
    this.investigasiVoice = const [],
    this.investigasiDokumen = const [],
    this.tanggal,
  });

  bool get isTerbukti {
    final val = (kesimpulanInvestigasi ?? '').trim().toLowerCase();
    return val.contains('terbukti') && !val.contains('tidak');
  }

  bool get isTidakTerbukti {
    final val = (kesimpulanInvestigasi ?? '').trim().toLowerCase();
    return val.contains('tidak') && val.contains('terbukti');
  }

  bool get punyaMedia =>
      investigasiFoto.isNotEmpty ||
      investigasiVideo.isNotEmpty ||
      investigasiVoice.isNotEmpty ||
      investigasiDokumen.isNotEmpty;
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
  /// Nama pihak/pelaku yang diadukan — orang yang dituju oleh pengaduan
  /// ini, WAJIB diisi pelapor saat membuat pengaduan.
  final String? pihakTerlapor;
  /// NIK pelaku/pihak yang diadukan — WAJIB diisi bersama [pihakTerlapor].
  final String? nikPelaku;
  /// Jabatan pelaku/pihak yang diadukan — WAJIB diisi bersama
  /// [pihakTerlapor].
  final String? jabatanPelaku;
  final bool anonim;
  final List<String> fotoBukti;
  final List<String> dokumenPendukung;
  final List<String> videoBukti;
  final List<String> voiceNote;
  // --- Lampiran hasil investigasi (TPDPK) ---
  final List<String> investigasiFoto;
  final List<String> investigasiVideo;
  final List<String> investigasiVoice;
  final List<String> investigasiDokumen;
  final List<StatusHistoryEntry> riwayatStatus;
  final List<InvestigasiHistoryEntry> riwayatInvestigasi;

  PengaduanStatus status;

  // --- Tahap Kadiv ---
  Keputusan? keputusanKadiv;
  String? catatanKadiv;

  // --- Tahap Dirut (approval tahap 1: layak diinvestigasi?) ---
  Keputusan? keputusanDirutTahap1;
  String? catatanDirutTahap1;

  // --- Tahap KSPI: pilih eksekutor investigasi ---
  Eksekutor? eksekutor;
  String? executorId; // ID pegawai eksekutor (foreign key ke tabel pegawai)
  String? petugasInvestigasi;
  /// Diisi hanya bila [eksekutor] == Eksekutor.kadiv — menentukan Kadiv
  /// divisi apa (administrasi/teknik) yang jadi eksekutor investigasi,
  /// supaya tugas ini hanya muncul di kotak masuk Kadiv yang bersangkutan.
  DivisiKadiv? eksekutorDivisiKadiv;

  // --- Tahap Investigasi (eksekutor: Kadiv/TPDPK) ---
  /// 'terbukti' | 'tidak_terbukti'
  String? kesimpulanInvestigasi;
  String? hasilInvestigasi;
  String? suratRekomendasi;
  DateTime? tanggalHasilInvestigasi;

  // --- Tahap Direksi (approval tahap 2: hasil investigasi diterima?) ---
  Keputusan? keputusanDirutTahap2;
  String? catatanDirutTahap2;

  // --- Tahap tindak lanjut ---
  Eksekutor? eksekutorTindakLanjut;
  /// Sama seperti [eksekutorDivisiKadiv] tapi untuk tahap tindak lanjut
  /// (setelah Dirut tahap 2 menerima hasil investigasi).
  DivisiKadiv? eksekutorTindakLanjutDivisiKadiv;
  String? catatanTindakLanjutSelesai;

  // --- Tahap SDM (Penerbitan Surat Putusan Sanksi) ---
  String? catatanSdm;
  String? nomorSuratPutusan;
  String? jenisSanksi;
  String? fileSuratPutusan;
  DateTime? tanggalSuratPutusan;

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
    this.pihakTerlapor,
    this.nikPelaku,
    this.jabatanPelaku,
    required this.status,
    this.anonim = false,
    List<String>? fotoBukti,
    List<String>? dokumenPendukung,
    List<String>? videoBukti,
    List<String>? voiceNote,
    List<String>? investigasiFoto,
    List<String>? investigasiVideo,
    List<String>? investigasiVoice,
    List<String>? investigasiDokumen,
    List<StatusHistoryEntry>? riwayatStatus,
    List<InvestigasiHistoryEntry>? riwayatInvestigasi,
    this.keputusanKadiv,
    this.catatanKadiv,
    this.keputusanDirutTahap1,
    this.catatanDirutTahap1,
    this.eksekutor,
    this.executorId,
    this.petugasInvestigasi,
    this.eksekutorDivisiKadiv,
    this.kesimpulanInvestigasi,
    this.hasilInvestigasi,
    this.suratRekomendasi,
    this.tanggalHasilInvestigasi,
    this.keputusanDirutTahap2,
    this.catatanDirutTahap2,
    this.eksekutorTindakLanjut,
    this.eksekutorTindakLanjutDivisiKadiv,
    this.catatanTindakLanjutSelesai,
    this.catatanSdm,
    this.nomorSuratPutusan,
    this.jenisSanksi,
    this.fileSuratPutusan,
    this.tanggalSuratPutusan,
    this.arsipPadaTahap,
    this.alasanArsip,
    this.tindakLanjutDiminta,
    this.alasanPenolakanDirektur,
    this.catatanPeninjauanKembali,
    this.catatanReviewHasilKspi,
    this.kategoriDivisi,
  })  : fotoBukti = fotoBukti ?? [],
        dokumenPendukung = dokumenPendukung ?? [],
        videoBukti = videoBukti ?? [],
        voiceNote = voiceNote ?? [],
        investigasiFoto = investigasiFoto ?? [],
        investigasiVideo = investigasiVideo ?? [],
        investigasiVoice = investigasiVoice ?? [],
        investigasiDokumen = investigasiDokumen ?? [],
        riwayatStatus = riwayatStatus ?? [],
        riwayatInvestigasi = riwayatInvestigasi ?? [];

  /// Apakah data pelaku (nama/NIK/jabatan) sudah lengkap diisi.
  bool get adaDataPelaku =>
      (pihakTerlapor != null && pihakTerlapor!.trim().isNotEmpty) ||
      (nikPelaku != null && nikPelaku!.trim().isNotEmpty) ||
      (jabatanPelaku != null && jabatanPelaku!.trim().isNotEmpty);

  /// Status kesimpulan investigasi: Terbukti vs Tidak Terbukti
  bool get isTerbukti =>
      (kesimpulanInvestigasi ?? '').toLowerCase() == 'terbukti';

  bool get isTidakTerbukti =>
      (kesimpulanInvestigasi ?? '').toLowerCase() == 'tidak_terbukti';

  /// Apakah Surat Putusan Sanksi dari SDM sudah diterbitkan
  bool get adaPutusanSdm =>
      (nomorSuratPutusan != null && nomorSuratPutusan!.trim().isNotEmpty) ||
      (fileSuratPutusan != null && fileSuratPutusan!.trim().isNotEmpty) ||
      (catatanSdm != null && catatanSdm!.contains('SK '));

  /// Ringkasan data pelaku/pihak yang diadukan (Nama, NIK, Jabatan),
  /// diformat satu baris supaya bisa ditampilkan secara konsisten di
  /// kartu info pengaduan maupun di setiap baris riwayat/status, di
  /// semua role (Kadiv, Dirut, KSPI, TPDPK, SDM, Pegawai).
  String get infoPelakuRingkas {
    final bagian = <String>[];
    if (pihakTerlapor != null && pihakTerlapor!.trim().isNotEmpty) {
      bagian.add(pihakTerlapor!.trim());
    }
    if (nikPelaku != null && nikPelaku!.trim().isNotEmpty) {
      bagian.add('NIK ${nikPelaku!.trim()}');
    }
    if (jabatanPelaku != null && jabatanPelaku!.trim().isNotEmpty) {
      bagian.add(jabatanPelaku!.trim());
    }
    if (bagian.isEmpty) return '-';
    return bagian.join(' · ');
  }

  /// Label lengkap "Pelaku: ..." dipakai di keterangan riwayat status.
  String get infoPelakuLabel => 'Pelaku diadukan: $infoPelakuRingkas';

  /// Keterangan/catatan terakhir dari riwayat status.
  String? get keteranganTerakhir {
    for (final h in riwayatStatus.reversed) {
      if (h.keterangan != null && h.keterangan!.trim().isNotEmpty) {
        return h.keterangan;
      }
    }
    return null;
  }

  bool _punyaRiwayat(bool Function(StatusHistoryEntry h) test) =>
      riwayatStatus.any(test);

  static String? _normDivisiStr(DivisiKadiv? d) => d?.name.toLowerCase();

  bool _eksekutorCocokKadivUser(
    AppUser user,
    DivisiKadiv? targetDivisi,
    Eksekutor? ek,
  ) {
    if (ek != Eksekutor.kadiv) return false;
    final userDiv = _normDivisiStr(user.divisiKadiv);
    final tgtDiv = _normDivisiStr(targetDivisi);
    if (userDiv == null) return true;
    if (tgtDiv != null && tgtDiv == userDiv) return true;
    final petugasLower = (petugasInvestigasi ?? '').toLowerCase();
    if (user.name.trim().isNotEmpty &&
        petugasLower.contains(user.name.trim().toLowerCase())) {
      return true;
    }
    if (executorId != null &&
        ((user.id.isNotEmpty && executorId == user.id) ||
            (user.nik.isNotEmpty && executorId == user.nik))) {
      return true;
    }
    return tgtDiv == null && divisiKadivDariKategori(kategori) == user.divisiKadiv;
  }

  // ---------- Cluster membership helpers per role ----------

  bool get kadivPerluVerifikasi =>
      status == PengaduanStatus.menungguKadiv ||
      status == PengaduanStatus.menungguVerifikasiKadiv;

  bool get kadivSudahVerifikasi =>
      keputusanKadiv != null ||
      (!kadivPerluVerifikasi &&
          status != PengaduanStatus.arsip &&
          _punyaRiwayat((h) =>
              h.role == UserRole.kadivKategori ||
              h.statusLama == PengaduanStatus.menungguKadiv ||
              h.statusLama == PengaduanStatus.menungguVerifikasiKadiv)) ||
      (status == PengaduanStatus.arsip && arsipPadaTahap == 'kadiv');

  bool kadivCocokDivisiKategori(AppUser user) {
    if (user.divisiKadiv == null) return true;
    final div = divisiKadivDariKategori(kategori);
    return div == null || div == user.divisiKadiv;
  }

  bool kadivMasukClusterVerifikasi(AppUser user) =>
      (kadivPerluVerifikasi && kadivCocokDivisiKategori(user)) ||
      (kadivSudahVerifikasi && kadivCocokDivisiKategori(user));

  bool kadivSedangInvestigasiAktif(AppUser user) =>
      (status == PengaduanStatus.investigasiBerjalan ||
          status == PengaduanStatus.revisiInvestigasi) &&
      (_eksekutorCocokKadivUser(user, eksekutorDivisiKadiv, eksekutor) ||
          (status == PengaduanStatus.investigasiBerjalan &&
              eksekutor == null &&
              kadivCocokDivisiKategori(user)));

  bool kadivPerluTindakLanjut(AppUser user) =>
      status == PengaduanStatus.tindakLanjutBerjalan &&
      _eksekutorCocokKadivUser(
        user,
        eksekutorTindakLanjutDivisiKadiv,
        eksekutorTindakLanjut,
      );

  bool kadivMasukClusterInvestigasi(AppUser user) {
    if (kadivSedangInvestigasiAktif(user) || kadivPerluTindakLanjut(user)) {
      return true;
    }
    final assignedAsInvestigator =
        _eksekutorCocokKadivUser(user, eksekutorDivisiKadiv, eksekutor) &&
            !kadivPerluVerifikasi &&
            status != PengaduanStatus.reviewKspi &&
            status != PengaduanStatus.menungguDirutTahap1 &&
            status != PengaduanStatus.menungguPilihEksekutor;
    final assignedAsFollowUp = _eksekutorCocokKadivUser(
          user,
          eksekutorTindakLanjutDivisiKadiv,
          eksekutorTindakLanjut,
        ) &&
        (status == PengaduanStatus.menungguSdm || status == PengaduanStatus.selesai);
    return assignedAsInvestigator || assignedAsFollowUp;
  }

  bool get kspiMenungguReviewAwal => status == PengaduanStatus.reviewKspi;

  bool get _kspiSudahLewatReviewAwal =>
      !kspiMenungguReviewAwal &&
      status != PengaduanStatus.menungguKadiv &&
      status != PengaduanStatus.menungguVerifikasiKadiv &&
      (keputusanKadiv != null ||
          status != PengaduanStatus.arsip ||
          arsipPadaTahap == 'kspi' ||
          _punyaRiwayat((h) =>
              h.status == PengaduanStatus.reviewKspi ||
              h.statusLama == PengaduanStatus.reviewKspi ||
              h.role == UserRole.kspi));

  bool get kspiMasukClusterDiterimaKadiv =>
      (kspiMenungguReviewAwal && keputusanKadiv != Keputusan.tolak) ||
      (_kspiSudahLewatReviewAwal && keputusanKadiv != Keputusan.tolak);

  bool get kspiMasukClusterDitolakKadiv =>
      keputusanKadiv == Keputusan.tolak &&
      (kspiMenungguReviewAwal || _kspiSudahLewatReviewAwal);

  bool get kspiMenungguPilihEksekutor =>
      status == PengaduanStatus.menungguPilihEksekutor;

  bool get kspiMasukClusterPilihEksekutor =>
      kspiMenungguPilihEksekutor ||
      eksekutor != null ||
      (petugasInvestigasi != null && petugasInvestigasi!.trim().isNotEmpty) ||
      status == PengaduanStatus.menungguInvestigasi ||
      status == PengaduanStatus.investigasiBerjalan ||
      status == PengaduanStatus.revisiInvestigasi ||
      status == PengaduanStatus.menungguReviewKspi ||
      status == PengaduanStatus.menungguDirutTahap2 ||
      status == PengaduanStatus.menungguDirutTahap3 ||
      status == PengaduanStatus.ditolakDirektur ||
      status == PengaduanStatus.peninjauanKembali ||
      status == PengaduanStatus.menungguPilihEksekutorTindakLanjut ||
      status == PengaduanStatus.tindakLanjutBerjalan ||
      status == PengaduanStatus.menungguSdm ||
      status == PengaduanStatus.selesai ||
      _punyaRiwayat((h) =>
          h.status == PengaduanStatus.menungguPilihEksekutor ||
          h.statusLama == PengaduanStatus.menungguPilihEksekutor);

  bool get kspiMenungguTinjauHasil =>
      status == PengaduanStatus.menungguReviewKspi;

  bool get kspiMasukClusterTinjauHasil =>
      kspiMenungguTinjauHasil ||
      (hasilInvestigasi != null && hasilInvestigasi!.trim().isNotEmpty) ||
      status == PengaduanStatus.revisiInvestigasi ||
      (catatanReviewHasilKspi != null &&
          catatanReviewHasilKspi!.trim().isNotEmpty) ||
      _punyaRiwayat((h) =>
          h.status == PengaduanStatus.menungguReviewKspi ||
          h.statusLama == PengaduanStatus.menungguReviewKspi);

  bool get kspiTindakLanjutAktif =>
      status == PengaduanStatus.tindakLanjutBerjalan &&
      eksekutorTindakLanjut == Eksekutor.kspi;

  bool get kspiMasukClusterTindakLanjut =>
      eksekutorTindakLanjut == Eksekutor.kspi &&
      (status == PengaduanStatus.tindakLanjutBerjalan ||
          status == PengaduanStatus.menungguSdm ||
          status == PengaduanStatus.selesai);

  bool get kspiPeninjauanAktif =>
      status == PengaduanStatus.peninjauanKembali ||
      (status == PengaduanStatus.menungguPilihEksekutor &&
          catatanPeninjauanKembali != null &&
          catatanPeninjauanKembali!.trim().isNotEmpty);

  bool get kspiMasukClusterPeninjauanKembali =>
      kspiPeninjauanAktif ||
      (catatanPeninjauanKembali != null &&
          catatanPeninjauanKembali!.trim().isNotEmpty) ||
      status == PengaduanStatus.ditolakDirektur;

  bool get pernahPeninjauanKembali =>
      status == PengaduanStatus.peninjauanKembali ||
      status == PengaduanStatus.menungguDirutTahap3 ||
      (catatanPeninjauanKembali != null &&
          catatanPeninjauanKembali!.trim().isNotEmpty) ||
      riwayatInvestigasi.any((r) => r.jenisTahap == 'peninjauan_kembali') ||
      _punyaRiwayat((h) =>
          h.status == PengaduanStatus.peninjauanKembali ||
          (h.statusLama == PengaduanStatus.menungguDirutTahap2 &&
              h.status == PengaduanStatus.menungguPilihEksekutor) ||
          h.aksi.toLowerCase().contains('peninjauan kembali') ||
          h.aksi.toLowerCase().contains('tinjau ulang'));

  bool get _adaHasilPascaPeninjauanKembali =>
      riwayatInvestigasi.any((r) => r.jenisTahap == 'peninjauan_kembali') ||
      riwayatInvestigasi.length > 1 ||
      status == PengaduanStatus.menungguDirutTahap3 ||
      _punyaRiwayat((h) => h.status == PengaduanStatus.menungguDirutTahap3);

  /// Daftar seluruh putaran investigasi (awal, peninjauan kembali, revisi).
  /// Fallback ke kolom tunggal di record jika backend belum menyertakan `riwayat_investigasi`.
  List<InvestigasiHistoryEntry> get daftarHasilInvestigasi {
    if (riwayatInvestigasi.isNotEmpty) return riwayatInvestigasi;
    final adaIsi = (kesimpulanInvestigasi ?? '').trim().isNotEmpty ||
        (hasilInvestigasi ?? '').trim().isNotEmpty ||
        (suratRekomendasi ?? '').trim().isNotEmpty ||
        investigasiFoto.isNotEmpty ||
        investigasiVideo.isNotEmpty ||
        investigasiVoice.isNotEmpty ||
        investigasiDokumen.isNotEmpty;
    if (!adaIsi) return const [];
    final isPk = pernahPeninjauanKembali;
    return [
      InvestigasiHistoryEntry(
        tahapKe: isPk ? 2 : 1,
        jenisTahap: isPk ? 'peninjauan_kembali' : 'awal',
        labelTahap: isPk
            ? 'Putaran #2 (Peninjauan Kembali)'
            : 'Putaran #1 (Investigasi Awal)',
        eksekutor: eksekutor?.name,
        eksekutorDivisiKadiv: eksekutorDivisiKadiv?.name,
        petugasInvestigasi: petugasInvestigasi,
        kesimpulanInvestigasi: kesimpulanInvestigasi,
        hasilInvestigasi: hasilInvestigasi,
        suratRekomendasi: suratRekomendasi,
        catatanPeninjauanKembali: catatanPeninjauanKembali,
        investigasiFoto: investigasiFoto,
        investigasiVideo: investigasiVideo,
        investigasiVoice: investigasiVoice,
        investigasiDokumen: investigasiDokumen,
        tanggal: tanggalHasilInvestigasi,
      ),
    ];
  }

  /// Label status tampilan (membedakan Tahap 2 vs Tahap 3 pasca PK).
  String get statusTampilLabel => dirutMenungguTahap3
      ? PengaduanStatus.menungguDirutTahap3.label
      : status.label;

  bool get dirutMenungguTahap1 => status == PengaduanStatus.menungguDirutTahap1;

  bool get dirutMasukClusterTahap1 =>
      dirutMenungguTahap1 ||
      keputusanDirutTahap1 != null ||
      arsipPadaTahap == 'dirutTahap1' ||
      status == PengaduanStatus.menungguPilihEksekutor ||
      status == PengaduanStatus.menungguInvestigasi ||
      status == PengaduanStatus.investigasiBerjalan ||
      status == PengaduanStatus.revisiInvestigasi ||
      status == PengaduanStatus.menungguReviewKspi ||
      status == PengaduanStatus.menungguDirutTahap2 ||
      status == PengaduanStatus.menungguDirutTahap3 ||
      status == PengaduanStatus.ditolakDirektur ||
      status == PengaduanStatus.peninjauanKembali ||
      status == PengaduanStatus.menungguPilihEksekutorTindakLanjut ||
      status == PengaduanStatus.tindakLanjutBerjalan ||
      status == PengaduanStatus.menungguSdm ||
      status == PengaduanStatus.selesai ||
      _punyaRiwayat((h) =>
          h.status == PengaduanStatus.menungguDirutTahap1 ||
          h.statusLama == PengaduanStatus.menungguDirutTahap1 ||
          h.status == PengaduanStatus.menungguPilihEksekutor);

  bool get dirutMenungguTahap2 =>
      status == PengaduanStatus.menungguDirutTahap2 &&
      !pernahPeninjauanKembali;

  bool get dirutMasukClusterTahap2 =>
      dirutMenungguTahap2 ||
      keputusanDirutTahap2 != null ||
      arsipPadaTahap == 'dirutTahap2' ||
      status == PengaduanStatus.menungguDirutTahap3 ||
      status == PengaduanStatus.ditolakDirektur ||
      status == PengaduanStatus.peninjauanKembali ||
      (catatanPeninjauanKembali != null &&
          catatanPeninjauanKembali!.trim().isNotEmpty) ||
      status == PengaduanStatus.menungguPilihEksekutorTindakLanjut ||
      status == PengaduanStatus.tindakLanjutBerjalan ||
      status == PengaduanStatus.menungguSdm ||
      status == PengaduanStatus.selesai ||
      _punyaRiwayat((h) =>
          h.status == PengaduanStatus.menungguDirutTahap2 ||
          h.statusLama == PengaduanStatus.menungguDirutTahap2);

  bool get dirutMenungguTahap3 =>
      status == PengaduanStatus.menungguDirutTahap3 ||
      (status == PengaduanStatus.menungguDirutTahap2 &&
          pernahPeninjauanKembali);

  bool get dirutMasukClusterTahap3 =>
      dirutMenungguTahap3 ||
      (pernahPeninjauanKembali &&
          (_adaHasilPascaPeninjauanKembali ||
              status == PengaduanStatus.menungguPilihEksekutorTindakLanjut ||
              status == PengaduanStatus.tindakLanjutBerjalan ||
              status == PengaduanStatus.menungguSdm ||
              status == PengaduanStatus.selesai ||
              (status == PengaduanStatus.arsip &&
                  arsipPadaTahap == 'dirutTahap2') ||
              status == PengaduanStatus.ditolakDirektur));

  bool get dirutMenungguPilihEksekutor =>
      status == PengaduanStatus.menungguPilihEksekutorTindakLanjut;

  bool get dirutMasukClusterPilihEksekutor =>
      dirutMenungguPilihEksekutor ||
      eksekutorTindakLanjut != null ||
      status == PengaduanStatus.tindakLanjutBerjalan ||
      _punyaRiwayat((h) =>
          h.status == PengaduanStatus.menungguPilihEksekutorTindakLanjut ||
          h.statusLama == PengaduanStatus.menungguPilihEksekutorTindakLanjut);

  bool get dirutPerluAksi =>
      dirutMenungguTahap1 ||
      dirutMenungguTahap2 ||
      dirutMenungguTahap3 ||
      dirutMenungguPilihEksekutor;

  bool get tpdpkMenungguPetugas => status == PengaduanStatus.menungguInvestigasi;

  bool get tpdpkMasukClusterMenungguPetugas =>
      tpdpkMenungguPetugas ||
      (eksekutor == Eksekutor.tpdpk &&
          _punyaRiwayat((h) =>
              h.status == PengaduanStatus.menungguInvestigasi ||
              h.statusLama == PengaduanStatus.menungguInvestigasi));

  bool get tpdpkInvestigasiAktif =>
      status == PengaduanStatus.investigasiBerjalan &&
      eksekutor == Eksekutor.tpdpk;

  bool get tpdpkMasukClusterInvestigasi =>
      tpdpkInvestigasiAktif ||
      (eksekutor == Eksekutor.tpdpk &&
          status != PengaduanStatus.revisiInvestigasi &&
          status != PengaduanStatus.menungguInvestigasi &&
          status != PengaduanStatus.menungguPilihEksekutor);

  bool get tpdpkPerluRevisi =>
      status == PengaduanStatus.revisiInvestigasi &&
      eksekutor == Eksekutor.tpdpk;

  bool get tpdpkTindakLanjutAktif =>
      status == PengaduanStatus.tindakLanjutBerjalan &&
      eksekutorTindakLanjut == Eksekutor.tpdpk;

  bool get tpdpkMasukClusterTindakLanjut =>
      eksekutorTindakLanjut == Eksekutor.tpdpk &&
      (status == PengaduanStatus.tindakLanjutBerjalan ||
          status == PengaduanStatus.menungguSdm ||
          status == PengaduanStatus.selesai);

  bool get sdmMenungguTindakLanjut => status == PengaduanStatus.menungguSdm;

  bool get sdmMasukClusterMenunggu =>
      sdmMenungguTindakLanjut ||
      (status == PengaduanStatus.selesai &&
          (adaPutusanSdm ||
              isTerbukti ||
              _punyaRiwayat((h) =>
                  h.status == PengaduanStatus.menungguSdm ||
                  h.statusLama == PengaduanStatus.menungguSdm ||
                  h.role == UserRole.sdm)));

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
  final d = date.toUtc().add(const Duration(hours: 7));
  return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.year}';
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
  final d = date.toUtc().add(const Duration(hours: 7));
  final jam = d.hour.toString().padLeft(2, '0');
  final menit = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${bulanSingkat[d.month - 1]} ${d.year}, $jam:$menit';
}

/// Mengurutkan daftar cluster pengaduan: item yang masih membutuhkan aksi
/// role saat ini ([isPending] == true) selalu di atas (terbaru dulu), disusul
/// item yang sudah diproses/diteruskan agar tetap terlihat di cluster tersebut.
List<Pengaduan> urutkanClusterPengaduan(
  Iterable<Pengaduan> items,
  bool Function(Pengaduan p) isPending,
) {
  final pending = <Pengaduan>[];
  final processed = <Pengaduan>[];
  for (final p in items) {
    if (isPending(p)) {
      pending.add(p);
    } else {
      processed.add(p);
    }
  }
  pending.sort((a, b) => b.tanggalPengaduan.compareTo(a.tanggalPengaduan));
  processed.sort((a, b) => b.tanggalPengaduan.compareTo(a.tanggalPengaduan));
  return [...pending, ...processed];
}