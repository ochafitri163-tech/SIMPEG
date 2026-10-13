import 'package:flutter/material.dart';

/// Pop-up dialog konfirmasi serbaguna untuk setiap aksi keputusan:
/// Terima, Tolak, Tinjau Kembali, Alihkan, Teruskan, dll.
Future<bool> showKonfirmasiDialog({
  required BuildContext context,
  required String judul,
  required String pesan,
  required String labelKonfirmasi,
  Color warnaKonfirmasi = const Color(0xFF0D2C6E),
  IconData iconHeader = Icons.help_outline_rounded,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: warnaKonfirmasi.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconHeader, color: warnaKonfirmasi, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                judul,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          pesan,
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade400),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Batal',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: Icon(iconHeader, size: 16),
            label: Text(
              labelKonfirmasi,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: warnaKonfirmasi,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class CatatanResult {
  final bool isConfirmed;
  final String? text;
  const CatatanResult({required this.isConfirmed, this.text});
}

/// Dialog input catatan (opsional / wajib) yang aman membedakan
/// antara tombol 'Batal' dan 'Konfirmasi'.
Future<CatatanResult> showDialogCatatan({
  required BuildContext context,
  required String judul,
  String hint = 'Tambahkan catatan (opsional)...',
  bool wajib = false,
  String labelTombol = 'Konfirmasi',
  Color warnaTombol = const Color(0xFF0D2C6E),
}) async {
  final controller = TextEditingController();
  final res = await showDialog<CatatanResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          judul,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(const CatatanResult(isConfirmed: false)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: warnaTombol,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (wajib && text.isEmpty) return;
              Navigator.of(ctx)
                  .pop(CatatanResult(isConfirmed: true, text: text.isEmpty ? null : text));
            },
            child: Text(labelTombol),
          ),
        ],
      );
    },
  );
  return res ?? const CatatanResult(isConfirmed: false);
}

