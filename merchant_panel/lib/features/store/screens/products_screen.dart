import 'package:excel/excel.dart' as exc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
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

                  // Auto Image Button
                  OutlinedButton.icon(
                    onPressed: () => _showAutoImageDialog(context),
                    icon: const Icon(Icons.image_search, size: 20),
                    label: const Text('Resimleri Bul'),
                  ),
                  const SizedBox(width: 12),

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
          (dialogContext) => AlertDialog(
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(dialogContext);
                  try {
                    await ref
                        .read(storeProductsProvider.notifier)
                        .deleteProduct(product.id);
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Urun silindi'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Urun silinemedi: $e'),
                        backgroundColor: AppColors.error,
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

  void _showAutoImageDialog(BuildContext context) {
    final products = ref.read(storeProductsProvider).valueOrNull ?? [];
    final noImage = products.where((p) => p.imageUrl == null || p.imageUrl!.isEmpty).toList();

    if (noImage.isEmpty) {
      AppDialogs.showSuccess(context, 'Tum urunlerin resmi mevcut!');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AutoImageDialog(
        totalProducts: noImage.length,
        onStart: () async {
          return await ref.read(storeProductsProvider.notifier).autoFetchProductImages(
            onProgress: null,
          );
        },
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImportDialog(
        onImport: (products) async {
          return await ref.read(storeProductsProvider.notifier).bulkAddProducts(products);
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

  // Variants
  List<ProductVariant> _variants = [];

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
    _variants = List<ProductVariant>.from(widget.product?.variants ?? []);
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
                const SizedBox(height: 16),

                // Variants Section
                _buildVariantsSection(),
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedImageBytes = result.files.single.bytes!;
          _selectedImageName = result.files.single.name;
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
        fileOptions: const FileOptions(cacheControl: '31536000', upsert: true),
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

  // ========== VARIANTS SECTION ==========
  Widget _buildVariantsSection() {
    // Grup isimleri
    final groupNames = _variants.map((v) => v.name).toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Urun Secenekleri',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddVariantGroupDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Grup Ekle'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        if (groupNames.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Renk, beden gibi secenekler ekleyebilirsiniz',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        for (final groupName in groupNames) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Grup basligi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        groupName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showAddVariantValueDialog(groupName),
                        icon: Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                        tooltip: 'Secenek Ekle',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _variants.removeWhere((v) => v.name == groupName);
                          });
                        },
                        icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                        tooltip: 'Grubu Sil',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
                // Secenekler
                ...() {
                  final groupVariants = _variants.where((v) => v.name == groupName).toList();
                  return groupVariants.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final v = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        border: idx < groupVariants.length - 1
                            ? Border(bottom: BorderSide(color: AppColors.border.withAlpha(80)))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(v.value, style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                          ),
                          if (v.priceModifier != null && v.priceModifier != 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '${v.priceModifier! > 0 ? '+' : ''}${v.priceModifier!.toStringAsFixed(0)} TL',
                                style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          if (v.stock != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                'Stok: ${v.stock}',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _variants.remove(v);
                              });
                            },
                            icon: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showAddVariantGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Secenek Grubu Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Grup Adi',
                hintText: 'Ornek: Renk, Beden, Boyut...',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final suggestion in ['Renk', 'Beden', 'Boyut', 'Malzeme', 'Model'])
                  ActionChip(
                    label: Text(suggestion, style: const TextStyle(fontSize: 12)),
                    onPressed: () => controller.text = suggestion,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.background,
                    side: BorderSide(color: AppColors.border),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _showAddVariantValueDialog(controller.text.trim());
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showAddVariantValueDialog(String groupName) {
    final valueController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$groupName - Secenek Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Deger',
                hintText: groupName.toLowerCase().contains('renk')
                    ? 'Ornek: Kirmizi, Mavi...'
                    : groupName.toLowerCase().contains('beden')
                        ? 'Ornek: S, M, L, XL...'
                        : 'Deger girin',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Fiyat Farki',
                      hintText: '0',
                      suffixText: 'TL',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stok',
                      hintText: 'Opsiyonel',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () {
              if (valueController.text.trim().isNotEmpty) {
                setState(() {
                  _variants.add(ProductVariant(
                    name: groupName,
                    value: valueController.text.trim(),
                    priceModifier: double.tryParse(priceController.text),
                    stock: int.tryParse(stockController.text),
                  ));
                });
                Navigator.pop(ctx);
                // Hemen bir daha eklemek isteyebilir
                _showAddVariantValueDialog(groupName);
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
      variants: _variants.isNotEmpty ? _variants : null,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
    );

    widget.onSave(product);
    if (mounted) Navigator.pop(context);
  }
}

class _ImportDialog extends ConsumerStatefulWidget {
  final Future<int> Function(List<StoreProduct>) onImport;

  const _ImportDialog({required this.onImport});

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  List<ProductCategory> get _categories => ref.watch(productCategoriesProvider).valueOrNull ?? [];
  String get _merchantId => ref.watch(currentMerchantProvider).valueOrNull?.id ?? '';
  int _step = 0; // 0: sablon indir, 1: excel yukle, 2: onizleme, 3: sonuc
  List<StoreProduct> _parsedProducts = [];
  Map<String, List<StoreProduct>> _groupedProducts = {};
  String? _errorMessage;
  String? _fileName;
  bool _isLoading = false;
  bool _isUploading = false;
  int _uploadedCount = 0;
  // Otomatik resim
  bool _isFetchingImages = false;
  int _imagesFound = 0;
  int _imagesTotal = 0;
  bool _imagesDone = false;

  // ========== SABLON INDIRME ==========
  Future<void> _downloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final excel = exc.Excel.createExcel();

      final headerStyle = exc.CellStyle(
        bold: true,
        fontSize: 11,
        backgroundColorHex: exc.ExcelColor.fromHexString('#4CAF50'),
        fontColorHex: exc.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: exc.HorizontalAlign.Center,
      );

      final exampleStyle = exc.CellStyle(
        fontSize: 10,
        fontColorHex: exc.ExcelColor.fromHexString('#999999'),
        italic: true,
      );

      final categoryHintStyle = exc.CellStyle(
        fontSize: 10,
        fontColorHex: exc.ExcelColor.fromHexString('#666666'),
        italic: true,
      );

      final headers = [
        exc.TextCellValue('Urun Adi *'),
        exc.TextCellValue('Fiyat *'),
        exc.TextCellValue('Kategori'),
        exc.TextCellValue('Aciklama'),
        exc.TextCellValue('SKU'),
        exc.TextCellValue('Barkod'),
        exc.TextCellValue('Stok'),
        exc.TextCellValue('Birim (adet/kg/gram/litre/ml)'),
        exc.TextCellValue('Marka'),
      ];

      final categoryNames = _categories.map((c) => c.name).join(', ');

      final exampleRow = [
        exc.TextCellValue('Ornek Urun'),
        exc.DoubleCellValue(29.90),
        exc.TextCellValue(_categories.isNotEmpty ? _categories.first.name : 'Icecekler'),
        exc.TextCellValue('Urun aciklamasi'),
        exc.TextCellValue('SKU001'),
        exc.TextCellValue('8691234567890'),
        exc.IntCellValue(100),
        exc.TextCellValue('adet'),
        exc.TextCellValue('Marka Adi'),
      ];

      // Tek sayfa: Urunler
      final sheet = excel['Urunler'];
      sheet.setColumnWidth(0, 25); // Urun Adi
      sheet.setColumnWidth(1, 12); // Fiyat
      sheet.setColumnWidth(2, 20); // Kategori
      sheet.setColumnWidth(3, 30); // Aciklama
      sheet.setColumnWidth(4, 15); // SKU
      sheet.setColumnWidth(5, 18); // Barkod
      sheet.setColumnWidth(6, 10); // Stok
      sheet.setColumnWidth(7, 28); // Birim
      sheet.setColumnWidth(8, 15); // Marka

      // Header satiri
      sheet.appendRow(headers);
      for (int col = 0; col < headers.length; col++) {
        sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
      }

      // Ornek satiri
      sheet.appendRow(exampleRow);
      for (int col = 0; col < exampleRow.length; col++) {
        sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1)).cellStyle = exampleStyle;
      }

      // Kategori ipucu satiri (3. satir)
      final hintRow = List<exc.CellValue>.generate(headers.length, (_) => exc.TextCellValue(''));
      hintRow[2] = exc.TextCellValue('Kategoriler: $categoryNames');
      sheet.appendRow(hintRow);
      sheet.cell(exc.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 2)).cellStyle = categoryHintStyle;

      // Varsayilan Sheet1 sil
      excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel olusturulamadi');

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'urun_sablonu.xlsx',
      );

      if (mounted) {
        setState(() {
          _step = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sablon olusturma hatasi: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ========== EXCEL PARSE ==========
  Future<void> _pickAndParseExcel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parsedProducts = [];
      _groupedProducts = {};
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Dosya okunamadi';
          _isLoading = false;
        });
        return;
      }

      _fileName = result.files.first.name;
      final isCsv = _fileName!.toLowerCase().endsWith('.csv');

      // CSV veya Excel parse
      List<List<String>> dataRows = [];

      if (isCsv) {
        final csvStr = String.fromCharCodes(bytes);
        final lines = csvStr.split('\n').where((l) => l.trim().isNotEmpty).toList();
        for (final line in lines) {
          dataRows.add(line.split(';').map((c) => c.trim()).toList());
        }
      } else {
        exc.Excel excel;
        try {
          excel = exc.Excel.decodeBytes(bytes);
        } catch (e) {
          setState(() {
            _errorMessage = 'Excel okunamadi: ${e.toString().length > 100 ? e.toString().substring(0, 100) : e}';
            _isLoading = false;
          });
          return;
        }

        // Ilk veri sayfasini bul
        for (final sheetName in excel.tables.keys) {
          if (sheetName.trim().toLowerCase() == 'bilgi') continue;
          final sheet = excel.tables[sheetName];
          if (sheet == null || sheet.rows.length < 2) continue;
          for (final row in sheet.rows) {
            dataRows.add(row.map((c) => c?.value?.toString().trim() ?? '').toList());
          }
          break; // Sadece ilk veri sayfasi
        }
      }

      // Kategori adi -> id eslestirmesi
      final categoryMap = <String, String?>{};
      for (final cat in _categories) {
        categoryMap[cat.name.trim().toLowerCase()] = cat.id;
      }

      final allProducts = <StoreProduct>[];
      final grouped = <String, List<StoreProduct>>{};
      final uuid = const Uuid();
      final newCategoryNames = <String>{};
      int errorCount = 0;

      if (dataRows.length < 2) {
        setState(() {
          _errorMessage = 'Dosyada yeterli veri bulunamadi';
          _isLoading = false;
        });
        return;
      }

      // Kolon tespiti
      int colName = 0, colPrice = -1, colCategory = -1, colDescription = -1;
      int colSku = -1, colBarcode = -1, colStock = -1, colUnit = -1, colBrand = -1;
      int dataStartRow = 1;

      final headerRow = dataRows[0];

      // 1) Bizim sablon mu? (Urun Adi + Fiyat header)
      final h0 = headerRow.isNotEmpty ? headerRow[0].toLowerCase() : '';
      final h1 = headerRow.length > 1 ? headerRow[1].toLowerCase() : '';
      if (h0.contains('urun') && h1.contains('fiyat')) {
        // Sablon formati: Urun Adi, Fiyat, Kategori, Aciklama, SKU, Barkod, Stok, Birim, Marka
        colName = 0; colPrice = 1; colCategory = 2; colDescription = 3;
        colSku = 4; colBarcode = 5; colStock = 6; colUnit = 7; colBrand = 8;
        dataStartRow = 2; // baslik + ornek satiri atla
      } else {
        // 2) Akilli kolon tespiti
        for (int c = 0; c < headerRow.length; c++) {
          final h = headerRow[c].toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
          if (h.contains('urun') || h.contains('isim') || h == 'ad' || h == 'adi' || h.contains('name')) {
            if (colName == 0 && c > 0) colName = c; // sadece ilk eslesen (varsayilan 0 degilse)
          } else if (h.contains('fiyat') || h.contains('price') || h.contains('tutar')) {
            colPrice = c;
          } else if (h.contains('kategori') || h.contains('category') || h.contains('grup')) {
            colCategory = c;
          } else if (h.contains('aciklama') || h.contains('desc')) {
            colDescription = c;
          } else if (h == 'sku' || h.contains('urunkod')) {
            colSku = c;
          } else if (h.contains('barkod') || h.contains('barcode') || h.contains('ean')) {
            colBarcode = c;
          } else if (h.contains('stok') || h.contains('miktar') || h.contains('stock')) {
            colStock = c;
          } else if (h.contains('birim') || h.contains('unit')) {
            colUnit = c;
          } else if (h.contains('marka') || h.contains('brand')) {
            colBrand = c;
          }
        }
        // 2. satir ornek ise atla
        if (dataRows.length > 1) {
          final firstVal = dataRows[1].isNotEmpty ? dataRows[1][0].toLowerCase().trim() : '';
          if (firstVal == 'ornek urun' || firstVal == 'ornek' || firstVal.isEmpty) {
            dataStartRow = 2;
          }
        }
      }


      for (int i = dataStartRow; i < dataRows.length; i++) {
        final row = dataRows[i];
        if (row.isEmpty || row.every((c) => c.isEmpty)) continue;

        String col(int idx) => (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

        final name = col(colName);
        final priceStr = col(colPrice);
        final price = priceStr.isNotEmpty ? (double.tryParse(priceStr.replaceAll(',', '.')) ?? 0.0) : 0.0;

        // Ornek/ipucu satirini atla
        if (name.toLowerCase() == 'ornek urun') continue;
        if (name.isEmpty) continue;

        final categoryStr = col(colCategory).isNotEmpty ? col(colCategory) : null;
        final description = col(colDescription).isNotEmpty ? col(colDescription) : null;
        final sku = col(colSku).isNotEmpty ? col(colSku) : null;
        final barcode = col(colBarcode).isNotEmpty ? col(colBarcode) : null;
        final stockStr = col(colStock);
        final stock = int.tryParse(stockStr) ?? 0;
        final unitStr = col(colUnit).isNotEmpty ? col(colUnit) : null;
        final brand = col(colBrand).isNotEmpty ? col(colBrand) : null;

        // Kategori eslestir
        String? categoryId;
        String categoryLabel = 'Kategorisiz';
        if (categoryStr != null && categoryStr.isNotEmpty) {
          final catKey = categoryStr.trim().toLowerCase();
          if (categoryMap.containsKey(catKey)) {
            categoryId = categoryMap[catKey];
            categoryLabel = categoryStr.trim();
          } else {
            // Kategori yok - olusturulacaklar listesine ekle
            newCategoryNames.add(categoryStr.trim());
            categoryLabel = categoryStr.trim();
          }
        }

        final product = StoreProduct(
          id: uuid.v4(),
          storeId: _merchantId,
          categoryId: categoryId,
          name: name,
          description: (description != null && description.isNotEmpty) ? description : null,
          price: price,
          stock: stock,
          sku: (sku != null && sku.isNotEmpty) ? sku : null,
          barcode: (barcode != null && barcode.isNotEmpty) ? barcode : null,
          unitType: (unitStr != null && unitStr.isNotEmpty) ? UnitTypeExtension.fromString(unitStr) : UnitType.adet,
          brand: (brand != null && brand.isNotEmpty) ? brand : null,
          createdAt: DateTime.now(),
        );

        allProducts.add(product);
        grouped.putIfAbsent(categoryLabel, () => []).add(product);
      }

      if (allProducts.isEmpty) {
        setState(() {
          _errorMessage = 'Dosyada gecerli urun bulunamadi${errorCount > 0 ? ' ($errorCount satir hatali)' : ''}';
          _isLoading = false;
        });
        return;
      }

      // Excel'den gelen yeni kategorileri otomatik olustur
      if (newCategoryNames.isNotEmpty) {
        final catNotifier = ref.read(productCategoriesProvider.notifier);
        final createdMap = <String, String>{}; // name.lower -> id
        for (final catName in newCategoryNames) {
          final created = await catNotifier.addCategory(catName, _merchantId);
          if (created != null) {
            createdMap[catName.toLowerCase()] = created.id;
            categoryMap[catName.toLowerCase()] = created.id;
          }
        }
        // Urunlere yeni kategori id'lerini ata
        if (createdMap.isNotEmpty) {
          for (int i = 0; i < allProducts.length; i++) {
            if (allProducts[i].categoryId == null) {
              // grouped'daki label'dan kategori bul
              final label = grouped.keys.firstWhere(
                (k) => grouped[k]!.any((p) => p.id == allProducts[i].id),
                orElse: () => 'Kategorisiz',
              );
              final catId = createdMap[label.toLowerCase()];
              if (catId != null) {
                allProducts[i] = allProducts[i].copyWith(categoryId: catId);
                // grouped guncelle (label zaten dogru)
              }
            }
          }
        }
      }

      // Hala kategorisiz urunler varsa AI ile kategorize et (batch: 50'ser)
      final uncategorized = allProducts.where((p) => p.categoryId == null).toList();
      if (uncategorized.isNotEmpty && _categories.isNotEmpty) {
        try {
          final supabase = Supabase.instance.client;
          final categoryList = _categories.map((c) => {'id': c.id, 'name': c.name}).toList();
          // Batch: max 50 urun per call
          for (int b = 0; b < uncategorized.length; b += 50) {
            final batch = uncategorized.skip(b).take(50).toList();
            final productNames = batch.map((p) => {'id': p.id, 'name': p.name, 'brand': p.brand}).toList();
            try {
              final response = await supabase.functions.invoke(
                'ai-categorize-products',
                body: {'products': productNames, 'categories': categoryList},
              );
              if (response.status == 200 && response.data != null) {
                final assignments = (response.data['assignments'] as Map?)?.cast<String, dynamic>() ?? {};
                for (final entry in assignments.entries) {
                  final productId = entry.key;
                  final catId = entry.value as String;
                  final idx = allProducts.indexWhere((p) => p.id == productId);
                  if (idx != -1) {
                    final oldLabel = grouped.keys.firstWhere(
                      (k) => grouped[k]!.any((p) => p.id == productId),
                      orElse: () => 'Kategorisiz',
                    );
                    grouped[oldLabel]?.removeWhere((p) => p.id == productId);
                    if (grouped[oldLabel]?.isEmpty ?? false) grouped.remove(oldLabel);
                    final catName = _categories.where((c) => c.id == catId).firstOrNull?.name ?? 'Kategorisiz';
                    allProducts[idx] = allProducts[idx].copyWith(categoryId: catId);
                    grouped.putIfAbsent(catName, () => []).add(allProducts[idx]);
                  }
                }
              }
            } catch (_) {} // Batch hata verirse sonrakine gec
          }
        } catch (e) {
          if (kDebugMode) print('AI categorize error: $e');
        }
      }

      setState(() {
        _parsedProducts = allProducts;
        _groupedProducts = grouped;
        _errorMessage = errorCount > 0 ? '$errorCount satir hatali (atlandilar)' : null;
        _step = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Excel okuma hatasi: $e';
        _isLoading = false;
      });
    }
  }

  // ========== TOPLU YUKLEME ==========
  Future<void> _doImport() async {
    setState(() => _isUploading = true);
    final count = await widget.onImport(_parsedProducts);
    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadedCount = count;
        _imagesTotal = _parsedProducts.where((p) => p.imageUrl == null || p.imageUrl!.isEmpty).length;
        _step = 3;
      });
    }
  }

  // ========== OTOMATIK RESIM BULMA ==========
  Future<void> _autoFetchImages() async {
    setState(() {
      _isFetchingImages = true;
      _imagesFound = 0;
      _imagesDone = false;
    });

    final productIds = _parsedProducts.map((p) => p.id).toList();
    final found = await ref.read(storeProductsProvider.notifier).autoFetchProductImages(
      productIds: productIds,
      onProgress: (found, total) {
        if (mounted) {
          setState(() {
            _imagesFound = found;
            _imagesTotal = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isFetchingImages = false;
        _imagesFound = found;
        _imagesDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 750,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baslik
            Row(
              children: [
                const Icon(Icons.upload_file, size: 28),
                const SizedBox(width: 12),
                Text('Toplu Urun Yukleme', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                // Adim gostergesi
                _buildStepIndicator(),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Hata mesaji
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (_step == 2 ? AppColors.warning : AppColors.error).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (_step == 2 ? AppColors.warning : AppColors.error).withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _step == 2 ? Icons.warning_amber : Icons.error_outline,
                      color: _step == 2 ? AppColors.warning : AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: _step == 2 ? AppColors.warning : AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Adim icerigi
            Flexible(child: _buildStepContent()),

            const SizedBox(height: 20),

            // Alt butonlar
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0) Container(width: 20, height: 2, color: i <= _step ? AppColors.primary : AppColors.border),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= _step ? AppColors.primary : AppColors.background,
              border: Border.all(color: i <= _step ? AppColors.primary : AppColors.border),
            ),
            child: Center(
              child: i < _step
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: i <= _step ? Colors.white : AppColors.textMuted,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStep0Template();
      case 1:
        return _buildStep1Upload();
      case 2:
        return _buildStep2Preview();
      case 3:
        return _buildStep3Result();
      default:
        return const SizedBox.shrink();
    }
  }

  // ========== ADIM 0: SABLON INDIR ==========
  Widget _buildStep0Template() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(40)),
          ),
          child: Column(
            children: [
              Icon(Icons.description_outlined, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'Excel Sablonunu Indirin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Sablonda mevcut kategorileriniz icin ayri sayfalar bulunur.\n'
                'Her sayfaya ilgili kategorinin urunlerini yazin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _downloadTemplate,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download, size: 20),
                label: Text(_isLoading ? 'Hazirlaniyor...' : 'Sablon Indir (.xlsx)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Kategori listesi
        Text('Mevcut Kategoriler:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final cat in _categories)
              Chip(
                label: Text(cat.name, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppColors.primary.withAlpha(20),
                side: BorderSide(color: AppColors.primary.withAlpha(40)),
                visualDensity: VisualDensity.compact,
              ),
            Chip(
              label: const Text('Kategorisiz', style: TextStyle(fontSize: 12)),
              backgroundColor: AppColors.background,
              side: BorderSide(color: AppColors.border),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  // ========== ADIM 1: EXCEL YUKLE ==========
  Widget _buildStep1Upload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isLoading ? null : _pickAndParseExcel,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withAlpha(80),
                width: 2,
                strokeAlign: BorderSide.strokeAlignCenter,
              ),
            ),
            child: Column(
              children: [
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  Icon(Icons.cloud_upload_outlined, size: 56, color: AppColors.primary.withAlpha(180)),
                  const SizedBox(height: 12),
                  Text(
                    'Excel Dosyasi Sec',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Doldurdugunuz .xlsx dosyasini secin',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_fileName != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.insert_drive_file, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(_fileName!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Ipuclari', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              _tipRow('Zorunlu alan: Urun Adi (Fiyat yoksa 0 olarak eklenir)'),
              _tipRow('Ilk iki satir (baslik + ornek) otomatik atlanir'),
              _tipRow('Kategori bos birakilirsa AI otomatik kategorize eder'),
              _tipRow('Excel veya CSV dosyasi yukleyebilirsiniz'),
              _tipRow('Birim secenekleri: adet, kg, gram, litre, ml'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('  •  ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Expanded(child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  // ========== ADIM 2: ONIZLEME ==========
  Widget _buildStep2Preview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ozet
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_parsedProducts.length} urun hazir',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_groupedProducts.length} kategori',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (_fileName != null) ...[
              const Spacer(),
              Icon(Icons.insert_drive_file, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(_fileName!, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Kategorilere gore gruplu liste
        Expanded(
          child: ListView.builder(
            itemCount: _groupedProducts.keys.length,
            itemBuilder: (context, catIndex) {
              final categoryName = _groupedProducts.keys.elementAt(catIndex);
              final products = _groupedProducts[categoryName]!;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori basligi
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            categoryName,
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${products.length} urun',
                              style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Urun satirlari
                    for (int i = 0; i < products.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: i < products.length - 1 ? Border(bottom: BorderSide(color: AppColors.border.withAlpha(80))) : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                products[i].name,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${products[i].price.toStringAsFixed(2)} TL',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 60,
                              child: Text(
                                'Stok: ${products[i].stock}',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ========== ADIM 3: SONUC & OTOMATIK RESIM ==========
  Widget _buildStep3Result() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Basari mesaji
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withAlpha(40)),
          ),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 48, color: AppColors.success),
              const SizedBox(height: 12),
              Text(
                '$_uploadedCount urun basariyla yuklendi!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Otomatik resim bulma
        if (!_imagesDone && !_isFetchingImages) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withAlpha(30)),
            ),
            child: Column(
              children: [
                Icon(Icons.image_search, size: 40, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  'Urun Resimlerini Otomatik Bul',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Urun adi ve barkoduna gore Open Food Facts veritabanindan\notomatik resim aranir. $_imagesTotal resimsiz urun var.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _imagesTotal > 0 ? _autoFetchImages : null,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Resimleri Otomatik Bul'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Resim arama devam ediyor
        if (_isFetchingImages) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withAlpha(30)),
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Resimler araniyor...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_imagesFound / $_imagesTotal urun icin resim bulundu',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_imagesTotal > 0)
                  LinearProgressIndicator(
                    value: _imagesFound / _imagesTotal,
                    backgroundColor: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
              ],
            ),
          ),
        ],

        // Resim arama tamamlandi
        if (_imagesDone) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (_imagesFound > 0 ? AppColors.success : AppColors.warning).withAlpha(10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (_imagesFound > 0 ? AppColors.success : AppColors.warning).withAlpha(30)),
            ),
            child: Column(
              children: [
                Icon(
                  _imagesFound > 0 ? Icons.image : Icons.image_not_supported_outlined,
                  size: 40,
                  color: _imagesFound > 0 ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(height: 12),
                Text(
                  _imagesFound > 0
                      ? '$_imagesFound / $_imagesTotal urun icin resim bulundu!'
                      : 'Maalesef resim bulunamadi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                if (_imagesFound < _imagesTotal && _imagesFound > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bulunamayan resimler icin urun duzenleme ekranindan manuel ekleyebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Sol: Geri
        if (_step > 0 && _step < 3)
          TextButton.icon(
            onPressed: () => setState(() {
              _step = _step - 1;
              if (_step < 2) {
                _parsedProducts = [];
                _groupedProducts = {};
              }
            }),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Geri'),
          )
        else
          const SizedBox.shrink(),

        // Sag: Iptal / Devam / Yukle / Kapat
        Row(
          children: [
            if (_step < 3)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Iptal'),
              ),
            const SizedBox(width: 12),
            if (_step == 0)
              OutlinedButton.icon(
                onPressed: () => setState(() => _step = 1),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Zaten Sablonum Var'),
              ),
            if (_step == 1)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAndParseExcel,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Excel Sec'),
              ),
            if (_step == 2)
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _doImport,
                icon: _isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 18),
                label: Text(_isUploading ? 'Yukleniyor...' : '${_parsedProducts.length} Urun Yukle'),
              ),
            if (_step == 3 && !_isFetchingImages)
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Tamamla'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Otomatik resim bulma dialog'u
class _AutoImageDialog extends StatefulWidget {
  final int totalProducts;
  final Future<int> Function() onStart;

  const _AutoImageDialog({
    required this.totalProducts,
    required this.onStart,
  });

  @override
  State<_AutoImageDialog> createState() => _AutoImageDialogState();
}

class _AutoImageDialogState extends State<_AutoImageDialog> {
  bool _isSearching = false;
  bool _isDone = false;
  int _found = 0;

  Future<void> _startSearch() async {
    setState(() => _isSearching = true);
    final found = await widget.onStart();
    if (mounted) {
      setState(() {
        _found = found;
        _isSearching = false;
        _isDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.image_search, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Otomatik Resim Bul',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _isSearching ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (!_isDone && !_isSearching) ...[
              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.totalProducts} urun resimsiz',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Barkod ve isim ile otomatik resim aranacak.\nPaylasilan havuz ve Open Food Facts kullanilir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Aramaya Basla'),
                ),
              ),
            ],

            if (_isSearching) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Resimler araniyor...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu islem biraz zaman alabilir',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
            ],

            if (_isDone) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _found > 0 ? AppColors.success.withAlpha(20) : AppColors.warning.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      _found > 0 ? Icons.check_circle : Icons.image_not_supported,
                      color: _found > 0 ? AppColors.success : AppColors.warning,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _found > 0
                          ? '$_found / ${widget.totalProducts} urun icin resim bulundu!'
                          : 'Maalesef resim bulunamadi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _found > 0 ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Tamam'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
