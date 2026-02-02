import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/car_sales_admin_service.dart';

class CarSalesFeaturesScreen extends ConsumerStatefulWidget {
  const CarSalesFeaturesScreen({super.key});

  @override
  ConsumerState<CarSalesFeaturesScreen> createState() => _CarSalesFeaturesScreenState();
}

class _CarSalesFeaturesScreenState extends ConsumerState<CarSalesFeaturesScreen> {
  String _selectedCategory = 'all';

  final List<String> _categories = [
    'all',
    'Güvenlik',
    'Konfor',
    'Multimedya',
    'Dış Donanım',
    'İç Donanım',
    'Diğer',
  ];

  @override
  Widget build(BuildContext context) {
    final featuresAsync = ref.watch(carFeaturesProvider);

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
                      'Araç Özellikleri',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Araçlara eklenebilecek özellikleri yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(carFeaturesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showFeatureDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Özellik Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Category Filter
            _buildCategoryFilter(),

            const SizedBox(height: 16),

            // Table
            Expanded(
              child: featuresAsync.when(
                data: (features) {
                  final filtered = _selectedCategory == 'all'
                      ? features
                      : features.where((f) => f.category == _selectedCategory).toList();
                  return _buildFeaturesTable(filtered);
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

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          const Text('Kategori:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return FilterChip(
                  label: Text(cat == 'all' ? 'Tümü' : cat),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesTable(List<CarFeature> features) {
    if (features.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.featured_play_list_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz özellik yok', style: TextStyle(color: AppColors.textMuted)),
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
            DataColumn(label: Text('Özellik Adı')),
            DataColumn(label: Text('Kategori')),
            DataColumn(label: Text('İkon')),
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: features.map((feature) => _buildFeatureRow(feature)).toList(),
        ),
      ),
    );
  }

  DataRow _buildFeatureRow(CarFeature feature) {
    return DataRow(
      cells: [
        DataCell(Text(feature.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(_buildCategoryBadge(feature.category)),
        DataCell(Text(feature.icon ?? '-')),
        DataCell(Text(feature.sortOrder.toString())),
        DataCell(_buildStatusBadge(feature.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showFeatureDialog(feature: feature),
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Düzenle',
                color: AppColors.info,
              ),
              IconButton(
                onPressed: () => _deleteFeature(feature),
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

  Widget _buildCategoryBadge(String category) {
    Color color;
    switch (category) {
      case 'Güvenlik':
        color = AppColors.error;
        break;
      case 'Konfor':
        color = AppColors.success;
        break;
      case 'Multimedya':
        color = AppColors.info;
        break;
      case 'Dış Donanım':
        color = AppColors.warning;
        break;
      case 'İç Donanım':
        color = AppColors.primary;
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

  void _showFeatureDialog({CarFeature? feature}) {
    final isEdit = feature != null;
    final nameController = TextEditingController(text: feature?.name ?? '');
    final iconController = TextEditingController(text: feature?.icon ?? '');
    final sortOrderController = TextEditingController(text: (feature?.sortOrder ?? 0).toString());
    String selectedCategory = feature?.category ?? 'Diğer';
    bool isActive = feature?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Özellik Düzenle' : 'Yeni Özellik Ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Özellik Adı *'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: _categories
                      .where((c) => c != 'all')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: iconController,
                  decoration: const InputDecoration(labelText: 'İkon (opsiyonel)'),
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
                    const SnackBar(content: Text('Özellik adı zorunludur')),
                  );
                  return;
                }

                final data = {
                  'name': nameController.text,
                  'category': selectedCategory,
                  'icon': iconController.text.isEmpty ? null : iconController.text,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_active': isActive,
                };

                final service = ref.read(carSalesAdminServiceProvider);
                try {
                  if (isEdit) {
                    await service.updateFeature(feature.id, data);
                  } else {
                    await service.createFeature(data);
                  }
                  ref.invalidate(carFeaturesProvider);
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

  void _deleteFeature(CarFeature feature) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özelliği Sil'),
        content: Text('"${feature.name}" özelliğini silmek istediğinize emin misiniz?'),
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
      final service = ref.read(carSalesAdminServiceProvider);
      try {
        await service.deleteFeature(feature.id);
        ref.invalidate(carFeaturesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Özellik silindi'), backgroundColor: AppColors.success),
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
