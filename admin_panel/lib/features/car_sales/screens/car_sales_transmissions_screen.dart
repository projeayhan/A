import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/car_sales_admin_service.dart';

class CarSalesTransmissionsScreen extends ConsumerStatefulWidget {
  const CarSalesTransmissionsScreen({super.key});

  @override
  ConsumerState<CarSalesTransmissionsScreen> createState() => _CarSalesTransmissionsScreenState();
}

class _CarSalesTransmissionsScreenState extends ConsumerState<CarSalesTransmissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(carTransmissionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vites Tipleri',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Araç vites tiplerini ekleyin ve düzenleyin (Otomatik, Manuel vb.)',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(carTransmissionsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Vites Tipi Ekle'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: typesAsync.when(
                data: (types) => _buildTable(types),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<CarTransmission> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz vites tipi yok', style: TextStyle(color: AppColors.textMuted)),
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
          columnSpacing: 32,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Ad')),
            DataColumn(label: Text('İkon')),
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: items.map((item) => _buildRow(item)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(CarTransmission item) {
    return DataRow(
      cells: [
        DataCell(Text(item.id, style: const TextStyle(fontFamily: 'monospace'))),
        DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconData(item.icon), size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(item.icon ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        DataCell(Text(item.sortOrder.toString())),
        DataCell(_buildStatusBadge(item.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showDialog(item: item),
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Düzenle',
                color: AppColors.info,
              ),
              IconButton(
                onPressed: () => _delete(item),
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

  IconData _getIconData(String? iconName) {
    const iconMap = {
      'settings': Icons.settings,
      'settings_applications': Icons.settings_applications,
      'tune': Icons.tune,
    };
    return iconMap[iconName] ?? Icons.settings;
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

  void _showDialog({CarTransmission? item}) {
    final isEdit = item != null;
    final idController = TextEditingController(text: item?.id ?? '');
    final nameController = TextEditingController(text: item?.name ?? '');
    final iconController = TextEditingController(text: item?.icon ?? 'settings');
    final sortOrderController = TextEditingController(text: (item?.sortOrder ?? 0).toString());
    bool isActive = item?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Vites Tipi Düzenle' : 'Yeni Vites Tipi Ekle'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'ID *',
                      hintText: 'automatic, manual, semi_automatic',
                    ),
                    enabled: !isEdit,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ad *'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: iconController.text.isNotEmpty ? iconController.text : null,
                    decoration: const InputDecoration(labelText: 'İkon'),
                    items: const [
                      DropdownMenuItem(value: 'settings', child: Text('⚙️ Otomatik')),
                      DropdownMenuItem(value: 'settings_applications', child: Text('🔧 Manuel')),
                      DropdownMenuItem(value: 'tune', child: Text('🎛️ Yarı Otomatik')),
                    ],
                    onChanged: (v) => iconController.text = v ?? 'settings',
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (idController.text.isEmpty || nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID ve Ad zorunludur')),
                  );
                  return;
                }

                final data = {
                  'id': idController.text.toLowerCase().replaceAll(' ', '_'),
                  'name': nameController.text,
                  'icon': iconController.text,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_active': isActive,
                };

                final service = ref.read(carSalesAdminServiceProvider);
                try {
                  if (isEdit) {
                    await service.updateTransmission(item.id, data);
                  } else {
                    await service.createTransmission(data);
                  }
                  ref.invalidate(carTransmissionsProvider);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
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

  void _delete(CarTransmission item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vites Tipini Sil'),
        content: Text('"${item.name}" vites tipini silmek istediğinize emin misiniz?'),
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
        await service.deleteTransmission(item.id);
        ref.invalidate(carTransmissionsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vites tipi silindi'), backgroundColor: AppColors.success),
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
