import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/store_colors.dart';
import '../../core/utils/image_utils.dart';
import '../../core/providers/store_cart_provider.dart';
import '../../core/providers/store_follow_provider.dart';
import '../../core/providers/store_favorite_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_product_model.dart';
import '../../core/providers/store_provider.dart';
import '../../core/providers/ai_context_provider.dart';
import '../../core/utils/name_masking.dart';

// Reviews provider for a store (merchant)
final storeReviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, merchantId) async {
  final response = await SupabaseService.client
      .from('reviews')
      .select('*')
      .eq('merchant_id', merchantId)
      .order('created_at', ascending: false)
      .limit(10);
  return List<Map<String, dynamic>>.from(response);
});

class StoreDetailScreen extends ConsumerStatefulWidget {
  final Store store;

  const StoreDetailScreen({super.key, required this.store});

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;
  String? _selectedCategory;

  // Product search
  final _productSearchController = TextEditingController();
  final _productSearchFocusNode = FocusNode();
  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _searchOverlayEntry;
  String _productSearchQuery = '';

  // Merchant details
  String? _merchantAddress;
  String? _merchantPhone;
  String? _merchantEmail;
  String? _workingHours;
  DateTime? _memberSince;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _productSearchController.addListener(_onProductSearchChanged);
    _productSearchFocusNode.addListener(_onProductSearchFocusChanged);
    _loadMerchantDetails();
    // Set AI context for this store/market (type determined in didChangeDependencies)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final location = GoRouterState.of(context).uri.path;
      final isMarket = location.startsWith('/grocery/market');
      final entityType = isMarket ? 'market' : 'store';
      ref.read(aiScreenContextProvider.notifier).state = AiScreenContext(
        screenType: '${entityType}_detail',
        entityId: widget.store.id,
        entityName: widget.store.name,
        entityType: entityType,
      );
    });
  }

  Future<void> _loadMerchantDetails() async {
    try {
      final response = await SupabaseService.client
          .from('merchants')
          .select('address, phone, email, created_at')
          .eq('id', widget.store.id)
          .single();

      // Get working hours for today
      final now = DateTime.now();
      final dayOfWeek = now.weekday - 1; // 0 = Monday

      final workingHoursResponse = await SupabaseService.client
          .from('merchant_working_hours')
          .select('open_time, close_time, is_open')
          .eq('merchant_id', widget.store.id)
          .eq('day_of_week', dayOfWeek)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _merchantAddress = response['address'] as String?;
          _merchantPhone = response['phone'] as String?;
          _merchantEmail = response['email'] as String?;

          final createdAt = response['created_at'] as String?;
          if (createdAt != null) {
            _memberSince = DateTime.tryParse(createdAt);
          }

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

  @override
  void dispose() {
    _removeSearchOverlay();
    _productSearchController.removeListener(_onProductSearchChanged);
    _productSearchFocusNode.removeListener(_onProductSearchFocusChanged);
    _productSearchController.dispose();
    _productSearchFocusNode.dispose();
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 200;
    if (show != _showTitle) {
      setState(() => _showTitle = show);
    }
  }

  void _onProductSearchFocusChanged() {
    if (_productSearchFocusNode.hasFocus && _productSearchQuery.isNotEmpty) {
      _showSearchOverlay();
    } else if (!_productSearchFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_productSearchFocusNode.hasFocus) {
          _removeSearchOverlay();
        }
      });
    }
  }

  void _onProductSearchChanged() {
    final query = _productSearchController.text.trim().toLowerCase();
    setState(() => _productSearchQuery = query);

    if (query.isEmpty || query.length < 2) {
      _removeSearchOverlay();
      return;
    }

    // Debounce
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _productSearchController.text.trim().toLowerCase() == query) {
        _showSearchOverlay();
      }
    });
  }

  void _showSearchOverlay() {
    _removeSearchOverlay();
    if (_productSearchQuery.length < 2) return;
    _searchOverlayEntry = _createSearchOverlayEntry();
    Overlay.of(context).insert(_searchOverlayEntry!);
  }

  void _removeSearchOverlay() {
    _searchOverlayEntry?.remove();
    _searchOverlayEntry = null;
  }

  List<StoreProduct> _getFilteredSearchResults(List<StoreProduct> allProducts) {
    if (_productSearchQuery.length < 2) return [];
    final query = _productSearchQuery.toLowerCase();
    return allProducts.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query) ||
          (p.description?.toLowerCase().contains(query) ?? false);
    }).take(8).toList();
  }

  OverlayEntry _createSearchOverlayEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsAsync = ref.read(productsByStoreProvider(widget.store.id));
    final allProducts = productsAsync.valueOrNull ?? [];
    final results = _getFilteredSearchResults(allProducts);

    return OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _searchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 350),
              decoration: BoxDecoration(
                color: isDark ? StoreColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            '"$_productSearchQuery" için ürün bulunamadı',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[600],
                              fontSize: context.bodySize,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 60,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                      ),
                      itemBuilder: (context, index) {
                        final product = results[index];
                        return ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: product.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: product.imageUrl!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 88,
                                    memCacheHeight: 88,
                                    placeholder: (_, __) => Container(
                                      width: 44,
                                      height: 44,
                                      color: Colors.grey[200],
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      width: 44,
                                      height: 44,
                                      color: StoreColors.primary.withValues(alpha: 0.1),
                                      child: Icon(Icons.shopping_bag_outlined,
                                          color: StoreColors.primary, size: 22),
                                    ),
                                  )
                                : Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: StoreColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.shopping_bag_outlined,
                                        color: StoreColors.primary, size: 22),
                                  ),
                          ),
                          title: Text(
                            product.name,
                            style: TextStyle(
                              fontSize: context.bodySize,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            product.category.isNotEmpty ? product.category : 'Ürün',
                            style: TextStyle(
                              fontSize: context.captionSize,
                              color: isDark ? Colors.white54 : Colors.grey[500],
                            ),
                          ),
                          trailing: Text(
                            '₺${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: context.bodySize,
                              fontWeight: FontWeight.bold,
                              color: StoreColors.primary,
                            ),
                          ),
                          onTap: () {
                            _removeSearchOverlay();
                            _productSearchController.clear();
                            _productSearchFocusNode.unfocus();
                            context.push(
                              '/store/product/${product.id}',
                              extra: {'product': product},
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final store = widget.store;
    final cartState = ref.watch(storeCartProvider);

    return Scaffold(
      backgroundColor: isDark ? StoreColors.backgroundDark : StoreColors.backgroundLight,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Custom App Bar with Cover Image
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              leading: _buildBackButton(isDark),
              actions: [
                IconButton(
                  onPressed: () => _shareStore(store),
                  icon: Icon(
                    Icons.share_outlined,
                    color: _showTitle
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => context.push('/store/cart'),
                  icon: Badge(
                    label: Text('${cartState.itemCount}'),
                    isLabelVisible: cartState.itemCount > 0,
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: _showTitle
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              title: AnimatedOpacity(
                opacity: _showTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: store.logoUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        memCacheWidth: 64,
                        memCacheHeight: 64,
                        placeholder: (_, __) => Container(
                          width: 32,
                          height: 32,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 32,
                          height: 32,
                          color: StoreColors.primary,
                          child: const Icon(
                            Icons.store,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        store.name,
                        style: TextStyle(
                          fontSize: context.heading2Size,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Image
                    CachedNetworkImage(
                      imageUrl: store.coverUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 800,
                      memCacheHeight: 400,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              StoreColors.primary,
                              StoreColors.primary.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Store Info Overlay
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Store Logo
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: CachedNetworkImage(
                                imageUrl: store.logoUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                memCacheWidth: 120,
                                memCacheHeight: 120,
                                placeholder: (_, __) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 60,
                                  height: 60,
                                  color: StoreColors.primary,
                                  child: const Icon(
                                    Icons.store,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Store Name & Badge
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        store.name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: context.heading2Size,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (store.isVerified) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.verified,
                                          color: StoreColors.primary,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (store.discountBadge != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      store.discountBadge!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: context.captionSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Stats & Follow Section
            SliverToBoxAdapter(
              child: Container(
                color: isDark ? Colors.grey[900] : Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Stats Row
                    Row(
                      children: [
                        _buildStatItem(
                          store.formattedRating,
                          'Puan',
                          Icons.star_rounded,
                          Colors.amber,
                          isDark,
                        ),
                        _buildDivider(isDark),
                        _buildStatItem(
                          store.formattedFollowers,
                          'Takipçi',
                          Icons.people_rounded,
                          StoreColors.primary,
                          isDark,
                        ),
                        _buildDivider(isDark),
                        _buildStatItem(
                          '${store.productCount}',
                          'Ürün',
                          Icons.inventory_2_rounded,
                          Colors.green,
                          isDark,
                        ),
                        _buildDivider(isDark),
                        _buildStatItem(
                          store.deliveryTime,
                          'Teslimat',
                          Icons.local_shipping_rounded,
                          Colors.orange,
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(child: _buildFollowButton(isDark, store)),
                        const SizedBox(width: 12),
                        _buildChatButton(isDark, store),
                        const SizedBox(width: 8),
                        _buildFavoriteButton(isDark, store),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: StoreColors.primary,
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: StoreColors.primary,
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'Ürünler'),
                    Tab(text: 'Hakkında'),
                    Tab(text: 'Yorumlar'),
                  ],
                ),
                isDark ? Colors.grey[900]! : Colors.white,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProductsTab(isDark),
            _buildAboutTab(isDark),
            _buildReviewsTab(isDark),
          ],
        ),
      ),
    );
  }

  void _shareStore(Store store) {
    final String tagsText = store.tags.isNotEmpty
        ? '\n🏷️ ${store.tags.join(", ")}'
        : '';
    final String shareText =
        '''
🏪 ${store.name}

⭐ ${store.rating} Puan | 👥 ${store.formattedFollowers} Takipçi | 📦 ${store.productCount} Ürün
🚚 Teslimat: ${store.deliveryTime}$tagsText

📍 Hemen incele ve alışverişe başla!

SuperCyp'te bu mağazayı keşfet! 🛍️
''';

    SharePlus.instance.share(
      ShareParams(text: shareText, subject: '${store.name} - SuperCyp'),
    );
  }

  Widget _buildChatButton(bool isDark, Store store) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: () => _showChatBottomSheet(isDark, store),
        icon: Icon(
          Icons.chat_bubble_outline_rounded,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(bool isDark, Store store) {
    final isFavorite = ref.watch(isStoreFavoriteProvider(store.id));

    return Container(
      decoration: BoxDecoration(
        color: isFavorite
            ? Colors.red.withValues(alpha: 0.1)
            : (isDark ? Colors.grey[800] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: () {
          ref.read(storeFavoriteProvider.notifier).toggleFavorite(store);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isFavorite ? Icons.heart_broken : Icons.favorite,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFavorite
                        ? '${store.name} favorilerden çıkarıldı'
                        : '${store.name} favorilere eklendi',
                  ),
                ],
              ),
              backgroundColor: isFavorite ? Colors.grey[700] : Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite
              ? Colors.red
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  void _showChatBottomSheet(bool isDark, Store store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StoreChatSheet(
        merchantId: store.id,
        storeName: store.name,
        logoUrl: store.logoUrl,
        isDark: isDark,
      ),
    );
  }

  Widget _buildFollowButton(bool isDark, Store store) {
    final isFollowing = ref.watch(isFollowingProvider(store.id));

    return ElevatedButton.icon(
      onPressed: () {
        if (isFollowing) {
          ref.read(storeFollowProvider.notifier).unfollowStore(store.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${store.name} takipten çıkarıldı'),
              backgroundColor: Colors.grey[800],
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ref.read(storeFollowProvider.notifier).followStore(store);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${store.name} takip ediliyor! İndirim ve yeni ürün bildirimlerini alacaksınız.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      icon: Icon(isFollowing ? Icons.check : Icons.add, size: 20),
      label: Text(isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowing
            ? (isDark ? Colors.grey[800] : Colors.grey[200])
            : StoreColors.primary,
        foregroundColor: isFollowing
            ? (isDark ? Colors.white : Colors.black87)
            : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: _showTitle
              ? Colors.transparent
              : Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_rounded,
            color: _showTitle
                ? (isDark ? Colors.white : Colors.black87)
                : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: context.heading2Size,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: context.captionSmallSize, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 40,
      width: 1,
      color: isDark ? Colors.grey[800] : Colors.grey[300],
    );
  }

  Widget _buildProductsTab(bool isDark) {
    // Get products from provider
    final productsAsync = ref.watch(productsByStoreProvider(widget.store.id));
    final allProducts = productsAsync.valueOrNull ?? [];

    // Build category map with sort_order
    final categoryMap = <String, int>{}; // category name -> sort order
    for (final product in allProducts) {
      if (product.category.isNotEmpty && product.category != 'Diğer') {
        if (!categoryMap.containsKey(product.category) ||
            product.categorySortOrder < categoryMap[product.category]!) {
          categoryMap[product.category] = product.categorySortOrder;
        }
      }
    }

    // Sort categories by sort_order
    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final categories = <Map<String, dynamic>>[
      {
        'name': 'Tümü',
        'id': null,
        'count': allProducts.length,
        'icon': Icons.apps_rounded,
      },
    ];

    for (final entry in sortedCategories) {
      final categoryName = entry.key;
      final count = allProducts.where((p) => p.category == categoryName).length;

      // Determine icon based on category name
      IconData icon = Icons.category_rounded;
      final lowerName = categoryName.toLowerCase();
      if (lowerName.contains('elektronik') || lowerName.contains('telefon')) {
        icon = Icons.devices_rounded;
      } else if (lowerName.contains('giyim') || lowerName.contains('elbise') || lowerName.contains('kıyafet')) {
        icon = Icons.checkroom_rounded;
      } else if (lowerName.contains('ayakkabı')) {
        icon = Icons.shopping_bag_rounded;
      } else if (lowerName.contains('yiyecek') || lowerName.contains('gıda')) {
        icon = Icons.restaurant_rounded;
      } else if (lowerName.contains('spor')) {
        icon = Icons.sports_soccer_rounded;
      } else if (lowerName.contains('kozmetik') || lowerName.contains('güzellik')) {
        icon = Icons.face_rounded;
      } else if (lowerName.contains('ev') || lowerName.contains('mobilya')) {
        icon = Icons.home_rounded;
      }

      categories.add({
        'name': categoryName,
        'id': categoryName,
        'count': count,
        'icon': icon,
      });
    }

    return Column(
      children: [
        // FIXED: Search + category chips - always visible at top
        Container(
          color: isDark ? Colors.grey[900] : Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product search bar
              CompositedTransformTarget(
                link: _searchLayerLink,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _productSearchController,
                      focusNode: _productSearchFocusNode,
                      style: TextStyle(
                        fontSize: context.bodySize,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ürün ara...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey[400],
                          fontSize: context.bodySize,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: _productSearchFocusNode.hasFocus
                              ? StoreColors.primary
                              : (isDark ? Colors.white38 : Colors.grey[400]),
                        ),
                        suffixIcon: _productSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
                                onPressed: () {
                                  _productSearchController.clear();
                                  _productSearchFocusNode.unfocus();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: StoreColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Horizontal scrollable category chips
              SizedBox(
                height: 52,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: categories.map((cat) {
                      final catId = cat['id'] as String?;
                      final isSelected = _selectedCategory == catId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat['id'] as String?;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? StoreColors.primary
                                  : (isDark ? Colors.grey[800] : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? StoreColors.primary
                                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: StoreColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat['icon'] as IconData, size: 16, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700])),
                                const SizedBox(width: 6),
                                Text(
                                  cat['name'] as String,
                                  style: TextStyle(
                                    fontSize: context.bodySmallSize,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable products below
        Expanded(
          child: SingleChildScrollView(
            child: _selectedCategory == null
                ? _buildGroupedProductsView(allProducts, sortedCategories, isDark)
                : _buildFilteredCategoryView(allProducts, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredCategoryView(List<StoreProduct> allProducts, bool isDark) {
    final filteredProducts = allProducts.where((p) => p.category == _selectedCategory).toList();

    if (filteredProducts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Bu kategoride ürün bulunmuyor',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Title Header
        _buildSectionHeader(_selectedCategory!, filteredProducts.length, isDark, icon: Icons.category, color: StoreColors.primary),
        // Product list
        ...filteredProducts.map((product) => Column(
          children: [
            _buildProductListItem(product, isDark),
            Divider(height: 0.5, indent: 16, endIndent: 16, color: isDark ? Colors.grey[800] : Colors.grey[100]),
          ],
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGroupedProductsView(
    List<StoreProduct> allProducts,
    List<MapEntry<String, int>> sortedCategories,
    bool isDark,
  ) {
    // Get popular products (top 6 by sold_count)
    final popularProducts = List<StoreProduct>.from(allProducts)
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final topPopular = popularProducts.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Popüler Section - grid layout
        if (topPopular.isNotEmpty) ...[
          _buildSectionHeader('Popüler', topPopular.length, isDark, icon: Icons.local_fire_department, color: Colors.orange, isPopular: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: topPopular.length,
              itemBuilder: (context, index) => _buildPopularGridCard(topPopular[index], isDark),
            ),
          ),
          Container(height: 6, color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF3F4F6)),
        ],

        // Reviews carousel
        _buildInlineReviewsCarousel(isDark),

        // Sorted Categories - horizontal card layout
        ...sortedCategories.map((entry) {
          final categoryName = entry.key;
          final categoryProducts = allProducts.where((p) => p.category == categoryName).toList();
          if (categoryProducts.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(categoryName, categoryProducts.length, isDark, icon: Icons.category, color: StoreColors.primary),
              ...categoryProducts.map((product) => Column(
                children: [
                  _buildProductListItem(product, isDark),
                  Divider(height: 0.5, indent: 16, endIndent: 16, color: isDark ? Colors.grey[800] : Colors.grey[100]),
                ],
              )),
              Container(height: 6, color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF3F4F6)),
            ],
          );
        }),

        // Products without category
        ...() {
          final uncategorized = allProducts.where((p) => p.category.isEmpty || p.category == 'Diğer').toList();
          if (uncategorized.isEmpty) return <Widget>[];
          return [
            _buildSectionHeader('Diğer', uncategorized.length, isDark, icon: Icons.more_horiz, color: Colors.grey),
            ...uncategorized.map((product) => Column(
              children: [
                _buildProductListItem(product, isDark),
                Divider(height: 0.5, indent: 16, endIndent: 16, color: isDark ? Colors.grey[800] : Colors.grey[100]),
              ],
            )),
          ];
        }(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark, {
    IconData icon = Icons.category,
    Color color = const Color(0xFF6366F1),
    bool isPopular = false,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: color, width: 3.5),
        ),
      ),
      child: Row(
        children: [
          if (isPopular) ...[
            Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
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
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count ürün',
              style: TextStyle(
                fontSize: context.captionSize,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularGridCard(StoreProduct product, bool isDark) {
    return GestureDetector(
      onTap: () {
        context.push('/store/product/${product.id}', extra: {'product': product});
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
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
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                      child: CachedNetworkImage(
                        imageUrl: ImageUtils.getProductThumbnail(product.imageUrl),
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        memCacheHeight: 400,
                        placeholder: (_, __) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          child: Icon(Icons.shopping_bag_outlined, size: 32, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
                  if (product.discountPercent != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          '%${product.discountPercent}',
                          style: TextStyle(color: Colors.white, fontSize: context.captionSmallSize, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
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
                    product.formattedPrice,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: StoreColors.primary,
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

  Widget _buildProductListItem(StoreProduct product, bool isDark) {
    return InkWell(
      onTap: () {
        context.push('/store/product/${product.id}', extra: {'product': product});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: context.priceSize,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.bodySmallSize,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          fontSize: context.bodySize,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      if (product.originalPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          product.formattedOriginalPrice,
                          style: TextStyle(
                            fontSize: context.captionSize,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      if (product.discountPercent != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '%${product.discountPercent}',
                            style: TextStyle(
                              fontSize: context.captionSmallSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                      if (product.freeShipping) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ücretsiz Kargo',
                            style: TextStyle(
                              fontSize: context.captionSmallSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.rating > 0 || product.formattedSoldCount.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (product.rating > 0) ...[
                          Icon(Icons.star_rounded, color: Colors.amber, size: context.captionSize),
                          const SizedBox(width: 2),
                          Text(
                            '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                            style: TextStyle(fontSize: context.captionSize, color: Colors.grey[500]),
                          ),
                        ],
                        if (product.formattedSoldCount.isNotEmpty) ...[
                          if (product.rating > 0) ...[
                            const SizedBox(width: 8),
                            Text('·', style: TextStyle(color: Colors.grey[400])),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            product.formattedSoldCount,
                            style: TextStyle(fontSize: context.captionSize, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Image
            SizedBox(
              width: 100,
              height: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: ImageUtils.getProductThumbnail(product.imageUrl),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  memCacheWidth: 200,
                  memCacheHeight: 200,
                  placeholder: (_, __) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    child: Icon(Icons.shopping_bag_outlined, size: 28, color: Colors.grey[400]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineReviewsCarousel(bool isDark) {
    final reviewsAsync = ref.watch(storeReviewsProvider(widget.store.id));

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Kullanıcı Yorumları',
                style: TextStyle(
                  fontSize: context.heading2Size,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  final comment = review['comment'] as String? ?? '';
                  final customerName = review['customer_name'] as String? ?? 'Anonim';
                  final courierRating = review['courier_rating'] as int? ?? 0;
                  final serviceRating = review['service_rating'] as int? ?? 0;
                  final tasteRating = review['taste_rating'] as int? ?? 0;
                  final avgRating = (courierRating + serviceRating + tasteRating) / 3;

                  return Container(
                    width: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (comment.isNotEmpty)
                          Expanded(
                            child: Text(
                              comment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: context.bodySmallSize,
                                color: isDark ? Colors.white70 : Colors.grey[700],
                                height: 1.3,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ...List.generate(5, (i) => Icon(
                              i < avgRating.round() ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 14,
                              color: Colors.amber,
                            )),
                            const Spacer(),
                            Text(
                              maskUserName(customerName),
                              style: TextStyle(
                                fontSize: context.captionSmallSize,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 6, color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF3F4F6)),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAboutTab(bool isDark) {
    // Format member since date
    String memberSinceText = 'Belirtilmemiş';
    if (_memberSince != null) {
      memberSinceText = '${_memberSince!.year}\'den beri';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard('Mağaza Bilgileri', [
            _buildInfoRow(
              Icons.store_rounded,
              'Mağaza Adı',
              widget.store.name,
              isDark,
            ),
            _buildInfoRow(
              Icons.calendar_today_rounded,
              'Üyelik',
              memberSinceText,
              isDark,
            ),
            _buildInfoRow(
              Icons.location_on_rounded,
              'Konum',
              _merchantAddress ?? 'Belirtilmemiş',
              isDark,
            ),
            if (_workingHours != null)
              _buildInfoRow(
                Icons.access_time_rounded,
                'Çalışma Saatleri',
                _workingHours!,
                isDark,
              ),
          ], isDark),
          const SizedBox(height: 16),
          _buildInfoCard('Teslimat', [
            _buildInfoRow(
              Icons.local_shipping_rounded,
              'Teslimat Süresi',
              '${widget.store.deliveryTime} içinde teslimat',
              isDark,
            ),
          ], isDark),
          const SizedBox(height: 16),
          _buildInfoCard('İletişim', [
            _buildInfoRow(
              Icons.email_rounded,
              'E-posta',
              _merchantEmail ?? 'Belirtilmemiş',
              isDark,
            ),
            _buildInfoRow(
              Icons.phone_rounded,
              'Telefon',
              _merchantPhone ?? 'Belirtilmemiş',
              isDark,
            ),
          ], isDark),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: context.heading2Size,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: StoreColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: context.captionSize, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: context.bodySize,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(bool isDark) {
    final reviewsAsync =
        ref.watch(storeReviewsProvider(widget.store.id));

    return reviewsAsync.when(
      data: (reviews) {
        // Calculate stats
        double avgRating = widget.store.rating;
        int totalReviews = reviews.length;
        Map<int, int> ratingCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

        if (reviews.isNotEmpty) {
          double totalRating = 0;
          for (final review in reviews) {
            final courier = review['courier_rating'] as int? ?? 0;
            final service = review['service_rating'] as int? ?? 0;
            final taste = review['taste_rating'] as int? ?? 0;
            final avg = (courier + service + taste) / 3;
            totalRating += avg;

            final roundedRating = avg.round().clamp(1, 5);
            ratingCounts[roundedRating] =
                (ratingCounts[roundedRating] ?? 0) + 1;
          }
          avgRating = totalRating / reviews.length;
        }

        return Column(
          children: [
            // Rating Summary
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          if (index < avgRating.floor()) {
                            return const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 20);
                          } else if (index < avgRating) {
                            return const Icon(Icons.star_half_rounded,
                                color: Colors.amber, size: 20);
                          }
                          return Icon(Icons.star_border_rounded,
                              color: Colors.grey[400], size: 20);
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalReviews değerlendirme',
                        style:
                            TextStyle(fontSize: context.captionSize, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _buildRatingBar(
                            '5',
                            totalReviews > 0
                                ? (ratingCounts[5] ?? 0) / totalReviews
                                : 0,
                            isDark),
                        _buildRatingBar(
                            '4',
                            totalReviews > 0
                                ? (ratingCounts[4] ?? 0) / totalReviews
                                : 0,
                            isDark),
                        _buildRatingBar(
                            '3',
                            totalReviews > 0
                                ? (ratingCounts[3] ?? 0) / totalReviews
                                : 0,
                            isDark),
                        _buildRatingBar(
                            '2',
                            totalReviews > 0
                                ? (ratingCounts[2] ?? 0) / totalReviews
                                : 0,
                            isDark),
                        _buildRatingBar(
                            '1',
                            totalReviews > 0
                                ? (ratingCounts[1] ?? 0) / totalReviews
                                : 0,
                            isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Reviews List
            if (reviews.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) =>
                      _buildReviewCard(reviews[index], isDark),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Henüz değerlendirme yok',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildRatingBar(String label, double percentage, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.captionSmallSize,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[200],
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber
                        .withValues(alpha: percentage > 0.5 ? 1.0 : 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
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
    final customerName = maskUserName(review['customer_name'] as String?);
    final createdAt =
        DateTime.tryParse(review['created_at'] as String? ?? '') ??
            DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: StoreColors.primary.withValues(alpha: 0.1),
                child: Text(
                  customerName[0].toUpperCase(),
                  style: const TextStyle(
                    color: StoreColors.primary,
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
                      customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    Text(
                      _formatReviewDate(createdAt),
                      style: TextStyle(fontSize: context.captionSmallSize, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Rating badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRatingColor(avgRating).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star,
                        size: 14, color: _getRatingColor(avgRating)),
                    const SizedBox(width: 2),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.captionSize,
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
              _buildMiniRatingChip('Kargo', courierRating, isDark),
              const SizedBox(width: 6),
              _buildMiniRatingChip('Paketleme', serviceRating, isDark),
              const SizedBox(width: 6),
              _buildMiniRatingChip('Ürün', tasteRating, isDark),
            ],
          ),

          // Comment
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: context.bodySmallSize,
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
                color: StoreColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: StoreColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply, size: 14, color: StoreColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mağaza Yanıtı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: context.captionSmallSize,
                            color: StoreColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          merchantReply,
                          style: TextStyle(
                            color:
                                isDark ? Colors.grey[300] : Colors.grey[700],
                            fontSize: context.captionSize,
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
            style: TextStyle(fontSize: context.captionSmallSize, color: Colors.grey[500]),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 10, color: Colors.amber),
          Text(
            rating.toString(),
            style: TextStyle(
              fontSize: context.captionSmallSize,
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
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

/// Mağaza ile gerçek mesajlaşma bottom sheet'i
class _StoreChatSheet extends StatefulWidget {
  final String merchantId;
  final String storeName;
  final String logoUrl;
  final bool isDark;

  const _StoreChatSheet({
    required this.merchantId,
    required this.storeName,
    required this.logoUrl,
    required this.isDark,
  });

  @override
  State<_StoreChatSheet> createState() => _StoreChatSheetState();
}

class _StoreChatSheetState extends State<_StoreChatSheet> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_subscription != null) {
      SupabaseService.client.removeChannel(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      final messages = await SupabaseService.client
          .from('store_messages')
          .select('*')
          .eq('merchant_id', widget.merchantId)
          .eq('customer_id', userId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(messages);
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Store chat load error: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await SupabaseService.client
          .from('store_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('merchant_id', widget.merchantId)
          .eq('customer_id', SupabaseService.currentUser!.id)
          .eq('sender_type', 'merchant')
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Mark store messages read error: $e');
    }
  }

  void _setupRealtimeSubscription() {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    _subscription = SupabaseService.client
        .channel('store_chat_${widget.merchantId}_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'store_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: widget.merchantId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newMsg = Map<String, dynamic>.from(payload.newRecord);
            // Bu conversation'a ait mi kontrol et
            if (newMsg['customer_id'] != userId) return;
            // Duplicate kontrolü
            if (_messages.any((m) => m['id'] == newMsg['id'])) return;
            // Temp mesajı gerçek mesajla değiştir
            if (newMsg['sender_type'] == 'customer') {
              final tempIdx = _messages.indexWhere((m) =>
                m['id'].toString().startsWith('temp_') &&
                m['message'] == newMsg['message']);
              if (tempIdx != -1) {
                setState(() => _messages[tempIdx] = newMsg);
                return;
              }
            }
            setState(() => _messages.add(newMsg));
            _scrollToBottom();
            if (newMsg['sender_type'] == 'merchant') {
              _markMessagesAsRead();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickMessage]) async {
    final text = (quickMessage ?? _messageController.text).trim();
    if (text.isEmpty) return;

    if (quickMessage == null) _messageController.clear();

    final user = SupabaseService.currentUser;
    if (user == null) return;
    final userName = user.userMetadata?['full_name'] ?? 'Müşteri';

    // Optimistic update
    final tempMessage = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'merchant_id': widget.merchantId,
      'customer_id': user.id,
      'sender_type': 'customer',
      'sender_id': user.id,
      'sender_name': userName,
      'message': text,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() => _messages.add(tempMessage));
    _scrollToBottom();

    try {
      await SupabaseService.client.from('store_messages').insert({
        'merchant_id': widget.merchantId,
        'customer_id': user.id,
        'sender_type': 'customer',
        'sender_id': user.id,
        'sender_name': userName,
        'message': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mesaj gönderilemedi'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: widget.logoUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    memCacheWidth: 88,
                    memCacheHeight: 88,
                    placeholder: (_, __) => Container(
                      width: 44,
                      height: 44,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: StoreColors.primary,
                      child: const Icon(Icons.store, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.storeName,
                        style: TextStyle(
                          fontSize: context.heading2Size,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Genellikle 1 saat içinde yanıt verir',
                            style: TextStyle(
                              fontSize: context.captionSize,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Messages Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyChat(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_type'] == 'customer';
                          final time = DateTime.tryParse(msg['created_at'] ?? '');
                          final timeStr = time != null
                              ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                              : '';

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isMe) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: widget.logoUrl,
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 56,
                                        memCacheHeight: 56,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: StoreColors.primary,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(Icons.store, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? StoreColors.primary
                                            : (isDark ? Colors.grey[800] : Colors.grey[100]),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                                          bottomRight: Radius.circular(isMe ? 4 : 16),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            msg['message'] ?? '',
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : (isDark ? Colors.white : Colors.black87),
                                              fontSize: context.bodySize,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : Colors.grey[500],
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
                        },
                      ),
          ),
          // Input Area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: StoreColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mağaza hoş geldin mesajı
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: widget.logoUrl,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                memCacheWidth: 56,
                memCacheHeight: 56,
                errorWidget: (_, __, ___) => Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: StoreColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  'Merhaba! ${widget.storeName} mağazasına hoş geldiniz. Size nasıl yardımcı olabiliriz?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: context.bodySize,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Quick action chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickChip('Ürün bilgisi almak istiyorum', isDark),
            _buildQuickChip('Kargo durumu', isDark),
            _buildQuickChip('İade/Değişim', isDark),
            _buildQuickChip('Fiyat bilgisi', isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, bool isDark) {
    return GestureDetector(
      onTap: () => _sendMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: StoreColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: context.bodySmallSize,
            color: StoreColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
