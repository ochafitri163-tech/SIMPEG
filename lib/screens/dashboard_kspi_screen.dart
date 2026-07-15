import 'package:flutter/material.dart';
import '../login_screen.dart';
import '../models/pengaduan_model.dart';
import '../models/user_role.dart';
import '../widgets/role_guard.dart';
import '../widgets/notification_bell.dart';
import 'detail_pengaduan_screen.dart';

/// Dashboard untuk role KSPI — Tahap 3 & Tahap 4 (fungsional).
///
/// KSPI menangani 4 jenis pekerjaan berbeda tergantung status pengaduan:
/// 1. `reviewKspi`            -> review awal & pilih eksekutor (Kadiv/TPDPK).
/// 2. `menungguReviewKspi`    -> review hasil investigasi dari TPDPK.
/// 3. `ditolakDirektur`       -> revisi lalu kirim ulang ke Direktur.
/// 4. `peninjauanKembali`     -> kirim ulang untuk investigasi ulang.
class DashboardKspiScreen extends StatefulWidget {
  final AppUser user;
  const DashboardKspiScreen({super.key, required this.user});

  @override
  State<DashboardKspiScreen> createState() => _DashboardKspiScreenState();
}

class _DashboardKspiScreenState extends State<DashboardKspiScreen> {
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

