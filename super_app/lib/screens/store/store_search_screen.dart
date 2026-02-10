import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/store_colors.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_product_model.dart';

class StoreSearchScreen extends ConsumerStatefulWidget {
  const StoreSearchScreen({super.key});

  @override
  ConsumerState<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends ConsumerState<StoreSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;

  String _query = '';
  List<Store> _storeResults = [];
  List<StoreProduct> _productResults = [];

  final List<String> _recentSearches = [
    'iPhone',
    'Spor ayakkabı',
    'Kozmetik',
    'Elektronik',
    'Kitap',
  ];

  final List<String> _popularSearches = [
    'Telefon',
    'Laptop',
    'Ayakkabı',
    'Çanta',
    'Parfüm',
    'Saat',
    'Gözlük',
    'Takı',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _query = query;
      if (query.isEmpty) {
        _storeResults = [];
        _productResults = [];
      } else {
        final lowerQuery = query.toLowerCase();
        _storeResults = Store.mockStores
            .where((s) => s.name.toLowerCase().contains(lowerQuery))
            .toList();
        _productResults = StoreProduct.mockProducts
            .where((p) =>
                p.name.toLowerCase().contains(lowerQuery) ||
                p.storeName.toLowerCase().contains(lowerQuery))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? StoreColors.backgroundDark : StoreColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: _search,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: context.heading2Size,
          ),
          decoration: InputDecoration(
            hintText: 'Mağaza veya ürün ara...',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: context.heading2Size,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              onPressed: () {
                _searchController.clear();
                _search('');
              },
            ),
        ],
        bottom: _query.isNotEmpty
            ? TabBar(
                controller: _tabController,
                labelColor: StoreColors.primary,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: StoreColors.primary,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Ürünler (${_productResults.length})'),
                  Tab(text: 'Mağazalar (${_storeResults.length})'),
                ],
              )
            : null,
      ),
      body: _query.isEmpty ? _buildInitialContent(isDark) : _buildSearchResults(isDark),
    );
  }

  Widget _buildInitialContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Son Aramalar',
                  style: TextStyle(
                    fontSize: context.heading2Size,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _recentSearches.clear();
                    });
                  },
                  child: Text(
                    'Temizle',
                    style: TextStyle(
                      color: StoreColors.primary,
                      fontSize: context.bodySize,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return GestureDetector(
                  onTap: () {
                    _searchController.text = search;
                    _search(search);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          search,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: context.bodySize,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Popular Searches
          Text(
            'Popüler Aramalar',
            style: TextStyle(
              fontSize: context.heading2Size,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularSearches.map((search) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = search;
                  _search(search);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: StoreColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 16,
                        color: StoreColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        search,
                        style: TextStyle(
                          color: StoreColors.primary,
                          fontSize: context.bodySize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Products Tab
        _productResults.isEmpty
            ? _buildEmptyState('Ürün bulunamadı', isDark)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _productResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = _productResults[index];
                  return _buildProductItem(product, isDark);
                },
              ),

        // Stores Tab
        _storeResults.isEmpty
            ? _buildEmptyState('Mağaza bulunamadı', isDark)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _storeResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final store = _storeResults[index];
                  return _buildStoreItem(store, isDark);
                },
              ),
      ],
    );
  }

  Widget _buildProductItem(StoreProduct product, bool isDark) {
    return GestureDetector(
      onTap: () {
        // Navigate to product detail
        context.push('/store/product/${product.id}', extra: {
          'product': product,
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 70,
                  height: 70,
                  color: StoreColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.image_outlined,
                    color: StoreColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: context.bodySize,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.store_rounded,
                        size: 14,
                        color: StoreColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.storeName,
                          style: TextStyle(
                            fontSize: context.captionSize,
                            color: StoreColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          fontSize: context.bodySize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (product.originalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          product.formattedOriginalPrice,
                          style: TextStyle(
                            fontSize: context.captionSize,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: context.captionSize,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreItem(Store store, bool isDark) {
    return GestureDetector(
      onTap: () {
        // Navigate to store detail
        context.push('/store/detail/${store.id}', extra: {
          'store': store,
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: store.logoUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: StoreColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.store_rounded,
                    color: StoreColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          store.name,
                          style: TextStyle(
                            fontSize: context.bodySize,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (store.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: StoreColors.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${store.formattedRating} (${store.reviewCount})',
                        style: TextStyle(
                          fontSize: context.captionSize,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.formattedFollowers,
                        style: TextStyle(
                          fontSize: context.captionSize,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  if (store.discountBadge != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        store.discountBadge!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.captionSmallSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: context.heading2Size,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir arama terimi deneyin',
            style: TextStyle(
              fontSize: context.bodySize,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
