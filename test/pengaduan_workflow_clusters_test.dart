import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simpeg_mobile/models/pengaduan_model.dart';
import 'package:simpeg_mobile/models/pengaduan_service.dart';
import 'package:simpeg_mobile/models/task_model.dart';
import 'package:simpeg_mobile/models/user_role.dart';
import 'package:simpeg_mobile/screens/dirut/dashboard_dirut_screen.dart';
import 'package:simpeg_mobile/screens/kspi/dashboard_kspi_screen.dart';
import 'package:simpeg_mobile/screens/shared/detail_pengaduan_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PengaduanService.resetLocalStateForTest();
  });

  const pelapor = AppUser(
    nik: '1711001',
    name: 'Pelapor Satu',
    jabatan: 'Staf Teknik',
    unitKerja: 'Distribusi',
    golongan: 'II/C',
    role: UserRole.pegawai,
  );

  const kadivTeknik = AppUser(
    nik: '1711251',
    name: 'Nurkhuliyah',
    jabatan: 'Kadiv SPI Teknik',
    unitKerja: 'SPI',
    golongan: 'III/D',
    role: UserRole.kadivKategori,
    divisiKadiv: DivisiKadiv.teknik,
  );

  const kspiUser = AppUser(
    nik: '1711161',
    name: 'Dodi Sudrajat, S.E., M.M.',
    jabatan: 'Ketua SPI',
    unitKerja: 'SPI',
    golongan: 'IV/A',
    role: UserRole.kspi,
  );

  const tpdpkUser = AppUser(
    nik: '1711999',
    name: 'Anggota TPDPK',
    jabatan: 'Tim TPDPK',
    unitKerja: 'SPI',
    golongan: 'III/B',
    role: UserRole.tpdpk,
  );

  const dirutUser = AppUser(
    nik: '1700001',
    name: 'Nurpan, S.E., M.Si.',
    jabatan: 'Direktur Utama',
    unitKerja: 'Direksi',
    golongan: 'Direksi',
    role: UserRole.direktur,
  );

  group('End-to-end cluster visibility across roles', () {
    test('retains approved/submitted pengaduan in source cluster while entering next step cluster',
        () async {
      await PengaduanService.submit(
        user: pelapor,
        kategori: 'Pelanggaran Teknik',
        judul: 'Dugaan Pengurangan Kualitas Material',
        deskripsi:
            'Material pipa yang terpasang tidak sesuai spesifikasi teknis kontrak.',
        pihakTerlapor: 'Terlapor Teknik',
        nikPelaku: '1711222',
        jabatanPelaku: 'Pelaksana',
      );

      // 1. Baru diajukan -> masuk Kadiv Teknik cluster Menunggu Verifikasi, belum masuk Dirut/KSPI
      final kadivList1 = await PengaduanService.untukRoleSebagaiObjek(
        UserRole.kadivKategori,
        divisiKadiv: 'teknik',
      );
      expect(kadivList1.length, 1);
      final p1 = kadivList1.first;
      final id = p1.supabaseId!;
      expect(p1.kadivMasukClusterVerifikasi(kadivTeknik), isTrue);
      expect(p1.kadivPerluVerifikasi, isTrue);
      expect(
        await PengaduanService.untukRoleSebagaiObjek(UserRole.direktur),
        isEmpty,
      );

      // 2. Kadiv terima -> tetap terlihat di cluster Verifikasi & Diterima Kadiv + masuk KSPI Diterima Kadiv
      await PengaduanService.kadivAksi(
        pengaduanId: id,
        oleh: kadivTeknik.name,
        keputusan: Keputusan.terima,
        catatan: 'Teruskan ke KSPI',
      );
      final kadivList2 = await PengaduanService.untukRoleSebagaiObjek(
        UserRole.kadivKategori,
        divisiKadiv: 'teknik',
      );
      expect(kadivList2.first.kadivMasukClusterVerifikasi(kadivTeknik), isTrue);
      expect(kadivList2.first.kadivPerluVerifikasi, isFalse);

      final kspiList2 = await PengaduanService.untukRoleSebagaiObjek(UserRole.kspi);
      expect(kspiList2.length, 1);
      expect(kspiList2.first.kspiMasukClusterDiterimaKadiv, isTrue);
      expect(kspiList2.first.kspiMenungguReviewAwal, isTrue);

      // 3. KSPI teruskan ke Dirut -> tetap di Diterima Kadiv (KSPI) & masuk Dirut Approval Tahap 1
      await PengaduanService.kspiTeruskanKeDirut(
        pengaduanId: id,
        oleh: kspiUser.name,
      );
      final kspiList3 = await PengaduanService.untukRoleSebagaiObjek(UserRole.kspi);
      expect(kspiList3.first.kspiMasukClusterDiterimaKadiv, isTrue);
      expect(kspiList3.first.kspiMenungguReviewAwal, isFalse);

      final dirutList3 =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
      expect(dirutList3.length, 1);
      expect(dirutList3.first.dirutMasukClusterTahap1, isTrue);
      expect(dirutList3.first.dirutMenungguTahap1, isTrue);

      // 4. Dirut menyetujui Tahap 1 -> TETAP muncul di Dirut Approval Tahap 1 & MASUK ke KSPI Pilih Eksekutor
      await PengaduanService.dirutTahap1Aksi(
        pengaduanId: id,
        oleh: dirutUser.name,
        keputusan: Keputusan.terima,
        catatan: 'Layak diinvestigasi',
      );
      final dirutList4 =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
      expect(dirutList4.length, 1);
      expect(dirutList4.first.status, PengaduanStatus.menungguPilihEksekutor);
      expect(dirutList4.first.dirutMasukClusterTahap1, isTrue);
      expect(dirutList4.first.dirutMenungguTahap1, isFalse);

      final kspiList4 = await PengaduanService.untukRoleSebagaiObjek(UserRole.kspi);
      expect(kspiList4.first.kspiMasukClusterPilihEksekutor, isTrue);
      expect(kspiList4.first.kspiMenungguPilihEksekutor, isTrue);

      // 5. KSPI memilih TPDPK -> TETAP muncul di KSPI Pilih Eksekutor & Dirut Approval Tahap 1 + MASUK ke TPDPK Investigasi Berjalan
      await PengaduanService.reviewDanPilihEksekutor(
        pengaduanId: id,
        oleh: kspiUser.name,
        selectedExecutors: [
          PegawaiOption(
            id: tpdpkUser.id,
            nik: tpdpkUser.nik,
            name: tpdpkUser.name,
            jabatan: tpdpkUser.jabatan,
            unitKerja: tpdpkUser.unitKerja,
            role: 'tpdpk',
          ),
        ],
        eksekutorCategory: 'tpdpk',
      );
      final kspiList5 = await PengaduanService.untukRoleSebagaiObjek(UserRole.kspi);
      expect(kspiList5.first.kspiMasukClusterPilihEksekutor, isTrue);
      expect(kspiList5.first.kspiMenungguPilihEksekutor, isFalse);

      final tpdpkList5 =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.tpdpk);
      expect(tpdpkList5.length, 1);
      expect(tpdpkList5.first.tpdpkMasukClusterInvestigasi, isTrue);
      expect(tpdpkList5.first.tpdpkInvestigasiAktif, isTrue);

      // 6. TPDPK mengirim hasil investigasi (Terbukti) -> TETAP di TPDPK Investigasi Berjalan & MASUK Dirut Approval Tahap 2
      await PengaduanService.kirimHasilInvestigasi(
        pengaduanId: id,
        oleh: tpdpkUser.name,
        role: UserRole.tpdpk,
        kesimpulan: 'Terbukti',
        hasilInvestigasi: 'Ditemukan ketidaksesuaian spesifikasi pipa.',
        suratRekomendasi: 'Sanksi sedang',
      );
      final tpdpkList6 =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.tpdpk);
      expect(tpdpkList6.first.tpdpkMasukClusterInvestigasi, isTrue);
      expect(tpdpkList6.first.tpdpkInvestigasiAktif, isFalse);

      final dirutList6 =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
      expect(dirutList6.first.dirutMasukClusterTahap1, isTrue);
      expect(dirutList6.first.dirutMasukClusterTahap2, isTrue);
      expect(dirutList6.first.dirutMenungguTahap2, isTrue);

      // 7. Dirut menyetujui Tahap 2 (Terbukti) -> TETAP di Dirut Approval Tahap 2 & MASUK ke SDM Menunggu SK Sanksi
      await PengaduanService.direksiTahap2Aksi(
        pengaduanId: id,
        oleh: dirutUser.name,
        keputusan: Keputusan.terima,
        kesimpulanInvestigasi: 'Terbukti',
      );
      final dirutList7 =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
      expect(dirutList7.first.dirutMasukClusterTahap2, isTrue);
      expect(dirutList7.first.dirutMenungguTahap2, isFalse);

      final sdmList7 = await PengaduanService.untukRoleSebagaiObjek(UserRole.sdm);
      expect(sdmList7.length, 1);
      expect(sdmList7.first.sdmMasukClusterMenunggu, isTrue);
      expect(sdmList7.first.sdmMenungguTindakLanjut, isTrue);

      // 8. SDM menerbitkan putusan -> TETAP terlihat di SDM Menunggu SK Sanksi (selesai) & selesai di seluruh role
      await PengaduanService.sdmSelesaikan(
        pengaduanId: id,
        oleh: 'Admin SDM',
        nomorSuratPutusan: 'SK-001/2026',
        jenisSanksi: 'Teguran Tertulis',
      );
      final sdmList8 = await PengaduanService.untukRoleSebagaiObjek(UserRole.sdm);
      expect(sdmList8.first.sdmMasukClusterMenunggu, isTrue);
      expect(sdmList8.first.sdmMenungguTindakLanjut, isFalse);
      expect(sdmList8.first.status, PengaduanStatus.selesai);
    });

    test('does not include cases archived by KSPI before Dirut in Dirut Tahap 1 cluster', () {
      final kspiArchived = pengaduanFromRow({
        'id': 999,
        'nomor_pengaduan': 'PGD-999',
        'status': 'arsip',
        'keputusan_kadiv': 'tolak',
        'arsip_pada_tahap': 'kspi',
      });
      expect(kspiArchived.dirutMasukClusterTahap1, isFalse);
      expect(kspiArchived.kspiMasukClusterDitolakKadiv, isTrue);
    });
  });

  group('Dashboard Dirut & KSPI cluster widget behavior', () {
    testWidgets(
        'Dirut Approval Tahap 1 keeps approved pengaduan alongside pending ones and KSPI shows it in Pilih Eksekutor',
        (tester) async {
      PengaduanService.seedLocalPengaduanForTest({
        'id': 501,
        'nomor_pengaduan': 'PGD-202610-009',
        'kategori': 'Pelanggaran Teknik',
        'judul': 'PENDING TAHAP 1 MATERIAL',
        'deskripsi': 'Deskripsi pengaduan menunggu approval tahap 1 oleh Dirut.',
        'status': 'menungguDirutTahap1',
        'keputusan_kadiv': 'terima',
        'tanggal_pengaduan': '2026-11-25T10:00:00Z',
      });
      PengaduanService.seedLocalPengaduanForTest({
        'id': 502,
        'nomor_pengaduan': 'PGD-202610-010',
        'kategori': 'Pelanggaran Teknik',
        'judul': 'SUDAH DIAPPROVE TAHAP 1 LANJUT KSPI',
        'deskripsi': 'Pengaduan sudah disetujui Dirut Tahap 1 dan diteruskan ke KSPI.',
        'status': 'menungguPilihEksekutor',
        'keputusan_kadiv': 'terima',
        'keputusan_dirut_tahap1': 'terima',
        'tanggal_pengaduan': '2026-11-25T12:00:00Z',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardDirutScreen(user: dirutUser, showBackButton: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap cluster Approval Tahap 1 dan pastikan item pending maupun yang sudah diapprove Tahap 1 muncul
      final chipTahap1 = find.text('Approval Tahap 1');
      await tester.ensureVisible(chipTahap1);
      await tester.tap(chipTahap1);
      await tester.pumpAndSettle();

      expect(find.text('PENDING TAHAP 1 MATERIAL'), findsOneWidget);
      expect(find.text('SUDAH DIAPPROVE TAHAP 1 LANJUT KSPI'), findsOneWidget);
      // Item pending masih punya tombol Tinjau & Verifikasi (hanya 1 tombol untuk yang pending),
      // sedangkan yang sudah disetujui menampilkan ringkasan keputusan Tahap 1: Terima
      expect(find.text('Tinjau & Verifikasi'), findsOneWidget);
      expect(find.textContaining('Tahap 1: Terima'), findsOneWidget);

      // Verifikasi item yang sama masuk ke cluster Pilih Eksekutor pada dashboard KSPI
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardKspiScreen(user: kspiUser, showBackButton: false),
        ),
      );
      await tester.pumpAndSettle();

      final chipPilihEksekutor = find.text('Pilih Eksekutor').first;
      await tester.ensureVisible(chipPilihEksekutor);
      await tester.tap(chipPilihEksekutor);
      await tester.pumpAndSettle();

      expect(find.text('SUDAH DIAPPROVE TAHAP 1 LANJUT KSPI'), findsOneWidget);
      expect(find.text('Pilih Eksekutor'), findsAtLeastNWidgets(2));
    });

    testWidgets(
        'Peninjauan Kembali routes post-PK investigation to Dirut Approval Tahap 3 and preserves all rounds & evidence',
        (tester) async {
      await PengaduanService.submit(
        user: pelapor,
        kategori: 'Pelanggaran Administrasi',
        judul: 'Dugaan Manipulasi Laporan Proyek',
        deskripsi: 'Laporan realisasi tidak sesuai kuitansi lapangan.',
        pihakTerlapor: 'Terlapor Admin',
        nikPelaku: '1711333',
        jabatanPelaku: 'Staf Proyek',
      );

      final initList = await PengaduanService.untukRoleSebagaiObjek(
        UserRole.kadivKategori,
        divisiKadiv: 'administrasi',
      );
      final id = initList.first.supabaseId!;

      await PengaduanService.kadivAksi(
        pengaduanId: id,
        oleh: 'Kadiv Admin',
        keputusan: Keputusan.terima,
      );
      await PengaduanService.dirutTahap1Aksi(
        pengaduanId: id,
        oleh: dirutUser.name,
        keputusan: Keputusan.terima,
      );
      await PengaduanService.reviewDanPilihEksekutor(
        pengaduanId: id,
        oleh: kspiUser.name,
        selectedExecutors: [
          PegawaiOption(
            id: tpdpkUser.id,
            nik: tpdpkUser.nik,
            name: tpdpkUser.name,
            jabatan: tpdpkUser.jabatan,
            unitKerja: tpdpkUser.unitKerja,
            role: 'tpdpk',
          ),
        ],
        eksekutorCategory: 'tpdpk',
      );

      // Putaran 1: Tidak Terbukti + bukti putaran 1
      await PengaduanService.kirimHasilInvestigasi(
        pengaduanId: id,
        oleh: tpdpkUser.name,
        role: UserRole.tpdpk,
        kesimpulan: 'tidak_terbukti',
        hasilInvestigasi: 'Temuan Putaran Satu belum cukup bukti.',
        suratRekomendasi: 'Pulihkan nama baik terlapor sementara.',
        foto: const ['https://example.com/bukti-putaran-1.jpg'],
        dokumen: const ['https://example.com/dok-putaran-1.pdf'],
      );

      // Dirut memilih Peninjauan Kembali -> kembali ke KSPI
      await PengaduanService.direksiTahap2PeninjauanKembali(
        pengaduanId: id,
        oleh: dirutUser.name,
        catatan: 'Periksa ulang saksi gudang & kuitansi asli',
      );

      // KSPI memilih eksekutor lagi -> TPDPK investigasi ulang
      await PengaduanService.reviewDanPilihEksekutor(
        pengaduanId: id,
        oleh: kspiUser.name,
        selectedExecutors: const [
          PegawaiOption(
            id: 'tpdpk-ulang',
            nik: '1711998',
            name: 'Tim PK Ulang',
            jabatan: 'Tim TPDPK',
            unitKerja: 'SPI',
            role: 'tpdpk',
          ),
        ],
        eksekutorCategory: 'tpdpk',
      );

      // Putaran 2 (Peninjauan Kembali): Terbukti + bukti baru
      await PengaduanService.kirimHasilInvestigasi(
        pengaduanId: id,
        oleh: 'Tim PK Ulang',
        role: UserRole.tpdpk,
        kesimpulan: 'terbukti',
        hasilInvestigasi: 'Temuan Putaran Dua membuktikan selisih kuitansi.',
        suratRekomendasi: 'Berikan sanksi disiplin tingkat sedang.',
        foto: const ['https://example.com/bukti-putaran-2.jpg'],
        dokumen: const ['https://example.com/dok-putaran-2.pdf'],
      );

      final dirutItemsBeforeApprove =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
      expect(dirutItemsBeforeApprove.length, 1);
      final pTahap3 = dirutItemsBeforeApprove.first;
      expect(pTahap3.status, PengaduanStatus.menungguDirutTahap3);
      expect(pTahap3.dirutMenungguTahap3, isTrue);
      expect(pTahap3.dirutMenungguTahap2, isFalse);
      expect(pTahap3.dirutMasukClusterTahap2, isTrue);
      expect(pTahap3.dirutMasukClusterTahap3, isTrue);
      expect(pTahap3.daftarHasilInvestigasi.length, 2);

      // Verifikasi cluster Approval Tahap 3 di Dashboard Dirut
      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardDirutScreen(user: dirutUser, showBackButton: false),
        ),
      );
      await tester.pumpAndSettle();

      final chipTahap3 = find.text('Approval Tahap 3');
      await tester.ensureVisible(chipTahap3);
      await tester.tap(chipTahap3);
      await tester.pumpAndSettle();

      expect(find.text('Dugaan Manipulasi Laporan Proyek'), findsOneWidget);
      expect(
        find.text('Menunggu Persetujuan Dirut (Tahap 3)'),
        findsOneWidget,
      );
      expect(find.text('Tinjau & Verifikasi (Tahap 3)'), findsOneWidget);

      // Verifikasi DetailPengaduanScreen menampilkan kedua putaran & riwayat lengkap
      await tester.pumpWidget(
        MaterialApp(
          home: PengaduanDetailScreen(
            user: dirutUser,
            pengaduanId: id,
            showAction: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Hasil Investigasi (2 Putaran)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Hasil Investigasi (2 Putaran)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('KESIMPULAN: TIDAK TERBUKTI'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('KESIMPULAN: TIDAK TERBUKTI'), findsOneWidget);
      expect(
        find.textContaining('Temuan Putaran Satu belum cukup bukti.'),
        findsAtLeastNWidgets(1),
      );

      await tester.scrollUntilVisible(
        find.text('KESIMPULAN: TERBUKTI'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('KESIMPULAN: TERBUKTI'), findsOneWidget);
      expect(
        find.textContaining('Temuan Putaran Dua membuktikan selisih kuitansi.'),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.textContaining('Periksa ulang saksi gudang & kuitansi asli'),
        findsAtLeastNWidgets(1),
      );

      // Setelah Dirut menyetujui di Tahap 3 -> lanjut menungguSdm & tetap ada di cluster Tahap 3
      await PengaduanService.direksiTahap2Aksi(
        pengaduanId: id,
        oleh: dirutUser.name,
        keputusan: Keputusan.terima,
        catatan: 'Disetujui pada Approval Tahap 3',
      );
      final dirutItemsAfterApprove =
          await PengaduanService.untukRoleSebagaiObjek(UserRole.direktur);
      final pAfter = dirutItemsAfterApprove.first;
      expect(pAfter.status, PengaduanStatus.menungguSdm);
      expect(pAfter.dirutMenungguTahap3, isFalse);
      expect(pAfter.dirutMasukClusterTahap3, isTrue);
    });
  });
}
