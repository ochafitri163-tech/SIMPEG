import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/pengumuman_model.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import '../../widgets/pengumuman_card.dart';
import '../../widgets/role_guard.dart';

/// Halaman KHUSUS SDM untuk mengelola pengumuman: buat, ubah, hapus,
/// serta publikasikan / batalkan publikasi (aktif). Menerapkan validasi
/// judul & isi wajib diisi sebelum disimpan.
class KelolaPengumumanScreen extends StatefulWidget {
  final AppUser user;
  const KelolaPengumumanScreen({super.key, required this.user});

  @override
  State<KelolaPengumumanScreen> createState() =>
      _KelolaPengumumanScreenState();
}

class _KelolaPengumumanScreenState extends State<KelolaPengumumanScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengumuman>> _future;

  @override
  void initState() {
    super.initState();
    _future = PengumumanService.semua();
  }

  Future<void> _refresh() async {
    setState(() => _future = PengumumanService.semua());
    await _future;
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ---------- Form buat / ubah ----------
  Future<void> _bukaForm({Pengumuman? existing}) async {
    final judulController = TextEditingController(text: existing?.judul ?? '');
    final isiController = TextEditingController(text: existing?.isi ?? '');
    final formKey = GlobalKey<FormState>();
    bool aktif = existing?.aktif ?? true;
    final isEdit = existing != null;

    final tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Text(
                      isEdit ? 'Ubah Pengumuman' : 'Buat Pengumuman',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Judul dan isi wajib diisi. Contoh: "Besok seluruh '
                      'pegawai diwajibkan memakai baju batik."',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: judulController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Judul pengumuman',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Judul tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: isiController,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Isi pengumuman',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Isi tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: aktif,
                      activeColor: _navy,
                      title: const Text('Publikasikan (aktif)',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        aktif
                            ? 'Tampil di dashboard semua role.'
                            : 'Disimpan sebagai draf, tidak tampil di dashboard.',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onChanged: (v) => setSheetState(() => aktif = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            if (isEdit) {
                              await PengumumanService.ubah(
                                id: existing.id,
                                judul: judulController.text,
                                isi: isiController.text,
                              );
                              if (aktif != existing.aktif) {
                                await PengumumanService.setAktif(
                                    id: existing.id, aktif: aktif);
                              }
                            } else {
                              await PengumumanService.buat(
                                judul: judulController.text,
                                isi: isiController.text,
                                pembuat: widget.user.name,
                                aktif: aktif,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text('Gagal menyimpan: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: Text(isEdit ? 'Simpan Perubahan' : 'Publikasikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (tersimpan == true) {
      _showSnack(
          isEdit ? 'Pengumuman diperbarui.' : 'Pengumuman dipublikasikan.',
          const Color(0xFF27AE60));
      await _refresh();
    }
  }

  Future<void> _toggleAktif(Pengumuman p) async {
    try {
      await PengumumanService.setAktif(id: p.id, aktif: !p.aktif);
      _showSnack(
          !p.aktif ? 'Pengumuman dipublikasikan.' : 'Publikasi dibatalkan.',
          const Color(0xFF2E86AB));
      await _refresh();
    } catch (e) {
      _showSnack('Gagal mengubah status: $e', Colors.red);
    }
  }

  Future<void> _hapus(Pengumuman p) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pengumuman'),
        content: Text('Hapus "${p.judul}" secara permanen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await PengumumanService.hapus(id: p.id);
      _showSnack('Pengumuman dihapus.', const Color(0xFF7F8C8D));
      await _refresh();
    } catch (e) {
      _showSnack('Gagal menghapus: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.sdm],
      child: FeatureScaffold(
        title: 'Kelola Pengumuman',
        subtitle: 'Buat & publikasikan pengumuman untuk semua role',
        icon: Icons.campaign_rounded,
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Muat ulang',
          onPressed: _refresh,
        ),
        child: Stack(
          children: [
            FutureBuilder<List<Pengumuman>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Gagal memuat pengumuman:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? const <Pengumuman>[];
                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      children: const [
                        EmptyState(
                          icon: Icons.campaign_outlined,
                          message:
                              'Belum ada pengumuman. Tekan + untuk membuat.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _buildKelolaCard(items[i]),
                  ),
                );
              },
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: FloatingActionButton.extended(
                onPressed: () => _bukaForm(),
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKelolaCard(Pengumuman p) {
    final color = p.aktif ? const Color(0xFF27AE60) : const Color(0xFF95A5A6);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.aktif ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              p.ringkasan,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.event_rounded, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(formatTanggalJam(p.tanggalPublikasi),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                _aksiBtn(
                  icon: Icons.visibility_outlined,
                  label: 'Detail',
                  color: _accent,
                  onTap: () => showPengumumanDetail(context, p),
                ),
                const SizedBox(width: 6),
                _aksiBtn(
                  icon: p.aktif
                      ? Icons.unpublished_outlined
                      : Icons.publish_rounded,
                  label: p.aktif ? 'Nonaktif' : 'Publikasi',
                  color: const Color(0xFFE67E22),
                  onTap: () => _toggleAktif(p),
                ),
                const SizedBox(width: 6),
                _aksiBtn(
                  icon: Icons.edit_outlined,
                  label: 'Ubah',
                  color: _navy,
                  onTap: () => _bukaForm(existing: p),
                ),
                const SizedBox(width: 6),
                _aksiBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  color: const Color(0xFFE74C3C),
                  onTap: () => _hapus(p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aksiBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
