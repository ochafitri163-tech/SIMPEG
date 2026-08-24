/// Model data terstruktur untuk seluruh fitur kepegawaian SIMPEG Mobile.
library;

class PendidikanItem {
  final String jenjang;
  final String? jurusan;
  final String? namaSekolah;
  final String? kotaLulus;
  final String tahunLulus;
  final String? noIjazah;

  const PendidikanItem({
    required this.jenjang,
    this.jurusan,
    this.namaSekolah,
    this.kotaLulus,
    required this.tahunLulus,
    this.noIjazah,
  });
}

/// Rincian slip "Tunjangan Pendidikan & Potongan", mengikuti persis format
/// cetak resmi PERUMDAM Tirta Darma Ayu. Dipakai tombol "Cek Detail" di
/// halaman Pendidikan untuk mengunduh PDF.
class PendidikanTunjanganDetail {
  // --- Kop & identitas pegawai ---
  final String perusahaan;
  final String bulanLabel; // mis. "JULI 2026"
  final String nik;
  final String nama;
  final String golongan;
  final String unitKerja;
  final String jabatan;

  // --- Kolom kiri: PENDAPATAN ---
  final int gapok;
  final int tunjanganIstri;
  final int tunjanganAnak;

  // --- Kolom kanan: POTONGAN (TRANDIST) ---
  final int potonganKoperasi;
  final int potonganKas;

  const PendidikanTunjanganDetail({
    this.perusahaan = 'PERUMDAM TIRTA DARMA AYU KAB. INDRAMAYU',
    required this.bulanLabel,
    required this.nik,
    required this.nama,
    required this.golongan,
    required this.unitKerja,
    required this.jabatan,
    this.gapok = 0,
    this.tunjanganIstri = 0,
    this.tunjanganAnak = 0,
    this.potonganKoperasi = 0,
    this.potonganKas = 0,
  });

  /// JUMLAH PENDAPATAN
  int get jumlahPendapatan => gapok + tunjanganIstri + tunjanganAnak;

  /// JUMLAH POTONGAN NON-INSENTIF
  int get jumlahPotonganNonInsentif => potonganKoperasi + potonganKas;

  /// JUMLAH INSENTIF DITERIMA
  int get jumlahInsentifDiterima =>
      jumlahPendapatan - jumlahPotonganNonInsentif;

  List<MapEntry<String, int>> get pendapatanLines => [
        MapEntry('Gaji pokok', gapok),
        MapEntry('Tunjangan istri', tunjanganIstri),
        MapEntry('Tunjangan anak', tunjanganAnak),
      ].where((e) => e.value > 0).toList();

  List<MapEntry<String, int>> get potonganLines => [
        MapEntry('Potongan koperasi', potonganKoperasi),
        MapEntry('Potongan kas', potonganKas),
      ].where((e) => e.value > 0).toList();
}

class KeluargaItem {
  final String nama;
  final String hubungan;
  final String tanggalLahir;
  final String pekerjaan;

  const KeluargaItem({
    required this.nama,
    required this.hubungan,
    required this.tanggalLahir,
    required this.pekerjaan,
  });
}

class GolonganItem {
  final String golongan;
  final String pangkat;
  final String tmt;
  final String noSk;

  const GolonganItem({
    required this.golongan,
    required this.pangkat,
    required this.tmt,
    required this.noSk,
  });
}

class JabatanItem {
  final String jabatan;
  final String unitKerja;
  final String tmt;
  final String noSk;

  const JabatanItem({
    required this.jabatan,
    required this.unitKerja,
    required this.tmt,
    required this.noSk,
  });
}

class PayrollItem {
  final String periode;
  final int gajiPokok;
  final int tunjanganKeluarga;
  final int tunjanganJabatan;
  final int potongan;
  final String status;
  // Rincian slip gaji lengkap (opsional). Kalau diisi, kartu "RINCIAN" di
  // layar dan PDF "Cek Detail" akan memakai data ini (persis slip resmi
  // perusahaan), bukan versi ringkas dari field di atas.
  final PayrollSlipDetail? slip;

