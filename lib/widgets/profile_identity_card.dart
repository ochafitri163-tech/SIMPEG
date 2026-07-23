import 'package:flutter/material.dart';
import '../models/user_role.dart';

/// Kartu identitas pegawai dengan avatar besar di tengah yang "menumpuk"
/// di atas tepi card (overlap), nama, jabatan, dan chip NIK — semuanya
/// tersusun rata tengah. Dipakai di [ProfileScreen] (versi kecil) dan
/// [ProfileDetailScreen] (versi `prominent`, avatar lebih besar).
class ProfileIdentityCard extends StatelessWidget {
  final AppUser user;
  final bool isSmallScreen;
  final bool prominent;

  const ProfileIdentityCard({
    super.key,
    required this.user,
    this.isSmallScreen = false,
    this.prominent = false,
  });

  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _labelDark = Color(0xFF1B2733);
  static const Color _hintGrey = Color(0xFF8B98A9);

  /// Ukuran avatar untuk kombinasi [prominent]/[isSmallScreen] tertentu.
  /// Dipakai juga oleh layar pemanggil (mis. [ProfileDetailScreen]) supaya
  /// jarak overlap avatar ke header dihitung dari nilai yang sama persis
  /// dengan yang dipakai widget ini saat digambar — jadi tidak ada lagi
  /// angka ajaib yang bisa "lari" saat salah satunya diubah.
  static double avatarSizeFor({
    required bool prominent,
    required bool isSmallScreen,
  }) {
    return prominent
        ? (isSmallScreen ? 88.0 : 100.0)
        : (isSmallScreen ? 72.0 : 82.0);
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = avatarSizeFor(
      prominent: prominent,
      isSmallScreen: isSmallScreen,
    );
    final hasPhoto = user.fotoUrl != null && user.fotoUrl!.trim().isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Card putih. Diberi margin-top setengah tinggi avatar supaya
        // avatar bisa "menumpuk" di atas tepi card, sama seperti referensi.
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: avatarSize / 2),
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 16.0 : 20.0,
            avatarSize / 2 + (isSmallScreen ? 10.0 : 14.0),
            isSmallScreen ? 16.0 : 20.0,
            isSmallScreen ? 18.0 : 22.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.10),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${user.name}${user.gelar.isNotEmpty ? ', ${user.gelar}' : ''}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: prominent
                      ? (isSmallScreen ? 16.0 : 18.5)
                      : (isSmallScreen ? 14.5 : 16.0),
                  fontWeight: FontWeight.w800,
                  color: _labelDark,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.jabatan,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: prominent
                      ? (isSmallScreen ? 12.0 : 13.0)
                      : (isSmallScreen ? 11.0 : 12.0),
                  color: _hintGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'NIK ${user.nik}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10.5 : 11.5,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Avatar besar, ditumpuk di atas (menutupi tepi atas card).
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: hasPhoto
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF5B9BD5), Color(0xFF3873B8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: hasPhoto
              ? ClipOval(
                  child: Image.network(
                    user.fotoUrl!,
                    width: avatarSize,
                    height: avatarSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initialsFallback(avatarSize),
                  ),
                )
              : _initialsFallback(avatarSize),
        ),
      ],
    );
  }

  Widget _initialsFallback(double size) {
    return Text(
      user.initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.32,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}