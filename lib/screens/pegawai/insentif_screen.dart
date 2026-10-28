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
    // 2a. Prioritas Utama: Tabel payroll di Supabase (data resmi disetujui dengan rincian potongan lengkap)
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

    // 2b. Fallback: Tabel insentif di Supabase
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

    final slip = item.slip ??
        InsentifSlipDetail(
          perusahaan: 'PERUMDAM TIRTA DARMA AYU KAB. INDRAMAYU',
          bulanLabel: item.periode.toUpperCase(),
          nik: widget.user.nik,
          nama: widget.user.name,
          golongan: widget.user.golonganUntukSlip,
          unitKerja: widget.user.unitKerja,
          jabatan: widget.user.jabatan,
          insentifJabatan: 0,
          insentifPrestasi: 0,
          insentifTransportasi: 0,
          insentifPangan: 0,
          insentifBpjsKesehatan: 0,
          insentifPerumahan: 0,
          insentifBpjsTenagaKerja: 0,
          insentifPerusahaan: 0,
          lembur: 0,
          insentifPajak: 0,
          insentifAirMinum: 0,
          insentifKomunikasi: 0,
          potonganSanksiPerusahaan: 0,
          potonganPmiLain: 0,
          potonganDapenma: 0,
          potonganBpjsTenagaKerja: 0,
          potonganPerumahan: 0,
          potonganInsentifPerusahaan: 0,
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

  pw.Widget _buildSlipPdfContent(InsentifSlipDetail slip) {
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
          'DAFTAR INSENTIF & POTONGAN BULAN : ${slip.bulanLabel}',
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
            // Left Column (Identitas & Insentif)
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
                  _pdfRowItem('INSENTIF JABATAN', slip.insentifJabatan),
                  _pdfRowItem('INSENTIF PRESTASI', slip.insentifPrestasi),
                  _pdfRowItem(
                      'INSENTIF TRANSPORTASI', slip.insentifTransportasi),
                  _pdfRowItem('INSENTIF PANGAN', slip.insentifPangan),
                  _pdfRowItem(
                      'INSENTIF BPJS KESEHATAN', slip.insentifBpjsKesehatan),
                  _pdfRowItem('INSENTIF PERUMAHAN', slip.insentifPerumahan),
                  _pdfRowItem('INSENTIF BPJS TENAGA KERJA',
                      slip.insentifBpjsTenagaKerja),
                  _pdfRowItem(
                      'INSENTIF PERUSAHAAN', slip.insentifPerusahaan),
                  _pdfRowItem('LEMBUR', slip.lembur),
                  _pdfRowItem('INSENTIF PAJAK', slip.insentifPajak),
                  _pdfRowItem('INSENTIF AIR MINUM', slip.insentifAirMinum),
                  _pdfRowItem('INSENTIF KOMUNIKASI', slip.insentifKomunikasi),
                  _pdfRowItem('JUMLAH INSENTIF', slip.jumlahInsentif,
                      bold: true),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'SLIP INSENTIF INI SUDAH DISETUJUI OLEH DIREKSI\nNAMUN SEGALA BENTUK PENYALAH GUNAAN SLIP\nBUKAN MENJADI TANGGUNG JAWAB KAMI.',
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
                      slip.potonganPmiLain,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN DAPENMA', slip.potonganDapenma,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BPJS TENAGA KERJA',
                      slip.potonganBpjsTenagaKerja,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN PERUMAHAN', slip.potonganPerumahan,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN INSENTIF PERUSAHAAN',
                      slip.potonganInsentifPerusahaan,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN KORPRI', slip.potonganKorpri,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN PAJAK', slip.potonganPajak,
                      labelWidth: 195),
                  _pdfRowItem('POTONGAN BPJS KESEHATAN',
                      slip.potonganBpjsKesehatan,
                      labelWidth: 195),
                  _pdfRowItem('JUMLAH POTONGAN INSENTIF',
                      slip.jumlahPotonganInsentif,
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
                  _pdfRowItem('JUMLAH POTONGAN NON-INSENTIF',
                      slip.jumlahPotonganNonInsentif,
                      bold: true, labelWidth: 195),
                  _pdfRowItem(
                      'JUMLAH INSENTIF DITERIMA', slip.jumlahDiterima,
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