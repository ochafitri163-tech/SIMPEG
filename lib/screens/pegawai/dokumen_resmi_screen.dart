import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/dokumen_service.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';

/// Halaman "Dokumen Surat (SDM)" / "Dokumen Resmi Pegawai (SDM)"
/// Menampilkan Surat Kerja (SK) & Surat Diklat/Pelatihan resmi milik pegawai
/// yang diterbitkan dan diverifikasi oleh SDM, identik dengan halaman di Web SIMPEG.
class DokumenResmiScreen extends StatefulWidget {
  final AppUser user;
  const DokumenResmiScreen({super.key, required this.user});

  @override
  State<DokumenResmiScreen> createState() => _DokumenResmiScreenState();
}

class _DokumenResmiScreenState extends State<DokumenResmiScreen> {
  static const Color navy = Color(0xFF0D2C6E);
  static const Color accent = Color(0xFF2E86AB);
  static const Color docBlue = Color(0xFF0284C7);

  late Future<List<DokumenKepegawaian>> _future;

  bool get _isSdm => widget.user.role == UserRole.sdm;

  @override
  void initState() {
    super.initState();
    _future = DokumenService.dokumenResmiSaya();
  }

  void _refresh() {
    setState(() {
      _future = DokumenService.dokumenResmiSaya();
    });
  }

