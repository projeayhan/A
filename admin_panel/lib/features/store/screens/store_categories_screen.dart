import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../food/services/food_admin_service.dart';

class StoreCategoriesScreen extends ConsumerStatefulWidget {
  const StoreCategoriesScreen({super.key});

  @override
  ConsumerState<StoreCategoriesScreen> createState() => _StoreCategoriesScreenState();
}

class _StoreCategoriesScreenState extends ConsumerState<StoreCategoriesScreen> {
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(storeCategoriesProvider);

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
                      'Magaza Kategorileri',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Surukleyerek siralama degistirin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isReordering)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(storeCategoriesProvider),
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
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 40), // drag handle
                  SizedBox(width: 60, child: Text('Resim', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13))),
                  SizedBox(width: 12),
                  SizedBox(width: 36, child: Text('Renk', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13))),
                  SizedBox(width: 12),
                  Expanded(child: Text('Kategori Adi', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13))),
                  SizedBox(width: 80, child: Text('Magaza', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center)),
                  SizedBox(width: 50, child: Text('Sira', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center)),
                  SizedBox(width: 70, child: Text('Durum', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center)),
                  SizedBox(width: 100, child: Text('Islemler', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) => _buildReorderableList(categories),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableList(List<StoreCategory> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henuz kategori yok', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        itemCount: categories.length,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surfaceLight,
              child: child,
            ),
            child: child,
          );
        },
        onReorder: (oldIndex, newIndex) => _onReorder(categories, oldIndex, newIndex),
        itemBuilder: (context, index) {
          final c = categories[index];
          return _buildCategoryRow(c, index, key: ValueKey(c.id));
        },
      ),
    );
  }

  Widget _buildCategoryRow(StoreCategory category, int index, {required Key key}) {
    final color = _parseColor(category.color);

    return Container(
      key: key,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: const MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator, color: AppColors.textMuted, size: 20),
              ),
            ),
          ),
          // Image
          Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      category.imageUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(_getIconData(category.iconName), color: color, size: 26),
                    ),
                  )
                : Icon(_getIconData(category.iconName), color: color, size: 26),
          ),
          // Color
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
          ),
          // Name
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Store count
          SizedBox(
            width: 80,
            child: Text(
              category.storeCount.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          // Sort order
          SizedBox(
            width: 50,
            child: Text(
              category.sortOrder.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          // Status
          SizedBox(
            width: 70,
            child: Center(child: _buildStatusBadge(category.isActive)),
          ),
          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _showCategoryDialog(category: category),
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Duzenle',
                  color: AppColors.info,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  onPressed: () => _deleteCategory(category),
                  icon: const Icon(Icons.delete, size: 20),
                  tooltip: 'Sil',
                  color: AppColors.error,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onReorder(List<StoreCategory> categories, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;

    final ids = categories.map((c) => c.id).toList();
    final movedId = ids.removeAt(oldIndex);
    ids.insert(newIndex, movedId);

    setState(() => _isReordering = true);

    try {
      final service = ref.read(foodAdminServiceProvider);
      await service.reorderStoreCategories(ids);
      ref.invalidate(storeCategoriesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Siralama hatasi: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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

  static const _colorOptions = [
    {'name': 'Mavi', 'value': '#3B82F6'},
    {'name': 'Pembe', 'value': '#EC4899'},
    {'name': 'Yesil', 'value': '#10B981'},
    {'name': 'Sari', 'value': '#F59E0B'},
    {'name': 'Mor', 'value': '#8B5CF6'},
    {'name': 'Kirmizi', 'value': '#EF4444'},
    {'name': 'Lacivert', 'value': '#6366F1'},
    {'name': 'Turuncu', 'value': '#F97316'},
    {'name': 'Cyan', 'value': '#06B6D4'},
    {'name': 'Lime', 'value': '#84CC16'},
  ];

  void _showCategoryDialog({StoreCategory? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final sortOrderController = TextEditingController(text: (category?.sortOrder ?? 0).toString());
    String selectedColor = category?.color ?? '#3B82F6';
    String selectedIcon = category?.iconName ?? 'electronics';
    bool isActive = category?.isActive ?? true;

    String? currentImageUrl = category?.imageUrl;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Kategori Duzenle' : 'Yeni Kategori Ekle'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Kategori Adi *',
                      hintText: 'Orn: Elektronik, Giyim, Kozmetik',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Image Upload
                  const Text('Kategori Resmi:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _parseColor(selectedColor).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: selectedImageBytes != null
                              ? Image.memory(selectedImageBytes!, width: 80, height: 80, fit: BoxFit.cover)
                              : currentImageUrl != null && currentImageUrl!.isNotEmpty
                                  ? Image.network(
                                      currentImageUrl!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        _getIconData(selectedIcon),
                                        color: _parseColor(selectedColor),
                                        size: 36,
                                      ),
                                    )
                                  : Icon(
                                      _getIconData(selectedIcon),
                                      color: _parseColor(selectedColor),
                                      size: 36,
                                    ),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                              label: const Text('Resim Sec'),
                            ),
                            if (selectedImageBytes != null || (currentImageUrl != null && currentImageUrl!.isNotEmpty))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextButton.icon(
                                  onPressed: isUploading
                                      ? null
                                      : () => setDialogState(() {
                                            selectedImageBytes = null;
                                            selectedImageName = null;
                                            currentImageUrl = null;
                                          }),
                                  icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                                  label: const Text('Resmi Kaldir', style: TextStyle(color: AppColors.error, fontSize: 13)),
                                ),
                              ),
                            if (selectedImageName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(selectedImageName!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                              ),
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('Otomatik 200x200 kare kirpilir', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Color picker
                  const Text('Arka Plan Rengi:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorOptions.map((opt) {
                      final isSelected = selectedColor == opt['value'];
                      final c = _parseColor(opt['value']);
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = opt['value']!),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)] : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Preview
                  const Text('Uygulamada Gorunum:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _parseColor(selectedColor).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: selectedImageBytes != null
                                ? Image.memory(selectedImageBytes!, width: 64, height: 64, fit: BoxFit.cover)
                                : currentImageUrl != null && currentImageUrl!.isNotEmpty
                                    ? Image.network(currentImageUrl!, width: 64, height: 64, fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Icon(_getIconData(selectedIcon), color: _parseColor(selectedColor), size: 32))
                                    : Icon(_getIconData(selectedIcon), color: _parseColor(selectedColor), size: 32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nameController.text.isEmpty ? 'Kategori' : nameController.text,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: sortOrderController,
                    decoration: const InputDecoration(labelText: 'Sira', hintText: 'Surukleyerek de degistirebilirsiniz'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    subtitle: const Text('Pasif kategoriler uygulamada gorunmez'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (isUploading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 12),
                          Text('Resim yukleniyor...', style: TextStyle(color: AppColors.textMuted)),
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
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (nameController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kategori adi zorunludur')),
                        );
                        return;
                      }

                      final service = ref.read(foodAdminServiceProvider);
                      String? imageUrl = currentImageUrl;

                      try {
                        if (selectedImageBytes != null && selectedImageName != null) {
                          setDialogState(() => isUploading = true);
                          imageUrl = await service.uploadStoreCategoryImage(
                            selectedImageBytes!,
                            selectedImageName!,
                          );
                        }

                        final data = {
                          'name': nameController.text,
                          'icon_name': selectedIcon,
                          'color': selectedColor,
                          'image_url': imageUrl,
                          'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                          'is_active': isActive,
                        };

                        if (isEdit) {
                          await service.updateStoreCategory(category.id, data);
                        } else {
                          await service.createStoreCategory(data);
                        }
                        ref.invalidate(storeCategoriesProvider);
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
              child: Text(isEdit ? 'Guncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(StoreCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Sil'),
        content: Text('"${category.name}" kategorisini silmek istediginize emin misiniz?\n\n'
            'Bu kategorideki magazalar kategorisiz kalacaktir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Iptal')),
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
        await service.deleteStoreCategory(category.id);
        ref.invalidate(storeCategoriesProvider);
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

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF3B82F6);
    String colorStr = hex.replaceFirst('#', '');
    if (colorStr.length == 6) colorStr = 'FF$colorStr';
    return Color(int.parse(colorStr, radix: 16));
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'electronics':
      case 'devices':
        return Icons.devices_rounded;
      case 'fashion':
      case 'checkroom':
        return Icons.checkroom_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'beauty':
      case 'spa':
        return Icons.spa_rounded;
      case 'sports':
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'books':
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'toys':
        return Icons.toys_rounded;
      case 'grocery':
        return Icons.local_grocery_store_rounded;
      case 'jewelry':
        return Icons.diamond_rounded;
      case 'pet':
        return Icons.pets_rounded;
      case 'automotive':
        return Icons.directions_car_rounded;
      case 'garden':
        return Icons.yard_rounded;
      case 'watch':
        return Icons.watch_rounded;
      case 'face':
        return Icons.face_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
