import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/store_cart_provider.dart';
import '../../core/providers/product_favorite_provider.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/app_dialogs.dart';
import '../../models/store/store_product_model.dart';
import '../../widgets/food/add_to_cart_animation.dart';

class StoreProductDetailScreen extends ConsumerStatefulWidget {
  final StoreProduct product;

  const StoreProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<StoreProductDetailScreen> createState() =>
      _StoreProductDetailScreenState();
}

class _StoreProductDetailScreenState
    extends ConsumerState<StoreProductDetailScreen> {
  int _quantity = 1;
  int _selectedImageIndex = 0;
  String? _selectedColor;
  String? _selectedSize;
  final PageController _imageController = PageController();

  // Animation keys
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _cartTargetKey = GlobalKey();
  final GlobalKey<CartIconBounceState> _cartBounceKey = GlobalKey<CartIconBounceState>();
  bool _isAnimating = false;

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  List<String> get _images {
    if (widget.product.images.isNotEmpty) {
      return [widget.product.imageUrl, ...widget.product.images]
          .map((url) => ImageUtils.getProductDetail(url))
          .toList();
    }
    return [ImageUtils.getProductDetail(widget.product.imageUrl)];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = widget.product;
    final cartState = ref.watch(storeCartProvider);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 20,
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.share_outlined,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => context.push('/store/cart'),
                icon: CartIconBounce(
                  key: _cartBounceKey,
                  child: Container(
                    key: _cartTargetKey,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.5)
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Badge(
                      label: Text('${cartState.itemCount}'),
                      isLabelVisible: cartState.itemCount > 0,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: isDark ? Colors.white : Colors.black87,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Image Carousel
                  PageView.builder(
                    controller: _imageController,
                    onPageChanged: (index) {
                      setState(() => _selectedImageIndex = index);
                    },
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Container(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        child: Image.network(
                          _images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: Icon(
                              Icons.image_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Discount Badge
                  if (product.discountPercent != null)
                    Positioned(
                      top: 100,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '%${product.discountPercent} İNDİRİM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Favorite Button
                  Positioned(
                    top: 100,
                    right: 16,
                    child: Builder(
                      builder: (context) {
                        final isFavorite = ref.watch(isProductFavoriteProvider(product.id));
                        return GestureDetector(
                          onTap: () {
                            ref.read(productFavoriteProvider.notifier).toggleFavorite(product);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFavorite
                                      ? '${product.name} favorilerden kaldırıldı'
                                      : '${product.name} favorilere eklendi',
                                ),
                                backgroundColor: isFavorite ? Colors.red : AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Image Indicators
                  if (_images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_images.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _selectedImageIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _selectedImageIndex == index
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? Colors.grey[900] : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Store Info
                        GestureDetector(
                          onTap: () {
                            // Navigate to store
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.store_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      product.storeName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Product Name
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Rating & Sales
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${product.reviewCount} Değerlendirme',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (product.formattedSoldCount.isNotEmpty)
                              Text(
                                product.formattedSoldCount,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Price
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              product.formattedPrice,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (product.originalPrice != null) ...[
                              const SizedBox(width: 12),
                              Text(
                                product.formattedOriginalPrice,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (product.freeShipping)
                              _buildBadge(
                                Icons.local_shipping_outlined,
                                'Ücretsiz Kargo',
                                Colors.green,
                                isDark,
                              ),
                            if (product.fastDelivery)
                              _buildBadge(
                                Icons.flash_on_rounded,
                                'Hızlı Teslimat',
                                AppColors.primary,
                                isDark,
                              ),
                            _buildBadge(
                              Icons.verified_user_outlined,
                              'Orijinal Ürün',
                              Colors.purple,
                              isDark,
                            ),
                            _buildBadge(
                              Icons.replay_rounded,
                              '14 Gün İade',
                              Colors.orange,
                              isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    height: 8,
                    color: isDark ? Colors.black : Colors.grey[100],
                  ),

                  // Variants
                  if (product.variants != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.variants!.containsKey('Renk')) ...[
                            Text(
                              'Renk Seçin',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              children: (product.variants!['Renk'] as List<String>)
                                  .map((color) {
                                final isSelected = _selectedColor == color;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedColor = color);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.grey[800] : Colors.grey[100]),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                      ),
                                    ),
                                    child: Text(
                                      color,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white : Colors.black87),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (product.variants!.containsKey('Beden') ||
                              product.variants!.containsKey('Numara') ||
                              product.variants!.containsKey('Boyut') ||
                              product.variants!.containsKey('Kapasite')) ...[
                            Text(
                              _getSizeLabel(product.variants!),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _getSizes(product.variants!).map((size) {
                                final isSelected = _selectedSize == size;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedSize = size);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? Colors.grey[800] : Colors.grey[100]),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                      ),
                                    ),
                                    child: Text(
                                      size,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? Colors.white : Colors.black87),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      height: 8,
                      color: isDark ? Colors.black : Colors.grey[100],
                    ),
                  ],

                  // Description
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ürün Açıklaması',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Yüksek kaliteli malzeme\n• Uzun ömürlü kullanım\n• Kolay bakım\n• Hızlı kargo ile kapınızda',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Quantity Selector
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: Icon(
                      Icons.remove,
                      color: _quantity > 1 ? AppColors.primary : Colors.grey,
                    ),
                  ),
                  Text(
                    '$_quantity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _quantity++),
                    icon: Icon(Icons.add, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Add to Cart Button
            Expanded(
              child: GestureDetector(
                key: _addButtonKey,
                onTap: () {
                  if (_isAnimating) return;

                  // Check if required variants are selected
                  final missingSelections = <String>[];
                  if (product.variants != null) {
                    if (product.variants!.containsKey('Renk') && _selectedColor == null) {
                      missingSelections.add('Renk');
                    }
                    // Check for size variants (Beden, Numara, Boyut, Kapasite)
                    final hasSizeVariant = product.variants!.containsKey('Beden') ||
                        product.variants!.containsKey('Numara') ||
                        product.variants!.containsKey('Boyut') ||
                        product.variants!.containsKey('Kapasite');
                    if (hasSizeVariant && _selectedSize == null) {
                      if (product.variants!.containsKey('Beden')) {
                        missingSelections.add('Beden');
                      } else if (product.variants!.containsKey('Numara')) {
                        missingSelections.add('Numara');
                      } else if (product.variants!.containsKey('Boyut')) {
                        missingSelections.add('Boyut');
                      } else if (product.variants!.containsKey('Kapasite')) {
                        missingSelections.add('Kapasite');
                      }
                    }
                  }

                  if (missingSelections.isNotEmpty) {
                    AppDialogs.showWarning(
                      context,
                      'Lütfen seçim yapın: ${missingSelections.join(", ")}',
                    );
                    return;
                  }

                  setState(() => _isAnimating = true);

                  // Trigger flying animation
                  CartAnimationHelper.animateToCart(
                    context: context,
                    startKey: _addButtonKey,
                    endKey: _cartTargetKey,
                    imageUrl: product.imageUrl,
                    onComplete: () {
                      // Add item to cart after animation
                      ref.read(storeCartProvider.notifier).addProduct(
                        product,
                        quantity: _quantity,
                      );

                      setState(() => _isAnimating = false);
                      _cartBounceKey.currentState?.bounce();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(child: Text('${product.name} sepete eklendi!')),
                              TextButton(
                                onPressed: () => context.push('/store/cart'),
                                child: const Text(
                                  'Sepete Git',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(milliseconds: 2000),
                        ),
                      );
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _isAnimating
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _isAnimating
                            ? 'Ekleniyor...'
                            : 'Sepete Ekle • ${(product.price * _quantity).toStringAsFixed(2)} ₺',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getSizeLabel(Map<String, List<String>> variants) {
    if (variants.containsKey('Beden')) return 'Beden Seçin';
    if (variants.containsKey('Numara')) return 'Numara Seçin';
    if (variants.containsKey('Boyut')) return 'Boyut Seçin';
    if (variants.containsKey('Kapasite')) return 'Kapasite Seçin';
    return 'Seçenek';
  }

  List<String> _getSizes(Map<String, List<String>> variants) {
    if (variants.containsKey('Beden')) return variants['Beden']!;
    if (variants.containsKey('Numara')) return variants['Numara']!;
    if (variants.containsKey('Boyut')) return variants['Boyut']!;
    if (variants.containsKey('Kapasite')) return variants['Kapasite']!;
    return [];
  }
}
