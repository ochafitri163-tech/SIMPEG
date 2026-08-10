import 'package:flutter/material.dart';

import '../../models/pengaduan_model.dart';
import '../../models/sk_sanksi_service.dart';
import '../../models/user_role.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dokumen_sk_picker.dart';
import '../../widgets/role_guard.dart';

/// =============================================================
/// SDM — PENERBITAN SK SANKSI
///
/// Form manual (SDM yang menyediakan seluruh dokumen pendukung) untuk
/// menerbitkan SK setelah keputusan disetujui DIRUT. SK berisi keputusan
/// sanksi — mis. penurunan jabatan Asmen -> Staf — dan otomatis:
///   • memperbarui jabatan/golongan pegawai,
///   • mengurangi payment lewat potongan sanksi di payroll,
///   • mengirim 4 dokumen wajib ke pegawai terlapor.
/// =============================================================
class TerbitkanSkScreen extends StatefulWidget {
  final AppUser user;

  /// Bila SK diterbitkan dari sebuah pengaduan, data terlapor & nomor
  /// pengaduan diisi otomatis.
  final Pengaduan? pengaduan;
  final int? pengaduanId;

  const TerbitkanSkScreen({
    super.key,
    required this.user,
    this.pengaduan,
    this.pengaduanId,
  });

  @override
  State<TerbitkanSkScreen> createState() => _TerbitkanSkScreenState();
}

