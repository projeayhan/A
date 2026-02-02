import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/merchant_models.dart';
import '../../../core/providers/merchant_provider.dart';
import '../../../core/services/supabase_service.dart';

// Menu Categories Provider
final menuCategoriesProvider = StateNotifierProvider<
  MenuCategoriesNotifier,
  AsyncValue<List<MenuCategory>>
>((ref) {
  return MenuCategoriesNotifier(ref);
});

class MenuCategoriesNotifier
    extends StateNotifier<AsyncValue<List<MenuCategory>>> {
  final Ref ref;

  MenuCategoriesNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> loadCategories(String merchantId) async {
    if (kDebugMode) print('=== LOADING CATEGORIES for $merchantId ===');
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('menu_categories')
          .select()
          .eq('merchant_id', merchantId)
          .order('sort_order');

      if (kDebugMode) print('Categories response: $response');
      final categories =
          (response as List)
              .map(
                (json) => MenuCategory.fromJson({
                  ...json,
                  'restaurant_id': json['merchant_id'],
                }),
              )
              .toList();

      if (kDebugMode) print('Loaded ${categories.length} categories');
      state = AsyncValue.data(categories);
    } catch (e) {
      if (kDebugMode) print('Load categories error: $e');
      state = AsyncValue.data([]);
    }
  }

  Future<bool> addCategory(
    String merchantId,
    String name,
    String? description,
  ) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      if (kDebugMode) print('Adding category: $name for merchant: $merchantId');

      await supabase.from('menu_categories').insert({
        'merchant_id': merchantId,
        'name': name,
        'description': description,
        'sort_order': 0,
        'is_active': true,
      });

      if (kDebugMode) print('Category added successfully');
      await loadCategories(merchantId);
      return true;
    } catch (e) {
      if (kDebugMode) print('Add category error: $e');
      return false;
    }
  }

  Future<bool> updateCategory(
    String categoryId,
    String name,
    String? description,
    bool isActive,
  ) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase
          .from('menu_categories')
          .update({
            'name': name,
            'description': description,
            'is_active': isActive,
          })
          .eq('id', categoryId);

      state.whenData((categories) {
        final index = categories.indexWhere((c) => c.id == categoryId);
        if (index != -1) {
          final merchant = ref.read(currentMerchantProvider).valueOrNull;
          if (merchant != null) {
            loadCategories(merchant.id);
          }
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId, String merchantId) async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('menu_categories').delete().eq('id', categoryId);
      await loadCategories(merchantId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateCategoryOrder(List<MenuCategory> categories) async {
    try {
      final supabase = ref.read(supabaseClientProvider);

      // Update each category's sort_order
      for (int i = 0; i < categories.length; i++) {
        await supabase
            .from('menu_categories')
            .update({'sort_order': i})
            .eq('id', categories[i].id);
      }

      // Update local state
      state = AsyncValue.data(categories);
      return true;
    } catch (e) {
      if (kDebugMode) print('Update category order error: $e');
      return false;
    }
  }
}

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategory;
  String _searchQuery = '';
  bool _categoriesLoaded = false;

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
    // Watch merchant
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final categories = ref.watch(menuCategoriesProvider);

    // Load categories once when merchant is available
    if (merchant != null && !_categoriesLoaded) {
      _categoriesLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(menuCategoriesProvider.notifier).loadCategories(merchant.id);
      });
    }

    return Column(
      children: [
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Urunler', icon: Icon(Icons.fastfood, size: 20)),
              Tab(text: 'Kategoriler', icon: Icon(Icons.category, size: 20)),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildProductsTab(), _buildCategoriesTab()],
          ),
        ),
      ],
    );
  }

  // ===================== PRODUCTS TAB =====================
  Widget _buildProductsTab() {
    final menuItems = ref.watch(menuItemsProvider);
    final categories = ref.watch(menuCategoriesProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              // Search
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Urun ara...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
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
              categories.when(
                data:
                    (cats) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        hint: const Text('Kategori'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tum Kategoriler'),
                          ),
                          ...cats.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setState(() => _selectedCategory = value),
                      ),
                    ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(width: 16),

              // Add Button
              ElevatedButton.icon(
                onPressed: () => _showAddItemDialog(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Urun Ekle'),
              ),
            ],
          ),
        ),

        // Menu Grid
        Expanded(
          child: menuItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Hata: $error')),
            data: (items) {
              var filtered = items;
              if (_selectedCategory != null) {
                filtered =
                    items
                        .where((i) => i.category == _selectedCategory)
                        .toList();
              }
              if (_searchQuery.isNotEmpty) {
                filtered =
                    filtered
                        .where(
                          (i) => i.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                        )
                        .toList();
              }

              if (filtered.isEmpty) {
                return _buildEmptyState();
              }

              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
                    onEdit: () => _showEditItemDialog(context, item),
                    onToggleAvailability: () {
                      ref
                          .read(menuItemsProvider.notifier)
                          .toggleAvailability(item.id);
                    },
                    onDelete: () => _showDeleteDialog(context, item),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: AppColors.textMuted),
          const SizedBox(height: 24),
          Text(
            'Menu bos',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Ilk urununu ekleyerek menuyu olusturmaya basla',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddItemDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Urun Ekle'),
          ),
        ],
      ),
    );
  }

  // ===================== CATEGORIES TAB =====================
  Widget _buildCategoriesTab() {
    final categories = ref.watch(menuCategoriesProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kategoriler',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.drag_indicator, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Siralama icin surukleyip birakin',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(context),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Kategori Ekle'),
              ),
            ],
          ),
        ),

        // Categories List
        Expanded(
          child: categories.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Hata: $error')),
            data: (cats) {
              if (cats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category,
                        size: 80,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Henuz kategori yok',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Urunlerinizi gruplamak icin kategori olusturun',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddCategoryDialog(context),
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
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final List<MenuCategory> reorderedCats = List.from(cats);
                  final item = reorderedCats.removeAt(oldIndex);
                  reorderedCats.insert(newIndex, item);

                  // Update database and state
                  ref.read(menuCategoriesProvider.notifier)
                      .updateCategoryOrder(reorderedCats);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kategori sirasi guncellendi'),
                      duration: Duration(seconds: 1),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  final category = cats[index];
                  return _buildReorderableCategoryCard(category, index, key: ValueKey(category.id));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReorderableCategoryCard(MenuCategory category, int index, {required Key key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_indicator,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.category, color: AppColors.primary),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(category.description ?? 'Aciklama yok'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    category.isActive
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                category.isActive ? 'Aktif' : 'Pasif',
                style: TextStyle(
                  color:
                      category.isActive ? AppColors.success : AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditCategoryDialog(context, category),
              tooltip: 'Duzenle',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
              onPressed: () => _showDeleteCategoryDialog(context, category),
              tooltip: 'Sil',
            ),
          ],
        ),
      ),
    );
  }

  // ===================== DIALOGS =====================
  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => _MenuItemDialog(
            onSave: (item, imageBytes, imageName, optionGroups) async {
              if (kDebugMode) print('=== SAVING MENU ITEM ===');
              final merchant = ref.read(currentMerchantProvider).valueOrNull;
              if (kDebugMode) print('Merchant: $merchant');
              if (merchant == null) {
                if (kDebugMode) print('ERROR: Merchant is null!');
                return;
              }

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder:
                    (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                String? imageUrl;

                // Upload image if exists (optional - continue even if fails)
                if (imageBytes != null && imageName != null) {
                  try {
                    if (kDebugMode) print('Uploading image: $imageName');
                    final supabase = ref.read(supabaseClientProvider);
                    // Use flat path without subfolders to avoid invalid key error
                    final safeFileName = imageName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
                    final fileName =
                        'menu_${merchant.id}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

                    await supabase.storage
                        .from('images')
                        .uploadBinary(
                          fileName,
                          imageBytes,
                          fileOptions: const FileOptions(
                            cacheControl: '3600',
                            upsert: true,
                          ),
                        );

                    imageUrl = supabase.storage.from('images').getPublicUrl(fileName);
                    if (kDebugMode) print('Image uploaded: $imageUrl');
                  } catch (e) {
                    if (kDebugMode) print('Image upload failed (continuing without image): $e');
                    // Continue without image
                  }
                }

                // Save menu item
                if (kDebugMode) print('Saving menu item: ${item.name}');
                final supabase = ref.read(supabaseClientProvider);
                if (kDebugMode) print('Category ID: ${item.category}');
                final menuItemResponse =
                    await supabase
                        .from('menu_items')
                        .insert({
                          'merchant_id': merchant.id,
                          'category_id': item.category,
                          'name': item.name,
                          'description': item.description,
                          'price': item.price,
                          'discounted_price': item.discountedPrice,
                          'image_url': imageUrl,
                          'is_available': true,
                          'is_popular': item.isPopular,
                          'sort_order': 0,
                        })
                        .select()
                        .single();
                if (kDebugMode) print('Menu item saved: ${menuItemResponse['id']}');

                // Save option groups if any
                if (optionGroups.isNotEmpty) {
                  for (final group in optionGroups) {
                    final groupResponse =
                        await supabase
                            .from('product_option_groups')
                            .insert({
                              'merchant_id': merchant.id,
                              'name': group['name'],
                              'is_required': group['isRequired'],
                              'max_selections':
                                  group['allowMultiple'] == true ? 10 : 1,
                            })
                            .select()
                            .single();

                    // Save options
                    for (final option in (group['options'] as List)) {
                      await supabase.from('product_options').insert({
                        'option_group_id': groupResponse['id'],
                        'name': option['name'],
                        'price': option['price'],
                      });
                    }

                    // Link option group to menu item
                    await supabase.from('menu_item_option_groups').insert({
                      'menu_item_id': menuItemResponse['id'],
                      'option_group_id': groupResponse['id'],
                    });
                  }
                }

                // Reload menu items
                ref.read(menuItemsProvider.notifier).loadMenuItems(merchant.id);
                if (kDebugMode) print('Menu items reloaded');

                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  Navigator.pop(context); // Close main dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Urun basariyla eklendi!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (kDebugMode) print('ERROR saving menu item: $e');
                if (context.mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
    );
  }

  void _showEditItemDialog(BuildContext context, MenuItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => _MenuItemDialog(
            item: item,
            onSave: (updatedItem, imageBytes, imageName, optionGroups) async {
              final merchant = ref.read(currentMerchantProvider).valueOrNull;
              if (merchant == null) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder:
                    (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                String? imageUrl = item.imageUrl;

                if (imageBytes != null && imageName != null) {
                  try {
                    final supabase = ref.read(supabaseClientProvider);
                    final safeFileName = imageName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
                    final fileName =
                        'menu_${merchant.id}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

                    await supabase.storage
                        .from('images')
                        .uploadBinary(
                          fileName,
                          imageBytes,
                          fileOptions: const FileOptions(
                            cacheControl: '3600',
                            upsert: true,
                          ),
                        );

                    imageUrl = supabase.storage.from('images').getPublicUrl(fileName);
                  } catch (e) {
                    if (kDebugMode) print('Image upload failed: $e');
                  }
                }

                final supabase = ref.read(supabaseClientProvider);
                await supabase
                    .from('menu_items')
                    .update({
                      'category_id': updatedItem.category,
                      'name': updatedItem.name,
                      'description': updatedItem.description,
                      'price': updatedItem.price,
                      'discounted_price': updatedItem.discountedPrice,
                      'image_url': imageUrl,
                      'is_popular': updatedItem.isPopular,
                    })
                    .eq('id', item.id);

                // Update option groups
                // First, get existing option group links
                final existingLinks = await supabase
                    .from('menu_item_option_groups')
                    .select('option_group_id')
                    .eq('menu_item_id', item.id);

                final existingGroupIds = (existingLinks as List)
                    .map((e) => e['option_group_id'] as String)
                    .toSet();

                final newGroupIds = optionGroups
                    .where((g) => g['id'] != null)
                    .map((g) => g['id'] as String)
                    .toSet();

                // Delete removed option groups
                for (final groupId in existingGroupIds) {
                  if (!newGroupIds.contains(groupId)) {
                    // Delete link
                    await supabase
                        .from('menu_item_option_groups')
                        .delete()
                        .eq('menu_item_id', item.id)
                        .eq('option_group_id', groupId);
                    // Delete options
                    await supabase
                        .from('product_options')
                        .delete()
                        .eq('option_group_id', groupId);
                    // Delete group
                    await supabase
                        .from('product_option_groups')
                        .delete()
                        .eq('id', groupId);
                  }
                }

                // Add or update option groups
                for (final group in optionGroups) {
                  if (group['id'] != null && existingGroupIds.contains(group['id'])) {
                    // Update existing group
                    await supabase
                        .from('product_option_groups')
                        .update({
                          'name': group['name'],
                          'is_required': group['isRequired'],
                          'max_selections': group['allowMultiple'] == true ? 10 : 1,
                        })
                        .eq('id', group['id']);

                    // Delete old options and add new ones
                    await supabase
                        .from('product_options')
                        .delete()
                        .eq('option_group_id', group['id']);

                    for (final option in (group['options'] as List)) {
                      await supabase.from('product_options').insert({
                        'option_group_id': group['id'],
                        'name': option['name'],
                        'price': option['price'],
                      });
                    }
                  } else {
                    // Add new group
                    final groupResponse = await supabase
                        .from('product_option_groups')
                        .insert({
                          'merchant_id': merchant.id,
                          'name': group['name'],
                          'is_required': group['isRequired'],
                          'max_selections': group['allowMultiple'] == true ? 10 : 1,
                        })
                        .select()
                        .single();

                    // Add options
                    for (final option in (group['options'] as List)) {
                      await supabase.from('product_options').insert({
                        'option_group_id': groupResponse['id'],
                        'name': option['name'],
                        'price': option['price'],
                      });
                    }

                    // Link to menu item
                    await supabase.from('menu_item_option_groups').insert({
                      'menu_item_id': item.id,
                      'option_group_id': groupResponse['id'],
                    });
                  }
                }

                ref.read(menuItemsProvider.notifier).loadMenuItems(merchant.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Urun guncellendi!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
    );
  }

  void _showDeleteDialog(BuildContext context, MenuItem item) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Urunu Sil'),
            content: Text('${item.name} silinsin mi? Bu islem geri alinamaz.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final merchant =
                      ref.read(currentMerchantProvider).valueOrNull;
                  if (merchant == null) return;

                  try {
                    final supabase = ref.read(supabaseClientProvider);
                    await supabase
                        .from('menu_items')
                        .delete()
                        .eq('id', item.id);
                    ref
                        .read(menuItemsProvider.notifier)
                        .loadMenuItems(merchant.id);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Urun silindi'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Hata: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Yeni Kategori'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Kategori Adi',
                          hintText: 'Ornegin: Ana Yemekler, Icecekler',
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Aciklama (Opsiyonel)',
                          hintText: 'Kategori hakkinda kisa bir aciklama',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Iptal'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Kategori adi zorunlu'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }

                                final merchant =
                                    ref
                                        .read(currentMerchantProvider)
                                        .valueOrNull;
                                if (kDebugMode) print('Merchant value: $merchant');
                                if (merchant == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Magaza bilgisi bulunamadi',
                                      ),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  Navigator.pop(context);
                                  return;
                                }

                                setDialogState(() => isLoading = true);

                                try {
                                  final success = await ref
                                      .read(menuCategoriesProvider.notifier)
                                      .addCategory(
                                        merchant.id,
                                        nameController.text.trim(),
                                        descriptionController.text
                                                .trim()
                                                .isEmpty
                                            ? null
                                            : descriptionController.text.trim(),
                                      );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Kategori eklendi!'
                                              : 'Hata olustu',
                                        ),
                                        backgroundColor:
                                            success
                                                ? AppColors.success
                                                : AppColors.error,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (kDebugMode) print('Category save error: $e');
                                  if (context.mounted) {
                                    setDialogState(() => isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Hata: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Kaydet'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, MenuCategory category) {
    final nameController = TextEditingController(text: category.name);
    final descriptionController = TextEditingController(
      text: category.description,
    );
    bool isActive = category.isActive;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Kategori Duzenle'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Kategori Adi',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Aciklama',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (v) => setDialogState(() => isActive = v),
                        title: const Text('Aktif'),
                        subtitle: const Text(
                          'Pasif kategoriler musterilere gosterilmez',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Iptal'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Kategori adi zorunlu'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() => isLoading = true);

                                final success = await ref
                                    .read(menuCategoriesProvider.notifier)
                                    .updateCategory(
                                      category.id,
                                      nameController.text.trim(),
                                      descriptionController.text.trim().isEmpty
                                          ? null
                                          : descriptionController.text.trim(),
                                      isActive,
                                    );

                                final merchant =
                                    ref
                                        .read(currentMerchantProvider)
                                        .valueOrNull;
                                if (merchant != null) {
                                  await ref
                                      .read(menuCategoriesProvider.notifier)
                                      .loadCategories(merchant.id);
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Kategori guncellendi!'
                                            : 'Hata olustu',
                                      ),
                                      backgroundColor:
                                          success
                                              ? AppColors.success
                                              : AppColors.error,
                                    ),
                                  );
                                }
                              },
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Kaydet'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, MenuCategory category) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Kategori Sil'),
            content: Text(
              '${category.name} silinsin mi?\n\nBu kategorideki urunler kategorisiz kalacak.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final merchant =
                      ref.read(currentMerchantProvider).valueOrNull;
                  if (merchant == null) return;

                  final success = await ref
                      .read(menuCategoriesProvider.notifier)
                      .deleteCategory(category.id, merchant.id);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Kategori silindi!' : 'Hata olustu',
                        ),
                        backgroundColor:
                            success ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }
}

