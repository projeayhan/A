import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../services/food_admin_service.dart';

class RestaurantCategoriesScreen extends ConsumerStatefulWidget {
  const RestaurantCategoriesScreen({super.key});

  @override
  ConsumerState<RestaurantCategoriesScreen> createState() => _RestaurantCategoriesScreenState();
}

class _RestaurantCategoriesScreenState extends ConsumerState<RestaurantCategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(restaurantCategoriesProvider);

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
                      'Restoran Kategorileri',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Yemek siparişi için restoran kategorilerini yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(restaurantCategoriesProvider),
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

  Widget _buildCategoriesTable(List<RestaurantCategory> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: AppColors.textMuted),
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
            DataColumn(label: Text('Resim')),
            DataColumn(label: Text('Kategori Adı')),
            DataColumn(label: Text('İkon')),
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlemler')),
          ],
          rows: categories.map((category) => _buildCategoryRow(category)).toList(),
        ),
      ),
    );
  }

  DataRow _buildCategoryRow(RestaurantCategory category) {
    return DataRow(
      cells: [
        DataCell(
          category.imageUrl != null && category.imageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    category.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image_not_supported, color: AppColors.textMuted),
                    ),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, color: AppColors.textMuted),
                ),
        ),
        DataCell(Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(category.icon ?? '-')),
        DataCell(Text(category.sortOrder.toString())),
        DataCell(_buildStatusBadge(category.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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

  void _showCategoryDialog({RestaurantCategory? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final sortOrderController = TextEditingController(text: (category?.sortOrder ?? 0).toString());
    String selectedIcon = category?.icon ?? 'restaurant';
    bool isActive = category?.isActive ?? true;

    // Image state
    String? currentImageUrl = category?.imageUrl;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isUploading = false;

    final iconOptions = [
      {'name': 'restaurant', 'icon': Icons.restaurant},
      {'name': 'lunch_dining', 'icon': Icons.lunch_dining},
      {'name': 'local_pizza', 'icon': Icons.local_pizza},
      {'name': 'kebab_dining', 'icon': Icons.kebab_dining},
      {'name': 'ramen_dining', 'icon': Icons.ramen_dining},
      {'name': 'eco', 'icon': Icons.eco},
      {'name': 'local_cafe', 'icon': Icons.local_cafe},
      {'name': 'icecream', 'icon': Icons.icecream},
      {'name': 'bakery_dining', 'icon': Icons.bakery_dining},
      {'name': 'set_meal', 'icon': Icons.set_meal},
      {'name': 'fastfood', 'icon': Icons.fastfood},
      {'name': 'coffee', 'icon': Icons.coffee},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Kategori Düzenle' : 'Yeni Kategori Ekle'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Adı *',
                      hintText: 'Örn: Burger, Pizza, Kebap',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Upload Section
                  const Text('Kategori Resmi:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Image Preview
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: selectedImageBytes != null
                              ? Image.memory(
                                  selectedImageBytes!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                )
                              : currentImageUrl != null && currentImageUrl!.isNotEmpty
                                  ? Image.network(
                                      currentImageUrl!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.image_not_supported,
                                        color: AppColors.textMuted,
                                        size: 40,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image,
                                      color: AppColors.textMuted,
                                      size: 40,
                                    ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Upload Buttons
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: isUploading
                                  ? null
                                  : () async {
                                      final result = await FilePicker.platform.pickFiles(
                                        type: FileType.image,
                                        allowMultiple: false,
                                        withData: true,
                                      );
                                      if (result != null && result.files.isNotEmpty) {
                                        final file = result.files.first;
                                        if (file.bytes != null) {
                                          setDialogState(() {
                                            selectedImageBytes = file.bytes;
                                            selectedImageName = file.name;
                                          });
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.upload, size: 18),
                              label: const Text('Resim Seç'),
                            ),
                            const SizedBox(height: 8),
                            if (selectedImageBytes != null || (currentImageUrl != null && currentImageUrl!.isNotEmpty))
                              TextButton.icon(
                                onPressed: isUploading
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          selectedImageBytes = null;
                                          selectedImageName = null;
                                          currentImageUrl = null;
                                        });
                                      },
                                icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                                label: const Text('Resmi Kaldır', style: TextStyle(color: AppColors.error)),
                              ),
                            if (selectedImageName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  selectedImageName!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 4),
                            const Text(
                              'Maks. 5MB, JPG/PNG/GIF/WebP\nOtomatik 400x400 boyutlandırılır',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  TextField(
                    controller: sortOrderController,
                    decoration: const InputDecoration(
                      labelText: 'Sıra',
                      hintText: '0, 1, 2...',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    subtitle: const Text('Pasif kategoriler uygulamada görünmez'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Loading indicator
                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Resim yükleniyor...', style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kategori adı zorunludur')),
                        );
                        return;
                      }

                      final service = ref.read(foodAdminServiceProvider);
                      String? imageUrl = currentImageUrl;

                      try {
                        // Upload new image if selected
                        if (selectedImageBytes != null && selectedImageName != null) {
                          setDialogState(() => isUploading = true);
                          imageUrl = await service.uploadCategoryImage(
                            selectedImageBytes!,
                            selectedImageName!,
                          );
                        }

                        final data = {
                          'name': nameController.text,
                          'image_url': imageUrl,
                          'icon': selectedIcon,
                          'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                          'is_active': isActive,
                        };

                        if (isEdit) {
                          await service.updateRestaurantCategory(category.id, data);
                        } else {
                          await service.createRestaurantCategory(data);
                        }
                        ref.invalidate(restaurantCategoriesProvider);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isUploading = false);
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

  void _deleteCategory(RestaurantCategory category) async {
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
      final service = ref.read(foodAdminServiceProvider);
      try {
        await service.deleteRestaurantCategory(category.id);
        ref.invalidate(restaurantCategoriesProvider);
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
}
