import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

String _sanitizeFileName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'lampiran';
  return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

Future<bool> _openTempFileOnDesktop(Uint8List bytes, String safeName) async {
  try {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return await (() async {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}${Platform.pathSeparator}$safeName');
        await file.writeAsBytes(bytes, flush: true);
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return false;
      })().timeout(const Duration(seconds: 5), onTimeout: () => false);
    }
  } catch (_) {}
  return false;
}

Future<bool> platformDownloadBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final safeName = _sanitizeFileName(fileName);
  try {
    final info = await Printing.info().timeout(
      const Duration(seconds: 1),
      onTimeout: () => PrintingInfo.unavailable,
    );
    if (info.canShare) {
      final shared = await Printing.sharePdf(bytes: bytes, filename: safeName)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (shared) return true;
    }
  } catch (_) {}

  return _openTempFileOnDesktop(bytes, safeName);
}

Future<bool> platformOpenBytesInViewer(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final safeName = _sanitizeFileName(fileName);
  PrintingInfo info = PrintingInfo.unavailable;
  try {
    info = await Printing.info().timeout(
      const Duration(seconds: 1),
      onTimeout: () => PrintingInfo.unavailable,
    );
  } catch (_) {}

  if (mimeType == 'application/pdf' && info.canPrint) {
    try {
      final ok = await Printing.layoutPdf(
        name: safeName,
        onLayout: (_) async => bytes,
      ).timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (ok) return true;
    } catch (_) {}
  }

  if (await _openTempFileOnDesktop(bytes, safeName)) {
    return true;
  }

  if (info.canShare) {
    try {
      return await Printing.sharePdf(bytes: bytes, filename: safeName)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }
  return false;
}
