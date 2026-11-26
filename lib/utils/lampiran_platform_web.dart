import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;

Future<bool> platformDownloadBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final blobUrl = web.URL.createObjectURL(blob);
  final doc = web.window.document;
  final link = web.HTMLAnchorElement()
    ..href = blobUrl
    ..download = fileName
    ..style.display = 'none';
  doc.body?.append(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 60), () {
    web.URL.revokeObjectURL(blobUrl);
  });
  return true;
}

Future<bool> platformOpenBytesInViewer(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final blobUrl = web.URL.createObjectURL(blob);
  final opened = web.window.open(blobUrl, '_blank');
  if (opened != null) {
    Timer(const Duration(minutes: 5), () {
      web.URL.revokeObjectURL(blobUrl);
    });
    return true;
  }

  // Fallback jika browser memblokir window.open
  if (mimeType == 'application/pdf') {
    Timer(const Duration(seconds: 30), () {
      web.URL.revokeObjectURL(blobUrl);
    });
    return Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => bytes,
    );
  }

  final doc = web.window.document;
  final link = web.HTMLAnchorElement()
    ..href = blobUrl
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..style.display = 'none';
  doc.body?.append(link);
  link.click();
  link.remove();
  Timer(const Duration(minutes: 5), () {
    web.URL.revokeObjectURL(blobUrl);
  });
  return true;
}