  const PayrollItem({
    required this.periode,
    required this.gajiPokok,
    required this.tunjanganKeluarga,
    required this.tunjanganJabatan,
    required this.potongan,
    required this.status,
    this.slip,
  });

  int get gajiBersih =>
      gajiPokok + tunjanganKeluarga + tunjanganJabatan - potongan;
}

/// Rincian lengkap slip gaji, mengikuti persis format cetak resmi
/// "DAFTAR GAJI" PERUMDAM Tirta Darma Ayu (kolom Pendapatan & Potongan).
class PayrollSlipDetail {
  // --- Kop & identitas pegawai ---
  final String perusahaan;
  final String bulanLabel; // mis. "JUNI 2026"
  final String nik;
  final String nama;
  final String golongan;
  final String unitKerja;
  final String jabatan;

  // --- Kolom kiri: PENDAPATAN ---
  final int gapok;
  final int tunjanganIstri;
  final int tunjanganAnak;
  final int tunjanganJabatan;
  final int tunjanganPrestasi;
  final int tunjanganTransportasi;
  final int tunjanganPangan;
  final int tunjanganBpjsKesehatan;
  final int tunjanganPerumahan;
  final int tunjanganBpjsTenagaKerja;
  final int tunjanganPerusahaan;
  final int lembur;
  final int tunjanganPajak;
  final int tunjanganAirMinum;
  final int tunjanganKomunikasi;

  // --- Kolom kanan: POTONGAN (bagian dari pendapatan) ---
  final int potonganSanksiPerusahaan;
  final int potonganTrandistPmiLain;
  final int potonganDapenma;
  final int potonganBpjsTenagaKerja;
  final int potonganPerumahan;
  final int potonganTunjanganPerusahaan;
  final int potonganKorpri;
  final int potonganPajak;
  final int potonganBpjsKesehatan;

  // --- Kolom kanan: POTONGAN NON-PENDAPATAN ---
  final int potonganKoperasi;
  final int potonganDarmaWanita;
  final int potonganRekeningAirMinum;
  final int potonganKas;
  final int potonganBankBjb;
  final int potonganBankBjbs;
  final int potonganBankBtn;
  final int potonganBankBpr;
  final int potonganAsuransi;
  final int potonganZakatProfesi;

  const PayrollSlipDetail({
    this.perusahaan = 'PERUMDAM TIRTA DARMA AYU KAB. INDRAMAYU',
    required this.bulanLabel,
    required this.nik,
    required this.nama,
    required this.golongan,
    required this.unitKerja,
    required this.jabatan,
    this.gapok = 0,
    this.tunjanganIstri = 0,
    this.tunjanganAnak = 0,
    this.tunjanganJabatan = 0,
    this.tunjanganPrestasi = 0,
    this.tunjanganTransportasi = 0,
    this.tunjanganPangan = 0,
    this.tunjanganBpjsKesehatan = 0,
    this.tunjanganPerumahan = 0,
    this.tunjanganBpjsTenagaKerja = 0,
    this.tunjanganPerusahaan = 0,
    this.lembur = 0,
    this.tunjanganPajak = 0,
    this.tunjanganAirMinum = 0,
    this.tunjanganKomunikasi = 0,
    this.potonganSanksiPerusahaan = 0,
    this.potonganTrandistPmiLain = 0,
    this.potonganDapenma = 0,
    this.potonganBpjsTenagaKerja = 0,
    this.potonganPerumahan = 0,
    this.potonganTunjanganPerusahaan = 0,
    this.potonganKorpri = 0,
    this.potonganPajak = 0,
    this.potonganBpjsKesehatan = 0,
    this.potonganKoperasi = 0,
    this.potonganDarmaWanita = 0,
    this.potonganRekeningAirMinum = 0,
    this.potonganKas = 0,
    this.potonganBankBjb = 0,
    this.potonganBankBjbs = 0,
    this.potonganBankBtn = 0,
    this.potonganBankBpr = 0,
    this.potonganAsuransi = 0,
    this.potonganZakatProfesi = 0,
  });

