import 'package:flutter/material.dart';
import '../../models/cuti_service.dart';
import '../../models/user_role.dart';
import '../../widgets/feature_scaffold.dart';
import '../../widgets/role_guard.dart';
import '../pegawai/pengajuan_cuti_screen.dart';

/// PERSETUJUAN CUTI PEGAWAI (sisi approver: SDM & Direktur).
/// Menggunakan kembali [CutiTabView] sehingga filter Tahun/Status,
/// pencarian pegawai, edit status dengan catatan approver,
/// dan cetak Surat Izin Cuti Resmi tetap konsisten dengan modul web.
class PersetujuanCutiScreen extends StatelessWidget {
  final AppUser user;
  const PersetujuanCutiScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      user: user,
      allowedRoles: CutiService.roleApprover,
      child: FeatureScaffold(
        title: 'Persetujuan Cuti',
        subtitle: 'Setujui / tolak pengajuan & kelola surat cuti pegawai',
        icon: Icons.fact_check_rounded,
        child: CutiTabView(
          user: user,
          manageAll: true,
          initialStatusFilter: 'PENDING',
        ),
      ),
    );
  }
}
