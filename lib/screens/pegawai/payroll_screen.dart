import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pegawai_data.dart';
import '../../models/user_role.dart';

String formatRupiah(int value) {
  final str = value.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    final posFromRight = str.length - i;
    buffer.write(str[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp $buffer';
}

/// Ambil semua data payroll milik pegawai yang sedang login dari Supabase,
/// diurutkan dari periode terbaru ke terlama, lalu dipetakan ke model
/// [PayrollItem] + [PayrollSlipDetail] yang sama persis dipakai UI/PDF di
/// bawah -- sehingga tidak ada satupun widget/PDF builder yang perlu diubah.
Future<List<PayrollItem>> _fetchPayroll(AppUser user) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final rows = await Supabase.instance.client
      .from('payroll')
      .select()
      .eq('pegawai_id', userId)
      .order('tahun', ascending: false)
      .order('bulan', ascending: false);

  return (rows as List).map((row) {
    final slip = PayrollSlipDetail(
      bulanLabel: (row['periode'] as String).toUpperCase(),
      nik: user.nik,
      nama: user.name,
      golongan: user.golonganUntukSlip,
      unitKerja: user.unitKerja,
      jabatan: user.jabatan,
      gapok: (row['gapok'] ?? 0) as int,
      tunjanganIstri: (row['tunjangan_istri'] ?? 0) as int,
      tunjanganAnak: (row['tunjangan_anak'] ?? 0) as int,
      tunjanganJabatan: (row['tunjangan_jabatan'] ?? 0) as int,
      tunjanganPrestasi: (row['tunjangan_prestasi'] ?? 0) as int,
      tunjanganTransportasi: (row['tunjangan_transportasi'] ?? 0) as int,
      tunjanganPangan: (row['tunjangan_pangan'] ?? 0) as int,
      tunjanganBpjsKesehatan: (row['tunjangan_bpjs_kesehatan'] ?? 0) as int,
      tunjanganPerumahan: (row['tunjangan_perumahan'] ?? 0) as int,
      tunjanganBpjsTenagaKerja:
          (row['tunjangan_bpjs_tenaga_kerja'] ?? 0) as int,
      tunjanganPerusahaan: (row['tunjangan_perusahaan'] ?? 0) as int,
      lembur: (row['lembur'] ?? 0) as int,
      tunjanganPajak: (row['tunjangan_pajak'] ?? 0) as int,
      tunjanganAirMinum: (row['tunjangan_air_minum'] ?? 0) as int,
      tunjanganKomunikasi: (row['tunjangan_komunikasi'] ?? 0) as int,
      potonganSanksiPerusahaan: (row['potongan_sanksi_perusahaan'] ?? 0) as int,
      potonganTrandistPmiLain: (row['potongan_trandist_pmi_lain'] ?? 0) as int,
      potonganDapenma: (row['potongan_dapenma'] ?? 0) as int,
      potonganBpjsTenagaKerja: (row['potongan_bpjs_tenaga_kerja'] ?? 0) as int,
      potonganPerumahan: (row['potongan_perumahan'] ?? 0) as int,
      potonganTunjanganPerusahaan:
          (row['potongan_tunjangan_perusahaan'] ?? 0) as int,
      potonganKorpri: (row['potongan_korpri'] ?? 0) as int,
      potonganPajak: (row['potongan_pajak'] ?? 0) as int,
      potonganBpjsKesehatan: (row['potongan_bpjs_kesehatan'] ?? 0) as int,
      potonganKoperasi: (row['potongan_koperasi'] ?? 0) as int,
      potonganDarmaWanita: (row['potongan_darma_wanita'] ?? 0) as int,
      potonganRekeningAirMinum:
          (row['potongan_rekening_air_minum'] ?? 0) as int,
      potonganKas: (row['potongan_kas'] ?? 0) as int,
      potonganBankBjb: (row['potongan_bank_bjb'] ?? 0) as int,
      potonganBankBjbs: (row['potongan_bank_bjbs'] ?? 0) as int,
      potonganBankBtn: (row['potongan_bank_btn'] ?? 0) as int,
      potonganBankBpr: (row['potongan_bank_bpr'] ?? 0) as int,
      potonganAsuransi: (row['potongan_asuransi'] ?? 0) as int,
      potonganZakatProfesi: (row['potongan_zakat_profesi'] ?? 0) as int,
    );

    return PayrollItem(
      periode: row['periode'] as String,
      gajiPokok: (row['gapok'] ?? 0) as int,
      tunjanganKeluarga: ((row['tunjangan_istri'] ?? 0) as int) +
          ((row['tunjangan_anak'] ?? 0) as int),
      tunjanganJabatan: (row['tunjangan_jabatan'] ?? 0) as int,
      potongan: slip.totalPotongan,
      status: row['status'] as String,
      slip: slip,
    );
  }).toList();
}

/// Halaman Payroll / Gaji — didesain mengikuti mockup UI (kartu ringkasan
/// hijau "Gaji Bersih", rincian pendapatan & potongan, riwayat per bulan,
/// dan tombol "Cek Detail" yang mengunduh slip gaji lengkap dalam PDF).
class PayrollScreen extends StatefulWidget {
  final AppUser user;

  const PayrollScreen({super.key, required this.user});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color greenStart = Color(0xFF35A76B);
  static const Color greenEnd = Color(0xFF1F7A4A);
  static const Color totalBg = Color(0xFFDCEBFB);
  static const Color labelGrey = Color(0xFF8C97A6);

  bool _isGenerating = false;
  late Future<List<PayrollItem>> _payrollFuture;

  @override
  void initState() {
    super.initState();
    _payrollFuture = _fetchPayroll(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _payrollFuture = _fetchPayroll(widget.user));
    await _payrollFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: FutureBuilder<List<PayrollItem>>(
              future: _payrollFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Gagal memuat data gaji: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: labelGrey, fontSize: 13),
                      ),
                    ),
                  );
                }

                final payrollList = snapshot.data ?? [];
                final PayrollItem? terbaru =
                    payrollList.isNotEmpty ? payrollList.first : null;
                final riwayat = payrollList.length > 1
                    ? payrollList.sublist(1)
                    : <PayrollItem>[];

                if (terbaru == null) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: const [
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'Belum ada data gaji',
                              style: TextStyle(color: labelGrey, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _buildHeroCard(terbaru),
                      const SizedBox(height: 22),
                      _buildSectionLabel('RINCIAN'),
                      const SizedBox(height: 10),
                      _buildRincianCard(terbaru),
                      const SizedBox(height: 22),
                      _buildSectionLabel('RIWAYAT PER BULAN'),
                      const SizedBox(height: 10),
                      _buildRiwayatCard(riwayat),
                      const SizedBox(height: 24),
                      _buildCekDetailButton(terbaru),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header navy dengan tombol kembali & judul "Payroll".
  // ---------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        color: navy,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -40,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 14,
                left: 16,
                right: 16,
                bottom: 20,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Payroll',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(PayrollItem item) {
    final total = item.slip?.jumlahDiterima ?? item.gajiBersih;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [greenStart, greenEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: greenEnd.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Gaji Bersih · ${item.periode}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatRupiah(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: labelGrey,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildRincianCard(PayrollItem item) {
    final slip = item.slip;

    if (slip == null) {
      return _WhiteCard(
        child: Column(
          children: [
            _plainRow('Gaji pokok', formatRupiah(item.gajiPokok)),
            const Divider(height: 1, color: Color(0xFFEDF0F3)),
            _plainRow(
                'Tunjangan keluarga', formatRupiah(item.tunjanganKeluarga)),
            const Divider(height: 1, color: Color(0xFFEDF0F3)),
            _plainRow('Tunjangan jabatan', formatRupiah(item.tunjanganJabatan)),
            const SizedBox(height: 4),
            _plainRow('Jumlah Potongan', '- ${formatRupiah(item.potongan)}',
                bold: true),
            const SizedBox(height: 8),
            _highlightRow('Pendapatan', formatRupiah(item.gajiBersih)),
          ],
        ),
      );
    }

    final pendapatanLines = slip.pendapatanLines;
    final potonganLines = slip.potonganLines;

    return _WhiteCard(
      child: Column(
        children: [
          for (int i = 0; i < pendapatanLines.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEDF0F3)),
            _plainRow(
              pendapatanLines[i].key,
              formatRupiah(pendapatanLines[i].value),
            ),
          ],
          if (pendapatanLines.isNotEmpty && potonganLines.isNotEmpty)
            const Divider(height: 1, color: Color(0xFFEDF0F3)),
          for (int i = 0; i < potonganLines.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEDF0F3)),
            _plainRow(
              potonganLines[i].key,
              formatRupiah(potonganLines[i].value),
            ),
          ],
          const SizedBox(height: 4),
          _plainRow(
            'Jumlah Potongan',
            formatRupiah(slip.totalPotongan),
            bold: true,
          ),
          const SizedBox(height: 8),
          _highlightRow('Pendapatan', formatRupiah(slip.jumlahDiterima)),
        ],
      ),
    );
  }

  Widget _plainRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: const Color(0xFF3B3F45),
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: bold ? navy : const Color(0xFF1B2733),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: totalBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatCard(List<PayrollItem> riwayat) {
    if (riwayat.isEmpty) {
      return _WhiteCard(
        child: Text(
          'Belum ada riwayat gaji bulan sebelumnya',
          style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
        ),
      );
    }
    return _WhiteCard(
      child: Column(
        children: [
          for (int i = 0; i < riwayat.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEDF0F3)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    riwayat[i].periode,
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFF3B3F45)),
                  ),
                  Text(
                    formatRupiah(riwayat[i].gajiBersih),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: labelGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCekDetailButton(PayrollItem item) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : () => _downloadPayrollPdf(item),
        icon: _isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.description_outlined, size: 19),
        label: Text(
          _isGenerating ? 'Menyiapkan PDF...' : 'Cek Detail',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPayrollPdf(PayrollItem item) async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generatePayrollPdf(item);
      final fileLabel =
          (item.slip?.bulanLabel ?? item.periode).replaceAll(' ', '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'GAJI_$fileLabel.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<Uint8List> _generatePayrollPdf(PayrollItem item) async {
    final doc = pw.Document();
    final navyColor = PdfColor.fromInt(0xFF0D2C6E);
    final greyColor = PdfColor.fromInt(0xFF8C97A6);

    if (item.slip != null) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) =>
              _buildSlipPdfContent(item.slip!, navyColor, greyColor),
        ),
      );
    } else {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) =>
              _buildSimplePdfContent(item, navyColor, greyColor),
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildSlipPdfContent(
    PayrollSlipDetail slip,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            slip.perusahaan,
            style: pw.TextStyle(
              fontSize: 12.5,
              fontWeight: pw.FontWeight.bold,
              color: navyColor,
            ),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            'DAFTAR GAJI BULAN : ${slip.bulanLabel}',
            style: pw.TextStyle(fontSize: 10.5, color: greyColor),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: greyColor, thickness: 0.7),
        pw.SizedBox(height: 10),
        _pdfIdentityRow('NIK', widget.user.nik),
        _pdfIdentityRow('NAMA', widget.user.name.toUpperCase()),
        _pdfIdentityRow('GOLONGAN', widget.user.golonganUntukSlip),
        _pdfIdentityRow('UNIT KERJA', widget.user.unitKerja.toUpperCase()),
        _pdfIdentityRow('JABATAN', widget.user.jabatan.toUpperCase()),
        pw.SizedBox(height: 14),
        pw.Divider(color: greyColor, thickness: 0.7),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _buildPendapatanColumn(slip, navyColor, greyColor),
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              child: _buildPotonganColumn(slip, navyColor, greyColor),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: greyColor, thickness: 0.7),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'JUMLAH PENDAPATAN DITERIMA',
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: navyColor,
              ),
            ),
            pw.Text(
              formatRupiah(slip.jumlahDiterima),
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: navyColor,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: greyColor, thickness: 0.7),
        pw.SizedBox(height: 6),
        pw.Text(
          'Slip gaji ini sudah disetujui oleh Direksi. Segala bentuk '
          'penyalahgunaan slip bukan menjadi tanggung jawab perusahaan.',
          style: pw.TextStyle(fontSize: 8, color: greyColor),
        ),
      ],
    );
  }

  pw.Widget _pdfIdentityRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPendapatanColumn(
    PayrollSlipDetail slip,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PENDAPATAN',
          style: pw.TextStyle(
              fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: greyColor),
        ),
        pw.SizedBox(height: 6),
        _pdfSlipLine('Gaji Pokok', slip.gapok),
        _pdfSlipLine('Tunjangan Istri', slip.tunjanganIstri),
        _pdfSlipLine('Tunjangan Anak', slip.tunjanganAnak),
        _pdfSlipLine('Tunjangan Jabatan', slip.tunjanganJabatan),
        _pdfSlipLine('Tunjangan Prestasi', slip.tunjanganPrestasi),
        _pdfSlipLine('Tunjangan Transportasi', slip.tunjanganTransportasi),
        _pdfSlipLine('Tunjangan Pangan', slip.tunjanganPangan),
        _pdfSlipLine('Tunjangan BPJS Kesehatan', slip.tunjanganBpjsKesehatan),
        _pdfSlipLine('Tunjangan Perumahan', slip.tunjanganPerumahan),
        _pdfSlipLine(
            'Tunjangan BPJS Tenaga Kerja', slip.tunjanganBpjsTenagaKerja),
        _pdfSlipLine('Tunjangan Perusahaan', slip.tunjanganPerusahaan),
        _pdfSlipLine('Lembur', slip.lembur),
        _pdfSlipLine('Tunjangan Pajak', slip.tunjanganPajak),
        _pdfSlipLine('Tunjangan Air Minum', slip.tunjanganAirMinum),
        _pdfSlipLine('Tunjangan Komunikasi', slip.tunjanganKomunikasi),
        pw.SizedBox(height: 4),
        pw.Divider(color: greyColor, thickness: 0.5),
        _pdfSlipLine('Jumlah Pendapatan', slip.jumlahPendapatan,
            bold: true, color: navyColor),
      ],
    );
  }

  pw.Widget _buildPotonganColumn(
    PayrollSlipDetail slip,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'POTONGAN',
          style: pw.TextStyle(
              fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: greyColor),
        ),
        pw.SizedBox(height: 6),
        _pdfSlipLine(
            'Potongan Sanksi Perusahaan', slip.potonganSanksiPerusahaan),
        _pdfSlipLine(
            'Trandist Potongan PMI / Lain-lain', slip.potonganTrandistPmiLain),
        _pdfSlipLine('Potongan Dapenma', slip.potonganDapenma),
        _pdfSlipLine(
            'Potongan BPJS Tenaga Kerja', slip.potonganBpjsTenagaKerja),
        _pdfSlipLine('Potongan Perumahan', slip.potonganPerumahan),
        _pdfSlipLine(
            'Potongan Tunjangan Perusahaan', slip.potonganTunjanganPerusahaan),
        _pdfSlipLine('Potongan Korpri', slip.potonganKorpri),
        _pdfSlipLine('Potongan Pajak', slip.potonganPajak),
        _pdfSlipLine('Potongan BPJS Kesehatan', slip.potonganBpjsKesehatan),
        pw.SizedBox(height: 4),
        pw.Divider(color: greyColor, thickness: 0.5),
        _pdfSlipLine(
            'Jumlah Potongan Pendapatan', slip.jumlahPotonganPendapatan,
            bold: true, color: navyColor),
        pw.SizedBox(height: 10),
        _pdfSlipLine('Potongan Koperasi', slip.potonganKoperasi),
        _pdfSlipLine('Potongan Darma Wanita', slip.potonganDarmaWanita),
        _pdfSlipLine(
            'Potongan Rekening Air Minum', slip.potonganRekeningAirMinum),
        _pdfSlipLine('Potongan Kas', slip.potonganKas),
        _pdfSlipLine('Potongan Bank BJB', slip.potonganBankBjb),
        _pdfSlipLine('Potongan Bank BJBS', slip.potonganBankBjbs),
        _pdfSlipLine('Potongan Bank BTN', slip.potonganBankBtn),
        _pdfSlipLine('Potongan Bank BPR', slip.potonganBankBpr),
        _pdfSlipLine('Potongan Asuransi', slip.potonganAsuransi),
        _pdfSlipLine('Potongan Zakat Profesi', slip.potonganZakatProfesi),
        pw.SizedBox(height: 4),
        pw.Divider(color: greyColor, thickness: 0.5),
        _pdfSlipLine(
            'Jumlah Potongan Non-Pendapatan', slip.jumlahPotonganNonPendapatan,
            bold: true, color: navyColor),
      ],
    );
  }

  pw.Widget _pdfSlipLine(
    String label,
    int value, {
    bool bold = false,
    PdfColor? color,
  }) {
    final style = pw.TextStyle(
      fontSize: 8.3,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(formatRupiah(value), style: style),
        ],
      ),
    );
  }

  pw.Widget _buildSimplePdfContent(
    PayrollItem item,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PERUMDAM TIRTA DARMA AYU',
          style: pw.TextStyle(
              fontSize: 11, color: greyColor, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Slip Gaji / Payroll',
          style: pw.TextStyle(
              fontSize: 20, fontWeight: pw.FontWeight.bold, color: navyColor),
        ),
        pw.SizedBox(height: 2),
        pw.Text('Periode ${item.periode}',
            style: pw.TextStyle(fontSize: 12, color: greyColor)),
        pw.SizedBox(height: 20),
        pw.Divider(color: greyColor),
        pw.SizedBox(height: 14),
        _pdfRow('Status', item.status, navyColor),
        pw.SizedBox(height: 20),
        pw.Text(
          'RINCIAN',
          style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold, color: greyColor),
        ),
        pw.SizedBox(height: 10),
        _pdfRow('Gaji Pokok', formatRupiah(item.gajiPokok), navyColor),
        pw.SizedBox(height: 8),
        _pdfRow('Tunjangan Keluarga', formatRupiah(item.tunjanganKeluarga),
            navyColor),
        pw.SizedBox(height: 8),
        _pdfRow('Tunjangan Jabatan', formatRupiah(item.tunjanganJabatan),
            navyColor),
        pw.SizedBox(height: 8),
        _pdfRow('Potongan', '- ${formatRupiah(item.potongan)}', navyColor),
        pw.SizedBox(height: 12),
        pw.Divider(color: greyColor),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Gaji Bersih',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: navyColor)),
            pw.Text(formatRupiah(item.gajiBersih),
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: navyColor)),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: greyColor),
        pw.SizedBox(height: 6),
        pw.Text(
          'Dokumen ini dibuat otomatis oleh aplikasi SIMPEG Mobile dan sah tanpa tanda tangan basah.',
          style: pw.TextStyle(fontSize: 8.5, color: greyColor),
        ),
      ],
    );
  }

  pw.Widget _pdfRow(String label, String value, PdfColor navyColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        pw.Text(
          value,
          style: pw.TextStyle(
              fontSize: 11, fontWeight: pw.FontWeight.bold, color: navyColor),
        ),
      ],
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
