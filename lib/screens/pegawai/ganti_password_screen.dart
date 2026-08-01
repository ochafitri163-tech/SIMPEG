import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/feature_scaffold.dart';

/// B10 — GANTI PASSWORD (untuk user yang sedang login).
/// Memakai Supabase Auth updateUser.
class GantiPasswordScreen extends StatefulWidget {
  const GantiPasswordScreen({super.key});

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  static const Color _navy = Color(0xFF0D2C6E);

  final _baruC = TextEditingController();
  final _konfirmasiC = TextEditingController();
  bool _simpan = false;
  bool _lihat1 = false;
  bool _lihat2 = false;

  @override
  void dispose() {
    _baruC.dispose();
    _konfirmasiC.dispose();
    super.dispose();
  }

  Future<void> _simpanPassword() async {
    final baru = _baruC.text;
    final konfirmasi = _konfirmasiC.text;
    if (baru.length < 6) {
      _pesan('Password minimal 6 karakter.');
      return;
    }
    if (baru != konfirmasi) {
      _pesan('Konfirmasi password tidak cocok.');
      return;
    }
    setState(() => _simpan = true);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: baru));
      if (!mounted) return;
      _pesan('Password berhasil diperbarui.');
      Navigator.pop(context);
    } catch (e) {
      setState(() => _simpan = false);
      _pesan('Gagal memperbarui password: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Ganti Password',
      subtitle: 'Perbarui kata sandi akun Anda',
      icon: Icons.password_rounded,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _field(
            controller: _baruC,
            label: 'Password Baru',
            lihat: _lihat1,
            onToggle: () => setState(() => _lihat1 = !_lihat1),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _konfirmasiC,
            label: 'Konfirmasi Password Baru',
            lihat: _lihat2,
            onToggle: () => setState(() => _lihat2 = !_lihat2),
          ),
          const SizedBox(height: 8),
          Text('Minimal 6 karakter.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _simpan ? null : _simpanPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _simpan
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Password',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool lihat,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !lihat,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          icon: Icon(lihat
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded),
          onPressed: onToggle,
        ),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
