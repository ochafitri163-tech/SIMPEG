import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/pengaduan_service.dart';
import '../theme/app_colors.dart';

/// Modal Bottom Sheet modern untuk memilih eksekutor (pegawai) oleh KSPI.
///
/// Fitur:
/// - Memilih 1 (single) atau lebih dari 1 (multi-select) eksekutor pegawai.
/// - Pencarian real-time berdasarkan Nama, NIK, Jabatan, & Divisi.
/// - Filter cepat role (Semua / Kadiv / TPDPK / Pegawai).
/// - Setiap item menampilkan Nama lengkap, Jabatan/Divisi, & NIK.

/// Picker single pegawai
Future<PegawaiOption?> showPegawaiPickerSheet({
  required BuildContext context,
  PegawaiOption? selectedPegawai,
  String title = 'Pilih Eksekutor Investigasi',
}) {
  return showModalBottomSheet<PegawaiOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PegawaiPickerContent(
      selectedPegawai: selectedPegawai,
      title: title,
    ),
  );
}

/// Picker multi-select pegawai (bisa memilih lebih dari 1 eksekutor)
Future<List<PegawaiOption>?> showPegawaiMultiPickerSheet({
  required BuildContext context,
  List<PegawaiOption>? selectedPegawaiList,
  String title = 'Pilih Tim Eksekutor Investigasi',
}) {
  return showModalBottomSheet<List<PegawaiOption>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _PegawaiMultiPickerContent(
      initialSelectedList: selectedPegawaiList ?? [],
      title: title,
    ),
  );
}

class _PegawaiPickerContent extends StatefulWidget {
  final PegawaiOption? selectedPegawai;
  final String title;

  const _PegawaiPickerContent({
    this.selectedPegawai,
    required this.title,
  });

  @override
  State<_PegawaiPickerContent> createState() => _PegawaiPickerContentState();
}

