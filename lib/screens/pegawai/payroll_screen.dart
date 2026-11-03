import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pegawai_data.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';

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
  String? userId = Supabase.instance.client.auth.currentUser?.id;

  // Fallback jika login via session tersimpan / auto-login
  if (userId == null) {
    try {
      final peg = await Supabase.instance.client
          .from('pegawai')
          .select('id')
          .eq('nik', user.nik)
          .maybeSingle();
      if (peg != null && peg['id'] != null) {
        userId = peg['id'].toString();
      }
    } catch (_) {}
  }

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
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10151C) : const Color(0xFFF3F6F9),
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
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
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
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'Belum ada data gaji',
                              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary(context),
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
            Divider(height: 1, color: AppColors.divider(context)),
            _plainRow(
                'Tunjangan keluarga', formatRupiah(item.tunjanganKeluarga)),
            Divider(height: 1, color: AppColors.divider(context)),
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
            if (i > 0) Divider(height: 1, color: AppColors.divider(context)),
            _plainRow(
              pendapatanLines[i].key,
              formatRupiah(pendapatanLines[i].value),
            ),
          ],
          if (pendapatanLines.isNotEmpty && potonganLines.isNotEmpty)
            Divider(height: 1, color: AppColors.divider(context)),
          for (int i = 0; i < potonganLines.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider(context)),
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
                color: AppColors.textPrimary(context),
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: bold ? navy : AppColors.textPrimary(context),
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
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context)),
        ),
      );
    }
    return _WhiteCard(
      child: Column(
        children: [
          for (int i = 0; i < riwayat.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider(context)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    riwayat[i].periode,
                    style: TextStyle(
                        fontSize: 13.5, color: AppColors.textPrimary(context)),
                  ),
                  Text(
                    formatRupiah(riwayat[i].gajiBersih),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
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

    final slip = item.slip ??
        PayrollSlipDetail(
          bulanLabel: item.periode.toUpperCase(),
          nik: widget.user.nik,
          nama: widget.user.name,
          golongan: widget.user.golonganUntukSlip,
          unitKerja: widget.user.unitKerja,
          jabatan: widget.user.jabatan,
          gapok: item.gajiPokok,
          tunjanganIstri: 0,
          tunjanganAnak: 0,
          tunjanganJabatan: item.tunjanganJabatan,
          tunjanganPrestasi: 0,
          tunjanganTransportasi: 0,
          tunjanganPangan: item.tunjanganKeluarga,
          tunjanganBpjsKesehatan: 0,
          tunjanganPerumahan: 0,
          tunjanganBpjsTenagaKerja: 0,
          tunjanganPerusahaan: 0,
          lembur: 0,
          tunjanganPajak: 0,
          tunjanganAirMinum: 0,
          tunjanganKomunikasi: 0,
          potonganSanksiPerusahaan: 0,
          potonganTrandistPmiLain: 0,
          potonganDapenma: 0,
          potonganBpjsTenagaKerja: 0,
          potonganPerumahan: 0,
          potonganTunjanganPerusahaan: 0,
          potonganKorpri: 0,
          potonganPajak: 0,
          potonganBpjsKesehatan: 0,
          potonganKoperasi: 0,
          potonganDarmaWanita: 0,
          potonganRekeningAirMinum: 0,
          potonganKas: 0,
          potonganBankBjb: 0,
          potonganBankBjbs: 0,
          potonganBankBtn: 0,
          potonganBankBpr: 0,
          potonganAsuransi: 0,
          potonganZakatProfesi: 0,
        );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        build: (context) => _buildSlipPdfContent(slip),
      ),
    );

    return doc.save();
  }

  String _formatNominal(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final posFromRight = str.length - i;
      buffer.write(str[i]);
      if (posFromRight > 1 && posFromRight % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  pw.Widget _pdfRowItem(
    String label,
    dynamic value, {
    bool bold = false,
    double labelWidth = 155,
    double numberWidth = 65,
    bool isNumber = true,
  }) {
    final style = pw.TextStyle(
      fontSize: 8.2,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: PdfColors.black,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.9),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: labelWidth,
            child: pw.Text(label, style: style),
          ),
          pw.Text(' : ', style: style),
          if (isNumber)
            pw.SizedBox(
              width: numberWidth,
              child: pw.Text(
                value is int ? _formatNominal(value) : value.toString(),
                textAlign: pw.TextAlign.right,
                style: style,
              ),
            )
          else
            pw.Expanded(
              child: pw.Text(value.toString(), style: style),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildSlipPdfContent(PayrollSlipDetail slip) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'PERUMDAM TIRTA DARMA AYU KAB. INDRAMAYU',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'DAFTAR GAJI BULAN : ${slip.bulanLabel}',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Column (Identitas & Pendapatan)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfRowItem('NIK', slip.nik, isNumber: false),
                  _pdfRowItem('NAMA', slip.nama.toUpperCase(), isNumber: false),
                  _pdfRowItem('GOLONGAN', slip.golongan, isNumber: false),
                  _pdfRowItem('UNIT KERJA', slip.unitKerja.toUpperCase(),
                      isNumber: false),
                  _pdfRowItem('JABATAN', slip.jabatan.toUpperCase(),
                      isNumber: false),
                  _pdfRowItem('GAPOK', slip.gapok),
                  _pdfRowItem('TUNJANGAN ISTRI', slip.tunjanganIstri),
                  _pdfRowItem('TUNJANGAN ANAK', slip.tunjanganAnak),
                  _pdfRowItem('TUNJANGAN JABATAN', slip.tunjanganJabatan),
                  _pdfRowItem('TUNJANGAN PRESTASI', slip.tunjanganPrestasi),
                  _pdfRowItem(
                      'TUNJANGAN TRANSPORTASI', slip.tunjanganTransportasi),
                  _pdfRowItem('TUNJANGAN PANGAN', slip.tunjanganPangan),
                  _pdfRowItem(
                      'TUNJANGAN BPJS KESEHATAN', slip.tunjanganBpjsKesehatan),
                  _pdfRowItem('TUNJANGAN PERUMAHAN', slip.tunjanganPerumahan),
                  _pdfRowItem('TUNJANGAN BPJS TENAGA KERJA',
                      slip.tunjanganBpjsTenagaKerja),
                  _pdfRowItem(
                      'TUNJANGAN PERUSAHAAN', slip.tunjanganPerusahaan),
                  _pdfRowItem('LEMBUR', slip.lembur),
                  _pdfRowItem('TUNJANGAN PAJAK', slip.tunjanganPajak),
                  _pdfRowItem('TUNJANGAN AIR MINUM', slip.tunjanganAirMinum),
                  _pdfRowItem(
                      'TUNJANGAN KOMUNIKASI', slip.tunjanganKomunikasi),
                  _pdfRowItem('JUMLAH PENDAPATAN', slip.jumlahPendapatan,
                      bold: true),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'SLIP GAJI INI SUDAH DISETUJUI OLEH DIREKSI\nNAMUN SEGALA BENTUK PENYALAH GUNAAN SLIP\nBUKAN MENJADI TANGGUNG JAWAB PERUMDAM.',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 25),
            // Right Column (Potongan)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 38), // sejajar dengan UNIT KERJA
                  _pdfRowItem('POTONGAN SANKSI PERUSAHAAN',
                      slip.potonganSanksiPerusahaan,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN PMI / LAIN-LAIN',
                      slip.potonganTrandistPmiLain,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN DAPENMA', slip.potonganDapenma,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BPJS TENAGA KERJA',
                      slip.potonganBpjsTenagaKerja,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN PERUMAHAN', slip.potonganPerumahan,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN TUNJANGAN PERUSAHAAN',
                      slip.potonganTunjanganPerusahaan,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN KORPRI', slip.potonganKorpri,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN PAJAK', slip.potonganPajak,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BPJS KESEHATAN',
                      slip.potonganBpjsKesehatan,
                      labelWidth: 195),
                  _pdfRowItem('JUMLAH POTONGAN PENDAPATAN',
                      slip.jumlahPotonganPendapatan,
                      bold: true, labelWidth: 195),
                  _pdfRowItem('POTONGAN KOPERASI', slip.potonganKoperasi,
                      labelWidth: 195),
                  _pdfRowItem(
                      'POTONGAN DARMA WANITA', slip.potonganDarmaWanita,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN REKENING AIR MINUM',
                      slip.potonganRekeningAirMinum,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN KAS', slip.potonganKas,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BANK BJB', slip.potonganBankBjb,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BANK BJBS', slip.potonganBankBjbs,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BANK BTN', slip.potonganBankBtn,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BANK BPR', slip.potonganBankBpr,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN ASURANSI', slip.potonganAsuransi,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN ZAKAT PROFESI',
                      slip.potonganZakatProfesi,
                      labelWidth: 195),
                  _pdfRowItem('JUMLAH POTONGAN NON-PENDAPATAN',
                      slip.jumlahPotonganNonPendapatan,
                      bold: true, labelWidth: 195),
                  _pdfRowItem(
                      'JUMLAH PENDAPATAN DITERIMA', slip.jumlahDiterima,
                      bold: true, labelWidth: 195),
                ],
              ),
            ),
          ],
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
        color: AppColors.card(context),
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