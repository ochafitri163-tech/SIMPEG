import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpeg_mobile/models/pengaduan_model.dart';
import 'package:simpeg_mobile/models/pengaduan_service.dart';
import 'package:simpeg_mobile/models/sk_sanksi_service.dart';
import 'package:simpeg_mobile/models/user_role.dart';
import 'package:simpeg_mobile/screens/auth/lupa_password_screen.dart';
import 'package:simpeg_mobile/screens/pegawai/ganti_password_screen.dart';
import 'package:simpeg_mobile/screens/pegawai/pengaduan_pegawai_screen.dart';
import 'package:simpeg_mobile/screens/pegawai/profile_screen_logout.dart';
import 'package:simpeg_mobile/screens/pegawai/sk_sanksi_screen.dart';
import 'package:simpeg_mobile/screens/pegawai/status_pengaduan_screen.dart';
import 'package:simpeg_mobile/screens/shared/detail_pengaduan_screen.dart';
import 'package:simpeg_mobile/services/api_service.dart';
import 'package:simpeg_mobile/services/notification_nav_helper.dart';
import 'package:simpeg_mobile/services/onesignal_service.dart';
import 'package:simpeg_mobile/widgets/konfirmasi_dialog.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/device_info'),
      (_) async => null,
    );
    SharedPreferences.setMockInitialValues({});
    ApiService.resetAuthCacheForTest();
  });

  test('ApiService migrates legacy plaintext token out of SharedPreferences & logout clears session', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'legacy-jwt-token',
      'user_nik': '1711001',
      'user_nama': 'Pegawai Satu',
    });

    final token = await ApiService.getAuthToken();
    expect(token, 'legacy-jwt-token');
    expect(await ApiService.hasAuthToken(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);

    await ApiService.logout();
    expect(await ApiService.hasAuthToken(), isFalse);
    expect(prefs.getString('user_nik'), isNull);
  });

  test('OneSignalService client REST push helpers complete without client REST secret', () async {
    await OneSignalService.sendNotificationToUser(
      userNikOrId: '1711001',
      title: 'Test',
      body: 'Body',
    );
    await OneSignalService.sendNotificationToRole(
      role: 'kspi',
      title: 'Test',
      body: 'Body',
    );
    await OneSignalService.sendBroadcastNotification(
      title: 'Broadcast',
      body: 'Body',
    );
  });

  testWidgets('GantiPasswordScreen enforces Old Password & distinct New Password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GantiPasswordScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Password Lama'), findsOneWidget);
    expect(find.text('Password Baru'), findsOneWidget);
    expect(find.text('Konfirmasi Password Baru'), findsOneWidget);

    await tester.tap(find.text('Simpan Password'));
    await tester.pump();
    expect(find.text('Password lama wajib diisi.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Password Lama'), 'Secret#2026');
    await tester.enterText(find.widgetWithText(TextField, 'Password Baru'), 'Secret#2026');
    await tester.enterText(find.widgetWithText(TextField, 'Konfirmasi Password Baru'), 'Secret#2026');
    await tester.ensureVisible(find.text('Simpan Password'));
    await tester.tap(find.text('Simpan Password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Password baru tidak boleh sama dengan password lama.'), findsOneWidget);
  });

  testWidgets('LupaPasswordScreen directs user to Bagian SDM without fake email confirmation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LupaPasswordScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pegawai@pdam.test');
    await tester.tap(find.text('Lihat Panduan Reset SDM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bagian SDM / Admin SIMPEG'), findsOneWidget);
    expect(find.textContaining('Tautan reset password telah dikirim'), findsNothing);
  });

  testWidgets('Dialogs dispose TextEditingController cleanly and scroll safely on compact screens', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                ElevatedButton(
                  onPressed: () => showDialogCatatan(context: context, judul: 'Catatan Uji'),
                  child: const Text('Buka Catatan'),
                ),
                ElevatedButton(
                  onPressed: () => confirmLogoutPatched(context),
                  child: const Text('Buka Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Catatan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tes dispose controller');
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buka Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar Akun?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ApiService.getAuthToken settles cleanly inside FakeAsync testWidgets', (tester) async {
    final t = await ApiService.getAuthToken();
    expect(t, '');
  });

  testWidgets('Kadiv task notification with pengaduan_id opens PengaduanDetailScreen, not StatusPengaduanScreen', (tester) async {
    addTearDown(NotificationNavHelper.resetNavigationState);
    const kadiv = AppUser(
      nik: '1711571',
      name: 'Kadiv Administrasi',
      role: UserRole.kadivKategori,
      divisiKadiv: DivisiKadiv.administrasi,
    );
    await ApiService.saveUserSession(kadiv.toJson());

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Dashboard Kadiv')),
      ),
    );
    await NotificationNavHelper.markDashboardReadyAndFlush();

    final clickFuture = NotificationNavHelper.handleNotificationClick({
      'type': 'task',
      'pengaduan_id': 999,
      'nomor': 'PGD-TEST-999',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await clickFuture;
    await tester.pump();

    expect(find.byType(PengaduanDetailScreen), findsOneWidget);
    expect(find.text('Informasi dan perkembangan laporan'), findsOneWidget);
    expect(find.byType(StatusPengaduanScreen), findsNothing);
  });

  testWidgets('SkSanksiScreen shows clean filename from Base64 URI and opens attachment via LampiranHelper', (tester) async {
    const pegawai = AppUser(
      nik: '1711431',
      name: 'Abdullah',
      role: UserRole.pegawai,
    );

    await SkSanksiService.terbitkan(
      nik: '1711431',
      namaPegawai: 'Abdullah',
      jenisSanksi: 'Penurunan Jabatan',
      tingkat: 'Berat',
      dokumen: {
        JenisDokumenSk.sk: ['data:application/pdf;name=sk_abdullah.pdf;base64,JVBERi0xLjQK'],
        JenisDokumenSk.buktiPelanggaran: ['data:application/pdf;name=bukti.pdf;base64,JVBERi0xLjQK'],
        JenisDokumenSk.hasilInvestigasiSpi: ['data:application/pdf;name=spi.pdf;base64,JVBERi0xLjQK'],
        JenisDokumenSk.keputusanDireksi: ['data:application/pdf;name=dirut.pdf;base64,JVBERi0xLjQK'],
      },
      diterbitkanOleh: 'Heddy Kelana, S.H.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SkSanksiScreen(user: pegawai),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('sk_abdullah.pdf'), findsOneWidget);
    await tester.tap(find.text('sk_abdullah.pdf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tidak dapat membuka dokumen.'), findsNothing);
    expect(find.byType(Dialog), findsWidgets);
  });

  testWidgets('StatusPengaduanScreen shows Ditolak for ditolakDirektur and Diproses (not Selesai) for peninjauanKembali', (tester) async {
    PengaduanService.resetLocalStateForTest();
    const pelapor = AppUser(
      nik: '1711001',
      name: 'Pelapor Uji',
      role: UserRole.pegawai,
    );

    await PengaduanService.submit(
      user: pelapor,
      kategori: 'Pelanggaran Administrasi',
      judul: 'Laporan Ditolak',
      pihakTerlapor: 'Terlapor A',
      nikPelaku: '1711222',
      jabatanPelaku: 'Staf',
      deskripsi: 'Deskripsi lengkap pengaduan minimal tiga puluh karakter untuk uji.',
    );
    final rows1 = await PengaduanService.punyaSaya(nik: '1711001');
    rows1.first['status'] = PengaduanStatus.ditolakDirektur.name;

    await PengaduanService.submit(
      user: pelapor,
      kategori: 'Pelanggaran Administrasi',
      judul: 'Laporan Peninjauan Kembali',
      pihakTerlapor: 'Terlapor B',
      nikPelaku: '1711223',
      jabatanPelaku: 'Staf',
      deskripsi: 'Deskripsi lengkap pengaduan minimal tiga puluh karakter untuk uji PK.',
    );
    final rows2 = await PengaduanService.punyaSaya(nik: '1711001');
    final pkRow = rows2.firstWhere((r) => r['judul'] == 'Laporan Peninjauan Kembali');
    pkRow['status'] = PengaduanStatus.peninjauanKembali.name;

    await tester.pumpWidget(
      const MaterialApp(
        home: StatusPengaduanScreen(user: pelapor),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.text('Ditolak'), findsOneWidget);

    // peninjauanKembali masuk cluster Investigasi (bukan Diarsipkan)
    await tester.tap(find.text('Investigasi'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan Peninjauan Kembali'), findsOneWidget);

    await tester.tap(find.text('Diarsipkan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan Peninjauan Kembali'), findsNothing);
  });

  testWidgets('PengaduanPegawaiScreen displays anonymous toggle switch', (tester) async {
    const pelapor = AppUser(
      nik: '1711001',
      name: 'Pelapor Uji',
      role: UserRole.pegawai,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: PengaduanPegawaiScreen(user: pelapor),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byType(SwitchListTile);
    await tester.scrollUntilVisible(
      switchFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Kirim Sebagai Pelapor Anonim'), findsOneWidget);
    expect(switchFinder, findsOneWidget);

    final initialSwitch = tester.widget<SwitchListTile>(switchFinder);
    expect(initialSwitch.value, isFalse);

    await tester.tap(switchFinder);
    await tester.pump();

    final updatedSwitch = tester.widget<SwitchListTile>(switchFinder);
    expect(updatedSwitch.value, isTrue);
  });
}

