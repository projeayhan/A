import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';
import '../../../core/services/supabase_service.dart';

class AdminMenuScreen extends ConsumerStatefulWidget {
  final String merchantId;
  const AdminMenuScreen({super.key, required this.merchantId});

  @override
  ConsumerState<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends ConsumerState<AdminMenuScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync =
        ref.watch(merchantMenuCategoriesProvider(widget.merchantId));
    final itemsAsync =
        ref.watch(merchantMenuItemsProvider(widget.merchantId));

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
                      'Menü Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Menü kategorileri ve öğelerini yönetin',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(
                            merchantMenuCategoriesProvider(widget.merchantId));
                        ref.invalidate(
                            merchantMenuItemsProvider(widget.merchantId));
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showCategoryDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Kategori Ekle'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showMenuItemDialog(
                        categories: categoriesAsync.valueOrNull ?? [],
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Öğe Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content: Categories (left) + Menu Items (right)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories panel
                  SizedBox(
                    width: 300,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Kategoriler',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Divider(
                              color: AppColors.surfaceLight, height: 1),
                          Expanded(
                            child: categoriesAsync.when(
                              data: (categories) =>
                                  _buildCategoriesList(categories),
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (e, _) =>
                                  Center(child: Text('Hata: $e')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Menu Items panel
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Menü Öğeleri',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Divider(
                              color: AppColors.surfaceLight, height: 1),
                          Expanded(
                            child: itemsAsync.when(
                              data: (items) => _buildMenuItemsTable(
                                items,
                                categoriesAsync.valueOrNull ?? [],
                              ),
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (e, _) =>
                                  Center(child: Text('Hata: $e')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList(List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Text(
          'Henüz kategori eklenmemiş',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedCategoryId == category['id'];

        return Container(
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                : null,
          ),
          child: ListTile(
            dense: true,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(
              category['name'] ?? '',
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textPrimary,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              'Sıralama: ${category['sort_order'] ?? 0}',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
            onTap: () {
              setState(() {
                _selectedCategoryId =
                    isSelected ? null : category['id'] as String?;
              });
            },
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textMuted, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  _showCategoryDialog(category: category);
                } else if (value == 'delete') {
                  _deleteCategory(category['id']);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Text('Düzenle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Sil', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItemsTable(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> categories,
  ) {
    // Filter by selected category if any
    final filteredItems = _selectedCategoryId != null
        ? items
            .where((item) => item['category_id'] == _selectedCategoryId)
            .toList()
        : items;

    if (filteredItems.isEmpty) {
      return const Center(
        child: Text(
          'Menü öğesi bulunamadı',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.surfaceLight.withValues(alpha: 0.3)),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columnSpacing: 24,
          columns: const [
            DataColumn(
                label: Text('Ad',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary))),
            DataColumn(
                label: Text('Kategori',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary))),
            DataColumn(
                label: Text('Fiyat',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary))),
            DataColumn(
                label: Text('Durum',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary))),
            DataColumn(
                label: Text('İşlemler',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary))),
          ],
          rows: filteredItems.map((item) {
            final categoryName =
                item['menu_categories']?['name'] ?? 'Kategorisiz';
            final price = (item['price'] as num?)?.toDouble() ?? 0;
            final isAvailable = item['is_available'] as bool? ?? true;

            return DataRow(cells: [
              DataCell(Text(
                item['name'] ?? '',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500),
              )),
              DataCell(Text(
                categoryName,
                style: const TextStyle(color: AppColors.textSecondary),
              )),
              DataCell(Text(
                '${price.toStringAsFixed(2)} \u20BA',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500),
              )),
              DataCell(
                Switch(
                  value: isAvailable,
                  activeThumbColor: AppColors.success,
                  onChanged: (value) => _toggleItemAvailability(
                      item['id'], value),
                ),
              ),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: AppColors.info),
                    tooltip: 'Düzenle',
                    onPressed: () => _showMenuItemDialog(
                      item: item,
                      categories: categories,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete,
                        size: 18, color: AppColors.error),
                    tooltip: 'Sil',
                    onPressed: () => _deleteMenuItem(item['id']),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ==================== Category CRUD ====================

  Future<void> _showCategoryDialog({Map<String, dynamic>? category}) async {
    final isEdit = category != null;
    final nameController =
        TextEditingController(text: category?['name'] ?? '');
    final sortOrderController = TextEditingController(
        text: (category?['sort_order'] ?? 0).toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Kategori Düzenle' : 'Kategori Ekle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Kategori Adı',
                  hintText: 'Örn: Ana Yemekler',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sortOrderController,
                decoration: const InputDecoration(
                  labelText: 'Sıralama',
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEdit ? 'Güncelle' : 'Ekle'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final client = ref.read(supabaseProvider);
    final data = {
      'name': nameController.text.trim(),
      'sort_order': int.tryParse(sortOrderController.text.trim()) ?? 0,
      'merchant_id': widget.merchantId,
    };

    try {
      if (isEdit) {
        await client
            .from('menu_categories')
            .update(data)
            .eq('id', category['id']);
      } else {
        await client.from('menu_categories').insert(data);
      }

      ref.invalidate(merchantMenuCategoriesProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Kategori güncellendi'
                : 'Kategori eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(String categoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kategori Sil'),
        content: const Text(
            'Bu kategoriyi silmek istediğinize emin misiniz? Kategorideki tüm öğeler etkilenecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = ref.read(supabaseProvider);
      await client.from('menu_categories').delete().eq('id', categoryId);
      ref.invalidate(merchantMenuCategoriesProvider(widget.merchantId));
      ref.invalidate(merchantMenuItemsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori silindi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ==================== Menu Item CRUD ====================

  Future<void> _showMenuItemDialog({
    Map<String, dynamic>? item,
    required List<Map<String, dynamic>> categories,
  }) async {
    final isEdit = item != null;
    final nameController =
        TextEditingController(text: item?['name'] ?? '');
    final priceController = TextEditingController(
        text: (item?['price'] as num?)?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: item?['description'] ?? '');
    String? selectedCategoryId =
        item?['category_id'] as String? ?? categories.firstOrNull?['id'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Öğe Düzenle' : 'Öğe Ekle'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Öğe Adı',
                    hintText: 'Örn: Adana Kebap',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                  ),
                  dropdownColor: AppColors.surface,
                  items: categories
                      .map((cat) => DropdownMenuItem<String>(
                            value: cat['id'] as String,
                            child: Text(cat['name'] ?? ''),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategoryId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat (\u20BA)',
                    hintText: '0.00',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Ürün açıklaması...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final client = ref.read(supabaseProvider);
    final data = {
      'name': nameController.text.trim(),
      'category_id': selectedCategoryId,
      'price': double.tryParse(priceController.text.trim()) ?? 0,
      'description': descriptionController.text.trim(),
      'merchant_id': widget.merchantId,
    };

    try {
      if (isEdit) {
        await client
            .from('menu_items')
            .update(data)
            .eq('id', item['id']);
      } else {
        data['is_available'] = true;
        await client.from('menu_items').insert(data);
      }

      ref.invalidate(merchantMenuItemsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isEdit ? 'Öğe güncellendi' : 'Öğe eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleItemAvailability(String itemId, bool value) async {
    try {
      final client = ref.read(supabaseProvider);
      await client
          .from('menu_items')
          .update({'is_available': value}).eq('id', itemId);
      ref.invalidate(merchantMenuItemsProvider(widget.merchantId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteMenuItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğe Sil'),
        content:
            const Text('Bu menü öğesini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = ref.read(supabaseProvider);
      await client.from('menu_items').delete().eq('id', itemId);
      ref.invalidate(merchantMenuItemsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Öğe silindi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
