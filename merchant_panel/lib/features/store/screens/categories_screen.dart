import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/merchant_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(productCategoriesProvider);
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Kategori Yonetimi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Yeni Kategori'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Kategori ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(height: 24),

          // Info text
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(Icons.drag_indicator, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Siralama icin surukleyip birakin',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),

          // Categories List
          Expanded(
            child: categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Hata: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (merchant != null) {
                          ref.read(productCategoriesProvider.notifier).loadCategories(merchant.id);
                        }
                      },
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
              data: (categoryList) {
                final filteredList = categoryList
                    .where((c) => c.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.category_outlined, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'Henuz kategori yok' : 'Sonuc bulunamadi',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Yeni kategori eklemek icin butona tiklayin',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // If searching, show grid; otherwise show reorderable list
                if (_searchQuery.isNotEmpty) {
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final category = filteredList[index];
                      return _CategoryCard(
                        category: category,
                        index: index,
                        onEdit: () => _showCategoryDialog(context, ref, category: category),
                        onDelete: () => _deleteCategory(context, ref, category),
                      );
                    },
                  );
                }

                return ReorderableListView.builder(
                  itemCount: filteredList.length,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final List<ProductCategory> reorderedCats = List.from(filteredList);
                    final item = reorderedCats.removeAt(oldIndex);
                    reorderedCats.insert(newIndex, item);

                    // Update database and state
                    ref.read(productCategoriesProvider.notifier)
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
                    final category = filteredList[index];
                    return _ReorderableCategoryCard(
                      key: ValueKey(category.id),
                      category: category,
                      index: index,
                      onEdit: () => _showCategoryDialog(context, ref, category: category),
                      onDelete: () => _deleteCategory(context, ref, category),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, {ProductCategory? category}) {
    final controller = TextEditingController(text: category?.name);
    final isEditing = category != null;
    final merchant = ref.read(currentMerchantProvider).valueOrNull;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEditing ? 'Kategori Duzenle' : 'Yeni Kategori'),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Kategori Adi',
              hintText: 'Ornek: Elektronik',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              if (isEditing) {
                await ref.read(productCategoriesProvider.notifier)
                    .updateCategory(category.id, name);
              } else if (merchant != null) {
                await ref.read(productCategoriesProvider.notifier)
                    .addCategory(name, merchant.id);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(isEditing ? 'Kaydet' : 'Ekle'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(BuildContext context, WidgetRef ref, ProductCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kategori Sil'),
        content: Text('"${category.name}" kategorisini silmek istediginize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(productCategoriesProvider.notifier).deleteCategory(category.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ProductCategory category;
  final int? index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.category, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Duzenle'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Sil', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReorderableCategoryCard extends StatelessWidget {
  final ProductCategory category;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReorderableCategoryCard({
    super.key,
    required this.category,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              tooltip: 'Duzenle',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: AppColors.error),
              onPressed: onDelete,
              tooltip: 'Sil',
            ),
          ],
        ),
      ),
    );
  }
}
