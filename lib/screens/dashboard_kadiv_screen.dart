import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../models/pengaduan_model.dart';
import '../models/user_role.dart';
import '../widgets/role_guard.dart';
import '../widgets/notification_bell.dart';
import 'detail_pengaduan_screen.dart';

/// Dashboard untuk role Kadiv Kategori — Tahap 3 & Tahap 4 (fungsional).
///
/// Tugas Kadiv pada flowchart: menentukan kategori pengaduan (Dev Admin /
/// Dev Teknis), melakukan verifikasi awal, lalu meneruskan ke KSPI.
class DashboardKadivScreen extends StatefulWidget {
  final AppUser user;
  const DashboardKadivScreen({super.key, required this.user});

  @override
  State<DashboardKadivScreen> createState() => _DashboardKadivScreenState();
}

class _DashboardKadivScreenState extends State<DashboardKadivScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message, Color color) {
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

  Future<void> _bukaVerifikasi(Pengaduan p) async {
    KategoriDivisi kategoriDipilih = KategoriDivisi.devAdmin;
    final catatanController = TextEditingController();

    final konfirmasi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Text('Verifikasi & Kategorisasi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(p.nomorPengaduan,
                        style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Text('Kategori Divisi',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: KategoriDivisi.values.map((k) {
                        final selected = kategoriDipilih == k;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(k.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: selected ? Colors.white : _navy,
                                    fontWeight: FontWeight.w600,
                                  )),
                              selected: selected,
                              selectedColor: _accent,
                              onSelected: (_) =>
                                  setSheetState(() => kategoriDipilih = k),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: catatanController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Catatan verifikasi (opsional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Verifikasi & Teruskan ke KSPI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (konfirmasi == true) {
      setState(() {
        p.verifikasiKadiv(
          oleh: widget.user.name,
          kategoriDivisiBaru: kategoriDipilih,
          catatan: catatanController.text.trim().isEmpty
              ? null
              : catatanController.text.trim(),
        );
      });
      NotificationCenter.tambah(
        untukRole: UserRole.kspi,
        judul: 'Pengaduan diteruskan dari Kadiv',
        pesan: '${p.nomorPengaduan} sudah diverifikasi & menunggu review KSPI.',
      );
      if (mounted) {
        _showSnack(
          '${p.nomorPengaduan} diverifikasi & diteruskan ke KSPI.',
          const Color(0xFF27AE60),
        );
      }
    }
  }

  Future<void> _bukaSelesaikanTindakLanjut(Pengaduan p) async {
    final catatanController = TextEditingController();

    final konfirmasi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const Text('Selesaikan Tindak Lanjut',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(p.nomorPengaduan, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF3F6F9), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Instruksi Direktur',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7F8C8D))),
                      const SizedBox(height: 4),
                      Text(p.tindakLanjutDiminta ?? '-', style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: catatanController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Keterangan penyelesaian (opsional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Tandai Selesai'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8449),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (konfirmasi == true) {
      setState(() {
        p.selesaikanTindakLanjut(
          oleh: widget.user.name,
          role: UserRole.kadivKategori,
          catatan: catatanController.text.trim().isEmpty ? null : catatanController.text.trim(),
        );
      });
      NotificationCenter.tambah(
        untukRole: UserRole.pegawai,
        judul: 'Pengaduan selesai',
        pesan: '${p.nomorPengaduan} — tindak lanjut telah dijalankan & dinyatakan selesai.',
      );
      if (mounted) {
        _showSnack('${p.nomorPengaduan} ditandai selesai.', const Color(0xFF27AE60));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semua = PengaduanRepository.untukRole(UserRole.kadivKategori);
    final menungguVerifikasi =
        semua.where((p) => p.status == PengaduanStatus.menungguVerifikasiKadiv).toList();
    final tindakLanjut = semua.where((p) => p.status == PengaduanStatus.tindakLanjut).toList();

    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.kadivKategori],
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F9),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('Dashboard Kadiv Kategori'),
          actions: [
            const NotificationBell(role: UserRole.kadivKategori),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Keluar',
              onPressed: _logout,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeaderCard(semua.length),
              const SizedBox(height: 20),
              const Text(
                'PENGADUAN MASUK — MENUNGGU VERIFIKASI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              const SizedBox(height: 10),
              if (menungguVerifikasi.isEmpty)
                _buildEmptyState('Tidak ada pengaduan yang menunggu verifikasi.')
              else
                ...menungguVerifikasi.map((p) => _buildPengaduanCard(
                      p,
                      tombolLabel: 'Verifikasi',
                      onAksi: () => _bukaVerifikasi(p),
                    )),
              const SizedBox(height: 20),
              const Text(
                'TINDAK LANJUT DARI DIREKTUR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF7F8C8D),
                ),
              ),
              const SizedBox(height: 10),
              if (tindakLanjut.isEmpty)
                _buildEmptyState('Tidak ada tindak lanjut yang ditugaskan.')
              else
                ...tindakLanjut.map((p) => _buildPengaduanCard(
                      p,
                      tombolLabel: 'Selesaikan',
                      onAksi: () => _bukaSelesaikanTindakLanjut(p),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(int jumlahMasuk) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Text(
              widget.user.initials,
              style: const TextStyle(
                color: _navy,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.user.role.label} · ${widget.user.jabatan}',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('$jumlahMasuk',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Masuk',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildPengaduanCard(
    Pengaduan p, {
    required String tombolLabel,
    required VoidCallback onAksi,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
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
                  child: Text(p.nomorPengaduan,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _accent)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.status.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.status.label,
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700, color: p.status.color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.judul,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Pelapor: ${p.namaPegawai}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text('Kategori: ${p.kategori} · ${formatTanggalJam(p.tanggalPengaduan)}',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPengaduanScreen(pengaduan: p),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Detail', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAksi,
                    icon: const Icon(Icons.fact_check_rounded, size: 16),
                    label: Text(tombolLabel, style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}