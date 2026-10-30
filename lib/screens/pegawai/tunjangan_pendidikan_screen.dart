import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pegawai_data.dart';
import '../../models/user_role.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

// ============================================================================
// MODEL & HELPER DATA
// ============================================================================

/// Model resmi rincian Tunjangan Pendidikan pegawai dari tabel `tunjangan_pendidikan`
class TunjanganPendidikanItem {
  final int? id;
  final String tahun;
  final String bulanLabel;
  final String tanggalCair;
  final String status;
  final int gapok;
  final int tunjanganIstri;
  final int tunjanganAnak;
  final int potonganKoperasi;
  final int potonganKas;

  const TunjanganPendidikanItem({
    this.id,
    required this.tahun,
    required this.bulanLabel,
    required this.tanggalCair,
    required this.status,
    required this.gapok,
    required this.tunjanganIstri,
    required this.tunjanganAnak,
    required this.potonganKoperasi,
    required this.potonganKas,
  });

  int get totalPendapatan => gapok + tunjanganIstri + tunjanganAnak;
  int get totalPotongan => potonganKoperasi + potonganKas;
  int get totalDiterima => totalPendapatan - totalPotongan;
}

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

InsentifItem _rowToInsentifItem(
    Map<String, dynamic> row, Map<String, String> profile) {
  final int bulan = _toInt(row['bulan'] ?? (row['month'] ?? 0));
  final int tahun = _toInt(row['tahun'] ?? (row['year'] ?? 0));

  const bulanNames = [
    '',
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
    'Desember'
  ];

  String periode = (row['periode'] ?? '').toString().trim();
  if (periode.isEmpty || periode == '-') {
    if (bulan >= 1 && bulan <= 12) {
      periode =
          '${bulanNames[bulan]} ${tahun > 0 ? tahun : DateTime.now().year}';
    } else {
      periode = 'Tahun ${tahun > 0 ? tahun : DateTime.now().year}';
    }
  }

  final slip = InsentifSlipDetail(
    bulanLabel: periode.toUpperCase(),
    nik: (row['nik'] ?? profile['nik'] ?? '-').toString(),
    nama: (row['nama'] ?? profile['nama'] ?? '-').toString(),
    golongan: (row['golongan'] ?? profile['golongan'] ?? '-').toString(),
    unitKerja: (row['unit_kerja'] ?? profile['unitKerja'] ?? '-').toString(),
    jabatan: (row['jabatan'] ?? profile['jabatan'] ?? '-').toString(),
    // Komponen Penerimaan Insentif (Non-Gapok PDAM)
    insentifJabatan:
        _toInt(row['insentif_jabatan'] ?? row['tunjangan_jabatan']),
    insentifPrestasi:
        _toInt(row['insentif_prestasi'] ?? row['tunjangan_prestasi']),
    insentifTransportasi:
        _toInt(row['insentif_transportasi'] ?? row['tunjangan_transportasi']),
    insentifPangan: _toInt(row['insentif_pangan'] ?? row['tunjangan_pangan']),
    insentifBpjsKesehatan: _toInt(row['insentif_bpjs_kesehatan'] ??
        (row['tunjangan_bpjs_kesehatan'] ?? row['tunjangan_bpjskes'])),
    insentifPerumahan:
        _toInt(row['insentif_perumahan'] ?? row['tunjangan_perumahan']),
    insentifBpjsTenagaKerja: _toInt(row['insentif_bpjs_tenaga_kerja'] ??
        (row['tunjangan_bpjs_tenaga_kerja'] ?? row['tunjangan_bpjstk'])),
    insentifPerusahaan:
        _toInt(row['insentif_perusahaan'] ?? row['tunjangan_perusahaan']),
    lembur: _toInt(row['lembur']),
    insentifPajak: _toInt(row['insentif_pajak'] ?? row['tunjangan_pajak']),
    insentifAirMinum: _toInt(row['insentif_air_minum'] ??
        (row['tunjangan_air_minum'] ?? row['tunjangan_airminum'])),
    insentifKomunikasi:
        _toInt(row['insentif_komunikasi'] ?? row['tunjangan_komunikasi']),
    // Potongan Insentif
    potonganSanksiPerusahaan:
        _toInt(row['potongan_sanksi_perusahaan'] ?? row['potongan_sanksi']),
    potonganPmiLain: _toInt(row['potongan_pmi_lain'] ??
        (row['potongan_trandist_pmi_lain'] ?? row['potongan_lain'])),
    potonganDapenma: _toInt(row['potongan_dapenma']),
    potonganBpjsTenagaKerja:
        _toInt(row['potongan_bpjs_tenaga_kerja'] ?? row['potongan_bpjstk']),
    potonganPerumahan: _toInt(row['potongan_perumahan']),
    potonganInsentifPerusahaan: _toInt(row['potongan_insentif_perusahaan'] ??
        (row['potongan_tunjangan_perusahaan'] ??
            row['potongan_tperusahaan'])),
    potonganKorpri: _toInt(row['potongan_korpri']),
    potonganPajak: _toInt(row['potongan_pajak']),
    potonganBpjsKesehatan:
        _toInt(row['potongan_bpjs_kesehatan'] ?? row['potongan_bpjskes']),
    // Potongan Non-Insentif
    potonganKoperasi: _toInt(row['potongan_koperasi']),
    potonganDarmaWanita: _toInt(
        row['potongan_darma_wanita'] ?? row['potongan_darmawanita']),
    potonganRekeningAirMinum: _toInt(
        row['potongan_rekening_air_minum'] ?? row['potongan_ledeng']),
    potonganKas: _toInt(row['potongan_kas']),
    potonganBankBjb:
        _toInt(row['potongan_bank_bjb'] ?? row['potongan_bjb']),
    potonganBankBjbs:
        _toInt(row['potongan_bank_bjbs'] ?? row['potongan_bjbs']),
    potonganBankBtn:
        _toInt(row['potongan_bank_btn'] ?? row['potongan_btn']),
    potonganBankBpr:
        _toInt(row['potongan_bank_bpr'] ?? row['potongan_bpr']),
    potonganAsuransi: _toInt(row['potongan_asuransi']),
    potonganZakatProfesi:
        _toInt(row['potongan_zakat_profesi'] ?? row['potongan_zakat']),
  );

  final calculatedJumlah = slip.jumlahDiterima;
  final explicitJumlah =
      _toInt(row['insentif_diterima'] ?? (row['nominal'] ?? row['jumlah']));

  return InsentifItem(
    judul: (row['judul'] ?? 'Slip Insentif $periode').toString(),
    periode: periode,
    jumlah: explicitJumlah > 0 ? explicitJumlah : calculatedJumlah,
    slip: slip,
  );
}