  /// JUMLAH PENDAPATAN
  int get jumlahPendapatan =>
      gapok +
      tunjanganIstri +
      tunjanganAnak +
      tunjanganJabatan +
      tunjanganPrestasi +
      tunjanganTransportasi +
      tunjanganPangan +
      tunjanganBpjsKesehatan +
      tunjanganPerumahan +
      tunjanganBpjsTenagaKerja +
      tunjanganPerusahaan +
      lembur +
      tunjanganPajak +
      tunjanganAirMinum +
      tunjanganKomunikasi;

  /// JUMLAH POTONGAN PENDAPATAN
  int get jumlahPotonganPendapatan =>
      potonganSanksiPerusahaan +
      potonganTrandistPmiLain +
      potonganDapenma +
      potonganBpjsTenagaKerja +
      potonganPerumahan +
      potonganTunjanganPerusahaan +
      potonganKorpri +
      potonganPajak +
      potonganBpjsKesehatan;

  /// JUMLAH POTONGAN NON-PENDAPATAN
  int get jumlahPotonganNonPendapatan =>
      potonganKoperasi +
      potonganDarmaWanita +
      potonganRekeningAirMinum +
      potonganKas +
      potonganBankBjb +
      potonganBankBjbs +
      potonganBankBtn +
      potonganBankBpr +
      potonganAsuransi +
      potonganZakatProfesi;

  /// Total seluruh potongan (dipakai untuk baris "Jumlah Potongan" ringkas
  /// di kartu RINCIAN pada layar).
  int get totalPotongan =>
      jumlahPotonganPendapatan + jumlahPotonganNonPendapatan;

  /// JUMLAH PENDAPATAN DITERIMA
  int get jumlahDiterima =>
      jumlahPendapatan - jumlahPotonganPendapatan - jumlahPotonganNonPendapatan;

  /// Daftar baris pendapatan (label, nilai) yang nilainya > 0, dipakai untuk
  /// menyusun kartu "RINCIAN" di layar secara dinamis.
  List<MapEntry<String, int>> get pendapatanLines => [
        MapEntry('Gaji pokok', gapok),
        MapEntry('Tunjangan istri', tunjanganIstri),
        MapEntry('Tunjangan anak', tunjanganAnak),
        MapEntry('Tunjangan jabatan', tunjanganJabatan),
        MapEntry('Tunjangan prestasi', tunjanganPrestasi),
        MapEntry('Tunjangan transport', tunjanganTransportasi),
        MapEntry('Tunjangan pangan', tunjanganPangan),
        MapEntry('Tunjangan BPJS kesehatan', tunjanganBpjsKesehatan),
        MapEntry('Tunjangan perumahan', tunjanganPerumahan),
        MapEntry('Tunjangan BPJS tenaga kerja', tunjanganBpjsTenagaKerja),
        MapEntry('Tunjangan perusahaan', tunjanganPerusahaan),
        MapEntry('Lembur', lembur),
        MapEntry('Tunjangan pajak', tunjanganPajak),
        MapEntry('Tunjangan air minum', tunjanganAirMinum),
        MapEntry('Tunjangan komunikasi', tunjanganKomunikasi),
      ].where((e) => e.value > 0).toList();

