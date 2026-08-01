import 'package:flutter/material.dart';
import '../../models/agenda_service.dart';
import '../../models/pengaduan_model.dart' show formatTanggalIndonesia;
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

/// B11 — KALENDER AGENDA / KEGIATAN.
/// Semua role dapat melihat agenda kantor. Role pengelola (SDM, Direktur,
/// Kadiv, KSPI, TPDPK) dapat menambah & menghapus agenda.
class AgendaScreen extends StatefulWidget {
  final AppUser user;
  const AgendaScreen({super.key, required this.user});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  static const List<String> _namaBulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  late int _tahun;
  late int _bulan;
  late Future<List<Agenda>> _future;

  bool get _bisaKelola => AgendaService.bolehKelola(widget.user.role);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tahun = now.year;
    _bulan = now.month;
    _future = AgendaService.bulan(tahun: _tahun, bulan: _bulan);
  }

  void _refresh() =>
      setState(() => _future = AgendaService.bulan(tahun: _tahun, bulan: _bulan));

  void _gantiBulan(int delta) {
    setState(() {
      _bulan += delta;
      if (_bulan < 1) {
        _bulan = 12;
        _tahun--;
      } else if (_bulan > 12) {
        _bulan = 1;
        _tahun++;
      }
      _future = AgendaService.bulan(tahun: _tahun, bulan: _bulan);
    });
  }

  Future<void> _tambah() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormAgendaSheet(
          user: widget.user, tahun: _tahun, bulan: _bulan),
    );
    if (ok == true) _refresh();
  }

  Future<void> _hapus(Agenda a) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Agenda'),
        content: Text('Hapus "${a.judul}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE74C3C)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    try {
      await AgendaService.hapus(id: a.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Agenda Kegiatan',
      subtitle: 'Kalender kegiatan & acara kantor',
      icon: Icons.calendar_month_rounded,
      trailing: _bisaKelola
          ? IconButton(
              onPressed: _tambah,
              icon: const Icon(Icons.add_circle_rounded,
                  color: Colors.white),
            )
          : null,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _gantiBulan(-1),
                  icon: const Icon(Icons.chevron_left_rounded, color: _navy),
                ),
                Text('${_namaBulan[_bulan - 1]} $_tahun',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _navy)),
                IconButton(
                  onPressed: () => _gantiBulan(1),
                  icon:
                      const Icon(Icons.chevron_right_rounded, color: _navy),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Agenda>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Gagal memuat: ${snapshot.error}'));
                }
                final items = snapshot.data ?? const <Agenda>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_available_rounded,
                    message: 'Tidak ada agenda pada bulan ini.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _tile(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Agenda a) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2230) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, _accent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('${a.tanggal.day}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text(_namaBulan[a.tanggal.month - 1].substring(0, 3),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.judul,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                if (a.deskripsi != null && a.deskripsi!.isNotEmpty)
                  Text(a.deskripsi!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    if (a.waktu != null && a.waktu!.isNotEmpty)
                      _meta(Icons.access_time_rounded, a.waktu!),
                    if (a.lokasi != null && a.lokasi!.isNotEmpty)
                      _meta(Icons.place_rounded, a.lokasi!),
                  ],
                ),
              ],
            ),
          ),
          if (_bisaKelola)
            IconButton(
              onPressed: () => _hapus(a),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFE74C3C), size: 20),
            ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _accent),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _accent)),
      ],
    );
  }
}

class _FormAgendaSheet extends StatefulWidget {
  final AppUser user;
  final int tahun;
  final int bulan;
  const _FormAgendaSheet(
      {required this.user, required this.tahun, required this.bulan});

  @override
  State<_FormAgendaSheet> createState() => _FormAgendaSheetState();
}

class _FormAgendaSheetState extends State<_FormAgendaSheet> {
  static const Color _navy = Color(0xFF0D2C6E);

  final _judulC = TextEditingController();
  final _deskripsiC = TextEditingController();
  final _waktuC = TextEditingController();
  final _lokasiC = TextEditingController();
  DateTime? _tanggal;
  bool _simpan = false;

  @override
  void dispose() {
    _judulC.dispose();
    _deskripsiC.dispose();
    _waktuC.dispose();
    _lokasiC.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(widget.tahun, widget.bulan, 1),
      firstDate: DateTime(widget.tahun - 1),
      lastDate: DateTime(widget.tahun + 2),
    );
    if (d != null) setState(() => _tanggal = d);
  }

  Future<void> _submit() async {
    if (_tanggal == null) {
      _pesan('Pilih tanggal kegiatan.');
      return;
    }
    setState(() => _simpan = true);
    try {
      await AgendaService.tambah(
        judul: _judulC.text,
        tanggal: _tanggal!,
        deskripsi: _deskripsiC.text.trim().isEmpty
            ? null
            : _deskripsiC.text.trim(),
        waktu: _waktuC.text.trim().isEmpty ? null : _waktuC.text.trim(),
        lokasi: _lokasiC.text.trim().isEmpty ? null : _lokasiC.text.trim(),
        dibuatOleh: widget.user.name,
      );
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (e) {
      setState(() => _simpan = false);
      _pesan(e.message.toString());
    } catch (e) {
      setState(() => _simpan = false);
      _pesan('Gagal menyimpan: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2230) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tambah Agenda',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _judulC,
              decoration: InputDecoration(
                labelText: 'Judul Kegiatan *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pilihTanggal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: _navy),
                    const SizedBox(width: 10),
                    Text(
                      _tanggal == null
                          ? 'Pilih tanggal *'
                          : formatTanggalIndonesia(_tanggal!),
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _waktuC,
                    decoration: InputDecoration(
                      labelText: 'Waktu',
                      hintText: 'mis. 09:00 WIB',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lokasiC,
                    decoration: InputDecoration(
                      labelText: 'Lokasi',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deskripsiC,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _simpan ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _simpan
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Agenda',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
