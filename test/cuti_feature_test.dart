import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpeg_mobile/models/cuti_service.dart';
import 'package:simpeg_mobile/models/user_role.dart';
import 'package:simpeg_mobile/screens/pegawai/pengajuan_cuti_screen.dart';
import 'package:simpeg_mobile/screens/pegawai/profile_detail_screen.dart';
import 'package:simpeg_mobile/screens/pegawai/surat_cuti_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CutiService.resetForTest();
  });

  const samplePegawai = AppUser(
    nik: '1711256',
    name: 'Aam Hamdan',
    gelar: 'S.H.',
    jabatan: 'Manajer Unit Pelayanan Arahan',
    unitKerja: 'Cabang Arahan',
    unitKerjaSingkat: 'Arahan',
    golongan: 'Staf I / C.4',
    alamat: 'Jl. Diponegoro No. 12, Indramayu',
    noTelp: '081234567890',
    role: UserRole.pegawai,
  );

  const sampleSdm = AppUser(
    nik: '1711254',
    name: 'Heddy Kelana, S.H.',
    jabatan: 'Manajer SDM',
    unitKerja: 'Bagian SDM',
    unitKerjaSingkat: 'SDM',
    golongan: 'IV/A',
    role: UserRole.sdm,
  );

  final sampleCutiList = <PengajuanCuti>[
    PengajuanCuti(
      id: 1,
      pegawaiId: 'uuid-1',
      nik: '1711256',
      namaPegawai: 'Aam Hamdan, S.H.',
      unitKerja: 'Cabang Arahan',
      jabatan: 'Manajer Unit Pelayanan Arahan',
      golongan: 'Staf I / C.4',
      jenis: 'Cuti Tahunan',
      noSurat: '850/001/SDM/XI/2026',
      tanggalMulai: DateTime(2026, 11, 10),
      tanggalSelesai: DateTime(2026, 11, 12),
      durasiHari: 3,
      alasan: 'Keperluan keluarga',
      alamatCuti: 'Jl. Diponegoro No. 12, Indramayu',
      noTelp: '081234567890',
      status: StatusCuti.disetujui,
      diputuskanOleh: 'Heddy Kelana, S.H.',
      catatanApprover: 'Disetujui sesuai hak cuti tahunan.',
      dibuatPada: DateTime(2026, 11, 8),
    ),
    PengajuanCuti(
      id: 2,
      pegawaiId: 'uuid-2',
      nik: '1711002',
      namaPegawai: 'Budi Santoso',
      unitKerja: 'Distribusi',
      jabatan: 'Staf Distribusi',
      golongan: 'C.1',
      jenis: 'Cuti Sakit',
      noSurat: '850/002/SDM/XI/2026',
      tanggalMulai: DateTime(2026, 11, 20),
      tanggalSelesai: DateTime(2026, 11, 21),
      durasiHari: 2,
      alasan: 'Rawat jalan',
      alamatCuti: 'Indramayu',
      noTelp: '081299998888',
      status: StatusCuti.menunggu,
      dibuatPada: DateTime(2026, 11, 19),
    ),
  ];

  group('Profile Cuti Entry Button & Screen', () {
    testWidgets(
      'ProfileDetailScreen displays Cuti quick-action and tab chip cleanly on desktop & narrow phone without overflow',
      (WidgetTester tester) async {
        CutiService.fetchOverride = ({nik, all = false, tahun, status}) async {
          return CutiFetchResult(
            items: [sampleCutiList.first],
            summary: CutiSummary.fromList([sampleCutiList.first], tahun: 2026),
          );
        };

        // Test on wide desktop/web size (matches screenshot aspect)
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: ProfileDetailScreen(user: samplePegawai, showBackButton: false),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Golongan'), findsAtLeastNWidgets(2));
        expect(find.text('Prestasi'), findsAtLeastNWidgets(2));
        expect(find.text('Pendidikan'), findsAtLeastNWidgets(2));
        expect(find.text('Keluarga'), findsAtLeastNWidgets(2));
        expect(find.text('CV'), findsAtLeastNWidgets(2));
        expect(find.text('Dokumen Surat'), findsAtLeastNWidgets(2));
        expect(find.text('Cuti'), findsAtLeastNWidgets(2));

        // Test on narrow mobile size (375x812) - ensures horizontal scroll avoids overflow
        tester.view.physicalSize = const Size(375, 812);
        await tester.pumpWidget(
          const MaterialApp(
            home: ProfileDetailScreen(user: samplePegawai, showBackButton: false),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cuti'), findsAtLeastNWidgets(2));

        // Scroll quick action bar horizontally on narrow phone & tap Cuti -> navigates to PengajuanCutiScreen
        await tester.ensureVisible(find.text('Cuti').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cuti').first);
        await tester.pumpAndSettle();

        expect(find.text('Cuti Pegawai'), findsOneWidget);
        expect(find.text('STATUS PENGAJUAN TERKINI'), findsOneWidget);
        expect(find.textContaining('850/001/SDM/XI/2026'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'PengajuanCutiScreen is view-only for web-submitted cuti without submit form/button and displays filters & surat button',
      (WidgetTester tester) async {
        String? capturedFilterStatus;

        CutiService.fetchOverride = ({nik, all = false, tahun, status}) async {
          capturedFilterStatus = status;
          final items = (status == 'PENDING')
              ? <PengajuanCuti>[]
              : [sampleCutiList.first];
          return CutiFetchResult(
            items: items,
            summary: CutiSummary.fromList([sampleCutiList.first], tahun: 2026),
          );
        };

        await tester.pumpWidget(
          const MaterialApp(home: PengajuanCutiScreen(user: samplePegawai)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sisa 9 dari 12 hari kerja (terpakai 3 hari)'), findsOneWidget);
        expect(find.text('Ajukan Permohonan Cuti'), findsNothing);
        expect(find.text('Ajukan / Input Cuti Pegawai'), findsNothing);
        expect(find.text('Cetak Surat Izin Cuti Resmi'), findsOneWidget);

        // Filter status Pending -> shows web-only empty message when none match
        await tester.tap(find.text('Pending').last);
        await tester.pumpAndSettle();

        expect(capturedFilterStatus, 'PENDING');
        expect(
          find.text('Belum ada data cuti yang diinput melalui web untuk periode ini.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'SDM user sees Kelola & Verifikasi tab and can approve/edit cuti with note',
      (WidgetTester tester) async {
        StatusCuti? capturedStatus;
        String? capturedCatatan;

        CutiService.fetchOverride = ({nik, all = false, tahun, status}) async {
          final list = all ? sampleCutiList : [sampleCutiList.first];
          return CutiFetchResult(
            items: list,
            summary: CutiSummary.fromList(list, tahun: 2026),
          );
        };
        CutiService.statusOverride = ({
          required pengajuan,
          required keputusan,
          required namaApprover,
          catatan,
        }) async {
          capturedStatus = keputusan;
          capturedCatatan = catatan;
        };

        await tester.pumpWidget(
          const MaterialApp(home: PengajuanCutiScreen(user: sampleSdm)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cuti Saya'), findsOneWidget);
        expect(find.text('Kelola & Verifikasi'), findsOneWidget);

        await tester.tap(find.text('Kelola & Verifikasi'));
        await tester.pumpAndSettle();

        expect(find.text('Budi Santoso'), findsOneWidget);
        await tester.tap(find.text('Setujui').first);
        await tester.pumpAndSettle();

        expect(find.text('Verifikasi Keputusan Cuti'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Catatan Approver / Alasan'),
          'Acc SDM',
        );
        await tester.tap(find.text('Setujui & Kirim Notifikasi'));
        await tester.pumpAndSettle();

        expect(capturedStatus, StatusCuti.disetujui);
        expect(capturedCatatan, 'Acc SDM');
      },
    );

    testWidgets('SuratCutiScreen renders official letter and builds valid PDF bytes',
        (WidgetTester tester) async {
      Uint8List? generatedPdf;
      CutiService.suratOverride = (id, {fallback}) async {
        return CutiSuratResult(
          cuti: sampleCutiList.first,
          pejabatTtd: const PejabatTtdCuti(),
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          home: SuratCutiScreen(
            cuti: sampleCutiList.first,
            onPdfGeneratedForTest: (bytes) => generatedPdf = bytes,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SURAT IZIN CUTI TAHUNAN'), findsOneWidget);
      expect(find.text('Nomor: 850/001/SDM/XI/2026'), findsOneWidget);
      expect(find.text('HEDDY KELANA, S.H.'), findsOneWidget);

      final bytes = await buildSuratCutiPdf(
        sampleCutiList.first,
        const PejabatTtdCuti(),
      );
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(generatedPdf, isNull);
    });
  });
}