  Future<T?> _openSheet<T>(Widget Function(BuildContext, void Function(void Function())) builder) {
    return showModalBottomSheet<T>(
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
            child: builder(ctx, setSheetState),
          ),
        ),
      ),
    );
  }

  Widget _grip() => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
      );

  Widget _judulSheet(String title, Pengaduan p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(p.nomorPengaduan, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
          const SizedBox(height: 16),
        ],
      );

  // ---------- 1. Review awal & pilih eksekutor ----------
  Future<void> _bukaReviewEksekutor(Pengaduan p) async {
    Eksekutor eksekutorDipilih = Eksekutor.kadiv;
    final petugasController = TextEditingController();
    final catatanController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Review & Pilih Eksekutor', p),
            const Text('Eksekutor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: Eksekutor.values.map((e) {
                final selected = eksekutorDipilih == e;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.label,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected ? Colors.white : _navy,
                              fontWeight: FontWeight.w600)),
                      selected: selected,
                      selectedColor: _accent,
                      onSelected: (_) => setSheetState(() => eksekutorDipilih = e),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (eksekutorDipilih == Eksekutor.kadiv) ...[
              const SizedBox(height: 14),
              TextField(
                controller: petugasController,
                decoration: InputDecoration(
                  labelText: 'Nama petugas investigasi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan review (opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (eksekutorDipilih == Eksekutor.kadiv &&
                      petugasController.text.trim().isEmpty) {
                    _showSnack('Nama petugas investigasi wajib diisi.', const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(eksekutorDipilih == Eksekutor.kadiv
                    ? 'Tetapkan Eksekutor & Petugas'
                    : 'Kirim ke TPDPK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok == true) {
      setState(() {
        p.reviewDanPilihEksekutor(
          oleh: widget.user.name,
          eksekutorBaru: eksekutorDipilih,
          petugas: petugasController.text.trim().isEmpty ? null : petugasController.text.trim(),
          catatan: catatanController.text.trim().isEmpty ? null : catatanController.text.trim(),
        );
      });
      NotificationCenter.tambah(
        untukRole: eksekutorDipilih == Eksekutor.kadiv ? UserRole.kadivKategori : UserRole.tpdpk,
        judul: 'Penugasan investigasi baru',
        pesan: '${p.nomorPengaduan} ditugaskan sebagai eksekutor: ${eksekutorDipilih.label}.',
      );
      if (mounted) {
        _showSnack('${p.nomorPengaduan} diteruskan ke ${eksekutorDipilih.label}.', const Color(0xFF27AE60));
      }
    }
  }

  // ---------- 2. Review hasil investigasi dari TPDPK ----------
  Future<void> _bukaReviewHasil(Pengaduan p) async {
    bool sesuai = true;
    final catatanController = TextEditingController();

    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Review Hasil Investigasi', p),
            _infoBlok('Hasil Investigasi', p.hasilInvestigasi ?? '-'),
            const SizedBox(height: 10),
            _infoBlok('Surat Rekomendasi', p.suratRekomendasi ?? '-'),
            const SizedBox(height: 16),
            const Text('Apakah hasil investigasi sudah sesuai?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sesuai', style: TextStyle(fontSize: 12)),
                    selected: sesuai,
                    selectedColor: const Color(0xFF27AE60),
                    labelStyle: TextStyle(color: sesuai ? Colors.white : _navy, fontWeight: FontWeight.w600),
                    onSelected: (_) => setSheetState(() => sesuai = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Belum sesuai', style: TextStyle(fontSize: 12)),
                    selected: !sesuai,
                    selectedColor: const Color(0xFFE74C3C),
                    labelStyle: TextStyle(color: !sesuai ? Colors.white : _navy, fontWeight: FontWeight.w600),
                    onSelected: (_) => setSheetState(() => sesuai = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: sesuai ? 'Catatan untuk Direktur (opsional)' : 'Alasan revisi (wajib)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!sesuai && catatanController.text.trim().isEmpty) {
                    _showSnack('Alasan revisi wajib diisi.', const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: Icon(sesuai ? Icons.send_rounded : Icons.replay_rounded, size: 18),
                label: Text(sesuai ? 'Kirim ke Direktur' : 'Kembalikan untuk Revisi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sesuai ? _navy : const Color(0xFFE74C3C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok == true) {
      setState(() {
        p.reviewHasilInvestigasi(
          oleh: widget.user.name,
          sesuai: sesuai,
          catatan: catatanController.text.trim().isEmpty ? null : catatanController.text.trim(),
        );
      });
      NotificationCenter.tambah(
        untukRole: sesuai ? UserRole.direktur : UserRole.tpdpk,
        judul: sesuai ? 'Menunggu persetujuan Anda' : 'Revisi investigasi diminta',
        pesan: sesuai
            ? '${p.nomorPengaduan} menunggu persetujuan Direktur.'
            : '${p.nomorPengaduan} dikembalikan untuk revisi investigasi.',
      );
      if (mounted) {
        _showSnack(
          sesuai ? '${p.nomorPengaduan} dikirim ke Direktur.' : '${p.nomorPengaduan} dikembalikan untuk revisi.',
          sesuai ? const Color(0xFF27AE60) : const Color(0xFFE67E22),
        );
      }
    }
  }

  // ---------- 3. Revisi setelah penolakan Direktur ----------
  Future<void> _bukaRevisiPenolakan(Pengaduan p) async {
    final catatanController = TextEditingController();
    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Revisi Setelah Penolakan Direktur', p),
            _infoBlok('Alasan Penolakan Direktur', p.alasanPenolakanDirektur ?? '-'),
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan revisi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (catatanController.text.trim().isEmpty) {
                    _showSnack('Catatan revisi wajib diisi.', const Color(0xFFE74C3C));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Kirim Ulang ke Direktur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok == true) {
      setState(() {
        p.kirimUlangSetelahRevisiKspi(oleh: widget.user.name, catatanRevisi: catatanController.text.trim());
      });
      NotificationCenter.tambah(
        untukRole: UserRole.direktur,
        judul: 'Revisi dari KSPI',
        pesan: '${p.nomorPengaduan} dikirim ulang setelah direvisi KSPI.',
      );
      if (mounted) {
        _showSnack('${p.nomorPengaduan} dikirim ulang ke Direktur.', const Color(0xFF27AE60));
      }
    }
  }

  // ---------- 4. Peninjauan kembali dari Direktur ----------
  Future<void> _bukaPeninjauanKembali(Pengaduan p) async {
    final catatanController = TextEditingController();
    final ok = await _openSheet<bool>((ctx, setSheetState) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grip(),
            _judulSheet('Peninjauan Kembali dari Direktur', p),
            _infoBlok('Catatan Direktur', p.catatanPeninjauanKembali ?? '-'),
            const SizedBox(height: 14),
            TextField(
              controller: catatanController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Catatan pengiriman ulang (opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Kirim untuk Investigasi Ulang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    });

    if (ok == true) {
      setState(() {
        p.kirimUntukInvestigasiUlang(
          oleh: widget.user.name,
          catatan: catatanController.text.trim().isEmpty ? null : catatanController.text.trim(),
        );
      });
      NotificationCenter.tambah(
        untukRole: UserRole.tpdpk,
        judul: 'Investigasi ulang diminta',
        pesan: '${p.nomorPengaduan} perlu investigasi ulang (peninjauan kembali Direktur).',
      );
      if (mounted) {
        _showSnack('${p.nomorPengaduan} dikirim untuk investigasi ulang.', const Color(0xFF27AE60));
      }
    }
  }

  Widget _infoBlok(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7F8C8D))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semua = PengaduanRepository.untukRole(UserRole.kspi);
    final reviewAwal = semua.where((p) => p.status == PengaduanStatus.reviewKspi).toList();
    final reviewHasil = semua.where((p) => p.status == PengaduanStatus.menungguReviewKspi).toList();
    final ditolak = semua.where((p) => p.status == PengaduanStatus.ditolakDirektur).toList();
    final peninjauan = semua.where((p) => p.status == PengaduanStatus.peninjauanKembali).toList();

    return RoleGuard(
      user: widget.user,
      allowedRoles: const [UserRole.kspi],
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F9),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('Dashboard KSPI'),
          actions: [
            const NotificationBell(role: UserRole.kspi),
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
              _buildSection('REVIEW AWAL — PILIH EKSEKUTOR', reviewAwal, _bukaReviewEksekutor,
                  'Belum ada pengaduan dari Kadiv.', 'Review'),
              _buildSection('REVIEW HASIL INVESTIGASI', reviewHasil, _bukaReviewHasil,
                  'Belum ada hasil investigasi masuk.', 'Review Hasil'),
              _buildSection('PESAN PENOLAKAN DARI DIREKTUR', ditolak, _bukaRevisiPenolakan,
                  'Tidak ada penolakan dari Direktur.', 'Revisi'),
              _buildSection('PENINJAUAN KEMBALI DARI DIREKTUR', peninjauan, _bukaPeninjauanKembali,
                  'Tidak ada permintaan peninjauan kembali.', 'Tindak Lanjuti'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Pengaduan> items,
    Future<void> Function(Pengaduan) onAksi,
    String emptyText,
    String tombolLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.centerLeft,
            child: Text(emptyText, style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
          )
        else
          ...items.map((p) => _buildPengaduanCard(p, onAksi, tombolLabel)),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildHeaderCard(int jumlah) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_navy, _accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Text(widget.user.initials,
                style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${widget.user.role.label} · ${widget.user.jabatan}',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text('$jumlah', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Perlu Aksi', style: TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPengaduanCard(Pengaduan p, Future<void> Function(Pengaduan) onAksi, String tombolLabel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
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
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _accent)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: p.status.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(p.status.label,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: p.status.color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.judul, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Kategori: ${p.kategori}${p.kategoriDivisi != null ? ' · ${p.kategoriDivisi!.label}' : ''}',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DetailPengaduanScreen(pengaduan: p)),
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
                  child: ElevatedButton(
                    onPressed: () => onAksi(p),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: Text(tombolLabel, style: const TextStyle(fontSize: 12)),
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
