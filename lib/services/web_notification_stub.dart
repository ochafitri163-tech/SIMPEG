/// Stub (non-web) — tidak melakukan apa-apa.
/// File ini di-import saat build BUKAN untuk web.
void showWebNotification(String title, String body) {
  // No-op di Android/iOS/Desktop
}

Future<bool> requestWebNotificationPermission() async => false;
