import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_responsive.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../services/car_sales_service.dart';
import 'car_detail_screen.dart';
import 'add_car_listing_screen.dart';
import 'my_car_listings_screen.dart';
import 'car_search_screen.dart';
import 'brand_search_sheet.dart';
import 'advanced_filter_sheet.dart';
import 'filter_selection_sheet.dart';

class CarSalesHomeScreen extends StatefulWidget {
  const CarSalesHomeScreen({super.key});

  @override
  State<CarSalesHomeScreen> createState() => _CarSalesHomeScreenState();
}

class _CarSalesHomeScreenState extends State<CarSalesHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  final ScrollController _scrollController = ScrollController();

  // Supabase service
  final CarSalesService _carSalesService = CarSalesService.instance;

  // Gerçek veriler
  List<CarListingData> _recentListings = [];
  List<CarListingData> _filteredListings = [];
  bool _isLoading = true;
  int _totalActiveListings = 0;

  // Gelişmiş filtre state'leri
  final Set<String> _selectedBodyTypeIds = {};
  final Set<String> _selectedFuelTypeIds = {};
  final Set<String> _selectedTransmissionIds = {};
  final Set<String> _selectedBrandIds = {};
  CarSortOption _currentSortOption = CarSortOption.newest;
  RangeValues _priceRange = const RangeValues(0, 50000000);
  RangeValues _yearRange = RangeValues(2010, DateTime.now().year.toDouble());
  RangeValues _mileageRange = const RangeValues(0, 500000);
  bool _isGridView = false;

  // Supabase'den gelen filtre tipleri
  List<CarBodyTypeData> _bodyTypesData = [];
  List<CarFuelTypeData> _fuelTypesData = [];
  List<CarTransmissionData> _transmissionsData = [];

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutBack,
    );

    _headerController.forward();

    // Gerçek verileri yükle
    _loadData();
  }

  /// CarListingData'yı CarListing'e dönüştür
  CarListing _convertToCarListing(CarListingData data) {
    // Brand'ı bul veya varsayılan kullan
    final brand = CarBrand.allBrands.firstWhere(
      (b) => b.name.toLowerCase().contains(data.brandName.toLowerCase()) ||
             data.brandName.toLowerCase().contains(b.name.toLowerCase()),
      orElse: () => CarBrand.allBrands.first,
    );

    // Rengi parse et
    CarColor exteriorColor = CarColor.white;
    try {
      exteriorColor = CarColor.values.firstWhere(
        (c) => c.label.toLowerCase() == (data.exteriorColor?.toLowerCase() ?? ''),
        orElse: () => CarColor.white,
      );
    } catch (_) {}

    // Kondisyonu parse et
    CarCondition condition = CarCondition.good;
    try {
      condition = CarCondition.values.firstWhere(
        (c) => c.name == data.condition,
        orElse: () => CarCondition.good,
      );
    } catch (_) {}

    // Traction'ı parse et
    CarTraction traction = CarTraction.fwd;
    try {
      traction = CarTraction.values.firstWhere(
        (t) => t.name == data.traction,
        orElse: () => CarTraction.fwd,
      );
    } catch (_) {}

    // Varsayılan satıcı oluştur - user_id kullan (dealer.id değil!)
    final seller = CarSeller(
      id: data.userId, // Satıcının auth.users ID'si
      name: data.dealer?.ownerName ?? 'Satıcı',
      phone: data.dealer?.phone ?? '',
      type: data.dealer?.isVerified == true ? SellerType.dealer : SellerType.individual,
      companyName: data.dealer?.businessName,
      isVerified: data.dealer?.isVerified ?? false,
      memberSince: DateTime.now().subtract(const Duration(days: 365)),
    );

    return CarListing(
      id: data.id,
      title: data.title,
      description: data.description ?? data.title,
      brand: brand,
      modelName: data.modelName,
      year: data.year,
      mileage: data.mileage,
      bodyType: data.bodyTypeEnum,
      fuelType: data.fuelTypeEnum,
      transmission: data.transmissionEnum,
      traction: traction,
      engineCC: data.engineCc ?? 1600,
      horsePower: data.horsepower ?? 120,
      exteriorColor: exteriorColor,
      interiorColor: CarColor.black,
      condition: condition,
      price: data.price,
      isPriceNegotiable: data.isPriceNegotiable,
      isExchangeAccepted: data.isExchangeAccepted,
      status: data.statusEnum,
      seller: seller,
      images: data.images.isNotEmpty
          ? data.images
          : ['https://via.placeholder.com/400x300?text=No+Image'],
      featureIds: data.features,
      createdAt: data.createdAt,
      viewCount: data.viewCount,
      favoriteCount: data.favoriteCount,
      isFeatured: data.isFeatured,
      isPremiumListing: data.isPremium,
      city: data.city,
      district: data.district,
    );
  }

  /// Supabase'den verileri yükle
  Future<void> _loadData({bool forceRefresh = false}) async {
    if (forceRefresh && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final results = await Future.wait([
        _carSalesService.getActiveListings(limit: 50),
        _carSalesService.getBodyTypes(),
        _carSalesService.getFuelTypes(),
        _carSalesService.getTransmissions(),
      ]);

      if (mounted) {
        setState(() {
          _recentListings = results[0] as List<CarListingData>;
          _filteredListings = results[0] as List<CarListingData>;
          _totalActiveListings = _recentListings.length;
          _bodyTypesData = results[1] as List<CarBodyTypeData>;
          _fuelTypesData = results[2] as List<CarFuelTypeData>;
          _transmissionsData = results[3] as List<CarTransmissionData>;
          _isLoading = false;
        });

        if (forceRefresh) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veriler güncellendi'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('CarSalesHomeScreen._loadData error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Gelişmiş filtreleme
  void _applyFilter() {
    _filteredListings = _recentListings.where((listing) {
      if (_selectedBodyTypeIds.isNotEmpty &&
          !_selectedBodyTypeIds.contains(listing.bodyType)) {
        return false;
      }
      if (_selectedFuelTypeIds.isNotEmpty &&
          !_selectedFuelTypeIds.contains(listing.fuelType)) {
        return false;
      }
      if (_selectedTransmissionIds.isNotEmpty &&
          !_selectedTransmissionIds.contains(listing.transmission)) {
        return false;
      }
      if (_selectedBrandIds.isNotEmpty) {
        if (!_selectedBrandIds.contains(listing.brandId)) {
          return false;
        }
      }
      if (listing.price < _priceRange.start || listing.price > _priceRange.end) {
        return false;
      }
      if (listing.year < _yearRange.start || listing.year > _yearRange.end) {
        return false;
      }
      if (listing.mileage < _mileageRange.start || listing.mileage > _mileageRange.end) {
        return false;
      }
      return true;
    }).toList();

    _sortListings();
  }

  /// Sıralama uygula
  void _sortListings() {
    switch (_currentSortOption) {
      case CarSortOption.newest:
        _filteredListings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case CarSortOption.oldest:
        _filteredListings.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case CarSortOption.priceLow:
        _filteredListings.sort((a, b) => a.price.compareTo(b.price));
        break;
      case CarSortOption.priceHigh:
        _filteredListings.sort((a, b) => b.price.compareTo(a.price));
        break;
      case CarSortOption.mileageLow:
        _filteredListings.sort((a, b) => a.mileage.compareTo(b.mileage));
        break;
      case CarSortOption.mileageHigh:
        _filteredListings.sort((a, b) => b.mileage.compareTo(a.mileage));
        break;
      case CarSortOption.yearNew:
        _filteredListings.sort((a, b) => b.year.compareTo(a.year));
        break;
      case CarSortOption.yearOld:
        _filteredListings.sort((a, b) => a.year.compareTo(b.year));
        break;
    }
  }

  /// Fiyat formatlama
  String _formatPrice(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M ₺';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K ₺';
    }
    return '${value.toStringAsFixed(0)} ₺';
  }

  /// Kilometre formatlama
  String _formatMileage(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K km';
    }
    return '$value km';
  }

  /// Aktif filtre sayısı
  int get _activeFilterCount {
    int count = 0;
    if (_selectedBodyTypeIds.isNotEmpty) count++;
    if (_selectedFuelTypeIds.isNotEmpty) count++;
    if (_selectedTransmissionIds.isNotEmpty) count++;
    if (_selectedBrandIds.isNotEmpty) count++;
    if (_priceRange.start > 0 || _priceRange.end < 50000000) count++;
    if (_yearRange.start > 2010 || _yearRange.end < DateTime.now().year) count++;
    if (_mileageRange.start > 0 || _mileageRange.end < 500000) count++;
    return count;
  }

  /// Tüm filtreleri temizle
  void _clearAllFilters() {
    setState(() {
      _selectedBodyTypeIds.clear();
      _selectedFuelTypeIds.clear();
      _selectedTransmissionIds.clear();
      _selectedBrandIds.clear();
      _priceRange = const RangeValues(0, 50000000);
      _yearRange = RangeValues(2010, DateTime.now().year.toDouble());
      _mileageRange = const RangeValues(0, 500000);
      _currentSortOption = CarSortOption.newest;
      _filteredListings = _recentListings;
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CarSalesColors.background(isDark),
        body: Stack(
          children: [
            // Main content with RefreshIndicator
            RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true),
              color: CarSalesColors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // App Bar
                  _buildSliverAppBar(isDark, size),

                  // Compact Filter Bar
                  SliverToBoxAdapter(
                    child: _buildCompactFilterBar(isDark),
                  ),

                  // Popular Brands
                  SliverToBoxAdapter(
                    child: _buildPopularBrands(isDark),
                  ),

                  // Sort & View Bar
                  SliverToBoxAdapter(
                    child: _buildSortAndViewBar(isDark),
                  ),

                  // Active Filters
                  if (_activeFilterCount > 0)
                    SliverToBoxAdapter(
                      child: _buildActiveFilters(isDark),
                    ),

                  // İlanlar
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(isDark, 'İlanlar'),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildRecentListings(isDark),
                  ),

                  // Bottom spacing
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.bottomNavPadding),
                  ),
                ],
              ),
            ),

            // Floating Add Button
            _buildFloatingAddButton(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, Size size) {
    final collapsedHeight = 60.0 + MediaQuery.of(context).padding.top;

    return SliverAppBar(
      expandedHeight: 120,
      collapsedHeight: collapsedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                  : CarSalesColors.primaryGradient,
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _headerAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(_headerAnimation),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                  child: Row(
                    children: [
                      // Logo & Title
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Araç Satış',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '$_totalActiveListings aktif ilan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quick action icons
                      _buildAppBarIcon(Icons.list_alt, () => _navigateToMyListings()),
                      _buildAppBarIcon(Icons.favorite_outline, () => context.push('/car-sales/favorites')),
                      _buildAppBarIcon(Icons.chat_bubble_outline, () => context.push('/car-sales/chats')),
                      _buildAppBarIcon(Icons.search, () => _navigateToSearch()),
                      _buildAppBarIcon(Icons.tune, () => _showFilterSheet()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  /// Kompakt filtre bar'ı
  Widget _buildCompactFilterBar(bool isDark) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Gövde',
            icon: Icons.directions_car_outlined,
            selectedCount: _selectedBodyTypeIds.length,
            onTap: () => _showBodyTypeSheet(isDark),
          ),
          const SizedBox(width: 8),
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Yakıt',
            icon: Icons.local_gas_station_outlined,
            selectedCount: _selectedFuelTypeIds.length,
            onTap: () => _showFuelTypeSheet(isDark),
          ),
          const SizedBox(width: 8),
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Vites',
            icon: Icons.settings_outlined,
            selectedCount: _selectedTransmissionIds.length,
            onTap: () => _showTransmissionSheet(isDark),
          ),
          const SizedBox(width: 8),
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Fiyat',
            icon: Icons.attach_money,
            selectedCount: (_priceRange.start > 0 || _priceRange.end < 50000000) ? 1 : 0,
            onTap: () => _showFilterSheet(),
          ),
          const SizedBox(width: 8),
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Tümü',
            icon: Icons.tune,
            selectedCount: _activeFilterCount,
            isAccent: true,
            onTap: () => _showFilterSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdownButton({
    required bool isDark,
    required String label,
    required IconData icon,
    required int selectedCount,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    final hasSelection = selectedCount > 0;
    final bgColor = isAccent
        ? CarSalesColors.primary.withValues(alpha: 0.1)
        : hasSelection
            ? CarSalesColors.primary.withValues(alpha: 0.1)
            : CarSalesColors.card(isDark);
    final borderColor = isAccent || hasSelection
        ? CarSalesColors.primary
        : CarSalesColors.border(isDark);
    final textColor = isAccent || hasSelection
        ? CarSalesColors.primary
        : CarSalesColors.textSecondary(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: hasSelection ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (hasSelection) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CarSalesColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  selectedCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: textColor),
          ],
        ),
      ),
    );
  }

  void _showBodyTypeSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSelectionSheet<CarBodyTypeData>(
        isDark: isDark,
        title: 'Gövde Tipi Seçin',
        items: _bodyTypesData,
        selectedIds: _selectedBodyTypeIds,
        getLabel: (t) => t.name,
        getIcon: (t) => _getIconDataForBodyType(t.icon),
        getId: (t) => t.id,
        onChanged: (ids) {
          setState(() {
            _selectedBodyTypeIds.clear();
            _selectedBodyTypeIds.addAll(ids);
            _applyFilter();
          });
        },
      ),
    );
  }

  void _showFuelTypeSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSelectionSheet<CarFuelTypeData>(
        isDark: isDark,
        title: 'Yakıt Tipi Seçin',
        items: _fuelTypesData,
        selectedIds: _selectedFuelTypeIds,
        getLabel: (t) => t.name,
        getIcon: (t) => _getIconDataForFuelType(t.icon),
        getId: (t) => t.id,
        getColor: (t) => t.colorValue,
        onChanged: (ids) {
          setState(() {
            _selectedFuelTypeIds.clear();
            _selectedFuelTypeIds.addAll(ids);
            _applyFilter();
          });
        },
      ),
    );
  }

  void _showTransmissionSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSelectionSheet<CarTransmissionData>(
        isDark: isDark,
        title: 'Vites Tipi Seçin',
        items: _transmissionsData,
        selectedIds: _selectedTransmissionIds,
        getLabel: (t) => t.name,
        getIcon: (t) => _getIconDataForTransmission(t.icon),
        getId: (t) => t.id,
        onChanged: (ids) {
          setState(() {
            _selectedTransmissionIds.clear();
            _selectedTransmissionIds.addAll(ids);
            _applyFilter();
          });
        },
      ),
    );
  }

  Widget _buildSortAndViewBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_filteredListings.length} araç bulundu',
              style: TextStyle(
                color: CarSalesColors.textSecondary(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CarSalesColors.surface(isDark),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CarSalesColors.border(isDark)),
            ),
            child: InkWell(
              onTap: () => _showSortOptions(isDark),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentSortOption.icon,
                    size: 14,
                    color: CarSalesColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentSortOption.label.split(' ').first,
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: CarSalesColors.textSecondary(isDark),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: CarSalesColors.surface(isDark),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CarSalesColors.border(isDark)),
            ),
            child: Row(
              children: [
                _buildViewToggle(isDark, Icons.view_list, !_isGridView, () {
                  setState(() => _isGridView = false);
                }),
                _buildViewToggle(isDark, Icons.grid_view, _isGridView, () {
                  setState(() => _isGridView = true);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(bool isDark, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? CarSalesColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : CarSalesColors.textSecondary(isDark),
        ),
      ),
    );
  }

  void _showSortOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: CarSalesColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: CarSalesColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sırala',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...CarSortOption.values.map((option) => InkWell(
                onTap: () {
                  setState(() {
                    _currentSortOption = option;
                    _sortListings();
                  });
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        option.icon,
                        size: 20,
                        color: _currentSortOption == option
                            ? CarSalesColors.primary
                            : CarSalesColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: _currentSortOption == option
                                ? CarSalesColors.primary
                                : CarSalesColors.textPrimary(isDark),
                            fontSize: 14,
                            fontWeight: _currentSortOption == option
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_currentSortOption == option)
                        const Icon(Icons.check, color: CarSalesColors.primary, size: 18),
                    ],
                  ),
                ),
              )),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilters(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aktif Filtreler ($_activeFilterCount)',
                style: TextStyle(
                  color: CarSalesColors.textSecondary(isDark),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _clearAllFilters,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Temizle',
                  style: TextStyle(
                    color: CarSalesColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._selectedBodyTypeIds.map((id) {
                final type = _bodyTypesData.firstWhere(
                  (t) => t.id == id,
                  orElse: () => CarBodyTypeData(id: id, name: id),
                );
                return _buildFilterChip(isDark, type.name, () {
                  setState(() {
                    _selectedBodyTypeIds.remove(id);
                    _applyFilter();
                  });
                });
              }),
              ..._selectedFuelTypeIds.map((id) {
                final type = _fuelTypesData.firstWhere(
                  (t) => t.id == id,
                  orElse: () => CarFuelTypeData(id: id, name: id),
                );
                return _buildFilterChip(isDark, type.name, () {
                  setState(() {
                    _selectedFuelTypeIds.remove(id);
                    _applyFilter();
                  });
                }, color: type.colorValue);
              }),
              ..._selectedTransmissionIds.map((id) {
                final type = _transmissionsData.firstWhere(
                  (t) => t.id == id,
                  orElse: () => CarTransmissionData(id: id, name: id),
                );
                return _buildFilterChip(isDark, type.name, () {
                  setState(() {
                    _selectedTransmissionIds.remove(id);
                    _applyFilter();
                  });
                });
              }),
              ..._selectedBrandIds.map((brandId) {
                final brand = CarBrand.allBrands.firstWhere(
                  (b) => b.id == brandId,
                  orElse: () => CarBrand.allBrands.first,
                );
                return _buildFilterChip(isDark, brand.name, () {
                  setState(() {
                    _selectedBrandIds.remove(brandId);
                    _applyFilter();
                  });
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(bool isDark, String label, VoidCallback onRemove, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? CarSalesColors.primary).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (color ?? CarSalesColors.primary).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? CarSalesColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: color ?? CarSalesColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconDataForBodyType(String? iconName) {
    const iconMap = {
      'directions_car': Icons.directions_car,
      'directions_car_filled': Icons.directions_car_filled,
      'sports_motorsports': Icons.sports_motorsports,
      'wb_sunny': Icons.wb_sunny,
      'local_shipping': Icons.local_shipping,
      'airport_shuttle': Icons.airport_shuttle,
      'family_restroom': Icons.family_restroom,
      'speed': Icons.speed,
      'diamond': Icons.diamond,
    };
    return iconMap[iconName] ?? Icons.directions_car;
  }

  IconData _getIconDataForFuelType(String? iconName) {
    const iconMap = {
      'local_gas_station': Icons.local_gas_station,
      'electric_bolt': Icons.electric_bolt,
      'eco': Icons.eco,
      'power': Icons.power,
      'propane_tank': Icons.propane_tank,
    };
    return iconMap[iconName] ?? Icons.local_gas_station;
  }

  IconData _getIconDataForTransmission(String? iconName) {
    const iconMap = {
      'settings': Icons.settings,
      'settings_applications': Icons.settings_applications,
      'tune': Icons.tune,
    };
    return iconMap[iconName] ?? Icons.settings;
  }

  Widget _buildPopularBrands(bool isDark) {
    final popularBrands = CarBrand.popularBrands.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Markalar',
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showBrandSearchSheet(isDark),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: CarSalesColors.surface(isDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.search,
                        size: 14,
                        color: CarSalesColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showBrandSearchSheet(isDark),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    color: CarSalesColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 68,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: popularBrands.length,
            itemBuilder: (context, index) {
              final brand = popularBrands[index];
              final isSelected = _selectedBrandIds.contains(brand.id);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedBrandIds.remove(brand.id);
                    } else {
                      _selectedBrandIds.add(brand.id);
                    }
                    _applyFilter();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 68,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CarSalesColors.primary.withValues(alpha: 0.1)
                        : CarSalesColors.card(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? CarSalesColors.primary
                          : CarSalesColors.border(isDark),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: CachedNetworkImage(
                              imageUrl: brand.logoUrl,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => Center(
                                child: Text(
                                  brand.name.substring(0, 1),
                                  style: const TextStyle(
                                    color: CarSalesColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: Text(
                                  brand.name.substring(0, 1),
                                  style: const TextStyle(
                                    color: CarSalesColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        brand.name.length > 9
                            ? '${brand.name.substring(0, 7)}..'
                            : brand.name,
                        style: TextStyle(
                          color: isSelected
                              ? CarSalesColors.primary
                              : CarSalesColors.textSecondary(isDark),
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBrandSearchSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BrandSearchSheet(
        isDark: isDark,
        selectedBrandIds: _selectedBrandIds,
        onBrandSelected: (brandId) {
          setState(() {
            if (_selectedBrandIds.contains(brandId)) {
              _selectedBrandIds.remove(brandId);
            } else {
              _selectedBrandIds.add(brandId);
            }
            _applyFilter();
          });
        },
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: CarSalesColors.textPrimary(isDark),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRecentListings(bool isDark) {
    final listings = _filteredListings.isNotEmpty
        ? _filteredListings.map((e) => _convertToCarListing(e)).toList()
        : _recentListings.map((e) => _convertToCarListing(e)).toList();

    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Filtre uygulandı ama sonuç yok
    if (_filteredListings.isEmpty && _activeFilterCount > 0) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Seçili filtrelere uygun ilan bulunamadı',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _clearAllFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CarSalesColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Filtreleri Temizle'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (listings.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.directions_car_outlined, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Henüz ilan bulunamadı',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isGridView) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final car = listings[index];
            return _buildGridCard(car, isDark);
          },
          childCount: listings.length,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final car = listings[index];
          return _buildListingCard(car, isDark);
        },
        childCount: listings.length,
      ),
    );
  }

  Widget _buildGridCard(CarListing car, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToDetail(car),
      child: Container(
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedNetworkImage(
                      imageUrl: car.images.first,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      memCacheHeight: 300,
                      placeholder: (_, __) => Container(
                        color: CarSalesColors.surface(isDark),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: CarSalesColors.surface(isDark),
                        child: Icon(
                          Icons.directions_car,
                          color: CarSalesColors.textTertiary(isDark),
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  if (car.isPremiumListing)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: CarSalesColors.goldGradient),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'VIP',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.fullName,
                      style: TextStyle(
                        color: CarSalesColors.textPrimary(isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${car.year} · ${_formatMileage(car.mileage)}',
                      style: TextStyle(
                        color: CarSalesColors.textSecondary(isDark),
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatPrice(car.price),
                      style: const TextStyle(
                        color: CarSalesColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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

  Widget _buildListingCard(CarListing car, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToDetail(car),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: CachedNetworkImage(
                imageUrl: car.images.first,
                width: 130,
                height: 120,
                fit: BoxFit.cover,
                memCacheWidth: 260,
                memCacheHeight: 240,
                placeholder: (_, __) => Container(
                  width: 130,
                  height: 120,
                  color: CarSalesColors.surface(isDark),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 130,
                  height: 120,
                  color: CarSalesColors.surface(isDark),
                  child: Icon(
                    Icons.directions_car,
                    color: CarSalesColors.textTertiary(isDark),
                    size: 36,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (car.isPremiumListing)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: CarSalesColors.goldGradient,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'P',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            car.fullName,
                            style: TextStyle(
                              color: CarSalesColors.textPrimary(isDark),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        _buildSpecChip(isDark, '${car.year}'),
                        _buildSpecChip(isDark, car.formattedMileage),
                        _buildSpecChip(isDark, car.fuelType.label),
                        _buildSpecChip(isDark, car.transmission.label),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.formattedPrice,
                              style: const TextStyle(
                                color: CarSalesColors.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (car.location.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 11,
                                    color: CarSalesColors.textTertiary(isDark),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    car.location,
                                    style: TextStyle(
                                      color: CarSalesColors.textTertiary(isDark),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: CarSalesColors.textTertiary(isDark),
                        ),
                      ],
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

  Widget _buildSpecChip(bool isDark, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: CarSalesColors.textSecondary(isDark),
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton(bool isDark) {
    return Positioned(
      right: 16,
      bottom: 90,
      child: GestureDetector(
        onTap: _navigateToAddListing,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: CarSalesColors.sportGradient,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: CarSalesColors.accent.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToSearch({String? brandId}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => CarSearchScreen(initialBrandId: brandId),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToDetail(CarListing car) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => CarDetailScreen(car: car),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToAddListing() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const AddCarListingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _navigateToMyListings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => const MyCarListingsScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdvancedFilterSheet(
        isDark: isDark,
        selectedBodyTypeIds: _selectedBodyTypeIds,
        selectedFuelTypeIds: _selectedFuelTypeIds,
        selectedTransmissionIds: _selectedTransmissionIds,
        selectedBrandIds: _selectedBrandIds,
        priceRange: _priceRange,
        yearRange: _yearRange,
        mileageRange: _mileageRange,
        bodyTypesData: _bodyTypesData,
        fuelTypesData: _fuelTypesData,
        transmissionsData: _transmissionsData,
        onApply: (bodyTypeIds, fuelTypeIds, transmissionIds, brandIds, priceRange, yearRange, mileageRange) {
          setState(() {
            _selectedBodyTypeIds.clear();
            _selectedBodyTypeIds.addAll(bodyTypeIds);
            _selectedFuelTypeIds.clear();
            _selectedFuelTypeIds.addAll(fuelTypeIds);
            _selectedTransmissionIds.clear();
            _selectedTransmissionIds.addAll(transmissionIds);
            _selectedBrandIds.clear();
            _selectedBrandIds.addAll(brandIds);
            _priceRange = priceRange;
            _yearRange = yearRange;
            _mileageRange = mileageRange;
            _applyFilter();
          });
        },
        onClear: _clearAllFilters,
      ),
    );
  }
}