Future<String?> _resolvePegawaiId(AppUser? user) async {
  String? userId = Supabase.instance.client.auth.currentUser?.id;

  String? nik = user?.nik;
  if (nik == null || nik.isEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      nik = prefs.getString('user_nik');
    } catch (_) {}
  }

  if (nik != null && nik.isNotEmpty) {
    try {
      final peg = await Supabase.instance.client
          .from('pegawai')
          .select('id')
          .eq('nik', nik)
          .maybeSingle();
      if (peg != null && peg['id'] != null) {
        return peg['id'].toString();
      }
    } catch (_) {}
  }

  return userId;
}

Future<Map<String, String>> _fetchPegawaiProfile(AppUser? user) async {
  String nik = user?.nik ?? '';
  String nama = user?.name ?? '';
  String golongan = user?.golonganUntukSlip ?? '';
  String unitKerja = user?.unitKerja ?? '';
  String jabatan = user?.jabatan ?? '';

  try {
    final userId = await _resolvePegawaiId(user);
    if (userId != null) {
      final row = await Supabase.instance.client
          .from('pegawai')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row != null) {
        if (nik.isEmpty) nik = (row['nik'] ?? '').toString();
        if (nama.isEmpty) nama = (row['name'] ?? '').toString();
        if (golongan.isEmpty) {
          golongan =
              (row['golongan_detail'] ?? row['golongan'] ?? '').toString();
        }
        if (unitKerja.isEmpty) unitKerja = (row['unit_kerja'] ?? '').toString();
        if (jabatan.isEmpty) jabatan = (row['jabatan'] ?? '').toString();
      }
    }
  } catch (_) {}

  return {
    'nik': nik.isEmpty ? '-' : nik,
    'nama': nama.isEmpty ? '-' : nama,
    'golongan': golongan.isEmpty ? '-' : golongan,
    'unitKerja': unitKerja.isEmpty ? '-' : unitKerja,
    'jabatan': jabatan.isEmpty ? '-' : jabatan,
  };
}