// ===================== MENU ITEM CARD =====================
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
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
    return Card(
      clipBehavior: Clip.antiAlias,
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
                child:
                    item.imageUrl != null
                        ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                        : const Icon(
                          Icons.fastfood,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
              ),
              // Availability Badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        item.isAvailable ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.isAvailable ? 'Mevcut' : 'Tukendi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (item.isPopular)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 12,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Populer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      if (item.hasDiscount) ...[
                        Text(
                          '${item.price.toStringAsFixed(0)} TL',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${item.effectivePrice.toStringAsFixed(0)} TL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              item.hasDiscount
                                  ? AppColors.success
                                  : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onToggleAvailability,
                        icon: Icon(
                          item.isAvailable
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                        ),
                        tooltip:
                            item.isAvailable ? 'Tukendi Yap' : 'Mevcut Yap',
                      ),
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Duzenle',
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

// ===================== MENU ITEM DIALOG =====================
class _MenuItemDialog extends ConsumerStatefulWidget {
  final MenuItem? item;
  final Function(
    MenuItem item,
    Uint8List? imageBytes,
    String? imageName,
    List<Map<String, dynamic>> optionGroups,
  )
  onSave;

  const _MenuItemDialog({this.item, required this.onSave});

  @override
  ConsumerState<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends ConsumerState<_MenuItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _discountedPriceController;
  String? _selectedCategoryId;
  bool _isPopular = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _existingImageUrl;

  // Option groups
  final List<Map<String, dynamic>> _optionGroups = [];
  bool _isLoadingOptions = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name);
    _descriptionController = TextEditingController(
      text: widget.item?.description,
    );
    _priceController = TextEditingController(
      text: widget.item?.price.toStringAsFixed(0),
    );
    _discountedPriceController = TextEditingController(
      text: widget.item?.discountedPrice?.toStringAsFixed(0),
    );
    _selectedCategoryId = widget.item?.category;
    _isPopular = widget.item?.isPopular ?? false;
    _existingImageUrl = widget.item?.imageUrl;

    // Load existing option groups if editing
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
      final supabase = ref.read(supabaseClientProvider);

      // Get option group links for this menu item
      final linksResponse = await supabase
          .from('menu_item_option_groups')
          .select('option_group_id')
          .eq('menu_item_id', widget.item!.id);

      if ((linksResponse as List).isEmpty) {
        if (mounted) setState(() => _isLoadingOptions = false);
        return;
      }

      final groupIds = linksResponse.map((e) => e['option_group_id']).toList();

      // Get option groups
      final groupsResponse = await supabase
          .from('product_option_groups')
          .select()
          .inFilter('id', groupIds);

      for (final group in groupsResponse) {
        // Get options for this group
        final optionsResponse = await supabase
            .from('product_options')
            .select()
            .eq('option_group_id', group['id']);

        _optionGroups.add({
          'id': group['id'],
          'name': group['name'],
          'isRequired': group['is_required'] ?? false,
          'allowMultiple': (group['max_selections'] ?? 1) > 1,
          'options': (optionsResponse as List).map((o) => {
            'id': o['id'],
            'name': o['name'],
            'price': (o['price'] as num?)?.toDouble() ?? 0.0,
          }).toList(),
        });
      }

      if (mounted) setState(() => _isLoadingOptions = false);
    } catch (e) {
      if (kDebugMode) print('Error loading option groups: $e');
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountedPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedImageBytes = result.files.first.bytes;
        _selectedImageName = result.files.first.name;
      });
    }
  }

  void _addOptionGroup() {
    final nameController = TextEditingController();
    bool isRequired = false;
    bool allowMultiple = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('Secenek Grubu Ekle'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Grup Adi',
                          hintText: 'Ornegin: Sos Secimi',
                        ),
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
                        onChanged:
                            (v) => setDialogState(() => allowMultiple = v),
                        title: const Text('Coklu Secim'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Iptal'),
                    ),
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
      builder:
          (ctx) => AlertDialog(
            title: Text('${_optionGroups[groupIndex]['name']} - Secenek Ekle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Secenek Adi',
                    hintText: 'Ornegin: Ketcap',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Ek Ucret (TL)',
                    hintText: '0 = Ucretsiz',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Iptal'),
              ),
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    final categories = ref.watch(menuCategoriesProvider);

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
                      isEditing ? 'Urunu Duzenle' : 'Yeni Urun Ekle',
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
                      const Text(
                        'Urun Resmi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickImage,
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child:
                              _selectedImageBytes != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      _selectedImageBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : _existingImageUrl != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _existingImageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                  : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        size: 48,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Resim Yukle',
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Urun Adi *',
                        ),
                        validator:
                            (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Aciklama',
                          hintText: 'Urun icerigi, malzemeler vs.',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Category
                      categories.when(
                        data: (cats) {
                          if (cats.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning,
                                    color: AppColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('Once kategori olusturun'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Kategorilere Git'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'Kategori *',
                            ),
                            items:
                                cats
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (v) => setState(() => _selectedCategoryId = v),
                            validator:
                                (v) => v == null ? 'Kategori secin' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Kategoriler yuklenemedi'),
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
                                suffixText: 'TL',
                              ),
                              keyboardType: TextInputType.number,
                              validator:
                                  (v) => v?.isEmpty ?? true ? 'Zorunlu' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _discountedPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Indirimli Fiyat',
                                suffixText: 'TL',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Popular Switch
                      SwitchListTile(
                        value: _isPopular,
                        onChanged: (v) => setState(() => _isPopular = v),
                        title: const Text('Populer Urun'),
                        subtitle: const Text('One cikacak urunler'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 20),

                      // Option Groups Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Urun Secenekleri',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
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
                              Icon(
                                Icons.info_outline,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sos secimi, ekstra malzeme gibi secenekler ekleyebilirsiniz',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(_optionGroups.length, (i) {
                          final group = _optionGroups[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              group['name'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                if (group['isRequired'])
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.error
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Zorunlu',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors.error,
                                                      ),
                                                    ),
                                                  ),
                                                if (group['allowMultiple'])
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.info
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Coklu',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors.info,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: AppColors.error,
                                        ),
                                        onPressed:
                                            () => setState(
                                              () => _optionGroups.removeAt(i),
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...(group['options'] as List)
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final opt = entry.value;
                                        return ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(opt['name']),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                opt['price'] > 0
                                                    ? '+${opt['price'].toStringAsFixed(0)} TL'
                                                    : 'Ucretsiz',
                                                style: TextStyle(
                                                  color:
                                                      opt['price'] > 0
                                                          ? AppColors.success
                                                          : AppColors.textMuted,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 16,
                                                ),
                                                onPressed:
                                                    () => setState(
                                                      () => (group['options']
                                                              as List)
                                                          .removeAt(entry.key),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  TextButton.icon(
                                    onPressed: () => _addOptionToGroup(i),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Secenek Ekle'),
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Iptal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 20),
                      label: Text(isEditing ? 'Guncelle' : 'Kaydet ve Yayinla'),
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    final item = MenuItem(
      id: widget.item?.id ?? '',
      merchantId: merchant.id,
      category: _selectedCategoryId,
      name: _nameController.text.trim(),
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      price: double.parse(_priceController.text),
      discountedPrice:
          _discountedPriceController.text.isEmpty
              ? null
              : double.parse(_discountedPriceController.text),
      isPopular: _isPopular,
      isAvailable: widget.item?.isAvailable ?? true,
      sortOrder: widget.item?.sortOrder ?? 0,
      createdAt: widget.item?.createdAt ?? DateTime.now(),
    );

    // Call onSave first, it will handle closing dialogs
    widget.onSave(item, _selectedImageBytes, _selectedImageName, _optionGroups);
  }
}
