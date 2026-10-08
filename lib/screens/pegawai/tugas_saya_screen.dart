import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../services/task_service.dart';
import '../../widgets/media_lampiran_picker.dart';
import '../../widgets/notification_bell.dart';
import '../../services/theme_controller.dart';
import '../shared/detail_pengaduan_screen.dart';
import '../../theme/app_colors.dart';

/// Halaman "Tugas Saya" — Menampilkan daftar penugasan eksekusi pengaduan
/// yang diberikan oleh KSPI kepada eksekutor (pegawai).
class TugasSayaScreen extends StatefulWidget {
  final AppUser user;
  final bool showBackButton;

  const TugasSayaScreen({
    super.key,
    required this.user,
    this.showBackButton = true,
  });

  @override
  State<TugasSayaScreen> createState() => _TugasSayaScreenState();
}

class _TugasSayaScreenState extends State<TugasSayaScreen> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);
  static const Color _green = Color(0xFF27AE60);
  static const Color _orange = Color(0xFFE67E22);

  late Future<List<TaskModel>> _futureTasks;
  String _statusFilter = 'ALL'; // 'ALL', 'Menunggu', 'Diproses', 'Selesai'

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  void _refreshTasks() {
    setState(() {
      _futureTasks = TaskService.fetchTugasSaya();
    });
  }

  List<TaskModel> _filterTasks(List<TaskModel> list) {
    if (_statusFilter == 'ALL') return list;
    return list
        .where((t) =>
            t.status.label.toLowerCase() == _statusFilter.toLowerCase())
        .toList();
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopActionButtonChild({required Widget child}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 360;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Bar Container Dashboard Style
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                mediaQuery.padding.top + 12,
                16,
                20,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_navy, Color(0xFF1B4998)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.showBackButton) ...[
                        _buildTopActionButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Kembali',
                          onTap: () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 8 : 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.water_drop_rounded,
                                  size: 12,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'PERUMDAM TIRTA DARMA AYU',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.78),
                                      fontSize: isSmallScreen ? 8 : 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.instance.themeMode,
                        builder: (context, mode, _) {
                          final isDark = mode == ThemeMode.dark;
                          return _buildTopActionButton(
                            tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                            onTap: () => ThemeController.instance.setDark(!isDark),
                            icon: isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                          );
                        },
                      ),
                      const SizedBox(width: 7),
                      _buildTopActionButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Muat Ulang',
                        onTap: _refreshTasks,
                      ),
                      const SizedBox(width: 7),
                      _buildTopActionButtonChild(
                        child: IconTheme(
                          data: const IconThemeData(color: Colors.white),
                          child: NotificationBell(
                            role: UserRole.pegawai,
                            user: widget.user,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 14 : 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: isSmallScreen ? 44 : 48,
                          height: isSmallScreen ? 44 : 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.22),
                                Colors.white.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Daftar Penugasan Eksekutor',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Kelola dan perbarui status investigasi pengaduan yang ditugaskan kepada Anda.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter Status Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Semua', 'ALL', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Menunggu', 'Menunggu', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Diproses', 'Diproses', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Selesai', 'Selesai', isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // List of Tasks
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<List<TaskModel>>(
                  future: _futureTasks,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Gagal memuat daftar tugas: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      );
                    }

                    final tasks = snapshot.data ?? [];
                    final filtered = _filterTasks(tasks);

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              size: 54,
                              color: textSecondary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusFilter == 'ALL'
                                  ? 'Belum ada tugas penugasan.'
                                  : 'Tidak ada tugas berstatus "$_statusFilter".',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => _refreshTasks(),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          return _buildTaskCard(task, isDark, textPrimary, textSecondary);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String code, bool isDark) {
    final isSelected = _statusFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = code),
      selectedColor: _navy,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey[300] : Colors.grey[800]),
      ),
      backgroundColor:
          isDark ? const Color(0xFF1E2633) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildTaskCard(
    TaskModel task,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (task.status) {
      case TaskStatus.menunggu:
        statusColor = _orange;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case TaskStatus.diproses:
        statusColor = _accent;
        statusIcon = Icons.autorenew_rounded;
        break;
      case TaskStatus.selesai:
        statusColor = _green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case TaskStatus.dibatalkan:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C384E) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openTaskDetailSheet(task),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Nomor & Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _navy.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.nomorPengaduan ?? 'PGD-TASK',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _navy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            task.status.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Task Title
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // Description snippet
                if ((task.description ?? '').isNotEmpty)
                  Text(
                    task.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textSecondary,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 12),

                // Bottom Meta: Assigner & Action hint
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Penugas: ${task.assignedByName ?? 'KSPI'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: const [
                        Text(
                          'Buka Detail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _accent,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: _accent),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens bottom sheet to view task details and update task status
  Future<void> _openTaskDetailSheet(TaskModel task) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    final catatanController = TextEditingController(text: task.notes ?? '');
    final MediaLampiranController mediaController = MediaLampiranController();
    bool isProcessing = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grip Bar
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title & Close
                      Row(
                        children: [
                          const Icon(Icons.assignment_turned_in_rounded,
                              color: _accent, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Detail Penugasan Task',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Task Info Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2638)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2C384E)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if ((task.category ?? '').isNotEmpty)
                              Text(
                                'Kategori: ${task.category}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _accent,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              task.description ?? '-',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textSecondary,
                                height: 1.3,
                              ),
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Status Saat Ini:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _navy.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    task.status.label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Button to View Full Complaint Detail
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PengaduanDetailScreen(
                                  user: widget.user,
                                  pengaduanId: task.pengaduanId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.description_rounded, size: 18),
                          label: const Text('Lihat Detail Pengaduan Lengkap'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(color: _accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Status Execution Section
                      if (task.status != TaskStatus.selesai &&
                          task.status != TaskStatus.dibatalkan) ...[
                        const Text(
                          'Perbarui Status & Hasil Eksekusi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Form Catatan Hasil
                        TextField(
                          controller: catatanController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Catatan / Hasil Investigasi',
                            hintText:
                                'Tuliskan uraian hasil investigasi & rekomendasi...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Media Lampiran Bukti
                        const Text(
                          'Lampiran Bukti foto & dokumen (Opsional)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        MediaLampiranPicker(
                          controller: mediaController,
                          prefix: 'task_${task.id}',
                        ),
                        const SizedBox(height: 18),

                        // Action Buttons based on current status
                        if (task.status == TaskStatus.menunggu) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isProcessing
                                  ? null
                                  : () async {
                                      setSheetState(() => isProcessing = true);
                                      try {
                                        await TaskService.updateTaskStatus(
                                          taskId: task.id,
                                          pengaduanId: task.pengaduanId,
                                          statusBaru: TaskStatus.diproses,
                                          user: widget.user,
                                          catatan: catatanController.text,
                                        );
                                        if (mounted) {
                                          Navigator.pop(context);
                                          _refreshTasks();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Status tugas diperbarui: Diproses'),
                                              backgroundColor: _accent,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setSheetState(() => isProcessing = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Gagal: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Mulai Proses Tugas'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Complete Task Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () async {
                                    if (catatanController.text
                                        .trim()
                                        .isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Harap isi catatan hasil investigasi terlebih dahulu.'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    setSheetState(() => isProcessing = true);
                                    try {
                                      await TaskService.updateTaskStatus(
                                        taskId: task.id,
                                        pengaduanId: task.pengaduanId,
                                        statusBaru: TaskStatus.selesai,
                                        user: widget.user,
                                        catatan: catatanController.text,
                                        buktiFoto: mediaController.foto,
                                        buktiDokumen: mediaController.dokumen,
                                      );
                                      if (mounted) {
                                        Navigator.pop(context);
                                        _refreshTasks();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Tugas investigasi diselesaikan! Diteruskan ke KSPI.'),
                                            backgroundColor: _green,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setSheetState(() => isProcessing = false);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Gagal: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Tandai Tugas Selesai'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Show existing notes & proofs if completed
                        if ((task.notes ?? '').isNotEmpty) ...[
                          const Text(
                            'Catatan / Hasil Penyelesaian:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _green.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              task.notes!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
