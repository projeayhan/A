import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/providers/product_favorite_provider.dart';
import '../../core/providers/store_favorite_provider.dart';
import '../../core/providers/unified_favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_ServiceTab> _serviceTabs = [
    _ServiceTab(
      title: 'Tümü',
      icon: Icons.apps_rounded,
      color: AppColors.primary,
    ),
    _ServiceTab(
      title: 'Yemek',
      icon: Icons.restaurant_rounded,
      color: FavoriteServiceColors.food,
    ),
    _ServiceTab(
      title: 'Mağaza',
      icon: Icons.shopping_bag_rounded,
      color: FavoriteServiceColors.market,
    ),
    _ServiceTab(
      title: 'Emlak',
      icon: Icons.home_rounded,
      color: FavoriteServiceColors.emlak,
    ),
    _ServiceTab(
      title: 'Araç',
      icon: Icons.directions_car_rounded,
      color: FavoriteServiceColors.car,
    ),
    _ServiceTab(
      title: 'İş İlanı',
      icon: Icons.work_rounded,
      color: FavoriteServiceColors.jobs,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _serviceTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = ref.watch(totalFavoriteCountProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark, totalCount),

            // Service tabs
            _buildServiceTabs(isDark),

            // Content based on selected tab
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllFavorites(isDark),
                  _buildFoodFavorites(isDark),
                  _buildMarketFavorites(isDark),
                  _buildEmlakFavorites(isDark),
                  _buildCarFavorites(isDark),
                  _buildJobFavorites(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, int totalCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Favorilerim',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  '$totalCount öğe kaydedildi',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTabs(bool isDark) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        tabs: _serviceTabs.map((tab) {
          return Tab(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                final index = _serviceTabs.indexOf(tab);
                final isSelected = _tabController.index == index;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tab.color
                        : (isDark ? AppColors.surfaceDark : Colors.white),
                    borderRadius: BorderRadius.circular(25),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: tab.color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 18,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================
  // TÜMÜ - TÜM FAVORİLER
  // ============================================

  Widget _buildAllFavorites(bool isDark) {
    // Only watch the total count to determine if empty - much more efficient
    final totalCount = ref.watch(totalFavoriteCountProvider);

    if (totalCount == 0) {
      return _buildEmptyState(isDark, 'Henüz favori eklemediniz', Icons.favorite_border_rounded);
    }

    // Use separate Consumer widgets to isolate rebuilds per section
    return ListView(
      padding: EdgeInsets.fromLTRB(context.pagePaddingH, 8, context.pagePaddingH, context.bottomNavPadding),
      children: [
        // Yemek Favorileri - isolated rebuild
        Consumer(
          builder: (context, ref, _) {
            final foodFavorites = ref.watch(foodFavoriteProvider.select((s) => s.restaurants));
            if (foodFavorites.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Yemek', FavoriteServiceColors.food, Icons.restaurant_rounded, foodFavorites.length),
                const SizedBox(height: 12),
                ...foodFavorites.take(3).map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildRestaurantCard(r, isDark),
                    )),
                if (foodFavorites.length > 3)
                  _buildSeeMoreButton('${foodFavorites.length - 3} restoran daha', () {
                    _tabController.animateTo(1);
                  }),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // Market Ürünleri - isolated rebuild
        Consumer(
          builder: (context, ref, _) {
            final productFavorites = ref.watch(productFavoriteProvider.select((s) => s.favorites));
            if (productFavorites.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Market Ürünleri', FavoriteServiceColors.market, Icons.shopping_bag_rounded, productFavorites.length),
                const SizedBox(height: 12),
                ...productFavorites.take(3).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildProductCard(p, isDark),
                    )),
                if (productFavorites.length > 3)
                  _buildSeeMoreButton('${productFavorites.length - 3} ürün daha', () {
                    _tabController.animateTo(2);
                  }),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // Mağazalar - isolated rebuild
        Consumer(
          builder: (context, ref, _) {
            final storeFavorites = ref.watch(storeFavoriteProvider.select((s) => s.favorites));
            if (storeFavorites.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Mağazalar', Colors.teal, Icons.storefront_rounded, storeFavorites.length),
                const SizedBox(height: 12),
                ...storeFavorites.take(3).map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildStoreCard(s, isDark),
                    )),
                if (storeFavorites.length > 3)
                  _buildSeeMoreButton('${storeFavorites.length - 3} mağaza daha', () {
                    _tabController.animateTo(2);
                  }),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // Emlak - isolated rebuild
        Consumer(
          builder: (context, ref, _) {
            final emlakFavorites = ref.watch(emlakFavoriteProvider.select((s) => s.properties));
            if (emlakFavorites.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Emlak İlanları', FavoriteServiceColors.emlak, Icons.home_rounded, emlakFavorites.length),
                const SizedBox(height: 12),
                ...emlakFavorites.take(3).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPropertyCard(p, isDark),
                    )),
                if (emlakFavorites.length > 3)
                  _buildSeeMoreButton('${emlakFavorites.length - 3} ilan daha', () {
                    _tabController.animateTo(3);
                  }),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // Araçlar - isolated rebuild
        Consumer(
          builder: (context, ref, _) {
            final carFavorites = ref.watch(carFavoriteProvider.select((s) => s.cars));
            if (carFavorites.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Araç İlanları', FavoriteServiceColors.car, Icons.directions_car_rounded, carFavorites.length),
                const SizedBox(height: 12),
                ...carFavorites.take(3).map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCarCard(c, isDark),
                    )),
                if (carFavorites.length > 3)
                  _buildSeeMoreButton('${carFavorites.length - 3} araç daha', () {
                    _tabController.animateTo(4);
                  }),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // İş İlanları - isolated rebuild
        Consumer(
          builder: (context, ref, _) {
            final jobFavorites = ref.watch(jobFavoriteProvider.select((s) => s.jobs));
            if (jobFavorites.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('İş İlanları', FavoriteServiceColors.jobs, Icons.work_rounded, jobFavorites.length),
                const SizedBox(height: 12),
                ...jobFavorites.take(3).map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildJobCard(j, isDark),
                    )),
                if (jobFavorites.length > 3)
                  _buildSeeMoreButton('${jobFavorites.length - 3} ilan daha', () {
                    _tabController.animateTo(5);
                  }),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon, int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeeMoreButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // YEMEK FAVORİLERİ
  // ============================================

  Widget _buildFoodFavorites(bool isDark) {
    final favorites = ref.watch(foodFavoriteProvider).restaurants;

    if (favorites.isEmpty) {
      return _buildEmptyState(isDark, 'Favori restoran yok', Icons.restaurant_rounded);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(context.pagePaddingH, 8, context.pagePaddingH, context.bottomNavPadding),
      itemCount: favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildRestaurantCard(favorites[index], isDark),
    );
  }

  Widget _buildRestaurantCard(FavoriteRestaurant restaurant, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/food/restaurant/${restaurant.id}', extra: {
          'name': restaurant.name,
          'imageUrl': restaurant.imageUrl,
          'rating': restaurant.rating,
          'categories': restaurant.category,
          'deliveryTime': restaurant.deliveryTime,
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: restaurant.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: FavoriteServiceColors.food.withValues(alpha: 0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: FavoriteServiceColors.food.withValues(alpha: 0.1),
                        child: Icon(Icons.restaurant, color: FavoriteServiceColors.food, size: 40),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: FavoriteServiceColors.food,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      restaurant.category,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRatingBadge(restaurant.rating),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.deliveryTime,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Min ₺${restaurant.minOrder.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Favorite button
            _buildFavoriteButton(
              onTap: () {
                ref.read(foodFavoriteProvider.notifier).removeRestaurant(restaurant.id);
                _showRemovedSnackbar(restaurant.name);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // MARKET FAVORİLERİ (Ürünler + Mağazalar)
  // ============================================

  Widget _buildMarketFavorites(bool isDark) {
    final productFavorites = ref.watch(productFavoriteProvider).favorites;
    final storeFavorites = ref.watch(storeFavoriteProvider).favorites;

    if (productFavorites.isEmpty && storeFavorites.isEmpty) {
      return _buildEmptyState(isDark, 'Favori ürün veya mağaza yok', Icons.shopping_bag_rounded);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        // Ürünler
        if (productFavorites.isNotEmpty) ...[
          _buildSectionHeader('Ürünler', FavoriteServiceColors.market, Icons.inventory_2_rounded, productFavorites.length),
          const SizedBox(height: 12),
          ...productFavorites.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildProductCard(p, isDark),
              )),
          const SizedBox(height: 20),
        ],

        // Mağazalar
        if (storeFavorites.isNotEmpty) ...[
          _buildSectionHeader('Mağazalar', Colors.teal, Icons.storefront_rounded, storeFavorites.length),
          const SizedBox(height: 12),
          ...storeFavorites.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildStoreCard(s, isDark),
              )),
        ],
      ],
    );
  }

  Widget _buildProductCard(FavoriteProduct product, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/store/${product.storeId}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: FavoriteServiceColors.market.withValues(alpha: 0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: FavoriteServiceColors.market.withValues(alpha: 0.1),
                        child: Icon(Icons.shopping_bag, color: FavoriteServiceColors.market, size: 40),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: FavoriteServiceColors.market,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.storeName,
                      style: TextStyle(fontSize: 13, color: FavoriteServiceColors.market),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRatingBadge(product.rating),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: FavoriteServiceColors.market.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '₺${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: FavoriteServiceColors.market,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildFavoriteButton(
              onTap: () {
                ref.read(productFavoriteProvider.notifier).removeFavorite(product.id);
                _showRemovedSnackbar(product.name);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(FavoriteStore store, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/store/${store.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: store.logoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.teal.withValues(alpha: 0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.teal.withValues(alpha: 0.1),
                        child: const Icon(Icons.storefront, color: Colors.teal, size: 40),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.category,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRatingBadge(store.rating),
                        const SizedBox(width: 8),
                        Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${store.productCount} ürün',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildFavoriteButton(
              onTap: () {
                ref.read(storeFavoriteProvider.notifier).removeFavorite(store.id);
                _showRemovedSnackbar(store.name);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // EMLAK FAVORİLERİ
  // ============================================

  Widget _buildEmlakFavorites(bool isDark) {
    final favorites = ref.watch(emlakFavoriteProvider).properties;

    if (favorites.isEmpty) {
      return _buildEmptyState(isDark, 'Favori emlak ilanı yok', Icons.home_rounded);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildPropertyCard(favorites[index], isDark),
    );
  }

  Widget _buildPropertyCard(FavoriteProperty property, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/emlak/detail/${property.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badge
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: property.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: FavoriteServiceColors.emlak.withValues(alpha: 0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: FavoriteServiceColors.emlak.withValues(alpha: 0.1),
                        child: Icon(Icons.home, color: FavoriteServiceColors.emlak, size: 50),
                      ),
                    ),
                    // Type badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: property.type == 'sale' ? FavoriteServiceColors.emlak : Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          property.type == 'sale' ? 'SATILIK' : 'KİRALIK',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Price badge
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          property.formattedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Favorite button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(emlakFavoriteProvider.notifier).removeProperty(property.id);
                          _showRemovedSnackbar(property.title);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite, color: Color(0xFFEC4899), size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        property.location,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildPropertyFeature(Icons.bed_rounded, '${property.rooms} Oda'),
                      const SizedBox(width: 16),
                      _buildPropertyFeature(Icons.square_foot_rounded, '${property.area} m²'),
                      const SizedBox(width: 16),
                      _buildPropertyFeature(Icons.home_work_rounded, property.propertyType),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyFeature(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: FavoriteServiceColors.emlak),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ============================================
  // ARAÇ FAVORİLERİ
  // ============================================

  Widget _buildCarFavorites(bool isDark) {
    final favorites = ref.watch(carFavoriteProvider).cars;

    if (favorites.isEmpty) {
      return _buildEmptyState(isDark, 'Favori araç ilanı yok', Icons.directions_car_rounded);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildCarCard(favorites[index], isDark),
    );
  }

  Widget _buildCarCard(FavoriteCar car, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/car/detail/${car.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: car.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: FavoriteServiceColors.car.withValues(alpha: 0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: FavoriteServiceColors.car.withValues(alpha: 0.1),
                        child: Icon(Icons.directions_car, color: FavoriteServiceColors.car, size: 50),
                      ),
                    ),
                    // Brand badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: FavoriteServiceColors.car,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          car.brand.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Price badge
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          car.formattedPrice,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Favorite button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(carFavoriteProvider.notifier).removeCar(car.id);
                          _showRemovedSnackbar(car.title);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite, color: Color(0xFFEC4899), size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        car.location,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildCarFeature(Icons.calendar_today_rounded, '${car.year}'),
                      const SizedBox(width: 12),
                      _buildCarFeature(Icons.speed_rounded, car.formattedKm),
                      const SizedBox(width: 12),
                      _buildCarFeature(Icons.local_gas_station_rounded, car.fuelType),
                      const SizedBox(width: 12),
                      _buildCarFeature(Icons.settings_rounded, car.transmission),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarFeature(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: FavoriteServiceColors.car),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ============================================
  // İŞ İLANI FAVORİLERİ
  // ============================================

  Widget _buildJobFavorites(bool isDark) {
    final favorites = ref.watch(jobFavoriteProvider).jobs;

    if (favorites.isEmpty) {
      return _buildEmptyState(isDark, 'Favori iş ilanı yok', Icons.work_rounded);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildJobCard(favorites[index], isDark),
    );
  }

  Widget _buildJobCard(FavoriteJob job, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/jobs/detail/${job.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Company logo
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: FavoriteServiceColors.jobs.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: job.companyLogo,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: Icon(
                            Icons.business,
                            color: FavoriteServiceColors.jobs.withValues(alpha: 0.5),
                            size: 28,
                          ),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.business,
                          color: FavoriteServiceColors.jobs,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: FavoriteServiceColors.jobs,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Favorite button
                  GestureDetector(
                    onTap: () {
                      ref.read(jobFavoriteProvider.notifier).removeJob(job.id);
                      _showRemovedSnackbar(job.title);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite, color: Color(0xFFEC4899), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Location and salary row
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    job.location,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      job.salary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildJobTag(job.employmentType, FavoriteServiceColors.jobs),
                  ...job.tags.take(3).map((tag) => _buildJobTag(tag, Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // ============================================
  // ORTAK WIDGET'LAR
  // ============================================

  Widget _buildEmptyState(bool isDark, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: const Color(0xFFEC4899),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Beğendiğiniz öğeleri favorilere ekleyin',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.green),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton({required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite,
            color: Color(0xFFEC4899),
            size: 20,
          ),
        ),
      ),
    );
  }

  void _showRemovedSnackbar(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name favorilerden kaldırıldı'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ServiceTab {
  final String title;
  final IconData icon;
  final Color color;

  const _ServiceTab({
    required this.title,
    required this.icon,
    required this.color,
  });
}
