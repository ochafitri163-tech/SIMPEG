import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'lampiran_platform_stub.dart'
    if (dart.library.js_interop) 'lampiran_platform_web.dart'
    if (dart.library.io) 'lampiran_platform_io.dart';

class DecodedDataUri {
  final Uint8List bytes;
  final String mimeType;
  final String? fileName;

  const DecodedDataUri({
    required this.bytes,
    required this.mimeType,
    this.fileName,
  });
}

class PdfPageRaster {
  final Uint8List pngBytes;
  final int width;
  final int height;

  const PdfPageRaster({
    required this.pngBytes,
    required this.width,
    required this.height,
  });
}

class LampiranHelper {
  LampiranHelper._();

  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _green = Color(0xFF27AE60);
  static const Color _red = Color(0xFFE74C3C);

  /// Decode URI `data:...;base64,...` dengan aman (termasuk normalisasi spasi dan padding).
  static DecodedDataUri? tryDecodeDataUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (!trimmed.toLowerCase().startsWith('data:')) {
      return null;
    }

    final commaIdx = trimmed.indexOf(',');
    if (commaIdx == -1 || commaIdx >= trimmed.length - 1) {
      return null;
    }

    final header = trimmed.substring(5, commaIdx);
    final headerParts = header.split(';');
    final rawMime = headerParts.isNotEmpty ? headerParts.first.trim().toLowerCase() : '';
    final mimeType = rawMime.isNotEmpty ? rawMime : 'application/octet-stream';

    String? fileName;
    final nameMatch = RegExp(r'name=([^;]+)', caseSensitive: false).firstMatch(header);
    if (nameMatch != null) {
      final rawName = nameMatch.group(1)!.trim();
      try {
        fileName = Uri.decodeComponent(rawName);
      } catch (_) {
        fileName = rawName;
      }
    }

    final isBase64 = headerParts.any((p) => p.trim().toLowerCase() == 'base64');
    final payload = trimmed.substring(commaIdx + 1);

