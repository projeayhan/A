import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/address_provider.dart';
import '../../core/providers/market_provider.dart';
import '../../core/providers/store_cart_provider.dart';
import '../../core/theme/app_responsive.dart';
import '../../models/store/store_model.dart';
import '../../widgets/store/store_card.dart';
import '../../widgets/common/generic_banner_carousel.dart';
import '../../core/providers/banner_provider.dart';

// Market theme colors
class MarketColors {
  static const Color primary = Color(0xFF22C55E);
  static const Color primaryDark = Color(0xFF16A34A);
  static const Color backgroundLight = Color(0xFFF0FDF4);
  static const Color backgroundDark = Color(0xFF0D1F12);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A2E1D);
}

class GroceryHomeScreen extends ConsumerStatefulWidget {
  const GroceryHomeScreen({super.key});

  @override
  ConsumerState<GroceryHomeScreen> createState() => _GroceryHomeScreenState();
}

class _GroceryHomeScreenState extends ConsumerState<GroceryHomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _selectedSorting = 'Önerilen';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final marketsAsync = ref.watch(marketsProvider);

    return Scaffold(
      backgroundColor: isDark ? MarketColors.backgroundDark : MarketColors.backgroundLight,
      body: marketsAsync.when(
        data: (markets) => _buildHomeContent(isDark, markets),
        loading: () => const Center(
          child: CircularProgressIndicator(color: MarketColors.primary),
        ),
        error: (error, stack) => _buildErrorState(isDark, error.toString()),
      ),
    );
  }

  Widget _buildHomeContent(bool isDark, List<Store> markets) {
    // Filter markets based on search
    final filteredMarkets = _searchQuery.isEmpty
        ? markets
        : markets.where((m) => m.name.toLowerCase().contains(_searchQuery)).toList();

    // Apply sorting
    final sortedMarkets = _applySorting(filteredMarkets);

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(isDark)),

        // Search Bar
        SliverToBoxAdapter(child: _buildSearchBar(isDark)),

        // Banner Carousel
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GenericBannerCarousel(
              bannerProvider: marketBannersProvider,
              height: 160,
              primaryColor: MarketColors.primary,
              defaultTitle: 'Market Fırsatları',
              defaultSubtitle: 'Taze ürünler kapında!',
            ),
          ),
        ),

        // Filter Bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _MarketFilterBarDelegate(
            isDark: isDark,
            selectedSorting: _selectedSorting,
            onSortingChanged: (value) => setState(() => _selectedSorting = value),
          ),
        ),

        // Markets Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(context.pagePaddingH, 12, context.pagePaddingH, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Marketler',
                  style: TextStyle(
                    fontSize: context.heading2Size,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  '${sortedMarkets.length} market',
                  style: TextStyle(fontSize: context.captionSize, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),

        // Market List
        sortedMarkets.isEmpty
            ? SliverToBoxAdapter(child: _buildEmptyState(isDark))
            : SliverPadding(
                padding: EdgeInsets.fromLTRB(context.pagePaddingH, 0, context.pagePaddingH, context.bottomNavPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final market = sortedMarkets[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < sortedMarkets.length - 1 ? 10 : 0,
                        ),
                        child: StoreCard(
                          store: market,
                          onTap: () => _navigateToMarket(market),
                        ),
                      );
                    },
                    childCount: sortedMarkets.length,
                  ),
                ),
              ),
      ],
    );
  }

  List<Store> _applySorting(List<Store> markets) {
    final sorted = List<Store>.from(markets);
    switch (_selectedSorting) {
      case 'Puana Göre':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'En Hızlı':
        sorted.sort((a, b) {
          final aTime = _parseDeliveryTime(a.deliveryTime);
          final bTime = _parseDeliveryTime(b.deliveryTime);
          return aTime.compareTo(bTime);
        });
        break;
      default: // 'Önerilen'
        // Keep default order
        break;
    }
    return sorted;
  }

  int _parseDeliveryTime(String time) {
    final match = RegExp(r'(\d+)').firstMatch(time);
    return match != null ? int.parse(match.group(1)!) : 999;
  }

  Widget _buildHeader(bool isDark) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final cartState = ref.watch(storeCartProvider);

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: isDark
            ? MarketColors.backgroundDark.withValues(alpha: 0.95)
            : MarketColors.backgroundLight.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title & Address
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_cart,
                            color: MarketColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Market',
                            style: TextStyle(
                              fontSize: context.heading1Size,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: MarketColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              selectedAddress?.shortAddress ?? 'Adres seçin',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Cart Button
                GestureDetector(
                  onTap: () => context.push('/store/cart'),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Badge(
                      label: Text('${cartState.itemCount}'),
                      isLabelVisible: cartState.itemCount > 0,
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePaddingH, 12, context.pagePaddingH, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? MarketColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Market ara...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: context.bodySize),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _searchFocusNode.hasFocus ? MarketColors.primary : Colors.grey[400],
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                    },
                    child: Icon(Icons.close_rounded, color: Colors.grey[400]),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MarketColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.store_mall_directory_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'Sonuç Bulunamadı'
                : 'Bölgenizde Market Yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? '"$_searchQuery" için sonuç bulunamadı'
                : 'Seçili adresinize teslimat yapan market bulunmuyor',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/settings/addresses'),
              icon: const Icon(Icons.location_on),
              label: const Text('Adres Değiştir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(marketsProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMarket(Store market) {
    context.push('/grocery/market/${market.id}', extra: {'store': market});
  }
}

// Filter Bar Delegate
class _MarketFilterBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final String selectedSorting;
  final ValueChanged<String> onSortingChanged;

  _MarketFilterBarDelegate({
    required this.isDark,
    required this.selectedSorting,
    required this.onSortingChanged,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: Container(
      color: isDark ? MarketColors.backgroundDark : MarketColors.backgroundLight,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Sort Button
          _buildFilterChip(
            icon: Icons.sort_rounded,
            label: selectedSorting,
            isActive: selectedSorting != 'Önerilen',
            onTap: () => _showSortingBottomSheet(context),
          ),
          const SizedBox(width: 8),
          // Delivery Info
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MarketColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 16,
                    color: MarketColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Bölgenize teslimat yapan marketler',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: MarketColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? MarketColors.primary
              : (isDark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? MarketColors.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortingBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? MarketColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sıralama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            ...['Önerilen', 'Puana Göre', 'En Hızlı'].map((option) {
              final isSelected = selectedSorting == option;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? MarketColors.primary : Colors.grey[400],
                ),
                title: Text(
                  option,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? MarketColors.primary
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                onTap: () {
                  onSortingChanged(option);
                  Navigator.pop(ctx);
                },
              );
            }),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 56;

  @override
  double get minExtent => 56;

  @override
  bool shouldRebuild(covariant _MarketFilterBarDelegate oldDelegate) {
    return oldDelegate.selectedSorting != selectedSorting ||
        oldDelegate.isDark != isDark;
  }
}
