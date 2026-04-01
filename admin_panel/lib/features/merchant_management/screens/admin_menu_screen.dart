import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';
import '../../../core/services/supabase_service.dart';

class AdminMenuScreen extends ConsumerStatefulWidget {
  final String merchantId;
  const AdminMenuScreen({super.key, required this.merchantId});

  @override
  ConsumerState<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends ConsumerState<AdminMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategoryFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  bottom: BorderSide(color: AppColors.surfaceLight)),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Ürünler', icon: Icon(Icons.fastfood, size: 20)),
                Tab(
                    text: 'Kategoriler',
                    icon: Icon(Icons.category, size: 20)),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildProductsTab(), _buildCategoriesTab()],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== PRODUCTS TAB =====================
  Widget _buildProductsTab() {
    final itemsAsync =
        ref.watch(merchantMenuItemsProvider(widget.merchantId));
    final categoriesAsync =
        ref.watch(merchantMenuCategoriesProvider(widget.merchantId));

    return Column(
      children: [
        // Header with search, filter, actions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
                bottom: BorderSide(color: AppColors.surfaceLight)),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Ürün ara...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Category Filter
              categoriesAsync.when(
                data: (cats) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCategoryFilter,
                    hint: const Text('Kategori'),
                    underline: const SizedBox(),
                    dropdownColor: AppColors.surface,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tüm Kategoriler'),
                      ),
                      ...cats.map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['name'] ?? ''),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedCategoryFilter = v),
                  ),
                ),
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
              const SizedBox(width: 16),
              // Refresh
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(
                      merchantMenuItemsProvider(widget.merchantId));
                  ref.invalidate(
                      merchantMenuCategoriesProvider(widget.merchantId));
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yenile'),
              ),
              const SizedBox(width: 8),
              // Add Button
              ElevatedButton.icon(
                onPressed: () => _showMenuItemDialog(
                  categories: categoriesAsync.valueOrNull ?? [],
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Ürün Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        // Grid View
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              var filtered = items;
              if (_selectedCategoryFilter != null) {
                filtered = items
                    .where(
                        (i) => i['category_id'] == _selectedCategoryFilter)
                    .toList();
              }
              if (_searchQuery.isNotEmpty) {
                filtered = filtered
                    .where((i) => (i['name'] as String? ?? '')
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu,
                          size: 80, color: AppColors.textMuted),
                      const SizedBox(height: 24),
                      Text('Menü boş',
                          style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('İlk ürünü ekleyerek menüyü oluşturmaya başlayın',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _MenuItemCard(
                    item: item,
                    onEdit: () => _showMenuItemDialog(
                      item: item,
                      categories: categoriesAsync.valueOrNull ?? [],
                    ),
                    onToggleAvailability: () => _toggleItemAvailability(
                      item['id'],
                      !(item['is_available'] as bool? ?? true),
                    ),
                    onDelete: () => _deleteMenuItem(item['id']),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }

  // ===================== CATEGORIES TAB =====================
  Widget _buildCategoriesTab() {
    final categoriesAsync =
        ref.watch(merchantMenuCategoriesProvider(widget.merchantId));

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
                bottom: BorderSide(color: AppColors.surfaceLight)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kategoriler',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.drag_indicator,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Sıralama için sürükleyip bırakın',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Kategori Ekle'),
              ),
            ],
          ),
        ),
        // Categories List
        Expanded(
          child: categoriesAsync.when(
            data: (cats) {
              if (cats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category,
                          size: 80, color: AppColors.textMuted),
                      const SizedBox(height: 24),
                      const Text('Henüz kategori yok',
                          style: TextStyle(
                              fontSize: 18,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      Text('Ürünlerinizi gruplamak için kategori oluşturun',
                          style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showCategoryDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Kategori Ekle'),
                      ),
                    ],
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cats.length,
                onReorderItem: (oldIndex, newIndex) async {
                  final reordered = List<Map<String, dynamic>>.from(cats);
                  final moved = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, moved);
                  // Update sort_order in DB
                  final client = ref.read(supabaseProvider);
                  for (int i = 0; i < reordered.length; i++) {
                    await client
                        .from('menu_categories')
                        .update({'sort_order': i}).eq(
                            'id', reordered[i]['id']);
                  }
                  ref.invalidate(
                      merchantMenuCategoriesProvider(widget.merchantId));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kategori sırası güncellendi'),
                        duration: Duration(seconds: 1),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                itemBuilder: (context, index) {
                  final cat = cats[index];
                  final isActive = cat['is_active'] as bool? ?? true;
                  return Card(
                    key: ValueKey(cat['id']),
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppColors.surface,
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.drag_indicator,
                                  color: AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.category,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Text(cat['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('#${index + 1}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      subtitle: Text(
                          cat['description'] ?? 'Açıklama yok',
                          style: const TextStyle(
                              color: AppColors.textMuted)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.success
                                      .withValues(alpha: 0.1)
                                  : AppColors.error
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? 'Aktif' : 'Pasif',
                              style: TextStyle(
                                color: isActive
                                    ? AppColors.success
                                    : AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () =>
                                _showCategoryDialog(category: cat),
                            tooltip: 'Düzenle',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: AppColors.error),
                            onPressed: () => _deleteCategory(cat['id']),
                            tooltip: 'Sil',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }

  // ==================== Category CRUD ====================
  Future<void> _showCategoryDialog({Map<String, dynamic>? category}) async {
    final isEdit = category != null;
    final nameController =
        TextEditingController(text: category?['name'] ?? '');
    final descController =
        TextEditingController(text: category?['description'] ?? '');
    bool isActive = category?['is_active'] as bool? ?? true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Kategori Düzenle' : 'Yeni Kategori'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Kategori Adı',
                    hintText: 'Örneğin: Ana Yemekler, İçecekler',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (Opsiyonel)',
                    hintText: 'Kategori hakkında kısa bir açıklama',
                  ),
                  maxLines: 2,
                ),
                if (isEdit) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: isActive,
                    onChanged: (v) =>
                        setDialogState(() => isActive = v),
                    title: const Text('Aktif'),
                    subtitle:
                        const Text('Pasif kategoriler müşterilere gösterilmez'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
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
    if (nameController.text.trim().isEmpty) return;

    final client = ref.read(supabaseProvider);
    final data = {
      'name': nameController.text.trim(),
      'description': descController.text.trim().isEmpty
          ? null
          : descController.text.trim(),
      'merchant_id': widget.merchantId,
      'is_active': isActive,
    };

    try {
      if (isEdit) {
        data.remove('merchant_id');
        await client
            .from('menu_categories')
            .update(data)
            .eq('id', category['id']);
      } else {
        data['sort_order'] = 0;
        await client.from('menu_categories').insert(data);
      }
      ref.invalidate(merchantMenuCategoriesProvider(widget.merchantId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isEdit ? 'Kategori güncellendi' : 'Kategori eklendi'),
            backgroundColor: AppColors.success,
          ),
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

  Future<void> _deleteCategory(String categoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Kategori Sil'),
        content: const Text(
            'Bu kategoriyi silmek istediğinize emin misiniz?\nKategorideki ürünler kategorisiz kalacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
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
              backgroundColor: AppColors.success),
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

  // ==================== Menu Item CRUD ====================
  Future<void> _showMenuItemDialog({
    Map<String, dynamic>? item,
    required List<Map<String, dynamic>> categories,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _MenuItemDialog(
        item: item,
        categories: categories,
        merchantId: widget.merchantId,
      ),
    );

    if (result == true) {
      ref.invalidate(merchantMenuItemsProvider(widget.merchantId));
      ref.invalidate(merchantMenuCategoriesProvider(widget.merchantId));
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
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteMenuItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ürünü Sil'),
        content:
            const Text('Bu ürünü silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
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
      // Delete option group links first
      final links = await client
          .from('menu_item_option_groups')
          .select('option_group_id')
          .eq('menu_item_id', itemId);
      for (final link in List<Map<String, dynamic>>.from(links)) {
        final groupId = link['option_group_id'] as String;
        await client
            .from('product_options')
            .delete()
            .eq('option_group_id', groupId);
        await client
            .from('menu_item_option_groups')
            .delete()
            .eq('option_group_id', groupId);
        await client
            .from('product_option_groups')
            .delete()
            .eq('id', groupId);
      }
      await client.from('menu_items').delete().eq('id', itemId);
      ref.invalidate(merchantMenuItemsProvider(widget.merchantId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ürün silindi'),
              backgroundColor: AppColors.success),
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

// ===================== MENU ITEM CARD =====================
class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onToggleAvailability;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onToggleAvailability,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final description = item['description'] as String?;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final discountedPrice = (item['discounted_price'] as num?)?.toDouble();
    final isAvailable = item['is_available'] as bool? ?? true;
    final isPopular = item['is_popular'] as bool? ?? false;
    final imageUrl = item['image_url'] as String?;
    final hasDiscount =
        discountedPrice != null && discountedPrice > 0 && discountedPrice < price;
    final effectivePrice = hasDiscount ? discountedPrice : price;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                color: AppColors.background,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                            Icons.fastfood,
                            size: 48,
                            color: AppColors.textMuted))
                    : const Icon(Icons.fastfood,
                        size: 48, color: AppColors.textMuted),
              ),
              // Availability Badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAvailable ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isAvailable ? 'Mevcut' : 'Tükendi',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              // Popular Badge
              if (isPopular)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Popüler',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      if (hasDiscount) ...[
                        Text('${price.toStringAsFixed(0)} \u20BA',
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 8),
                      ],
                      Text('${effectivePrice.toStringAsFixed(0)} \u20BA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: hasDiscount
                                  ? AppColors.success
                                  : AppColors.textPrimary)),
                      const Spacer(),
                      IconButton(
                        onPressed: onToggleAvailability,
                        icon: Icon(
                          isAvailable
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        tooltip: isAvailable ? 'Tükendi Yap' : 'Mevcut Yap',
                      ),
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit,
                            size: 20, color: AppColors.info),
                        tooltip: 'Düzenle',
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete,
                            size: 20, color: AppColors.error),
                        tooltip: 'Sil',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== MENU ITEM DIALOG (Full-featured) =====================
class _MenuItemDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> categories;
  final String merchantId;

  const _MenuItemDialog({
    this.item,
    required this.categories,
    required this.merchantId,
  });

  @override
  State<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<_MenuItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _discountedPriceController;
  late TextEditingController _prepTimeController;
  String? _selectedCategoryId;
  bool _isPopular = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _existingImageUrl;
  bool _isSaving = false;

  // Option groups
  final List<Map<String, dynamic>> _optionGroups = [];
  bool _isLoadingOptions = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?['name'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.item?['description'] ?? '');
    _priceController = TextEditingController(
        text: (widget.item?['price'] as num?)?.toStringAsFixed(0) ?? '');
    _discountedPriceController = TextEditingController(
        text: (widget.item?['discounted_price'] as num?)?.toStringAsFixed(0) ??
            '');
    _prepTimeController = TextEditingController(
        text: (widget.item?['preparation_time'] as num?)?.toString() ?? '15');
    _selectedCategoryId = widget.item?['category_id'] as String? ??
        (widget.categories.isNotEmpty
            ? widget.categories.first['id'] as String
            : null);
    _isPopular = widget.item?['is_popular'] as bool? ?? false;
    _existingImageUrl = widget.item?['image_url'] as String?;

    if (widget.item != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingOptionGroups();
      });
    }
  }

  Future<void> _loadExistingOptionGroups() async {
    if (widget.item == null || !mounted) return;
    setState(() => _isLoadingOptions = true);

    try {
      final supabase = Supabase.instance.client;
      final linksResponse = await supabase
          .from('menu_item_option_groups')
          .select('option_group_id')
          .eq('menu_item_id', widget.item!['id']);

      if ((linksResponse as List).isEmpty) {
        if (mounted) setState(() => _isLoadingOptions = false);
        return;
      }

      final groupIds =
          linksResponse.map((e) => e['option_group_id']).toList();
      final groupsResponse = await supabase
          .from('product_option_groups')
          .select()
          .inFilter('id', groupIds);

      for (final group in groupsResponse) {
        final optionsResponse = await supabase
            .from('product_options')
            .select()
            .eq('option_group_id', group['id']);

        _optionGroups.add({
          'id': group['id'],
          'name': group['name'],
          'isRequired': group['is_required'] ?? false,
          'allowMultiple': (group['max_selections'] ?? 1) > 1,
          'options': (optionsResponse as List)
              .map((o) => {
                    'id': o['id'],
                    'name': o['name'],
                    'price': (o['price'] as num?)?.toDouble() ?? 0.0,
                  })
              .toList(),
        });
      }

      if (mounted) setState(() => _isLoadingOptions = false);
    } catch (e) {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountedPriceController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = picked.name;
      });
    }
  }

  void _addOptionGroup() {
    final nameController = TextEditingController();
    bool isRequired = false;
    bool allowMultiple = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Seçenek Grubu Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Grup Adı',
                  hintText: 'Örneğin: Sos Seçimi',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Sos Seçimi'),
                    onPressed: () => nameController.text = 'Sos Seçimi',
                  ),
                  ActionChip(
                    label: const Text('Boyut'),
                    onPressed: () => nameController.text = 'Boyut',
                  ),
                  ActionChip(
                    label: const Text('Ekstra'),
                    onPressed: () => nameController.text = 'Ekstra Malzeme',
                  ),
                  ActionChip(
                    label: const Text('İçecek'),
                    onPressed: () => nameController.text = 'İçecek Seçimi',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: isRequired,
                onChanged: (v) => setDialogState(() => isRequired = v),
                title: const Text('Zorunlu'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              SwitchListTile(
                value: allowMultiple,
                onChanged: (v) => setDialogState(() => allowMultiple = v),
                title: const Text('Çoklu Seçim'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    _optionGroups.add({
                      'name': nameController.text,
                      'isRequired': isRequired,
                      'allowMultiple': allowMultiple,
                      'options': <Map<String, dynamic>>[],
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _addOptionToGroup(int groupIndex) {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${_optionGroups[groupIndex]['name']} - Seçenek Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Seçenek Adı',
                hintText: 'Örneğin: Ketçap',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Ek Ücret (\u20BA)',
                hintText: '0 = Ücretsiz',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  (_optionGroups[groupIndex]['options'] as List).add({
                    'name': nameController.text,
                    'price': double.tryParse(priceController.text) ?? 0,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final isEdit = widget.item != null;
      String? imageUrl = _existingImageUrl;

      // Upload image if selected
      if (_selectedImageBytes != null && _selectedImageName != null) {
        try {
          final safeFileName =
              _selectedImageName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
          final fileName =
              'menu_${widget.merchantId}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
          await supabase.storage.from('images').uploadBinary(
                fileName,
                _selectedImageBytes!,
                fileOptions: const FileOptions(
                    cacheControl: '31536000', upsert: true),
              );
          imageUrl =
              supabase.storage.from('images').getPublicUrl(fileName);
        } catch (_) {
          // Continue without image on upload failure
        }
      }

      // Auto-find image from pool if none
      if (imageUrl == null && _nameController.text.isNotEmpty && !isEdit) {
        try {
          final poolResult = await supabase.rpc(
            'match_product_image',
            params: {
              'p_barcode': null,
              'p_name': _nameController.text.trim(),
              'p_brand': null
            },
          );
          if (poolResult != null &&
              poolResult is List &&
              poolResult.isNotEmpty) {
            final poolUrl = poolResult[0]['image_url'] as String?;
            if (poolUrl != null && poolUrl.isNotEmpty) {
              imageUrl = poolUrl;
            }
          }
        } catch (_) {}
      }

      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category_id': _selectedCategoryId,
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'discounted_price': _discountedPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_discountedPriceController.text.trim()),
        'image_url': imageUrl,
        'is_popular': _isPopular,
        'preparation_time':
            int.tryParse(_prepTimeController.text.trim()) ?? 15,
      };

      if (isEdit) {
        await supabase
            .from('menu_items')
            .update(data)
            .eq('id', widget.item!['id']);

        // Update option groups
        final existingLinks = await supabase
            .from('menu_item_option_groups')
            .select('option_group_id')
            .eq('menu_item_id', widget.item!['id']);
        final existingGroupIds = (existingLinks as List)
            .map((e) => e['option_group_id'] as String)
            .toSet();
        final newGroupIds = _optionGroups
            .where((g) => g['id'] != null)
            .map((g) => g['id'] as String)
            .toSet();

        // Delete removed groups
        for (final groupId in existingGroupIds) {
          if (!newGroupIds.contains(groupId)) {
            await supabase
                .from('menu_item_option_groups')
                .delete()
                .eq('menu_item_id', widget.item!['id'])
                .eq('option_group_id', groupId);
            await supabase
                .from('product_options')
                .delete()
                .eq('option_group_id', groupId);
            await supabase
                .from('product_option_groups')
                .delete()
                .eq('id', groupId);
          }
        }

        // Add/update groups
        for (final group in _optionGroups) {
          if (group['id'] != null &&
              existingGroupIds.contains(group['id'])) {
            // Update existing
            await supabase.from('product_option_groups').update({
              'name': group['name'],
              'is_required': group['isRequired'],
              'max_selections':
                  group['allowMultiple'] == true ? 10 : 1,
            }).eq('id', group['id']);

            await supabase
                .from('product_options')
                .delete()
                .eq('option_group_id', group['id']);
            for (final opt in (group['options'] as List)) {
              await supabase.from('product_options').insert({
                'option_group_id': group['id'],
                'name': opt['name'],
                'price': opt['price'],
              });
            }
          } else {
            // Create new
            final groupResponse = await supabase
                .from('product_option_groups')
                .insert({
                  'merchant_id': widget.merchantId,
                  'name': group['name'],
                  'is_required': group['isRequired'],
                  'max_selections':
                      group['allowMultiple'] == true ? 10 : 1,
                })
                .select()
                .single();

            for (final opt in (group['options'] as List)) {
              await supabase.from('product_options').insert({
                'option_group_id': groupResponse['id'],
                'name': opt['name'],
                'price': opt['price'],
              });
            }

            await supabase.from('menu_item_option_groups').insert({
              'menu_item_id': widget.item!['id'],
              'option_group_id': groupResponse['id'],
            });
          }
        }
      } else {
        // Insert new item
        data['merchant_id'] = widget.merchantId;
        data['is_available'] = true;
        data['sort_order'] = 0;
        final menuItemResponse =
            await supabase.from('menu_items').insert(data).select().single();

        // Save option groups
        for (final group in _optionGroups) {
          final groupResponse = await supabase
              .from('product_option_groups')
              .insert({
                'merchant_id': widget.merchantId,
                'name': group['name'],
                'is_required': group['isRequired'],
                'max_selections':
                    group['allowMultiple'] == true ? 10 : 1,
              })
              .select()
              .single();

          for (final opt in (group['options'] as List)) {
            await supabase.from('product_options').insert({
              'option_group_id': groupResponse['id'],
              'name': opt['name'],
              'price': opt['price'],
            });
          }

          await supabase.from('menu_item_option_groups').insert({
            'menu_item_id': menuItemResponse['id'],
            'option_group_id': groupResponse['id'],
          });
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Ürün güncellendi!' : 'Ürün eklendi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 750),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Text(
                      isEditing ? 'Ürünü Düzenle' : 'Yeni Ürün Ekle',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Upload
                      const Text('Ürün Resmi',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceLight),
                          ),
                          child: _selectedImageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(_selectedImageBytes!,
                                      fit: BoxFit.cover))
                              : _existingImageUrl != null &&
                                      _existingImageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      child: Image.network(
                                          _existingImageUrl!,
                                          fit: BoxFit.cover))
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate,
                                            size: 48,
                                            color: AppColors.textMuted),
                                        const SizedBox(height: 8),
                                        Text('Resim Yükle',
                                            style: TextStyle(
                                                color:
                                                    AppColors.textMuted)),
                                      ],
                                    ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Ürün Adı *'),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          hintText: 'Ürün içeriği, malzemeler vs.',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Category
                      if (widget.categories.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning,
                                  color: AppColors.warning, size: 20),
                              SizedBox(width: 8),
                              Text('Önce kategori oluşturun'),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration:
                              const InputDecoration(labelText: 'Kategori *'),
                          dropdownColor: AppColors.surface,
                          items: widget.categories
                              .map((c) => DropdownMenuItem<String>(
                                    value: c['id'] as String,
                                    child: Text(c['name'] ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategoryId = v),
                          validator: (v) =>
                              v == null ? 'Kategori seçin' : null,
                        ),
                      const SizedBox(height: 16),

                      // Price Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Fiyat *',
                                suffixText: '\u20BA',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Zorunlu' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _discountedPriceController,
                              decoration: const InputDecoration(
                                labelText: 'İndirimli Fiyat',
                                suffixText: '\u20BA',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Prep time
                      TextFormField(
                        controller: _prepTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Hazırlama Süresi',
                          suffixText: 'dk',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Popular Switch
                      SwitchListTile(
                        value: _isPopular,
                        onChanged: (v) => setState(() => _isPopular = v),
                        title: const Text('Popüler Ürün'),
                        subtitle: const Text('Öne çıkacak ürünler'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 20),

                      // Option Groups Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ürün Seçenekleri',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: _addOptionGroup,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Grup Ekle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_isLoadingOptions)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          ),
                        )
                      else if (_optionGroups.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppColors.textMuted, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sos seçimi, ekstra malzeme gibi seçenekler ekleyebilirsiniz',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(_optionGroups.length, (i) {
                          final group = _optionGroups[i];
                          return Card(
                            color: AppColors.background,
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(group['name'],
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Row(
                                              children: [
                                                if (group['isRequired'] ==
                                                    true)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets
                                                            .only(
                                                            right: 8),
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: AppColors
                                                          .error
                                                          .withValues(
                                                              alpha:
                                                                  0.1),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  4),
                                                    ),
                                                    child: const Text(
                                                        'Zorunlu',
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                AppColors
                                                                    .error)),
                                                  ),
                                                if (group[
                                                        'allowMultiple'] ==
                                                    true)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                    decoration:
                                                        BoxDecoration(
                                                      color: AppColors
                                                          .info
                                                          .withValues(
                                                              alpha:
                                                                  0.1),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  4),
                                                    ),
                                                    child: const Text(
                                                        'Çoklu',
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                AppColors
                                                                    .info)),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 20,
                                            color: AppColors.error),
                                        onPressed: () => setState(
                                            () => _optionGroups
                                                .removeAt(i)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...(group['options'] as List)
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final opt = entry.value;
                                    final optPrice =
                                        (opt['price'] as num?) ?? 0;
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(opt['name'] ?? '',
                                          style: const TextStyle(
                                              color:
                                                  AppColors.textPrimary)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            optPrice > 0
                                                ? '+${optPrice.toStringAsFixed(0)} \u20BA'
                                                : 'Ücretsiz',
                                            style: TextStyle(
                                              color: optPrice > 0
                                                  ? AppColors.success
                                                  : AppColors.textMuted,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                size: 16),
                                            onPressed: () => setState(
                                                () => (group['options']
                                                        as List)
                                                    .removeAt(
                                                        entry.key)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _addOptionToGroup(i),
                                    icon:
                                        const Icon(Icons.add, size: 16),
                                    label: const Text('Seçenek Ekle'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Actions
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save, size: 20),
                      label: Text(
                          isEditing ? 'Güncelle' : 'Kaydet ve Yayınla'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
