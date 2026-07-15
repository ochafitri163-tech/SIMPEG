import 'package:flutter/material.dart';
import 'user_role.dart';

/// =============================================================
/// STATUS PENGADUAN — 14 tahap sesuai flowchart SIMPEG PDAM.
/// Alur normal (Tahap 4 & 5):
/// Draft -> Menunggu Verifikasi Kadiv -> Diverifikasi Kadiv ->
/// Review KSPI -> Menunggu Investigasi -> Investigasi Berjalan ->
/// Hasil Investigasi -> Menunggu Review KSPI ->
/// Menunggu Persetujuan Direktur -> Selesai
///
/// Cabang alternatif dari "Menunggu Persetujuan Direktur":
/// - Ditolak Direktur -> (KSPI revisi) -> Menunggu Persetujuan Direktur lagi
/// - Peninjauan Kembali -> (KSPI investigasi ulang) -> Menunggu Investigasi
/// - Tindak Lanjut -> (eksekutor menjalankan) -> Selesai
///
/// Dari "Menunggu Review KSPI" / hasil investigasi belum sesuai:
/// - Revisi Investigasi -> kembali ke Investigasi Berjalan
/// =============================================================
enum PengaduanStatus {
  draft,
  menungguVerifikasiKadiv,
  diverifikasiKadiv,
  reviewKspi,
  menungguInvestigasi,
  investigasiBerjalan,
  hasilInvestigasi,
  menungguReviewKspi,
  menungguPersetujuanDirektur,
  ditolakDirektur,
  revisiInvestigasi,
  peninjauanKembali,
  tindakLanjut,
  selesai,
}

extension PengaduanStatusX on PengaduanStatus {
  String get label {
    switch (this) {
      case PengaduanStatus.draft:
        return 'Draft';
      case PengaduanStatus.menungguVerifikasiKadiv:
        return 'Menunggu Verifikasi Kadiv';
      case PengaduanStatus.diverifikasiKadiv:
        return 'Diverifikasi Kadiv';
      case PengaduanStatus.reviewKspi:
        return 'Review KSPI';
      case PengaduanStatus.menungguInvestigasi:
        return 'Menunggu Investigasi';
      case PengaduanStatus.investigasiBerjalan:
        return 'Investigasi Berjalan';
      case PengaduanStatus.hasilInvestigasi:
        return 'Hasil Investigasi';
      case PengaduanStatus.menungguReviewKspi:
        return 'Menunggu Review KSPI';
      case PengaduanStatus.menungguPersetujuanDirektur:
        return 'Menunggu Persetujuan Direktur';
      case PengaduanStatus.ditolakDirektur:
        return 'Ditolak Direktur';
      case PengaduanStatus.revisiInvestigasi:
        return 'Revisi Investigasi';
      case PengaduanStatus.peninjauanKembali:
        return 'Peninjauan Kembali';
      case PengaduanStatus.tindakLanjut:
        return 'Tindak Lanjut';
      case PengaduanStatus.selesai:
        return 'Selesai';
    }
  }

  Color get color {
    switch (this) {
      case PengaduanStatus.draft:
        return const Color(0xFF95A5A6);
      case PengaduanStatus.menungguVerifikasiKadiv:
        return const Color(0xFF95A5A6);
      case PengaduanStatus.diverifikasiKadiv:
        return const Color(0xFF2E86AB);
      case PengaduanStatus.reviewKspi:
        return const Color(0xFF2E86AB);
      case PengaduanStatus.menungguInvestigasi:
        return const Color(0xFFE67E22);
      case PengaduanStatus.investigasiBerjalan:
        return const Color(0xFFE67E22);
      case PengaduanStatus.hasilInvestigasi:
        return const Color(0xFF8E44AD);
      case PengaduanStatus.menungguReviewKspi:
        return const Color(0xFF8E44AD);
      case PengaduanStatus.menungguPersetujuanDirektur:
        return const Color(0xFF6C3483);
      case PengaduanStatus.ditolakDirektur:
        return const Color(0xFFE74C3C);
      case PengaduanStatus.revisiInvestigasi:
        return const Color(0xFFE74C3C);
      case PengaduanStatus.peninjauanKembali:
        return const Color(0xFFD35400);
      case PengaduanStatus.tindakLanjut:
        return const Color(0xFF27AE60);
      case PengaduanStatus.selesai:
        return const Color(0xFF1E8449);
    }
  }

