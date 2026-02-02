import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/car_sales_admin_service.dart';

class CarSalesBrandsScreen extends ConsumerStatefulWidget {
  const CarSalesBrandsScreen({super.key});

  @override
  ConsumerState<CarSalesBrandsScreen> createState() => _CarSalesBrandsScreenState();
}

class _CarSalesBrandsScreenState extends ConsumerState<CarSalesBrandsScreen> {
  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(carBrandsProvider);

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
                      'Araç Markaları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Araç markalarını ekleyin ve düzenleyin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(carBrandsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showBrandDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Marka Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Table
            Expanded(
              child: brandsAsync.when(
                data: (brands) => _buildBrandsTable(brands),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandsTable(List<CarBrand> brands) {
    if (brands.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.branding_watermark, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz marka yok', style: TextStyle(color: AppColors.textMuted)),
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
            DataColumn(label: Text('Logo')),
            DataColumn(label: Text('Marka')),
            DataColumn(label: Text('Ülke')),
            DataColumn(label: Text('Premium')),
            DataColumn(label: Text('Popüler')),
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: brands.map((brand) => _buildBrandRow(brand)).toList(),
        ),
      ),
    );
  }

  DataRow _buildBrandRow(CarBrand brand) {
    return DataRow(
      cells: [
        DataCell(
          brand.logoUrl != null
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.background,
                  ),
                  child: Image.network(brand.logoUrl!, fit: BoxFit.contain),
                )
              : const Icon(Icons.image, color: AppColors.textMuted),
        ),
        DataCell(Text(brand.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(brand.country ?? '-')),
        DataCell(Icon(
          brand.isPremium ? Icons.check_circle : Icons.cancel,
          color: brand.isPremium ? AppColors.success : AppColors.textMuted,
          size: 20,
        )),
        DataCell(Icon(
          brand.isPopular ? Icons.check_circle : Icons.cancel,
          color: brand.isPopular ? AppColors.success : AppColors.textMuted,
          size: 20,
        )),
        DataCell(Text(brand.sortOrder.toString())),
        DataCell(_buildStatusBadge(brand.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showBrandDialog(brand: brand),
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Düzenle',
                color: AppColors.info,
              ),
              IconButton(
                onPressed: () => _deleteBrand(brand),
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

  void _showBrandDialog({CarBrand? brand}) {
    final isEdit = brand != null;
    final nameController = TextEditingController(text: brand?.name ?? '');
    final countryController = TextEditingController(text: brand?.country ?? '');
    final logoUrlController = TextEditingController(text: brand?.logoUrl ?? '');
    final sortOrderController = TextEditingController(text: (brand?.sortOrder ?? 0).toString());
    bool isPremium = brand?.isPremium ?? false;
    bool isPopular = brand?.isPopular ?? false;
    bool isActive = brand?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Marka Düzenle' : 'Yeni Marka Ekle'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Marka Adı *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Ülke'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: logoUrlController,
                    decoration: const InputDecoration(labelText: 'Logo URL'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sortOrderController,
                    decoration: const InputDecoration(labelText: 'Sıra'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Premium Marka'),
                    value: isPremium,
                    onChanged: (v) => setDialogState(() => isPremium = v),
                  ),
                  SwitchListTile(
                    title: const Text('Popüler Marka'),
                    value: isPopular,
                    onChanged: (v) => setDialogState(() => isPopular = v),
                  ),
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
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marka adı zorunludur')),
                  );
                  return;
                }

                final data = {
                  'name': nameController.text,
                  'country': countryController.text.isEmpty ? null : countryController.text,
                  'logo_url': logoUrlController.text.isEmpty ? null : logoUrlController.text,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_premium': isPremium,
                  'is_popular': isPopular,
                  'is_active': isActive,
                };

                final service = ref.read(carSalesAdminServiceProvider);
                try {
                  if (isEdit) {
                    await service.updateBrand(brand.id, data);
                  } else {
                    await service.createBrand(data);
                  }
                  ref.invalidate(carBrandsProvider);
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

  void _deleteBrand(CarBrand brand) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Markayı Sil'),
        content: Text('"${brand.name}" markasını silmek istediğinize emin misiniz?'),
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
        await service.deleteBrand(brand.id);
        ref.invalidate(carBrandsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marka silindi'), backgroundColor: AppColors.success),
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
