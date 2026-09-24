import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

class _KeluargaRow {
  final int? id;
  final String nama;
  final String hubungan;
  final String tanggalLahir;
  final String pekerjaan;

  const _KeluargaRow({
    this.id,
    required this.nama,
    required this.hubungan,
    required this.tanggalLahir,
    required this.pekerjaan,
  });

  factory _KeluargaRow.fromMap(Map<String, dynamic> row) {
    return _KeluargaRow(
      id: row['id'] != null ? int.tryParse(row['id'].toString()) : null,
      nama: (row['nama'] ?? '') as String,
      hubungan: (row['hubungan'] ?? '') as String,
      tanggalLahir: (row['tanggal_lahir'] ?? row['tgl_lahir'] ?? '-') as String,
      pekerjaan: (row['pekerjaan'] ?? row['keterangan'] ?? '-') as String,
    );
  }
}

Future<String?> _resolvePegawaiId(AppUser? user) async {
  String? userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null && userId.isNotEmpty) return userId;

  String? nik = user?.nik;
  if (nik == null || nik.isEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      nik = prefs.getString('user_nik');
      if (nik == null || nik.isEmpty) {
        final sessionStr = prefs.getString('user_session_json');
        if (sessionStr != null && sessionStr.isNotEmpty) {
          final jsonMap = jsonDecode(sessionStr);
          nik = jsonMap['nik'] as String?;
        }
      }
    } catch (_) {}
  }

  if (nik != null && nik.isNotEmpty) {
    try {
      final peg = await Supabase.instance.client
          .from('pegawai')
          .select('id')
          .eq('nik', nik)
          .maybeSingle();
      if (peg != null && peg['id'] != null) {
        return peg['id'].toString();
      }
    } catch (_) {}
  }

  return null;
}

Future<List<_KeluargaRow>> _fetchKeluarga(AppUser? user) async {
  final userId = await _resolvePegawaiId(user);
  if (userId == null) return [];

  final rows = await Supabase.instance.client
      .from('keluarga')
      .select()
      .eq('pegawai_id', userId)
      .order('created_at', ascending: true);

  return (rows as List)
      .map((r) => _KeluargaRow.fromMap(r as Map<String, dynamic>))
      .toList();
}

/// Halaman "Data Keluarga" — menampilkan daftar anggota keluarga pegawai
/// yang sedang login, diambil dari Supabase.
class KeluargaScreen extends StatefulWidget {
  final AppUser? user;
  const KeluargaScreen({super.key, this.user});

  @override
  State<KeluargaScreen> createState() => _KeluargaScreenState();
}

class _KeluargaScreenState extends State<KeluargaScreen> {
  late Future<List<_KeluargaRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchKeluarga(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchKeluarga(widget.user));
    await _future;
  }

  Future<void> _showTambahDialog() async {
    final namaCtrl = TextEditingController();
    final tglCtrl = TextEditingController();
    final pekerjaanCtrl = TextEditingController();
    String hubungan = 'Istri/Suami';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.family_restroom, color: Color(0xFF8E44AD)),
              SizedBox(width: 10),
              Text('Tambah Anggota Keluarga', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nama Lengkap', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: namaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Siti Aisyah',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Hubungan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: hubungan,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Istri/Suami', child: Text('Istri/Suami')),
                    DropdownMenuItem(value: 'Anak', child: Text('Anak')),
                    DropdownMenuItem(value: 'Orang Tua', child: Text('Orang Tua')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => hubungan = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Tanggal Lahir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: tglCtrl,
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2000, 1, 1),
                      firstDate: DateTime(1930),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final str = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      setDlgState(() => tglCtrl.text = str);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Pilih Tanggal Lahir',
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Pekerjaan / Status Kuliah', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: pekerjaanCtrl,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Kuliah / Pelajar / Bekerja',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (namaCtrl.text.trim().isEmpty) return;
                final pegId = await _resolvePegawaiId(widget.user);
                if (pegId != null) {
                  try {
                    await Supabase.instance.client.from('keluarga').insert({
                      'pegawai_id': pegId,
                      'nama': namaCtrl.text.trim(),
                      'hubungan': hubungan,
                      'tanggal_lahir': tglCtrl.text.trim().isEmpty ? '-' : tglCtrl.text.trim(),
                      'pekerjaan': pekerjaanCtrl.text.trim().isEmpty ? '-' : pekerjaanCtrl.text.trim(),
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
                    }
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data anggota keluarga berhasil ditambahkan')),
        );
      }
    }
  }

  Future<void> _hapusKeluarga(_KeluargaRow item) async {
    if (item.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Anggota Keluarga'),
        content: Text('Yakin ingin menghapus ${item.nama}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('keluarga').delete().eq('id', item.id!);
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anggota keluarga berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Data Keluarga',
      subtitle: 'Daftar anggota keluarga pegawai',
      icon: Icons.family_restroom_rounded,
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
        tooltip: 'Tambah Anggota Keluarga',
        onPressed: _showTambahDialog,
      ),
      child: FutureBuilder<List<_KeluargaRow>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'Gagal memuat data keluarga: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            );
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  const EmptyState(message: 'Belum ada data keluarga'),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _showTambahDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E44AD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah Anggota Keluarga'),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InfoCard(
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1E7F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Color(0xFF8E44AD), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.nama,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: FeatureScaffold.navy,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(
                                    label: item.hubungan,
                                    color: const Color(0xFF8E44AD),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Lahir: ${item.tanggalLahir}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              Text(
                                'Pekerjaan: ${item.pekerjaan}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.id != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                            tooltip: 'Hapus',
                            onPressed: () => _hapusKeluarga(item),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
