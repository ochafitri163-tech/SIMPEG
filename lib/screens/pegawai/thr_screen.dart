import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/pegawai_data.dart';
import '../../models/user_role.dart';
import 'payroll_screen.dart' show formatRupiah;

/// Halaman THR — didesain ulang mengikuti mockup UI (kartu ringkasan
/// oranye "THR terakhir cair", rincian perhitungan, riwayat per tahun,
/// dan tombol "Cek Detail" yang mengunduh slip THR dalam bentuk PDF).
class ThrScreen extends StatefulWidget {
  final AppUser user;

  const ThrScreen({super.key, required this.user});

  @override
  State<ThrScreen> createState() => _ThrScreenState();
}

class _ThrScreenState extends State<ThrScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color orangeStart = Color(0xFFF5A623);
  static const Color orangeEnd = Color(0xFFE8890B);
  static const Color totalBg = Color(0xFFDCEBFB);
  static const Color labelGrey = Color(0xFF8C97A6);

  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final ThrItem? terakhir = dummyThr.isNotEmpty ? dummyThr.first : null;
    final riwayat = dummyThr.length > 1 ? dummyThr.sublist(1) : <ThrItem>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: terakhir == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Belum ada data THR',
                        style: TextStyle(color: labelGrey, fontSize: 13),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _buildHeroCard(terakhir),
                      const SizedBox(height: 22),
                      _buildSectionLabel('RINCIAN PERHITUNGAN'),
                      const SizedBox(height: 10),
                      _buildRincianCard(terakhir),
                      const SizedBox(height: 22),
                      _buildSectionLabel('RIWAYAT PER TAHUN'),
                      const SizedBox(height: 10),
                      _buildRiwayatCard(riwayat),
                      const SizedBox(height: 24),
                      _buildCekDetailButton(terakhir),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header navy dengan tombol kembali & judul "THR".
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
                    'THR',
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

  // ---------------------------------------------------------------------
  // Kartu oranye "THR terakhir cair".
  // ---------------------------------------------------------------------
  Widget _buildHeroCard(ThrItem item) {
    final total = item.slip?.jumlahDiterima ?? item.jumlah;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [orangeStart, orangeEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: orangeEnd.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'THR terakhir cair',
            style: TextStyle(
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
          const SizedBox(height: 6),
          Text(
            'Dicairkan ${item.tanggalCair}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
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

  // ---------------------------------------------------------------------
  // Kartu rincian perhitungan. Dibangun dinamis dari ThrSlipDetail (semua
  // baris pendapatan & potongan yang nilainya > 0) supaya selalu sinkron
  // dengan angka di PDF. Kalau item belum punya slip, jatuh ke versi
  // ringkas (gaji pokok / tunjangan tetap / total).
  // ---------------------------------------------------------------------
  Widget _buildRincianCard(ThrItem item) {
    final slip = item.slip;

    if (slip == null) {
      return _WhiteCard(
        child: Column(
          children: [
            _plainRow('Gaji pokok', formatRupiah(item.gajiPokok)),
            const Divider(height: 1, color: Color(0xFFEDF0F3)),
            _plainRow('Tunjangan tetap', formatRupiah(item.tunjanganTetap)),
            const SizedBox(height: 12),
            _highlightRow('Total THR', formatRupiah(item.jumlah)),
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
          if (potonganLines.isNotEmpty) ...[
            if (pendapatanLines.isNotEmpty)
              const Divider(height: 1, color: Color(0xFFEDF0F3)),
            for (int i = 0; i < potonganLines.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFEDF0F3)),
              _plainRow(
                potonganLines[i].key,
                formatRupiah(potonganLines[i].value),
              ),
            ],
            const SizedBox(height: 4),
            _plainRow('Jumlah Potongan', formatRupiah(slip.totalPotongan),
                bold: true),
          ],
          const SizedBox(height: 8),
          _highlightRow('Total THR', formatRupiah(slip.jumlahDiterima)),
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

  // ---------------------------------------------------------------------
  // Kartu riwayat THR per tahun.
  // ---------------------------------------------------------------------
  Widget _buildRiwayatCard(List<ThrItem> riwayat) {
    if (riwayat.isEmpty) {
      return _WhiteCard(
        child: Text(
          'Belum ada riwayat THR tahun sebelumnya',
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
                    'THR ${riwayat[i].tahun}',
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFF3B3F45)),
                  ),
                  Text(
                    formatRupiah(riwayat[i].jumlah),
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

  // ---------------------------------------------------------------------
  // Tombol "Cek Detail" -> generate & unduh slip THR (PDF).
  // ---------------------------------------------------------------------
  Widget _buildCekDetailButton(ThrItem item) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : () => _downloadThrPdf(item),
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isGenerating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Cek Detail',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _downloadThrPdf(ThrItem item) async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generateThrPdf(item);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'THR_${item.tahun}.pdf',
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

  /// Menyusun dokumen PDF slip THR.
  /// Kalau [item.slip] tersedia, cetak slip lengkap dua kolom
  /// (Pendapatan & Potongan) persis format resmi perusahaan.
  /// Kalau tidak, jatuh ke versi ringkas (gaji pokok/tunjangan/total).
  Future<Uint8List> _generateThrPdf(ThrItem item) async {
    final doc = pw.Document();
    final navyColor = PdfColor.fromInt(0xFF0D2C6E);
    final greyColor = PdfColor.fromInt(0xFF8C97A6);

    if (item.slip != null) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildSlipPdfContent(item, item.slip!, navyColor, greyColor),
        ),
      );
    } else {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => _buildSimplePdfContent(item, navyColor, greyColor),
        ),
      );
    }

    return doc.save();
  }

  // ---------------------------------------------------------------------
  // Layout PDF lengkap: kop perusahaan, identitas pegawai, 2 kolom
  // (PENDAPATAN | POTONGAN), lalu baris "JUMLAH PENDAPATAN DITERIMA".
  // ---------------------------------------------------------------------
  pw.Widget _buildSlipPdfContent(
    ThrItem item,
    ThrSlipDetail slip,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Kop.
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
            'DAFTAR THR BULAN : ${slip.bulanLabel}',
            style: pw.TextStyle(fontSize: 10.5, color: greyColor),
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: greyColor, thickness: 0.7),
        pw.SizedBox(height: 10),

        // Identitas pegawai.
        _pdfIdentityRow('NIK', widget.user.nik),
        _pdfIdentityRow('NAMA', widget.user.name.toUpperCase()),
        _pdfIdentityRow('GOLONGAN', widget.user.golonganUntukSlip),
        _pdfIdentityRow('UNIT KERJA', widget.user.unitKerja.toUpperCase()),
        _pdfIdentityRow('JABATAN', widget.user.jabatan.toUpperCase()),

        pw.SizedBox(height: 14),
        pw.Divider(color: greyColor, thickness: 0.7),
        pw.SizedBox(height: 10),

        // Dua kolom: PENDAPATAN | POTONGAN.
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

        // Total diterima.
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
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPendapatanColumn(
    ThrSlipDetail slip,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PENDAPATAN',
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: greyColor,
          ),
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
        _pdfSlipLine('Jumlah Pendapatan', slip.jumlahPendapatan, bold: true, color: navyColor),
      ],
    );
  }

  pw.Widget _buildPotonganColumn(
    ThrSlipDetail slip,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'POTONGAN',
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: greyColor,
          ),
        ),
        pw.SizedBox(height: 6),
        _pdfSlipLine('Trandist Potongan PMI / Lain-lain',
            slip.potonganTrandistPmiLain),
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
        _pdfSlipLine('Jumlah Potongan Pendapatan',
            slip.jumlahPotonganPendapatan,
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
        _pdfSlipLine('Potongan Zakat Ramadhan', slip.potonganZakatRamadhan),
        pw.SizedBox(height: 4),
        pw.Divider(color: greyColor, thickness: 0.5),
        _pdfSlipLine('Jumlah Potongan Non-Pendapatan',
            slip.jumlahPotonganNonPendapatan,
            bold: true, color: navyColor),
      ],
    );
  }

  /// Satu baris "label ......... nilai" untuk kolom pendapatan/potongan.
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
          pw.Expanded(
            child: pw.Text(label, style: style),
          ),
          pw.Text(formatRupiah(value), style: style),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Layout PDF ringkas (fallback bila item tidak punya rincian slip).
  // ---------------------------------------------------------------------
  pw.Widget _buildSimplePdfContent(
    ThrItem item,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PERUMDAM TIRTA DARMA AYU',
          style: pw.TextStyle(
            fontSize: 11,
            color: greyColor,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Slip Tunjangan Hari Raya (THR)',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: navyColor,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Tahun ${item.tahun}',
          style: pw.TextStyle(fontSize: 12, color: greyColor),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: greyColor),
        pw.SizedBox(height: 14),
        _pdfRow('Status', item.status, navyColor),
        pw.SizedBox(height: 8),
        _pdfRow('Tanggal Cair', item.tanggalCair, navyColor),
        pw.SizedBox(height: 20),
        pw.Text(
          'RINCIAN PERHITUNGAN',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: greyColor,
          ),
        ),
        pw.SizedBox(height: 10),
        _pdfRow('Gaji Pokok', formatRupiah(item.gajiPokok), navyColor),
        pw.SizedBox(height: 8),
        _pdfRow(
            'Tunjangan Tetap', formatRupiah(item.tunjanganTetap), navyColor),
        pw.SizedBox(height: 12),
        pw.Divider(color: greyColor),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total THR',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: navyColor,
              ),
            ),
            pw.Text(
              formatRupiah(item.jumlah),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: navyColor,
              ),
            ),
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
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: navyColor,
          ),
        ),
      ],
    );
  }
}

/// Kartu putih dasar dengan shadow lembut, dipakai berulang di halaman ini.
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