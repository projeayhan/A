import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/providers/store_cart_provider.dart';
import '../../core/providers/product_favorite_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../models/store/store_category_model.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_product_model.dart';
import '../../widgets/store/flash_deal_banner.dart';
import '../../widgets/store/store_card.dart';
import '../../widgets/store/product_card.dart';
import '../../widgets/store/section_header.dart';
import '../../widgets/store/campaign_carousel.dart';
import '../../widgets/common/generic_banner_carousel.dart';
import '../../core/providers/banner_provider.dart';

class StoreHomeScreen extends ConsumerStatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  ConsumerState<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends ConsumerState<StoreHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showFloatingButton = false;
  String? _selectedCategoryId;

  // Search related
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _removeOverlay();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChanged);
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

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchQuery = query;
      });
      _removeOverlay();
      return;
    }

    // Debounce search to avoid excessive rebuilds (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _showOverlay();
      }
    });
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
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final screenWidth = renderBox?.size.width ?? MediaQuery.of(context).size.width;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: screenWidth - (context.pagePaddingH * 2),
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
    // Use server-side search for better performance
    final productResultsAsync = ref.watch(productSearchProvider(_searchQuery));
    final storeResultsAsync = ref.watch(storeSearchProvider(_searchQuery));

    final productResults = (productResultsAsync.valueOrNull ?? []).take(4).toList();
    final storeResults = (storeResultsAsync.valueOrNull ?? []).take(3).toList();

    // Show loading state
    if (productResultsAsync.isLoading || storeResultsAsync.isLoading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (productResults.isEmpty && storeResults.isEmpty && _searchQuery.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
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
              if (storeResults.isNotEmpty) ...[
                _buildSearchSectionHeader('Mağazalar', Icons.storefront, isDark),
                ...storeResults.map((store) => _buildStoreSearchItem(store, isDark)),
              ],
              if (productResults.isNotEmpty) ...[
                if (storeResults.isNotEmpty)
                  Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                _buildSearchSectionHeader('Ürünler', Icons.shopping_bag, isDark),
                ...productResults.map((product) => _buildProductSearchItem(product, isDark)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSectionHeader(String title, IconData icon, bool isDark) {
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

  Widget _buildStoreSearchItem(Store store, bool isDark) {
    return InkWell(
      onTap: () {
        _removeOverlay();
        _searchFocusNode.unfocus();
        _searchController.clear();
        _navigateToStore(store);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
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
                child: Image.network(
                  store.logoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.store, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[900],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (store.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 14, color: AppColors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        store.formattedRating,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final cats = ref.watch(storeCategoriesProvider).valueOrNull ?? [];
                            final categoryName = cats
                                .where((c) => c.id == store.categoryId)
                                .map((c) => c.name)
                                .firstOrNull ?? '';
                            return Text(
                              categoryName,
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
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

  Widget _buildProductSearchItem(StoreProduct product, bool isDark) {
    return InkWell(
      onTap: () {
        _removeOverlay();
        _searchFocusNode.unfocus();
        _searchController.clear();
        _navigateToProduct(product);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
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
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.shopping_bag, color: AppColors.primary),
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
                    product.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.storefront, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.storeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    product.formattedPrice,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w700,
                    ),
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

  void _onScroll() {
    final showButton = _scrollController.offset > 300;
    if (showButton != _showFloatingButton) {
      setState(() {
        _showFloatingButton = showButton;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
  }

  String _getSelectedCategoryName(List<StoreCategory> categories) {
    if (_selectedCategoryId == null) return '';
    final category = categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
    return category?.name ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(storeCategoriesProvider);
    final storesAsync = ref.watch(storesProvider);
    final flashDealsAsync = ref.watch(flashDealsProvider);
    final bestSellersAsync = ref.watch(bestSellersProvider);
    final cartState = ref.watch(storeCartProvider);
    final campaigns = CampaignItem.mockCampaigns;

    final categories = categoriesAsync.valueOrNull ?? [];
    final allStores = storesAsync.valueOrNull ?? [];
    final allFlashDeals = flashDealsAsync.valueOrNull ?? [];
    final allBestSellers = bestSellersAsync.valueOrNull ?? [];

    final filteredStores = _selectedCategoryId == null
        ? allStores
        : allStores.where((s) => s.categoryId == _selectedCategoryId).toList();
    final filteredFeaturedStores = _selectedCategoryId == null
        ? allStores.where((s) => s.isVerified).toList()
        : allStores.where((s) => s.isVerified && s.categoryId == _selectedCategoryId).toList();
    final filteredFlashDeals = _selectedCategoryId == null
        ? allFlashDeals
        : allFlashDeals.where((p) {
            final store = allStores.firstWhere((s) => s.id == p.storeId, orElse: () => allStores.first);
            return store.categoryId == _selectedCategoryId;
          }).toList();
    final filteredBestSellers = _selectedCategoryId == null
        ? allBestSellers
        : allBestSellers.where((p) {
            final store = allStores.firstWhere((s) => s.id == p.storeId, orElse: () => allStores.first);
            return store.categoryId == _selectedCategoryId;
          }).toList();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mağazalar',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedCategoryId != null
                                        ? '${_getSelectedCategoryName(categories)} kategorisinde ${filteredStores.length} mağaza'
                                        : '${allStores.length}+ mağaza sizi bekliyor',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Notification Button - BottomSheet
                            IconButton(
                              onPressed: () => _showNotificationsSheet(isDark),
                              icon: Badge(
                                label: const Text('2'),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            // Cart Button
                            IconButton(
                              onPressed: () {
                                context.push('/store/cart');
                              },
                              icon: Badge(
                                label: Text('${cartState.itemCount}'),
                                isLabelVisible: cartState.itemCount > 0,
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    color: isDark ? Colors.grey[900] : Colors.white,
                    child: CompositedTransformTarget(
                      link: _layerLink,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _searchFocusNode.hasFocus
                                ? AppColors.primary
                                : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                            width: _searchFocusNode.hasFocus ? 2 : 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Mağaza veya ürün ara...',
                            hintStyle: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: _searchFocusNode.hasFocus
                                  ? AppColors.primary
                                  : Colors.grey[500],
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      _searchFocusNode.unfocus();
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey[500],
                                      size: 20,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Categories with "All" option
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildAllCategoryChip(isDark);
                          }
                          final category = categories[index - 1];
                          final isSelected = _selectedCategoryId == category.id;
                          return _buildCategoryChip(category, isSelected, isDark);
                        },
                      ),
                    ),

                    // Selected category indicator
                    if (_selectedCategoryId != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getSelectedCategoryName(categories),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _selectCategory(null),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${filteredStores.length} mağaza, ${filteredFlashDeals.length + filteredBestSellers.length} ürün',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 6),

                    // DB Banner Carousel (only when no filter)
                    if (_selectedCategoryId == null) ...[
                      GenericBannerCarousel(
                        bannerProvider: storeBannersProvider,
                        height: 130,
                        primaryColor: Colors.teal,
                        defaultTitle: 'Market Fırsatları',
                        defaultSubtitle: 'En iyi fiyatlar burada!',
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Campaign Carousel (only when no filter and campaigns exist)
                    if (_selectedCategoryId == null && campaigns.isNotEmpty) ...[
                      CampaignCarousel(
                        campaigns: campaigns,
                        onTap: (campaign) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${campaign.title} kampanyası açılıyor...'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Flash Deals Banner (only when no filter)
                    if (_selectedCategoryId == null) ...[
                      FlashDealBanner(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Flash fırsatlar sayfası açılıyor...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Flash Deal Products
                    if (filteredFlashDeals.isNotEmpty) ...[
                      SectionHeader(
                        title: _selectedCategoryId != null
                            ? '${_getSelectedCategoryName(categories)} Fırsatları'
                            : 'Flaş Fırsatlar',
                        icon: Icons.flash_on_rounded,
                        actionText: 'Tümü',
                        onActionTap: () {},
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredFlashDeals.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final product = filteredFlashDeals[index];
                            return SizedBox(
                              width: 150,
                              child: ProductCard(
                                product: product,
                                isFavorite: ref.watch(isProductFavoriteProvider(product.id)),
                                onTap: () {
                                  _navigateToProduct(product);
                                },
                                onFavorite: () {
                                  ref.read(productFavoriteProvider.notifier).toggleFavorite(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ref.read(isProductFavoriteProvider(product.id))
                                            ? '${product.name} favorilere eklendi'
                                            : '${product.name} favorilerden çıkarıldı',
                                      ),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Featured Stores
                    if (filteredFeaturedStores.isNotEmpty) ...[
                      SectionHeader(
                        title: _selectedCategoryId != null
                            ? 'Öne Çıkan ${_getSelectedCategoryName(categories)} Mağazaları'
                            : 'Öne Çıkan Mağazalar',
                        icon: Icons.store_rounded,
                        actionText: 'Tümü',
                        onActionTap: () {},
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredFeaturedStores.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return StoreCard(
                              store: filteredFeaturedStores[index],
                              compact: true,
                              onTap: () {
                                _navigateToStore(filteredFeaturedStores[index]);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Best Sellers
                    if (filteredBestSellers.isNotEmpty) ...[
                      SectionHeader(
                        title: _selectedCategoryId != null
                            ? '${_getSelectedCategoryName(categories)} Çok Satanlar'
                            : 'Çok Satanlar',
                        icon: Icons.trending_up_rounded,
                        actionText: 'Tümü',
                        onActionTap: () {},
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredBestSellers.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final product = filteredBestSellers[index];
                            return SizedBox(
                              width: 150,
                              child: ProductCard(
                                product: product,
                                isFavorite: ref.watch(isProductFavoriteProvider(product.id)),
                                onTap: () {
                                  _navigateToProduct(product);
                                },
                                onFavorite: () {
                                  ref.read(productFavoriteProvider.notifier).toggleFavorite(product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ref.read(isProductFavoriteProvider(product.id))
                                            ? '${product.name} favorilere eklendi'
                                            : '${product.name} favorilerden çıkarıldı',
                                      ),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // All Stores
                    if (filteredStores.isNotEmpty) ...[
                      SectionHeader(
                        title: _selectedCategoryId != null
                            ? '${_getSelectedCategoryName(categories)} Mağazaları'
                            : 'Tüm Mağazalar',
                        icon: Icons.apps_rounded,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: filteredStores
                              .map((store) => StoreCard(
                                    store: store,
                                    onTap: () {
                                      _navigateToStore(store);
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    ],

                    // Empty state when filtered
                    if (_selectedCategoryId != null && filteredStores.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.store_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Bu kategoride mağaza bulunamadı',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _selectCategory(null),
                                child: Text(
                                  'Tüm mağazaları göster',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: context.bottomNavPadding),
                  ],
                ),
              ),
            ],
          ),

          // Floating scroll to top button
          if (_showFloatingButton)
            Positioned(
              right: 16,
              bottom: 100,
              child: AnimatedOpacity(
                opacity: _showFloatingButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.small(
                  onPressed: _scrollToTop,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllCategoryChip(bool isDark) {
    final isSelected = _selectedCategoryId == null;
    return GestureDetector(
      onTap: () => _selectCategory(null),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey[800] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.apps_rounded,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tümü',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(StoreCategory category, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () => _selectCategory(category.id),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? category.color
                    : category.color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? category.color
                      : category.color.withValues(alpha: 0.3),
                  width: isSelected ? 2.5 : 1.5,
                ),
              ),
              child: Icon(
                category.icon,
                color: isSelected ? Colors.white : category.color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? category.color
                    : (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Bildirimler',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tümünü Gör',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _buildNotificationItem(
                icon: Icons.local_offer_rounded,
                color: Colors.orange,
                title: 'Flash İndirim Başladı!',
                message: '%50\'ye varan indirimler',
                time: '5 dk önce',
                isDark: isDark,
              ),
              _buildNotificationItem(
                icon: Icons.local_shipping_rounded,
                color: Colors.green,
                title: 'Siparişiniz Yola Çıktı',
                message: 'TechZone kargoya verdi',
                time: '1 saat önce',
                isDark: isDark,
              ),
              _buildNotificationItem(
                icon: Icons.favorite_rounded,
                color: Colors.red,
                title: 'Favori Mağazanızda İndirim',
                message: 'Fashion House %30 indirim',
                time: '3 saat önce',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String time,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProduct(StoreProduct product) {
    context.push('/store/product/${product.id}', extra: {'product': product});
  }

  void _navigateToStore(Store store) {
    context.push('/store/detail/${store.id}', extra: {'store': store});
  }
}