  IconData get icon {
    switch (this) {
      case PengaduanStatus.draft:
        return Icons.edit_note_rounded;
      case PengaduanStatus.menungguVerifikasiKadiv:
        return Icons.hourglass_top_rounded;
      case PengaduanStatus.diverifikasiKadiv:
        return Icons.fact_check_rounded;
      case PengaduanStatus.reviewKspi:
        return Icons.rate_review_rounded;
      case PengaduanStatus.menungguInvestigasi:
        return Icons.pending_actions_rounded;
      case PengaduanStatus.investigasiBerjalan:
        return Icons.search_rounded;
      case PengaduanStatus.hasilInvestigasi:
        return Icons.description_rounded;
      case PengaduanStatus.menungguReviewKspi:
        return Icons.reviews_rounded;
      case PengaduanStatus.menungguPersetujuanDirektur:
        return Icons.gavel_rounded;
      case PengaduanStatus.ditolakDirektur:
        return Icons.cancel_rounded;
      case PengaduanStatus.revisiInvestigasi:
        return Icons.replay_rounded;
      case PengaduanStatus.peninjauanKembali:
        return Icons.history_toggle_off_rounded;
      case PengaduanStatus.tindakLanjut:
        return Icons.flag_rounded;
      case PengaduanStatus.selesai:
        return Icons.task_alt_rounded;
    }
  }

  /// Urutan tahapan pada alur normal (dipakai untuk timeline linear).
  /// Status cabang (ditolak/revisi/peninjauan) tetap punya nilai supaya
  /// tetap bisa ditampilkan tapi tidak dianggap "maju" secara linear.
  int get stepOrder {
    switch (this) {
      case PengaduanStatus.draft:
        return 0;
      case PengaduanStatus.menungguVerifikasiKadiv:
        return 1;
      case PengaduanStatus.diverifikasiKadiv:
        return 2;
      case PengaduanStatus.reviewKspi:
        return 3;
      case PengaduanStatus.menungguInvestigasi:
        return 4;
      case PengaduanStatus.investigasiBerjalan:
        return 5;
      case PengaduanStatus.hasilInvestigasi:
        return 6;
      case PengaduanStatus.menungguReviewKspi:
        return 7;
      case PengaduanStatus.menungguPersetujuanDirektur:
        return 8;
      case PengaduanStatus.tindakLanjut:
        return 9;
      case PengaduanStatus.selesai:
        return 10;
      case PengaduanStatus.ditolakDirektur:
        return -1;
      case PengaduanStatus.revisiInvestigasi:
        return -2;
      case PengaduanStatus.peninjauanKembali:
        return -3;
    }
  }

  /// Apakah pengaduan pada status ini dianggap sudah tuntas (tidak bisa
  /// diproses lebih lanjut oleh siapapun).
  bool get isFinal => this == PengaduanStatus.selesai;
}

/// Kategori divisi hasil penentuan Kadiv (Tahap 4, langkah 3).
enum KategoriDivisi { devAdmin, devTeknis }

extension KategoriDivisiX on KategoriDivisi {
  String get label {
    switch (this) {
      case KategoriDivisi.devAdmin:
        return 'Dev Admin';
      case KategoriDivisi.devTeknis:
        return 'Dev Teknis';
    }
  }
}

/// Pilihan eksekutor yang ditentukan KSPI (atau Direktur untuk tindak
/// lanjut) — sesuai flowchart node "kspi pilih eksekutor".
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

/// Keputusan akhir Direktur (Tahap 4 — "Keputusan Direktur").
enum KeputusanDirektur { setuju, tolak, peninjauanKembali, tindakLanjut }

/// Satu baris riwayat perubahan status pada sebuah pengaduan (Tahap 6).
/// Menyimpan: tanggal+jam, user, role, aksi, status lama, status baru,
/// catatan.
class StatusHistoryEntry {
  final PengaduanStatus status; // status baru setelah aksi ini
  final PengaduanStatus? statusLama; // status sebelum aksi ini (null = awal)
  final DateTime tanggal; // sudah termasuk jam (DateTime.now())
  final String? keterangan; // catatan aksi
  final String oleh; // nama user yang melakukan aksi ("Sistem" utk otomatis)
  final UserRole? role; // role user yang melakukan aksi
  final String aksi; // deskripsi singkat aksi, mis. "Verifikasi Kadiv"

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

/// Model utama satu pengaduan pegawai — mengikuti seluruh field yang
/// dibutuhkan sepanjang alur flowchart (kategori divisi, eksekutor,
/// petugas investigasi, hasil investigasi, surat rekomendasi, dst).
class Pengaduan {
  final String nomorPengaduan;
  final String kategori; // kategori bebas isian pegawai, mis. "Fasilitas Kerja"
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
  KategoriDivisi? kategoriDivisi; // ditentukan Kadiv: Dev Admin / Dev Teknis
  String? catatanVerifikasiKadiv;

