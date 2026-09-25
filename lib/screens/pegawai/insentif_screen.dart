import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pegawai_data.dart';
import '../../models/user_role.dart';
import '../../services/api_service.dart';
import 'payroll_screen.dart' show formatRupiah;
import '../../theme/app_colors.dart';

/// Helper: konversi value (bisa num/double/int/String) ke int secara aman
int _toInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  if (val is num) return val.toInt();
  if (val is String) {
    final cleaned = val.replaceAll(RegExp(r'[^0-9\-]'), '');
    return int.tryParse(cleaned) ?? 0;
  }
  return 0;
}

/// Helper untuk memetakan satu baris record (dari ApiService backend atau Supabase)
/// ke model [InsentifItem] dan [InsentifSlipDetail]
InsentifItem _rowToInsentifItem(Map<String, dynamic> row, AppUser user) {
  final int bulan = _toInt(row['bulan'] ?? (row['month'] ?? 0));
  final int tahun = _toInt(row['tahun'] ?? (row['year'] ?? 0));

  const bulanNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  String periode = (row['periode'] ?? '').toString().trim();
  if (periode.isEmpty || periode == '-') {
    if (bulan >= 1 && bulan <= 12) {
      periode = '${bulanNames[bulan]} ${tahun > 0 ? tahun : DateTime.now().year}';
    } else {
      periode = 'Tahun ${tahun > 0 ? tahun : DateTime.now().year}';
    }
  }

  final slip = InsentifSlipDetail(
    bulanLabel: periode.toUpperCase(),
    nik: (row['nik'] ?? user.nik).toString(),
    nama: (row['nama'] ?? user.name).toString(),
    golongan: (row['golongan'] ?? user.golonganUntukSlip).toString(),
    unitKerja: (row['unit_kerja'] ?? user.unitKerja).toString(),
    jabatan: (row['jabatan'] ?? user.jabatan).toString(),
    // Komponen Penerimaan Insentif (Non-Gapok PDAM)
    insentifJabatan: _toInt(row['insentif_jabatan'] ?? row['tunjangan_jabatan']),
    insentifPrestasi: _toInt(row['insentif_prestasi'] ?? row['tunjangan_prestasi']),
    insentifTransportasi: _toInt(row['insentif_transportasi'] ?? row['tunjangan_transportasi']),
    insentifPangan: _toInt(row['insentif_pangan'] ?? row['tunjangan_pangan']),
    insentifBpjsKesehatan: _toInt(row['insentif_bpjs_kesehatan'] ?? (row['tunjangan_bpjs_kesehatan'] ?? row['tunjangan_bpjskes'])),
    insentifPerumahan: _toInt(row['insentif_perumahan'] ?? row['tunjangan_perumahan']),
    insentifBpjsTenagaKerja: _toInt(row['insentif_bpjs_tenaga_kerja'] ?? (row['tunjangan_bpjs_tenaga_kerja'] ?? row['tunjangan_bpjstk'])),
    insentifPerusahaan: _toInt(row['insentif_perusahaan'] ?? row['tunjangan_perusahaan']),
    lembur: _toInt(row['lembur']),
    insentifPajak: _toInt(row['insentif_pajak'] ?? row['tunjangan_pajak']),
    insentifAirMinum: _toInt(row['insentif_air_minum'] ?? (row['tunjangan_air_minum'] ?? row['tunjangan_airminum'])),
    insentifKomunikasi: _toInt(row['insentif_komunikasi'] ?? row['tunjangan_komunikasi']),
    // Potongan Insentif
    potonganSanksiPerusahaan: _toInt(row['potongan_sanksi_perusahaan'] ?? row['potongan_sanksi']),
    potonganPmiLain: _toInt(row['potongan_pmi_lain'] ?? (row['potongan_trandist_pmi_lain'] ?? row['potongan_lain'])),
    potonganDapenma: _toInt(row['potongan_dapenma']),
    potonganBpjsTenagaKerja: _toInt(row['potongan_bpjs_tenaga_kerja'] ?? row['potongan_bpjstk']),
    potonganPerumahan: _toInt(row['potongan_perumahan']),
    potonganInsentifPerusahaan: _toInt(row['potongan_insentif_perusahaan'] ?? (row['potongan_tunjangan_perusahaan'] ?? row['potongan_tperusahaan'])),
    potonganKorpri: _toInt(row['potongan_korpri']),
    potonganPajak: _toInt(row['potongan_pajak']),
    potonganBpjsKesehatan: _toInt(row['potongan_bpjs_kesehatan'] ?? row['potongan_bpjskes']),
    // Potongan Non-Insentif
    potonganKoperasi: _toInt(row['potongan_koperasi']),
    potonganDarmaWanita: _toInt(row['potongan_darma_wanita'] ?? row['potongan_darmawanita']),
    potonganRekeningAirMinum: _toInt(row['potongan_rekening_air_minum'] ?? row['potongan_ledeng']),
    potonganKas: _toInt(row['potongan_kas']),
    potonganBankBjb: _toInt(row['potongan_bank_bjb'] ?? row['potongan_bjb']),
    potonganBankBjbs: _toInt(row['potongan_bank_bjbs'] ?? row['potongan_bjbs']),
    potonganBankBtn: _toInt(row['potongan_bank_btn'] ?? row['potongan_btn']),
    potonganBankBpr: _toInt(row['potongan_bank_bpr'] ?? row['potongan_bpr']),
    potonganAsuransi: _toInt(row['potongan_asuransi']),
    potonganZakatProfesi: _toInt(row['potongan_zakat_profesi'] ?? row['potongan_zakat']),
  );

  final calculatedJumlah = slip.jumlahDiterima;
  final explicitJumlah = _toInt(row['insentif_diterima'] ?? (row['nominal'] ?? row['jumlah']));

  return InsentifItem(
    judul: (row['judul'] ?? 'Slip Insentif $periode').toString(),
    periode: periode,
    jumlah: explicitJumlah > 0 ? explicitJumlah : calculatedJumlah,
    slip: slip,
  );
}