  /// Daftar baris potongan (label, nilai) yang nilainya > 0, gabungan
  /// potongan-pendapatan & non-pendapatan, dipakai untuk kartu "RINCIAN".
  List<MapEntry<String, int>> get potonganLines => [
        MapEntry('Potongan sanksi perusahaan', potonganSanksiPerusahaan),
        MapEntry('Trandist potongan PMI / lain-lain', potonganTrandistPmiLain),
        MapEntry('Potongan Dapenma', potonganDapenma),
        MapEntry('Potongan BPJS tenaga kerja', potonganBpjsTenagaKerja),
        MapEntry('Potongan perumahan', potonganPerumahan),
        MapEntry('Potongan tunjangan perusahaan', potonganTunjanganPerusahaan),
        MapEntry('Potongan Kopri', potonganKorpri),
        MapEntry('Potongan pajak (PPh21)', potonganPajak),
        MapEntry('Potongan pajak kesehatan', potonganBpjsKesehatan),
        MapEntry('Potongan koperasi', potonganKoperasi),
        MapEntry('Potongan Dharma Wanita', potonganDarmaWanita),
        MapEntry('Potongan rekening air minum', potonganRekeningAirMinum),
        MapEntry('Potongan kas', potonganKas),
        MapEntry('Potongan Bank BJB', potonganBankBjb),
        MapEntry('Potongan Bank BJBS', potonganBankBjbs),
        MapEntry('Potongan Bank BTN', potonganBankBtn),
        MapEntry('Potongan Bank BPR', potonganBankBpr),
        MapEntry('Potongan asuransi', potonganAsuransi),
        MapEntry('Potongan zakat profesi', potonganZakatProfesi),
      ].where((e) => e.value > 0).toList();
}

class ThrItem {
  final String tahun;
  final int jumlah;
  final String tanggalCair;
  final String status;
  final int gajiPokok;
  final int tunjanganTetap;
  // Rincian slip THR lengkap (opsional). Kalau diisi, tombol "Cek Detail"
  // akan mencetak PDF selengkap slip resmi perusahaan (dua kolom
  // pendapatan & potongan), bukan versi ringkas.
  final ThrSlipDetail? slip;

  const ThrItem({
    required this.tahun,
    required this.jumlah,
    required this.tanggalCair,
    required this.status,
    this.gajiPokok = 0,
    this.tunjanganTetap = 0,
    this.slip,
  });
}

/// Rincian lengkap slip THR, mengikuti persis format cetak resmi
/// "DAFTAR THR" PERUMDAM Tirta Darma Ayu (kolom Pendapatan & Potongan).
class ThrSlipDetail {
  // --- Kop & identitas pegawai ---
  final String perusahaan;
  final String bulanLabel; // mis. "MARET 2026"
  final String nik;
  final String nama;
  final String golongan;
  final String unitKerja;
  final String jabatan;

  // --- Kolom kiri: PENDAPATAN ---
  final int gapok;
  final int tunjanganIstri;
  final int tunjanganAnak;
  final int tunjanganJabatan;
  final int tunjanganPrestasi;
  final int tunjanganTransportasi;
  final int tunjanganPangan;
  final int tunjanganBpjsKesehatan;
  final int tunjanganPerumahan;
  final int tunjanganBpjsTenagaKerja;
  final int tunjanganPerusahaan;
  final int lembur;
  final int tunjanganPajak;
  final int tunjanganAirMinum;
  final int tunjanganKomunikasi;

  // --- Kolom kanan: POTONGAN (bagian dari pendapatan) ---
  final int potonganTrandistPmiLain;
  final int potonganDapenma;
  final int potonganBpjsTenagaKerja;
  final int potonganPerumahan;
  final int potonganTunjanganPerusahaan;
  final int potonganKorpri;
  final int potonganPajak;
  final int potonganBpjsKesehatan;

  // --- Kolom kanan: POTONGAN NON-PENDAPATAN ---
  final int potonganKoperasi;
  final int potonganDarmaWanita;
  final int potonganRekeningAirMinum;
  final int potonganKas;
  final int potonganBankBjb;
  final int potonganBankBjbs;
  final int potonganBankBtn;
  final int potonganBankBpr;
  final int potonganAsuransi;
  final int potonganZakatRamadhan;