  // --- Tahap KSPI (review awal & pemilihan eksekutor) ---
  String? catatanReviewKspi;
  Eksekutor? eksekutor; // Kadiv atau TPDPK, dipilih KSPI (atau Direktur)
  String? petugasInvestigasi; // dipilih KSPI (jika eksekutor kadiv) atau TPDPK

  // --- Tahap Investigasi (TPDPK) ---
  String? hasilInvestigasi;
  String? suratRekomendasi;
  DateTime? tanggalHasilInvestigasi;

  // --- Tahap Review Hasil oleh KSPI ---
  String? catatanReviewHasilKspi;
  bool? hasilSesuaiMenurutKspi; // true = sesuai -> lanjut Direktur

  // --- Tahap Direktur ---
  KeputusanDirektur? keputusanDirektur;
  String? alasanPenolakanDirektur;
  String? catatanPeninjauanKembali;
  String? tindakLanjutDiminta;
  Eksekutor? eksekutorTindakLanjut;
  String? keteranganSelesai;

  // Alias lama dipertahankan agar UI Pegawai yang sudah ada tetap kompatibel.
  String? get alasanPenolakan => alasanPenolakanDirektur;
  set alasanPenolakan(String? v) => alasanPenolakanDirektur = v;

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
    this.kategoriDivisi,
    this.catatanVerifikasiKadiv,
    this.catatanReviewKspi,
    this.eksekutor,
    this.petugasInvestigasi,
    this.hasilInvestigasi,
    this.suratRekomendasi,
    this.tanggalHasilInvestigasi,
    this.catatanReviewHasilKspi,
    this.hasilSesuaiMenurutKspi,
    this.keputusanDirektur,
    this.alasanPenolakanDirektur,
    this.catatanPeninjauanKembali,
    this.tindakLanjutDiminta,
    this.eksekutorTindakLanjut,
    this.keteranganSelesai,
  })  : fotoBukti = fotoBukti ?? [],
        dokumenPendukung = dokumenPendukung ?? [],
        riwayatStatus = riwayatStatus ?? [];

  /// Keterangan/catatan terakhir dari riwayat status (dipakai halaman detail
  /// Pegawai untuk menampilkan info ringkas terbaru).
  String? get keteranganTerakhir {
    for (final h in riwayatStatus.reversed) {
      if (h.keterangan != null && h.keterangan!.trim().isNotEmpty) {
        return h.keterangan;
      }
    }
    return null;
  }

  /// Mencatat satu baris riwayat sekaligus memindahkan status pengaduan.
  /// Dipakai oleh seluruh method aksi role di bawah supaya Tahap 6
  /// (riwayat) selalu konsisten dengan Tahap 4 (alur) & Tahap 7 (notifikasi
  /// - lihat [NotificationCenter]).
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

  // ===========================================================
  // METHOD AKSI PER ROLE — satu-satunya cara mengubah status agar
  // riwayat (Tahap 6) & notifikasi (Tahap 7) selalu tercatat benar.
  // ===========================================================

  /// KADIV — Tahap 4 langkah 3-4: menentukan kategori & verifikasi awal,
  /// lalu meneruskan ke KSPI.
  void verifikasiKadiv({
    required String oleh,
    required KategoriDivisi kategoriDivisiBaru,
    String? catatan,
  }) {
    kategoriDivisi = kategoriDivisiBaru;
    catatanVerifikasiKadiv = catatan;
    _ubahStatus(
      statusBaru: PengaduanStatus.diverifikasiKadiv,
      oleh: oleh,
      role: UserRole.kadivKategori,
      aksi: 'Verifikasi & kategorisasi (${kategoriDivisiBaru.label})',
      catatan: catatan,
    );
    // Otomatis diteruskan ke KSPI (Tahap 4 langkah 5).
    _ubahStatus(
      statusBaru: PengaduanStatus.reviewKspi,
      oleh: 'Sistem',
      role: UserRole.kadivKategori,
      aksi: 'Diteruskan otomatis ke KSPI',
    );
  }

  /// KSPI — Tahap 4 langkah 6-8: review, lalu pilih eksekutor & petugas
  /// investigasi (jika eksekutor = Kadiv, KSPI langsung memilih petugas).
  void reviewDanPilihEksekutor({
    required String oleh,
    required Eksekutor eksekutorBaru,
    String? petugas,
    String? catatan,
  }) {
    eksekutor = eksekutorBaru;
    catatanReviewKspi = catatan;
    if (eksekutorBaru == Eksekutor.kadiv) {
      petugasInvestigasi = petugas;
      _ubahStatus(
        statusBaru: PengaduanStatus.investigasiBerjalan,
        oleh: oleh,
        role: UserRole.kspi,
        aksi:
            'Review KSPI, eksekutor: Kadiv, petugas investigasi: ${petugas ?? '-'}',
        catatan: catatan,
      );
    } else {
      // Eksekutor TPDPK -> TPDPK yang akan memilih petugasnya sendiri.
      _ubahStatus(
        statusBaru: PengaduanStatus.menungguInvestigasi,
        oleh: oleh,
        role: UserRole.kspi,
        aksi: 'Review KSPI, eksekutor: TPDPK',
        catatan: catatan,
      );
    }
  }

  /// TPDPK — dipanggil saat eksekutor = TPDPK dan TPDPK memilih petugas
  /// investigasinya sendiri (Tahap 4 langkah 8, cabang TPDPK).
  void tpdpkPilihPetugas({
    required String oleh,
    required String petugas,
  }) {
    petugasInvestigasi = petugas;
    _ubahStatus(
      statusBaru: PengaduanStatus.investigasiBerjalan,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Menetapkan petugas investigasi: $petugas',
    );
  }

  /// TPDPK — Tahap 4 langkah 9: membuat hasil investigasi + surat
  /// rekomendasi, lalu mengirim ke KSPI.
  void kirimHasilInvestigasi({
    required String oleh,
    required String hasil,
    required String rekomendasi,
  }) {
    hasilInvestigasi = hasil;
    suratRekomendasi = rekomendasi;
    tanggalHasilInvestigasi = DateTime.now();
    _ubahStatus(
      statusBaru: PengaduanStatus.hasilInvestigasi,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Mengirim hasil investigasi & surat rekomendasi',
    );
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguReviewKspi,
      oleh: 'Sistem',
      role: UserRole.tpdpk,
      aksi: 'Diteruskan otomatis ke KSPI untuk direview',
    );
  }

  /// KSPI — Tahap 4 langkah 11: review hasil investigasi. Jika belum
  /// sesuai -> dikembalikan untuk revisi (ke TPDPK). Jika sesuai -> dikirim
  /// ke Direktur.
  void reviewHasilInvestigasi({
    required String oleh,
    required bool sesuai,
    String? catatan,
  }) {
    hasilSesuaiMenurutKspi = sesuai;
    catatanReviewHasilKspi = catatan;
    if (sesuai) {
      _ubahStatus(
        statusBaru: PengaduanStatus.menungguPersetujuanDirektur,
        oleh: oleh,
        role: UserRole.kspi,
        aksi: 'Hasil investigasi disetujui, dikirim ke Direktur',
        catatan: catatan,
      );
    } else {
      _ubahStatus(
        statusBaru: PengaduanStatus.revisiInvestigasi,
        oleh: oleh,
        role: UserRole.kspi,
        aksi: 'Hasil investigasi dikembalikan untuk revisi',
        catatan: catatan,
      );
    }
  }

  /// TPDPK — mengirim ulang hasil investigasi setelah revisi diminta KSPI.
  void kirimRevisiInvestigasi({
    required String oleh,
    required String hasil,
    required String rekomendasi,
  }) {
    hasilInvestigasi = hasil;
    suratRekomendasi = rekomendasi;
    tanggalHasilInvestigasi = DateTime.now();
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguReviewKspi,
      oleh: oleh,
      role: UserRole.tpdpk,
      aksi: 'Mengirim ulang hasil investigasi (revisi) ke KSPI',
    );
  }

  /// DIREKTUR — Tahap 4 "Keputusan Direktur": setuju, tolak, peninjauan
  /// kembali, atau tindak lanjut.
  void keputusanDirekturAction({
    required String oleh,
    required KeputusanDirektur keputusan,
    String? catatan,
  }) {
    keputusanDirektur = keputusan;
    switch (keputusan) {
      case KeputusanDirektur.setuju:
        keteranganSelesai = catatan ?? 'Disetujui oleh Direktur yah.';
        _ubahStatus(
          statusBaru: PengaduanStatus.selesai,
          oleh: oleh,
          role: UserRole.direktur,
          aksi: 'Menyetujui pengaduan',
          catatan: catatan,
        );
        break;
      case KeputusanDirektur.tolak:
        alasanPenolakanDirektur = catatan;
        _ubahStatus(
          statusBaru: PengaduanStatus.ditolakDirektur,
          oleh: oleh,
          role: UserRole.direktur,
          aksi: 'Menolak & mengirim pesan penolakan ke KSPI',
          catatan: catatan,
        );
        break;
      case KeputusanDirektur.peninjauanKembali:
        catatanPeninjauanKembali = catatan;
        _ubahStatus(
          statusBaru: PengaduanStatus.peninjauanKembali,
          oleh: oleh,
          role: UserRole.direktur,
          aksi: 'Meminta peninjauan kembali (dikembalikan ke KSPI)',
          catatan: catatan,
        );
        break;
      case KeputusanDirektur.tindakLanjut:
        tindakLanjutDiminta = catatan;
        _ubahStatus(
          statusBaru: PengaduanStatus.tindakLanjut,
          oleh: oleh,
          role: UserRole.direktur,
          aksi: 'Menentukan tindak lanjut, menunggu eksekutor',
          catatan: catatan,
        );
        break;
    }
  }

  /// DIREKTUR — memilih eksekutor tindak lanjut (Tahap 4, cabang "tindak
  /// lanjut").
  void pilihEksekutorTindakLanjut({
    required String oleh,
    required Eksekutor eksekutorBaru,
  }) {
    eksekutorTindakLanjut = eksekutorBaru;
    _ubahStatus(
      statusBaru: PengaduanStatus.tindakLanjut,
      oleh: oleh,
      role: UserRole.direktur,
      aksi: 'Memilih eksekutor tindak lanjut: ${eksekutorBaru.label}',
    );
  }

  /// Eksekutor (Kadiv/TPDPK) menandai tindak lanjut selesai dijalankan.
  void selesaikanTindakLanjut({
    required String oleh,
    required UserRole role,
    String? catatan,
  }) {
    keteranganSelesai = catatan ?? 'Tindak lanjut telah dijalankan.';
    _ubahStatus(
      statusBaru: PengaduanStatus.selesai,
      oleh: oleh,
      role: role,
      aksi: 'Menyelesaikan tindak lanjut',
      catatan: catatan,
    );
  }

  /// KSPI — merevisi lalu mengirim ulang ke Direktur setelah pesan
  /// penolakan diterima (Tahap 4, cabang "ditolak").
  void kirimUlangSetelahRevisiKspi({
    required String oleh,
    required String catatanRevisi,
  }) {
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguPersetujuanDirektur,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Revisi selesai, mengirim ulang ke Direktur',
      catatan: catatanRevisi,
    );
  }

  /// KSPI — menindaklanjuti permintaan peninjauan kembali dari Direktur
  /// dengan mengirim ulang untuk investigasi ulang (Tahap 4, cabang
  /// "peninjauan kembali").
  void kirimUntukInvestigasiUlang({
    required String oleh,
    String? catatan,
  }) {
    _ubahStatus(
      statusBaru: PengaduanStatus.menungguInvestigasi,
      oleh: oleh,
      role: UserRole.kspi,
      aksi: 'Mengirim ulang untuk investigasi ulang',
      catatan: catatan,
    );
  }
}

