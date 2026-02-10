import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/providers/restaurant_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/services/restaurant_service.dart';
import '../../widgets/home/service_card.dart';
import '../../widgets/home/promo_banner.dart';
import '../../widgets/delivery_header.dart';
import '../../core/providers/user_provider.dart';

// Enhanced searchable data model with source info
class SearchableItem {
  final String id;
  final String name;
  final String category;
  final String description;
  final String imageUrl;
  final String type; // 'restaurant', 'store', 'menu_item', 'store_product'
  final String? sourceId; // Restaurant or Store ID for products
  final String? sourceName; // Restaurant or Store name for products
  final String? sourceImageUrl; // Source logo
  final double? price;
  final double? rating;

  const SearchableItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.type,
    this.sourceId,
    this.sourceName,
    this.sourceImageUrl,
    this.price,
    this.rating,
  });
}

// Unified search provider
final unifiedSearchProvider = FutureProvider.family<List<SearchableItem>, String>((ref, query) async {
  if (query.isEmpty || query.length < 2) return [];

  final results = <SearchableItem>[];
  final lowerQuery = query.toLowerCase();

  // Search restaurants
  final restaurants = await ref.watch(restaurantsProvider.future);
  for (final restaurant in restaurants) {
    if (restaurant.name.toLowerCase().contains(lowerQuery) ||
        (restaurant.description?.toLowerCase().contains(lowerQuery) ?? false) ||
        restaurant.categoryTags.any((tag) => tag.toLowerCase().contains(lowerQuery))) {
      results.add(SearchableItem(
        id: restaurant.id,
        name: restaurant.name,
        category: restaurant.categoryTags.isNotEmpty ? restaurant.categoryTags.first : 'Restoran',
        description: restaurant.description ?? restaurant.deliveryTime,
        imageUrl: restaurant.logoUrl ?? restaurant.coverUrl ?? '',
        type: 'restaurant',
        rating: restaurant.rating,
      ));
    }
  }

  // Search menu items with restaurant info
  for (final restaurant in restaurants) {
    final menuItems = await RestaurantService.getMenuItems(restaurant.id);
    for (final item in menuItems) {
      if (item.name.toLowerCase().contains(lowerQuery) ||
          (item.description?.toLowerCase().contains(lowerQuery) ?? false)) {
        results.add(SearchableItem(
          id: item.id,
          name: item.name,
          category: item.category ?? 'Yemek',
          description: item.description ?? '',
          imageUrl: item.imageUrl ?? '',
          type: 'menu_item',
          sourceId: restaurant.id,
          sourceName: restaurant.name,
          sourceImageUrl: restaurant.logoUrl,
          price: item.discountedPrice ?? item.price,
          rating: restaurant.rating,
        ));
      }
    }
  }

  // Search stores
  final stores = await ref.watch(storesProvider.future);
  for (final store in stores) {
    if (store.name.toLowerCase().contains(lowerQuery) ||
        store.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))) {
      results.add(SearchableItem(
        id: store.id,
        name: store.name,
        category: store.tags.isNotEmpty ? store.tags.first : 'Mağaza',
        description: store.deliveryTime,
        imageUrl: store.logoUrl,
        type: 'store',
        rating: store.rating,
      ));
    }
  }

  // Search store products
  final products = await ref.watch(storeProductsProvider.future);
  for (final product in products) {
    if (product.name.toLowerCase().contains(lowerQuery) ||
        product.description.toLowerCase().contains(lowerQuery) ||
        product.category.toLowerCase().contains(lowerQuery)) {
      results.add(SearchableItem(
        id: product.id,
        name: product.name,
        category: product.category,
        description: product.description,
        imageUrl: product.imageUrl,
        type: 'store_product',
        sourceId: product.storeId,
        sourceName: product.storeName,
        price: product.price,
        rating: product.rating,
      ));
    }
  }

  return results;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  String _searchQuery = '';
  List<SearchableItem> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
      _showOverlay();
    } else if (!_searchFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_searchFocusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    if (query.isEmpty || query.length < 2) {
      _removeOverlay();
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Debounce search - wait for user to stop typing
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text.trim().toLowerCase() == query) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await ref.read(unifiedSearchProvider(query).future);
      if (mounted && _searchController.text.trim().toLowerCase() == query) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        _showOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        _showOverlay();
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - (context.pagePaddingH * 2),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, context.isMobile ? 52 : 56),
          child: Material(
            color: Colors.transparent,
            child: _buildSearchResults(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    // Loading state
    if (_isSearching) {
      return Container(
        padding: EdgeInsets.all(context.cardPadding * 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: context.itemGap),
            Text(
              'Aranıyor...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // No results
    if (_searchResults.isEmpty && _searchQuery.isNotEmpty && _searchQuery.length >= 2) {
      return Container(
        padding: EdgeInsets.all(context.cardPadding * 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: context.iconLarge * 1.5, color: Colors.grey[400]),
            SizedBox(height: context.itemGap),
            Text(
              'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"$_searchQuery" için sonuç yok',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Group results by type
    final restaurants = _searchResults.where((i) => i.type == 'restaurant').toList();
    final menuItems = _searchResults.where((i) => i.type == 'menu_item').toList();
    final stores = _searchResults.where((i) => i.type == 'store').toList();
    final storeProducts = _searchResults.where((i) => i.type == 'store_product').toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Restoranlar
              if (restaurants.isNotEmpty) ...[
                _buildSectionHeader('Restoranlar', Icons.restaurant, isDark),
                ...restaurants.take(3).map((item) => _buildSearchItem(item, isDark)),
              ],
              // Menü Ürünleri (Restoran ürünleri)
              if (menuItems.isNotEmpty) ...[
                if (restaurants.isNotEmpty)
                  Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                _buildSectionHeader('Yemekler', Icons.lunch_dining, isDark),
                ...menuItems.take(5).map((item) => _buildSearchItem(item, isDark)),
              ],
              // Mağazalar
              if (stores.isNotEmpty) ...[
                if (restaurants.isNotEmpty || menuItems.isNotEmpty)
                  Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                _buildSectionHeader('Mağazalar', Icons.storefront, isDark),
                ...stores.take(3).map((item) => _buildSearchItem(item, isDark)),
              ],
              // Mağaza Ürünleri
              if (storeProducts.isNotEmpty) ...[
                if (restaurants.isNotEmpty || menuItems.isNotEmpty || stores.isNotEmpty)
                  Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                _buildSectionHeader('Ürünler', Icons.shopping_bag, isDark),
                ...storeProducts.take(5).map((item) => _buildSearchItem(item, isDark)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchItem(SearchableItem item, bool isDark) {
    IconData typeIcon;
    Color typeColor;

    switch (item.type) {
      case 'restaurant':
        typeIcon = Icons.restaurant;
        typeColor = const Color(0xFFF97316); // Orange
        break;
      case 'menu_item':
        typeIcon = Icons.lunch_dining;
        typeColor = const Color(0xFFEA580C); // Deep orange
        break;
      case 'store':
        typeIcon = Icons.storefront;
        typeColor = const Color(0xFF10B981); // Green
        break;
      case 'store_product':
        typeIcon = Icons.shopping_bag;
        typeColor = AppColors.primary;
        break;
      default:
        typeIcon = Icons.circle;
        typeColor = Colors.grey;
    }

    // Check if this is a product with source info
    final hasSource = item.sourceName != null && item.sourceName!.isNotEmpty;
    final isProduct = item.type == 'menu_item' || item.type == 'store_product';

    return InkWell(
      onTap: () {
        _removeOverlay();
        _searchFocusNode.unfocus();
        _searchController.clear();
        // Navigate based on type
        switch (item.type) {
          case 'restaurant':
            context.push('/food/restaurant/${item.id}');
            break;
          case 'menu_item':
            context.push(
              '/food/item/${item.id}',
              extra: {
                'name': item.name,
                'description': item.description,
                'price': item.price ?? 0.0,
                'imageUrl': item.imageUrl,
                'rating': item.rating ?? 4.5,
                'restaurantName': item.sourceName ?? '',
                'deliveryTime': '30-40 dk',
              },
            );
            break;
          case 'store':
            context.push('/store/detail/${item.id}');
            break;
          case 'store_product':
            context.push('/store/product/${item.id}');
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Product/Item image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: typeColor.withValues(alpha: 0.1),
                          child: Icon(typeIcon, color: typeColor, size: 28),
                        ),
                      )
                    : Container(
                        color: typeColor.withValues(alpha: 0.1),
                        child: Icon(typeIcon, color: typeColor, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product/Item name
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Source store/restaurant name (for products)
                  if (hasSource && isProduct) ...[
                    Row(
                      children: [
                        Icon(
                          item.type == 'menu_item' ? Icons.restaurant : Icons.storefront,
                          size: 12,
                          color: typeColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.sourceName!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  // Category & Price row
                  Row(
                    children: [
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: typeColor,
                          ),
                        ),
                      ),
                      // Price (for products)
                      if (item.price != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₺${item.price!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ],
                      // Rating (for businesses)
                      if (item.rating != null && item.rating! > 0 && !isProduct) ...[
                        const Spacer(),
                        Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          const DeliveryHeader(showCart: true),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildWelcomeHeader(isDark)),
                SliverToBoxAdapter(child: _buildSearchBar(isDark)),
                SliverPadding(
                  padding: context.pageInsets,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      PromoBanner(),
                      SizedBox(height: context.sectionGap),
                      _buildServicesSection(isDark),
                      SizedBox(height: context.bottomNavPadding),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(bool isDark) {
    final userProfile = ref.watch(userProfileProvider);
    final userName = [userProfile?.firstName, userProfile?.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    return Container(
      padding: EdgeInsets.fromLTRB(context.pagePaddingH, context.pagePaddingV, context.pagePaddingH, 0),
      child: Row(
        children: [
          // Avatar & Welcome
          Container(
            width: context.avatarMedium,
            height: context.avatarMedium,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF60A5FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.apps,
              color: Colors.white,
              size: context.iconLarge,
            ),
          ),
          SizedBox(width: context.itemGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOŞ GELDİN,',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userName.isNotEmpty ? userName : 'Kullanıcı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: context.pageInsets,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _searchFocusNode.hasFocus
                  ? AppColors.primary
                  : (isDark ? Colors.grey[700]! : Colors.grey[100]!),
              width: _searchFocusNode.hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onTap: () {
              // Focus is handled by the TextField itself
            },
            decoration: InputDecoration(
              hintText: 'Restoran, mağaza veya ürün ara...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: _searchFocusNode.hasFocus ? AppColors.primary : Colors.grey[400],
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesSection(bool isDark) {
    return Column(
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hizmetlerimiz',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Tümünü gör',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: context.itemGap + 4),

        // Main Food Card
        ServiceCard(
          title: 'Yemek',
          subtitle: 'Lezzet kapında',
          icon: Icons.lunch_dining,
          gradientColors: const [Color(0xFFFB923C), Color(0xFFEA580C)],
          height: context.isMobile ? 180 : 220,
          isLarge: true,
          imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
          onTap: () => context.push('/food'),
        ),

        SizedBox(height: context.itemGap),

        // Two cards row
        Row(
          children: [
            Expanded(
              child: ServiceCard(
                title: 'Mağazalar',
                subtitle: 'Market & Alışveriş',
                icon: Icons.storefront,
                gradientColors: const [Color(0xFF34D399), Color(0xFF0D9488)],
                height: context.isMobile ? 130 : 160,
                onTap: () => context.push('/market'),
              ),
            ),
            SizedBox(width: context.itemGap),
            Expanded(
              child: ServiceCard(
                title: 'Taksi',
                subtitle: 'Hızlı ulaşım',
                icon: Icons.local_taxi,
                gradientColors: const [Color(0xFFFDE047), Color(0xFFFBBF24)],
                height: context.isMobile ? 130 : 160,
                isDarkText: true,
                onTap: () => context.push('/taxi'),
              ),
            ),
          ],
        ),

        SizedBox(height: context.itemGap),

        // Another two cards row
        Row(
          children: [
            Expanded(
              child: ServiceCard(
                title: 'Araç Kiralama',
                subtitle: 'Saatlik & Günlük',
                icon: Icons.car_rental,
                gradientColors: const [Color(0xFF8B5CF6), Color(0xFF9333EA)],
                height: context.isMobile ? 130 : 160,
                onTap: () => context.push('/rental'),
              ),
            ),
            SizedBox(width: context.itemGap),
            Expanded(
              child: ServiceCard(
                title: 'Emlak',
                subtitle: 'Konut & Arsa',
                icon: Icons.real_estate_agent,
                gradientColors: const [Color(0xFF60A5FA), Color(0xFF06B6D4)],
                height: context.isMobile ? 130 : 160,
                onTap: () => context.push('/emlak'),
              ),
            ),
          ],
        ),

        SizedBox(height: context.itemGap),

        // Bottom compact cards
        Row(
          children: [
            Expanded(
              child: _buildCompactCard(
                title: 'Araç Satışı',
                subtitle: '2. El Fırsatlar',
                icon: Icons.directions_car,
                gradientColors: const [Color(0xFFF43F5E), Color(0xFFDC2626)],
                isDark: isDark,
                onTap: () => context.push('/car-sales'),
              ),
            ),
            SizedBox(width: context.itemGap),
            Expanded(
              child: _buildCompactCard(
                title: 'İş İlanları',
                subtitle: 'Kariyer Fırsatları',
                icon: Icons.work,
                gradientColors: [
                  isDark ? const Color(0xFF374151) : const Color(0xFF0F766E),
                  isDark ? Colors.black : const Color(0xFF14B8A6),
                ],
                isDark: isDark,
                onTap: () => context.push('/jobs'),
              ),
            ),
          ],
        ),

        SizedBox(height: context.itemGap),

        // Market Card - Grocery stores with delivery zones
        ServiceCard(
          title: 'Market',
          subtitle: 'Taze ürünler kapında',
          icon: Icons.shopping_cart,
          gradientColors: const [Color(0xFF22C55E), Color(0xFF16A34A)],
          height: context.isMobile ? 130 : 160,
          onTap: () => context.push('/grocery'),
        ),
      ],
    );
  }

  Widget _buildCompactCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    final cardPadding = context.cardPadding;
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

}
