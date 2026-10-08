import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'web_notification_stub.dart'
    if (dart.library.js_interop) 'web_notification_web.dart';

/// Service pengganti FcmService (Firebase sudah dihapus).
///
/// Fungsi utama:
/// 1. Subscribe ke Supabase Realtime untuk semua tabel notifikasi
///    (pengumuman, payroll, thr, gaji_13, insentif, pengaduan, cuti,
///    lembur, dokumen) lalu menampilkan notifikasi lokal.
/// 2. Pada platform Web: menggunakan Web Notifications API sebagai
///    fallback karena flutter_local_notifications tidak support Web.
/// 3. Pada Android/iOS: menggunakan flutter_local_notifications.
class RealtimeNotificationService {
  RealtimeNotificationService._();
  static final RealtimeNotificationService instance =
      RealtimeNotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Minta izin notifikasi browser saat pertama kali init di Web
    if (kIsWeb) {
      try {
        await requestWebNotificationPermission();
      } catch (_) {}
    }

    // 1. Supabase Realtime Listener untuk Pengumuman Baru & Update
    try {
      Supabase.instance.client
          .channel('public:pengumuman')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'pengumuman',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              final eventType = payload.eventType;

              if (eventType == PostgresChangeEvent.delete) {
                final oldId = (oldRecord['id'] as num?)?.toInt();
                if (oldId != null) {
                  NotificationService.instance.cancelPengumuman(oldId);
                }
                return;
              }

              if (newRecord.isEmpty) return;

              final id = (newRecord['id'] as num?)?.toInt() ??
                  (DateTime.now().millisecondsSinceEpoch ~/ 1000);
              final aktif = newRecord['aktif'] as bool? ?? true;

              // Jika dinonaktifkan, batalkan notifikasi terjadwal
              if (!aktif) {
                NotificationService.instance.cancelPengumuman(id);
                return;
              }

              final judul =
                  newRecord['judul'] as String? ?? 'Pengumuman Baru';
              final isi = newRecord['isi'] as String? ??
                  'Ada pengumuman terbaru dari PDAM.';
              final title = '📢 Pengumuman Baru';
              final body = judul.isNotEmpty ? judul : isi;

              final terbitStr = newRecord['terbit_pada'] as String?;
              final kedaluwarsaStr =
                  newRecord['kedaluwarsa_pada'] as String?;
              final now = DateTime.now().toUtc();

              DateTime? terbitPada = terbitStr != null
                  ? DateTime.tryParse(terbitStr)?.toUtc()
                  : null;
              DateTime? kedaluwarsaPada = kedaluwarsaStr != null
                  ? DateTime.tryParse(kedaluwarsaStr)?.toUtc()
                  : null;

              // Jika sudah kedaluwarsa, batalkan & abaikan
              if (kedaluwarsaPada != null &&
                  kedaluwarsaPada.isBefore(now)) {
                NotificationService.instance.cancelPengumuman(id);
                return;
              }

              // Jika dijadwalkan di masa depan, jadwalkan notifikasi lokal
              if (terbitPada != null && terbitPada.isAfter(now)) {
                if (kDebugMode) {
                  print(
                      'Pengumuman terjadwal diterima: $judul untuk $terbitPada');
                }
                if (!kIsWeb) {
                  NotificationService.instance.schedulePengumuman(
                    id: id,
                    title: title,
                    body: body,
                    scheduledDate: terbitPada.toLocal(),
                  );
                }
                return;
              }

              // Jika baru di-insert dan langsung tayang
              if (eventType == PostgresChangeEvent.insert) {
                if (kDebugMode) {
                  print(
                      'Supabase Realtime Insert Langsung Tayang: $judul');
                }
                _showNotification(title: title, body: body);
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) {
        print('Supabase Realtime subscription error (pengumuman): $e');
      }
    }

    // 2. Supabase Realtime Listener untuk Notifikasi Umum / In-App (lonceng & popup)
    _subscribeTable('notifikasi', PostgresChangeEvent.insert, (newRecord) {
      final judul = newRecord['judul'] as String? ?? 'Notifikasi Baru';
      final pesan = newRecord['pesan'] as String? ?? 'Anda memiliki notifikasi baru.';
      _showNotification(
        title: judul,
        body: pesan,
      );
    });

    // 3. Supabase Realtime Listener untuk Gaji Masuk (Payroll) saat terbit
    _subscribeTable('payroll', PostgresChangeEvent.all, (newRecord) {
      final status = (newRecord['status'] as String? ?? '').toUpperCase();
      if (status == 'DITERBITKAN') {
        _showNotification(
          title: '💰 Gaji Masuk!',
          body:
              'Slip gaji periode ${newRecord['periode'] ?? '-'} telah diterbitkan.',
        );
      }
    });