/// Format tanggal Indonesia: "Senin, 13 Juli 2026".
String formatTanggalIndonesia(DateTime date) {
  const hari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    "Jum'at",
    'Sabtu',
    'Minggu',
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
  final namaHari = hari[date.weekday - 1];
  final namaBulan = bulan[date.month - 1];
  return '$namaHari, ${date.day} $namaBulan ${date.year}';
}

/// Format tanggal singkat: "13 Jul 2026, 09:40".
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

/// "Penyimpanan" sederhana in-memory untuk data pengaduan (belum terhubung
/// ke API/database sungguhan). Dipakai bersama oleh seluruh dashboard role
/// (Pegawai, Kadiv, KSPI, TPDPK, Direktur).
class PengaduanRepository {
  PengaduanRepository._();

  static final List<Pengaduan> _data = _seedDummyData();

  static List<Pengaduan> get semua => List.unmodifiable(_data);

  static void tambah(Pengaduan pengaduan) {
    _data.insert(0, pengaduan);
    NotificationCenter.tambah(
      untukRole: UserRole.kadivKategori,
      judul: 'Pengaduan baru masuk',
      pesan: '${pengaduan.namaPegawai} membuat pengaduan baru '
          '(${pengaduan.nomorPengaduan}).',
    );
  }

  /// Daftar pengaduan yang perlu ditindaklanjuti oleh [role] tertentu,
  /// dipakai masing-masing dashboard untuk menampilkan "kotak masuk".
  static List<Pengaduan> untukRole(UserRole role) {
    switch (role) {
      case UserRole.pegawai:
        return List.unmodifiable(_data);
      case UserRole.kadivKategori:
        return _data
            .where((p) =>
                p.status == PengaduanStatus.menungguVerifikasiKadiv ||
                (p.status == PengaduanStatus.tindakLanjut &&
                    p.eksekutorTindakLanjut == Eksekutor.kadiv))
            .toList();
      case UserRole.kspi:
        return _data
            .where((p) =>
                p.status == PengaduanStatus.reviewKspi ||
                p.status == PengaduanStatus.menungguReviewKspi ||
                p.status == PengaduanStatus.ditolakDirektur ||
                p.status == PengaduanStatus.peninjauanKembali)
            .toList();
      case UserRole.tpdpk:
        return _data
            .where((p) =>
                p.status == PengaduanStatus.menungguInvestigasi ||
                p.status == PengaduanStatus.investigasiBerjalan ||
                p.status == PengaduanStatus.revisiInvestigasi ||
                (p.status == PengaduanStatus.tindakLanjut &&
                    p.eksekutorTindakLanjut == Eksekutor.tpdpk))
            .toList();
      case UserRole.direktur:
        return _data
            .where((p) =>
                p.status == PengaduanStatus.menungguPersetujuanDirektur)
            .toList();
    }
  }

