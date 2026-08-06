import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/pengaduan_model.dart' show formatTanggalJam;
import '../../models/pengumuman_model.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import '../../widgets/pengumuman_card.dart';
import '../../widgets/role_guard.dart';

/// Halaman KELOLA PENGUMUMAN — khusus role SDM.
/// Buat / ubah / hapus / publikasikan pengumuman lengkap dengan prioritas,
/// sematkan, target role, jadwal terbit, kedaluwarsa, dan lampiran.
class KelolaPengumumanScreen extends StatefulWidget {
  final AppUser user;
  const KelolaPengumumanScreen({super.key, required this.user});

  @override
  State<KelolaPengumumanScreen> createState() => _KelolaPengumumanScreenState();
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

  void _refresh() {
    // Gunakan body blok (bukan arrow) agar closure setState mengembalikan
    // void, bukan Future. Arrow `=> _future = ...` membuat closure
    // mengembalikan Future sehingga memicu error "setState() callback
    // argument returned a Future" saat hapus / nonaktifkan.
    setState(() {
      _future = PengumumanService.semua();
    });
  }

  Future<void> _bukaForm({Pengumuman? existing}) async {
    final berubah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _FormPengumumanScreen(
          user: widget.user,
          existing: existing,
        ),
      ),
    );
    if (berubah == true) _refresh();
  }

  Future<void> _togglePublikasi(Pengumuman p) async {
    try {
      await PengumumanService.setAktif(id: p.id, aktif: !p.aktif);
      _refresh();
    } catch (e) {
      _pesan('Gagal memperbarui status: $e');
    }
  }

  Future<void> _hapus(Pengumuman p) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengumuman'),
        content: Text('Yakin ingin menghapus "${p.judul}"?'),
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
      await PengumumanService.hapus(id: p.id);
      _refresh();
    } catch (e) {
      _pesan('Gagal menghapus: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.sdm],
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _bukaForm(),
          backgroundColor: _navy,
          elevation: 3,
          highlightElevation: 6,
          shape: const StadiumBorder(),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Buat',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: FeatureScaffold(
          title: 'Kelola Pengumuman',
          subtitle: 'Buat & atur pengumuman untuk seluruh pegawai',
          icon: Icons.campaign_rounded,
          child: FutureBuilder<List<Pengumuman>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Gagal memuat: ${snapshot.error}',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              final items = snapshot.data ?? const <Pengumuman>[];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.campaign_outlined,
                  message: 'Belum ada pengumuman. Tekan "Buat".',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                itemCount: items.length,
                itemBuilder: (context, i) =>
                    _buildItem(items[i], isDark),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItem(Pengumuman p, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1B2230) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEDF0F4);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.disematkan)
                      Container(
                        margin: const EdgeInsets.only(right: 6, top: 1),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD35400).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.push_pin_rounded,
                            size: 13, color: Color(0xFFD35400)),
                      ),
                    if (p.isPenting)
                      Container(
                        margin: const EdgeInsets.only(right: 6, top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('PENTING',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                letterSpacing: 0.3,
                                fontWeight: FontWeight.w800)),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(p.judul,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1B2733))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(p),
                  ],
                ),
                const SizedBox(height: 8),
                Text(p.ringkasan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark
                            ? const Color(0xFF9AA6B2)
                            : Colors.grey[700])),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _metaChip(
                      icon: Icons.event_rounded,
                      label: formatTanggalJam(p.tanggalPublikasi),
                      isDark: isDark,
                    ),
                    if (p.adaLampiran)
                      _metaChip(
                        icon: Icons.attach_file_rounded,
                        label: 'Lampiran',
                        isDark: isDark,
                        color: _accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 1)),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => showPengumumanDetail(context, p),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Lihat',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    backgroundColor: _accent.withValues(alpha: 0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    _actionButton(
                      tooltip: p.aktif ? 'Batalkan publikasi' : 'Publikasikan',
                      icon: p.aktif
                          ? Icons.toggle_on_rounded
                          : Icons.toggle_off_rounded,
                      color: p.aktif ? const Color(0xFF27AE60) : Colors.grey,
                      onPressed: () => _togglePublikasi(p),
                      iconSize: 24,
                    ),
                    const SizedBox(width: 6),
                    _actionButton(
                      tooltip: 'Ubah',
                      icon: Icons.edit_rounded,
                      color: _navy,
                      onPressed: () => _bukaForm(existing: p),
                    ),
                    const SizedBox(width: 6),
                    _actionButton(
                      tooltip: 'Hapus',
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFE74C3C),
                      onPressed: () => _hapus(p),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip({
    required IconData icon,
    required String label,
    required bool isDark,
    Color? color,
  }) {
    final fg = color ?? (isDark ? Colors.grey[400] : Colors.grey[600]);
    final bg = color != null
        ? color.withValues(alpha: 0.1)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F6F9));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double iconSize = 20,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(Pengumuman p) {
    final tayang = p.sedangTayang;
    final terjadwal = p.aktif &&
        p.terbitPada != null &&
        DateTime.now().toUtc().isBefore(p.terbitPada!);
    String label;
    Color color;
    if (terjadwal) {
      label = 'Terjadwal';
      color = const Color(0xFFE67E22);
    } else if (tayang) {
      label = 'Tayang';
      color = const Color(0xFF27AE60);
    } else {
      label = 'Nonaktif';
      color = const Color(0xFF95A5A6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Form buat/ubah pengumuman.
class _FormPengumumanScreen extends StatefulWidget {
  final AppUser user;
  final Pengumuman? existing;
  const _FormPengumumanScreen({required this.user, this.existing});

  @override
  State<_FormPengumumanScreen> createState() => _FormPengumumanScreenState();
}

class _FormPengumumanScreenState extends State<_FormPengumumanScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const _bucket = 'pengumuman';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judulC;
  late final TextEditingController _isiC;

  bool _penting = false;
  bool _sematkan = false;
  bool _publikasikan = true;
  late Set<UserRole> _target;
  DateTime? _terbitPada;
  DateTime? _kedaluwarsa;
  String? _lampiranUrl;
  String? _lampiranNama;
  bool _uploading = false;
  bool _menyimpan = false;

  bool get _edit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _judulC = TextEditingController(text: e?.judul ?? '');
    _isiC = TextEditingController(text: e?.isi ?? '');
    _penting = e?.isPenting ?? false;
    _sematkan = e?.disematkan ?? false;
    _publikasikan = e?.aktif ?? true;
    _terbitPada = e?.terbitPada?.add(const Duration(hours: 7));
    _kedaluwarsa = e?.kedaluwarsaPada?.add(const Duration(hours: 7));
    _lampiranUrl = e?.lampiranUrl;
    _lampiranNama = e?.lampiranNama;
    if (e != null && e.targetRoles.isNotEmpty) {
      _target = e.targetRoles
          .map((n) => UserRole.values.firstWhere((r) => r.name == n,
              orElse: () => UserRole.pegawai))
          .toSet();
    } else {
      _target = PengumumanService.roleTujuan.toSet();
    }
  }

  @override
  void dispose() {
    _judulC.dispose();
    _isiC.dispose();
    super.dispose();
  }

  Future<void> _pilihLampiran() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      if (f.bytes == null) {
        _pesan('Tidak dapat membaca file.');
        return;
      }
      setState(() => _uploading = true);
      final client = Supabase.instance.client;
      final path =
          '${DateTime.now().millisecondsSinceEpoch}_${f.name}'.replaceAll(' ', '_');
      await client.storage.from(_bucket).uploadBinary(path, f.bytes!);
      final url = client.storage.from(_bucket).getPublicUrl(path);
      setState(() {
        _lampiranUrl = url;
        _lampiranNama = f.name;
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      _pesan('Gagal mengunggah lampiran: $e');
    }
  }

  Future<DateTime?> _pilihTanggalWaktu(DateTime? awal) async {
    final now = DateTime.now();
    final tgl = await showDatePicker(
      context: context,
      initialDate: awal ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (tgl == null) return null;
    if (!mounted) return null;
    final waktu = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(awal ?? now),
    );
    return DateTime(
        tgl.year, tgl.month, tgl.day, waktu?.hour ?? 0, waktu?.minute ?? 0);
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_target.isEmpty) {
      _pesan('Pilih minimal satu role tujuan.');
      return;
    }
    setState(() => _menyimpan = true);
    try {
      final target = _target.toList();
      if (_edit) {
        await PengumumanService.ubah(
          id: widget.existing!.id,
          judul: _judulC.text,
          isi: _isiC.text,
          prioritas: _penting ? 'penting' : 'umum',
          disematkan: _sematkan,
          target: target,
          terbitPada: _terbitPada,
          kedaluwarsaPada: _kedaluwarsa,
          lampiranUrl: _lampiranUrl,
          lampiranNama: _lampiranNama,
        );
        if (widget.existing!.aktif != _publikasikan) {
          await PengumumanService.setAktif(
              id: widget.existing!.id, aktif: _publikasikan);
        }
      } else {
        await PengumumanService.buat(
          judul: _judulC.text,
          isi: _isiC.text,
          pembuat: widget.user.name,
          aktif: _publikasikan,
          prioritas: _penting ? 'penting' : 'umum',
          disematkan: _sematkan,
          target: target,
          terbitPada: _terbitPada,
          kedaluwarsaPada: _kedaluwarsa,
          lampiranUrl: _lampiranUrl,
          lampiranNama: _lampiranNama,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (e) {
      setState(() => _menyimpan = false);
      _pesan(e.message.toString());
    } catch (e) {
      setState(() => _menyimpan = false);
      _pesan('Gagal menyimpan: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: _edit ? 'Ubah Pengumuman' : 'Buat Pengumuman',
      subtitle: 'Isi detail lalu simpan',
      icon: Icons.edit_note_rounded,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            TextFormField(
              controller: _judulC,
              decoration: _dek('Judul *', 'Judul pengumuman'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _isiC,
              maxLines: 6,
              decoration: _dek('Isi *', 'Tulis isi pengumuman lengkap…'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Isi wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _kartu(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: _accent,
                    title: const Text('Tandai Penting',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Tampil dengan warna & badge merah'),
                    value: _penting,
                    onChanged: (v) => setState(() => _penting = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: _accent,
                    title: const Text('Sematkan di atas',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Selalu tampil paling atas'),
                    value: _sematkan,
                    onChanged: (v) => setState(() => _sematkan = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: _accent,
                    title: const Text('Publikasikan sekarang',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Nonaktif = disimpan sebagai draf'),
                    value: _publikasikan,
                    onChanged: (v) => setState(() => _publikasikan = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _label('Role Tujuan'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: PengumumanService.roleTujuan.map((r) {
                final aktif = _target.contains(r);
                return FilterChip(
                  label: Text(r.label),
                  selected: aktif,
                  selectedColor: _accent.withValues(alpha: 0.2),
                  checkmarkColor: _accent,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _target.add(r);
                    } else {
                      _target.remove(r);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _jadwalTile(
              label: 'Jadwal Terbit (opsional)',
              value: _terbitPada,
              onPick: () async {
                final d = await _pilihTanggalWaktu(_terbitPada);
                if (d != null) setState(() => _terbitPada = d);
              },
              onClear: () => setState(() => _terbitPada = null),
            ),
            const SizedBox(height: 10),
            _jadwalTile(
              label: 'Kedaluwarsa (opsional)',
              value: _kedaluwarsa,
              onPick: () async {
                final d = await _pilihTanggalWaktu(_kedaluwarsa);
                if (d != null) setState(() => _kedaluwarsa = d);
              },
              onClear: () => setState(() => _kedaluwarsa = null),
            ),
            const SizedBox(height: 16),
            _label('Lampiran (gambar / PDF, opsional)'),
            const SizedBox(height: 8),
            if (_lampiranUrl != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded,
                        size: 18, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_lampiranNama ?? 'Lampiran',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _lampiranUrl = null;
                        _lampiranNama = null;
                      }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pilihLampiran,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(_uploading
                  ? 'Mengunggah…'
                  : (_lampiranUrl == null ? 'Pilih Lampiran' : 'Ganti Lampiran')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _menyimpan ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _menyimpan
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_edit ? 'Simpan Perubahan' : 'Terbitkan',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jadwalTile({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return _kartu(
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: _accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value == null
                      ? 'Belum diatur'
                      : formatTanggalJam(value.toUtc()),
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (value != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onClear,
            ),
          TextButton(onPressed: onPick, child: const Text('Pilih')),
        ],
      ),
    );
  }

  Widget _kartu({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2230) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _label(String t) => Align(
        alignment: Alignment.centerLeft,
        child: Text(t,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700)),
      );

  InputDecoration _dek(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      );
}