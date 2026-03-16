import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';
import '../../../core/services/supabase_service.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  final String merchantId;
  const AdminProductsScreen({super.key, required this.merchantId});

  @override
  ConsumerState<AdminProductsScreen> createState() =>
      _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  String? _selectedCategoryFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync =
        ref.watch(merchantProductsProvider(widget.merchantId));
    final categoriesAsync =
        ref.watch(merchantProductCategoriesProvider(widget.merchantId));

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
                      'Ürün Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mağaza ürünlerini yönetin',
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
                            merchantProductsProvider(widget.merchantId));
                        ref.invalidate(
                            merchantProductCategoriesProvider(widget.merchantId));
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showProductDialog(
                        categories: categoriesAsync.valueOrNull ?? [],
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ürün Ekle'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filters row: search + category dropdown
            Row(
              children: [
                // Search bar
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Ürün ara...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textMuted, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.surfaceLight),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Category filter dropdown
                SizedBox(
                  width: 220,
                  child: categoriesAsync.when(
                    data: (categories) => DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryFilter,
                      decoration: InputDecoration(
                        labelText: 'Kategori Filtresi',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.surfaceLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.surfaceLight),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      dropdownColor: AppColors.surface,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Tüm Kategoriler'),
                        ),
                        ...categories.map((cat) => DropdownMenuItem<String>(
                              value: cat['id'] as String,
                              child: Text(cat['name'] ?? ''),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategoryFilter = value);
                      },
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Products table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: productsAsync.when(
                  data: (products) => _buildProductsTable(
                    products,
                    categoriesAsync.valueOrNull ?? [],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Hata: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTable(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> categories,
  ) {
    // Apply filters
    var filtered = products;

    if (_selectedCategoryFilter != null) {
      filtered = filtered
          .where((p) => p['category_id'] == _selectedCategoryFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              (p['name'] as String? ?? '')
                  .toLowerCase()
                  .contains(_searchQuery) ||
              (p['description'] as String? ?? '')
                  .toLowerCase()
                  .contains(_searchQuery))
          .toList();
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Ürün bulunamadı',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              AppColors.surfaceLight.withValues(alpha: 0.3)),
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
                label: Text('Stok',
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
          rows: filtered.map((product) {
            final categoryName =
                product['product_categories']?['name'] ?? 'Kategorisiz';
            final price = (product['price'] as num?)?.toDouble() ?? 0;
            final stockQuantity = product['stock_quantity'] as int? ?? 0;
            final isActive = product['is_active'] as bool? ?? true;

            return DataRow(cells: [
              DataCell(Text(
                product['name'] ?? '',
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockQuantity <= 5
                        ? AppColors.error.withValues(alpha: 0.15)
                        : stockQuantity <= 20
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$stockQuantity',
                    style: TextStyle(
                      color: stockQuantity <= 5
                          ? AppColors.error
                          : stockQuantity <= 20
                              ? AppColors.warning
                              : AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              DataCell(
                Switch(
                  value: isActive,
                  activeThumbColor: AppColors.success,
                  onChanged: (value) =>
                      _toggleProductActive(product['id'], value),
                ),
              ),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: AppColors.info),
                    tooltip: 'Düzenle',
                    onPressed: () => _showProductDialog(
                      product: product,
                      categories: categories,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete,
                        size: 18, color: AppColors.error),
                    tooltip: 'Sil',
                    onPressed: () => _deleteProduct(product['id']),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ==================== Product CRUD ====================

  Future<void> _showProductDialog({
    Map<String, dynamic>? product,
    required List<Map<String, dynamic>> categories,
  }) async {
    final isEdit = product != null;
    final nameController =
        TextEditingController(text: product?['name'] ?? '');
    final priceController = TextEditingController(
        text: (product?['price'] as num?)?.toString() ?? '');
    final stockController = TextEditingController(
        text: (product?['stock_quantity'] as int?)?.toString() ?? '0');
    final descriptionController =
        TextEditingController(text: product?['description'] ?? '');
    String? selectedCategoryId = product?['category_id'] as String? ??
        categories.firstOrNull?['id'];
    bool isActive = product?['is_active'] as bool? ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Ürün Düzenle' : 'Ürün Ekle'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ürün Adı',
                      hintText: 'Örn: Organik Süt',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Fiyat (\u20BA)',
                            hintText: '0.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: stockController,
                          decoration: const InputDecoration(
                            labelText: 'Stok Miktarı',
                            hintText: '0',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    subtitle: Text(
                      isActive
                          ? 'Ürün müşterilere görünür'
                          : 'Ürün müşterilere görünmez',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    value: isActive,
                    activeThumbColor: AppColors.success,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value;
                      });
                    },
                  ),
                ],
              ),
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
      'stock_quantity': int.tryParse(stockController.text.trim()) ?? 0,
      'description': descriptionController.text.trim(),
      'is_active': isActive,
      'merchant_id': widget.merchantId,
    };

    try {
      if (isEdit) {
        await client
            .from('products')
            .update(data)
            .eq('id', product['id']);
      } else {
        await client.from('products').insert(data);
      }

      ref.invalidate(merchantProductsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(isEdit ? 'Ürün güncellendi' : 'Ürün eklendi'),
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

  Future<void> _toggleProductActive(String productId, bool value) async {
    try {
      final client = ref.read(supabaseProvider);
      await client
          .from('products')
          .update({'is_active': value}).eq('id', productId);
      ref.invalidate(merchantProductsProvider(widget.merchantId));
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

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürün Sil'),
        content:
            const Text('Bu ürünü silmek istediğinize emin misiniz?'),
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
      await client.from('products').delete().eq('id', productId);
      ref.invalidate(merchantProductsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün silindi'),
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
