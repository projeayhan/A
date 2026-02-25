import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_responsive.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/providers/emlak_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/providers/banner_provider.dart';
import '../../widgets/common/generic_banner_carousel.dart';
import 'property_filter_screen.dart';

class EmlakHomeScreen extends ConsumerStatefulWidget {
  const EmlakHomeScreen({super.key});

  @override
  ConsumerState<EmlakHomeScreen> createState() => _EmlakHomeScreenState();
}

class _EmlakHomeScreenState extends ConsumerState<EmlakHomeScreen> {

  final ScrollController _scrollController = ScrollController();

  // Filter States - All accessible from main page
  String _selectedCity = ''; // Boş = Tüm Şehirler
  final Set<String> _selectedDistricts = {}; // Multiple district selection
  ListingType? _selectedListingType;
  String? _selectedPropertyTypeName; // Dinamik property type (DB'den)
  RangeValues _priceRange = const RangeValues(0, 10000000);
  RangeValues _areaRange = const RangeValues(0, 500);
  int? _minRooms;

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

      // Provider'a şehir filtresini gönder
      _applyFiltersToProvider();
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

  /// Seçili filtreleri provider'a gönder (DB seviyesinde filtre uygular)
  void _applyFiltersToProvider() {
    ref.read(propertyListProvider.notifier).setFilter(
      PropertyFilter(
        city: _selectedCity.isEmpty ? null : _selectedCity,
        district: _selectedDistricts.length == 1 ? _selectedDistricts.first : null,
        listingType: _selectedListingType,
      ),
    );
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<Property> get filteredProperties {
    var list = _properties.toList();
    // Not: Şehir filtresi artık provider (DB) seviyesinde uygulanıyor

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

  Future<void> _openFilterScreen() async {
    // Mevcut filtre durumunu PropertyFilter'a dönüştür
    final currentFilter = PropertyFilter(
      selectedPropertyTypes: _selectedPropertyTypeName != null
          ? {_selectedPropertyTypeName!}
          : null,
      listingType: _selectedListingType,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 10000000 ? _priceRange.end : null,
      minSquareMeters: _areaRange.start > 0 ? _areaRange.start.toInt() : null,
      maxSquareMeters: _areaRange.end < 500 ? _areaRange.end.toInt() : null,
      city: _selectedCity.isEmpty ? null : _selectedCity,
      district: _selectedDistricts.length == 1 ? _selectedDistricts.first : null,
    );

    final result = await Navigator.push<PropertyFilter>(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyFilterScreen(initialFilter: currentFilter),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedListingType = result.listingType;
        // Tek tip seçildiyse chip'i aktif yap, çoklu seçimde local filtre uygulanmasın
        // (DB sorgusu zaten multi-select'i doğru şekilde filtreliyor)
        _selectedPropertyTypeName = result.selectedPropertyTypes?.length == 1
            ? result.selectedPropertyTypes!.first
            : null;
        _selectedCity = result.city ?? '';
        _selectedDistricts.clear();
        if (result.district != null) _selectedDistricts.add(result.district!);
        _minRooms = null; // roomTypes artık multi-select
        _priceRange = RangeValues(
          result.minPrice ?? 0,
          result.maxPrice ?? 10000000,
        );
        _areaRange = RangeValues(
          result.minSquareMeters?.toDouble() ?? 0,
          result.maxSquareMeters?.toDouble() ?? 500,
        );
        _searchController.text = result.keyword ?? '';
        _searchQuery = result.keyword?.toLowerCase() ?? '';
      });
      // Şehir değişmişse ilçeleri yeniden yükle
      _loadDistricts();
      // Tüm filtreyi provider'a gönder (DB seviyesinde uygula)
      ref.read(propertyListProvider.notifier).setFilter(result);
    }
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
    _applyFiltersToProvider();
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
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: EmlakColors.background(isDark),
          floatingActionButton: _buildFAB(context),
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: EmlakColors.primary,
            child: CustomScrollView(
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

              // Advanced Filters → Tam ekran filtre sayfasına taşındı

              // Quick Actions (İlan Ver, İlanlarım, Favoriler)
              SliverToBoxAdapter(child: _buildQuickActions(context, isDark)),

              // Featured Properties Carousel
              if (_featuredProperties.isNotEmpty && _searchQuery.isEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'Öne Çıkan İlanlar',
                    'Tümünü Gör',
                    isDark,
                    icon: Icons.star_rounded,
                    iconColor: EmlakColors.accent,
                    onViewAll: () => context.push('/emlak/featured', extra: {
                      'city': _selectedCity.isNotEmpty ? _selectedCity : null,
                    }),
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
                        : SliverList(
                            delegate: SliverChildBuilderDelegate((context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildPropertyCard(
                                  context,
                                  filteredProperties[index],
                                  index,
                                  isDark,
                                ),
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
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, Size size, bool isDark) {
    return Container(
      color: EmlakColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const Expanded(
                child: Text(
                  'Emlak',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final unreadCount = ref.watch(totalUnreadMessagesProvider);
                  return unreadCount.when(
                    data: (count) => _buildHeaderIcon(
                      Icons.chat_bubble_outline_rounded,
                      badgeCount: count > 0 ? count : null,
                      onTap: () => context.push('/emlak/chats'),
                    ),
                    loading: () => _buildHeaderIcon(
                      Icons.chat_bubble_outline_rounded,
                      onTap: () => context.push('/emlak/chats'),
                    ),
                    error: (_, __) => _buildHeaderIcon(
                      Icons.chat_bubble_outline_rounded,
                      onTap: () => context.push('/emlak/chats'),
                    ),
                  );
                },
              ),
              _buildHeaderIcon(
                Icons.favorite_border_rounded,
                onTap: () => context.push('/emlak/favorites'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(
    IconData icon, {
    VoidCallback? onTap,
    int? badgeCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 22),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
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
                    IconButton(
                      onPressed: () {
                        setState(() => _selectedDistricts.clear());
                        _applyFiltersToProvider();
                      },
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: EmlakColors.textSecondary(isDark),
                      ),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
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
          // Filter Button → Tam ekran filtre sayfasını aç
          Material(
            color: Colors.transparent,
            child: InkWell(
            onTap: () => _openFilterScreen(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: activeFilterCount > 0
                    ? EmlakColors.primary
                    : EmlakColors.surface(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: activeFilterCount > 0
                      ? EmlakColors.primary
                      : EmlakColors.border(isDark),
                ),
              ),
              child: Stack(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: activeFilterCount > 0
                        ? Colors.white
                        : EmlakColors.primary,
                    size: 22,
                  ),
                  if (activeFilterCount > 0)
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
                            color: activeFilterCount > 0
                                ? EmlakColors.primary
                                : EmlakColors.surface(isDark),
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
                  _applyFiltersToProvider();
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
            ActionChip(
              label: const Text('Temizle', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              avatar: const Icon(Icons.clear_all, size: 16, color: Colors.red),
              backgroundColor: Colors.red.withValues(alpha: 0.1),
              side: BorderSide.none,
              onPressed: _clearAllFilters,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
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
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _buildQuickActionChip(
            isDark,
            Icons.add_home_rounded,
            'İlan Ver',
            EmlakColors.primary,
            () => context.push('/emlak/add'),
          ),
          const SizedBox(width: 10),
          _buildQuickActionChip(
            isDark,
            Icons.list_alt_rounded,
            'İlanlarım',
            const Color(0xFF3B82F6),
            () => context.push('/emlak/my-listings'),
          ),
          const SizedBox(width: 10),
          _buildQuickActionChip(
            isDark,
            Icons.chat_bubble_outline_rounded,
            'Mesajlar',
            const Color(0xFF8B5CF6),
            () => context.push('/emlak/chats'),
          ),
          const SizedBox(width: 10),
          _buildQuickActionChip(
            isDark,
            Icons.favorite_outline_rounded,
            'Favoriler',
            const Color(0xFFF97316),
            () => context.push('/emlak/favorites'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(
    bool isDark,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertiesHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showSortOptions(context, isDark),
              borderRadius: BorderRadius.circular(20),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
    VoidCallback? onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
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
          onViewAll != null
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onViewAll,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: EmlakColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: EmlakColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: EmlakColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Container(
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/emlak/property/${property.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
                  children: [
                    // Background Image
                    if (property.images.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: property.images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: EmlakColors.primary.withValues(alpha: 0.3),
                          child: const Icon(
                            Icons.image,
                            size: 60,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: EmlakColors.primary.withValues(alpha: 0.3),
                        child: const Icon(Icons.home, size: 60, color: Colors.white54),
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
                      padding: const EdgeInsets.all(16),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/emlak/property/${property.id}');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: EmlakColors.card(isDark),
            borderRadius: BorderRadius.circular(14),
            border: property.isPremium
                ? Border.all(color: EmlakColors.accent, width: 2)
                : property.isFeatured
                    ? Border.all(color: EmlakColors.accent.withValues(alpha: 0.5), width: 1.5)
                    : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image - full width
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: property.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: property.images.first,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 200,
                              color: EmlakColors.surface(isDark),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: EmlakColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 200,
                              color: EmlakColors.surface(isDark),
                              child: Icon(Icons.home, size: 48, color: EmlakColors.textTertiary(isDark)),
                            ),
                          )
                        : Container(
                            height: 200,
                            color: EmlakColors.surface(isDark),
                            child: Icon(Icons.home, size: 48, color: EmlakColors.textTertiary(isDark)),
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
                          _buildBadge('Premium', EmlakColors.accent, icon: Icons.workspace_premium_rounded),
                        ] else if (property.isFeatured) ...[
                          const SizedBox(width: 6),
                          _buildBadge('Öne Çıkan', EmlakColors.accent.withValues(alpha: 0.8), icon: Icons.star_rounded),
                        ],
                      ],
                    ),
                  ),
                  // Image count
                  if (property.images.length > 1)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${property.images.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Emlakçı Fotoğrafı
                  if (property.agent?.isRealtor == true)
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
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
                    ),
                ],
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
                        fontWeight: FontWeight.w600,
                        color: EmlakColors.textPrimary(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: EmlakColors.textSecondary(isDark)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location.shortAddress,
                            style: TextStyle(
                              fontSize: 13,
                              color: EmlakColors.textSecondary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Features + Price Row
                    Row(
                      children: [
                        _buildSmallFeature(Icons.bed_outlined, '${property.rooms}+1', isDark),
                        const SizedBox(width: 12),
                        _buildSmallFeature(Icons.bathtub_outlined, '${property.bathrooms}', isDark),
                        const SizedBox(width: 12),
                        _buildSmallFeature(Icons.square_foot, '${property.squareMeters}m²', isDark),
                        const Spacer(),
                        Text(
                          property.fullFormattedPrice,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: EmlakColors.primary,
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
    return FloatingActionButton.extended(
      onPressed: () => context.push('/emlak/add'),
      backgroundColor: EmlakColors.primary,
      elevation: 4,
      icon: const Icon(Icons.add_home_rounded, color: Colors.white),
      label: const Text(
        'İlan Ver',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
                        _applyFiltersToProvider();
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
                        _selectedDistricts.clear();
                        _districts = []; // Eski ilçeleri temizle
                      });
                      Navigator.pop(context);
                      _applyFiltersToProvider();
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
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFiltersToProvider();
                    },
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
