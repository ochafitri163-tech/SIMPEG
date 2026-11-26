import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/cuti_service.dart';
import '../../models/pengaduan_model.dart' show formatTanggalIndonesia;
import '../../theme/app_colors.dart';
import '../../utils/lampiran_helper.dart';
import '../../widgets/feature_scaffold.dart';

/// Halaman pratinjau & cetak fisik resmi **Surat Izin Cuti Pegawai**.
/// Mengikuti 100% struktur kedinasan `cuti/surat.blade.php` di website SIMPEG.
class SuratCutiScreen extends StatefulWidget {
  final PengajuanCuti cuti;
  @visibleForTesting
  final void Function(Uint8List pdfBytes)? onPdfGeneratedForTest;

  const SuratCutiScreen({
    super.key,
    required this.cuti,
    this.onPdfGeneratedForTest,
  });

  @override
  State<SuratCutiScreen> createState() => _SuratCutiScreenState();
}

class _SuratCutiScreenState extends State<SuratCutiScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF0284C7);

  late Future<CutiSuratResult> _future;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _future = CutiService.fetchSurat(widget.cuti.id, fallback: widget.cuti);
  }

  void _reload() {
    setState(() {
      _future = CutiService.fetchSurat(widget.cuti.id, fallback: widget.cuti);
    });
  }

  Future<void> _exportPdf(
    CutiSuratResult data, {
    required bool downloadOnly,
  }) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final bytes = await buildSuratCutiPdf(data.cuti, data.pejabatTtd);
      widget.onPdfGeneratedForTest?.call(bytes);
      final safeNo = data.cuti.noSurat.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final fileName = 'Surat_Izin_Cuti_$safeNo.pdf';

      bool ok;
      if (downloadOnly) {
        ok = await LampiranHelper.downloadBytes(
          bytes,
          fileName,
          'application/pdf',
        );
      } else {
        ok = await LampiranHelper.openBytesInViewer(
          bytes,
          fileName,
          'application/pdf',
        );
        if (!ok) {
          await Printing.layoutPdf(
            name: fileName,
            onLayout: (_) async => bytes,
          );
          ok = true;
        }
      }

      if (mounted && ok && downloadOnly) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF $fileName berhasil diunduh.'),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyiapkan PDF Surat Cuti: $e'),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Surat Izin Cuti',
      subtitle: 'Format resmi kedinasan PDAM Tirta Darma Ayu',
      icon: Icons.article_rounded,
      trailing: IconButton(
        onPressed: _reload,
        tooltip: 'Muat Ulang',
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      child: FutureBuilder<CutiSuratResult>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data ?? CutiSuratResult(cuti: widget.cuti);
          final cuti = result.cuti;
          final ttd = result.pejabatTtd;
          final isApproved = cuti.status == StatusCuti.disetujui;

          return Column(
            children: [
              // Action Toolbar mirip toolbar layar di website
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider(context)),
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: cuti.status.label,
                      color: isApproved
                          ? const Color(0xFF16A34A)
                          : (cuti.status == StatusCuti.ditolak
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFD97706)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _generating
                              ? null
                              : () => _exportPdf(result, downloadOnly: true),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Unduh PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(color: _accent),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _generating
                              ? null
                              : () => _exportPdf(result, downloadOnly: false),
                          icon: _generating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.print_rounded, size: 16),
                          label: const Text('Cetak / PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 740),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildKopSurat(),
                              const SizedBox(height: 16),
                              Center(
                                child: Column(
                                  children: [
                                    Text(
                                      'SURAT IZIN ${cuti.jenis.toUpperCase()}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.underline,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Nomor: ${cuti.noSurat}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Berdasarkan Peraturan Direksi PERUMDAM Tirta Darma Ayu Kabupaten Indramayu tentang Manajemen Sumber Daya Manusia serta permohonan izin cuti yang bersangkutan, dengan ini Direksi / Bagian Sumber Daya Manusia memberikan Izin Cuti kepada Pegawai:',
                                textAlign: TextAlign.justify,
                              ),
                              const SizedBox(height: 12),
                              _infoRow('Nama Pegawai', cuti.namaPegawai, bold: true),
                              _infoRow('Nomor Induk Karyawan (NIK)', cuti.nik, bold: true),
                              _infoRow('Pangkat / Golongan', cuti.golongan),
                              _infoRow('Jabatan', cuti.jabatan),
                              _infoRow('Unit Kerja / Bagian', cuti.unitKerja),
                              const SizedBox(height: 12),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(text: 'Untuk menjalankan '),
                                    TextSpan(
                                      text: cuti.jenis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const TextSpan(
                                        text: ' dengan ketentuan sebagai berikut:'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              _infoRow('Lamanya Cuti', '${cuti.jumlahHari} hari kerja',
                                  bold: true),
                              _infoRow(
                                'Terhitung Mulai Tanggal',
                                '${formatTanggalIndonesia(cuti.tanggalMulai)} s/d ${formatTanggalIndonesia(cuti.tanggalSelesai)}',
                                bold: true,
                              ),
                              _infoRow('Alasan / Keperluan', cuti.alasan),
                              _infoRow('Alamat Selama Cuti', cuti.alamatCuti),
                              _infoRow('Nomor Telepon / HP', cuti.noTelp),
                              const SizedBox(height: 12),
                              const Text(
                                'Ketentuan Selama Menjalankan Cuti:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              _diktumItem(1,
                                  'Sebelum menjalankan cuti, yang bersangkutan wajib menyelesaikan pekerjaan mendesak serta menyerahkan tugas dan wewenang kepada atasan langsung atau pejabat/rekan kerja pengganti sementara yang ditunjuk.'),
                              _diktumItem(2,
                                  'Setelah masa cuti berakhir, yang bersangkutan diwajibkan melapor kembali kepada Pimpinan Unit Kerja dan melaksanakan tugas kedinasan sebagaimana mestinya.'),
                              _diktumItem(3,
                                  'Apabila terdapat kepentingan dinas mendesak yang membutuhkan kehadiran yang bersangkutan, perusahaan berhak memanggil kembali sebelum masa cuti berakhir.'),
                              const SizedBox(height: 10),
                              const Text(
                                'Demikian Surat Izin Cuti ini dibuat dan diberikan untuk dipergunakan sebagaimana mestinya.',
                                textAlign: TextAlign.justify,
                              ),
                              const SizedBox(height: 18),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${ttd.kota}, ${formatTanggalIndonesia(cuti.tanggalSurat)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _ttdBlock(
                                      header: 'PEMOHON CUTI,',
                                      sub: 'Pegawai Yang Bersangkutan',
                                      nama: cuti.namaPegawai,
                                      nik: 'NIK. ${cuti.nik}',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ttdBlock(
                                      header: 'MENYETUJUI,',
                                      sub: 'Atasan Langsung',
                                      nama: '( ............................ )',
                                      nik: 'NIK. ....................',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ttdBlock(
                                      header: ttd.pembuat.label,
                                      sub: ttd.pembuat.jabatan,
                                      nama: ttd.pembuat.nama,
                                      nik: 'NIK. ${ttd.pembuat.nik}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Tembusan disampaikan Kepada Yth:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '1. Direktur Utama PERUMDAM Tirta Darma Ayu Kabupaten Indramayu;\n'
                                '2. Direktur Umum PERUMDAM Tirta Darma Ayu Kabupaten Indramayu;\n'
                                '3. Manajer / Kepala ${cuti.unitKerja};\n'
                                '4. Pertinggal / Arsip Bagian Sumber Daya Manusia.',
                                style: const TextStyle(fontSize: 10.5, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKopSurat() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 48,
              height: 48,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.water_drop_rounded,
                size: 38,
                color: _navy,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                children: [
                  Text(
                    'PEMERINTAH KABUPATEN INDRAMAYU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'PERUSAHAAN UMUM DAERAH AIR MINUM TIRTA DARMA AYU',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _navy,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Jalan Letnan Jenderal Suprapto No. 25/E Indramayu - Jawa Barat 45212\n'
                    'Telp: (0234) 272111, 274111 • Faksimile: (0234) 274112',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 2, color: Colors.black),
        const SizedBox(height: 2),
        Container(height: 0.8, color: Colors.black),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(label, style: const TextStyle(color: Color(0xFF334155))),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diktumItem(int nomor, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 18, child: Text('$nomor.')),
          Expanded(child: Text(text, textAlign: TextAlign.justify)),
        ],
      ),
    );
  }

  Widget _ttdBlock({
    required String header,
    required String sub,
    required String nama,
    required String nik,
  }) {
    return Column(
      children: [
        Text(
          header,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 36),
        Text(
          nama,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
        Text(
          nik,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 8.5),
        ),
      ],
    );
  }
}

/// Menghasilkan dokumen PDF resmi A4 **Surat Izin Cuti** sesuai kop & layout
/// kedinasan pada website `cuti/surat.blade.php`.
Future<Uint8List> buildSuratCutiPdf(
  PengajuanCuti cuti,
  PejabatTtdCuti pejabatTtd,
) async {
  pw.MemoryImage? logoImage;
  try {
    final raw = await rootBundle.load('assets/images/logo.png');
    logoImage = pw.MemoryImage(raw.buffer.asUint8List());
  } catch (_) {}

  final pdf = pw.Document();
  const darkSlate = PdfColor.fromInt(0xFF0F172A);
  const greyText = PdfColor.fromInt(0xFF475569);

  pw.Widget pdfInfoRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 155,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 10, color: darkSlate)),
          ),
          pw.Text(': ',
              style: const pw.TextStyle(fontSize: 10, color: darkSlate)),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '-' : value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: darkSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget pdfSignCol({
    required String title,
    required String roleSub,
    required String nama,
    required String nik,
  }) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            roleSub,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8.5, color: greyText),
          ),
          pw.SizedBox(height: 44),
          pw.Text(
            nama,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
          pw.Text(
            nik,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8.5),
          ),
        ],
      ),
    );
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 38, 44, 38),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null) ...[
                  pw.Image(logoImage, width: 54, height: 54),
                  pw.SizedBox(width: 14),
                ],
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'PEMERINTAH KABUPATEN INDRAMAYU',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 11.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'PERUSAHAAN UMUM DAERAH AIR MINUM TIRTA DARMA AYU',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 12.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Jalan Letnan Jenderal Suprapto No. 25/E Indramayu - Jawa Barat 45212',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                      pw.Text(
                        'Telepon: (0234) 272111, 274111 | Faksimile: (0234) 274112 | Email: pdam.tda@gmail.com',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 2, color: PdfColors.black),
            pw.SizedBox(height: 1.5),
            pw.Container(height: 0.7, color: PdfColors.black),
            pw.SizedBox(height: 18),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'SURAT IZIN ${cuti.jenis.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Nomor: ${cuti.noSurat}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              '      Berdasarkan Peraturan Direksi PERUMDAM Tirta Darma Ayu Kabupaten Indramayu tentang Manajemen Sumber Daya Manusia serta permohonan izin cuti yang bersangkutan, dengan ini Direksi / Bagian Sumber Daya Manusia memberikan Izin Cuti kepada Pegawai:',
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2.5),
            ),
            pw.SizedBox(height: 10),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16),
              child: pw.Column(
                children: [
                  pdfInfoRow('Nama Pegawai', cuti.namaPegawai, bold: true),
                  pdfInfoRow('Nomor Induk Karyawan (NIK)', cuti.nik, bold: true),
                  pdfInfoRow('Pangkat / Golongan', cuti.golongan),
                  pdfInfoRow('Jabatan', cuti.jabatan),
                  pdfInfoRow('Unit Kerja / Bagian', cuti.unitKerja),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '      Untuk menjalankan ${cuti.jenis} dengan ketentuan sebagai berikut:',
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            pw.SizedBox(height: 8),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16),
              child: pw.Column(
                children: [
                  pdfInfoRow('Lamanya Cuti', '${cuti.jumlahHari} hari kerja',
                      bold: true),
                  pdfInfoRow(
                    'Terhitung Mulai Tanggal',
                    '${formatTanggalIndonesia(cuti.tanggalMulai)} s/d ${formatTanggalIndonesia(cuti.tanggalSelesai)}',
                    bold: true,
                  ),
                  pdfInfoRow('Alasan / Keperluan', cuti.alasan),
                  pdfInfoRow('Alamat Selama Cuti', cuti.alamatCuti),
                  pdfInfoRow('Nomor Telepon / HP', cuti.noTelp),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Ketentuan Selama Menjalankan Cuti:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            for (final entry in const [
              '1. Sebelum menjalankan cuti, yang bersangkutan wajib menyelesaikan pekerjaan mendesak serta menyerahkan tugas dan wewenang kepada atasan langsung atau pejabat/rekan kerja pengganti sementara yang ditunjuk.',
              '2. Setelah masa cuti berakhir, yang bersangkutan diwajibkan melapor kembali kepada Pimpinan Unit Kerja dan melaksanakan tugas kedinasan sebagaimana mestinya.',
              '3. Apabila terdapat kepentingan dinas mendesak yang membutuhkan kehadiran yang bersangkutan, perusahaan berhak memanggil kembali sebelum masa cuti berakhir.',
            ])
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Text(
                  entry,
                  textAlign: pw.TextAlign.justify,
                  style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.8),
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Text(
              '      Demikian Surat Izin Cuti ini dibuat dan diberikan untuk dipergunakan sebagaimana mestinya.',
              textAlign: pw.TextAlign.justify,
              style: const pw.TextStyle(fontSize: 10.5),
            ),
            pw.SizedBox(height: 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '${pejabatTtd.kota}, ${formatTanggalIndonesia(cuti.tanggalSurat)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pdfSignCol(
                  title: 'PEMOHON CUTI,',
                  roleSub: 'Pegawai Yang Bersangkutan',
                  nama: cuti.namaPegawai,
                  nik: 'NIK. ${cuti.nik}',
                ),
                pw.SizedBox(width: 8),
                pdfSignCol(
                  title: 'MENYETUJUI,',
                  roleSub: 'Atasan Langsung / Pimpinan Unit',
                  nama: '( .................................... )',
                  nik: 'NIP / NIK. ..........................',
                ),
                pw.SizedBox(width: 8),
                pdfSignCol(
                  title: pejabatTtd.pembuat.label,
                  roleSub: pejabatTtd.pembuat.jabatan,
                  nama: pejabatTtd.pembuat.nama,
                  nik: 'NIK. ${pejabatTtd.pembuat.nik}',
                ),
              ],
            ),
            pw.Spacer(),
            pw.Text(
              'Tembusan disampaikan Kepada Yth:',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              '1. Direktur Utama PERUMDAM Tirta Darma Ayu Kabupaten Indramayu;\n'
              '2. Direktur Umum PERUMDAM Tirta Darma Ayu Kabupaten Indramayu;\n'
              '3. Manajer / Kepala ${cuti.unitKerja};\n'
              '4. Pertinggal / Arsip Bagian Sumber Daya Manusia.',
              style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.5),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
