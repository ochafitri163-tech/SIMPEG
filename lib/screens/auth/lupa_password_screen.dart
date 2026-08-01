import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// B10 — LUPA PASSWORD.
/// Mengirim email tautan reset password lewat Supabase Auth.
class LupaPasswordScreen extends StatefulWidget {
  const LupaPasswordScreen({super.key});

  @override
  State<LupaPasswordScreen> createState() => _LupaPasswordScreenState();
}

class _LupaPasswordScreenState extends State<LupaPasswordScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  final _emailC = TextEditingController();
  bool _kirim = false;
  bool _terkirim = false;

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _pesan('Masukkan email yang valid.');
      return;
    }
    setState(() => _kirim = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() {
        _kirim = false;
        _terkirim = true;
      });
    } catch (e) {
      setState(() => _kirim = false);
      _pesan('Gagal mengirim email reset: $e');
    }
  }

  void _pesan(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Lupa Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset_rounded,
                  size: 40, color: _accent),
            ).paddingCenter(),
            const SizedBox(height: 20),
            if (_terkirim) ...[
              const Icon(Icons.mark_email_read_rounded,
                  color: Color(0xFF27AE60), size: 40),
              const SizedBox(height: 12),
              Text(
                'Tautan reset password telah dikirim ke '
                '${_emailC.text.trim()}.\nSilakan cek kotak masuk (dan folder spam).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Kembali ke Login'),
              ),
            ] else ...[
              const Text(
                'Masukkan email akun Anda. Kami akan mengirimkan tautan '
                'untuk mengatur ulang password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Color(0xFF7F8C8D)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _kirim ? null : _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _kirim
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Kirim Tautan Reset',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _CenterPad on Widget {
  Widget paddingCenter() => Center(child: this);
}
