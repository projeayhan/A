import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';
import '../../../core/services/supabase_service.dart';

// Unit type enum for product weight/quantity
enum _UnitType {
  adet('Adet', 'adet'),
  kg('Kilogram', 'kg'),
  gram('Gram', 'g'),
  litre('Litre', 'lt'),
  ml('Mililitre', 'ml');

  final String displayName;
  final String shortName;
  const _UnitType(this.displayName, this.shortName);

  static _UnitType fromString(String? value) {
    if (value == null) return _UnitType.adet;
    return _UnitType.values.firstWhere(
      (e) => e.name == value || e.shortName == value,
      orElse: () => _UnitType.adet,
    );
  }
}

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
  bool _showLowStock = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _countLowStockProducts(List<Map<String, dynamic>> products) {
    return products.where((p) {
      final stock = p['stock'] as int? ?? 0;
      final threshold = p['low_stock_threshold'] as int? ?? 5;
      return stock <= threshold && stock > 0;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync =
        ref.watch(merchantProductsProvider(widget.merchantId));
    final categoriesAsync =
        ref.watch(merchantProductCategoriesProvider(widget.merchantId));

    final allProducts = productsAsync.valueOrNull ?? [];
    final lowStockCount = _countLowStockProducts(allProducts);

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
                        ref.invalidate(merchantProductCategoriesProvider(
                            widget.merchantId));
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Toplu yükleme özelliği yakında eklenecek'),
                            backgroundColor: AppColors.info,
                          ),
                        );
                      },
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Toplu Yükle'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showAutoImageSearch(),
                      icon: const Icon(Icons.image_search, size: 18),
                      label: const Text('Resimleri Bul'),
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

            // Filters row: search + low stock + category dropdown
            Row(
              children: [
                // Search bar
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Ürün ara (ad, SKU, barkod)...',
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

                // Low stock filter button
                if (lowStockCount > 0)
                  InkWell(
                    onTap: () =>
                        setState(() => _showLowStock = !_showLowStock),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _showLowStock
                            ? AppColors.error.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showLowStock
                              ? AppColors.error
                              : AppColors.surfaceLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 18,
                            color: _showLowStock
                                ? AppColors.error
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Düşük Stok ($lowStockCount)',
                            style: TextStyle(
                              color: _showLowStock
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: _showLowStock
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (lowStockCount > 0) const SizedBox(width: 16),

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

            // Products list
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: productsAsync.when(
                  data: (products) => _buildProductsList(
                    products,
                    categoriesAsync.valueOrNull ?? [],
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Hata: $e',
                        style: const TextStyle(color: AppColors.error)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> categories,
  ) {
    // Apply filters
    var filtered = products;

    if (_showLowStock) {
      filtered = filtered.where((p) {
        final stock = p['stock'] as int? ?? 0;
        final threshold = p['low_stock_threshold'] as int? ?? 5;
        return stock <= threshold && stock > 0;
      }).toList();
    }

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
                  .contains(_searchQuery) ||
              (p['sku'] as String? ?? '')
                  .toLowerCase()
                  .contains(_searchQuery) ||
              (p['barcode'] as String? ?? '')
                  .toLowerCase()
                  .contains(_searchQuery))
          .toList();
    }

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.surfaceLight)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 60),
              Expanded(
                  flex: 3,
                  child: Text('Ürün', style: _headerStyle)),
              Expanded(
                  flex: 2,
                  child: Text('SKU / Barkod', style: _headerStyle)),
              Expanded(
                  child: Text('Fiyat', style: _headerStyle)),
              Expanded(
                  child: Text('Stok', style: _headerStyle)),
              Expanded(
                  child: Text('Durum', style: _headerStyle)),
              const SizedBox(width: 120),
            ],
          ),
        ),
        // Product Rows
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final product = filtered[index];
              return _buildProductRow(product, categories);
            },
          ),
        ),
      ],
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 24),
          Text(
            'Ürün bulunamadı',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'İlk ürünü ekleyerek başlayın',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final categoriesAsync = ref
                  .read(merchantProductCategoriesProvider(widget.merchantId));
              _showProductDialog(
                  categories: categoriesAsync.valueOrNull ?? []);
            },
            icon: const Icon(Icons.add),
            label: const Text('Ürün Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> categories,
  ) {
    final categoryName =
        product['product_categories']?['name'] ?? 'Kategorisiz';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final originalPrice = (product['original_price'] as num?)?.toDouble();
    final hasDiscount =
        originalPrice != null && originalPrice > price;
    final stock = product['stock'] as int? ?? 0;
    final lowStockThreshold = product['low_stock_threshold'] as int? ?? 5;
    final isActive = product['is_available'] as bool? ?? true;
    final isFeatured = product['is_featured'] as bool? ?? false;
    final imageUrl = product['image_url'] as String?;
    final sku = product['sku'] as String?;
    final barcode = product['barcode'] as String?;
    final unitType = _UnitType.fromString(product['weight_unit'] as String?);
    final isOutOfStock = stock <= 0;
    final isLowStock = stock > 0 && stock <= lowStockThreshold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppColors.surfaceLight.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image,
                          color: AppColors.textMuted,
                          size: 24),
                    ),
                  )
                : const Icon(Icons.image, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),

          // Name & Category
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        product['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFeatured) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star,
                          size: 16, color: AppColors.warning),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  categoryName,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),

          // SKU / Barcode
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sku ?? '-',
                  style:
                      const TextStyle(color: AppColors.textSecondary),
                ),
                if (barcode != null && barcode.isNotEmpty)
                  Text(
                    barcode,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),

          // Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${price.toStringAsFixed(2)} \u20BA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (hasDiscount)
                  Text(
                    '${originalPrice.toStringAsFixed(2)} \u20BA',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ),

          // Stock
          Expanded(
            child: Row(
              children: [
                if (isOutOfStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Tükendi',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (isLowStock)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '$stock ${unitType.shortName}',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '$stock ${unitType.shortName}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),

          // Status
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    color: isActive ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _toggleProductAvailability(product['id'], isActive),
                  icon: Icon(
                    isActive ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 18,
                    color: isActive ? AppColors.warning : AppColors.success,
                  ),
                  tooltip: isActive ? 'Pasife Al' : 'Aktif Et',
                ),
                IconButton(
                  onPressed: () =>
                      _showUpdateStockDialog(product),
                  icon: const Icon(Icons.inventory,
                      size: 18, color: AppColors.textSecondary),
                  tooltip: 'Stok Güncelle',
                ),
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
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Quick Stock Update Dialog ====================

  Future<void> _showUpdateStockDialog(Map<String, dynamic> product) async {
    final stockController = TextEditingController(
        text: (product['stock'] as int?)?.toString() ?? '0');
    final unitType =
        _UnitType.fromString(product['weight_unit'] as String?);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Stok Güncelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${product['name']} için yeni stok miktarını girin'),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Stok Miktarı',
                suffixText: unitType.shortName,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final client = ref.read(supabaseProvider);
      await client.from('products').update({
        'stock': int.tryParse(stockController.text.trim()) ?? 0,
      }).eq('id', product['id']);
      ref.invalidate(merchantProductsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stok güncellendi'),
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

  // ==================== Auto Image Search ====================

  Future<void> _showAutoImageSearch() async {
    final products =
        ref.read(merchantProductsProvider(widget.merchantId)).valueOrNull ??
            [];
    final noImage = products
        .where((p) =>
            p['image_url'] == null ||
            (p['image_url'] as String).isEmpty)
        .toList();

    if (noImage.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm ürünlerin resmi mevcut!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${noImage.length} ürün resmi eksik. Otomatik resim arama özelliği yakında eklenecek.'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  // ==================== Product CRUD ====================

  Future<void> _showProductDialog({
    Map<String, dynamic>? product,
    required List<Map<String, dynamic>> categories,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AdminProductDialog(
        merchantId: widget.merchantId,
        product: product,
        categories: categories,
        supabaseClient: ref.read(supabaseProvider),
      ),
    );

    if (result == true) {
      ref.invalidate(merchantProductsProvider(widget.merchantId));
    }
  }

  Future<void> _toggleProductAvailability(String productId, bool currentlyActive) async {
    try {
      final client = ref.read(supabaseProvider);
      await client.from('products').update({
        'is_available': !currentlyActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);
      ref.invalidate(merchantProductsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentlyActive ? 'Ürün aktif edildi' : 'Ürün pasife alındı'),
            backgroundColor: !currentlyActive ? AppColors.success : AppColors.warning,
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

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ürün Sil'),
        content:
            const Text('Bu ürünü silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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

// ==================== Product Add/Edit Dialog ====================

class _AdminProductDialog extends StatefulWidget {
  final String merchantId;
  final Map<String, dynamic>? product;
  final List<Map<String, dynamic>> categories;
  final dynamic supabaseClient;

  const _AdminProductDialog({
    required this.merchantId,
    this.product,
    required this.categories,
    required this.supabaseClient,
  });

  @override
  State<_AdminProductDialog> createState() => _AdminProductDialogState();
}

class _AdminProductDialogState extends State<_AdminProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _skuController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockThresholdController;
  late final TextEditingController _weightController;
  late final TextEditingController _brandController;
  late final TextEditingController _imageUrlController;

  _UnitType _selectedUnitType = _UnitType.adet;
  bool _isFeatured = false;
  bool _isActive = true;
  String? _selectedCategoryId;

  // Image upload state
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isUploadingImage = false;
  bool _useUrlInput = true;
  bool _isSaving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?['name'] ?? '');
    _descriptionController =
        TextEditingController(text: p?['description'] ?? '');
    _priceController = TextEditingController(
        text: (p?['price'] as num?)?.toString() ?? '');
    _originalPriceController = TextEditingController(
        text: (p?['original_price'] as num?)?.toString() ?? '');
    _skuController = TextEditingController(text: p?['sku'] ?? '');
    _barcodeController = TextEditingController(text: p?['barcode'] ?? '');
    _stockController = TextEditingController(
        text: (p?['stock'] as int?)?.toString() ?? '0');
    _lowStockThresholdController = TextEditingController(
        text: (p?['low_stock_threshold'] as int?)?.toString() ?? '5');
    _weightController = TextEditingController(
        text: (p?['weight'] as num?)?.toString() ?? '');
    _brandController = TextEditingController(text: p?['brand'] ?? '');
    _imageUrlController =
        TextEditingController(text: p?['image_url'] ?? '');

    _selectedCategoryId = p?['category_id'] as String?;
    _selectedUnitType =
        _UnitType.fromString(p?['weight_unit'] as String?);
    _isFeatured = p?['is_featured'] as bool? ?? false;
    _isActive = p?['is_available'] as bool? ?? true;
    _useUrlInput =
        p?['image_url'] != null || _selectedImageBytes == null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _lowStockThresholdController.dispose();
    _weightController.dispose();
    _brandController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    _isEdit ? 'Ürünü Düzenle' : 'Yeni Ürün Ekle',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Upload Section
                      _buildImageSection(),
                      const SizedBox(height: 20),

                      // Name & Brand Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Ürün Adı *',
                                hintText: 'Örn: Organik Süt',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Zorunlu alan'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _brandController,
                              decoration: const InputDecoration(
                                labelText: 'Marka',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // SKU & Barcode Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skuController,
                              decoration: const InputDecoration(
                                labelText: 'SKU',
                                helperText: 'Stok kodu',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _barcodeController,
                              decoration: const InputDecoration(
                                labelText: 'Barkod',
                                helperText: 'EAN/UPC kodu',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama',
                          hintText: 'Ürün açıklaması...',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                        ),
                        dropdownColor: AppColors.surface,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Kategorisiz'),
                          ),
                          ...widget.categories
                              .map((cat) => DropdownMenuItem<String>(
                                    value: cat['id'] as String,
                                    child: Text(cat['name'] ?? ''),
                                  )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCategoryId = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Satış Fiyatı *',
                                suffixText: '\u20BA',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Zorunlu alan'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _originalPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Liste Fiyatı',
                                suffixText: '\u20BA',
                                helperText: 'İndirimli gösterim için',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Unit Type & Weight Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<_UnitType>(
                              initialValue: _selectedUnitType,
                              decoration: const InputDecoration(
                                labelText: 'Birim Tipi',
                              ),
                              dropdownColor: AppColors.surface,
                              items: _UnitType.values
                                  .map((u) => DropdownMenuItem<_UnitType>(
                                        value: u,
                                        child: Text(u.displayName),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(
                                      () => _selectedUnitType = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              decoration: InputDecoration(
                                labelText: 'Ağırlık/Miktar',
                                suffixText: _selectedUnitType.shortName,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Stock & Low Stock Threshold Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              decoration: InputDecoration(
                                labelText: 'Stok Miktarı',
                                suffixText: _selectedUnitType.shortName,
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lowStockThresholdController,
                              decoration: const InputDecoration(
                                labelText: 'Düşük Stok Eşiği',
                                helperText: 'Uyarı gösterilecek miktar',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Featured Switch
                      SwitchListTile(
                        title: const Text('Öne Çıkan Ürün'),
                        subtitle: const Text(
                          'Bu ürün ana sayfada gösterilsin',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        value: _isFeatured,
                        activeTrackColor:
                            AppColors.warning.withValues(alpha: 0.4),
                        thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                          (states) {
                            if (states.contains(WidgetState.selected)) {
                              return const Icon(Icons.star,
                                  size: 16, color: AppColors.warning);
                            }
                            return null;
                          },
                        ),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() => _isFeatured = value);
                        },
                      ),

                      // Active Switch
                      SwitchListTile(
                        title: const Text('Aktif'),
                        subtitle: Text(
                          _isActive
                              ? 'Ürün müşterilere görünür'
                              : 'Ürün müşterilere görünmez',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        value: _isActive,
                        activeTrackColor:
                            AppColors.success.withValues(alpha: 0.4),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() => _isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context, false),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Güncelle' : 'Ekle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'Ürün Fotoğrafı',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const Spacer(),
              // Toggle between URL and Upload
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('URL'),
                    icon: Icon(Icons.link, size: 16),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Yükle'),
                    icon: Icon(Icons.upload, size: 16),
                  ),
                ],
                selected: {_useUrlInput},
                onSelectionChanged: (selection) {
                  setState(() => _useUrlInput = selection.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_useUrlInput) ...[
            // URL Input
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Resim URL',
                hintText: 'https://example.com/image.jpg',
                prefixIcon: Icon(Icons.link, size: 20),
              ),
            ),
            // Preview existing image
            if (_imageUrlController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _imageUrlController.text,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 80,
                    width: 80,
                    color: AppColors.error.withValues(alpha: 0.12),
                    child: const Icon(Icons.broken_image,
                        color: AppColors.error),
                  ),
                ),
              ),
            ],
          ] else ...[
            // File Upload
            InkWell(
              onTap: _isUploadingImage ? null : _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Yükleniyor...'),
                          ],
                        ),
                      )
                    : _selectedImageBytes != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _selectedImageBytes!,
                                  width: double.infinity,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedImageBytes = null;
                                      _selectedImageName = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 40,
                                  color: AppColors.textMuted),
                              SizedBox(height: 8),
                              Text(
                                'Resim seçmek için tıklayın',
                                style: TextStyle(
                                    color: AppColors.textMuted),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'PNG, JPG, WEBP (Max 5MB)',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
            if (_selectedImageName != null) ...[
              const SizedBox(height: 8),
              Text(
                _selectedImageName!,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim seçilemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToStorage() async {
    if (_selectedImageBytes == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final client = widget.supabaseClient;
      final fileName =
          'products/${widget.merchantId}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage.from('products').uploadBinary(
            fileName,
            _selectedImageBytes!,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', upsert: true),
          );

      final url =
          client.storage.from('products').getPublicUrl(fileName);
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resim yüklenemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Handle image URL
      String? imageUrl;
      if (_useUrlInput) {
        imageUrl = _imageUrlController.text.isNotEmpty
            ? _imageUrlController.text.trim()
            : widget.product?['image_url'];
      } else if (_selectedImageBytes != null) {
        imageUrl = await _uploadImageToStorage();
      } else {
        imageUrl = widget.product?['image_url'];
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'price':
            double.tryParse(_priceController.text.trim()) ?? 0,
        'original_price':
            _originalPriceController.text.trim().isNotEmpty
                ? double.tryParse(_originalPriceController.text.trim())
                : null,
        'stock':
            int.tryParse(_stockController.text.trim()) ?? 0,
        'low_stock_threshold':
            int.tryParse(_lowStockThresholdController.text.trim()) ?? 5,
        'category_id': _selectedCategoryId,
        'sku': _skuController.text.trim().isNotEmpty
            ? _skuController.text.trim()
            : null,
        'barcode': _barcodeController.text.trim().isNotEmpty
            ? _barcodeController.text.trim()
            : null,
        'brand': _brandController.text.trim().isNotEmpty
            ? _brandController.text.trim()
            : null,
        'weight': _weightController.text.trim().isNotEmpty
            ? double.tryParse(_weightController.text.trim())
            : null,
        'weight_unit': _selectedUnitType.name,
        'is_featured': _isFeatured,
        'is_available': _isActive,
        'image_url': imageUrl,
        'merchant_id': widget.merchantId,
      };

      final client = widget.supabaseClient;

      if (_isEdit) {
        await client
            .from('products')
            .update(data)
            .eq('id', widget.product!['id']);
      } else {
        await client.from('products').insert(data);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isEdit ? 'Ürün güncellendi' : 'Ürün eklendi'),
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
