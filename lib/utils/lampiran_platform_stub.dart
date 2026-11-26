import 'dart:typed_data';

Future<bool> platformDownloadBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  throw UnsupportedError('Platform download tidak didukung.');
}

Future<bool> platformOpenBytesInViewer(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  throw UnsupportedError('Platform viewer tidak didukung.');
}
