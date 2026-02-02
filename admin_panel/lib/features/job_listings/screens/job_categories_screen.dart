import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/job_listings_admin_service.dart';

class JobCategoriesScreen extends ConsumerStatefulWidget {
  const JobCategoriesScreen({super.key});

  @override
  ConsumerState<JobCategoriesScreen> createState() => _JobCategoriesScreenState();
}

class _JobCategoriesScreenState extends ConsumerState<JobCategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(jobCategoriesProvider);

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
                      'İş Kategorileri',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İş ilanları için kategorileri yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(jobCategoriesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showCategoryDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Kategori Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Table
            Expanded(
              child: categoriesAsync.when(
                data: (categories) => _buildCategoriesTable(categories),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTable(List<JobCategory> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz kategori yok', style: TextStyle(color: AppColors.textMuted)),
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
            DataColumn(label: Text('İkon')),
            DataColumn(label: Text('Kategori Adı')),
            DataColumn(label: Text('Alt Kategoriler')),
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: categories.map((category) => _buildCategoryRow(category)).toList(),
        ),
      ),
    );
  }

  DataRow _buildCategoryRow(JobCategory category) {
    return DataRow(
      cells: [
        DataCell(
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: category.colorValue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(category.iconData, color: category.colorValue, size: 22),
          ),
        ),
        DataCell(Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text('${category.subcategories.length} alt kategori')),
        DataCell(Text(category.sortOrder.toString())),
        DataCell(_buildStatusBadge(category.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showSubcategoriesDialog(category),
                icon: const Icon(Icons.list, size: 20),
                tooltip: 'Alt Kategoriler',
                color: AppColors.primary,
              ),
              IconButton(
                onPressed: () => _showCategoryDialog(category: category),
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Düzenle',
                color: AppColors.info,
              ),
              IconButton(
                onPressed: () => _deleteCategory(category),
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

  void _showCategoryDialog({JobCategory? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final sortOrderController = TextEditingController(text: (category?.sortOrder ?? 0).toString());
    String selectedIcon = category?.icon ?? 'work';
    String selectedColor = category?.color ?? '#6366F1';
    bool isActive = category?.isActive ?? true;

    final iconOptions = [
      {'name': 'work', 'icon': Icons.work},
      {'name': 'computer', 'icon': Icons.computer},
      {'name': 'health_and_safety', 'icon': Icons.health_and_safety},
      {'name': 'school', 'icon': Icons.school},
      {'name': 'restaurant', 'icon': Icons.restaurant},
      {'name': 'shopping_cart', 'icon': Icons.shopping_cart},
      {'name': 'build', 'icon': Icons.build},
      {'name': 'local_shipping', 'icon': Icons.local_shipping},
      {'name': 'account_balance', 'icon': Icons.account_balance},
      {'name': 'engineering', 'icon': Icons.engineering},
      {'name': 'design_services', 'icon': Icons.design_services},
      {'name': 'campaign', 'icon': Icons.campaign},
    ];

    final colorOptions = [
      '#6366F1', '#EC4899', '#10B981', '#F59E0B',
      '#EF4444', '#3B82F6', '#8B5CF6', '#14B8A6',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Kategori Düzenle' : 'Yeni Kategori Ekle'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Kategori Adı *'),
                  ),
                  const SizedBox(height: 16),
                  const Text('İkon Seçin:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: iconOptions.map((opt) {
                      final isSelected = selectedIcon == opt['name'];
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = opt['name'] as String),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                          ),
                          child: Icon(opt['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Renk Seçin:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colorOptions.map((hex) {
                      final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                      final isSelected = selectedColor == hex;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
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
                    const SnackBar(content: Text('Kategori adı zorunludur')),
                  );
                  return;
                }

                final data = {
                  'name': nameController.text,
                  'icon': selectedIcon,
                  'color': selectedColor,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_active': isActive,
                };

                final service = ref.read(jobListingsAdminServiceProvider);
                try {
                  if (isEdit) {
                    await service.updateCategory(category.id, data);
                  } else {
                    await service.createCategory(data);
                  }
                  ref.invalidate(jobCategoriesProvider);
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

  void _showSubcategoriesDialog(JobCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${category.name} - Alt Kategoriler'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showSubcategoryDialog(category.id),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Alt Kategori Ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: category.subcategories.isEmpty
                    ? const Center(
                        child: Text('Henüz alt kategori yok', style: TextStyle(color: AppColors.textMuted)),
                      )
                    : ListView.builder(
                        itemCount: category.subcategories.length,
                        itemBuilder: (context, index) {
                          final sub = category.subcategories[index];
                          return ListTile(
                            title: Text(sub.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showSubcategoryDialog(category.id, subcategory: sub),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                                  onPressed: () => _deleteSubcategory(sub),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showSubcategoryDialog(String categoryId, {JobSubcategory? subcategory}) {
    final isEdit = subcategory != null;
    final nameController = TextEditingController(text: subcategory?.name ?? '');
    final sortOrderController = TextEditingController(text: (subcategory?.sortOrder ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Alt Kategori Düzenle' : 'Yeni Alt Kategori'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Alt Kategori Adı *'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sortOrderController,
                decoration: const InputDecoration(labelText: 'Sıra'),
                keyboardType: TextInputType.number,
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
              if (nameController.text.isEmpty) return;

              final data = {
                'category_id': categoryId,
                'name': nameController.text,
                'sort_order': int.tryParse(sortOrderController.text) ?? 0,
              };

              final service = ref.read(jobListingsAdminServiceProvider);
              try {
                if (isEdit) {
                  await service.updateSubcategory(subcategory.id, data);
                } else {
                  await service.createSubcategory(data);
                }
                ref.invalidate(jobCategoriesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
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
    );
  }

  void _deleteCategory(JobCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Sil'),
        content: Text('"${category.name}" kategorisini silmek istediğinize emin misiniz?'),
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
        await service.deleteCategory(category.id);
        ref.invalidate(jobCategoriesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kategori silindi'), backgroundColor: AppColors.success),
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

  void _deleteSubcategory(JobSubcategory subcategory) async {
    final service = ref.read(jobListingsAdminServiceProvider);
    try {
      await service.deleteSubcategory(subcategory.id);
      ref.invalidate(jobCategoriesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alt kategori silindi'), backgroundColor: AppColors.success),
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