    // 3. Supabase Realtime Listener untuk THR Masuk
    _subscribeTable('thr', PostgresChangeEvent.insert, (newRecord) {
      _showNotification(
        title: '🎉 THR Masuk!',
        body:
            'THR periode ${newRecord['periode'] ?? '-'} telah diterbitkan.',
      );
    });

    // 4. Supabase Realtime Listener untuk Gaji 13
    _subscribeTable('gaji_13', PostgresChangeEvent.insert, (newRecord) {
      _showNotification(
        title: '📚 Tunjangan Pendidikan Masuk!',
        body: 'Gaji ke-13 / Tunjangan Pendidikan telah diterbitkan.',
      );
    });

    // 5. Supabase Realtime Listener untuk Insentif
    _subscribeTable('insentif', PostgresChangeEvent.insert, (newRecord) {
      _showNotification(
        title: '💵 Insentif Masuk!',
        body:
            'Slip insentif periode ${newRecord['periode'] ?? '-'} telah diterbitkan.',
      );
    });

    // 6. Supabase Realtime Listener untuk Pengaduan (status update)
    _subscribeTable('pengaduan_pegawai', PostgresChangeEvent.update,
        (newRecord) {
      final status = newRecord['status'] as String? ?? '';
      final judul = newRecord['judul'] as String? ?? 'pengaduan';
      _showNotification(
        title: '📋 Update Pengaduan',
        body: 'Pengaduan "$judul" sekarang berstatus: $status',
      );
    });

    // 7. Supabase Realtime Listener untuk Pengajuan Cuti (approval)
    _subscribeTable('pengajuan_cuti', PostgresChangeEvent.update,
        (newRecord) {
      final status = newRecord['status'] as String? ?? '';
      _showNotification(
        title: '📝 Update Pengajuan Cuti',
        body: 'Pengajuan cuti Anda sekarang berstatus: $status',
      );
    });

    // 8. Supabase Realtime Listener untuk Lembur
    _subscribeTable('lembur', PostgresChangeEvent.insert, (newRecord) {
      final bulan = newRecord['bulan'] as String? ?? '-';
      _showNotification(
        title: '⏰ Data Lembur',
        body: 'Data lembur bulan $bulan telah dicatat.',
      );
    });

    // 9. Supabase Realtime Listener untuk Dokumen Kepegawaian
    _subscribeTable('dokumen_pegawai', PostgresChangeEvent.insert,
        (newRecord) {
      final judul = newRecord['judul'] as String? ?? 'Dokumen Baru';
      _showNotification(
        title: '📄 Dokumen Baru',
        body: 'Dokumen "$judul" telah diunggah oleh SDM.',
      );
    });

    _initialized = true;
  }

  /// Menampilkan notifikasi — otomatis pilih metode yang sesuai platform.
  /// - Android/iOS: flutter_local_notifications (status bar)
  /// - Web: Web Notifications API (browser notification)
  void _showNotification({required String title, required String body}) {
    if (kIsWeb) {
      showWebNotification(title, body);
    } else {
      // Gunakan flutter_local_notifications via NotificationService
      NotificationService.instance.showPengumuman(
        title: title,
        body: body,
      );
    }
  }

  /// Helper: subscribe ke Supabase Realtime untuk tabel tertentu.
  /// Filter notifikasi agar hanya tampil untuk pegawai yang sedang login.
  void _subscribeTable(
    String table,
    PostgresChangeEvent event,
    void Function(Map<String, dynamic> newRecord) onEvent,
  ) {
    try {
      Supabase.instance.client
          .channel('public:$table')
          .onPostgresChanges(
            event: event,
            schema: 'public',
            table: table,
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isEmpty) return;

              // Filter: hanya tampilkan notifikasi untuk pegawai yang login
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final recordPegawaiId =
                  (newRecord['pegawai_id'] ?? newRecord['untuk_pegawai_id'])?.toString();

              // Jika user sedang login via Supabase Auth, filter per pegawai_id
              if (currentUserId != null &&
                  recordPegawaiId != null &&
                  recordPegawaiId != currentUserId) {
                return;
              }

              if (kDebugMode) {
                print(
                    'Supabase Realtime [$table] event: ${payload.eventType}');
              }

              onEvent(newRecord);
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) {
        print('Supabase Realtime [$table] subscription error: $e');
      }
    }
  }
}
