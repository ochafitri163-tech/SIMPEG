import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpeg_mobile/models/cuti_service.dart';
import 'package:simpeg_mobile/models/user_role.dart';
import 'package:simpeg_mobile/services/api_service.dart';
import 'package:simpeg_mobile/services/android_notification_compat_service.dart';
import 'package:simpeg_mobile/services/notification_deduplicator.dart';
import 'package:simpeg_mobile/services/notification_nav_helper.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationNavHelper.resetNavigationState();
    CutiService.resetForTest();
  });

  testWidgets(
    'Cold-start notification tap queues before dashboard and routes to PengajuanCutiScreen once dashboard is ready',
    (WidgetTester tester) async {
      CutiService.fetchOverride = ({nik, all = false, tahun, status}) async {
        return CutiFetchResult(
          items: const [],
          summary: CutiSummary.fromList(const [], tahun: 2026),
        );
      };

      await ApiService.saveUserSession(
        const AppUser(
          nik: '1711256',
          name: 'Aam Hamdan',
          jabatan: 'Manajer Unit Pelayanan Arahan',
          unitKerja: 'Cabang Arahan',
          golongan: 'Staf I / C.4',
          role: UserRole.pegawai,
        ).toJson(),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Dashboard Ready'))),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate cold-start click before dashboard finishes mounting
      await NotificationNavHelper.handleNotificationClick(
        {'type': 'cuti', 'id': '12'},
      );
      expect(find.text('Cuti Pegawai'), findsNothing);

      // Dashboard mounts and flushes pending notification (openCuti delays 300ms)
      unawaited(NotificationNavHelper.markDashboardReadyAndFlush());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Cuti Pegawai'), findsOneWidget);
    },
  );

  test('NotificationDeduplicator suppresses duplicate title+body within window', () {
    const t = 'Cuti Disetujui';
    const b = 'Pengajuan cuti Anda disetujui SDM.';
    expect(NotificationDeduplicator.shouldDisplay(t, b), isTrue);
    expect(NotificationDeduplicator.shouldDisplay(t, b), isFalse);
    expect(
      NotificationDeduplicator.shouldDisplay('Pengumuman Baru', 'Apel pagi'),
      isTrue,
    );
  });

  test('AndroidNotificationDiagnostic detects OEM policies and guidance', () {
    const xiaomiDiag = AndroidNotificationDiagnostic(
      notificationsEnabled: false,
      ignoringBatteryOptimizations: false,
      sdkInt: 34,
      manufacturer: 'xiaomi',
      model: 'Redmi Note 13',
      urgentChannelImportance: 4,
    );
    expect(xiaomiDiag.needsAttention, isTrue);
    expect(xiaomiDiag.hasStrictOemPolicy, isTrue);
    expect(xiaomiDiag.oemGuidance, contains('Autostart'));

    const pixelOk = AndroidNotificationDiagnostic(
      notificationsEnabled: true,
      ignoringBatteryOptimizations: true,
      sdkInt: 35,
      manufacturer: 'google',
      model: 'Pixel 9',
      urgentChannelImportance: 5,
    );
    expect(pixelOk.needsAttention, isFalse);
    expect(pixelOk.hasStrictOemPolicy, isFalse);
  });

  testWidgets(
    'NotificationNavHelper routes new notification types cleanly',
    (WidgetTester tester) async {
      await ApiService.saveUserSession(
        const AppUser(
          nik: '1711256',
          name: 'Aam Hamdan',
          jabatan: 'Pegawai',
          unitKerja: 'Pusat',
          golongan: 'C.4',
          role: UserRole.pegawai,
        ).toJson(),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Center(child: Text('Home'))),
        ),
      );
      await NotificationNavHelper.markDashboardReadyAndFlush();

      unawaited(NotificationNavHelper.handleNotificationClick({'type': 'sanksi'}));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Riwayat Sanksi'), findsOneWidget);
    },
  );
}
