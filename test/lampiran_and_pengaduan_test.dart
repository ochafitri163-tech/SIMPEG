import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpeg_mobile/models/pengaduan_service.dart';
import 'package:simpeg_mobile/models/user_role.dart';
import 'package:simpeg_mobile/screens/shared/surat_detail_pengaduan_screen.dart';
import 'package:simpeg_mobile/services/api_service.dart';
import 'package:simpeg_mobile/utils/lampiran_helper.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });
  // 1x1 transparent PNG
  const oneByOnePngB64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  const minimalPdfB64 =
      'JVBERi0xLjAKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmoK';

  group('pengaduanFromRow PostgreSQL array parsing', () {
    test('preserves commas inside quoted PostgreSQL text[] data URIs', () {
      const pgFoto = '{"data:image/jpeg;base64,$oneByOnePngB64"}';
      const pgDok =
          '{"data:application/pdf;name=1711179_1795581885735.pdf;base64,$minimalPdfB64"}';

      final p = pengaduanFromRow({
        'id': 146,
        'nomor_pengaduan': 'PGD-20261125-5995',
        'kategori': 'Pelanggaran Administrasi',
        'judul': 'Tes',
        'deskripsi': 'Uraian tes pengaduan minimal 30 karakter.',
        'foto_bukti': pgFoto,
        'dokumen_pendukung': pgDok,
      });

      expect(p.fotoBukti.length, 1);
      expect(p.fotoBukti.first, 'data:image/jpeg;base64,$oneByOnePngB64');
      expect(p.dokumenPendukung.length, 1);
      expect(
        p.dokumenPendukung.first,
        'data:application/pdf;name=1711179_1795581885735.pdf;base64,$minimalPdfB64',
      );
    });

    test('restitches legacy split data URIs in list responses', () {
      final p = pengaduanFromRow({
        'id': 146,
        'nomor_pengaduan': 'PGD-20261125-5995',
        'foto_bukti': ['data:image/jpeg;base64', oneByOnePngB64],
      });

      expect(p.fotoBukti.length, 1);
      expect(p.fotoBukti.first, 'data:image/jpeg;base64,$oneByOnePngB64');
    });
  });

  group('LampiranHelper & ApiService URL resolution', () {
    test('decodes base64 data URI, filename, and MIME cleanly', () {
      const imgUri = 'data:image/jpeg;base64,$oneByOnePngB64';
      const pdfUri =
          'data:application/pdf;name=1711179_1795581885735.pdf;base64,$minimalPdfB64';

      expect(LampiranHelper.isImageUrl(imgUri), isTrue);
      expect(LampiranHelper.isPdfUrl(imgUri), isFalse);
      expect(LampiranHelper.extractFileName(imgUri, fallback: 'Foto_1'), 'Foto_1.jpg');

      final decodedImg = LampiranHelper.tryDecodeDataUri(imgUri);
      expect(decodedImg, isNotNull);
      expect(decodedImg!.bytes, base64Decode(oneByOnePngB64));
      expect(decodedImg.mimeType, 'image/jpeg');

      expect(LampiranHelper.isImageUrl(pdfUri), isFalse);
      expect(LampiranHelper.isPdfUrl(pdfUri), isTrue);
      expect(
        LampiranHelper.extractFileName(pdfUri),
        '1711179_1795581885735.pdf',
      );

      final decodedPdf = LampiranHelper.tryDecodeDataUri(pdfUri);
      expect(decodedPdf, isNotNull);
      expect(decodedPdf!.mimeType, 'application/pdf');
      expect(decodedPdf.fileName, '1711179_1795581885735.pdf');
    });

    test('resolves local /storage paths to CORS-enabled /api/v1/storage/', () {
      final resolvedLocal = ApiService.resolveUrl('/storage/pengaduan_bukti/a.jpg');
      expect(resolvedLocal, contains('/api/v1/storage/pengaduan_bukti/a.jpg'));

      const supabaseUrl =
          'https://jyywrknlkqwmiqokmcju.supabase.co/storage/v1/object/public/pengaduan-bukti/a.jpg';
      expect(ApiService.resolveUrl(supabaseUrl), supabaseUrl);
    });

    test('embeds decoded base64 PNG/JPEG data URI into PDF without errors', () async {
      final bytes = LampiranHelper.tryDecodeDataUri(
        'data:image/jpeg;base64,$oneByOnePngB64',
      )!.bytes;
      final pdf = pw.Document();
      final memImage = pw.MemoryImage(Uint8List.fromList(bytes));
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(child: pw.Image(memImage)),
        ),
      );
      final out = await pdf.save();
      expect(out.isNotEmpty, isTrue);
      expect(String.fromCharCodes(out.take(4)), '%PDF');
    });
  });

  group('SuratDetailPengaduanScreen widget behavior', () {
    testWidgets('renders intact attachments and opens photo & PDF modals without errors',
        (tester) async {
      final pengaduan = pengaduanFromRow({
        'id': 146,
        'nomor_pengaduan': 'PGD-20261125-5995',
        'kategori': 'Pelanggaran Administrasi',
        'judul': 'Laporan Test',
        'deskripsi': 'Deskripsi test pengaduan yang cukup panjang untuk validasi tampilan.',
        'nama_pegawai': 'Pelapor Uji',
        'nik': '1711179',
        'cabang': 'Kantor Pusat',
        'golongan': 'II/B',
        'pihak_terlapor': 'Terlapor Uji',
        'nik_pelaku': '1711200',
        'jabatan_pelaku': 'Staf',
        'status': 'menungguKadiv',
        'foto_bukti': ['data:image/jpeg;base64,$oneByOnePngB64'],
        'dokumen_pendukung': [
          'data:application/pdf;name=1711179_1795581885735.pdf;base64,$minimalPdfB64'
        ],
      });

      const user = AppUser(
        nik: '1711161',
        name: 'KSPI Uji',
        jabatan: 'Ketua SPI',
        unitKerja: 'SPI',
        golongan: 'IV',
        role: UserRole.kspi,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SuratDetailPengaduanScreen(
            user: user,
            pengaduanId: 146,
            initialPengaduan: pengaduan,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Lampiran #1: Foto Bukti Pelapor #1'), findsOneWidget);
      expect(find.text('Nama Berkas: Foto_Bukti_1.jpg'), findsOneWidget);
      expect(find.text('Lampiran #2: Dokumen Pendukung #1'), findsOneWidget);
      expect(find.text('Nama Berkas: 1711179_1795581885735.pdf'), findsOneWidget);
      expect(find.text('Unduh PDF'), findsOneWidget);
      expect(find.text('Pratinjau PDF'), findsOneWidget);

      // Tap Buka Foto Ukuran Penuh -> must open dark photo viewer without FormatException
      final bukaFotoBtn = find.text('Buka Foto Ukuran Penuh');
      await tester.ensureVisible(bukaFotoBtn);
      await tester.tap(bukaFotoBtn);
      await tester.pumpAndSettle();

      expect(find.text('Foto_Bukti_1.jpg'), findsOneWidget);
      expect(find.text('Unduh'), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);

      // Close photo viewer
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      // Tap Buka / Unduh Dokumen -> must open PDF detail modal without FormatException
      final bukaDokBtn = find.text('Buka / Unduh Dokumen');
      await tester.ensureVisible(bukaDokBtn);
      await tester.tap(bukaDokBtn);
      await tester.pumpAndSettle();

      expect(find.text('Detail Berkas Dokumen'), findsOneWidget);
      expect(find.text('1711179_1795581885735.pdf'), findsOneWidget);
      expect(find.text('Buka Pratinjau PDF'), findsOneWidget);
      expect(find.text('Unduh Berkas PDF'), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);
    });

    testWidgets('renders inline DOCX/TXT/PDF contents on screen and inside exported PDF',
        (tester) async {
      // Bangun DOCX valid di memori dengan Archive/ZipEncoder
      const docxXml =
          '<w:document><w:body>'
          '<w:p><w:r><w:t>Ringkasan Temuan Pelanggaran Internal</w:t></w:r></w:p>'
          '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Lokasi</w:t></w:r></w:p></w:tc>'
          '<w:tc><w:p><w:r><w:t>Unit Distribusi Indramayu</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
          '</w:body></w:document>';
      final docxArchive = Archive()
        ..addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(docxXml)));
      final docxBytes = Uint8List.fromList(ZipEncoder().encode(docxArchive));
      final docxUri =
          'data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;name=bap_investigasi.docx;base64,${base64Encode(docxBytes)}';

      // Bangun TXT di memori
      const txtContent = 'Catatan Tambahan Pelapor: Bukti terlampir lengkap.';
      final txtUri =
          'data:text/plain;name=catatan_tambahan.txt;base64,${base64Encode(utf8.encode(txtContent))}';

      // Bangun PDF nyata menggunakan pw.Document
      final nestedPdf = pw.Document();
      nestedPdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(
            child: pw.Text('ISI LAMPIRAN PDF RAHASIA 2026'),
          ),
        ),
      );
      final nestedPdfBytes = await nestedPdf.save();
      final nestedPdfUri =
          'data:application/pdf;name=lampiran_bap.pdf;base64,${base64Encode(nestedPdfBytes)}';

      final pengaduan = pengaduanFromRow({
        'id': 200,
        'nomor_pengaduan': 'PGD-20261125-7777',
        'kategori': 'Pelanggaran Disiplin',
        'judul': 'Laporan dengan Banyak Lampiran',
        'deskripsi': 'Uraian lengkap pengaduan beserta dokumen pendukung.',
        'nama_pegawai': 'Pelapor Dua',
        'nik': '1711180',
        'cabang': 'Cabang Indramayu',
        'golongan': 'III/A',
        'status': 'menungguKadiv',
        'foto_bukti': ['data:image/jpeg;base64,$oneByOnePngB64'],
        'dokumen_pendukung': [docxUri, txtUri, nestedPdfUri],
      });

      const user = AppUser(
        nik: '1711161',
        name: 'KSPI Uji',
        jabatan: 'Ketua SPI',
        unitKerja: 'SPI',
        golongan: 'IV',
        role: UserRole.kspi,
      );

      Uint8List? exportedPdfBytes;

      await tester.pumpWidget(
        MaterialApp(
          home: SuratDetailPengaduanScreen(
            user: user,
            pengaduanId: 200,
            initialPengaduan: pengaduan,
            onPdfGeneratedForTest: (bytes) => exportedPdfBytes = bytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi konten DOCX, TXT, dan PDF fallback teks langsung tampil inline di halaman Surat
      expect(find.textContaining('Ringkasan Temuan Pelanggaran Internal'), findsOneWidget);
      expect(find.textContaining('Lokasi | Unit Distribusi Indramayu'), findsOneWidget);
      expect(find.textContaining('Catatan Tambahan Pelapor: Bukti terlampir lengkap.'), findsOneWidget);
      expect(find.textContaining('ISI LAMPIRAN PDF RAHASIA 2026'), findsOneWidget);

      // Verifikasi Unduh PDF menyertakan isi lampiran ke dokumen PDF ekspor
      final unduhPdfBtn = find.text('Unduh PDF');
      await tester.ensureVisible(unduhPdfBtn);
      await tester.tap(unduhPdfBtn);
      await tester.pumpAndSettle();

      expect(exportedPdfBytes, isNotNull);
      expect(String.fromCharCodes(exportedPdfBytes!.take(4)), '%PDF');

      final exportedText = LampiranHelper.extractReadableDocumentText(
        exportedPdfBytes!,
        'Surat_Pengaduan.pdf',
        mimeType: 'application/pdf',
      );
      expect(exportedText, isNotNull);
      expect(exportedText, contains('Lampiran #1'));
      expect(exportedText, contains('Lampiran #2'));
      expect(exportedText, contains('Ringkasan Temuan Pelanggaran Internal'));
      expect(exportedText, contains('Lampiran #3'));
      expect(exportedText, contains('Catatan Tambahan Pelapor: Bukti terlampir lengkap.'));
      expect(exportedText, contains('Lampiran #4'));
      expect(exportedText, contains('ISI LAMPIRAN PDF RAHASIA 2026'));
    });
  });

  group('LampiranHelper document extraction and PDF raster fallback', () {
    test('extracts readable text from DOCX, XLSX, JSON, and handles headless raster gracefully', () async {
      final xlsxArchive = Archive()
        ..addFile(ArchiveFile.bytes(
          'xl/sharedStrings.xml',
          utf8.encode('<sst><si><t>No</t></si><si><t>Uraian Temuan</t></si></sst>'),
        ))
        ..addFile(ArchiveFile.bytes(
          'xl/worksheets/sheet1.xml',
          utf8.encode('<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row></sheetData></worksheet>'),
        ));
      final xlsxBytes = Uint8List.fromList(ZipEncoder().encode(xlsxArchive));
      expect(
        LampiranHelper.extractReadableDocumentText(xlsxBytes, 'data_temuan.xlsx'),
        'No | Uraian Temuan',
      );

      final jsonBytes = Uint8List.fromList(utf8.encode('{"status":"ok","jumlah":2}'));
      final jsonText = LampiranHelper.extractReadableDocumentText(jsonBytes, 'meta.json');
      expect(jsonText, contains('"status": "ok"'));

      final rasterResult = await LampiranHelper.rasterPdfPages(Uint8List.fromList([1, 2, 3]));
      expect(rasterResult, isEmpty);
    });
  });
}