  const ThrSlipDetail({
    this.perusahaan = 'PERUMDAM TIRTA DARMA AYU KAB. INDRAMAYU',
    required this.bulanLabel,
    required this.nik,
    required this.nama,
    required this.golongan,
    required this.unitKerja,
    required this.jabatan,
    this.gapok = 0,
    this.tunjanganIstri = 0,
    this.tunjanganAnak = 0,
    this.tunjanganJabatan = 0,
    this.tunjanganPrestasi = 0,
    this.tunjanganTransportasi = 0,
    this.tunjanganPangan = 0,
    this.tunjanganBpjsKesehatan = 0,
    this.tunjanganPerumahan = 0,
    this.tunjanganBpjsTenagaKerja = 0,
    this.tunjanganPerusahaan = 0,
    this.lembur = 0,
    this.tunjanganPajak = 0,
    this.tunjanganAirMinum = 0,
    this.tunjanganKomunikasi = 0,
    this.potonganTrandistPmiLain = 0,
    this.potonganDapenma = 0,
    this.potonganBpjsTenagaKerja = 0,
    this.potonganPerumahan = 0,
    this.potonganTunjanganPerusahaan = 0,
    this.potonganKorpri = 0,
    this.potonganPajak = 0,
    this.potonganBpjsKesehatan = 0,
    this.potonganKoperasi = 0,
    this.potonganDarmaWanita = 0,
    this.potonganRekeningAirMinum = 0,
    this.potonganKas = 0,
    this.potonganBankBjb = 0,
    this.potonganBankBjbs = 0,
    this.potonganBankBtn = 0,
    this.potonganBankBpr = 0,
    this.potonganAsuransi = 0,
    this.potonganZakatRamadhan = 0,
  });

  /// JUMLAH PENDAPATAN
  int get jumlahPendapatan =>
      gapok +
      tunjanganIstri +
      tunjanganAnak +
      tunjanganJabatan +
      tunjanganPrestasi +
      tunjanganTransportasi +
      tunjanganPangan +
      tunjanganBpjsKesehatan +
      tunjanganPerumahan +
      tunjanganBpjsTenagaKerja +
      tunjanganPerusahaan +
      lembur +
      tunjanganPajak +
      tunjanganAirMinum +
      tunjanganKomunikasi;

  /// JUMLAH POTONGAN PENDAPATAN
  int get jumlahPotonganPendapatan =>
      potonganTrandistPmiLain +
      potonganDapenma +
      potonganBpjsTenagaKerja +
      potonganPerumahan +
      potonganTunjanganPerusahaan +
      potonganKorpri +
      potonganPajak +
      potonganBpjsKesehatan;

  /// JUMLAH POTONGAN NON-PENDAPATAN
  int get jumlahPotonganNonPendapatan =>
      potonganKoperasi +
      potonganDarmaWanita +
      potonganRekeningAirMinum +
      potonganKas +
      potonganBankBjb +
      potonganBankBjbs +
      potonganBankBtn +
      potonganBankBpr +
      potonganAsuransi +
      potonganZakatRamadhan;

  /// JUMLAH PENDAPATAN DITERIMA
  int get jumlahDiterima =>
      jumlahPendapatan - jumlahPotonganPendapatan - jumlahPotonganNonPendapatan;

  /// Total seluruh potongan (dipakai untuk baris "Jumlah Potongan" ringkas
  /// di kartu RINCIAN pada layar).
  int get totalPotongan =>
      jumlahPotonganPendapatan + jumlahPotonganNonPendapatan;

  /// Daftar baris pendapatan (label, nilai) yang nilainya > 0, dipakai untuk
  /// menyusun kartu "RINCIAN PERHITUNGAN" di layar secara dinamis.
  List<MapEntry<String, int>> get pendapatanLines => [
        MapEntry('Gaji pokok', gapok),
        MapEntry('Tunjangan istri', tunjanganIstri),
        MapEntry('Tunjangan anak', tunjanganAnak),
        MapEntry('Tunjangan jabatan', tunjanganJabatan),
        MapEntry('Tunjangan prestasi', tunjanganPrestasi),
        MapEntry('Tunjangan transport', tunjanganTransportasi),
        MapEntry('Tunjangan pangan', tunjanganPangan),
        MapEntry('Tunjangan BPJS kesehatan', tunjanganBpjsKesehatan),
        MapEntry('Tunjangan perumahan', tunjanganPerumahan),
        MapEntry('Tunjangan BPJS tenaga kerja', tunjanganBpjsTenagaKerja),
        MapEntry('Tunjangan perusahaan', tunjanganPerusahaan),
        MapEntry('Lembur', lembur),
        MapEntry('Tunjangan pajak', tunjanganPajak),
        MapEntry('Tunjangan air minum', tunjanganAirMinum),
        MapEntry('Tunjangan komunikasi', tunjanganKomunikasi),
      ].where((e) => e.value > 0).toList();

