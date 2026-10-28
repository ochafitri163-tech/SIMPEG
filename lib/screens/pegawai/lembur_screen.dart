import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_role.dart';
import '../../services/api_service.dart';
import '../../widgets/feature_scaffold.dart';
import 'payroll_screen.dart' show formatRupiah;

class _LemburRow {
  final String bulan;
  final num jamLembur;
  final int uangLembur;
  final String? keterangan;
  final String? tanggal;

  const _LemburRow({
    required this.bulan,
    required this.jamLembur,
    required this.uangLembur,
    this.keterangan,
    this.tanggal,
  });

  factory _LemburRow.fromMap(Map<String, dynamic> row) {
    return _LemburRow(
      bulan: (row['bulan'] ?? '-') as String,
      jamLembur: _lemburToNum(row['jam_lembur']),
      uangLembur: _lemburToInt(row['uang_lembur']),
      keterangan: row['keterangan']?.toString(),
      tanggal: row['tanggal']?.toString(),
    );
  }
}

/// Helper: konversi value ke int secara aman.
int _lemburToInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is double) return val.toInt();
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? 0;
  return 0;
}

/// Helper: konversi value jam (bisa 9 atau 9.5) secara aman.
num _lemburToNum(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val;
  if (val is String) return num.tryParse(val) ?? 0;
  return 0;
}

Future<String?> _resolvePegawaiId(AppUser? user) async {
  // 1. Prioritas: gunakan NIK dari AppUser (selalu ada setelah login)
  String? nik = user?.nik;

  // 2. Fallback: ambil dari SharedPreferences
  if (nik == null || nik.isEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      nik = prefs.getString('user_nik');
      if (nik == null || nik.isEmpty) {
        final sessionStr = prefs.getString('user_session_json');
        if (sessionStr != null && sessionStr.isNotEmpty) {
          final jsonMap = jsonDecode(sessionStr);
          nik = jsonMap['nik'] as String?;
        }
      }
    } catch (_) {}
  }

  // 3. Resolve NIK ke pegawai_id (UUID) dengan caching di SharedPreferences
  if (nik != null && nik.isNotEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getString('cached_peg_id_$nik');
      if (cachedId != null && cachedId.isNotEmpty) {
        return cachedId;
      }

      final peg = await Supabase.instance.client
          .from('pegawai')
          .select('id')
          .eq('nik', nik)
          .maybeSingle();
      if (peg != null && peg['id'] != null) {
        final id = peg['id'].toString();
        await prefs.setString('cached_peg_id_$nik', id);
        return id;
      }
    } catch (_) {}
  }

  // 4. Last resort: coba Supabase Auth user ID
  String? userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null && userId.isNotEmpty) return userId;

  return null;
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