/// Ambil data insentif resmi pegawai dari backend Laravel (ApiService)
/// atau fallback ke Supabase
Future<List<InsentifItem>> _fetchInsentif(AppUser user) async {
  // 1. Prioritas Utama: Ambil dari API Laravel Backend
  try {
    final res = await ApiService.getInsentif(nik: user.nik);
    if (res['success'] == true && res['data'] != null) {
      final data = res['data'];
      final List<InsentifItem> items = [];

      if (data['list'] is List && (data['list'] as List).isNotEmpty) {
        for (final item in (data['list'] as List)) {
          if (item is Map<String, dynamic>) {
            items.add(_rowToInsentifItem(item, user));
          } else if (item is Map) {
            items.add(_rowToInsentifItem(Map<String, dynamic>.from(item), user));
          }
        }
      } else if (data['insentif'] is Map) {
        items.add(_rowToInsentifItem(Map<String, dynamic>.from(data['insentif'] as Map), user));
      }

      if (items.isNotEmpty) {
        return items;
      }
    }
  } catch (e) {
    debugPrint('Gagal fetch insentif dari ApiService: $e');
  }

  // 2. Fallback Supabase: Dapatkan target ID pegawai
  String? userId = Supabase.instance.client.auth.currentUser?.id;
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

  if (userId != null) {
    // 2a. Coba tabel insentif di Supabase
    try {
      final rows = await Supabase.instance.client
          .from('insentif')
          .select()
          .eq('pegawai_id', userId)
          .order('created_at', ascending: false);

      if ((rows as List).isNotEmpty) {
        return (rows as List)
            .map((row) => _rowToInsentifItem(Map<String, dynamic>.from(row as Map), user))
            .toList();
      }
    } catch (_) {}

    // 2b. Fallback tabel payroll di Supabase
    try {
      final payrollRows = await Supabase.instance.client
          .from('payroll')
          .select()
          .eq('pegawai_id', userId)
          .order('tahun', ascending: false)
          .order('bulan', ascending: false);

      if ((payrollRows as List).isNotEmpty) {
        return (payrollRows as List)
            .map((row) => _rowToInsentifItem(Map<String, dynamic>.from(row as Map), user))
            .toList();
      }
    } catch (_) {}
  }

  return [];
}

