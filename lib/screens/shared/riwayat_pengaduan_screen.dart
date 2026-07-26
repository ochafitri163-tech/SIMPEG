import 'package:flutter/material.dart';
import '../../models/pengaduan_model.dart';
import '../../models/pengaduan_service.dart';
import '../../models/user_role.dart';
import 'detail_pengaduan_screen.dart';

/// Layar Riwayat Pengaduan yang dipakai bersama oleh SEMUA role
/// (Kadiv, KSPI, TPDPK, SDM, dan bisa juga Direktur). Menampilkan seluruh
/// pengaduan yang relevan dengan role tersebut, lengkap dengan filter
/// status (Semua / Diproses / Selesai / Diarsipkan) & pencarian ke halaman
/// detail.
///
/// Sumber data: [PengaduanService.untukRoleSebagaiObjek], sehingga tiap
/// role melihat daftar sesuai kewenangannya. Layar ini sengaja read-only —
/// aksi (verifikasi/approval/investigasi) tetap dilakukan dari dashboard
/// masing-masing role.
class RiwayatPengaduanScreen extends StatefulWidget {
  final AppUser user;
  const RiwayatPengaduanScreen({super.key, required this.user});

  @override
  State<RiwayatPengaduanScreen> createState() => _RiwayatPengaduanScreenState();
}

/// Kategori filter yang ditampilkan sebagai chip di bagian atas.
enum _FilterRiwayat { semua, diproses, selesai, arsip }

extension _FilterRiwayatX on _FilterRiwayat {
  String get label {
    switch (this) {
      case _FilterRiwayat.semua:
        return 'Semua';
      case _FilterRiwayat.diproses:
        return 'Diproses';
      case _FilterRiwayat.selesai:
        return 'Selesai';
      case _FilterRiwayat.arsip:
        return 'Diarsipkan';
    }
  }

  bool cocok(Pengaduan p) {
    switch (this) {
      case _FilterRiwayat.semua:
        return true;
      case _FilterRiwayat.selesai:
        return p.status == PengaduanStatus.selesai;
      case _FilterRiwayat.arsip:
        return p.status == PengaduanStatus.arsip;
      case _FilterRiwayat.diproses:
        return p.status != PengaduanStatus.selesai &&
            p.status != PengaduanStatus.arsip;
    }
  }
}

class _RiwayatPengaduanScreenState extends State<RiwayatPengaduanScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  late Future<List<Pengaduan>> _future;
  _FilterRiwayat _filter = _FilterRiwayat.semua;

  @override
  void initState() {
    super.initState();
    _future = PengaduanService.untukRoleSebagaiObjek(widget.user.role);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PengaduanService.untukRoleSebagaiObjek(widget.user.role);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Riwayat Pengaduan'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Pengaduan>>(
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
                  'Gagal memuat riwayat: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            );
          }

          final semua = snapshot.data ?? [];
          final terfilter = semua.where(_filter.cocok).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                _buildFilterBar(semua),
                Expanded(
                  child: terfilter.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            _buildEmptyState(),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: terfilter.length,
                          itemBuilder: (_, i) => _buildCard(terfilter[i]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(List<Pengaduan> semua) {
    int hitung(_FilterRiwayat f) => semua.where(f.cocok).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _FilterRiwayat.values.map((f) {
            final selected = _filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${f.label} (${hitung(f)})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _navy,
                  ),
                ),
                selected: selected,
                selectedColor: _accent,
                backgroundColor: const Color(0xFFF3F6F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: selected ? _accent : const Color(0xFFE0E7EE),
                  ),
                ),
                onSelected: (_) => setState(() => _filter = f),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text(
          'Belum ada riwayat pengaduan.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildCard(Pengaduan p) {
    final pelapor = p.anonim ? 'Anonim' : p.namaPegawai;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        final id = p.supabaseId;
        if (id == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PengaduanDetailScreen(user: widget.user, pengaduanId: id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                      p.nomorPengaduan,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.status.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.status.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                p.judul,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Pelapor: $pelapor',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                'Kategori: ${p.kategori} \u00b7 ${formatTanggalJam(p.tanggalPengaduan)}',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 15, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Ketuk untuk lihat detail & alur status',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