class _TerbitkanSkScreenState extends State<TerbitkanSkScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _red = Color(0xFFE74C3C);
  static const Color _green = Color(0xFF27AE60);

  final _nikController = TextEditingController();
  final _namaController = TextEditingController();
  final _jabatanLamaController = TextEditingController();
  final _jabatanBaruController = TextEditingController();
  final _golonganLamaController = TextEditingController();
  final _golonganBaruController = TextEditingController();
  final _nominalController = TextEditingController();
  final _ringkasanController = TextEditingController();
  final _disetujuiOlehController = TextEditingController(text: 'Direktur Utama');

  final _dokumen = DokumenSkController();

  String _jenisSanksi = jenisSanksiPilihan.first;
  String _tingkat = 'Sedang';
  DateTime _tanggalBerlaku = DateTime.now();
  bool _validasiLisanDirut = true;
  bool _mencariPegawai = false;
  bool _menyimpan = false;
  String? _pesanPegawai;

  @override
  void initState() {
    super.initState();
    final p = widget.pengaduan;
    if (p != null) {
      _nikController.text = p.nik;
      _namaController.text = p.namaPegawai;
      _golonganLamaController.text = p.golongan;
      _ringkasanController.text = '${p.judul} (${p.nomorPengaduan})';
      _cariPegawai();
    }
  }

  @override
  void dispose() {
    _nikController.dispose();
    _namaController.dispose();
    _jabatanLamaController.dispose();
    _jabatanBaruController.dispose();
    _golonganLamaController.dispose();
    _golonganBaruController.dispose();
    _nominalController.dispose();
    _ringkasanController.dispose();
    _disetujuiOlehController.dispose();
    super.dispose();
  }

  void _snack(String pesan, Color warna) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan, style: const TextStyle(fontSize: 13)),
        backgroundColor: warna,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Mengambil jabatan & golongan pegawai saat ini berdasarkan NIK, supaya
  /// SDM tinggal mengisi jabatan barunya saja.
  Future<void> _cariPegawai() async {
    final nik = _nikController.text.trim();
    if (nik.isEmpty) {
      setState(() => _pesanPegawai = 'Isi NIK terlebih dahulu.');
      return;
    }
    setState(() {
      _mencariPegawai = true;
      _pesanPegawai = null;
    });
    try {
      final pegawai = await SkSanksiService.cariPegawaiByNik(nik);
      if (!mounted) return;
      if (pegawai == null) {
        setState(() => _pesanPegawai =
            'Pegawai dengan NIK $nik tidak ditemukan \u2014 data bisa diisi manual.');
        return;
      }
      setState(() {
        if (_namaController.text.trim().isEmpty) {
          _namaController.text = pegawai.nama;
        }
        if (pegawai.jabatan.isNotEmpty) {
          _jabatanLamaController.text = pegawai.jabatan;
        }
        if (pegawai.golongan.isNotEmpty) {
          _golonganLamaController.text = pegawai.golongan;
        }
        _pesanPegawai = 'Ditemukan: ${pegawai.nama}';
      });
    } catch (e) {
      if (mounted) setState(() => _pesanPegawai = 'Gagal mencari pegawai: $e');
    } finally {
      if (mounted) setState(() => _mencariPegawai = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggalBerlaku,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (hasil != null) setState(() => _tanggalBerlaku = hasil);
  }

  Future<void> _terbitkan() async {
    final nik = _nikController.text.trim();
    final nama = _namaController.text.trim();

    if (nik.isEmpty || nama.isEmpty) {
      _snack('NIK dan nama pegawai terlapor wajib diisi.', _red);
      return;
    }
    final kurang = _dokumen.belumLengkap;
    if (kurang.isNotEmpty) {
      _snack(
        'Dokumen wajib belum lengkap: ${kurang.map((j) => j.label).join(', ')}.',
        _red,
      );
      return;
    }
    if (!_validasiLisanDirut) {
      final lanjut = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Belum divalidasi DIRUT'),
          content: const Text(
            'SK sebaiknya hanya diterbitkan setelah keputusan divalidasi ke '
            'DIRUT. Tetap lanjutkan penerbitan?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Lanjutkan')),
          ],
        ),
      );
      if (lanjut != true) return;
    }

    setState(() => _menyimpan = true);
    try {
      final nominal = int.tryParse(
              _nominalController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
          0;

      final sk = await SkSanksiService.terbitkan(
        nik: nik,
        namaPegawai: nama,
        jenisSanksi: _jenisSanksi,
        tingkat: _tingkat,
        dokumen: _dokumen.snapshot(),
        dokumenTambahan: _dokumen.snapshotTambahan(),
        diterbitkanOleh: widget.user.name,
        pengaduanId: widget.pengaduanId,
        jabatanLama: _jabatanLamaController.text.trim(),
        jabatanBaru: _jabatanBaruController.text.trim(),
        golonganLama: _golonganLamaController.text.trim(),
        golonganBaru: _golonganBaruController.text.trim(),
        nominalPenurunanGaji: nominal,
        tanggalBerlaku: _tanggalBerlaku,
        ringkasanPelanggaran: _ringkasanController.text.trim(),
        validasiLisanDirut: _validasiLisanDirut,
        disetujuiOleh: _disetujuiOlehController.text.trim(),
        tanggalPersetujuanDirut:
            _validasiLisanDirut ? DateTime.now() : null,
      );

      if (!mounted) return;
      _snack(
        '${sk.nomorSk} terbit \u00b7 ${sk.totalBerkas} berkas terkirim ke $nama.',
        _green,
      );
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Gagal menerbitkan SK: $e', _red);
    } finally {
      if (mounted) setState(() => _menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.sdm],
      child: Scaffold(
        backgroundColor: AppColors.pageBackground(context),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('Terbitkan SK Sanksi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _judulBagian('1. Pegawai Terlapor', icon: Icons.badge_rounded),
              _kartu([
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        controller: _nikController,
                        label: 'NIK pegawai terlapor',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _mencariPegawai ? null : _cariPegawai,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _mencariPegawai
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
                if (_pesanPegawai != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _pesanPegawai!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _field(controller: _namaController, label: 'Nama pegawai'),
              ]),
              const SizedBox(height: 18),
              _judulBagian('2. Isi Keputusan', icon: Icons.gavel_rounded),
              _kartu([
                DropdownButtonFormField<String>(
                  value: _tingkat,
                  decoration: _dekorasi('Tingkat pelanggaran'),
                  items: [
                    for (final t in tingkatSanksiPilihan)
                      DropdownMenuItem(
                          value: t,
                          child: Text(t, style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) => setState(() => _tingkat = v ?? _tingkat),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _jenisSanksi,
                  decoration: _dekorasi('Jenis sanksi'),
                  items: [
                    for (final j in jenisSanksiPilihan)
                      DropdownMenuItem(
                          value: j,
                          child: Text(j, style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (v) =>
                      setState(() => _jenisSanksi = v ?? _jenisSanksi),
                ),
                if (_tingkat == 'Berat') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                            controller: _jabatanLamaController,
                            label: 'Jabatan lama'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                            controller: _jabatanBaruController,
                            label: 'Jabatan baru'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                            controller: _golonganLamaController,
                            label: 'Golongan lama'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                            controller: _golonganBaruController,
                            label: 'Golongan baru'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _nominalController,
                    label: 'Penurunan payment / potongan gaji (Rp)',
                    keyboardType: TextInputType.number,
                    prefixText: 'Rp ',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Jabatan turun berarti payment ikut berkurang. Nominal ini '
                    'langsung dipotong dari slip gaji periode terbaru pegawai.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pilihTanggal,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: _dekorasi('Tanggal SK berlaku'),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded,
                            size: 17, color: _accent),
                        const SizedBox(width: 8),
                        Text(
                          formatTanggalIndonesia(_tanggalBerlaku),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _ringkasanController,
                  label: 'Ringkasan pelanggaran',
                  maxLines: 3,
                ),
              ]),
              const SizedBox(height: 18),
              _judulBagian('3. Dokumen Wajib (4) + Tambahan',
                  icon: Icons.folder_copy_rounded),
              _kartu([
                DokumenSkPicker(
                  controller: _dokumen,
                  onChanged: () => setState(() {}),
                ),
              ]),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _menyimpan ? null : _terbitkan,
                  icon: _menyimpan
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.gavel_rounded, size: 18),
                  label: Text(
                    _menyimpan ? 'Menerbitkan...' : 'Terbitkan SK',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dokumen.lengkap ? _navy : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _judulBagian(String teks, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 6),
            ],
            Text(
              teks.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.divider(context),
              ),
            ),
          ],
        ),
      );

  Widget _kartu(List<Widget> anak) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider(context), width: 1),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: anak),
      );

  InputDecoration _dekorasi(String label, {String? prefixText}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixText: prefixText,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? prefixText,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: _dekorasi(label, prefixText: prefixText),
      );
}