class _PegawaiPickerContentState extends State<_PegawaiPickerContent> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  final TextEditingController _searchController = TextEditingController();
  late Future<List<PegawaiOption>> _futurePegawai;

  String _searchQuery = '';
  String _roleFilter = 'EKSEKUTOR'; // 'EKSEKUTOR', 'TPDPK', 'KADIV', 'ALL', 'PEGAWAI'

  @override
  void initState() {
    super.initState();
    _futurePegawai = PengaduanService.fetchDaftarPegawai();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PegawaiOption> _applyFilter(List<PegawaiOption> list) {
    return list.where((p) {
      // 1. Query filter (nama, nik, jabatan, unit kerja)
      final q = _searchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.nik.toLowerCase().contains(q) ||
          p.jabatan.toLowerCase().contains(q) ||
          p.unitKerja.toLowerCase().contains(q);

      // 2. Role filter
      bool matchRole = true;
      if (_roleFilter == 'EKSEKUTOR') {
        matchRole = p.nik == '1711161' ||
            p.nik == '1711251' ||
            p.nik == '1711571' ||
            p.name.toLowerCase().contains('dodi sudrajat') ||
            (p.role ?? '').toLowerCase().contains('kadiv');
      } else if (_roleFilter == 'KADIV') {
        matchRole = (p.role ?? '').toLowerCase().contains('kadiv') ||
            p.nik == '1711251' ||
            p.nik == '1711571';
      } else if (_roleFilter == 'TPDPK') {
        matchRole = p.nik == '1711161' ||
            p.name.toLowerCase().contains('dodi sudrajat') ||
            (p.role ?? '').toLowerCase() == 'tpdpk';
      } else if (_roleFilter == 'PEGAWAI') {
        matchRole = (p.role ?? '').toLowerCase() == 'pegawai' &&
            p.nik != '1711161' &&
            p.nik != '1711251' &&
            p.nik != '1711571';
      }

      return matchQuery && matchRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
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

            // Header Title
            Row(
              children: [
                const Icon(Icons.person_search_rounded,
                    color: _accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
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
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari nama, NIK, atau jabatan...',
                hintStyle: TextStyle(fontSize: 13.5, color: textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E2633)
                    : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips (Role)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Eksekutor Resmi (3)', 'EKSEKUTOR', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('TPDPK (Dodi Sudrajat)', 'TPDPK', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Kadiv SPI (2)', 'KADIV', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Semua Pegawai', 'ALL', isDark),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pegawai Lainnya', 'PEGAWAI', isDark),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // List of Pegawai
            Expanded(
              child: FutureBuilder<List<PegawaiOption>>(
                future: _futurePegawai,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Gagal memuat data pegawai: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final allPegawai = snapshot.data ?? [];
                  final filteredList = _applyFilter(allPegawai);

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_rounded,
                              size: 48, color: textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 10),
                          Text(
                            'Pegawai tidak ditemukan',
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

                  return ListView.separated(
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final isSelected = widget.selectedPegawai?.id == item.id ||
                          widget.selectedPegawai?.nik == item.nik;

                      return Material(
                        color: isSelected
                            ? _accent.withOpacity(0.12)
                            : (isDark
                                ? const Color(0xFF1E2638)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, item),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? _accent
                                    : (isDark
                                        ? const Color(0xFF2C384E)
                                        : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar Circle
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: isSelected
                                      ? _accent
                                      : _navy.withOpacity(0.85),
                                  child: Text(
                                    item.initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Detail Info (Nama, Jabatan/Divisi, NIK)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _accent.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.badgeLabel,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _accent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${item.unitKerja}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'NIK: ${item.nik}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Checkmark Indicator
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: _accent,
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String code, bool isDark) {
    final isSelected = _roleFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _roleFilter = code),
      selectedColor: _accent,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey[300] : Colors.grey[800]),
      ),
      backgroundColor:
          isDark ? const Color(0xFF1E2633) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}

/// Content Stateful Widget untuk Multi-select Pegawai
class _PegawaiMultiPickerContent extends StatefulWidget {
  final List<PegawaiOption> initialSelectedList;
  final String title;

  const _PegawaiMultiPickerContent({
    required this.initialSelectedList,
    required this.title,
  });

  @override
  State<_PegawaiMultiPickerContent> createState() =>
      _PegawaiMultiPickerContentState();
}

class _PegawaiMultiPickerContentState
    extends State<_PegawaiMultiPickerContent> {
  static const Color _navy = Color(0xFF0D2C6E);
  static const Color _accent = Color(0xFF2E86AB);

  final TextEditingController _searchController = TextEditingController();
  late Future<List<PegawaiOption>> _futurePegawai;
  final List<PegawaiOption> _selectedList = [];

  String _searchQuery = '';
  String _roleFilter = 'EKSEKUTOR';

  @override
  void initState() {
    super.initState();
    _selectedList.addAll(widget.initialSelectedList);
    _futurePegawai = PengaduanService.fetchDaftarPegawai();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(PegawaiOption item) {
    setState(() {
      final index = _selectedList.indexWhere((p) => p.id == item.id);
      if (index >= 0) {
        _selectedList.removeAt(index);
      } else {
        _selectedList.add(item);
      }
    });
  }

  List<PegawaiOption> _applyFilter(List<PegawaiOption> list) {
    return list.where((p) {
      final q = _searchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.nik.toLowerCase().contains(q) ||
          p.jabatan.toLowerCase().contains(q) ||
          p.unitKerja.toLowerCase().contains(q);

      bool matchRole = true;
      if (_roleFilter == 'EKSEKUTOR') {
        matchRole = p.nik == '1711161' ||
            p.nik == '1711251' ||
            p.nik == '1711571' ||
            p.name.toLowerCase().contains('dodi sudrajat') ||
            (p.role ?? '').toLowerCase().contains('kadiv');
      } else if (_roleFilter == 'KADIV') {
        matchRole = (p.role ?? '').toLowerCase().contains('kadiv') ||
            p.nik == '1711251' ||
            p.nik == '1711571';
      } else if (_roleFilter == 'TPDPK') {
        matchRole = p.nik == '1711161' ||
            p.name.toLowerCase().contains('dodi sudrajat') ||
            (p.role ?? '').toLowerCase() == 'tpdpk';
      } else if (_roleFilter == 'PEGAWAI') {
        matchRole = (p.role ?? '').toLowerCase() == 'pegawai' &&
            p.nik != '1711161' &&
            p.nik != '1711251' &&
            p.nik != '1711571';
      }

      return matchQuery && matchRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
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
            const SizedBox(height: 14),

            // Header Title
            Row(
              children: [
                const Icon(Icons.group_add_rounded, color: _accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pilih 1 atau beberapa eksekutor sekaligus',
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari nama, NIK, atau jabatan...',
                hintStyle: TextStyle(fontSize: 13.5, color: textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E2633)
                    : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Filter Chips (Role)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('Eksekutor Resmi (3)', 'EKSEKUTOR', isDark),
                  const SizedBox(width: 8),
                  _buildChip('TPDPK (Dodi Sudrajat)', 'TPDPK', isDark),
                  const SizedBox(width: 8),
                  _buildChip('Kadiv SPI (2)', 'KADIV', isDark),
                  const SizedBox(width: 8),
                  _buildChip('Semua Pegawai', 'ALL', isDark),
                  const SizedBox(width: 8),
                  _buildChip('Pegawai Lainnya', 'PEGAWAI', isDark),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // List of Pegawai (Multi-select)
            Expanded(
              child: FutureBuilder<List<PegawaiOption>>(
                future: _futurePegawai,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Gagal memuat data pegawai: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final allPegawai = snapshot.data ?? [];
                  final filteredList = _applyFilter(allPegawai);

                  if (filteredList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_rounded,
                              size: 44, color: textSecondary.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'Pegawai tidak ditemukan',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final isSelected =
                          _selectedList.any((p) => p.id == item.id);

                      return Material(
                        color: isSelected
                            ? _accent.withOpacity(0.12)
                            : (isDark
                                ? const Color(0xFF1E2638)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => _toggleSelection(item),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? _accent
                                    : (isDark
                                        ? const Color(0xFF2C384E)
                                        : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Checkbox Indicator
                                Checkbox(
                                  value: isSelected,
                                  activeColor: _accent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5)),
                                  onChanged: (_) => _toggleSelection(item),
                                ),
                                const SizedBox(width: 4),

                                // Avatar Circle
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isSelected
                                      ? _accent
                                      : _navy.withOpacity(0.85),
                                  child: Text(
                                    item.initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Detail Info (Nama, Jabatan/Divisi, NIK)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _accent.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.badgeLabel,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _accent,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '• ${item.unitKerja}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'NIK: ${item.nik}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Action Bar: Konfirmasi Pilihan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton.icon(
                onPressed: _selectedList.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selectedList),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _selectedList.isEmpty
                      ? 'Pilih Minimal 1 Eksekutor'
                      : 'Simpan Pilihan (${_selectedList.length} Eksekutor)',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF1E2633)
                      : const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String code, bool isDark) {
    final isSelected = _roleFilter == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _roleFilter = code),
      selectedColor: _accent,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey[300] : Colors.grey[800]),
      ),
      backgroundColor:
          isDark ? const Color(0xFF1E2633) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}

