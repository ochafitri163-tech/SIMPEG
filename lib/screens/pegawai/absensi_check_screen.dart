import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/absensi_service.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

/// B7 — ABSENSI ASLI: check-in / check-out dengan swafoto (selfie) &
/// lokasi GPS (opsional bila izin lokasi tersedia). Menggantikan data
/// kehadiran dummy dengan presensi nyata yang tersimpan di Supabase.
class AbsensiCheckScreen extends StatefulWidget {
  final AppUser user;
  const AbsensiCheckScreen({super.key, required this.user});

  @override
  State<AbsensiCheckScreen> createState() => _AbsensiCheckScreenState();
}

class _AbsensiCheckScreenState extends State<AbsensiCheckScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const _bucket = 'absensi';

  bool _loading = true;
  bool _proses = false;
  AbsensiHarian? _hariIni;
  List<AbsensiHarian> _riwayat = const [];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final ini = await AbsensiService.hariIni();
      final riwayat = await AbsensiService.riwayat();
      if (!mounted) return;
      setState(() {
        _hariIni = ini;
        _riwayat = riwayat;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _pesan('Gagal memuat data absensi: $e');
    }
  }

  Future<Uint8List?> _ambilSelfie() async {
    try {
      final picker = ImagePicker();
      final XFile? img = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 55,
        preferredCameraDevice: CameraDevice.front,
      );
      if (img == null) return null;
      return await img.readAsBytes();
    } catch (e) {
      _pesan('Gagal mengambil foto: $e');
      return null;
    }
  }

  /// Ambil lokasi GPS bila diizinkan. Tidak wajib — mengembalikan null bila
  /// izin ditolak atau layanan lokasi tidak tersedia.
  Future<Position?> _ambilLokasi() async {
    try {
      final aktif = await Geolocator.isLocationServiceEnabled();
      if (!aktif) return null;
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkIn() async {
    setState(() => _proses = true);
    try {
      final selfie = await _ambilSelfie();
      if (selfie == null) {
        setState(() => _proses = false);
        _pesan('Swafoto diperlukan untuk check-in.');
        return;
      }
      final pos = await _ambilLokasi();
      final client = Supabase.instance.client;
      final path =
          '${widget.user.nik}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String? fotoUrl;
      try {
        await client.storage.from(_bucket).uploadBinary(path, selfie);
        fotoUrl = client.storage.from(_bucket).getPublicUrl(path);
      } catch (e) {
        // Bila upload gagal, absensi tetap tercatat tanpa foto.
        fotoUrl = null;
      }
      await AbsensiService.checkIn(
        fotoUrl: fotoUrl,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      await _muat();
      _pesan(pos == null
          ? 'Check-in berhasil (tanpa lokasi GPS).'
          : 'Check-in berhasil.');
    } catch (e) {
      _pesan('Gagal check-in: $e');
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _checkOut() async {
    final ini = _hariIni;
    if (ini == null) return;
    setState(() => _proses = true);
    try {
      await AbsensiService.checkOut(id: ini.id);
      await _muat();
      _pesan('Check-out berhasil. Selamat beristirahat!');
    } catch (e) {
      _pesan('Gagal check-out: $e');
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  Future<void> _ajukanIzin() async {
    final c = TextEditingController();
    final ket = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajukan Izin Hari Ini'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: 'Alasan izin (mis. sakit, keperluan keluarga)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (ket == null || ket.isEmpty) return;
    setState(() => _proses = true);
    try {
      await AbsensiService.ajukanIzinHariIni(keterangan: ket);
      await _muat();
      _pesan('Izin hari ini tercatat.');
    } catch (e) {
      _pesan('Gagal mengajukan izin: $e');
    } finally {
      if (mounted) setState(() => _proses = false);
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Absensi',
      subtitle: 'Check-in & check-out kehadiran',
      icon: Icons.fingerprint_rounded,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  _kartuStatus(),
                  const SizedBox(height: 20),
                  const Text('Riwayat Absensi',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_riwayat.isEmpty)
                    const EmptyState(
                        icon: Icons.history_rounded,
                        message: 'Belum ada riwayat absensi.')
                  else
                    ..._riwayat.map(_riwayatTile),
                ],
              ),
            ),
    );
  }

  Widget _kartuStatus() {
    final ini = _hariIni;
    final sudahMasuk = ini != null && ini.jamMasuk != null;
    final sudahPulang = ini?.sudahPulang ?? false;
    final izin = ini != null && ini.status == 'izin';

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.today_rounded, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatTanggalJam(DateTime.now().toUtc()),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                      izin
                          ? 'Anda mengajukan izin hari ini'
                          : sudahPulang
                              ? 'Anda sudah menyelesaikan hari ini'
                              : sudahMasuk
                                  ? 'Anda sudah check-in'
                                  : 'Anda belum melakukan check-in',
                      style:
                          TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: _jamBox('Jam Masuk',
                    ini?.jamMasuk == null
                        ? '--:--'
                        : formatTanggalJam(ini!.jamMasuk!).split(', ').last,
                    ini != null && ini.status == 'telat'
                        ? const Color(0xFFE67E22)
                        : const Color(0xFF27AE60)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _jamBox(
                    'Jam Pulang',
                    ini?.jamPulang == null
                        ? '--:--'
                        : formatTanggalJam(ini!.jamPulang!).split(', ').last,
                    _navy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!sudahMasuk && !izin) ...[
            _tombolUtama(
              label: 'Check-in Sekarang',
              icon: Icons.login_rounded,
              color: const Color(0xFF27AE60),
              onTap: _proses ? null : _checkIn,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _proses ? null : _ajukanIzin,
              icon: const Icon(Icons.event_busy_rounded, size: 18),
              label: const Text('Ajukan Izin Hari Ini'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
          ] else if (sudahMasuk && !sudahPulang && !izin)
            _tombolUtama(
              label: 'Check-out Sekarang',
              icon: Icons.logout_rounded,
              color: _navy,
              onTap: _proses ? null : _checkOut,
            ),
          if (_proses)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _jamBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _tombolUtama({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _riwayatTile(AbsensiHarian a) {
    Color c;
    switch (a.status) {
      case 'telat':
        c = const Color(0xFFE67E22);
        break;
      case 'izin':
        c = const Color(0xFF2E86AB);
        break;
      default:
        c = const Color(0xFF27AE60);
    }
    final masuk = a.jamMasuk == null
        ? '-'
        : formatTanggalJam(a.jamMasuk!).split(', ').last;
    final pulang = a.jamPulang == null
        ? '-'
        : formatTanggalJam(a.jamPulang!).split(', ').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1B2230)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${a.tanggal.day}/${a.tanggal.month}/${a.tanggal.year}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Masuk $masuk · Pulang $pulang',
                    style:
                        TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                if (a.keterangan != null && a.keterangan!.isNotEmpty)
                  Text(a.keterangan!,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(a.status[0].toUpperCase() + a.status.substring(1),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: c)),
          ),
        ],
      ),
    );
  }
}
