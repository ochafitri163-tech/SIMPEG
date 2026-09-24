import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';

class _CvData {
  final Map<String, dynamic> pegawai;
  final List<Map<String, dynamic>> pendidikan;
  final List<Map<String, dynamic>> riwayatJabatan;
  final List<Map<String, dynamic>> prestasi;
  final List<Map<String, dynamic>> keluarga;
  final List<Map<String, dynamic>> dokumen;

  const _CvData({
    required this.pegawai,
    required this.pendidikan,
    required this.riwayatJabatan,
    required this.prestasi,
    required this.keluarga,
    required this.dokumen,
  });
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

Future<_CvData> _fetchCvData(AppUser? user) async {
  final pegId = await _resolvePegawaiId(user);
  final client = Supabase.instance.client;

  Map<String, dynamic> pegMap = {};
  if (pegId != null) {
    try {
      final res = await client.from('pegawai').select().eq('id', pegId).maybeSingle();
      if (res != null) pegMap = Map<String, dynamic>.from(res);
    } catch (_) {}
  } else if (user?.nik != null && user!.nik.isNotEmpty) {
    try {
      final res = await client.from('pegawai').select().eq('nik', user.nik).maybeSingle();
      if (res != null) pegMap = Map<String, dynamic>.from(res);
    } catch (_) {}
  }

  final targetId = pegMap['id']?.toString() ?? pegId;

  List<Map<String, dynamic>> pendList = [];
  List<Map<String, dynamic>> jabList = [];
  List<Map<String, dynamic>> presList = [];
  List<Map<String, dynamic>> kelList = [];
  List<Map<String, dynamic>> dokList = [];

  if (targetId != null) {
    try {
      final r = await client.from('pendidikan').select().eq('pegawai_id', targetId).order('tahun_lulus', ascending: false);
      pendList = List<Map<String, dynamic>>.from(r);
    } catch (_) {}

    try {
      final r = await client.from('riwayat_jabatan').select().eq('pegawai_id', targetId).order('tmt', ascending: false);
      jabList = List<Map<String, dynamic>>.from(r);
    } catch (_) {}

    try {
      final r = await client.from('prestasi').select().eq('pegawai_id', targetId).order('tanggal', ascending: false);
      presList = List<Map<String, dynamic>>.from(r);
    } catch (_) {}

    try {
      final r = await client.from('keluarga').select().eq('pegawai_id', targetId).order('created_at', ascending: true);
      kelList = List<Map<String, dynamic>>.from(r);
    } catch (_) {}

    try {
      final r = await client.from('dokumen_pegawai').select().eq('pegawai_id', targetId).order('created_at', ascending: false);
      dokList = List<Map<String, dynamic>>.from(r);
    } catch (_) {}
  }

  return _CvData(
    pegawai: pegMap,
    pendidikan: pendList,
    riwayatJabatan: jabList,
    prestasi: presList,
    keluarga: kelList,
    dokumen: dokList,
  );
}

/// Halaman Curriculum Vitae (CV) Pegawai
/// Menyajikan ringkasan profil, biodata lengkap, riwayat pendidikan, riwayat jabatan,
/// diklat/dokumen surat, prestasi, dan susunan keluarga sama persis dengan modul CV di web.
class CvScreen extends StatefulWidget {
  final AppUser? user;
  const CvScreen({super.key, this.user});

  @override
  State<CvScreen> createState() => _CvScreenState();
}

class _CvScreenState extends State<CvScreen> {
  late Future<_CvData> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchCvData(widget.user);
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchCvData(widget.user));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Curriculum Vitae',
      subtitle: 'Dokumen Profil Riwayat Hidup Pegawai',
      icon: Icons.badge_rounded,
      child: FutureBuilder<_CvData>(
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
                  'Gagal memuat Curriculum Vitae: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            );
          }

          final cv = snapshot.data!;
          final peg = cv.pegawai;

          final nama = (peg['name'] ?? widget.user?.name ?? 'Pegawai').toString();
          final nik = (peg['nik'] ?? widget.user?.nik ?? '-').toString();
          final jabatan = (peg['jabatan'] ?? widget.user?.jabatan ?? '-').toString();
          final unitKerja = (peg['unit_kerja'] ?? widget.user?.unitKerja ?? 'Kantor Pusat').toString();
          final golongan = (peg['golongan'] ?? widget.user?.golonganUntukSlip ?? '-').toString();
          final statusPeg = (peg['status'] ?? widget.user?.status ?? '-').toString();

          final ttl = (peg['tempat_tanggal_lahir'] ?? '-').toString();
          final statusKawin = (peg['status_pernikahan'] ?? '-').toString();
          final alamat = (peg['alamat'] ?? '-').toString();
          final noTelp = (peg['no_telp'] ?? '-').toString();
          final email = (peg['email'] ?? '-').toString();