/// Mengambil data resmi Tunjangan Pendidikan dari tabel `tunjangan_pendidikan`
/// yang memuat rincian asli GAPOK, Tunjangan Istri/Anak, dan Potongan
Future<List<TunjanganPendidikanItem>> _fetchTunjanganPendidikan(
    AppUser? user) async {
  // 0. ApiService Laravel Backend (jika NIK tersedia)
  final nik = user?.nik;
  if (nik != null && nik.isNotEmpty && nik != '-') {
    try {
      final res = await ApiService.getTunjanganPendidikan(nik: nik);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final List<TunjanganPendidikanItem> items = [];
        if (data['tunjangan_pendidikan'] is List &&
            (data['tunjangan_pendidikan'] as List).isNotEmpty) {
          for (final item in (data['tunjangan_pendidikan'] as List)) {
            final map = Map<String, dynamic>.from(item as Map);
            final bulanLabel = (map['bulan_label'] ?? '2026').toString();
            final yearMatch = RegExp(r'\b(20\d\d)\b').firstMatch(bulanLabel);
            final tahun = yearMatch?.group(1) ??
                (map['tahun'] ?? DateTime.now().year).toString();

            String tanggalCair = (map['tanggal_cair'] ?? '').toString();
            if (tanggalCair.isEmpty || tanggalCair == '-') {
              final createdAt = (map['created_at'] ?? '').toString();
              if (createdAt.isNotEmpty) {
                try {
                  final dt = DateTime.parse(createdAt);
                  tanggalCair =
                      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                } catch (_) {
                  tanggalCair = '-';
                }
              } else {
                tanggalCair = '-';
              }
            }

            items.add(TunjanganPendidikanItem(
              id: map['id'] as int?,
              tahun: tahun,
              bulanLabel: bulanLabel,
              tanggalCair: tanggalCair,
              status: (map['status'] ?? 'Diterbitkan').toString(),
              gapok: _toInt(map['gapok']),
              tunjanganIstri: _toInt(map['tunjangan_istri']),
              tunjanganAnak: _toInt(map['tunjangan_anak']),
              potonganKoperasi: _toInt(map['potongan_koperasi']),
              potonganKas: _toInt(map['potongan_kas']),
            ));
          }
          if (items.isNotEmpty) return items;
        }
      }
    } catch (_) {}
  }

  final userId = await _resolvePegawaiId(user);
  if (userId == null) return [];

  // 1. Prioritas Utama: Tabel `tunjangan_pendidikan`
  try {
    final rows = await Supabase.instance.client
        .from('tunjangan_pendidikan')
        .select()
        .eq('pegawai_id', userId)
        .order('created_at', ascending: false);

    if ((rows as List).isNotEmpty) {
      return (rows as List).map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        final bulanLabel = (map['bulan_label'] ?? '2026').toString();
        final yearMatch = RegExp(r'\b(20\d\d)\b').firstMatch(bulanLabel);
        final tahun = yearMatch?.group(1) ??
            (map['tahun'] ?? DateTime.now().year).toString();

        String tanggalCair = (map['tanggal_cair'] ?? '').toString();
        if (tanggalCair.isEmpty || tanggalCair == '-') {
          final createdAt = (map['created_at'] ?? '').toString();
          if (createdAt.isNotEmpty) {
            try {
              final dt = DateTime.parse(createdAt);
              tanggalCair =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            } catch (_) {
              tanggalCair = '-';
            }
          } else {
            tanggalCair = '-';
          }
        }

        return TunjanganPendidikanItem(
          id: map['id'] as int?,
          tahun: tahun,
          bulanLabel: bulanLabel,
          tanggalCair: tanggalCair,
          status: (map['status'] ?? 'Diterbitkan').toString(),
          gapok: _toInt(map['gapok']),
          tunjanganIstri: _toInt(map['tunjangan_istri']),
          tunjanganAnak: _toInt(map['tunjangan_anak']),
          potonganKoperasi: _toInt(map['potongan_koperasi']),
          potonganKas: _toInt(map['potongan_kas']),
        );
      }).toList();
    }
  } catch (e) {
    debugPrint('Gagal fetch tunjangan_pendidikan: $e');
  }

  // 2. Fallback: tabel `gaji_13` jika belum ada di tabel `tunjangan_pendidikan`
  try {
    final rows13 = await Supabase.instance.client
        .from('gaji_13')
        .select()
        .eq('pegawai_id', userId)
        .order('tahun', ascending: false);

    if ((rows13 as List).isNotEmpty) {
      return (rows13 as List).map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        final jumlah = _toInt(map['jumlah']);
        final tahun = (map['tahun'] ?? DateTime.now().year).toString();
        return TunjanganPendidikanItem(
          id: map['id'] as int?,
          tahun: tahun,
          bulanLabel: 'TAHUN $tahun',
          tanggalCair: (map['tanggal_cair'] ?? '-').toString(),
          status: (map['status'] ?? 'Diterbitkan').toString(),
          gapok: jumlah,
          tunjanganIstri: 0,
          tunjanganAnak: 0,
          potonganKoperasi: 0,
          potonganKas: 0,
        );
      }).toList();
    }
  } catch (_) {}

  return [];
}