  static String generateNomorPengaduan() {
    final now = DateTime.now();
    final urut = (_data.length + 1).toString().padLeft(3, '0');
    return 'PGD-${now.year}${now.month.toString().padLeft(2, '0')}-$urut';
  }

  static List<Pengaduan> _seedDummyData() {
    final now = DateTime.now();

    Pengaduan p1 = Pengaduan(
      nomorPengaduan: 'PGD-${now.year}06-014',
      kategori: 'Fasilitas Kerja',
      judul: 'AC ruangan produksi rusak sejak 2 minggu',
      deskripsi:
          'AC di ruang kontrol produksi Cabang Indramayu tidak dingin sejak dua minggu terakhir sehingga mengganggu kenyamanan kerja shift siang.',
      tanggalPengaduan: now.subtract(const Duration(days: 32)),
      namaPegawai: 'Budi Santoso',
      nik: '3000000003',
      cabang: 'Cabang Indramayu',
      golongan: 'B.3 / Pelaksana',
      anonim: false,
      fotoBukti: const ['foto_ac_rusak_1.jpg'],
      status: PengaduanStatus.menungguVerifikasiKadiv,
      riwayatStatus: [
        StatusHistoryEntry(
          status: PengaduanStatus.menungguVerifikasiKadiv,
          tanggal: now.subtract(const Duration(days: 32)),
          oleh: 'Sistem',
          aksi: 'Pengaduan dibuat',
        ),
      ],
    );
    p1
      ..kategoriDivisi = KategoriDivisi.devTeknis
      ..verifikasiKadiv(
        oleh: 'Siti Rahmawati',
        kategoriDivisiBaru: KategoriDivisi.devTeknis,
        catatan: 'Valid, terkait fasilitas teknis. Diteruskan ke KSPI.',
      )
      ..reviewDanPilihEksekutor(
        oleh: 'Ahmad Fauzi',
        eksekutorBaru: Eksekutor.tpdpk,
        catatan: 'Diteruskan ke TPDPK untuk investigasi lapangan.',
      )
      ..tpdpkPilihPetugas(oleh: 'Dedi Kurniawan', petugas: 'Rudi Hartono')
      ..kirimHasilInvestigasi(
        oleh: 'Dedi Kurniawan',
        hasil:
            'AC rusak karena kompresor bocor, sudah diganti oleh tim maintenance pada 20 Juni.',
        rekomendasi:
            'Direkomendasikan penjadwalan preventive maintenance AC ruang produksi setiap 3 bulan.',
      )
      ..reviewHasilInvestigasi(
        oleh: 'Ahmad Fauzi',
        sesuai: true,
        catatan: 'Hasil investigasi lengkap & sesuai, diteruskan ke Direktur.',
      )
      ..keputusanDirekturAction(
        oleh: 'H. Dedi Supriadi',
        keputusan: KeputusanDirektur.setuju,
        catatan:
            'AC sudah diperbaiki oleh tim maintenance pada 20 Juni. Kondisi dinyatakan normal kembali.',
      );

    Pengaduan p2 = Pengaduan(
      nomorPengaduan: 'PGD-${now.year}07-021',
      kategori: 'Rekan Kerja',
      judul: 'Konflik pembagian jadwal shift',
      deskripsi:
          'Terjadi kesalahpahaman terkait pembagian jadwal shift antar rekan kerja di unit distribusi yang berulang setiap minggu.',
      tanggalPengaduan: now.subtract(const Duration(days: 14)),
      namaPegawai: 'Budi Santoso',
      nik: '3000000003',
      cabang: 'Cabang Indramayu',
      golongan: 'B.3 / Pelaksana',
      anonim: false,
      status: PengaduanStatus.menungguVerifikasiKadiv,
      riwayatStatus: [
        StatusHistoryEntry(
          status: PengaduanStatus.menungguVerifikasiKadiv,
          tanggal: now.subtract(const Duration(days: 14)),
          oleh: 'Sistem',
          aksi: 'Pengaduan dibuat',
        ),
      ],
    );
    p2
      ..verifikasiKadiv(
        oleh: 'Siti Rahmawati',
        kategoriDivisiBaru: KategoriDivisi.devAdmin,
        catatan: 'Pengaduan diverifikasi, dijadwalkan investigasi.',
      )
      ..reviewDanPilihEksekutor(
        oleh: 'Ahmad Fauzi',
        eksekutorBaru: Eksekutor.kadiv,
        petugas: 'Wawan Setiawan',
        catatan: 'Eksekutor: Kadiv, petugas investigasi ditugaskan.',
      );

    Pengaduan p3 = Pengaduan(
      nomorPengaduan: 'PGD-${now.year}07-025',
      kategori: 'Kebijakan Perusahaan',
      judul: 'Usulan revisi kebijakan lembur',
      deskripsi:
          'Kebijakan pengajuan lembur dirasa kurang jelas alurnya sehingga sering terjadi keterlambatan pencairan uang lembur.',
      tanggalPengaduan: now.subtract(const Duration(days: 6)),
      namaPegawai: 'Budi Santoso',
      nik: '3000000003',
      cabang: 'Cabang Indramayu',
      golongan: 'B.3 / Pelaksana',
      anonim: false,
      status: PengaduanStatus.menungguVerifikasiKadiv,
      riwayatStatus: [
        StatusHistoryEntry(
          status: PengaduanStatus.menungguVerifikasiKadiv,
          tanggal: now.subtract(const Duration(days: 6)),
          oleh: 'Sistem',
          aksi: 'Pengaduan dibuat',
        ),
      ],
    );
    p3
      ..verifikasiKadiv(
        oleh: 'Siti Rahmawati',
        kategoriDivisiBaru: KategoriDivisi.devAdmin,
        catatan: 'Diteruskan ke KSPI untuk direview.',
      )
      ..reviewDanPilihEksekutor(
        oleh: 'Ahmad Fauzi',
        eksekutorBaru: Eksekutor.tpdpk,
        catatan: 'Diteruskan ke TPDPK.',
      )
      ..tpdpkPilihPetugas(oleh: 'Dedi Kurniawan', petugas: 'Rudi Hartono')
      ..kirimHasilInvestigasi(
        oleh: 'Dedi Kurniawan',
        hasil:
            'Bukan pelanggaran disiplin, melainkan usulan perbaikan kebijakan administratif.',
        rekomendasi:
            'Direkomendasikan disampaikan sebagai usulan kebijakan ke HRD, bukan pengaduan pelanggaran.',
      )
      ..reviewHasilInvestigasi(
        oleh: 'Ahmad Fauzi',
        sesuai: true,
        catatan: 'Diteruskan ke Direktur untuk keputusan akhir.',
      )
      ..keputusanDirekturAction(
        oleh: 'H. Dedi Supriadi',
        keputusan: KeputusanDirektur.tolak,
        catatan:
            'Bukan termasuk kategori pengaduan pelanggaran, disarankan disampaikan melalui usulan kebijakan ke HRD.',
      );

    Pengaduan p4 = Pengaduan(
      nomorPengaduan: 'PGD-${now.year}07-031',
      kategori: 'Atasan / Pimpinan',
      judul: 'Instruksi kerja tidak sesuai SOP',
      deskripsi:
          'Ada instruksi kerja dari atasan langsung yang dinilai tidak sesuai dengan SOP keselamatan kerja di area produksi.',
      tanggalPengaduan: now.subtract(const Duration(days: 2)),
      namaPegawai: 'Budi Santoso',
      nik: '3000000003',
      cabang: 'Cabang Indramayu',
      golongan: 'B.3 / Pelaksana',
      anonim: false,
      status: PengaduanStatus.menungguVerifikasiKadiv,
      riwayatStatus: [
        StatusHistoryEntry(
          status: PengaduanStatus.menungguVerifikasiKadiv,
          tanggal: now.subtract(const Duration(days: 2)),
          oleh: 'Sistem',
          aksi: 'Pengaduan dibuat',
        ),
      ],
    );
    p4.verifikasiKadiv(
      oleh: 'Siti Rahmawati',
      kategoriDivisiBaru: KategoriDivisi.devTeknis,
      catatan: 'Pengaduan diverifikasi dan valid untuk ditindaklanjuti.',
    );

    Pengaduan p5 = Pengaduan(
      nomorPengaduan: 'PGD-${now.year}07-033',
      kategori: 'Lingkungan Kerja',
      judul: 'Area parkir kurang penerangan',
      deskripsi:
          'Lampu di area parkir belakang kantor Cabang Indramayu mati sejak beberapa hari lalu sehingga kurang aman saat pulang malam.',
      tanggalPengaduan: now.subtract(const Duration(hours: 10)),
      namaPegawai: 'Budi Santoso',
      nik: '3000000003',
      cabang: 'Cabang Indramayu',
      golongan: 'B.3 / Pelaksana',
      anonim: false,
      fotoBukti: const ['foto_parkir_gelap_1.jpg', 'foto_parkir_gelap_2.jpg'],
      status: PengaduanStatus.menungguVerifikasiKadiv,
      riwayatStatus: [
        StatusHistoryEntry(
          status: PengaduanStatus.menungguVerifikasiKadiv,
          tanggal: now.subtract(const Duration(hours: 10)),
          oleh: 'Sistem',
          aksi: 'Pengaduan dibuat',
        ),
      ],
    );

    return [p1, p2, p3, p4, p5];
  }
}