  /// Daftar baris potongan (label, nilai) yang nilainya > 0, gabungan
  /// potongan-pendapatan & non-pendapatan, dipakai untuk kartu "RINCIAN".
  List<MapEntry<String, int>> get potonganLines => [
        MapEntry('Trandist potongan PMI / lain-lain', potonganTrandistPmiLain),
        MapEntry('Potongan Dapenma', potonganDapenma),
        MapEntry('Potongan BPJS tenaga kerja', potonganBpjsTenagaKerja),
        MapEntry('Potongan perumahan', potonganPerumahan),
        MapEntry('Potongan tunjangan perusahaan', potonganTunjanganPerusahaan),
        MapEntry('Potongan Kopri', potonganKorpri),
        MapEntry('Potongan pajak (PPh21)', potonganPajak),
        MapEntry('Potongan pajak kesehatan', potonganBpjsKesehatan),
        MapEntry('Potongan koperasi', potonganKoperasi),
        MapEntry('Potongan Dharma Wanita', potonganDarmaWanita),
        MapEntry('Potongan rekening air minum', potonganRekeningAirMinum),
        MapEntry('Potongan kas', potonganKas),
        MapEntry('Potongan Bank BJB', potonganBankBjb),
        MapEntry('Potongan Bank BJBS', potonganBankBjbs),
        MapEntry('Potongan Bank BTN', potonganBankBtn),
        MapEntry('Potongan Bank BPR', potonganBankBpr),
        MapEntry('Potongan asuransi', potonganAsuransi),
        MapEntry('Potongan zakat Ramadhan', potonganZakatRamadhan),
      ].where((e) => e.value > 0).toList();
}

class SanksiItem {
  final String jenisSanksi;
  final String tanggal;
  final String keterangan;
  final String tingkat; // Ringan / Sedang / Berat

  const SanksiItem({
    required this.jenisSanksi,
    required this.tanggal,
    required this.keterangan,
    required this.tingkat,
  });
}

class PengaduanItem {
  final String namaPelapor;
  final String tanggal;
  final String kategori;
  final String isi;
  final String status; // Baru / Diproses / Selesai

  const PengaduanItem({
    required this.namaPelapor,
    required this.tanggal,
    required this.kategori,
    required this.isi,
    required this.status,
  });
}

class LemburItem {
  final String bulan;
  final int jamLembur;
  final int uangLembur;

  const LemburItem({
    required this.bulan,
    required this.jamLembur,
    required this.uangLembur,
  });
}

class Gaji13Item {
  final String tahun;
  final int jumlah;
  final String tanggalCair;
  final String status;

  const Gaji13Item({
    required this.tahun,
    required this.jumlah,
    required this.tanggalCair,
    required this.status,
  });
}

class InsentifItem {
  final String judul;
  final String periode;
  final int jumlah;
  // Rincian slip Insentif lengkap (opsional). Kalau diisi, tombol
  // "Cek Detail" akan mencetak PDF selengkap slip resmi perusahaan (dua
  // kolom Insentif & Potongan), bukan versi ringkas.
  final InsentifSlipDetail? slip;

  const InsentifItem({
    required this.judul,
    required this.periode,
    required this.jumlah,
    this.slip,
  });
}