Future<List<InsentifItem>> _fetchInsentif(
    AppUser? user, Map<String, String> profile) async {
  final nik = profile['nik'] ?? user?.nik ?? '';

  // 1. ApiService Laravel Backend
  if (nik.isNotEmpty && nik != '-') {
    try {
      final res = await ApiService.getInsentif(nik: nik);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final List<InsentifItem> items = [];

        if (data['list'] is List && (data['list'] as List).isNotEmpty) {
          for (final item in (data['list'] as List)) {
            if (item is Map<String, dynamic>) {
              items.add(_rowToInsentifItem(item, profile));
            } else if (item is Map) {
              items.add(_rowToInsentifItem(
                  Map<String, dynamic>.from(item), profile));
            }
          }
        } else if (data['insentif'] is Map) {
          items.add(_rowToInsentifItem(
              Map<String, dynamic>.from(data['insentif'] as Map), profile));
        }

        if (items.isNotEmpty) {
          return items;
        }
      }
    } catch (_) {}
  }

  // 2. Supabase Fallback
  final userId = await _resolvePegawaiId(user);
  if (userId != null) {
    try {
      final payrollRows = await Supabase.instance.client
          .from('payroll')
          .select()
          .eq('pegawai_id', userId)
          .order('tahun', ascending: false)
          .order('bulan', ascending: false);

      if ((payrollRows as List).isNotEmpty) {
        return (payrollRows as List)
            .map((row) => _rowToInsentifItem(
                Map<String, dynamic>.from(row as Map), profile))
            .toList();
      }
    } catch (_) {}

    try {
      final rows = await Supabase.instance.client
          .from('insentif')
          .select()
          .eq('pegawai_id', userId)
          .order('created_at', ascending: false);

      if ((rows as List).isNotEmpty) {
        return (rows as List)
            .map((row) => _rowToInsentifItem(
                Map<String, dynamic>.from(row as Map), profile))
            .toList();
      }
    } catch (_) {}
  }

  return [];
}

// ============================================================================
// WIDGET SCREEN
// ============================================================================

class TunjanganPendidikanScreen extends StatefulWidget {
  final AppUser? user;
  const TunjanganPendidikanScreen({super.key, this.user});

  @override
  State<TunjanganPendidikanScreen> createState() =>
      _TunjanganPendidikanScreenState();
}

