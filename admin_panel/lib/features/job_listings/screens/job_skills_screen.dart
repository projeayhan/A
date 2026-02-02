import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/job_listings_admin_service.dart';

class JobSkillsScreen extends ConsumerStatefulWidget {
  const JobSkillsScreen({super.key});

  @override
  ConsumerState<JobSkillsScreen> createState() => _JobSkillsScreenState();
}

class _JobSkillsScreenState extends ConsumerState<JobSkillsScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

  final List<String> _categories = [
    'all',
    'Programlama',
    'Tasarım',
    'Pazarlama',
    'Yönetim',
    'İletişim',
    'Dil',
    'Teknik',
    'Diğer',
  ];

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(jobSkillsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yetenekler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İş ilanlarında kullanılacak yetenekleri yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(jobSkillsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showSkillDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yetenek Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Filters
            _buildFilters(),

            const SizedBox(height: 16),

            // Table
            Expanded(
              child: skillsAsync.when(
                data: (skills) {
                  var filtered = skills;
                  if (_selectedCategory != 'all') {
                    filtered = filtered.where((s) => s.category == _selectedCategory).toList();
                  }
                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered.where((s) =>
                      s.name.toLowerCase().contains(_searchQuery.toLowerCase())
                    ).toList();
                  }
                  return _buildSkillsTable(filtered);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 250,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Yetenek ara...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 24),
          const Text('Kategori:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat == 'all' ? 'Tümü' : cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTable(List<JobSkill> skills) {
    if (skills.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz yetenek yok', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Yetenek Adı')),
            DataColumn(label: Text('Kategori')),
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: skills.map((skill) => _buildSkillRow(skill)).toList(),
        ),
      ),
    );
  }

  DataRow _buildSkillRow(JobSkill skill) {
    return DataRow(
      cells: [
        DataCell(Text(skill.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(_buildCategoryBadge(skill.category)),
        DataCell(Text(skill.sortOrder.toString())),
        DataCell(_buildStatusBadge(skill.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showSkillDialog(skill: skill),
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Düzenle',
                color: AppColors.info,
              ),
              IconButton(
                onPressed: () => _deleteSkill(skill),
                icon: const Icon(Icons.delete, size: 20),
                tooltip: 'Sil',
                color: AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBadge(String? category) {
    if (category == null) return const Text('-');

    Color color;
    switch (category) {
      case 'Programlama':
        color = AppColors.primary;
        break;
      case 'Tasarım':
        color = AppColors.info;
        break;
      case 'Pazarlama':
        color = AppColors.warning;
        break;
      case 'Yönetim':
        color = AppColors.success;
        break;
      case 'İletişim':
        color = const Color(0xFF8B5CF6);
        break;
      case 'Dil':
        color = const Color(0xFFEC4899);
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(category, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showSkillDialog({JobSkill? skill}) {
    final isEdit = skill != null;
    final nameController = TextEditingController(text: skill?.name ?? '');
    final sortOrderController = TextEditingController(text: (skill?.sortOrder ?? 0).toString());
    String? selectedCategory = skill?.category ?? 'Diğer';
    bool isActive = skill?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Yetenek Düzenle' : 'Yeni Yetenek Ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Yetenek Adı *'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: _categories
                      .where((c) => c != 'all')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sortOrderController,
                  decoration: const InputDecoration(labelText: 'Sıra'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yetenek adı zorunludur')),
                  );
                  return;
                }

                final data = {
                  'name': nameController.text,
                  'category': selectedCategory,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_active': isActive,
                };

                final service = ref.read(jobListingsAdminServiceProvider);
                try {
                  if (isEdit) {
                    await service.updateSkill(skill.id, data);
                  } else {
                    await service.createSkill(data);
                  }
                  ref.invalidate(jobSkillsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSkill(JobSkill skill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yetenek Sil'),
        content: Text('"${skill.name}" yeteneğini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(jobListingsAdminServiceProvider);
      try {
        await service.deleteSkill(skill.id);
        ref.invalidate(jobSkillsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yetenek silindi'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