Future<List<_LemburRow>> _fetchLembur(AppUser? user) async {
  // 1. Prioritas Utama: Ambil dari API Laravel (ApiService.getLembur)
  // Backend menyatukan data input manual Set Prestasi SDM, tabel lembur, & payroll.
  try {
    final res = await ApiService.getLembur(nik: user?.nik);
    if (res['success'] == true && res['data'] is List) {
      final list = res['data'] as List;
      return list
          .map((r) => _LemburRow.fromMap(r as Map<String, dynamic>))
          .toList();
    }
  } catch (e) {
    debugPrint('Gagal fetch lembur via ApiService: $e');
  }

  // 2. Fallback: Query langsung ke Supabase jika API backend offline
  final userId = await _resolvePegawaiId(user);
  if (userId == null) return [];

  try {
    final results = await Future.wait([
      Supabase.instance.client
          .from('prestasi')
          .select()
          .eq('pegawai_id', userId)
          .order('created_at', ascending: false),
      Supabase.instance.client
          .from('lembur')
          .select()
          .eq('pegawai_id', userId)
          .order('created_at', ascending: false),
      Supabase.instance.client
          .from('payroll')
          .select('periode, lembur, tahun, bulan')
          .eq('pegawai_id', userId)
          .gt('lembur', 0)
          .order('tahun', ascending: false)
          .order('bulan', ascending: false),
    ]);

    final prestasiRows = results[0] as List;
    final lemburRows = results[1] as List;
    final payrollRows = results[2] as List;

    // 2a. Dari tabel prestasi (input manual SDM)
    final List<_LemburRow> fromPrestasi = [];
    for (final r in prestasiRows) {
      Map<String, dynamic> meta = {};
      if (r['keterangan'] != null) {
        try {
          meta = jsonDecode(r['keterangan'].toString()) as Map<String, dynamic>;
        } catch (_) {}
      }
      final jam = _lemburToNum(meta['jam_lembur'] ?? r['jam_lembur']);
      final uang = _lemburToInt(meta['nominal_lembur'] ?? (jam * 9375).round());
      if (jam > 0 || uang > 0) {
        String bulanStr = '-';
        if (r['tanggal'] != null) {
          final tglStr = r['tanggal'].toString();
          try {
            final dt = DateTime.parse(tglStr);
            const bNames = [
              '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
              'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
            ];
            bulanStr = '${bNames[dt.month]} ${dt.year}';
          } catch (_) {
            bulanStr = tglStr;
          }
        }
        fromPrestasi.add(_LemburRow(
          bulan: bulanStr,
          jamLembur: jam,
          uangLembur: uang,
          keterangan: meta['desc'] ?? (r['judul']?.toString()),
          tanggal: r['tanggal']?.toString(),
        ));
      }
    }
    if (fromPrestasi.isNotEmpty) {
      return fromPrestasi;
    }

    // 2b. Dari tabel lembur
    if (lemburRows.isNotEmpty) {
      return lemburRows
          .map((r) => _LemburRow.fromMap(r as Map<String, dynamic>))
          .toList();
    }

    // 2c. Fallback dari tabel payroll di mana lembur > 0
    if (payrollRows.isNotEmpty) {
      return payrollRows.map((r) {
        final uang = _lemburToInt(r['lembur']);
        // Standard rate PDAM Rp 9.375 / jam (BUKAN 50.000)
        final jam = max(1.0, (uang / 9375.0));
        return _LemburRow(
          bulan: (r['periode'] ?? '-') as String,
          jamLembur: double.parse(jam.toStringAsFixed(1)),
          uangLembur: uang,
        );
      }).toList();
    }
  } catch (e) {
    debugPrint('Fallback Supabase lembur error: $e');
  }

  return [];
}

/// Halaman "Lembur" — menampilkan riwayat jam & uang lembur pegawai yang
/// sedang login serta fitur cetak slip lembur resmi PERUMDAM (PDF).
class LemburScreen extends StatefulWidget {
  final AppUser? user;
  const LemburScreen({super.key, this.user});

  @override
  State<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends State<LemburScreen> {
  late Future<List<_LemburRow>> _future;
  bool _isGenerating = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _fetchLembur(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchLembur(widget.user));
    await _future;
  }

