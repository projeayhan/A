import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_responsive.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/providers/emlak_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/banner_provider.dart';
import '../../widgets/common/generic_banner_carousel.dart';

class EmlakHomeScreen extends ConsumerStatefulWidget {
  const EmlakHomeScreen({super.key});

  @override
  ConsumerState<EmlakHomeScreen> createState() => _EmlakHomeScreenState();
}

class _EmlakHomeScreenState extends ConsumerState<EmlakHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late Animation<double> _heroAnimation;
  late Animation<double> _floatingAnimation;

  final ScrollController _scrollController = ScrollController();

  // Filter States - All accessible from main page
  String _selectedCity = ''; // Boş = Tüm Şehirler
  final Set<String> _selectedDistricts = {}; // Multiple district selection
  ListingType? _selectedListingType;
  String? _selectedPropertyTypeName; // Dinamik property type (DB'den)
  RangeValues _priceRange = const RangeValues(0, 10000000);
  RangeValues _areaRange = const RangeValues(0, 500);
  int? _minRooms;
  bool _showFilters = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();

  // Sorting
  SortOption _selectedSort = SortOption.newest;

  // Supabase'den gelen veriler
  List<Property> _properties = [];
  List<Property> _featuredProperties = [];
  bool _isLoading = true;

  // DB'den gelen şehir ve ilçeler
  List<String> _cities = [];
  List<String> _districts = [];

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _heroAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    );

    _floatingAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _heroController.forward();

    _searchController.addListener(_onSearchChanged);

    // Verileri yükle
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Şehirleri DB'den yükle
      final propertyService = ref.read(propertyServiceProvider);
      final cities = await propertyService.getCities();

      if (mounted) {
        setState(() {
          _cities = cities;
          // Varsayılan şehir yoksa ilk şehri seç
          if (_cities.isNotEmpty && !_cities.contains(_selectedCity)) {
            _selectedCity = _cities.first;
          }
        });
      }

      // Seçili şehrin ilçelerini yükle
      await _loadDistricts();
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDistricts() async {
    try {
      final propertyService = ref.read(propertyServiceProvider);
      final districts = await propertyService.getDistrictsByCity(_selectedCity);

      if (mounted) {
        setState(() {
          _districts = districts;
        });
      }
    } catch (e) {
      debugPrint('İlçe yükleme hatası: $e');
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Property> get filteredProperties {
    var list = _properties.toList();

    // City filter - EN ÖNEMLİ FİLTRE
    if (_selectedCity.isNotEmpty) {
      list = list.where((p) => p.location.city == _selectedCity).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) {
        return p.title.toLowerCase().contains(_searchQuery) ||
            p.location.district.toLowerCase().contains(_searchQuery) ||
            p.location.city.toLowerCase().contains(_searchQuery) ||
            p.location.neighborhood.toLowerCase().contains(_searchQuery) ||
            p.description.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (_selectedListingType != null) {
      list = list.where((p) => p.listingType == _selectedListingType).toList();
    }
    if (_selectedPropertyTypeName != null) {
      list = list.where((p) => p.type.name == _selectedPropertyTypeName).toList();
    }
    // Multiple districts filter
    if (_selectedDistricts.isNotEmpty) {
      list = list
          .where((p) => _selectedDistricts.contains(p.location.district))
          .toList();
    }
    if (_minRooms != null) {
      list = list.where((p) => p.rooms >= _minRooms!).toList();
    }

    // Apply sorting
    switch (_selectedSort) {
      case SortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.priceLowToHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighToLow:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.areaLargest:
        list.sort((a, b) => b.squareMeters.compareTo(a.squareMeters));
        break;
      case SortOption.areaSmallest:
        list.sort((a, b) => a.squareMeters.compareTo(b.squareMeters));
        break;
      case SortOption.roomsMore:
        list.sort((a, b) => b.rooms.compareTo(a.rooms));
        break;
      case SortOption.roomsLess:
        list.sort((a, b) => a.rooms.compareTo(b.rooms));
        break;
    }

    return list;
  }

  int get activeFilterCount {
    int count = 0;
    if (_selectedListingType != null) count++;
    if (_selectedPropertyTypeName != null) count++;
    if (_selectedDistricts.isNotEmpty) count += _selectedDistricts.length;
    if (_minRooms != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  void _clearAllFilters() {
    setState(() {
      _selectedListingType = null;
      _selectedPropertyTypeName = null;
      _selectedDistricts.clear();
      _minRooms = null;
      _priceRange = const RangeValues(0, 10000000);
      _areaRange = const RangeValues(0, 500);
      _searchController.clear();
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    // Supabase provider'larını dinle
    final propertyState = ref.watch(propertyListProvider);
    final featuredAsync = ref.watch(featuredPropertiesProvider);

    // Provider'dan gelen verileri güncelle
    _properties = propertyState.properties;
    _isLoading = propertyState.isLoading;

    featuredAsync.whenData((featured) {
      if (featured.isNotEmpty) {
        _featuredProperties = featured;
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: EmlakColors.background(isDark),
          extendBodyBehindAppBar: true,
          floatingActionButton: _buildFAB(context),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Compact Hero Header
              SliverToBoxAdapter(
                child: _buildCompactHeader(context, size, isDark),
              ),

              // Banner Carousel - En üstte, header'dan hemen sonra (UX best practice)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                  child: GenericBannerCarousel(
                    bannerProvider: emlakBannersProvider,
                    height: 160,
                    primaryColor: Colors.brown,
                    defaultTitle: 'Emlak Fırsatları',
                    defaultSubtitle: 'Hayalinizdeki eve ulaşın!',
                  ),
                ),
              ),

              // Location Selector (Inline)
              SliverToBoxAdapter(
                child: _buildLocationSelector(context, isDark),
              ),

              // Active Search Bar
              SliverToBoxAdapter(child: _buildActiveSearchBar(context, isDark)),

              // Selected Districts Chips
              if (_selectedDistricts.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildSelectedDistrictsChips(context, isDark),
                ),

              // Quick Filter Chips (Always Visible)
              SliverToBoxAdapter(child: _buildQuickFilters(context, isDark)),

              // Advanced Filters Panel (Expandable)
              if (_showFilters)
                SliverToBoxAdapter(
                  child: _buildAdvancedFilters(context, isDark),
                ),

              // Quick Actions (İlan Ver, İlanlarım, Favoriler)
              SliverToBoxAdapter(child: _buildQuickActions(context, isDark)),

              // Popular Districts Quick Access
              SliverToBoxAdapter(
                child: _buildPopularDistricts(context, isDark),
              ),

              // Featured Properties Carousel
              if (_featuredProperties.isNotEmpty && _searchQuery.isEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'Öne Çıkan İlanlar',
                    'Premium',
                    isDark,
                    icon: Icons.star_rounded,
                    iconColor: EmlakColors.accent,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildFeaturedCarousel(context, isDark),
                ),
              ],

              // All Properties Grid
              SliverToBoxAdapter(
                child: _buildPropertiesHeader(context, isDark),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _isLoading && _properties.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: EmlakColors.primary,
                            ),
                          ),
                        ),
                      )
                    : filteredProperties.isEmpty
                        ? SliverToBoxAdapter(
                            child: _buildEmptyState(context, isDark),
                          )
                        : SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 0.72,
                                ),
                            delegate: SliverChildBuilderDelegate((context, index) {
                              return _buildPropertyCard(
                                context,
                                filteredProperties[index],
                                index,
                                isDark,
                              );
                            }, childCount: filteredProperties.length),
                          ),
              ),

              // Bottom Padding
              SliverToBoxAdapter(child: SizedBox(height: context.bottomNavPadding)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, Size size, bool isDark) {
    return AnimatedBuilder(
      animation: _heroAnimation,
      builder: (context, child) {
        return Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                EmlakColors.primary,
                EmlakColors.secondary,
                EmlakColors.primaryDark,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated Background Pattern
              ...List.generate(4, (index) {
                return AnimatedBuilder(
                  animation: _floatingAnimation,
                  builder: (context, _) {
                    final offset =
                        _floatingAnimation.value * (index % 2 == 0 ? 1 : -1);
                    return Positioned(
                      top: 20 + (index * 35) + offset,
                      right: -20 + (index * 30),
                      child: Opacity(
                        opacity: 0.08 + (index * 0.02),
                        child: Transform.rotate(
                          angle: index * 0.3,
                          child: Icon(
                            Icons.home_work_rounded,
                            size: 60 + (index * 12),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),

              // Main Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => context.pop(),
                          ),
                          SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.5),
                              end: Offset.zero,
                            ).animate(_heroAnimation),
                            child: FadeTransition(
                              opacity: _heroAnimation,
                              child: const Text(
                                'EMLAK',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              // Mesajlar butonu
                              Consumer(
                                builder: (context, ref, _) {
                                  final unreadCount = ref.watch(totalUnreadMessagesProvider);
                                  return unreadCount.when(
                                    data: (count) => _buildGlassButton(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      badgeCount: count > 0 ? count : null,
                                      onTap: () => context.push('/emlak/chats'),
                                    ),
                                    loading: () => _buildGlassButton(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      onTap: () => context.push('/emlak/chats'),
                                    ),
                                    error: (_, __) => _buildGlassButton(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      onTap: () => context.push('/emlak/chats'),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildGlassButton(
                                icon: Icons.favorite_border_rounded,
                                onTap: () => context.push('/emlak/favorites'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Hero Text - Compact
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(-0.3, 0),
                          end: Offset.zero,
                        ).animate(_heroAnimation),
                        child: FadeTransition(
                          opacity: _heroAnimation,
                          child: Row(
                            children: [
                              Text(
                                'Hayalindeki Evi ',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              const Text(
                                'Keşfet',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationSelector(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: EmlakColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // City Selector
          InkWell(
            onTap: () => _showCityPicker(context, isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EmlakColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_city_rounded,
                      color: EmlakColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Şehir',
                          style: TextStyle(
                            fontSize: 12,
                            color: EmlakColors.textTertiary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedCity.isEmpty ? 'Tüm Şehirler' : _selectedCity,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: EmlakColors.textPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: EmlakColors.textSecondary(isDark),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: EmlakColors.border(isDark)),
          // District Selector - Multiple Selection
          InkWell(
            onTap: _selectedCity.isEmpty ? null : () => _showDistrictPicker(context, isDark),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EmlakColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: EmlakColors.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İlçe (Çoklu Seçim)',
                          style: TextStyle(
                            fontSize: 12,
                            color: EmlakColors.textTertiary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedCity.isEmpty
                              ? 'Önce şehir seçin'
                              : _selectedDistricts.isEmpty
                                  ? 'Tüm İlçeler'
                                  : '${_selectedDistricts.length} ilçe seçili',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedDistricts.isNotEmpty
                                ? EmlakColors.primary
                                : EmlakColors.textTertiary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedDistricts.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _selectedDistricts.clear()),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: EmlakColors.border(isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: EmlakColors.textSecondary(isDark),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: EmlakColors.textSecondary(isDark),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Active Search Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: EmlakColors.surface(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _searchFocusNode.hasFocus
                      ? EmlakColors.primary
                      : EmlakColors.border(isDark),
                  width: _searchFocusNode.hasFocus ? 2 : 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  color: EmlakColors.textPrimary(isDark),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Konum, özellik veya ilan ara...',
                  hintStyle: TextStyle(
                    color: EmlakColors.textTertiary(isDark),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: EmlakColors.primary,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: EmlakColors.textSecondary(isDark),
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onTap: () => setState(() {}),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter Toggle Button
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _showFilters
                    ? EmlakColors.primary
                    : EmlakColors.surface(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _showFilters
                      ? EmlakColors.primary
                      : EmlakColors.border(isDark),
                ),
              ),
              child: Stack(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: _showFilters ? Colors.white : EmlakColors.primary,
                    size: 22,
                  ),
                  if (activeFilterCount > 0 && !_showFilters)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: EmlakColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: EmlakColors.surface(isDark),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$activeFilterCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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

  Widget _buildSelectedDistrictsChips(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'Seçili: ',
            style: TextStyle(
              fontSize: 12,
              color: EmlakColors.textSecondary(isDark),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          ..._selectedDistricts.map((district) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  district,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                backgroundColor: EmlakColors.primary,
                deleteIcon: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
                onDeleted: () {
                  setState(() {
                    _selectedDistricts.remove(district);
                  });
                },
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickFilters(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Listing Type Chips
          _buildFilterChip(
            label: 'Satılık',
            isSelected: _selectedListingType == ListingType.sale,
            onTap: () => setState(() {
              _selectedListingType = _selectedListingType == ListingType.sale
                  ? null
                  : ListingType.sale;
            }),
            isDark: isDark,
            color: ListingType.sale.color,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Kiralık',
            isSelected: _selectedListingType == ListingType.rent,
            onTap: () => setState(() {
              _selectedListingType = _selectedListingType == ListingType.rent
                  ? null
                  : ListingType.rent;
            }),
            isDark: isDark,
            color: ListingType.rent.color,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: EmlakColors.border(isDark)),
          const SizedBox(width: 12),
          // Property Type Chips - Dinamik olarak DB'den
          ...ref.watch(propertyTypesProvider).when(
            data: (types) => types.map((type) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: type.label,
                  icon: type.iconData,
                  isSelected: _selectedPropertyTypeName == type.name,
                  onTap: () => setState(() {
                    _selectedPropertyTypeName = _selectedPropertyTypeName == type.name
                        ? null
                        : type.name;
                  }),
                  isDark: isDark,
                ),
              );
            }).toList(),
            loading: () => [const SizedBox(width: 100, child: LinearProgressIndicator())],
            error: (_, __) => PropertyType.values.map((type) {
              // Fallback - DB'den yüklenemezse enum kullan
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: type.label,
                  icon: type.icon,
                  isSelected: _selectedPropertyTypeName == type.name,
                  onTap: () => setState(() {
                    _selectedPropertyTypeName = _selectedPropertyTypeName == type.name
                        ? null
                        : type.name;
                  }),
                  isDark: isDark,
                ),
              );
            }).toList(),
          ),
          // Clear All Button
          if (activeFilterCount > 0) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _clearAllFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear_all, size: 16, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'Temizle',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
    IconData? icon,
  }) {
    final activeColor = color ?? EmlakColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : EmlakColors.surface(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : EmlakColors.border(isDark),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : EmlakColors.textSecondary(isDark),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : EmlakColors.textSecondary(isDark),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters(BuildContext context, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EmlakColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EmlakColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price Range
          Text(
            'Fiyat Aralığı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: EmlakColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPriceButton(
                  context,
                  isDark,
                  'Min',
                  _priceRange.start.toInt(),
                  () => _showPricePicker(context, isDark, true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '-',
                  style: TextStyle(color: EmlakColors.textSecondary(isDark)),
                ),
              ),
              Expanded(
                child: _buildPriceButton(
                  context,
                  isDark,
                  'Max',
                  _priceRange.end.toInt(),
                  () => _showPricePicker(context, isDark, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Room Count
          Text(
            'Oda Sayısı',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: EmlakColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildRoomChip('1+', 1, isDark),
              _buildRoomChip('2+', 2, isDark),
              _buildRoomChip('3+', 3, isDark),
              _buildRoomChip('4+', 4, isDark),
              _buildRoomChip('5+', 5, isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Area Range
          Text(
            'Alan (m²)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: EmlakColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: EmlakColors.primary,
              inactiveTrackColor: EmlakColors.border(isDark),
              thumbColor: EmlakColors.primary,
              overlayColor: EmlakColors.primary.withValues(alpha: 0.2),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 10,
              ),
            ),
            child: RangeSlider(
              values: _areaRange,
              min: 0,
              max: 500,
              divisions: 50,
              labels: RangeLabels(
                '${_areaRange.start.toInt()}m²',
                '${_areaRange.end.toInt()}m²',
              ),
              onChanged: (values) => setState(() => _areaRange = values),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_areaRange.start.toInt()}m²',
                style: TextStyle(
                  color: EmlakColors.textSecondary(isDark),
                  fontSize: 12,
                ),
              ),
              Text(
                '${_areaRange.end.toInt()}m²',
                style: TextStyle(
                  color: EmlakColors.textSecondary(isDark),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceButton(
    BuildContext context,
    bool isDark,
    String label,
    int value,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: EmlakColors.surface(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EmlakColors.border(isDark)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: EmlakColors.textTertiary(isDark),
                fontSize: 12,
              ),
            ),
            Text(
              value == 0 ? '-' : _formatPrice(value),
              style: TextStyle(
                color: EmlakColors.textPrimary(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomChip(String label, int value, bool isDark) {
    final isSelected = _minRooms == value;
    return GestureDetector(
      onTap: () => setState(() {
        _minRooms = _minRooms == value ? null : value;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? EmlakColors.primary : EmlakColors.surface(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? EmlakColors.primary
                : EmlakColors.border(isDark),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : EmlakColors.textSecondary(isDark),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPopularDistricts(BuildContext context, bool isDark) {
    if (_districts.isEmpty) return const SizedBox.shrink();
    final districts = _districts.take(6).toList(); // İlk 6 ilçeyi göster

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: EmlakColors.accent,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Popüler Bölgeler (çoklu seç)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EmlakColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: districts.map((district) {
              final isSelected = _selectedDistricts.contains(district);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedDistricts.remove(district);
                  } else {
                    _selectedDistricts.add(district);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? EmlakColors.primary
                        : EmlakColors.surface(isDark),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? EmlakColors.primary
                          : EmlakColors.border(isDark),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        district,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : EmlakColors.textSecondary(isDark),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
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

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  isDark,
                  Icons.add_circle_outline,
                  'İlan Ver',
                  'Mülkünü sat/kirala',
                  [EmlakColors.primary, const Color(0xFF059669)],
                  () => context.push('/emlak/add'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  isDark,
                  Icons.list_alt,
                  'İlanlarım',
                  'Yönet',
                  [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                  () => context.push('/emlak/my-listings'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  isDark,
                  Icons.chat_bubble_outline,
                  'Mesajlar',
                  'Görüşmelerim',
                  [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
                  () => context.push('/emlak/chats'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  isDark,
                  Icons.favorite_outline,
                  'Favoriler',
                  'Kaydedilenler',
                  [const Color(0xFFF97316), const Color(0xFFEA580C)],
                  () => context.push('/emlak/favorites'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                _searchQuery.isNotEmpty ? 'Arama Sonuçları' : 'Tüm İlanlar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: EmlakColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: EmlakColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filteredProperties.length}',
                  style: TextStyle(
                    color: EmlakColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Sort Button
          GestureDetector(
            onTap: () => _showSortOptions(context, isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedSort != SortOption.newest
                    ? EmlakColors.primary.withValues(alpha: 0.1)
                    : EmlakColors.surface(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedSort != SortOption.newest
                      ? EmlakColors.primary
                      : EmlakColors.border(isDark),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedSort.icon,
                    size: 18,
                    color: _selectedSort != SortOption.newest
                        ? EmlakColors.primary
                        : EmlakColors.textSecondary(isDark),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedSort == SortOption.newest
                        ? 'Sırala'
                        : _selectedSort.label.split(' ').first,
                    style: TextStyle(
                      color: _selectedSort != SortOption.newest
                          ? EmlakColors.primary
                          : EmlakColors.textSecondary(isDark),
                      fontSize: 13,
                      fontWeight: _selectedSort != SortOption.newest
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _selectedSort != SortOption.newest
                        ? EmlakColors.primary
                        : EmlakColors.textSecondary(isDark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: EmlakColors.textTertiary(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            'İlan Bulunamadı',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: EmlakColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? '"$_searchQuery" için sonuç bulunamadı'
                : 'Filtreleri değiştirerek tekrar deneyin',
            style: TextStyle(
              fontSize: 14,
              color: EmlakColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _clearAllFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: EmlakColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Filtreleri Temizle'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: EmlakColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
    bool isDark, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? EmlakColors.primary, size: 24),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: EmlakColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: EmlakColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                color: EmlakColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel(BuildContext context, bool isDark) {
    return SizedBox(
      height: 300,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.88),
        itemCount: _featuredProperties.length,
        itemBuilder: (context, index) {
          final property = _featuredProperties[index];
          return _buildFeaturedCard(context, property, index, isDark);
        },
      ),
    );
  }

  Widget _buildFeaturedCard(
    BuildContext context,
    Property property,
    int index,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => context.push('/emlak/property/${property.id}'),
      child: AnimatedBuilder(
        animation: _floatingAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatingAnimation.value * 0.3),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background Image
                    Image.network(
                      property.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: EmlakColors.primary.withValues(alpha: 0.3),
                        child: const Icon(
                          Icons.image,
                          size: 60,
                          color: Colors.white54,
                        ),
                      ),
                    ),

                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                          stops: const [0.3, 0.6, 1.0],
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row - Badges
                          Row(
                            children: [
                              _buildBadge(
                                property.listingType.label,
                                property.listingType.color,
                              ),
                              const SizedBox(width: 8),
                              if (property.isPremium)
                                _buildBadge(
                                  'Premium',
                                  EmlakColors.accent,
                                  icon: Icons.workspace_premium_rounded,
                                ),
                              const Spacer(),
                              _buildGlassButton(
                                icon: Icons.favorite_border_rounded,
                                onTap: () {},
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Property Info
                          Text(
                            property.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                property.location.shortAddress,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Features Row
                          Row(
                            children: [
                              _buildFeatureChip(
                                Icons.bed_outlined,
                                '${property.rooms}+1',
                              ),
                              const SizedBox(width: 12),
                              _buildFeatureChip(
                                Icons.bathtub_outlined,
                                '${property.bathrooms}',
                              ),
                              const SizedBox(width: 12),
                              _buildFeatureChip(
                                Icons.square_foot,
                                '${property.squareMeters}m²',
                              ),
                              const Spacer(),
                              // Emlakçı fotoğrafı
                              if (property.agent?.isRealtor == true) ...[
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: EmlakColors.primary.withValues(alpha: 0.1),
                                        backgroundImage: property.agent?.imageUrl != null
                                            ? NetworkImage(property.agent!.imageUrl!)
                                            : null,
                                        child: property.agent?.imageUrl == null
                                            ? Icon(Icons.business, size: 16, color: EmlakColors.primary)
                                            : null,
                                      ),
                                      if (property.agent?.isVerified == true)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(1),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.verified, size: 10, color: EmlakColors.primary),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                property.fullFormattedPrice,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(
    BuildContext context,
    Property property,
    int index,
    bool isDark,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () => context.push('/emlak/property/${property.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: EmlakColors.card(isDark),
            borderRadius: BorderRadius.circular(20),
            // Premium/Featured ilanlar için altın kenarlık
            border: property.isPremium
                ? Border.all(color: EmlakColors.accent, width: 2)
                : property.isFeatured
                    ? Border.all(color: EmlakColors.accent.withValues(alpha: 0.5), width: 1.5)
                    : null,
            boxShadow: [
              BoxShadow(
                color: property.isPremium
                    ? EmlakColors.accent.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: property.isPremium ? 20 : 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(property.isPremium || property.isFeatured ? 18 : 20),
                      ),
                      child: Image.network(
                        property.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: EmlakColors.primary.withValues(alpha: 0.2),
                          child: const Icon(Icons.image, color: Colors.white54),
                        ),
                      ),
                    ),
                    // Badges
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Row(
                        children: [
                          _buildBadge(
                            property.listingType.label,
                            property.listingType.color,
                          ),
                          if (property.isPremium) ...[
                            const SizedBox(width: 6),
                            _buildBadge(
                              'Premium',
                              EmlakColors.accent,
                              icon: Icons.workspace_premium_rounded,
                            ),
                          ] else if (property.isFeatured) ...[
                            const SizedBox(width: 6),
                            _buildBadge(
                              'Öne Çıkan',
                              EmlakColors.accent.withValues(alpha: 0.8),
                              icon: Icons.star_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Favorite Button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 32,
                        height: 32,
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
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    // Emlakçı Fotoğrafı (sadece emlakçı ilanları için)
                    if (property.agent?.isRealtor == true)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: EmlakColors.primary.withValues(alpha: 0.1),
                                backgroundImage: property.agent?.imageUrl != null
                                    ? NetworkImage(property.agent!.imageUrl!)
                                    : null,
                                child: property.agent?.imageUrl == null
                                    ? Icon(
                                        Icons.business,
                                        size: 18,
                                        color: EmlakColors.primary,
                                      )
                                    : null,
                              ),
                              // Onaylı rozeti
                              if (property.agent?.isVerified == true)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.verified,
                                      size: 12,
                                      color: EmlakColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: EmlakColors.textPrimary(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: EmlakColors.textTertiary(isDark),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              property.location.shortAddress,
                              style: TextStyle(
                                fontSize: 10,
                                color: EmlakColors.textTertiary(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Features
                      Row(
                        children: [
                          _buildSmallFeature(
                            Icons.bed_outlined,
                            '${property.rooms}',
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildSmallFeature(
                            Icons.square_foot,
                            '${property.squareMeters}',
                            isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property.fullFormattedPrice,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: EmlakColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallFeature(IconData icon, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: EmlakColors.textTertiary(isDark)),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: EmlakColors.textSecondary(isDark),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFAB(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/emlak/add'),
            backgroundColor: EmlakColors.primary,
            elevation: 8,
            icon: const Icon(Icons.add_home_rounded, color: Colors.white),
            label: const Text(
              'İlan Ver',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method
  String _formatPrice(int price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toString();
  }

  // Bottom Sheet: City Picker
  void _showCityPicker(BuildContext context, bool isDark) {
    final cities = _cities;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: EmlakColors.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EmlakColors.border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Şehir Seçin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EmlakColors.textPrimary(isDark),
                ),
              ),
            ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: cities.length + 1, // +1 for "Tüm Şehirler"
                itemBuilder: (context, index) {
                  // İlk eleman "Tüm Şehirler"
                  if (index == 0) {
                    final isSelected = _selectedCity.isEmpty;
                    return ListTile(
                      leading: Icon(
                        Icons.public_rounded,
                        color: isSelected
                            ? EmlakColors.primary
                            : EmlakColors.textTertiary(isDark),
                      ),
                      title: Text(
                        'Tüm Şehirler',
                        style: TextStyle(
                          color: EmlakColors.textPrimary(isDark),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: EmlakColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCity = '';
                          _selectedDistricts.clear();
                          _districts = [];
                        });
                        Navigator.pop(context);
                      },
                    );
                  }

                  final city = cities[index - 1];
                  final isSelected = city == _selectedCity;
                  return ListTile(
                    leading: Icon(
                      Icons.location_city_rounded,
                      color: isSelected
                          ? EmlakColors.primary
                          : EmlakColors.textTertiary(isDark),
                    ),
                    title: Text(
                      city,
                      style: TextStyle(
                        color: EmlakColors.textPrimary(isDark),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: EmlakColors.primary)
                        : null,
                    onTap: () async {
                      setState(() {
                        _selectedCity = city;
                        _selectedDistricts
                            .clear(); // Reset districts when city changes
                      });
                      Navigator.pop(context);
                      // Yeni şehrin ilçelerini yükle
                      await _loadDistricts();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Bottom Sheet: District Picker - Multiple Selection
  void _showDistrictPicker(BuildContext context, bool isDark) {
    final allDistricts = _districts;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: EmlakColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EmlakColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedCity.isEmpty ? 'KKTC' : _selectedCity} - İlçe Seçin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: EmlakColors.textPrimary(isDark),
                      ),
                    ),
                    if (_selectedDistricts.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setModalState(() {});
                          setState(() => _selectedDistricts.clear());
                        },
                        child: Text(
                          'Temizle',
                          style: TextStyle(color: EmlakColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
              // Selected count
              if (_selectedDistricts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: EmlakColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: EmlakColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedDistricts.length} ilçe seçildi',
                          style: TextStyle(
                            color: EmlakColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: allDistricts.length,
                  itemBuilder: (context, index) {
                    final district = allDistricts[index];
                    final isSelected = _selectedDistricts.contains(district);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setModalState(() {
                          if (value == true) {
                            _selectedDistricts.add(district);
                          } else {
                            _selectedDistricts.remove(district);
                          }
                        });
                        setState(() {});
                      },
                      title: Text(
                        district,
                        style: TextStyle(
                          color: EmlakColors.textPrimary(isDark),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      secondary: Icon(
                        Icons.location_on_rounded,
                        color: isSelected
                            ? EmlakColors.primary
                            : EmlakColors.textTertiary(isDark),
                      ),
                      activeColor: EmlakColors.primary,
                      checkColor: Colors.white,
                    );
                  },
                ),
              ),
              // Done Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EmlakColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selectedDistricts.isEmpty
                          ? 'Tüm İlçeleri Göster'
                          : '${_selectedDistricts.length} İlçe ile Ara',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom Sheet: Price Picker
  void _showPricePicker(BuildContext context, bool isDark, bool isMin) {
    final prices = [
      0,
      500000,
      1000000,
      2000000,
      3000000,
      5000000,
      7500000,
      10000000,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: EmlakColors.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EmlakColors.border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                isMin ? 'Minimum Fiyat' : 'Maksimum Fiyat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EmlakColors.textPrimary(isDark),
                ),
              ),
            ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: prices.length,
                itemBuilder: (context, index) {
                  final price = prices[index];
                  final currentValue = isMin
                      ? _priceRange.start
                      : _priceRange.end;
                  final isSelected = price == currentValue.toInt();

                  return ListTile(
                    title: Text(
                      price == 0 ? 'Limit Yok' : '${_formatPrice(price)} TL',
                      style: TextStyle(
                        color: EmlakColors.textPrimary(isDark),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: EmlakColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        if (isMin) {
                          _priceRange = RangeValues(
                            price.toDouble(),
                            _priceRange.end,
                          );
                        } else {
                          _priceRange = RangeValues(
                            _priceRange.start,
                            price.toDouble(),
                          );
                        }
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Bottom Sheet: Sort Options
  void _showSortOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: EmlakColors.card(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EmlakColors.border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Sıralama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: EmlakColors.textPrimary(isDark),
                ),
              ),
            ),
            ...SortOption.values.map((option) {
              final isSelected = _selectedSort == option;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? EmlakColors.primary.withValues(alpha: 0.1)
                        : EmlakColors.surface(isDark),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    option.icon,
                    color: isSelected
                        ? EmlakColors.primary
                        : EmlakColors.textSecondary(isDark),
                    size: 20,
                  ),
                ),
                title: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected
                        ? EmlakColors.primary
                        : EmlakColors.textPrimary(isDark),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: EmlakColors.primary,
                        size: 22,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedSort = option);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