/// Halaman Insentif — didesain mengikuti mockup UI (kartu ringkasan ungu
/// "Insentif · <periode>", daftar "Riwayat Insentif", dan tombol
/// "Cek Detail" yang mengunduh slip insentif & potongan lengkap dalam PDF).
class InsentifScreen extends StatefulWidget {
  final AppUser user;

  const InsentifScreen({super.key, required this.user});

  @override
  State<InsentifScreen> createState() => _InsentifScreenState();
}

class _InsentifScreenState extends State<InsentifScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color purpleStart = Color(0xFF9B59D9);
  static const Color purpleEnd = Color(0xFF6C3FB5);

  bool _isGenerating = false;
  late Future<List<InsentifItem>> _insentifFuture;

  @override
  void initState() {
    super.initState();
    _insentifFuture = _fetchInsentif(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _insentifFuture = _fetchInsentif(widget.user));
    await _insentifFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF10151C) : const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: FutureBuilder<List<InsentifItem>>(
              future: _insentifFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Gagal memuat data insentif: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                      ),
                    ),
                  );
                }

                final riwayatSemua = snapshot.data ?? [];
                final InsentifItem? terbaru =
                    riwayatSemua.isNotEmpty ? riwayatSemua.first : null;

                if (terbaru == null) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'Belum ada data insentif',
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
                      const SizedBox(height: 26),
                      _buildSectionLabel('RIWAYAT INSENTIF'),
                      const SizedBox(height: 10),
                      _buildRiwayatCard(riwayatSemua),
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
                    'Insentif Pegawai',
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

  Widget _buildHeroCard(InsentifItem item) {
    final total = item.slip?.jumlahDiterima ?? item.jumlah;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [purpleStart, purpleEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: purpleEnd.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Insentif Pegawai · ${item.periode}',
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
          const SizedBox(height: 4),
          Text(
            item.judul,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
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

  Widget _buildRiwayatCard(List<InsentifItem> riwayat) {
    if (riwayat.isEmpty) {
      return _WhiteCard(
        child: Text(
          'Belum ada riwayat insentif',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context)),
        ),
      );
    }
    const icons = [
      Icons.star_rounded,
      Icons.wb_sunny_rounded,
      Icons.check_box_rounded,
    ];
    return _WhiteCard(
      child: Column(
        children: [
          for (int i = 0; i < riwayat.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider(context)),
            InkWell(
              onTap: riwayat[i].slip == null
                  ? null
                  : () => _downloadInsentifPdf(riwayat[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icons[i % icons.length],
                          color: const Color(0xFF8E44AD), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riwayat[i].judul,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: navy,
                            ),
                          ),
                          Text(
                            riwayat[i].periode,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatRupiah(
                          riwayat[i].slip?.jumlahDiterima ?? riwayat[i].jumlah),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCekDetailButton(InsentifItem item) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : () => _downloadInsentifPdf(item),
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

  Future<void> _downloadInsentifPdf(InsentifItem item) async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generateInsentifPdf(item);
      final fileLabel =
          (item.slip?.bulanLabel ?? item.periode).replaceAll(' ', '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'INSENTIF_$fileLabel.pdf',
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

  Future<Uint8List> _generateInsentifPdf(InsentifItem item) async {
    final doc = pw.Document();
    const navyColor = PdfColor.fromInt(0xFF0D2C6E);
    const greyColor = PdfColor.fromInt(0xFF8C97A6);

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
    InsentifSlipDetail slip,
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
            'DAFTAR INSENTIF & POTONGAN BULAN : ${slip.bulanLabel}',
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
              child: _buildInsentifColumn(slip, navyColor, greyColor),
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
              'JUMLAH INSENTIF DITERIMA',
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
          'Slip insentif ini sudah disetujui oleh Direksi. Segala bentuk '
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

  pw.Widget _buildInsentifColumn(
    InsentifSlipDetail slip,
    PdfColor navyColor,
    PdfColor greyColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'INSENTIF',
          style: pw.TextStyle(
              fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: greyColor),
        ),
        pw.SizedBox(height: 6),
        _pdfSlipLine('Insentif Jabatan', slip.insentifJabatan),
        _pdfSlipLine('Insentif Prestasi', slip.insentifPrestasi),
        _pdfSlipLine('Insentif Transportasi', slip.insentifTransportasi),
        _pdfSlipLine('Insentif Pangan', slip.insentifPangan),
        _pdfSlipLine('Insentif BPJS Kesehatan', slip.insentifBpjsKesehatan),
        _pdfSlipLine('Insentif Perumahan', slip.insentifPerumahan),
        _pdfSlipLine(
            'Insentif BPJS Tenaga Kerja', slip.insentifBpjsTenagaKerja),
        _pdfSlipLine('Insentif Perusahaan', slip.insentifPerusahaan),
        _pdfSlipLine('Lembur', slip.lembur),
        _pdfSlipLine('Insentif Pajak', slip.insentifPajak),
        _pdfSlipLine('Insentif Air Minum', slip.insentifAirMinum),
        _pdfSlipLine('Insentif Komunikasi', slip.insentifKomunikasi),
        pw.SizedBox(height: 4),
        pw.Divider(color: greyColor, thickness: 0.5),
        _pdfSlipLine('Jumlah Insentif', slip.jumlahInsentif,
            bold: true, color: navyColor),
      ],
    );
  }

  pw.Widget _buildPotonganColumn(
    InsentifSlipDetail slip,
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
        _pdfSlipLine('Potongan PMI / Lain-lain', slip.potonganPmiLain),
        _pdfSlipLine('Potongan Dapenma', slip.potonganDapenma),
        _pdfSlipLine(
            'Potongan BPJS Tenaga Kerja', slip.potonganBpjsTenagaKerja),
        _pdfSlipLine('Potongan Perumahan', slip.potonganPerumahan),
        _pdfSlipLine(
            'Potongan Insentif Perusahaan', slip.potonganInsentifPerusahaan),
        _pdfSlipLine('Potongan Korpri', slip.potonganKorpri),
        _pdfSlipLine('Potongan Pajak', slip.potonganPajak),
        _pdfSlipLine('Potongan BPJS Kesehatan', slip.potonganBpjsKesehatan),
        pw.SizedBox(height: 4),
        pw.Divider(color: greyColor, thickness: 0.5),
        _pdfSlipLine('Jumlah Potongan Insentif', slip.jumlahPotonganInsentif,
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
            'Jumlah Potongan Non-Insentif', slip.jumlahPotonganNonInsentif,
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
    InsentifItem item,
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
          'Slip Insentif Pegawai',
          style: pw.TextStyle(
              fontSize: 20, fontWeight: pw.FontWeight.bold, color: navyColor),
        ),
        pw.SizedBox(height: 2),
        pw.Text('Periode ${item.periode}',
            style: pw.TextStyle(fontSize: 12, color: greyColor)),
        pw.SizedBox(height: 20),
        pw.Divider(color: greyColor),
        pw.SizedBox(height: 14),
        _pdfRow('Judul', item.judul, navyColor),
        pw.SizedBox(height: 12),
        pw.Divider(color: greyColor),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Jumlah Diterima',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: navyColor)),
            pw.Text(formatRupiah(item.jumlah),
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