/// Rincian lengkap slip Insentif, mengikuti persis format cetak resmi
/// "DAFTAR INSENTIF & POTONGAN" PERUMDAM Tirta Darma Ayu.
class InsentifSlipDetail {
  // --- Kop & identitas pegawai ---
  final String perusahaan;
  final String bulanLabel; // mis. "JULI 2026"
  final String nik;
  final String nama;
  final String golongan;
  final String unitKerja;
  final String jabatan;

  // --- Kolom kiri: INSENTIF ---
  final int insentifJabatan;
  final int insentifPrestasi;
  final int insentifTransportasi;
  final int insentifPangan;
  final int insentifBpjsKesehatan;
  final int insentifPerumahan;
  final int insentifBpjsTenagaKerja;
  final int insentifPerusahaan;
  final int lembur;
  final int insentifPajak;
  final int insentifAirMinum;
  final int insentifKomunikasi;

  // --- Kolom kanan: POTONGAN (bagian dari insentif) ---
  final int potonganSanksiPerusahaan;
  final int potonganPmiLain;
  final int potonganDapenma;
  final int potonganBpjsTenagaKerja;
  final int potonganPerumahan;
  final int potonganInsentifPerusahaan;
  final int potonganKorpri;
  final int potonganPajak;
  final int potonganBpjsKesehatan;

  // --- Kolom kanan: POTONGAN NON-INSENTIF ---
  final int potonganKoperasi;
  final int potonganDarmaWanita;
  final int potonganRekeningAirMinum;
  final int potonganKas;
  final int potonganBankBjb;
  final int potonganBankBjbs;
  final int potonganBankBtn;
  final int potonganBankBpr;
  final int potonganAsuransi;
  final int potonganZakatProfesi;

  const InsentifSlipDetail({
    this.perusahaan = 'PERUMDAM TIRTA DARMA AYU KAB. INDRAMAYU',
    required this.bulanLabel,
    required this.nik,
    required this.nama,
    required this.golongan,
    required this.unitKerja,
    required this.jabatan,
    this.insentifJabatan = 0,
    this.insentifPrestasi = 0,
    this.insentifTransportasi = 0,
    this.insentifPangan = 0,
    this.insentifBpjsKesehatan = 0,
    this.insentifPerumahan = 0,
    this.insentifBpjsTenagaKerja = 0,
    this.insentifPerusahaan = 0,
    this.lembur = 0,
    this.insentifPajak = 0,
    this.insentifAirMinum = 0,
    this.insentifKomunikasi = 0,
    this.potonganSanksiPerusahaan = 0,
    this.potonganPmiLain = 0,
    this.potonganDapenma = 0,
    this.potonganBpjsTenagaKerja = 0,
    this.potonganPerumahan = 0,
    this.potonganInsentifPerusahaan = 0,
    this.potonganKorpri = 0,
    this.potonganPajak = 0,
    this.potonganBpjsKesehatan = 0,
    this.potonganKoperasi = 0,
    this.potonganDarmaWanita = 0,
    this.potonganRekeningAirMinum = 0,
    this.potonganKas = 0,
    this.potonganBankBjb = 0,
    this.potonganBankBjbs = 0,
    this.potonganBankBtn = 0,
    this.potonganBankBpr = 0,
    this.potonganAsuransi = 0,
    this.potonganZakatProfesi = 0,
  });

  /// JUMLAH INSENTIF
  int get jumlahInsentif =>
      insentifJabatan +
      insentifPrestasi +
      insentifTransportasi +
      insentifPangan +
      insentifBpjsKesehatan +
      insentifPerumahan +
      insentifBpjsTenagaKerja +
      insentifPerusahaan +
      lembur +
      insentifPajak +
      insentifAirMinum +
      insentifKomunikasi;

  /// JUMLAH POTONGAN INSENTIF
  int get jumlahPotonganInsentif =>
      potonganSanksiPerusahaan +
      potonganPmiLain +
      potonganDapenma +
      potonganBpjsTenagaKerja +
      potonganPerumahan +
      potonganInsentifPerusahaan +
      potonganKorpri +
      potonganPajak +
      potonganBpjsKesehatan;

