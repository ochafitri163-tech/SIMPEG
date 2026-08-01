import 'package:flutter/material.dart';
import '../../models/cuti_service.dart';
import '../../models/pengaduan_model.dart' show formatTanggalIndonesia;
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import '../../widgets/role_guard.dart';

/// B8 — PERSETUJUAN CUTI / IZIN (sisi approver: SDM & Direktur).
/// Menyetujui atau menolak pengajuan cuti pegawai + memberi catatan.
class PersetujuanCutiScreen extends StatefulWidget {
  final AppUser user;
  const PersetujuanCutiScreen({super.key, required this.user});

  @override
  State<PersetujuanCutiScreen> createState() => _PersetujuanCutiScreenState();
}

class _PersetujuanCutiScreenState extends State<PersetujuanCutiScreen> {
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<PengajuanCuti>> _future;
  bool _hanyaMenunggu = true;

  @override
  void initState() {
    super.initState();
    _future = CutiService.semua(hanyaMenunggu: _hanyaMenunggu);
  }

  void _refresh() => setState(() {
        _future = CutiService.semua(hanyaMenunggu: _hanyaMenunggu);
      });

  Future<void> _putuskan(PengajuanCuti c, StatusCuti keputusan) async {
    final catatanC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(keputusan == StatusCuti.disetujui
            ? 'Setujui Pengajuan'
            : 'Tolak Pengajuan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${c.namaPegawai} — ${c.jenis.label} (${c.jumlahHari} hari)'),
            const SizedBox(height: 12),
            TextField(
              controller: catatanC,
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Catatan (opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: keputusan == StatusCuti.disetujui
                  ? const Color(0xFF27AE60)
                  : const Color(0xFFE74C3C),
            ),
            child: Text(
                keputusan == StatusCuti.disetujui ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CutiService.putuskan(
        pengajuan: c,
        keputusan: keputusan,
        namaApprover: widget.user.name,
        catatan: catatanC.text.trim().isEmpty ? null : catatanC.text.trim(),
      );
      _refresh();
      _pesan('Pengajuan ${keputusan.label.toLowerCase()}.');
    } catch (e) {
      _pesan('Gagal memproses: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: CutiService.roleApprover,
      child: FeatureScaffold(
        title: 'Persetujuan Cuti',
        subtitle: 'Setujui / tolak pengajuan pegawai',
        icon: Icons.fact_check_rounded,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _filterChip('Menunggu', true),
                  const SizedBox(width: 8),
                  _filterChip('Semua', false),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<PengajuanCuti>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Gagal memuat: ${snapshot.error}'));
                  }
                  final items = snapshot.data ?? const <PengajuanCuti>[];
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.fact_check_outlined,
                      message: 'Tidak ada pengajuan.',
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
      ),
    );
  }

  Widget _filterChip(String label, bool menunggu) {
    final aktif = _hanyaMenunggu == menunggu;
    return ChoiceChip(
      label: Text(label),
      selected: aktif,
      selectedColor: _accent.withValues(alpha: 0.2),
      onSelected: (_) {
        setState(() => _hanyaMenunggu = menunggu);
        _refresh();
      },
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
    final menunggu = c.status == StatusCuti.menunggu;
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
              CircleAvatar(
                radius: 16,
                backgroundColor: _accent.withValues(alpha: 0.15),
                child: Text(
                  c.namaPegawai.isNotEmpty
                      ? c.namaPegawai[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: _accent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(c.namaPegawai,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              StatusBadge(label: c.status.label, color: warna),
            ],
          ),
          const SizedBox(height: 10),
          Text('${c.jenis.label} · ${c.jumlahHari} hari',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _accent)),
          Text(
              '${formatTanggalIndonesia(c.tanggalMulai)} s/d '
              '${formatTanggalIndonesia(c.tanggalSelesai)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(c.alasan,
              style: const TextStyle(fontSize: 12.5, height: 1.4)),
          if (menunggu) ...[
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _putuskan(c, StatusCuti.ditolak),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Tolak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE74C3C),
                      side: const BorderSide(color: Color(0xFFE74C3C)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _putuskan(c, StatusCuti.disetujui),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Setujui'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF27AE60),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (c.catatanApprover != null &&
              c.catatanApprover!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Catatan: ${c.catatanApprover}'
                '${c.diputuskanOleh != null ? ' — ${c.diputuskanOleh}' : ''}',
                style: TextStyle(fontSize: 11.5, color: warna)),
          ],
        ],
      ),
    );
  }
}