          final diklatDocs = cv.dokumen.where((d) {
            final kat = (d['kategori'] ?? '').toString().toLowerCase();
            return kat.contains('diklat') || kat.contains('pelatihan');
          }).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Header CV Card (Navy gradient style)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2C6E), Color(0xFF1E5FBF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D2C6E).withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 65,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.person, color: Colors.white, size: 36),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'CURRICULUM VITAE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  nama.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  jabatan,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  unitKerja,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHeaderMeta('NIK', nik),
                          _buildHeaderMeta('GOLONGAN', golongan),
                          _buildHeaderMeta('STATUS', statusPeg),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 1. DATA PRIBADI
                _buildCvSection(
                  title: '1. DATA PRIBADI',
                  icon: Icons.person_pin_rounded,
                  children: [
                    _buildKvRow('Tempat, Tgl Lahir', ttl),
                    _buildKvRow('Status Perkawinan', statusKawin),
                    _buildKvRow('Alamat', alamat),
                    _buildKvRow('No. Telepon', noTelp),
                    _buildKvRow('Email', email),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. RIWAYAT PENDIDIKAN
                _buildCvSection(
                  title: '2. RIWAYAT PENDIDIKAN',
                  icon: Icons.school_rounded,
                  children: [
                    if (cv.pendidikan.isEmpty)
                      _buildEmptyText('Belum ada data riwayat pendidikan.')
                    else
                      ...cv.pendidikan.map((p) {
                        final jenjang = (p['jenjang'] ?? '-').toString();
                        final jurusan = (p['jurusan'] ?? '').toString();
                        final inst = (p['nama_sekolah'] ?? p['institusi'] ?? '-').toString();
                        final thn = (p['tahun_lulus'] ?? '-').toString();
                        return _buildItemCard(
                          title: '$jenjang ${jurusan.isNotEmpty ? "• $jurusan" : ""}',
                          subtitle: inst,
                          trailing: thn,
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. RIWAYAT JABATAN
                _buildCvSection(
                  title: '3. RIWAYAT JABATAN',
                  icon: Icons.work_history_rounded,
                  children: [
                    if (cv.riwayatJabatan.isEmpty)
                      _buildEmptyText('Belum ada data riwayat jabatan.')
                    else
                      ...cv.riwayatJabatan.map((j) {
                        final jab = (j['jabatan'] ?? '-').toString();
                        final unit = (j['unit_kerja'] ?? '-').toString();
                        final tmt = (j['tmt'] ?? '-').toString();
                        return _buildItemCard(
                          title: jab,
                          subtitle: unit,
                          trailing: 'TMT: $tmt',
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 16),

                // 4. DIKLAT & PELATIHAN
                _buildCvSection(
                  title: '4. DIKLAT & PELATIHAN',
                  icon: Icons.card_membership_rounded,
                  children: [
                    if (diklatDocs.isEmpty)
                      _buildEmptyText('Belum ada data diklat/pelatihan resmi.')
                    else
                      ...diklatDocs.map((d) {
                        final judul = (d['judul'] ?? d['nomor'] ?? 'Sertifikat Diklat').toString();
                        final diunggah = (d['diunggah_oleh'] ?? 'Admin SDM').toString();
                        final tgl = (d['created_at'] != null ? d['created_at'].toString().substring(0, 10) : '-');
                        return _buildItemCard(
                          title: judul,
                          subtitle: 'Penerbit: $diunggah',
                          trailing: tgl,
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 16),

                // 5. PRESTASI / PENGHARGAAN
                _buildCvSection(
                  title: '5. PRESTASI & PENGHARGAAN',
                  icon: Icons.emoji_events_rounded,
                  children: [
                    if (cv.prestasi.isEmpty)
                      _buildEmptyText('Belum ada data penghargaan/prestasi.')
                    else
                      ...cv.prestasi.map((pr) {
                        final judul = (pr['judul'] ?? 'Prestasi Kerja').toString();
                        final tgl = (pr['tanggal'] ?? '-').toString();
                        String ket = (pr['keterangan'] ?? '-').toString();
                        if (ket.trim().startsWith('{')) {
                          try {
                            final dec = jsonDecode(ket);
                            if (dec is Map) ket = (dec['desc'] ?? dec['keterangan'] ?? ket).toString();
                          } catch (_) {}
                        }
                        return _buildItemCard(
                          title: judul,
                          subtitle: ket != '-' && ket.isNotEmpty ? ket : null,
                          trailing: tgl,
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 16),

                // 6. SUSUNAN KELUARGA
                _buildCvSection(
                  title: '6. DATA KELUARGA',
                  icon: Icons.family_restroom_rounded,
                  children: [
                    if (cv.keluarga.isEmpty)
                      _buildEmptyText('Belum ada data anggota keluarga.')
                    else
                      ...cv.keluarga.map((k) {
                        final kNama = (k['nama'] ?? '-').toString();
                        final kHub = (k['hubungan'] ?? '-').toString();
                        final kPek = (k['pekerjaan'] ?? k['keterangan'] ?? '-').toString();
                        final kTgl = (k['tanggal_lahir'] ?? k['tgl_lahir'] ?? '-').toString();
                        return _buildItemCard(
                          title: kNama,
                          subtitle: 'Pekerjaan: $kPek • Lahir: $kTgl',
                          trailing: kHub,
                        );
                      }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderMeta(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCvSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF1E40AF)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E40AF),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(' :  ', style: TextStyle(color: Color(0xFF94A3B8))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard({
    required String title,
    String? subtitle,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