class _TunjanganPendidikanScreenState extends State<TunjanganPendidikanScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color purpleStart = Color(0xFF9B59D9);
  static const Color purpleEnd = Color(0xFF6C3FB5);

  late Future<Map<String, String>> _profileFuture;
  late Future<List<TunjanganPendidikanItem>> _pendidikanFuture;
  late Future<List<InsentifItem>> _insentifFuture;

  int _selectedPendidikanIndex = 0;
  int _selectedInsentifIndex = 0;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _loadAllData() {
    _profileFuture = _fetchPegawaiProfile(widget.user);
    _pendidikanFuture = _fetchTunjanganPendidikan(widget.user);
    _insentifFuture = _profileFuture.then((profile) {
      return _fetchInsentif(widget.user, profile);
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loadAllData();
    });
    await Future.wait([_pendidikanFuture, _insentifFuture]);
  }

  // ==========================================================================
  // PDF HELPERS & BUILDERS
  // ==========================================================================

  static String _formatNominal(int value) {
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

  static pw.Widget _pdfRowItem(
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

  /// Page 1: Dokumen Resmi Tunjangan Pendidikan
  static pw.Widget _buildPendidikanPdfContent({
    required TunjanganPendidikanItem item,
    required Map<String, String> profile,
  }) {
    final gapok = item.gapok;
    final tunjIstri = item.tunjanganIstri;
    final tunjAnak = item.tunjanganAnak;
    final potKoperasi = item.potonganKoperasi;
    final potKas = item.potonganKas;

    final totPendapatan = item.totalPendapatan;
    final totPotongan = item.totalPotongan;
    final diterima = item.totalDiterima;

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
          'DAFTAR TUNJANGAN PENDIDIKAN & POTONGAN BULAN : ${item.tahun.toUpperCase()}',
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
            // Left Column
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfRowItem('NIK', profile['nik'] ?? '-', isNumber: false),
                  _pdfRowItem('NAMA', (profile['nama'] ?? '-').toUpperCase(),
                      isNumber: false),
                  _pdfRowItem('GOLONGAN', profile['golongan'] ?? '-',
                      isNumber: false),
                  _pdfRowItem('UNIT KERJA',
                      (profile['unitKerja'] ?? '-').toUpperCase(),
                      isNumber: false),
                  _pdfRowItem('JABATAN',
                      (profile['jabatan'] ?? '-').toUpperCase(),
                      isNumber: false),
                  _pdfRowItem('GAPOK', gapok),
                  _pdfRowItem('TUNJANGAN ISTRI', tunjIstri),
                  _pdfRowItem('TUNJANGAN ANAK', tunjAnak),
                  _pdfRowItem('JUMLAH PENDAPATAN', totPendapatan, bold: true),
                ],
              ),
            ),
            pw.SizedBox(width: 25),
            // Right Column
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 52), // sejajar dengan GAPOK
                  _pdfRowItem('POTONGAN KOPERASI', potKoperasi, labelWidth: 195),
                  _pdfRowItem('POTONGAN KAS', potKas, labelWidth: 195),
                  _pdfRowItem('JUMLAH POTONGAN NON-INSENTIF', totPotongan,
                      bold: true, labelWidth: 195),
                  _pdfRowItem('JUMLAH INSENTIF DITERIMA', diterima,
                      bold: true, labelWidth: 195),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'SLIP GAJI INI SUDAH DISETUJUI OLEH DIREKSI NAMUN SEGALA BENTUK PENYALAH GUNAAN SLIP GAJI BUKAN MENJADI TANGGUNG JAWAB PERUMDAM TIRTA DARMA AYU.',
            style: pw.TextStyle(
              fontSize: 7.5,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  /// Page 2: Dokumen Resmi Insentif Pekerjaan
  static pw.Widget _buildInsentifPdfContent(InsentifSlipDetail slip) {
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
          'DAFTAR INSENTIF PEKERJAAN & POTONGAN BULAN : ${slip.bulanLabel}',
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
                  _pdfRowItem('INSENTIF PERUSAHAAN', slip.insentifPerusahaan),
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

  // ==========================================================================
  // ACTION DOWNLOADS
  // ==========================================================================

  Future<void> _downloadPendidikanPdf(TunjanganPendidikanItem item) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final profile = await _profileFuture;

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          build: (context) => _buildPendidikanPdfContent(
            item: item,
            profile: profile,
          ),
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'TUNJANGAN_PENDIDIKAN_${item.tahun}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF Tunjangan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _downloadInsentifPdf(InsentifItem item) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final profile = await _profileFuture;
      final slip = item.slip ??
          InsentifSlipDetail(
            bulanLabel: item.periode.toUpperCase(),
            nik: profile['nik'] ?? '-',
            nama: profile['nama'] ?? '-',
            golongan: profile['golongan'] ?? '-',
            unitKerja: profile['unitKerja'] ?? '-',
            jabatan: profile['jabatan'] ?? '-',
          );

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          build: (context) => _buildInsentifPdfContent(slip),
        ),
      );

      final bytes = await doc.save();
      final fileLabel =
          (item.slip?.bulanLabel ?? item.periode).replaceAll(' ', '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'INSENTIF_$fileLabel.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF Insentif: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  /// Mengunduh SATU file PDF gabungan: Page 1 Tunjangan Pendidikan, Page 2 Insentif Pekerjaan
  Future<void> _downloadCombinedPdf(
    TunjanganPendidikanItem? pendItem,
    InsentifItem? insItem,
  ) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final profile = await _profileFuture;

      final activePendItem = pendItem ??
          TunjanganPendidikanItem(
            tahun: DateTime.now().year.toString(),
            bulanLabel: 'TAHUN ${DateTime.now().year}',
            tanggalCair: '-',
            status: 'DITERBITKAN',
            gapok: 0,
            tunjanganIstri: 0,
            tunjanganAnak: 0,
            potonganKoperasi: 0,
            potonganKas: 0,
          );

      final activeInsSlip = insItem?.slip ??
          InsentifSlipDetail(
            bulanLabel: (insItem?.periode ??
                    'TAHUN ${DateTime.now().year}')
                .toUpperCase(),
            nik: profile['nik'] ?? '-',
            nama: profile['nama'] ?? '-',
            golongan: profile['golongan'] ?? '-',
            unitKerja: profile['unitKerja'] ?? '-',
            jabatan: profile['jabatan'] ?? '-',
          );

      final doc = pw.Document();

      // Page 1: Rincian Tunjangan Pendidikan
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          build: (context) => _buildPendidikanPdfContent(
            item: activePendItem,
            profile: profile,
          ),
        ),
      );

      // Page 2: Rincian Insentif Pekerjaan
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          build: (context) => _buildInsentifPdfContent(activeInsSlip),
        ),
      );

      final bytes = await doc.save();
      final tahunLabel = activePendItem.tahun;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'TUNJANGAN_PENDIDIKAN_DAN_INSENTIF_$tahunLabel.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF Gabungan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ==========================================================================
  // UI WIDGET BUILDERS
  // ==========================================================================

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary(context),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _rincianRow(String label, String value, {bool isSubtotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSubtotal ? FontWeight.w600 : FontWeight.normal,
              color: isSubtotal
                  ? AppColors.textPrimary(context)
                  : AppColors.textSecondary(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSubtotal ? FontWeight.bold : FontWeight.w500,
              color: isSubtotal ? navy : AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsentifHeroCard(InsentifItem item) {
    final total = item.slip?.jumlahDiterima ?? item.jumlah;
    return InkWell(
      onTap: () => _downloadInsentifPdf(item),
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
              color: purpleEnd.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Insentif Pekerjaan · ${item.periode}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.file_download_outlined,
                  size: 14,
                  color: Colors.white70,
                ),
              ],
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
              '${item.judul}  (Ketuk untuk unduh slip PDF)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsentifRiwayatCard(List<InsentifItem> riwayat) {
    if (riwayat.isEmpty) {
      return InfoCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'Belum ada data riwayat insentif',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ),
      );
    }

    const icons = [
      Icons.star_rounded,
      Icons.wb_sunny_rounded,
      Icons.check_box_rounded,
    ];

    return InfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < riwayat.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.divider(context)),
            InkWell(
              onTap: () {
                setState(() => _selectedInsentifIndex = i);
                _downloadInsentifPdf(riwayat[i]);
              },
              borderRadius: BorderRadius.circular(12),
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
                      child: Icon(
                        icons[i % icons.length],
                        color: const Color(0xFF8E44AD),
                        size: 20,
                      ),
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
                        riwayat[i].slip?.jumlahDiterima ?? riwayat[i].jumlah,
                      ),
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

  Widget _buildCekDetailButton(
    TunjanganPendidikanItem? selectedPend,
    InsentifItem? selectedIns,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isGeneratingPdf
                ? null
                : () => _downloadCombinedPdf(selectedPend, selectedIns),
            icon: _isGeneratingPdf
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
              _isGeneratingPdf ? 'Menyiapkan PDF Gabungan...' : 'Cek Detail',
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
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Tombol di atas mengunduh slip resmi gabungan Tunjangan Pendidikan & Insentif Pekerjaan (1 file PDF)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Tunjangan Pendidikan',
      subtitle: 'Riwayat pencairan tunjangan pendidikan & insentif pekerjaan',
      icon: Icons.school_rounded,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<TunjanganPendidikanItem>>(
          future: _pendidikanFuture,
          builder: (context, pendSnapshot) {
            return FutureBuilder<List<InsentifItem>>(
              future: _insentifFuture,
              builder: (context, insSnapshot) {
                final isLoading =
                    pendSnapshot.connectionState == ConnectionState.waiting &&
                        insSnapshot.connectionState == ConnectionState.waiting;

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pendData = pendSnapshot.data ?? [];
                final insData = insSnapshot.data ?? [];

                final selectedPendidikan = pendData.isNotEmpty
                    ? pendData[_selectedPendidikanIndex.clamp(
                        0, pendData.length - 1)]
                    : null;

                final activeInsentif = insData.isNotEmpty
                    ? insData[_selectedInsentifIndex.clamp(
                        0, insData.length - 1)]
                    : null;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  children: [
                    // ========================================================
                    // BAGIAN 1: RINCIAN TUNJANGAN PENDIDIKAN
                    // ========================================================
                    _buildSectionHeader(
                      title: 'RINCIAN TUNJANGAN PENDIDIKAN',
                      subtitle:
                          'Ketuk kartu untuk mengunduh slip PDF resmi tunjangan',
                      icon: Icons.school_rounded,
                      accentColor: const Color(0xFF16A085),
                    ),
                    if (pendData.isEmpty)
                      InfoCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              'Belum ada data Tunjangan Pendidikan',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      for (int i = 0; i < pendData.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedPendidikanIndex = i);
                              _downloadPendidikanPdf(pendData[i]);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: i == _selectedPendidikanIndex
                                    ? Border.all(
                                        color: const Color(0xFF16A085),
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                              child: InfoCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Kartu
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDFF3EE),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.school_rounded,
                                            color: Color(0xFF16A085),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Tunjangan Pendidikan Tahun ${pendData[i].tahun}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: navy,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Periode: ${pendData[i].bulanLabel} · Ketuk untuk unduh slip PDF',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        StatusBadge.auto(pendData[i].status),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // RINCIAN KOMPONEN PENDAPATAN & POTONGAN
                                    Text(
                                      'RINCIAN KOMPONEN',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary(context),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _rincianRow('Gaji Pokok (GAPOK)',
                                        formatRupiah(pendData[i].gapok)),
                                    if (pendData[i].tunjanganIstri > 0)
                                      _rincianRow('Tunjangan Istri',
                                          formatRupiah(pendData[i].tunjanganIstri)),
                                    if (pendData[i].tunjanganAnak > 0)
                                      _rincianRow('Tunjangan Anak',
                                          formatRupiah(pendData[i].tunjanganAnak)),
                                    _rincianRow(
                                      'Jumlah Pendapatan',
                                      formatRupiah(pendData[i].totalPendapatan),
                                      isSubtotal: true,
                                    ),

                                    const SizedBox(height: 4),
                                    Divider(
                                        height: 1,
                                        color: AppColors.divider(context)),
                                    const SizedBox(height: 4),

                                    _rincianRow('Potongan Koperasi',
                                        formatRupiah(pendData[i].potonganKoperasi)),
                                    _rincianRow('Potongan Kas',
                                        formatRupiah(pendData[i].potonganKas)),
                                    if (pendData[i].totalPotongan > 0)
                                      _rincianRow(
                                        'Jumlah Potongan',
                                        '- ${formatRupiah(pendData[i].totalPotongan)}',
                                        isSubtotal: true,
                                      ),

                                    const SizedBox(height: 12),

                                    // TOTAL DITERIMA HIGHLIGHT BOX
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F6F3),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF16A085)
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Total Diterima',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF117A65),
                                                ),
                                              ),
                                              Text(
                                                'Bersih non-potongan',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: Color(0xFF16A085),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            formatRupiah(
                                                pendData[i].totalDiterima),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF117A65),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 10),
                                    InfoRow(
                                      label: 'Tanggal Pencairan',
                                      value: pendData[i].tanggalCair,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                    const SizedBox(height: 22),

                    // ========================================================
                    // BAGIAN 2: RINCIAN INSENTIF PEKERJAAN
                    // ========================================================
                    _buildSectionHeader(
                      title: 'RINCIAN INSENTIF PEKERJAAN',
                      subtitle:
                          'Ketuk kartu hero/riwayat untuk unduh slip PDF resmi insentif pekerjaan',
                      icon: Icons.stars_rounded,
                      accentColor: const Color(0xFF8E44AD),
                    ),
                    if (activeInsentif != null) ...[
                      _buildInsentifHeroCard(activeInsentif),
                      const SizedBox(height: 20),
                    ],
                    _buildSectionSubHeader('RIWAYAT INSENTIF'),
                    _buildInsentifRiwayatCard(insData),

                    const SizedBox(height: 30),

                    // ========================================================
                    // BAGIAN 3: TOMBOL CEK DETAIL (PDF GABUNGAN)
                    // ========================================================
                    _buildCekDetailButton(selectedPendidikan, activeInsentif),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
