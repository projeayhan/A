import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/name_masking.dart';
import '../../widgets/food/menu_item_card.dart';
import '../../widgets/food/add_to_cart_animation.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/restaurant_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/providers/ai_context_provider.dart';
import 'food_home_screen.dart';

// Reviews provider for a merchant
final merchantReviewsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, merchantId) async {
  final response = await SupabaseService.client
      .from('reviews')
      .select('*')
      .eq('merchant_id', merchantId)
      .order('created_at', ascending: false)
      .limit(10);
  return List<Map<String, dynamic>>.from(response);
});

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String name;
  final String imageUrl;
  final double rating;
  final String categories;
  final String deliveryTime;

  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.categories,
    required this.deliveryTime,
  });

  @override
  ConsumerState<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen> {
  int _selectedCategoryIndex = 0;
  bool _isFavorite = false;
  bool _isLoadingMenu = true;
  List<MenuItem> _menuItems = [];
  List<String> _categories = ['Tümü'];

  final GlobalKey _cartIconKey = GlobalKey();
  final GlobalKey<CartIconBounceState> _cartBounceKey = GlobalKey<CartIconBounceState>();
  final GlobalKey _reviewsKey = GlobalKey();

  // Merchant details
  String? _merchantAddress;
  String? _merchantPhone;
  String? _workingHours;
  double? _minOrderAmount;
  double? _deliveryFee;
  double? _freeDeliveryThreshold;

  // Grid card keys for cart animation
  final Map<String, GlobalKey> _gridAddButtonKeys = {};

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
    _loadMerchantDetails();
    _loadFavoriteStatus();
    // Set AI context for this restaurant
    Future.microtask(() {
      ref.read(aiScreenContextProvider.notifier).state = AiScreenContext(
        screenType: 'restaurant_detail',
        entityId: widget.restaurantId,
        entityName: widget.name,
        entityType: 'restaurant',
      );
    });
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await FavoritesService.isFavorite(widget.restaurantId);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _loadMerchantDetails() async {
    try {
      final response = await SupabaseService.client
          .from('merchants')
          .select('address, phone, min_order_amount, delivery_fee, free_delivery_threshold')
          .eq('id', widget.restaurantId)
          .single();

      // Get working hours for today
      final now = DateTime.now();
      final dayOfWeek = now.weekday - 1; // 0 = Monday

      final workingHoursResponse = await SupabaseService.client
          .from('merchant_working_hours')
          .select('open_time, close_time, is_open')
          .eq('merchant_id', widget.restaurantId)
          .eq('day_of_week', dayOfWeek)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _merchantAddress = response['address'] as String?;
          _merchantPhone = response['phone'] as String?;
          _minOrderAmount = (response['min_order_amount'] as num?)?.toDouble();
          _deliveryFee = (response['delivery_fee'] as num?)?.toDouble();
          _freeDeliveryThreshold = (response['free_delivery_threshold'] as num?)?.toDouble();

          if (workingHoursResponse != null && workingHoursResponse['is_open'] == true) {
            final openTime = (workingHoursResponse['open_time'] as String?)?.substring(0, 5) ?? '';
            final closeTime = (workingHoursResponse['close_time'] as String?)?.substring(0, 5) ?? '';
            _workingHours = '$openTime - $closeTime';
          } else {
            _workingHours = 'Kapalı';
          }
        });
      }
    } catch (e) {
      // Silently fail - we'll show default/empty values
    }
  }

  Future<void> _loadMenuItems() async {
    try {
      final items = await RestaurantService.getMenuItems(widget.restaurantId);

      // Extract unique categories with sort order
      final categoryMap = <String, int>{}; // category name -> sort order
      for (final item in items) {
        if (item.category != null && item.category!.isNotEmpty) {
          // Keep the lowest sort order for each category
          if (!categoryMap.containsKey(item.category!) ||
              item.categorySortOrder < categoryMap[item.category!]!) {
            categoryMap[item.category!] = item.categorySortOrder;
          }
        }
      }

      // Sort categories by sort_order
      final sortedCategories = categoryMap.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      // Build final category list: Tümü first, then sorted categories
      final categories = ['Tümü', ...sortedCategories.map((e) => e.key)];

      if (mounted) {
        setState(() {
          _menuItems = items;
          _categories = categories;
          _isLoadingMenu = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMenu = false);
      }
    }
  }

  void _scrollToReviews() {
    final context = _reviewsKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final newState = !_isFavorite;
    setState(() => _isFavorite = newState);

    // Save to database
    bool success;
    if (newState) {
      success = await FavoritesService.addFavorite(widget.restaurantId);
    } else {
      success = await FavoritesService.removeFavorite(widget.restaurantId);
    }

    if (!success && mounted) {
      // Revert on failure
      setState(() => _isFavorite = !newState);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı'),
          backgroundColor: FoodColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSearchDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = searchQuery.isEmpty
                ? _menuItems
                : _menuItems.where((item) {
                    final q = searchQuery.toLowerCase();
                    final words = q.split(RegExp(r'\s+'));
                    final text = '${item.name} ${item.category ?? ''} ${item.description ?? ''}'.toLowerCase();
                    return words.every((w) => w.isEmpty || text.contains(w));
                  }).toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
                right: 16,
              ),
              alignment: Alignment.topCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                decoration: BoxDecoration(
                  color: isDark ? FoodColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        autofocus: true,
                        onChanged: (value) => setDialogState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Menüde ara...',
                          prefixIcon: Icon(Icons.search, color: FoodColors.primary),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setDialogState(() => searchQuery = ''),
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),

                    // Results
                    if (filteredItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'Sonuç bulunamadı',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => Divider(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                          ),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final displayPrice = item.discountedPrice ?? item.price;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: item.imageUrl!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    )
                                  : null,
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                item.category ?? '',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                '${displayPrice.toStringAsFixed(2)} TL',
                                style: TextStyle(
                                  color: FoodColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                context.push(
                                  '/food/item/${item.id}',
                                  extra: {
                                    'name': item.name,
                                    'description': item.description ?? '',
                                    'price': item.discountedPrice ?? item.price,
                                    'imageUrl': item.imageUrl ?? '',
                                    'rating': 4.5,
                                    'restaurantName': widget.name,
                                    'deliveryTime': '30-40 dk',
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStoreInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.location_on, 'Adres', _merchantAddress ?? 'Belirtilmemiş', isDark),
                  _buildInfoRow(Icons.phone, 'Telefon', _merchantPhone ?? 'Belirtilmemiş', isDark),
                  _buildInfoRow(Icons.access_time, 'Çalışma Saatleri', _workingHours ?? 'Belirtilmemiş', isDark),
                  _buildInfoRow(Icons.delivery_dining, 'Teslimat Süresi', widget.deliveryTime, isDark),
                  _buildInfoRow(Icons.attach_money, 'Min. Sipariş', _minOrderAmount != null ? '₺${_minOrderAmount!.toStringAsFixed(0)}' : 'Belirtilmemiş', isDark),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Aranıyor...'),
                                backgroundColor: FoodColors.primary,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: FoodColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Ara',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Haritada açılıyor...'),
                              backgroundColor: FoodColors.primary,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.map,
                            color: FoodColors.primary,
                          ),
                        ),
                      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FoodColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartState = ref.watch(cartProvider);
    final cartItemCount = cartState.itemCount;

    return Scaffold(
      backgroundColor: isDark ? FoodColors.backgroundDark : FoodColors.backgroundLight,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            slivers: [
              // Hero Image Section
              SliverToBoxAdapter(child: _buildHeroSection(isDark)),

              // Restaurant Info
              SliverToBoxAdapter(child: _buildRestaurantInfo(isDark)),

              // Store Info Card
              SliverToBoxAdapter(child: _buildStoreInfoCard(isDark)),

              // Search Bar
              SliverToBoxAdapter(child: _buildSearchBar(isDark)),

              // Category Tabs - Sticky
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryTabDelegate(
                  child: _buildCategoryTabs(isDark),
                ),
              ),

              // Menu Items
              SliverToBoxAdapter(child: _buildMenuSection(isDark)),

              // Bottom padding for cart button
              SliverToBoxAdapter(child: SizedBox(height: context.bottomNavPadding + 80)),
            ],
          ),

          // Promo banner - free delivery achieved
          if (_freeDeliveryThreshold != null &&
              _freeDeliveryThreshold! > 0 &&
              cartState.subtotal >= _freeDeliveryThreshold!)
            Positioned(
              bottom: cartItemCount > 0 ? 150 : 90,
              left: 16,
              right: 16,
              child: _buildPromoBanner(isDark, achieved: true),
            )
          // Promo banner - progress toward free delivery
          else if (_freeDeliveryThreshold != null &&
              _freeDeliveryThreshold! > 0 &&
              cartState.subtotal > 0 &&
              cartState.subtotal < _freeDeliveryThreshold!)
            Positioned(
              bottom: cartItemCount > 0 ? 150 : 90,
              left: 16,
              right: 16,
              child: _buildPromoBanner(isDark, achieved: false, remaining: _freeDeliveryThreshold! - cartState.subtotal),
            ),

          // Floating Cart Button
          if (cartItemCount > 0)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: _buildCartButton(isDark, cartState),
            ),

        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isDark) {
    return SizedBox(
      height: context.heroImageHeight,
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: widget.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: ImageUtils.getHeroImage(widget.imageUrl),
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    memCacheHeight: 400,
                    placeholder: (_, __) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      child: Icon(Icons.restaurant, size: 48, color: Colors.grey[400]),
                    ),
                  )
                : Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    child: Icon(Icons.restaurant, size: 48, color: Colors.grey[400]),
                  ),
          ),

          // Top Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: context.pagePaddingH,
            right: context.pagePaddingH,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleButton(Icons.arrow_back, () => context.pop()),
                Row(
                  children: [
                    _buildCircleButton(Icons.info_outline, _showStoreInfo),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      _toggleFavorite,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Delivery Time Badge
          Positioned(
            bottom: 10,
            right: context.pagePaddingH,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? FoodColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: context.iconSmall,
                    color: FoodColors.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    widget.deliveryTime,
                    style: TextStyle(
                      fontSize: context.captionSize,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildRestaurantInfo(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePaddingH, 12, context.pagePaddingH, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: context.heading1Size,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _scrollToReviews,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF166534).withValues(alpha: 0.3)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: context.captionSize, color: FoodColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        widget.rating.toString(),
                        style: TextStyle(
                          fontSize: context.bodySmallSize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.categories.isNotEmpty ? widget.categories : 'Restoran',
            style: TextStyle(
              fontSize: context.captionSize,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfoCard(bool isDark) {
    final deliveryFeeText = _deliveryFee != null && _deliveryFee! > 0
        ? '${_deliveryFee!.toStringAsFixed(0)} TL'
        : 'Ücretsiz';
    final thresholdText = _freeDeliveryThreshold != null && _freeDeliveryThreshold! > 0
        ? '${_freeDeliveryThreshold!.toStringAsFixed(0)} TL'
        : (_minOrderAmount != null ? '${_minOrderAmount!.toStringAsFixed(0)} TL' : '-');
    final thresholdLabel = _freeDeliveryThreshold != null && _freeDeliveryThreshold! > 0
        ? 'Ücretsiz Teslimat'
        : 'Min. Sipariş';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH, vertical: 8),
      child: GestureDetector(
        onTap: _showStoreInfo,
        child: Container(
          padding: EdgeInsets.all(context.cardPadding),
          decoration: BoxDecoration(
            color: isDark ? FoodColors.surfaceDark : const Color(0xFFFCFAF8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Teslimat suresi
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.schedule, size: 20, color: FoodColors.primary),
                      const SizedBox(height: 4),
                      Text(
                        widget.deliveryTime,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Teslimat',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, color: isDark ? Colors.grey[700] : Colors.grey[200]),
                // Teslimat ucreti
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.delivery_dining, size: 20, color: FoodColors.primary),
                      const SizedBox(height: 4),
                      Text(
                        deliveryFeeText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: deliveryFeeText == 'Ücretsiz'
                              ? const Color(0xFF22C55E)
                              : (isDark ? Colors.white : const Color(0xFF111827)),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Teslimat Ücreti',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, color: isDark ? Colors.grey[700] : Colors.grey[200]),
                // Min siparis / ucretsiz teslimat esigi
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 20, color: FoodColors.primary),
                      const SizedBox(height: 4),
                      Text(
                        thresholdText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        thresholdLabel,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH, vertical: 4),
      child: GestureDetector(
        onTap: _showSearchDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? FoodColors.surfaceDark : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(
                '${widget.name} menüsünde ara',
                style: TextStyle(
                  fontSize: context.bodySize,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? FoodColors.backgroundDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 20),
          itemBuilder: (context, index) {
            final isSelected = index == _selectedCategoryIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategoryIndex = index),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? FoodColors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF111827))
                        : (isDark ? Colors.grey[400] : Colors.grey[500]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuSection(bool isDark) {
    if (_isLoadingMenu) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final selectedCategory = _categories[_selectedCategoryIndex];

    // If "Tümü" is selected, group by categories
    if (selectedCategory == 'Tümü') {
      return _buildGroupedMenuSection(isDark);
    }

    // Filter menu items by category
    final filteredItems = _menuItems.where((item) => item.category == selectedCategory).toList();

    if (filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Bu kategoride ürün bulunmuyor',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Title - More prominent styling
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [FoodColors.primary.withValues(alpha: 0.2), FoodColors.primary.withValues(alpha: 0.05)]
                  : [FoodColors.primary.withValues(alpha: 0.15), FoodColors.primary.withValues(alpha: 0.03)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border(
              left: BorderSide(
                color: FoodColors.primary,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedCategory,
                  style: TextStyle(
                    fontSize: context.heading2Size,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FoodColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredItems.length} ürün',
                    style: TextStyle(
                      fontSize: context.captionSize,
                      fontWeight: FontWeight.w600,
                      color: FoodColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Menu Items from Supabase
        ...filteredItems.map((item) => Column(
          children: [
            MenuItemCard(
              itemId: item.id,
              name: item.name,
              description: item.description ?? '',
              price: item.discountedPrice ?? item.price,
              imageUrl: item.imageUrl ?? '',
              badge: item.isPopular ? 'Popüler' : null,
              isDark: isDark,
              onAdd: () => _addToCart(item),
              restaurantName: widget.name,
              deliveryTime: widget.deliveryTime,
              rating: widget.rating,
              cartIconKey: _cartIconKey,
              hasOptionGroups: item.hasOptionGroups,
              imageSize: 110,
            ),
            Divider(height: 0.5, color: isDark ? Colors.grey[800] : Colors.grey[100]),
          ],
        )),

        // Spacer
        Container(
          height: 8,
          color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF9FAFB),
        ),
      ],
    );
  }

  Widget _buildGroupedMenuSection(bool isDark) {
    // Get popular items (max 6)
    final popularItems = _menuItems.where((item) => item.isPopular).take(6).toList();

    // Group remaining items by category with sort order
    final Map<String, ({List<MenuItem> items, int sortOrder})> groupedItems = {};

    for (final item in _menuItems) {
      final category = item.category ?? 'Diğer';
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = (items: [], sortOrder: item.categorySortOrder);
      }
      groupedItems[category]!.items.add(item);
    }

    // Sort categories by sort_order
    final sortedCategories = groupedItems.entries.toList()
      ..sort((a, b) => a.value.sortOrder.compareTo(b.value.sortOrder));

    if (groupedItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Henüz ürün bulunmuyor',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Popular section first (if has popular items)
        if (popularItems.isNotEmpty) ...[
          _buildCategorySection(
            categoryName: 'Popüler',
            items: popularItems,
            isDark: isDark,
            isPopularSection: true,
          ),
        ],

        // Reviews carousel between popular and categories
        Container(
          key: _reviewsKey,
          child: _buildReviewsCarousel(isDark),
        ),

        // Then categories sorted by sort_order
        ...sortedCategories.map((entry) {
          final categoryName = entry.key;
          final items = entry.value.items;

          return _buildCategorySection(
            categoryName: categoryName,
            items: items,
            isDark: isDark,
          );
        }),

        // Bottom spacer
        Container(
          height: 8,
          color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF9FAFB),
        ),
      ],
    );
  }

  Widget _buildCategorySection({
    required String categoryName,
    required List<MenuItem> items,
    required bool isDark,
    bool isPopularSection = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Container(
          margin: EdgeInsets.fromLTRB(context.pagePaddingH, 20, context.pagePaddingH, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? FoodColors.primary.withValues(alpha: 0.08)
                : FoodColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: isPopularSection ? Colors.orange : FoodColors.primary,
                width: 3.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (isPopularSection) ...[
                Icon(Icons.local_fire_department, color: Colors.orange, size: context.iconMedium),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: context.heading2Size,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} ürün',
                  style: TextStyle(
                    fontSize: context.captionSize,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Items in this category
        if (isPopularSection)
          // Grid layout for popular items
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH, vertical: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildPopularGridCard(items[index], isDark),
            ),
          )
        else
          ...items.map((item) => Column(
            children: [
              MenuItemCard(
                itemId: item.id,
                name: item.name,
                description: item.description ?? '',
                price: item.discountedPrice ?? item.price,
                imageUrl: item.imageUrl ?? '',
                badge: item.isPopular ? 'Popüler' : null,
                isDark: isDark,
                onAdd: () => _addToCart(item),
                restaurantName: widget.name,
                deliveryTime: widget.deliveryTime,
                rating: widget.rating,
                cartIconKey: _cartIconKey,
                hasOptionGroups: item.hasOptionGroups,
                imageSize: 110,
              ),
              Divider(height: 0.5, color: isDark ? Colors.grey[800] : Colors.grey[100]),
            ],
          )),

        // Category separator
        Container(
          height: 6,
          color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF3F4F6),
        ),
      ],
    );
  }

  Widget _buildPopularGridCard(MenuItem item, bool isDark) {
    final addKey = _gridAddButtonKeys.putIfAbsent(item.id, () => GlobalKey());

    return GestureDetector(
      onTap: () {
        context.push(
          '/food/item/${item.id}',
          extra: {
            'name': item.name,
            'description': item.description ?? '',
            'price': item.discountedPrice ?? item.price,
            'imageUrl': item.imageUrl ?? '',
            'rating': widget.rating,
            'restaurantName': widget.name,
            'deliveryTime': widget.deliveryTime,
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image - fills available space
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: CachedNetworkImage(
                        imageUrl: ImageUtils.getProductThumbnail(item.imageUrl ?? ''),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        memCacheHeight: 400,
                        placeholder: (_, __) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          child: Icon(Icons.fastfood, size: 32, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
                  // + button on image
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      key: addKey,
                      onTap: () {
                        if (item.hasOptionGroups) {
                          context.push(
                            '/food/item/${item.id}',
                            extra: {
                              'name': item.name,
                              'description': item.description ?? '',
                              'price': item.discountedPrice ?? item.price,
                              'imageUrl': item.imageUrl ?? '',
                              'rating': widget.rating,
                              'restaurantName': widget.name,
                              'deliveryTime': widget.deliveryTime,
                            },
                          );
                          return;
                        }
                        CartAnimationHelper.animateToCart(
                          context: context,
                          startKey: addKey,
                          endKey: _cartIconKey,
                          imageUrl: item.imageUrl ?? '',
                          onComplete: () => _addToCart(item),
                        );
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: FoodColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Name + Price - natural height
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(item.discountedPrice ?? item.price).toStringAsFixed(2)} TL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: FoodColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsCarousel(bool isDark) {
    final reviewsAsync = ref.watch(merchantReviewsProvider(widget.restaurantId));

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(context.pagePaddingH, 12, context.pagePaddingH, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Diğer kullanıcıların yorumları',
                    style: TextStyle(
                      fontSize: context.heading2Size,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAllReviews(isDark),
                    child: Text(
                      'Tümünü gör',
                      style: TextStyle(
                        fontSize: context.bodySmallSize,
                        fontWeight: FontWeight.w600,
                        color: FoodColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _buildCompactReviewCard(reviews[index], isDark),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCompactReviewCard(Map<String, dynamic> review, bool isDark) {
    final courierRating = review['courier_rating'] as int? ?? 0;
    final serviceRating = review['service_rating'] as int? ?? 0;
    final tasteRating = review['taste_rating'] as int? ?? 0;
    final avgRating = (courierRating + serviceRating + tasteRating) / 3;
    final comment = review['comment'] as String? ?? '';
    final customerName = review['customer_name'] as String? ?? 'Anonim';
    final createdAt = DateTime.tryParse(review['created_at'] as String? ?? '') ?? DateTime.now();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment
          Expanded(
            child: Text(
              comment.isNotEmpty ? comment : 'Yorum yok',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Rating + name + date
          Row(
            children: [
              // Stars
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avgRating.round() ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  );
                }),
              ),
              const Spacer(),
              Text(
                _formatReviewDate(createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            maskUserName(customerName),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final courierRating = review['courier_rating'] as int? ?? 0;
    final serviceRating = review['service_rating'] as int? ?? 0;
    final tasteRating = review['taste_rating'] as int? ?? 0;
    final avgRating = (courierRating + serviceRating + tasteRating) / 3;
    final comment = review['comment'] as String?;
    final merchantReply = review['merchant_reply'] as String?;
    final customerName = review['customer_name'] as String? ?? 'Anonim';
    final createdAt = DateTime.tryParse(review['created_at'] as String? ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: FoodColors.primary.withValues(alpha: 0.1),
                child: Text(
                  maskUserName(customerName)[0].toUpperCase(),
                  style: const TextStyle(
                    color: FoodColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maskUserName(customerName),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    Text(
                      _formatReviewDate(createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRatingColor(avgRating).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: _getRatingColor(avgRating)),
                    const SizedBox(width: 2),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _getRatingColor(avgRating),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Rating breakdown
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniRatingChip('Kurye', courierRating, isDark),
              const SizedBox(width: 6),
              _buildMiniRatingChip('Servis', serviceRating, isDark),
              const SizedBox(width: 6),
              _buildMiniRatingChip('Lezzet', tasteRating, isDark),
            ],
          ),

          // Comment
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 13,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Merchant reply
          if (merchantReply != null && merchantReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FoodColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FoodColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply, size: 14, color: FoodColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İşletme Yanıtı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: FoodColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          merchantReply,
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniRatingChip(String label, int rating, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star, size: 10, color: Colors.amber),
          Text(
            rating.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return const Color(0xFF22C55E);
    if (rating >= 3) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _formatReviewDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes} dk önce';
      return '${diff.inHours} saat önce';
    }
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showAllReviews(bool isDark) {
    final reviewsAsync = ref.read(merchantReviewsProvider(widget.restaurantId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? FoodColors.backgroundDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
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
                  'Tüm Değerlendirmeler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
              ),
              Expanded(
                child: reviewsAsync.when(
                  data: (reviews) => reviews.isEmpty
                      ? Center(
                          child: Text(
                            'Henüz değerlendirme yok',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: reviews.length,
                          itemBuilder: (context, index) => _buildReviewCard(reviews[index], isDark),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('Yorumlar yüklenemedi')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _addToCart(MenuItem item) {
    ref.read(cartProvider.notifier).addItem(CartItem(
      id: item.id,
      name: item.name,
      description: item.description,
      price: item.discountedPrice ?? item.price,
      quantity: 1,
      imageUrl: item.imageUrl ?? '',
      merchantId: widget.restaurantId,
      merchantName: widget.name,
    ));
    // Trigger cart bounce animation
    _cartBounceKey.currentState?.bounce();
  }

  Widget _buildPromoBanner(bool isDark, {required bool achieved, double remaining = 0}) {
    if (achieved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tebrikler, teslimat ücreti ödemeyeceksin!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(Icons.local_shipping, color: Colors.white, size: 18),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FoodColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping, color: FoodColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${remaining.toStringAsFixed(0)} TL daha ekle, ücretsiz teslimat kazan!',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartButton(bool isDark, CartState cartState) {
    return CartIconBounce(
      key: _cartBounceKey,
      child: GestureDetector(
        onTap: () {
          context.push('/food/cart');
        },
        child: Container(
          key: _cartIconKey,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: FoodColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: FoodColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        cartState.itemCount.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      '${cartState.subtotal.toStringAsFixed(2)} TL',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Row(
              children: [
                Text(
                  'View Cart',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _CategoryTabDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _CategoryTabDelegate({required this.child});

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _CategoryTabDelegate oldDelegate) => true;
}
