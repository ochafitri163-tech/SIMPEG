import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/pegawai_data.dart';
import 'payroll_screen.dart' show formatRupiah;

/// Halaman Pendidikan — riwayat jenjang pendidikan pegawai, ditutup dengan
/// tombol "Cek Detail" yang mengunduh slip Tunjangan Pendidikan & Potongan
/// dalam bentuk PDF (persis format resmi perusahaan).
class PendidikanScreen extends StatefulWidget {
  const PendidikanScreen({super.key});

  @override
  State<PendidikanScreen> createState() => _PendidikanScreenState();
}

class _PendidikanScreenState extends State<PendidikanScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color badgeBg = Color(0xFFE3F1F8);
  static const Color labelGrey = Color(0xFF8C97A6);

  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: dummyPendidikan.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Belum ada data pendidikan',
                        style: TextStyle(color: labelGrey, fontSize: 13),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _buildSectionLabel('RIWAYAT PENDIDIKAN'),
                      const SizedBox(height: 10),
                      for (int i = 0; i < dummyPendidikan.length; i++) ...[
                        _buildPendidikanCard(
                          dummyPendidikan[i],
                          isTerakhir: i == 0,
                        ),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 10),
                      _buildCekDetailButton(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header navy dengan tombol kembali & judul "Pendidikan".
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
                bottom: 24,
              ),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.maybePop(context),
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
                    'Pendidikan',
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
  // Kartu satu jenjang pendidikan.
  // ---------------------------------------------------------------------
  Widget _buildPendidikanCard(PendidikanItem item, {required bool isTerakhir}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.jenjang,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: navy,
                  ),
                ),
              ),
              if (isTerakhir)
                const Text(
                  'Terakhir',
                  style: TextStyle(fontSize: 12, color: labelGrey),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _fieldColumn('JURUSAN', item.jurusan ?? '—'),
              ),
              Expanded(
                child: _fieldColumn('TAHUN LULUS', item.tahunLulus),
              ),
            ],
          ),
          if (item.namaSekolah != null) ...[
            const SizedBox(height: 14),
            _fieldColumn('NAMA SEKOLAH', item.namaSekolah!),
          ],
          if (item.kotaLulus != null) ...[
            const SizedBox(height: 14),
            _fieldColumn('KOTA LULUS', item.kotaLulus!),
          ],
        ],
      ),
    );
  }

  Widget _fieldColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: labelGrey,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B2733),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Tombol "Cek Detail" -> generate & unduh slip tunjangan pendidikan (PDF).
  // ---------------------------------------------------------------------
  Widget _buildCekDetailButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _downloadPendidikanPdf,
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

  Future<void> _downloadPendidikanPdf() async {
    setState(() => _isGenerating = true);
    try {
      final slip = dummyPendidikanTunjangan;
      final bytes = await _generatePendidikanPdf(slip);
      final fileLabel = slip.bulanLabel.replaceAll(' ', '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'TUNJANGAN_PENDIDIKAN_$fileLabel.pdf',
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

  /// Menyusun dokumen PDF slip Tunjangan Pendidikan & Potongan, persis
  /// format resmi perusahaan (kop, identitas pegawai, 2 kolom
  /// Pendapatan | Potongan, lalu "JUMLAH INSENTIF DITERIMA").
  Future<Uint8List> _generatePendidikanPdf(
      PendidikanTunjanganDetail slip) async {
    final doc = pw.Document();
    final navyColor = PdfColor.fromInt(0xFF0D2C6E);
    final greyColor = PdfColor.fromInt(0xFF8C97A6);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
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
                  'DAFTAR TUNJANGAN PENDIDIKAN & POTONGAN BULAN : ${slip.bulanLabel}',
                  style: pw.TextStyle(fontSize: 10.5, color: greyColor),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: greyColor, thickness: 0.7),
              pw.SizedBox(height: 10),
              _pdfIdentityRow('NIK', slip.nik),
              _pdfIdentityRow('NAMA', slip.nama),
              _pdfIdentityRow('GOLONGAN', slip.golongan),
              _pdfIdentityRow('UNIT KERJA', slip.unitKerja),
              _pdfIdentityRow('JABATAN', slip.jabatan),
              pw.SizedBox(height: 14),
              pw.Divider(color: greyColor, thickness: 0.7),
              pw.SizedBox(height: 10),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
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
                        _pdfLine('Gaji Pokok', slip.gapok),
                        _pdfLine('Tunjangan Istri', slip.tunjanganIstri),
                        _pdfLine('Tunjangan Anak', slip.tunjanganAnak),
                        pw.SizedBox(height: 4),
                        pw.Divider(color: greyColor, thickness: 0.5),
                        _pdfLine('Jumlah Pendapatan', slip.jumlahPendapatan,
                            bold: true, color: navyColor),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 18),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'POTONGAN (TRANDIST)',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: greyColor,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        _pdfLine('Potongan Koperasi', slip.potonganKoperasi),
                        _pdfLine('Potongan Kas', slip.potonganKas),
                        pw.SizedBox(height: 4),
                        pw.Divider(color: greyColor, thickness: 0.5),
                        _pdfLine('Jumlah Potongan Non-Insentif',
                            slip.jumlahPotonganNonInsentif,
                            bold: true, color: navyColor),
                      ],
                    ),
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
                    'JUMLAH INSENTIF DITERIMA',
                    style: pw.TextStyle(
                      fontSize: 11.5,
                      fontWeight: pw.FontWeight.bold,
                      color: navyColor,
                    ),
                  ),
                  pw.Text(
                    formatRupiah(slip.jumlahInsentifDiterima),
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
                'penyalahgunaan slip gaji bukan menjadi tanggung jawab '
                'Perumdam Tirta Darma Ayu.',
                style: pw.TextStyle(fontSize: 8, color: greyColor),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
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

  /// Satu baris "label ......... nilai" untuk kolom pendapatan/potongan.
  pw.Widget _pdfLine(
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
}
