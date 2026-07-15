import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/pengaduan_model.dart';
import '../../widgets/feature_scaffold.dart';

/// Halaman Detail Pengaduan — menampilkan informasi lengkap satu
/// pengaduan: identitas pelapor, isi laporan, status saat ini, riwayat
/// perubahan status (timeline), bukti foto, keterangan SPI/Tim Penegak
/// Disiplin, serta tombol unduh laporan dalam bentuk PDF.
class DetailPengaduanScreen extends StatefulWidget {
  final Pengaduan pengaduan;
  const DetailPengaduanScreen({super.key, required this.pengaduan});

  @override
  State<DetailPengaduanScreen> createState() => _DetailPengaduanScreenState();
}

class _DetailPengaduanScreenState extends State<DetailPengaduanScreen> {
  static const Color labelDark = Color(0xFF1B2733);
  static const Color hintGrey = Color(0xFF9AA5B1);

  bool _isGeneratingPdf = false;

  Pengaduan get p => widget.pengaduan;

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Detail Pengaduan',
      subtitle: p.nomorPengaduan,
      icon: Icons.fact_check_rounded,
      trailing: IconButton(
        onPressed: _isGeneratingPdf ? null : _unduhPdf,
        tooltip: 'Unduh PDF',
        icon: _isGeneratingPdf
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white, size: 20),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _buildStatusHeaderCard(),
          const SizedBox(height: 14),
          _buildIdentitasCard(),
          const SizedBox(height: 14),
          _buildLaporanCard(),
          if (p.kategoriDivisi != null || p.eksekutor != null || p.hasilInvestigasi != null) ...[
            const SizedBox(height: 14),
            _buildProsesCard(),
          ],
          if (p.fotoBukti.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildFotoBuktiCard(),
          ],
          if (p.status == PengaduanStatus.ditolakDirektur &&
              (p.alasanPenolakan ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildKeteranganCard(
              title: 'Alasan Penolakan',
              icon: Icons.block_rounded,
              color: const Color(0xFFE74C3C),
              text: p.alasanPenolakan!,
            ),
          ],
          if (p.status == PengaduanStatus.selesai &&
              (p.keteranganSelesai ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildKeteranganCard(
              title: 'Keterangan Penyelesaian',
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF1E8449),
              text: p.keteranganSelesai!,
            ),
          ],
          const SizedBox(height: 14),
          _buildTimelineCard(),
        ],
      ),
    );
  }

  // ==================== STATUS HEADER ====================
  Widget _buildStatusHeaderCard() {
    return InfoCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: p.status.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(p.status.icon, color: p.status.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Saat Ini',
                  style: TextStyle(fontSize: 11, color: hintGrey),
                ),
                const SizedBox(height: 3),
                Text(
                  p.status.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: p.status.color,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(label: p.status.label, color: p.status.color),
        ],
      ),
    );
  }

  // ==================== IDENTITAS ====================
  Widget _buildIdentitasCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Identitas Pelapor'),
          const SizedBox(height: 8),
          InfoRow(label: 'Nomor Pengaduan', value: p.nomorPengaduan),
          InfoRow(
            label: 'Nama Pegawai',
            value: p.namaPegawai,
          ),
          InfoRow(
            label: 'NIK',
            value: p.nik,
          ),
          InfoRow(label: 'Cabang', value: p.cabang),
          InfoRow(label: 'Golongan / Jenjang Karier', value: p.golongan),
        ],
      ),
    );
  }

  // ==================== ISI LAPORAN ====================
  Widget _buildLaporanCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Isi Pengaduan'),
          const SizedBox(height: 8),
          InfoRow(label: 'Kategori', value: p.kategori),
          InfoRow(label: 'Judul', value: p.judul),
          InfoRow(
              label: 'Tanggal Pengaduan',
              value: formatTanggalIndonesia(p.tanggalPengaduan)),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEEF1F4)),
          const SizedBox(height: 10),
          Text(
            p.deskripsi,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: labelDark,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PROSES PENANGANAN ====================
  Widget _buildProsesCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Proses Penanganan'),
          const SizedBox(height: 8),
          if (p.kategoriDivisi != null)
            InfoRow(label: 'Kategori Divisi', value: p.kategoriDivisi!.label),
          if (p.eksekutor != null)
            InfoRow(label: 'Eksekutor', value: p.eksekutor!.label),
          if ((p.petugasInvestigasi ?? '').isNotEmpty)
            InfoRow(label: 'Petugas Investigasi', value: p.petugasInvestigasi!),
          if (p.hasilInvestigasi != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEEF1F4)),
            const SizedBox(height: 10),
            const Text('Hasil Investigasi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hintGrey)),
            const SizedBox(height: 4),
            Text(p.hasilInvestigasi!, style: const TextStyle(fontSize: 13, height: 1.5, color: labelDark)),
          ],
          if ((p.suratRekomendasi ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Surat Rekomendasi',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hintGrey)),
            const SizedBox(height: 4),
            Text(p.suratRekomendasi!, style: const TextStyle(fontSize: 13, height: 1.5, color: labelDark)),
          ],
          if (p.tindakLanjutDiminta != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEEF1F4)),
            const SizedBox(height: 10),
            const Text('Tindak Lanjut',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: hintGrey)),
            const SizedBox(height: 4),
            Text(p.tindakLanjutDiminta!, style: const TextStyle(fontSize: 13, height: 1.5, color: labelDark)),
            if (p.eksekutorTindakLanjut != null) ...[
              const SizedBox(height: 6),
              InfoRow(label: 'Eksekutor Tindak Lanjut', value: p.eksekutorTindakLanjut!.label),
            ],
          ],
        ],
      ),
    );
  }

  // ==================== FOTO BUKTI ====================
  Widget _buildFotoBuktiCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Bukti Foto (${p.fotoBukti.length})'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: p.fotoBukti.map((f) {
              return Container(
                width: 84,
                height: 84,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEEF1F4)),
                ),
                child: _buildFotoThumb(f),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Placeholder ikon untuk foto yang tidak dapat dimuat (data contoh lama
  /// tanpa berkas asli, atau path tidak valid).
  static const Widget _fotoPlaceholder = Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.image_rounded, color: hintGrey, size: 26),
      SizedBox(height: 4),
      Text('Bukti', style: TextStyle(fontSize: 9.5, color: hintGrey)),
    ],
  );

  /// Menampilkan thumbnail foto bukti. Di Flutter Web, path hasil
  /// image_picker berupa blob URL sehingga dimuat lewat [Image.network];
  /// di Android/iOS path berupa lokasi berkas asli sehingga dimuat lewat
  /// [Image.file]. Jika berkas/URL tidak valid (mis. data contoh lama),
  /// tampilkan ikon placeholder.
  Widget _buildFotoThumb(String path) {
    if (kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fotoPlaceholder,
      );
    }
    final file = File(path);
    if (!file.existsSync()) return _fotoPlaceholder;
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _fotoPlaceholder,
    );
  }

  // ==================== KETERANGAN (Ditolak / Selesai) ====================
  Widget _buildKeteranganCard({
    required String title,
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: labelDark),
          ),
        ],
      ),
    );
  }

  // ==================== TIMELINE RIWAYAT STATUS ====================
  Widget _buildTimelineCard() {
    final riwayat = p.riwayatStatus;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Riwayat Perubahan Status'),
          const SizedBox(height: 14),
          if (riwayat.isEmpty)
            const Text('Belum ada riwayat status.',
                style: TextStyle(fontSize: 12.5, color: hintGrey))
          else
            Column(
              children: List.generate(riwayat.length, (index) {
                final h = riwayat[index];
                final isLast = index == riwayat.length - 1;
                return _buildTimelineItem(h, isLast: isLast, isCurrent: isLast);
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(StatusHistoryEntry h,
      {required bool isLast, required bool isCurrent}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? h.status.color
                      : h.status.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  h.status.icon,
                  size: 15,
                  color: isCurrent ? Colors.white : h.status.color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: const Color(0xFFE0E4E9),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.status.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? h.status.color : labelDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatTanggalJam(h.tanggal)} · ${h.oleh}',
                    style: const TextStyle(fontSize: 11, color: hintGrey),
                  ),
                  if (h.keterangan != null && h.keterangan!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        h.keterangan!,
                        style:
                            const TextStyle(fontSize: 11.5, color: labelDark, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EXPORT PDF ====================
  Future<void> _unduhPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final bytes = await _generatePdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'LAPORAN_${p.nomorPengaduan}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<Uint8List> _generatePdf() async {
    final doc = pw.Document();
    final navyColor = PdfColor.fromInt(0xFF0D2C6E);
    final greyColor = PdfColor.fromInt(0xFF8C97A6);
    final statusColor = PdfColor.fromInt(p.status.color.value);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'PERUMDAM TIRTA DARMA AYU',
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold, color: navyColor),
          ),
          pw.Text(
            'Laporan Pengaduan Pegawai',
            style: pw.TextStyle(fontSize: 10.5, color: greyColor),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: greyColor, thickness: 0.7),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Nomor Pengaduan: ${p.nomorPengaduan}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  p.status.label,
                  style: pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('Identitas Pegawai', navyColor),
          _pdfInfoRow('Nama Pegawai', p.namaPegawai, greyColor),
          _pdfInfoRow('NIK', p.nik, greyColor),
          _pdfInfoRow('Cabang', p.cabang, greyColor),
          _pdfInfoRow('Golongan / Jenjang Karier', p.golongan, greyColor),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('Isi Pengaduan', navyColor),
          _pdfInfoRow('Kategori', p.kategori, greyColor),
          _pdfInfoRow(
              'Tanggal Pengaduan', formatTanggalIndonesia(p.tanggalPengaduan), greyColor),
          pw.SizedBox(height: 6),
          pw.Text(p.deskripsi,
              style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
          if (p.fotoBukti.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Bukti foto terlampir: ${p.fotoBukti.length} berkas',
                style: pw.TextStyle(fontSize: 9.5, color: greyColor)),
          ],
          if (p.status == PengaduanStatus.ditolakDirektur &&
              (p.alasanPenolakan ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _pdfSectionTitle('Alasan Penolakan', navyColor),
            pw.Text(p.alasanPenolakan!,
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
          ],
          if (p.status == PengaduanStatus.selesai &&
              (p.keteranganSelesai ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _pdfSectionTitle('Keterangan Penyelesaian', navyColor),
            pw.Text(p.keteranganSelesai!,
                style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
          ],
          pw.SizedBox(height: 14),
          _pdfSectionTitle('Riwayat Status', navyColor),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.4),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(3.6),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _pdfCell('Tanggal', bold: true),
                  _pdfCell('Status', bold: true),
                  _pdfCell('Oleh', bold: true),
                  _pdfCell('Keterangan', bold: true),
                ],
              ),
              ...p.riwayatStatus.map(
                (h) => pw.TableRow(
                  children: [
                    _pdfCell(formatTanggalJam(h.tanggal)),
                    _pdfCell(h.status.label),
                    _pdfCell(h.oleh),
                    _pdfCell(h.keterangan ?? '-'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Dokumen ini dibuat otomatis oleh SIMPEG Mobile pada '
            '${formatTanggalJam(DateTime.now())}.',
            style: pw.TextStyle(fontSize: 8.5, color: greyColor),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfSectionTitle(String text, PdfColor color) {
    return pw.Text(
      text,
      style: pw.TextStyle(
          fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: color),
    );
  }

  pw.Widget _pdfInfoRow(String label, String value, PdfColor greyColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: greyColor)),
          ),
          pw.Text(': ', style: pw.TextStyle(fontSize: 10, color: greyColor)),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: Color(0xFF7F8C8D),
      ),
    );
  }
}