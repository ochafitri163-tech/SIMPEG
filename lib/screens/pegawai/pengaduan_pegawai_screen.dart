import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/pengaduan_model.dart';
import '../../models/user_role.dart';

/// Halaman "Pengaduan Pegawai" — form untuk mengirimkan keluhan/pengaduan
/// pegawai, mengikuti referensi desain UI "Pengaduan_Warga.png" secara
/// persis: header navy, field Kategori (dropdown), Judul Singkat,
/// Deskripsi, tombol lampirkan foto (opsional, border putus-putus),
/// dan tombol merah "Kirim Pengaduan".
///
/// Setelah dikirim, pengaduan disimpan ke [PengaduanRepository] sehingga
/// langsung muncul pada halaman "Status Pengaduan".
class PengaduanPegawaiScreen extends StatefulWidget {
  final AppUser user;
  const PengaduanPegawaiScreen({super.key, required this.user});

  @override
  State<PengaduanPegawaiScreen> createState() =>
      _PengaduanPegawaiScreenState();
}

class _PengaduanPegawaiScreenState extends State<PengaduanPegawaiScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color navyDark = Color(0xFF0A2257);
  static const Color accent = Color(0xFF2E86AB);
  static const Color red = Color(0xFFE74C3C);
  static const Color labelDark = Color(0xFF1B2733);
  static const Color hintGrey = Color(0xFF9AA5B1);

  static const List<String> _kategoriOptions = [
    'Pelanggaran Administrasi',
    'Pelanggaran Teknik',
  ];

  /// Catatan/penjelasan singkat untuk membantu pegawai menentukan kategori
  /// pengaduan yang tepat. Ditampilkan di bawah setiap pilihan pada bottom
  /// sheet "Pilih Kategori", dan juga sebagai ringkasan di bawah field
  /// setelah kategori dipilih.
  static const Map<String, String> _kategoriNotes = {
    'Pelanggaran Administrasi':
        'Mencakup masalah SDM/kepegawaian internal, seperti: keterlambatan '
        'atau ketidakhadiran kerja, pelanggaran jam kerja, hasil setoran/'
        'pendapatan yang tidak disetorkan atau tidak sesuai (masalah '
        'keuangan), penyalahgunaan wewenang atau fasilitas kantor, '
        'ketidaksesuaian data kepegawaian, serta pelanggaran kedisiplinan '
        'dan kode etik pegawai lainnya.',
    'Pelanggaran Teknik':
        'Mencakup masalah pekerjaan teknis/lapangan, seperti: ukuran atau '
        'spesifikasi pekerjaan tidak sesuai (contoh: panjang pipa yang '
        'terpasang di lapangan tidak sama dengan yang tercatat pada '
        'laporan), kualitas material/pemasangan tidak sesuai standar '
        '(SNI/SOP), kesalahan pencatatan meter air atau data teknis, '
        'pekerjaan tidak sesuai gambar teknis (as-built drawing), '
        'keterlambatan penyelesaian pekerjaan teknis, kerusakan sarana/'
        'prasarana produksi dan distribusi air yang tidak dilaporkan, '
        'serta pelanggaran prosedur keselamatan kerja (K3) di lapangan.',
  };

  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  String? _kategori;
  final List<_FotoLampiran> _fotoLampiran = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _pilihKategori() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E4E9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pilih Kategori',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final k in _kategoriOptions)
                          InkWell(
                            onTap: () => Navigator.pop(context, k),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          k,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: labelDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _kategoriNotes[k] ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                            color: hintGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_kategori == k) ...[
                                    const SizedBox(width: 10),
                                    const Icon(Icons.check_rounded,
                                        color: accent, size: 20),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    setState(() => _kategori = selected);
    // Ringkasan notes kategori akan otomatis muncul di bawah field
    // (lihat build()) sesuai kategori yang dipilih.
  }

  Future<void> _pilihSumberFoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E4E9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: accent),
                title: const Text('Ambil foto dengan kamera',
                    style: TextStyle(fontSize: 13.5, color: labelDark)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: accent),
                title: const Text('Pilih dari galeri',
                    style: TextStyle(fontSize: 13.5, color: labelDark)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _fotoLampiran.add(_FotoLampiran(picked, bytes)));
      _showSnack('Foto berhasil dilampirkan.', accent);
    } catch (e) {
      _showSnack('Gagal mengambil foto: $e', red);
    }
  }

  void _hapusFoto(int index) {
    setState(() => _fotoLampiran.removeAt(index));
  }

  void _kirimPengaduan() {
    if (_kategori == null) {
      _showSnack('Silakan pilih kategori pengaduan.', red);
      return;
    }
    if (_judulController.text.trim().isEmpty) {
      _showSnack('Judul singkat tidak boleh kosong.', red);
      return;
    }
    if (_deskripsiController.text.trim().isEmpty) {
      _showSnack('Deskripsi tidak boleh kosong.', red);
      return;
    }

    final kategoriFinal = _kategori!;

    setState(() => _isSubmitting = true);

    // Simulasi pengiriman (belum terhubung ke API/database sungguhan).
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final nomor = PengaduanRepository.generateNomorPengaduan();
      final sekarang = DateTime.now();
      PengaduanRepository.tambah(
        Pengaduan(
          nomorPengaduan: nomor,
          kategori: kategoriFinal,
          judul: _judulController.text.trim(),
          deskripsi: _deskripsiController.text.trim(),
          tanggalPengaduan: sekarang,
          namaPegawai: widget.user.name,
          nik: widget.user.nik,
          cabang: widget.user.unitKerja,
          golongan: widget.user.golongan,
          anonim: false,
          fotoBukti: _fotoLampiran.map((f) => f.xfile.path).toList(),
          status: PengaduanStatus.menungguVerifikasiKadiv,
          riwayatStatus: [
            StatusHistoryEntry(
              status: PengaduanStatus.menungguVerifikasiKadiv,
              tanggal: sekarang,
              oleh: 'Sistem',
            ),
          ],
        ),
      );
      setState(() => _isSubmitting = false);
      _showSnack(
          'Pengaduan berhasil dikirim (No. $nomor).', const Color(0xFF27AE60));
      Navigator.pop(context);
    });
  }

  void _showSnack(String message, Color color) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                _buildFieldLabel('Kategori'),
                const SizedBox(height: 8),
                _buildKategoriField(),
                if (_kategori != null) ...[
                  const SizedBox(height: 10),
                  _buildKategoriNoteBox(_kategori!),
                ],
                const SizedBox(height: 18),
                _buildFieldLabel('Judul Singkat'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _judulController,
                  hint: 'Contoh: AC ruangan rusak',
                ),
                const SizedBox(height: 18),
                _buildFieldLabel('Deskripsi'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _deskripsiController,
                  hint: 'Jelaskan kejadian atau keluhan kamu di sini....',
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                _buildLampirkanFotoButton(),
                const SizedBox(height: 22),
                _buildKirimButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 12,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navyDark, navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Pengaduan Pegawai',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: labelDark,
      ),
    );
  }

  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _buildKategoriField() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pilihKategori,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: _fieldDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _kategori ?? 'Pilih kategori pengaduan',
                style: TextStyle(
                  fontSize: 13.5,
                  color: _kategori != null ? labelDark : hintGrey,
                  fontWeight:
                      _kategori != null ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: hintGrey, size: 20),
          ],
        ),
      ),
    );
  }

  /// Kotak kecil berisi penjelasan/notes dari kategori yang sedang dipilih,
  /// supaya pegawai bisa memastikan pengaduannya sudah masuk kategori yang
  /// tepat sebelum mengirim.
  Widget _buildKategoriNoteBox(String kategori) {
    final note = _kategoriNotes[kategori];
    if (note == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: labelDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      width: double.infinity,
      decoration: _fieldDecoration(),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13.5, color: labelDark),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: hintGrey),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 1.3),
          ),
        ),
      ),
    );
  }

  Widget _buildLampirkanFotoButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fotoLampiran.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < _fotoLampiran.length; i++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _fotoLampiran[i].bytes,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 84,
                            height: 84,
                            color: const Color(0xFFF3F6F9),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined,
                                color: hintGrey, size: 22),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _hapusFoto(i),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pilihSumberFoto,
          child: CustomPaint(
            painter: _DashedBorderPainter(color: accent.withValues(alpha: 0.45)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    _fotoLampiran.isEmpty
                        ? 'Lampirkan foto (opsional)'
                        : 'Tambah foto lainnya',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKirimButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _kirimPengaduan,
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Kirim Pengaduan',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

/// Painter sederhana untuk border putus-putus (dashed) tanpa dependency
/// eksternal, dipakai pada tombol "Lampirkan foto".
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  static const double _radius = 12;
  static const double _dashWidth = 5;
  static const double _dashSpace = 4;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Menyimpan file foto hasil pilihan [ImagePicker] beserta byte datanya.
/// Menggunakan [Uint8List] (bukan dart:io File) agar preview foto tetap
/// berfungsi baik di Android/iOS maupun di Flutter Web, karena Image.file
/// tidak didukung pada platform web.
class _FotoLampiran {
  final XFile xfile;
  final Uint8List bytes;
  const _FotoLampiran(this.xfile, this.bytes);
}