/// =============================================================
/// Tahap 7 — Notifikasi. Pusat notifikasi in-memory sederhana,
/// terpisah per role sehingga tiap role hanya melihat notifikasi yang
/// relevan dengan kewenangannya.
/// =============================================================
class AppNotification {
  final String judul;
  final String pesan;
  final DateTime waktu;
  bool dibaca;

  AppNotification({
    required this.judul,
    required this.pesan,
    required this.waktu,
    this.dibaca = false,
  });
}

class NotificationCenter {
  NotificationCenter._();

  static final Map<UserRole, List<AppNotification>> _data = {
    for (final r in UserRole.values) r: <AppNotification>[],
  };

  static void tambah({
    required UserRole untukRole,
    required String judul,
    required String pesan,
  }) {
    _data[untukRole]!.insert(
      0,
      AppNotification(judul: judul, pesan: pesan, waktu: DateTime.now()),
    );
  }

  static List<AppNotification> untukRole(UserRole role) =>
      List.unmodifiable(_data[role] ?? const []);

  static int belumDibaca(UserRole role) =>
      (_data[role] ?? const []).where((n) => !n.dibaca).length;

  static void tandaiSemuaDibaca(UserRole role) {
    for (final n in _data[role] ?? const []) {
      n.dibaca = true;
    }
  }
}