  Future<void> _bukaFileLangsung(DokumenKepegawaian d) async {
    if (d.fileUrl.isNotEmpty) {
      final uri = Uri.tryParse(d.fileUrl);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Mengunduh ${d.fileNama.isNotEmpty ? d.fileNama : 'dokumen.pdf'}...'),
              ),
            ],
          ),
          backgroundColor: docBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showPreviewModal(DokumenKepegawaian d) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E2638) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Preview: ${d.judul}',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppColors.textSecondary(context),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141A29) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3A52) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: docBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 42,
                          color: docBlue,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        d.fileNama.isNotEmpty ? d.fileNama : 'Dokumen.pdf',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'File PDF / Gambar telah diverifikasi oleh Admin SDM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppColors.divider(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Tutup Preview',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _bukaFileLangsung(d);
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Buka / Unduh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: docBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showUploadModal() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UploadDokumenSheet(user: widget.user),
    );
    if (ok == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dokumen berhasil diunggah/diperbarui oleh Admin SDM.'),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.pageBackground(context),
      body: Column(
        children: [
          // Top AppBar Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF081A45), Color(0xFF1F5F79)]
                    : const [navy, accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Dokumen Surat (SDM)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Surat Kerja & Surat Diklat resmi dari SDM',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Card View
          Expanded(
            child: FutureBuilder<List<DokumenKepegawaian>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const <DokumenKepegawaian>[];
                final skList = items.where((d) => d.kategori == 'SK').toList();
                final diklatList = items.where((d) => d.kategori == 'Diklat').toList();

                final sk = skList.isNotEmpty ? skList.first : null;
                final diklat = diklatList.isNotEmpty ? diklatList.first : null;

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppColors.cardShadow(context),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dokumen Resmi Pegawai (SDM)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Surat Kerja & Surat Diklat resmi yang diterbitkan dan diunggah oleh SDM.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary(context),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Button Khusus Admin SDM
                            if (_isSdm) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _showUploadModal,
                                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                                  label: const Text(
                                    '+ Upload Dokumen (Admin SDM)',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: navy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Kartu 1: Surat Kerja (SK)
                            _DocCard(
                              badgeLabel: 'Surat Kerja (SK)',
                              badgeBg: const Color(0xFFECFDF5),
                              badgeBorder: const Color(0xFFA7F3D0),
                              badgeText: const Color(0xFF047857),
                              badgeIcon: Icons.description_rounded,
                              defaultTitle: 'Surat Keputusan Pengangkatan Pegawai Tetap',
                              defaultNomor: 'SK/SDM/2024/001',
                              defaultDate: '2024-01-15',
                              defaultFileName: 'SK_Pengangkatan_Pegawai.pdf',
                              dokumen: sk,
                              onView: (d) => _showPreviewModal(d),
                              onDownload: (d) => _bukaFileLangsung(d),
                            ),

                            const SizedBox(height: 16),

                            // Kartu 2: Surat Diklat / Pelatihan
                            _DocCard(
                              badgeLabel: 'Surat Diklat / Pelatihan',
                              badgeBg: const Color(0xFFF5F3FF),
                              badgeBorder: const Color(0xFFDDD6FE),
                              badgeText: const Color(0xFF6D28D9),
                              badgeIcon: Icons.school_rounded,
                              defaultTitle: 'Sertifikat Diklat & Pelatihan Manajemen Kepegawaian',
                              defaultNomor: 'STP/SDM/2024/088',
                              defaultDate: '2024-05-20',
                              defaultFileName: 'Sertifikat_Diklat_SDM.pdf',
                              dokumen: diklat,
                              onView: (d) => _showPreviewModal(d),
                              onDownload: (d) => _bukaFileLangsung(d),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeText;
  final IconData badgeIcon;
  final String defaultTitle;
  final String defaultNomor;
  final String defaultDate;
  final String defaultFileName;
  final DokumenKepegawaian? dokumen;
  final void Function(DokumenKepegawaian) onView;
  final void Function(DokumenKepegawaian) onDownload;

  const _DocCard({
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeText,
    required this.badgeIcon,
    required this.defaultTitle,
    required this.defaultNomor,
    required this.defaultDate,
    required this.defaultFileName,
    required this.dokumen,
    required this.onView,
    required this.onDownload,
  });

  static const Color docBlue = Color(0xFF0284C7);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final judul = dokumen?.judul.trim().isNotEmpty == true ? dokumen!.judul : defaultTitle;
    final nomor = dokumen?.nomor?.trim().isNotEmpty == true ? dokumen!.nomor! : defaultNomor;
    final fileNama = dokumen?.fileNama.trim().isNotEmpty == true ? dokumen!.fileNama : defaultFileName;
    final tglStr = dokumen != null ? _formatTgl(dokumen!.dibuatPada) : defaultDate;

    // Objek aktif untuk action
    final activeDoc = dokumen ??
        DokumenKepegawaian(
          id: 0,
          judul: judul,
          kategori: badgeLabel,
          fileUrl: '',
          fileNama: fileNama,
          nomor: nomor,
          dibuatPada: DateTime.tryParse(tglStr) ?? DateTime.now(),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192132) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF28344C) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark ? badgeText.withValues(alpha: 0.18) : badgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? badgeText.withValues(alpha: 0.35) : badgeBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: isDark ? badgeText : badgeText),
                    const SizedBox(width: 5),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: AppColors.textSecondary(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tglStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            judul,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              height: 1.35,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle / No Surat
          Text(
            'No: $nomor',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onView(activeDoc),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View File', style: TextStyle(fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary(context),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                    backgroundColor: isDark ? const Color(0xFF141A29) : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onDownload(activeDoc),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download', style: TextStyle(fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: docBlue,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: docBlue.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTgl(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class _UploadDokumenSheet extends StatefulWidget {
  final AppUser user;
  const _UploadDokumenSheet({required this.user});

  @override
  State<_UploadDokumenSheet> createState() => _UploadDokumenSheetState();
}

class _UploadDokumenSheetState extends State<_UploadDokumenSheet> {
  static const Color navy = Color(0xFF0D2C6E);

  final _nomorC = TextEditingController();
  final _judulC = TextEditingController();
  String _jenisDokumen = 'SK'; // 'SK' atau 'Diklat'
  DateTime _tglTerbit = DateTime.now();
  String? _fileNama;
  Uint8List? _fileBytes;
  bool _saving = false;

  @override
  void dispose() {
    _nomorC.dispose();
    _judulC.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _fileNama = res.files.first.name;
        _fileBytes = res.files.first.bytes;
      });
    }
  }

  Future<void> _submit() async {
    final nomor = _nomorC.text.trim();
    final judul = _judulC.text.trim();

    if (nomor.isEmpty) {
      _snack('Nomor surat/sertifikat wajib diisi.');
      return;
    }
    if (judul.isEmpty) {
      _snack('Judul/keterangan dokumen wajib diisi.');
      return;
    }

    setState(() => _saving = true);

    try {
      String fileUrl = '';
      if (_fileBytes != null && _fileNama != null) {
        fileUrl = await DokumenService.unggahFile(
          namaFile: _fileNama!,
          bytes: _fileBytes!,
        );
      }

      await DokumenService.simpan(
        judul: judul,
        kategori: _jenisDokumen,
        fileUrl: fileUrl,
        fileNama: _fileNama ?? (_jenisDokumen == 'SK' ? 'SK_Pegawai.pdf' : 'Sertifikat_Diklat.pdf'),
        diunggahOleh: widget.user.name,
        nomor: nomor,
        tglTerbit: _tglTerbit,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      _snack('Gagal mengunggah dokumen: $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2230) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Upload Dokumen (Admin SDM)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),

              // Jenis Dokumen Dropdown
              DropdownButtonFormField<String>(
                value: _jenisDokumen,
                decoration: InputDecoration(
                  labelText: 'Jenis Dokumen',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'SK', child: Text('Surat Kerja (SK)')),
                  DropdownMenuItem(value: 'Diklat', child: Text('Surat Diklat / Pelatihan')),
                ],
                onChanged: (v) => setState(() => _jenisDokumen = v ?? 'SK'),
              ),
              const SizedBox(height: 12),

              // Nomor Surat
              TextField(
                controller: _nomorC,
                decoration: InputDecoration(
                  labelText: 'Nomor Surat/Sertifikat',
                  hintText: 'Contoh: SK/SDM/2024/001',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Judul Dokumen
              TextField(
                controller: _judulC,
                decoration: InputDecoration(
                  labelText: 'Judul / Keterangan Dokumen',
                  hintText: 'Contoh: SK Pengangkatan Pegawai',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Tanggal Terbit DatePicker
              InkWell(
                onTap: () async {
                  final pick = await showDatePicker(
                    context: context,
                    initialDate: _tglTerbit,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pick != null) {
                    setState(() => _tglTerbit = pick);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tanggal Terbit: ${_tglTerbit.year}-${_tglTerbit.month.toString().padLeft(2, '0')}-${_tglTerbit.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                      ),
                      const Icon(Icons.calendar_month_rounded, size: 18, color: navy),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // File Picker
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(
                  _fileNama ?? 'Pilih File (PDF/Gambar)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: const BorderSide(color: navy),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: AppColors.divider(context)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Unggah Dokumen',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}