  /// JUMLAH POTONGAN NON-INSENTIF
  int get jumlahPotonganNonInsentif =>
      potonganKoperasi +
      potonganDarmaWanita +
      potonganRekeningAirMinum +
      potonganKas +
      potonganBankBjb +
      potonganBankBjbs +
      potonganBankBtn +
      potonganBankBpr +
      potonganAsuransi +
      potonganZakatProfesi;

  /// Total seluruh potongan (dipakai untuk baris ringkas di layar).
  int get totalPotongan => jumlahPotonganInsentif + jumlahPotonganNonInsentif;

  /// JUMLAH INSENTIF DITERIMA
  int get jumlahDiterima =>
      jumlahInsentif - jumlahPotonganInsentif - jumlahPotonganNonInsentif;

  /// Daftar baris insentif (label, nilai) yang nilainya > 0, dipakai untuk
  /// menyusun kartu rincian di layar secara dinamis.
  List<MapEntry<String, int>> get insentifLines => [
        MapEntry('Insentif jabatan', insentifJabatan),
        MapEntry('Insentif prestasi', insentifPrestasi),
        MapEntry('Insentif transportasi', insentifTransportasi),
        MapEntry('Insentif pangan', insentifPangan),
        MapEntry('Insentif BPJS kesehatan', insentifBpjsKesehatan),
        MapEntry('Insentif perumahan', insentifPerumahan),
        MapEntry('Insentif BPJS tenaga kerja', insentifBpjsTenagaKerja),
        MapEntry('Insentif perusahaan', insentifPerusahaan),
        MapEntry('Lembur', lembur),
        MapEntry('Insentif pajak', insentifPajak),
        MapEntry('Insentif air minum', insentifAirMinum),
        MapEntry('Insentif komunikasi', insentifKomunikasi),
      ].where((e) => e.value > 0).toList();

  /// Daftar baris potongan (label, nilai) yang nilainya > 0, gabungan
  /// potongan-insentif & non-insentif, dipakai untuk kartu rincian.
  List<MapEntry<String, int>> get potonganLines => [
        MapEntry('Potongan sanksi perusahaan', potonganSanksiPerusahaan),
        MapEntry('Potongan PMI / lain-lain', potonganPmiLain),
        MapEntry('Potongan Dapenma', potonganDapenma),
        MapEntry('Potongan BPJS tenaga kerja', potonganBpjsTenagaKerja),
        MapEntry('Potongan perumahan', potonganPerumahan),
        MapEntry('Potongan insentif perusahaan', potonganInsentifPerusahaan),
        MapEntry('Potongan Kopri', potonganKorpri),
        MapEntry('Potongan pajak (PPh21)', potonganPajak),
        MapEntry('Potongan BPJS kesehatan', potonganBpjsKesehatan),
        MapEntry('Potongan koperasi', potonganKoperasi),
        MapEntry('Potongan Dharma Wanita', potonganDarmaWanita),
        MapEntry('Potongan rekening air minum', potonganRekeningAirMinum),
        MapEntry('Potongan kas', potonganKas),
        MapEntry('Potongan Bank BJB', potonganBankBjb),
        MapEntry('Potongan Bank BJBS', potonganBankBjbs),
        MapEntry('Potongan Bank BTN', potonganBankBtn),
        MapEntry('Potongan Bank BPR', potonganBankBpr),
        MapEntry('Potongan asuransi', potonganAsuransi),
        MapEntry('Potongan zakat profesi', potonganZakatProfesi),
      ].where((e) => e.value > 0).toList();
}

/// Ringkasan kehadiran bulanan yang tampil di dashboard.
class AttendanceSummary {
  final String bulanLabel; // mis. "Juni 2026"
  final int hadir;
  final int telat;
  final int izin;

  const AttendanceSummary({
    required this.bulanLabel,
    required this.hadir,
    required this.telat,
    required this.izin,
  });
}