    try {
      if (isBase64) {
        var normalized = payload.replaceAll(RegExp(r'\s+'), '');
        if (normalized.isEmpty) return null;
        // Dukung URL-safe base64 bila ada
        normalized = normalized.replaceAll('-', '+').replaceAll('_', '/');
        final mod = normalized.length % 4;
        if (mod != 0) {
          normalized = normalized.padRight(normalized.length + (4 - mod), '=');
        }
        final bytes = base64Decode(normalized);
        if (bytes.isEmpty) return null;
        return DecodedDataUri(
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        );
      } else {
        final decodedText = Uri.decodeComponent(payload);
        final bytes = Uint8List.fromList(utf8.encode(decodedText));
        if (bytes.isEmpty) return null;
        return DecodedDataUri(
          bytes: bytes,
          mimeType: mimeType,
          fileName: fileName,
        );
      }
    } catch (_) {
      return null;
    }
  }

  static String resolveUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.toLowerCase().startsWith('data:')) {
      return trimmed;
    }
    return ApiService.resolveUrl(trimmed) ?? trimmed;
  }

  static String extractFileName(
    String rawUrl, {
    String fallback = 'lampiran',
  }) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return fallback;

    if (trimmed.toLowerCase().startsWith('data:')) {
      final commaIdx = trimmed.indexOf(',');
      final header = commaIdx != -1 ? trimmed.substring(0, commaIdx) : trimmed;
      final nameMatch = RegExp(r'name=([^;]+)', caseSensitive: false).firstMatch(header);
      if (nameMatch != null) {
        final rawName = nameMatch.group(1)!.trim();
        if (rawName.isNotEmpty) {
          try {
            return Uri.decodeComponent(rawName);
          } catch (_) {
            return rawName;
          }
        }
      }
      String withExt(String ext) {
        if (RegExp(r'\.[a-z0-9]{2,5}$', caseSensitive: false)
            .hasMatch(fallback)) {
          return fallback;
        }
        return '$fallback$ext';
      }

      final lowerHeader = header.toLowerCase();
      if (lowerHeader.contains('application/pdf')) return withExt('.pdf');
      if (lowerHeader.contains('word') || lowerHeader.contains('msword')) {
        return withExt('.docx');
      }
      if (lowerHeader.contains('excel') || lowerHeader.contains('sheet')) {
        return withExt('.xlsx');
      }
      if (lowerHeader.contains('image/png')) return withExt('.png');
      if (lowerHeader.contains('image/webp')) return withExt('.webp');
      if (lowerHeader.contains('image/gif')) return withExt('.gif');
      if (lowerHeader.contains('image/')) return withExt('.jpg');
      if (lowerHeader.contains('video/')) return withExt('.mp4');
      if (lowerHeader.contains('audio/mpeg')) return withExt('.mp3');
      if (lowerHeader.contains('audio/')) return withExt('.m4a');
      if (lowerHeader.contains('text/csv')) return withExt('.csv');
      if (lowerHeader.contains('text/plain')) return withExt('.txt');
      if (lowerHeader.contains('application/json')) return withExt('.json');
      return fallback;
    }

    try {
      final clean = trimmed.split('?').first.split('#').first;
      final uri = Uri.tryParse(clean);
      final segments = uri != null && uri.pathSegments.isNotEmpty
          ? uri.pathSegments
          : clean.split('/');
      final last = segments.lastWhere(
        (s) => s.trim().isNotEmpty,
        orElse: () => '',
      );
      if (last.isNotEmpty) {
        try {
          return Uri.decodeComponent(last);
        } catch (_) {
          return last;
        }
      }
    } catch (_) {}

    return fallback;
  }

  static String inferMimeType(String url, {Uint8List? bytes}) {
    final trimmed = url.trim();
    if (trimmed.toLowerCase().startsWith('data:')) {
      final commaIdx = trimmed.indexOf(',');
      final header = commaIdx != -1 ? trimmed.substring(5, commaIdx) : trimmed.substring(5);
      final mime = header.split(';').first.trim().toLowerCase();
      if (mime.isNotEmpty && mime != 'application/octet-stream') {
        return mime;
      }
    }

    final clean = extractFileName(trimmed).toLowerCase();
    if (clean.endsWith('.pdf')) return 'application/pdf';
    if (clean.endsWith('.png')) return 'image/png';
    if (clean.endsWith('.jpg') || clean.endsWith('.jpeg')) return 'image/jpeg';
    if (clean.endsWith('.webp')) return 'image/webp';
    if (clean.endsWith('.gif')) return 'image/gif';
    if (clean.endsWith('.bmp')) return 'image/bmp';
    if (clean.endsWith('.doc')) return 'application/msword';
    if (clean.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (clean.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (clean.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (clean.endsWith('.mp4')) return 'video/mp4';
    if (clean.endsWith('.mov')) return 'video/quicktime';
    if (clean.endsWith('.webm')) return 'video/webm';
    if (clean.endsWith('.mp3')) return 'audio/mpeg';
    if (clean.endsWith('.m4a')) return 'audio/mp4';
    if (clean.endsWith('.wav')) return 'audio/wav';
    if (clean.endsWith('.ogg')) return 'audio/ogg';
    if (clean.endsWith('.txt') || clean.endsWith('.log') || clean.endsWith('.md')) {
      return 'text/plain';
    }
    if (clean.endsWith('.csv')) return 'text/csv';
    if (clean.endsWith('.json')) return 'application/json';

    if (bytes != null && bytes.length >= 4) {
      if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        return 'application/pdf';
      }
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
        return 'image/gif';
      }
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'image/webp';
      }
    }

    return 'application/octet-stream';
  }

  static bool isImageUrl(String url, [Uint8List? bytes]) {
    final lower = url.trim().toLowerCase();
    if (lower.startsWith('data:')) {
      final commaIdx = lower.indexOf(',');
      final header = commaIdx != -1 ? lower.substring(0, commaIdx) : lower;
      if (header.contains('image/')) return true;
      if (RegExp(r'name=[^;]*\.(jpg|jpeg|png|webp|gif|bmp|heic)(?:;|$)').hasMatch(header)) {
        return true;
      }
    }
    final clean = lower.split('?').first.split('#').first;
    if (clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.png') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.bmp') ||
        clean.endsWith('.heic')) {
      return true;
    }
    if (bytes != null && bytes.length >= 4) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return true;
      }
    }
    return false;
  }

  static bool isPdfUrl(String url, [Uint8List? bytes]) {
    final lower = url.trim().toLowerCase();
    if (lower.startsWith('data:')) {
      final commaIdx = lower.indexOf(',');
      final header = commaIdx != -1 ? lower.substring(0, commaIdx) : lower;
      if (header.contains('application/pdf') || header.contains('.pdf')) return true;
    }
    final clean = lower.split('?').first.split('#').first;
    if (clean.endsWith('.pdf')) return true;
    if (bytes != null && bytes.length >= 4) {
      if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) return true;
    }
    return false;
  }

  static bool isVideoUrl(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.startsWith('data:')) {
      final commaIdx = lower.indexOf(',');
      final header = commaIdx != -1 ? lower.substring(0, commaIdx) : lower;
      if (header.contains('video/')) return true;
    }
    final clean = lower.split('?').first.split('#').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.3gp');
  }

  static bool isAudioUrl(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.startsWith('data:')) {
      final commaIdx = lower.indexOf(',');
      final header = commaIdx != -1 ? lower.substring(0, commaIdx) : lower;
      if (header.contains('audio/')) return true;
    }
    final clean = lower.split('?').first.split('#').first;
    return clean.endsWith('.m4a') ||
        clean.endsWith('.mp3') ||
        clean.endsWith('.wav') ||
        clean.endsWith('.ogg') ||
        clean.endsWith('.aac');
  }

  static bool isWordUrl(String url) {
    final lower = extractFileName(url).toLowerCase();
    final rawLower = url.trim().toLowerCase();
    return lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        rawLower.contains('application/msword') ||
        rawLower.contains('wordprocessingml');
  }

  static bool isExcelUrl(String url) {
    final lower = extractFileName(url).toLowerCase();
    final rawLower = url.trim().toLowerCase();
    return lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        rawLower.contains('application/vnd.ms-excel') ||
        rawLower.contains('spreadsheetml');
  }

  static bool isTextDocUrl(String url) {
    final lower = extractFileName(url).toLowerCase();
    final rawLower = url.trim().toLowerCase();
    return lower.endsWith('.txt') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.log') ||
        lower.endsWith('.json') ||
        lower.endsWith('.md') ||
        rawLower.contains('text/plain') ||
        rawLower.contains('text/csv') ||
        rawLower.contains('application/json');
  }

  static bool isReadableDocument(
    String url, {
    String? fileName,
    Uint8List? bytes,
  }) {
    final lowerName = (fileName ?? extractFileName(url)).toLowerCase();
    if (isPdfUrl(url, bytes) ||
        isWordUrl(url) ||
        isExcelUrl(url) ||
        isTextDocUrl(url) ||
        lowerName.endsWith('.docx') ||
        lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.txt') ||
        lowerName.endsWith('.csv') ||
        lowerName.endsWith('.json') ||
        lowerName.endsWith('.log') ||
        lowerName.endsWith('.md')) {
      return true;
    }
    if (bytes != null && bytes.length >= 4) {
      // ZIP header (DOCX/XLSX OOXML)
      if (bytes[0] == 0x50 &&
          bytes[1] == 0x4B &&
          bytes[2] == 0x03 &&
          bytes[3] == 0x04) {
        return true;
      }
    }
    return false;
  }

  /// Ambil bytes mentah dari `data:` URI atau URL jaringan yang telah di-resolve.
  static Future<Uint8List?> fetchBytes(
    String rawUrl, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.toLowerCase().startsWith('data:')) {
      return tryDecodeDataUri(trimmed)?.bytes;
    }

    final resolved = resolveUrl(trimmed);
    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme) return null;

    try {
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// Widget gambar universal untuk `data:` base64 maupun URL HTTP/storage.
  static Widget buildImageWidget(
    String rawUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext)? errorBuilder,
  }) {
    Widget buildFallback(BuildContext context) {
      if (errorBuilder != null) return errorBuilder(context);
      return Container(
        width: width,
        height: height ?? 100,
        color: AppColors.card(context),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: AppColors.textSecondary(context),
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Gambar gagal dimuat',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    final trimmed = rawUrl.trim();
    if (trimmed.toLowerCase().startsWith('data:')) {
      final decoded = tryDecodeDataUri(trimmed);
      if (decoded == null || decoded.bytes.isEmpty) {
        return Builder(builder: buildFallback);
      }
      return Image.memory(
        decoded.bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, _, __) => buildFallback(context),
      );
    }

    final resolved = resolveUrl(trimmed);
    return Image.network(
      resolved,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height ?? 120,
          color: AppColors.surfaceMuted(context),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, _, __) => buildFallback(context),
    );
  }

  static Future<bool> downloadBytes(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) {
    return platformDownloadBytes(bytes, fileName, mimeType);
  }

  static Future<bool> openBytesInViewer(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) {
    return platformOpenBytesInViewer(bytes, fileName, mimeType);
  }

  static void _showSnack(BuildContext context, String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Membuka atau mengunduh lampiran secara universal (foto, PDF, Word/Excel, video, voice note)
  /// baik dari `data:` URI maupun URL server (`/storage/...` atau `https://...`).
  static Future<void> bukaLampiran(
    BuildContext context,
    String rawUrl, {
    String? fallbackName,
    bool forceImage = false,
    bool forceVideo = false,
    bool forceAudio = false,
  }) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      _showSnack(context, 'Berkas lampiran tidak tersedia.', _red);
      return;
    }

    final isDataUri = trimmed.toLowerCase().startsWith('data:');
    DecodedDataUri? decoded;
    if (isDataUri) {
      decoded = tryDecodeDataUri(trimmed);
      if (decoded == null) {
        _showSnack(
          context,
          'Format data lampiran tidak valid atau terpotong.',
          _red,
        );
        return;
      }
    }

    final fileName = extractFileName(
      trimmed,
      fallback: fallbackName ?? 'lampiran',
    );
    final bytes = decoded?.bytes;
    final networkUrl = isDataUri ? null : resolveUrl(trimmed);
    final mimeType = decoded?.mimeType ?? inferMimeType(trimmed, bytes: bytes);

    final isGambar = forceImage ||
        isImageUrl(trimmed, bytes) ||
        mimeType.startsWith('image/');
    final isPdf = !isGambar &&
        (isPdfUrl(trimmed, bytes) || mimeType == 'application/pdf');
    final isVideo = !isGambar &&
        !isPdf &&
        (forceVideo || isVideoUrl(trimmed) || mimeType.startsWith('video/'));
    final isAudio = !isGambar &&
        !isPdf &&
        !isVideo &&
        (forceAudio || isAudioUrl(trimmed) || mimeType.startsWith('audio/'));

    if (!context.mounted) return;

    if (isGambar) {
      await _showImageDialog(
        context,
        fileName: fileName,
        bytes: bytes,
        networkUrl: networkUrl,
        mimeType: mimeType.startsWith('image/') ? mimeType : 'image/jpeg',
      );
      return;
    }

    await _showDocumentOrMediaDialog(
      context,
      fileName: fileName,
      bytes: bytes,
      networkUrl: networkUrl,
      mimeType: mimeType,
      isPdf: isPdf,
      isVideo: isVideo,
      isAudio: isAudio,
    );
  }

  static Future<void> _showImageDialog(
    BuildContext context, {
    required String fileName,
    Uint8List? bytes,
    String? networkUrl,
    required String mimeType,
  }) async {
    bool isDownloading = false;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.black.withValues(alpha: 0.72),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isDownloading
                            ? null
                            : () async {
                                setModalState(() => isDownloading = true);
                                try {
                                  final targetBytes = bytes ??
                                      (networkUrl != null
                                          ? await fetchBytes(networkUrl)
                                          : null);
                                  if (targetBytes != null &&
                                      targetBytes.isNotEmpty) {
                                    final ok = await downloadBytes(
                                      targetBytes,
                                      fileName,
                                      mimeType,
                                    );
                                    if (ok && context.mounted) {
                                      _showSnack(
                                        context,
                                        'Foto $fileName berhasil diunduh.',
                                        _green,
                                      );
                                      return;
                                    }
                                  }
                                  if (networkUrl != null) {
                                    final uri = Uri.tryParse(networkUrl);
                                    if (uri != null &&
                                        await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      return;
                                    }
                                  }
                                  if (context.mounted) {
                                    _showSnack(
                                      context,
                                      'Gagal mengunduh foto $fileName.',
                                      _red,
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    _showSnack(
                                      context,
                                      'Gagal mengunduh foto: $e',
                                      _red,
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => isDownloading = false);
                                  }
                                }
                              },
                        icon: isDownloading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded,
                                size: 16, color: Colors.white),
                        label: Text(
                          isDownloading ? 'Mengunduh...' : 'Unduh',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      maxScale: 5.0,
                      child: bytes != null
                          ? Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text(
                                'Gambar tidak dapat ditampilkan.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : (networkUrl != null
                              ? Image.network(
                                  networkUrl,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return const CircularProgressIndicator(
                                      color: Colors.white,
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => const Text(
                                    'Gambar gagal dimuat dari server.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : const SizedBox()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _showDocumentOrMediaDialog(
    BuildContext context, {
    required String fileName,
    Uint8List? bytes,
    String? networkUrl,
    required String mimeType,
    required bool isPdf,
    required bool isVideo,
    required bool isAudio,
  }) async {
    final isWord = isWordUrl(fileName) || mimeType.contains('word');
    final isExcel = isExcelUrl(fileName) || mimeType.contains('excel') || mimeType.contains('sheet');

    Color iconColor = _navy;
    Color iconBg = _navy.withValues(alpha: 0.1);
    IconData docIcon = Icons.insert_drive_file_rounded;
    String titleBar = 'Detail Berkas Dokumen';
    String jenisLabel = 'Dokumen Lampiran';

    if (isPdf) {
      iconColor = const Color(0xFFD32F2F);
      iconBg = const Color(0xFFD32F2F).withValues(alpha: 0.1);
      docIcon = Icons.picture_as_pdf_rounded;
      jenisLabel = 'Dokumen PDF (Portable Document Format)';
    } else if (isWord) {
      iconColor = const Color(0xFF185ABD);
      iconBg = const Color(0xFF185ABD).withValues(alpha: 0.1);
      docIcon = Icons.description_rounded;
      jenisLabel = 'Dokumen Microsoft Word';
    } else if (isExcel) {
      iconColor = const Color(0xFF107C41);
      iconBg = const Color(0xFF107C41).withValues(alpha: 0.1);
      docIcon = Icons.table_chart_rounded;
      jenisLabel = 'Spreadsheet Microsoft Excel';
    } else if (isVideo) {
      titleBar = 'Detail Video Bukti';
      iconColor = const Color(0xFFD35400);
      iconBg = const Color(0xFFD35400).withValues(alpha: 0.12);
      docIcon = Icons.play_circle_fill_rounded;
      jenisLabel = 'Berkas Video Bukti';
    } else if (isAudio) {
      titleBar = 'Detail Rekaman Suara';
      iconColor = const Color(0xFF8E44AD);
      iconBg = const Color(0xFF8E44AD).withValues(alpha: 0.12);
      docIcon = Icons.audiotrack_rounded;
      jenisLabel = 'Rekaman Suara / Voice Note';
    }

    final ukuranKb =
        bytes != null ? (bytes.length / 1024).toStringAsFixed(1) : null;

    bool isBusy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> handleDownload() async {
            setModalState(() => isBusy = true);
            try {
              final targetBytes = bytes ??
                  (networkUrl != null ? await fetchBytes(networkUrl) : null);
              if (targetBytes != null && targetBytes.isNotEmpty) {
                final ok = await downloadBytes(
                  targetBytes,
                  fileName,
                  mimeType,
                );
                if (ok && context.mounted) {
                  _showSnack(
                    context,
                    'Berkas $fileName berhasil diunduh.',
                    _green,
                  );
                  return;
                }
              }
              if (networkUrl != null) {
                final uri = Uri.tryParse(networkUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return;
                }
              }
              if (context.mounted) {
                _showSnack(
                  context,
                  'Gagal mengunduh berkas $fileName.',
                  _red,
                );
              }
            } catch (e) {
              if (context.mounted) {
                _showSnack(
                  context,
                  'Gagal mengunduh berkas: $e',
                  _red,
                );
              }
            } finally {
              if (ctx.mounted) {
                setModalState(() => isBusy = false);
              }
            }
          }

          return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: _navy,
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          titleBar,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(docIcon, size: 36, color: iconColor),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        fileName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        jenisLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (ukuranKb != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Ukuran: $ukuranKb KB',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Tombol Utama: Buka / Pratinjau / Putar
                      if (isPdf || isVideo || isAudio) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    // Untuk data bytes yang sudah siap, buka secara sinkron agar tidak diblokir popup blocker Web
                                    if (bytes != null && bytes.isNotEmpty) {
                                      try {
                                        final ok = await openBytesInViewer(
                                          bytes,
                                          fileName,
                                          mimeType,
                                        );
                                        if (!ok && context.mounted) {
                                          _showSnack(
                                            context,
                                            'Tidak dapat membuka pratinjau berkas.',
                                            _red,
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          _showSnack(
                                            context,
                                            'Gagal membuka berkas: $e',
                                            _red,
                                          );
                                        }
                                      }
                                      return;
                                    }

                                    if (networkUrl != null) {
                                      setModalState(() => isBusy = true);
                                      try {
                                        if (kIsWeb) {
                                          final uri = Uri.tryParse(networkUrl);
                                          if (uri != null &&
                                              await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                            return;
                                          }
                                        } else {
                                          final fetched =
                                              await fetchBytes(networkUrl);
                                          if (fetched != null &&
                                              fetched.isNotEmpty) {
                                            await openBytesInViewer(
                                              fetched,
                                              fileName,
                                              mimeType,
                                            );
                                            return;
                                          }
                                          final uri = Uri.tryParse(networkUrl);
                                          if (uri != null &&
                                              await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                            return;
                                          }
                                        }
                                        if (context.mounted) {
                                          _showSnack(
                                            context,
                                            'Gagal membuka berkas dari server.',
                                            _red,
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          _showSnack(
                                            context,
                                            'Gagal membuka berkas: $e',
                                            _red,
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setModalState(() => isBusy = false);
                                        }
                                      }
                                    }
                                  },
                            icon: isBusy
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isPdf
                                        ? Icons.visibility_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 17,
                                  ),
                            label: Text(
                              isPdf
                                  ? 'Buka Pratinjau PDF'
                                  : (isVideo ? 'Putar Video' : 'Putar Audio'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Tombol Unduh Berkas (untuk semua dokumen & media)
                      SizedBox(
                        width: double.infinity,
                        child: (isPdf || isVideo || isAudio)
                            ? OutlinedButton.icon(
                                onPressed: isBusy ? null : handleDownload,
                                icon: const Icon(Icons.download_rounded, size: 16),
                                label: Text(
                                  isPdf ? 'Unduh Berkas PDF' : 'Unduh Berkas',
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _navy,
                                  side: BorderSide(
                                      color: _navy.withValues(alpha: 0.5)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9)),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: isBusy ? null : handleDownload,
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download_rounded,
                                        size: 17),
                                label: const Text(
                                  'Unduh / Buka Berkas',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _navy,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9)),
                                ),
                              ),
                      ),

                      if (networkUrl != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () async {
                              final uri = Uri.tryParse(networkUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else if (context.mounted) {
                                _showSnack(
                                  context,
                                  'Tidak dapat membuka tautan eksternal.',
                                  _red,
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: const Text(
                              'Buka Tautan di Browser',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  /// Rasterisasi halaman PDF menjadi gambar PNG menggunakan backend platform
  /// (`Printing.raster`: PDF.js di Web, `PdfRenderer` di Android, PDFium di Windows).
  /// Mengembalikan daftar halaman yang berhasil diraster, atau list kosong bila gagal / headless.
  static Future<List<PdfPageRaster>> rasterPdfPages(
    Uint8List pdfBytes, {
    double dpi = 140,
    int maxPages = 20,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (pdfBytes.length < 4 || !isPdfUrl('', pdfBytes)) {
      return const [];
    }

    final pages = <PdfPageRaster>[];
    try {
      final info = await Printing.info().timeout(
        const Duration(seconds: 1),
        onTimeout: () => PrintingInfo.unavailable,
      );
      if (!info.canRaster) {
        return const [];
      }

      await Future<void>(() async {
        await for (final raster in Printing.raster(pdfBytes, dpi: dpi)) {
          final pngBytes = await raster.toPng();
          if (pngBytes.isNotEmpty) {
            pages.add(
              PdfPageRaster(
                pngBytes: pngBytes,
                width: raster.width,
                height: raster.height,
              ),
            );
          }
          if (pages.length >= maxPages) {
            break;
          }
        }
      }).timeout(timeout, onTimeout: () {});
    } catch (_) {
      // Abaikan bila backend rasterisasi belum tersedia (misalnya headless test atau offline PDF.js)
    }
    return pages;
  }

  /// Mengekstrak isi teks yang dapat dibaca dari berkas lampiran dokumen:
  /// `.docx`, `.xlsx`, `.txt`/`.csv`/`.json`/`.log`, `.rtf`, maupun fallback teks PDF.
  static String? extractReadableDocumentText(
    Uint8List bytes,
    String fileName, {
    String? mimeType,
    int maxChars = 20000,
  }) {
    if (bytes.isEmpty) return null;

    final lowerName = fileName.trim().toLowerCase();
    final lowerMime = (mimeType ?? '').trim().toLowerCase();

    String? extracted;

    final bool looksZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;

    if (looksZip ||
        lowerName.endsWith('.docx') ||
        lowerName.endsWith('.xlsx') ||
        lowerMime.contains('wordprocessingml') ||
        lowerMime.contains('spreadsheetml')) {
      extracted = _extractOoxmlArchiveText(bytes);
    }

    if ((extracted == null || extracted.isEmpty) &&
        (isPdfUrl(fileName, bytes) || lowerMime == 'application/pdf')) {
      extracted = _extractPdfTextFallback(bytes);
    }

    if ((extracted == null || extracted.isEmpty) &&
        (lowerName.endsWith('.rtf') ||
            (bytes.length >= 5 &&
                latin1.decode(bytes.sublist(0, 5), allowInvalid: true) == '{\\rtf'))) {
      extracted = _extractRtfText(bytes);
    }

    if ((extracted == null || extracted.isEmpty) &&
        (lowerName.endsWith('.txt') ||
            lowerName.endsWith('.csv') ||
            lowerName.endsWith('.log') ||
            lowerName.endsWith('.json') ||
            lowerName.endsWith('.md') ||
            lowerMime.startsWith('text/') ||
            lowerMime == 'application/json')) {
      extracted = _extractPlainText(bytes, isJson: lowerName.endsWith('.json') || lowerMime == 'application/json');
    }

    if (extracted == null) return null;
    final trimmed = extracted.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > maxChars) {
      return '${trimmed.substring(0, maxChars).trimRight()}\n\n... (isi dokumen dipotong karena terlalu panjang)';
    }
    return trimmed;
  }

  static String? _extractOoxmlArchiveText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final wordDoc = archive.findFile('word/document.xml');
      if (wordDoc != null) {
        final xml = utf8.decode(wordDoc.content, allowMalformed: true);
        return _extractWordXmlText(xml);
      }

      final hasSheets = archive.files.any(
        (f) => f.isFile && f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'),
      );
      if (hasSheets) {
        return _extractExcelArchiveText(archive);
      }
    } catch (_) {}
    return null;
  }

  static String _extractWordXmlText(String xml) {
    // Sisipkan penanda newline dan pemisah kolom tabel sebelum menghapus tag XML
    var normalized = xml
        .replaceAll(RegExp(r'<w:tab\b[^>]*/?>'), '\t')
        .replaceAll(RegExp(r'<w:(br|cr)\b[^>]*/?>'), '\n')
        .replaceAll(RegExp(r'</w:p\s*>\s*</w:tc\s*>'), ' | ')
        .replaceAll(RegExp(r'</w:tc\s*>'), ' | ')
        .replaceAll(RegExp(r'</w:tr\s*>'), '\n')
        .replaceAll(RegExp(r'</w:p\s*>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    normalized = _unescapeXml(normalized);

    final lines = normalized
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s*\|\s*$'), '').trimRight())
        .toList();

    final compacted = <String>[];
    bool prevBlank = false;
    for (final line in lines) {
      final blank = line.trim().isEmpty;
      if (blank) {
        if (!prevBlank && compacted.isNotEmpty) {
          compacted.add('');
        }
      } else {
        compacted.add(line);
      }
      prevBlank = blank;
    }
    return compacted.join('\n').trim();
  }

  static String? _extractExcelArchiveText(Archive archive) {
    final sharedStrings = <String>[];
    final sstFile = archive.findFile('xl/sharedStrings.xml');
    if (sstFile != null) {
      final sstXml = utf8.decode(sstFile.content, allowMalformed: true);
      for (final siMatch in RegExp(r'<si\b[^>]*>([\s\S]*?)</si>').allMatches(sstXml)) {
        final buf = StringBuffer();
        for (final tMatch in RegExp(r'<t\b[^>]*>([\s\S]*?)</t>').allMatches(siMatch.group(1)!)) {
          buf.write(_unescapeXml(tMatch.group(1)!));
        }
        sharedStrings.add(buf.toString());
      }
    }

    final sheetFiles = archive.files
        .where((f) =>
            f.isFile &&
            RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (sheetFiles.isEmpty) return null;

    final out = StringBuffer();
    final maxSheets = sheetFiles.length > 5 ? 5 : sheetFiles.length;
    for (int sIdx = 0; sIdx < maxSheets; sIdx++) {
      final sheetFile = sheetFiles[sIdx];
      final sheetXml = utf8.decode(sheetFile.content, allowMalformed: true);
      final sheetRows = <String>[];

      for (final rowMatch in RegExp(r'<row\b[^>]*>([\s\S]*?)</row>').allMatches(sheetXml)) {
        final cells = <String>[];
        for (final cellMatch in RegExp(r'<c\b([^>]*)>([\s\S]*?)</c>').allMatches(rowMatch.group(1)!)) {
          final attrs = cellMatch.group(1) ?? '';
          final body = cellMatch.group(2) ?? '';
          final typeMatch = RegExp(r'\bt="([^"]+)"').firstMatch(attrs);
          final cellType = typeMatch?.group(1) ?? '';

          String val = '';
          if (cellType == 'inlineStr') {
            final tBuf = StringBuffer();
            for (final tm in RegExp(r'<t\b[^>]*>([\s\S]*?)</t>').allMatches(body)) {
              tBuf.write(_unescapeXml(tm.group(1)!));
            }
            val = tBuf.toString();
          } else {
            final vMatch = RegExp(r'<v\b[^>]*>([\s\S]*?)</v>').firstMatch(body);
            if (vMatch != null) {
              final rawV = _unescapeXml(vMatch.group(1)!.trim());
              if (cellType == 's') {
                final idx = int.tryParse(rawV);
                if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                  val = sharedStrings[idx];
                }
              } else {
                val = rawV;
              }
            }
          }
          if (val.trim().isNotEmpty) {
            cells.add(val.trim());
          }
        }
        if (cells.isNotEmpty) {
          sheetRows.add(cells.join(' | '));
        }
      }

      if (sheetRows.isNotEmpty) {
        if (maxSheets > 1) {
          out.writeln('[Sheet ${sIdx + 1}]');
        }
        out.writeln(sheetRows.take(250).join('\n'));
        if (sIdx < maxSheets - 1) out.writeln();
      }
    }

    final result = out.toString().trim();
    return result.isEmpty ? null : result;
  }

  static String? _extractPlainText(Uint8List bytes, {bool isJson = false}) {
    var text = utf8.decode(bytes, allowMalformed: true)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (text.isEmpty) return null;
    if (isJson) {
      try {
        final decoded = jsonDecode(text);
        text = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {}
    }
    return text;
  }

  static String? _extractRtfText(Uint8List bytes) {
    var text = latin1.decode(bytes, allowInvalid: true);
    text = text
        .replaceAll(RegExp(r'\\par\b\s*'), '\n')
        .replaceAll(RegExp(r'\\line\b\s*'), '\n')
        .replaceAll(RegExp(r'\\tab\b\s*'), '\t')
        .replaceAll(RegExp(r'\{\\\*?\\[^}]+\}'), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d* ?'), '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .trim();
    return text.isEmpty ? null : text;
  }

  static String? _extractPdfTextFallback(Uint8List bytes) {
    try {
      final raw = latin1.decode(bytes, allowInvalid: true);
      final chunks = <String>[];

      void collectFromStream(String content) {
        final buf = StringBuffer();
        double? prevY;

        void startNewFragment(double? y) {
          if (buf.isEmpty) {
            prevY = y;
            return;
          }
          final tail = buf.toString();
          final lastChar = tail.isNotEmpty ? tail[tail.length - 1] : '';
          if (y != null && prevY != null && (y - prevY!).abs() <= 2.5) {
            if (lastChar != ' ' && lastChar != '\n') {
              buf.write(' ');
            }
          } else if (lastChar != '\n') {
            buf.write('\n');
          }
          if (y != null) {
            prevY = y;
          }
        }

        for (final bt in RegExp(r'BT([\s\S]*?)ET').allMatches(content)) {
          final block = bt.group(1) ?? '';

          // Deteksi koordinat Y teks dari operator posisi PDF (Td, TD, atau Tm)
          double? blockY;
          final tmMatch = RegExp(
            r'[-+]?\d*\.?\d+\s+[-+]?\d*\.?\d+\s+[-+]?\d*\.?\d+\s+[-+]?\d*\.?\d+\s+[-+]?\d*\.?\d+\s+([-+]?\d*\.?\d+)\s+Tm\b',
          ).firstMatch(block);
          if (tmMatch != null) {
            blockY = double.tryParse(tmMatch.group(1)!);
          } else {
            final tdMatch = RegExp(
              r'[-+]?\d*\.?\d+\s+([-+]?\d*\.?\d+)\s+T[dD]\b',
            ).firstMatch(block);
            if (tdMatch != null) {
              blockY = double.tryParse(tdMatch.group(1)!);
            }
          }

          startNewFragment(blockY);

          int i = 0;
          bool inArray = false;
          while (i < block.length) {
            final ch = block[i];
            if (ch == '[') {
              inArray = true;
              i++;
              continue;
            }
            if (ch == ']') {
              inArray = false;
              i++;
              continue;
            }
            if (inArray && (ch == '-' || (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57))) {
              final numMatch = RegExp(r'^[-+]?\d*\.?\d+').firstMatch(block.substring(i));
              if (numMatch != null) {
                final val = double.tryParse(numMatch.group(0)!);
                if (val != null && val < -120 && buf.isNotEmpty) {
                  final tail = buf.toString();
                  if (!tail.endsWith(' ') && !tail.endsWith('\n')) {
                    buf.write(' ');
                  }
                }
                i += numMatch.group(0)!.length;
                continue;
              }
            }
            if (ch == '(') {
              i++;
              final lit = StringBuffer();
              int depth = 1;
              while (i < block.length && depth > 0) {
                final c = block[i];
                if (c == '\\' && i + 1 < block.length) {
                  final nxt = block[i + 1];
                  if (nxt == 'n' || nxt == 'r') {
                    lit.write('\n');
                  } else if (nxt == 't') {
                    lit.write(' ');
                  } else {
                    lit.write(nxt);
                  }
                  i += 2;
                  continue;
                }
                if (c == '(') {
                  depth++;
                } else if (c == ')') {
                  depth--;
                  if (depth == 0) {
                    i++;
                    break;
                  }
                }
                lit.write(c);
                i++;
              }
              buf.write(lit.toString());
              continue;
            }
            if (i + 1 < block.length && block.substring(i, i + 2) == 'T*') {
              if (buf.isNotEmpty && !buf.toString().endsWith('\n')) {
                buf.write('\n');
              }
              i += 2;
              continue;
            }
            i++;
          }
        }

        final extracted = buf
            .toString()
            .replaceAll(RegExp(r'[^\x20-\x7E\n\r\t\u00A0-\u00FF]'), '')
            .trim();
        if (extracted.isNotEmpty) {
          chunks.add(extracted);
        }
      }

      // Temukan seluruh stream beserta kamus header langsung di belakang kata kunci `stream`
      final streamStartRe = RegExp(r'stream\r?\n');
      bool foundStream = false;
      for (final m in streamStartRe.allMatches(raw)) {
        final dictLookbackStart = m.start > 900 ? m.start - 900 : 0;
        final dictSlice = raw.substring(dictLookbackStart, m.start);
        if (dictSlice.contains('/Type/XRef') || dictSlice.contains('/Type /XRef')) {
          continue;
        }
        final endIdx = raw.indexOf('endstream', m.end);
        if (endIdx == -1) continue;
        foundStream = true;

        var bodyEnd = endIdx;
        if (bodyEnd > m.end && raw[bodyEnd - 1] == '\n') {
          bodyEnd--;
          if (bodyEnd > m.end && raw[bodyEnd - 1] == '\r') {
            bodyEnd--;
          }
        }
        final body = raw.substring(m.end, bodyEnd);
        if (dictSlice.contains('/FlateDecode')) {
          try {
            final decoded = const ZLibDecoder().decodeBytes(latin1.encode(body));
            collectFromStream(latin1.decode(decoded, allowInvalid: true));
          } catch (_) {}
        } else {
          collectFromStream(body);
        }
      }

      if (!foundStream) {
        collectFromStream(raw);
      }

      final joined = chunks.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      if (joined.length < 3) return null;
      final readableChars = RegExp(r'[A-Za-z0-9]').allMatches(joined).length;
      if (readableChars < 2 || readableChars / joined.length < 0.15) {
        return null;
      }
      return joined;
    } catch (_) {
      return null;
    }
  }

  static String _unescapeXml(String input) {
    var s = input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
    s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    return s;
  }
}
