import 'package:flutter/material.dart';
import '../../models/cuti_service.dart';
import '../../models/pengaduan_model.dart' show formatTanggalIndonesia;
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

/// B8 — PENGAJUAN CUTI / IZIN (sisi Pegawai).
/// Pegawai mengajukan cuti/izin/sakit lalu memantau statusnya.
class PengajuanCutiScreen extends StatefulWidget {
  final AppUser user;
  const PengajuanCutiScreen({super.key, required this.user});

  @override
  State<PengajuanCutiScreen> createState() => _PengajuanCutiScreenState();
}

class _PengajuanCutiScreenState extends State<PengajuanCutiScreen> {
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<PengajuanCuti>> _future;

  @override
  void initState() {
    super.initState();
    _future = CutiService.milikSaya();
  }

  void _refresh() => setState(() => _future = CutiService.milikSaya());

  Future<void> _bukaForm() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormCutiSheet(namaPegawai: widget.user.name),
    );
    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Pengajuan Cuti / Izin',
      subtitle: 'Ajukan & pantau status pengajuan Anda',
      icon: Icons.beach_access_rounded,
      trailing: IconButton(
        onPressed: _bukaForm,
        icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
      ),
      child: FutureBuilder<List<PengajuanCuti>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const <PengajuanCuti>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.beach_access_outlined,
              message: 'Belum ada pengajuan. Tekan + untuk mengajukan.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              itemCount: items.length,
              itemBuilder: (context, i) => _tile(items[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(PengajuanCuti c) {
    Color warna;
    switch (c.status) {
      case StatusCuti.disetujui:
        warna = const Color(0xFF27AE60);
        break;
      case StatusCuti.ditolak:
        warna = const Color(0xFFE74C3C);
        break;
      default:
        warna = const Color(0xFFE67E22);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${c.jenis.label} · ${c.jumlahHari} hari',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              StatusBadge(label: c.status.label, color: warna),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${formatTanggalIndonesia(c.tanggalMulai)} s/d '
              '${formatTanggalIndonesia(c.tanggalSelesai)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(c.alasan,
              style: const TextStyle(fontSize: 12.5, height: 1.4)),
          if (c.catatanApprover != null &&
              c.catatanApprover!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                  'Catatan: ${c.catatanApprover}'
                  '${c.diputuskanOleh != null ? ' — ${c.diputuskanOleh}' : ''}',
                  style: TextStyle(fontSize: 11.5, color: warna)),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormCutiSheet extends StatefulWidget {
  final String namaPegawai;
  const _FormCutiSheet({required this.namaPegawai});

  @override
  State<_FormCutiSheet> createState() => _FormCutiSheetState();
}

class _FormCutiSheetState extends State<_FormCutiSheet> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  final _alasanC = TextEditingController();
  JenisCuti _jenis = JenisCuti.cuti;
  DateTime? _mulai;
  DateTime? _selesai;
  bool _kirim = false;

  @override
  void dispose() {
    _alasanC.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal({required bool mulai}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: mulai ? (_mulai ?? now) : (_selesai ?? _mulai ?? now),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d == null) return;
    setState(() {
      if (mulai) {
        _mulai = d;
        if (_selesai != null && _selesai!.isBefore(d)) _selesai = d;
      } else {
        _selesai = d;
      }
    });
  }

  Future<void> _submit() async {
    if (_mulai == null || _selesai == null) {
      _pesan('Pilih tanggal mulai & selesai.');
      return;
    }
    if (_alasanC.text.trim().isEmpty) {
      _pesan('Alasan wajib diisi.');
      return;
    }
    setState(() => _kirim = true);
    try {
      await CutiService.ajukan(
        namaPegawai: widget.namaPegawai,
        jenis: _jenis,
        mulai: _mulai!,
        selesai: _selesai!,
        alasan: _alasanC.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (e) {
      setState(() => _kirim = false);
      _pesan(e.message.toString());
    } catch (e) {
      setState(() => _kirim = false);
      _pesan('Gagal mengirim: $e');
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
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
            const Text('Ajukan Cuti / Izin',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Jenis',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: JenisCuti.values.map((j) {
                final aktif = _jenis == j;
                return ChoiceChip(
                  label: Text(j.label),
                  selected: aktif,
                  selectedColor: _accent.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _jenis = j),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _tanggalPicker('Mulai', _mulai,
                      () => _pilihTanggal(mulai: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _tanggalPicker('Selesai', _selesai,
                      () => _pilihTanggal(mulai: false)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _alasanC,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _kirim ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _kirim
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Kirim Pengajuan',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tanggalPicker(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              value == null
                  ? 'Pilih tanggal'
                  : formatTanggalIndonesia(value),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