  Future<void> _downloadLemburPdf(_LemburRow item) async {
    setState(() => _isGenerating = true);
    try {
      final profile = await _fetchPegawaiProfile(widget.user);
      final bytes = await _generateLemburPdf(item, profile);
      final fileLabel = item.bulan.replaceAll(' ', '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'SLIP_LEMBUR_$fileLabel.pdf',
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

  Future<Uint8List> _generateLemburPdf(
    _LemburRow item,
    Map<String, String> profile,
  ) async {
    final doc = pw.Document();

    final jamDisplay = item.jamLembur % 1 == 0
        ? '${item.jamLembur.toInt()} JAM'
        : '${item.jamLembur} JAM';
    const tarifPerJam = 9375;
    final nominalTotal = item.uangLembur > 0
        ? item.uangLembur
        : (item.jamLembur * tarifPerJam).round();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        build: (context) {
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
                'DAFTAR LEMBUR BULAN : ${item.bulan.toUpperCase()}',
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
                  // Left Column (Identitas & Pendapatan Lembur)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _pdfRowItem('NIK', profile['nik'] ?? '-',
                            isNumber: false),
                        _pdfRowItem(
                            'NAMA', (profile['nama'] ?? '-').toUpperCase(),
                            isNumber: false),
                        _pdfRowItem('GOLONGAN', profile['golongan'] ?? '-',
                            isNumber: false),
                        _pdfRowItem('UNIT KERJA',
                            (profile['unitKerja'] ?? '-').toUpperCase(),
                            isNumber: false),
                        _pdfRowItem('JABATAN',
                            (profile['jabatan'] ?? '-').toUpperCase(),
                            isNumber: false),
                        _pdfRowItem('JAM LEMBUR', jamDisplay, isNumber: false),
                        _pdfRowItem('TARIF LEMBUR / JAM', tarifPerJam),
                        _pdfRowItem('UPAH LEMBUR', nominalTotal),
                        if (item.keterangan != null &&
                            item.keterangan!.isNotEmpty)
                          _pdfRowItem('KETERANGAN', item.keterangan!,
                              isNumber: false),
                        _pdfRowItem(
                            'JUMLAH PENDAPATAN LEMBUR', nominalTotal,
                            bold: true),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 25),
                  // Right Column (Potongan & Diterima)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 52), // sejajar dengan JAM LEMBUR
                        _pdfRowItem('POTONGAN PAJAK PPH 21', 0,
                            labelWidth: 195),
                        _pdfRowItem('POTONGAN KAS', 0, labelWidth: 195),
                        _pdfRowItem('POTONGAN LAIN-LAIN', 0, labelWidth: 195),
                        _pdfRowItem('JUMLAH POTONGAN', 0,
                            bold: true, labelWidth: 195),
                        _pdfRowItem('JUMLAH LEMBUR DITERIMA', nominalTotal,
                            bold: true, labelWidth: 195),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'SLIP LEMBUR INI SUDAH DISETUJUI OLEH DIREKSI NAMUN SEGALA BENTUK PENYALAH GUNAAN SLIP BUKAN MENJADI TANGGUNG JAWAB PERUMDAM TIRTA DARMA AYU.',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ],
          );
        },
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

  Widget _buildCekDetailButton(_LemburRow item) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : () => _downloadLemburPdf(item),
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
          backgroundColor: FeatureScaffold.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Lembur',
      subtitle: 'Riwayat jam & uang lembur',
      icon: Icons.access_time_filled_rounded,
      child: FutureBuilder<List<_LemburRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'Gagal memuat data lembur: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            );
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  EmptyState(message: 'Belum ada data lembur'),
                ],
              ),
            );
          }

          final selectedItem = data[_selectedIndex.clamp(0, data.length - 1)];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              itemCount: data.length + 1,
              itemBuilder: (context, index) {
                if (index == data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildCekDetailButton(selectedItem),
                  );
                }

                final item = data[index];
                final isSelected = index == _selectedIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      _downloadLemburPdf(item);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(
                                color: FeatureScaffold.accent, width: 1.5)
                            : null,
                      ),
                      child: InfoCard(
                        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    FeatureScaffold.accent,
                                    FeatureScaffold.navy,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.bulan,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: FeatureScaffold.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3F1F8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.access_time_filled_rounded,
                                          size: 12,
                                          color: FeatureScaffold.accent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${item.jamLembur % 1 == 0 ? item.jamLembur.toInt() : item.jamLembur} jam',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: FeatureScaffold.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item.keterangan != null &&
                                      item.keterangan!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.keterangan!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 3),
                                  Text(
                                    'Ketuk untuk unduh slip PDF',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Uang Lembur',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF95A5A6),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  formatRupiah(item.uangLembur),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: FeatureScaffold.navy,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

