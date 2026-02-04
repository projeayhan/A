import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/merchant_models.dart';
import '../../../core/providers/merchant_provider.dart';
import '../../../core/utils/app_dialogs.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  bool _showLowStock = false;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(storeProductsProvider);
    final lowStockProducts = ref.watch(lowStockProductsProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Search
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        onChanged:
                            (value) => setState(() => _searchQuery = value),
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

                  // Low Stock Filter
                  if (lowStockProducts.isNotEmpty)
                    InkWell(
                      onTap:
                          () => setState(() => _showLowStock = !_showLowStock),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _showLowStock
                                  ? AppColors.error.withAlpha(30)
                                  : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                _showLowStock
                                    ? AppColors.error
                                    : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 18,
                              color:
                                  _showLowStock
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Dusuk Stok (${lowStockProducts.length})',
                              style: TextStyle(
                                color:
                                    _showLowStock
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                fontWeight:
                                    _showLowStock
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),

                  // Category Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ref.watch(productCategoriesProvider).when(
                      loading: () => const SizedBox(
                        width: 120,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (_, __) => const Text('Kategori yuklenemedi'),
                      data: (categories) => DropdownButton<String>(
                        value: _selectedCategory,
                        hint: const Text('Kategori'),
                        underline: const SizedBox(),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tum Kategoriler'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ),
                        ],
                        onChanged:
                            (value) => setState(() => _selectedCategory = value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Import Button
                  OutlinedButton.icon(
                    onPressed: () => _showImportDialog(context),
                    icon: const Icon(Icons.upload_file, size: 20),
                    label: const Text('Toplu Yukle'),
                  ),
                  const SizedBox(width: 12),

                  // Add Button
                  ElevatedButton.icon(
                    onPressed: () => _showAddProductDialog(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Urun Ekle'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Products Table
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Hata: $error')),
            data: (productList) {
              var filtered = _showLowStock ? lowStockProducts : productList;

              if (_selectedCategory != null) {
                filtered =
                    filtered
                        .where((p) => p.categoryId == _selectedCategory)
                        .toList();
              }
              if (_searchQuery.isNotEmpty) {
                filtered =
                    filtered
                        .where(
                          (p) =>
                              p.name.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ||
                              (p.sku?.toLowerCase().contains(
                                    _searchQuery.toLowerCase(),
                                  ) ??
                                  false),
                        )
                        .toList();
              }

              if (filtered.isEmpty) {
                return _buildEmptyState();
              }

              return _buildProductsTable(context, filtered);
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
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 24),
          Text(
            'Urun bulunamadi',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Ilk urununu ekleyerek basla',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddProductDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Urun Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable(
    BuildContext context,
    List<StoreProduct> products,
  ) {
    final categories = ref.watch(productCategoriesProvider).valueOrNull ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 60),
                  Expanded(flex: 3, child: Text('Urun', style: _headerStyle)),
                  Expanded(flex: 2, child: Text('SKU / Barkod', style: _headerStyle)),
                  Expanded(child: Text('Fiyat', style: _headerStyle)),
                  Expanded(child: Text('Stok', style: _headerStyle)),
                  Expanded(child: Text('Durum', style: _headerStyle)),
                  const SizedBox(width: 100),
                ],
              ),
            ),
            // Table Rows
            ...products.map(
              (product) => _ProductRow(
                product: product,
                categories: categories,
                onEdit: () => _showEditProductDialog(context, product),
                onUpdateStock: () => _showUpdateStockDialog(context, product),
                onDelete: () => _showDeleteDialog(context, product),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => _ProductDialog(
            onSave: (product) {
              ref.read(storeProductsProvider.notifier).addProduct(product);
            },
          ),
    );
  }

  void _showEditProductDialog(BuildContext context, StoreProduct product) {
    showDialog(
      context: context,
      builder:
          (context) => _ProductDialog(
            product: product,
            onSave: (updatedProduct) {
              ref
                  .read(storeProductsProvider.notifier)
                  .updateProduct(updatedProduct);
            },
          ),
    );
  }

  void _showUpdateStockDialog(BuildContext context, StoreProduct product) {
    final stockController = TextEditingController(
      text: product.stock.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Stok Guncelle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${product.name} icin yeni stok miktarini girin'),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stok Miktari',
                    suffixText: product.unitType.shortName,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newStock = int.tryParse(stockController.text) ?? 0;
                  ref
                      .read(storeProductsProvider.notifier)
                      .updateStock(product.id, newStock);
                  Navigator.pop(context);
                },
                child: const Text('Guncelle'),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog(BuildContext context, StoreProduct product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Urunu Sil'),
            content: Text(
              '${product.name} silinsin mi? Bu islem geri alinamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(storeProductsProvider.notifier)
                      .deleteProduct(product.id);
                  Navigator.pop(context);
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

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ImportDialog(
        onImport: (products) {
          for (final product in products) {
            ref.read(storeProductsProvider.notifier).addProduct(product);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${products.length} urun basariyla yuklendi'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final StoreProduct product;
  final List<ProductCategory> categories;
  final VoidCallback onEdit;
  final VoidCallback onUpdateStock;
  final VoidCallback onDelete;

  const _ProductRow({
    required this.product,
    required this.categories,
    required this.onEdit,
    required this.onUpdateStock,
    required this.onDelete,
  });

  String _getCategoryName() {
    if (product.categoryId == null) return 'Kategorisiz';
    final category = categories.where((c) => c.id == product.categoryId).firstOrNull;
    return category?.name ?? 'Kategorisiz';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withAlpha(100)),
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
            child:
                product.imageUrl != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
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
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  _getCategoryName(),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),

          // SKU / Barkod
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.sku ?? '-',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                if (product.barcode != null)
                  Text(
                    product.barcode!,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                  '${product.price.toStringAsFixed(0)} TL',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (product.hasDiscount)
                  Text(
                    '${product.originalPrice!.toStringAsFixed(0)} TL',
                    style: TextStyle(
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
                if (product.isOutOfStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Tukendi',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (product.isLowStock)
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${product.stock} ${product.unitType.shortName}',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${product.stock} ${product.unitType.shortName}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),

          // Status
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    product.isAvailable
                        ? AppColors.success.withAlpha(30)
                        : AppColors.error.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                product.isAvailable ? 'Aktif' : 'Pasif',
                style: TextStyle(
                  color:
                      product.isAvailable ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onUpdateStock,
                  icon: const Icon(Icons.inventory, size: 20),
                  tooltip: 'Stok Guncelle',
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Duzenle',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete, size: 20, color: AppColors.error),
                  tooltip: 'Sil',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDialog extends ConsumerStatefulWidget {
  final StoreProduct? product;
  final Function(StoreProduct) onSave;

  const _ProductDialog({this.product, required this.onSave});

  @override
  ConsumerState<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _stockController;
  late TextEditingController _weightController;
  late TextEditingController _lowStockThresholdController;
  late TextEditingController _brandController;
  late TextEditingController _imageUrlController;
  UnitType _selectedUnitType = UnitType.adet;
  bool _isFeatured = false;
  String? _selectedCategoryId;

  // Image upload state
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isUploadingImage = false;
  bool _useUrlInput = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name);
    _descriptionController = TextEditingController(
      text: widget.product?.description,
    );
    _priceController = TextEditingController(
      text: widget.product?.price.toStringAsFixed(0),
    );
    _originalPriceController = TextEditingController(
      text: widget.product?.originalPrice?.toStringAsFixed(0),
    );
    _skuController = TextEditingController(text: widget.product?.sku);
    _barcodeController = TextEditingController(text: widget.product?.barcode);
    _stockController = TextEditingController(
      text: widget.product?.stock.toString() ?? '0',
    );
    _weightController = TextEditingController(
      text: widget.product?.weight?.toString(),
    );
    _lowStockThresholdController = TextEditingController(
      text: widget.product?.lowStockThreshold.toString() ?? '5',
    );
    _brandController = TextEditingController(text: widget.product?.brand);
    _selectedCategoryId = widget.product?.categoryId;
    _imageUrlController = TextEditingController(
      text: widget.product?.imageUrl,
    );
    _selectedUnitType = widget.product?.unitType ?? UnitType.adet;
    _isFeatured = widget.product?.isFeatured ?? false;
    _useUrlInput = widget.product?.imageUrl != null || _selectedImageBytes == null;
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
    _weightController.dispose();
    _lowStockThresholdController.dispose();
    _brandController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                const SizedBox(height: 24),

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
                          labelText: 'Urun Adi',
                        ),
                        validator:
                            (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _brandController,
                        decoration: const InputDecoration(labelText: 'Marka'),
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
                  decoration: const InputDecoration(labelText: 'Aciklama'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Category
                _buildCategoryDropdown(),
                const SizedBox(height: 16),

                // Price Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Satis Fiyati',
                          suffixText: 'TL',
                        ),
                        keyboardType: TextInputType.number,
                        validator:
                            (v) => v?.isEmpty ?? true ? 'Zorunlu alan' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _originalPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Liste Fiyati',
                          suffixText: 'TL',
                          helperText: 'Indirimli gosterim icin',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Unit Type & Weight Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<UnitType>(
                        value: _selectedUnitType,
                        decoration: const InputDecoration(
                          labelText: 'Birim Tipi',
                        ),
                        items: UnitType.values
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedUnitType = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        decoration: InputDecoration(
                          labelText: 'Agirlik/Miktar',
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
                          labelText: 'Stok Miktari',
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
                          labelText: 'Dusuk Stok Esigi',
                          helperText: 'Uyari gosterilecek miktar',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Featured Switch
                SwitchListTile(
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                  title: const Text('One Cikan Urun'),
                  subtitle: const Text('Bu urun ana sayfada gosterilsin'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Iptal'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text(isEditing ? 'Guncelle' : 'Ekle'),
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

  Widget _buildCategoryDropdown() {
    final categories = ref.watch(productCategoriesProvider);

    return categories.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Kategori yuklenemedi: $e'),
      data: (categoryList) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategoryId != null &&
                     categoryList.any((c) => c.id == _selectedCategoryId)
                  ? _selectedCategoryId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Kategori',
              ),
              items: categoryList.map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                ),
              ).toList(),
              onChanged: (value) {
                setState(() => _selectedCategoryId = value);
              },
              // Kategori opsiyonel
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Urun Fotografı',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // Toggle between URL and Upload
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('URL'), icon: Icon(Icons.link, size: 16)),
                  ButtonSegment(value: false, label: Text('Yukle'), icon: Icon(Icons.upload, size: 16)),
                ],
                selected: {_useUrlInput},
                onSelectionChanged: (selection) {
                  setState(() => _useUrlInput = selection.first);
                },
                style: ButtonStyle(
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
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Yukleniyor...'),
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
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 40,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Resim secmek icin tiklayin',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 4),
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
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ],

          // Preview existing image
          if (_useUrlInput && _imageUrlController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _imageUrlController.text,
                height: 80,
                width: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 80,
                  width: 80,
                  color: AppColors.error.withAlpha(30),
                  child: const Icon(Icons.broken_image, color: AppColors.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = pickedFile.name;
        });
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Resim secilemedi: $e');
      }
    }
  }

  Future<String?> _uploadImageToStorage() async {
    if (_selectedImageBytes == null) return null;

    setState(() => _isUploadingImage = true);

    try {
      final supabase = Supabase.instance.client;
      final fileName = 'products/${DateTime.now().millisecondsSinceEpoch}_$_selectedImageName';

      await supabase.storage.from('images').uploadBinary(
        fileName,
        _selectedImageBytes!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final publicUrl = supabase.storage.from('images').getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Resim yuklenemedi: $e');
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

    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    String? imageUrl;

    // Handle image URL
    if (_useUrlInput) {
      imageUrl = _imageUrlController.text.isNotEmpty ? _imageUrlController.text : widget.product?.imageUrl;
    } else if (_selectedImageBytes != null) {
      // Upload image to storage
      imageUrl = await _uploadImageToStorage();
    } else {
      imageUrl = widget.product?.imageUrl;
    }

    final product = StoreProduct(
      id:
          widget.product?.id ??
          const Uuid().v4(),
      storeId: widget.product?.storeId ?? merchant.id,
      categoryId: _selectedCategoryId ?? widget.product?.categoryId,
      name: _nameController.text,
      description:
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
      imageUrl: imageUrl,
      price: double.parse(_priceController.text),
      originalPrice:
          _originalPriceController.text.isEmpty
              ? null
              : double.parse(_originalPriceController.text),
      sku: _skuController.text.isEmpty ? null : _skuController.text,
      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
      stock: int.tryParse(_stockController.text) ?? 0,
      weight: _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
      unitType: _selectedUnitType,
      lowStockThreshold: int.tryParse(_lowStockThresholdController.text) ?? 5,
      brand: _brandController.text.isEmpty ? null : _brandController.text,
      isAvailable: widget.product?.isAvailable ?? true,
      isFeatured: _isFeatured,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
    );

    widget.onSave(product);
    if (mounted) Navigator.pop(context);
  }
}

class _ImportDialog extends StatefulWidget {
  final Function(List<StoreProduct>) onImport;

  const _ImportDialog({required this.onImport});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _csvController = TextEditingController();
  List<StoreProduct> _parsedProducts = [];
  String? _errorMessage;
  bool _isParsing = false;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  void _parseCSV() {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _parsedProducts = [];
    });

    try {
      final lines = _csvController.text.trim().split('\n');
      if (lines.isEmpty) {
        setState(() {
          _errorMessage = 'CSV verisi bos';
          _isParsing = false;
        });
        return;
      }

      // Skip header if present
      final startIndex = lines[0].toLowerCase().contains('urun') ||
                         lines[0].toLowerCase().contains('name') ? 1 : 0;

      final products = <StoreProduct>[];
      for (var i = startIndex; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(';').map((e) => e.trim()).toList();
        if (parts.length < 3) {
          setState(() {
            _errorMessage = 'Satir ${i + 1}: En az 3 sutun gerekli (Urun Adi;Fiyat;Stok)';
            _isParsing = false;
          });
          return;
        }

        final name = parts[0];
        final price = double.tryParse(parts[1].replaceAll(',', '.'));
        final stock = int.tryParse(parts[2]);

        if (name.isEmpty || price == null || stock == null) {
          setState(() {
            _errorMessage = 'Satir ${i + 1}: Gecersiz veri formati';
            _isParsing = false;
          });
          return;
        }

        products.add(StoreProduct(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          storeId: '',
          categoryId: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
          name: name,
          description: parts.length > 4 ? parts[4] : null,
          price: price,
          stock: stock,
          sku: parts.length > 5 ? parts[5] : null,
          barcode: parts.length > 6 ? parts[6] : null,
          unitType: parts.length > 7 ? UnitTypeExtension.fromString(parts[7]) : UnitType.adet,
          createdAt: DateTime.now(),
        ));
      }

      setState(() {
        _parsedProducts = products;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ayristirma hatasi: $e';
        _isParsing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Toplu Urun Yukleme',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Format Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'CSV Formati',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Her satir bir urun icin olmali. Sutunlar noktali virgul (;) ile ayrilmali.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Urun Adi;Fiyat;Stok;Kategori;Aciklama;SKU;Barkod;Birim\n'
                      'Ornek Urun;99.90;50;Gida;Aciklama;SKU001;8691234567890;adet',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CSV Input
            Text(
              'CSV Verisi',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _csvController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Urun verilerini buraya yapiştirin...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Parse Button
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isParsing ? null : _parseCSV,
                  icon: _isParsing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Kontrol Et'),
                ),
                const SizedBox(width: 12),
                if (_parsedProducts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_parsedProducts.length} urun hazir',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Preview
            if (_parsedProducts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Onizleme',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _parsedProducts.length,
                  itemBuilder: (context, index) {
                    final product = _parsedProducts[index];
                    return ListTile(
                      dense: true,
                      title: Text(product.name),
                      subtitle: Text(
                        '${product.price.toStringAsFixed(2)} TL | ${product.stock} ${product.unitType.shortName}',
                      ),
                      trailing: product.sku != null
                        ? Text(product.sku!, style: TextStyle(color: AppColors.textMuted))
                        : null,
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Iptal'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _parsedProducts.isEmpty
                      ? null
                      : () {
                          widget.onImport(_parsedProducts);
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text('${_parsedProducts.length} Urun Yukle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
