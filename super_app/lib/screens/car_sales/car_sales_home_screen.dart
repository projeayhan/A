import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../core/theme/app_responsive.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../services/car_sales_service.dart';
import '../../core/providers/banner_provider.dart';
import '../../widgets/common/generic_banner_carousel.dart';
import 'car_detail_screen.dart';
import 'add_car_listing_screen.dart';
import 'my_car_listings_screen.dart';
import 'car_search_screen.dart';

class CarSalesHomeScreen extends StatefulWidget {
  const CarSalesHomeScreen({super.key});

  @override
  State<CarSalesHomeScreen> createState() => _CarSalesHomeScreenState();
}

class _CarSalesHomeScreenState extends State<CarSalesHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _carShowcaseController;
  late AnimationController _pulseController;
  late Animation<double> _headerAnimation;
  // ignore: unused_field
  late Animation<double> _carRotation;
  late Animation<double> _pulseAnimation;

  final ScrollController _scrollController = ScrollController();
  int _currentShowcaseIndex = 0;

  // Supabase service
  final CarSalesService _carSalesService = CarSalesService.instance;

  // Gerçek veriler
  List<CarListingData> _featuredListings = [];
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

  // ValueNotifier kullanarak scroll offset'i izle - setState'den çok daha performanslı
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0);

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

    _carShowcaseController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutBack,
    );

    _carRotation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_carShowcaseController);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _headerController.forward();

    // ValueNotifier ile scroll offset güncelleme - setState çağırmaz, sadece dinleyen widget'lar güncellenir
    _scrollController.addListener(() {
      _scrollOffsetNotifier.value = _scrollController.offset;
    });

    // Gerçek verileri yükle
    _loadData();

    // Auto-scroll showcase
    Future.delayed(const Duration(seconds: 5), _autoScrollShowcase);
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
        _carSalesService.getFeaturedListings(limit: 10),
        _carSalesService.getActiveListings(limit: 50),
        _carSalesService.getBodyTypes(),
        _carSalesService.getFuelTypes(),
        _carSalesService.getTransmissions(),
      ]);

      if (mounted) {
        setState(() {
          _featuredListings = results[0] as List<CarListingData>;
          _recentListings = results[1] as List<CarListingData>;
          _filteredListings = results[1] as List<CarListingData>;
          _totalActiveListings = _recentListings.length;
          _bodyTypesData = results[2] as List<CarBodyTypeData>;
          _fuelTypesData = results[3] as List<CarFuelTypeData>;
          _transmissionsData = results[4] as List<CarTransmissionData>;
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
      // Gövde tipi filtresi (string ID karşılaştırması)
      if (_selectedBodyTypeIds.isNotEmpty &&
          !_selectedBodyTypeIds.contains(listing.bodyType)) {
        return false;
      }

      // Yakıt tipi filtresi (string ID karşılaştırması)
      if (_selectedFuelTypeIds.isNotEmpty &&
          !_selectedFuelTypeIds.contains(listing.fuelType)) {
        return false;
      }

      // Vites tipi filtresi (string ID karşılaştırması)
      if (_selectedTransmissionIds.isNotEmpty &&
          !_selectedTransmissionIds.contains(listing.transmission)) {
        return false;
      }

      // Marka filtresi
      if (_selectedBrandIds.isNotEmpty) {
        if (!_selectedBrandIds.contains(listing.brandId)) {
          return false;
        }
      }

      // Fiyat aralığı filtresi
      if (listing.price < _priceRange.start || listing.price > _priceRange.end) {
        return false;
      }

      // Yıl aralığı filtresi
      if (listing.year < _yearRange.start || listing.year > _yearRange.end) {
        return false;
      }

      // Kilometre aralığı filtresi
      if (listing.mileage < _mileageRange.start || listing.mileage > _mileageRange.end) {
        return false;
      }

      return true;
    }).toList();

    // Sıralama uygula
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

  void _autoScrollShowcase() {
    if (!mounted) return;
    // Sadece gerçek verileri kullan
    final featuredCars = _featuredListings.isNotEmpty
        ? _featuredListings
        : _recentListings;
    if (featuredCars.isEmpty) return;
    setState(() {
      _currentShowcaseIndex = (_currentShowcaseIndex + 1) % featuredCars.length;
    });
    Future.delayed(const Duration(seconds: 5), _autoScrollShowcase);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _carShowcaseController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
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
            // Background gradient animation
            _buildAnimatedBackground(isDark, size),

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
                // Animated App Bar
                _buildSliverAppBar(isDark, size),

                // Premium Car Showcase
                SliverToBoxAdapter(
                  child: _buildPremiumShowcase(isDark, size),
                ),

                // Banner Carousel - Quick Actions'dan önce
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Consumer(
                      builder: (context, ref, _) {
                        return GenericBannerCarousel(
                          bannerProvider: carSalesBannersProvider,
                          height: 160,
                          primaryColor: Colors.red,
                          defaultTitle: 'Araç Fırsatları',
                          defaultSubtitle: 'Hayalinizdeki araca ulaşın!',
                        );
                      },
                    ),
                  ),
                ),

                // Quick Actions
                SliverToBoxAdapter(
                  child: _buildQuickActions(isDark),
                ),

                // Category Filter
                SliverToBoxAdapter(
                  child: _buildCategoryFilter(isDark),
                ),

                // Popular Brands
                SliverToBoxAdapter(
                  child: _buildPopularBrands(isDark),
                ),

                // Featured Listings
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    isDark,
                    'Öne Çıkan İlanlar',
                    'Tümünü Gör',
                    () {},
                  ),
                ),

                SliverToBoxAdapter(
                  child: _buildFeaturedListings(isDark),
                ),

                // Recent Listings
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    isDark,
                    'Son Eklenen İlanlar',
                    'Tümünü Gör',
                    () {},
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildAnimatedBackground(bool isDark, Size size) {
    return Positioned.fill(
      // ValueListenableBuilder sadece scrollOffset değiştiğinde bu widget'ı rebuild eder
      // Tüm ekran yerine sadece background yeniden çizilir
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollOffsetNotifier,
        builder: (context, scrollOffset, child) {
          return AnimatedBuilder(
            animation: _carShowcaseController,
            builder: (context, child) {
              return CustomPaint(
                painter: _BackgroundPainter(
                  isDark: isDark,
                  animationValue: _carShowcaseController.value,
                  scrollOffset: scrollOffset,
                ),
              );
            },
          );
        },
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      // Logo & Title
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Araç Satış',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '$_totalActiveListings aktif ilan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Refresh Button
                      _buildIconButton(
                        Icons.refresh,
                        () => _loadData(forceRefresh: true),
                      ),
                      const SizedBox(width: 8),
                      // Search Button
                      _buildIconButton(
                        Icons.search,
                        () => _navigateToSearch(),
                      ),
                      const SizedBox(width: 8),
                      // Filter Button
                      _buildIconButton(
                        Icons.tune,
                        () => _showFilterSheet(),
                      ),
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

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildPremiumShowcase(bool isDark, Size size) {
    // Sadece gerçek verileri kullan - demo veri kullanma
    if (_recentListings.isEmpty) return const SizedBox.shrink();

    // En son eklenen 5 ilanı göster
    final featuredCars = _recentListings.take(5).map((e) => _convertToCarListing(e)).toList();
    if (featuredCars.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 320,
      margin: const EdgeInsets.only(top: 16),
      child: Stack(
        children: [
          // Car Cards PageView
          PageView.builder(
            itemCount: featuredCars.length,
            onPageChanged: (index) {
              setState(() => _currentShowcaseIndex = index);
            },
            itemBuilder: (context, index) {
              final car = featuredCars[index];
              return _buildShowcaseCard(car, isDark, index);
            },
          ),

          // Page Indicators
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(featuredCars.length, (index) {
                final isActive = index == _currentShowcaseIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? CarSalesColors.primary
                        : CarSalesColors.textTertiary(isDark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseCard(CarListing car, bool isDark, int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = index == _currentShowcaseIndex
            ? _pulseAnimation.value
            : 1.0;

        return Transform.scale(
          scale: scale * 0.92,
          child: GestureDetector(
            onTap: () => _navigateToDetail(car),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: car.brand.isPremium
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [CarSalesColors.primary, CarSalesColors.primaryDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (car.brand.isPremium
                        ? const Color(0xFF1E293B)
                        : CarSalesColors.primary).withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background Pattern
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CustomPaint(
                        painter: _CardPatternPainter(),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Premium Badge
                            if (car.isPremiumListing)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: CarSalesColors.goldGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'PREMIUM',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Like Button
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite_border,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 20,
                              ),
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Car Image
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Hero(
                              tag: 'car_${car.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  car.images.first,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    child: const Icon(
                                      Icons.directions_car,
                                      color: Colors.white54,
                                      size: 80,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Car Info
                        Text(
                          car.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildCarInfoChip(
                              Icons.calendar_today,
                              car.year.toString(),
                            ),
                            const SizedBox(width: 12),
                            _buildCarInfoChip(
                              Icons.speed,
                              car.formattedMileage,
                            ),
                            const SizedBox(width: 12),
                            _buildCarInfoChip(
                              car.fuelType.icon,
                              car.fuelType.label,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              car.fullFormattedPrice,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'İncele',
                                style: TextStyle(
                                  color: CarSalesColors.primary,
                                  fontWeight: FontWeight.bold,
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
          ),
        );
      },
    );
  }

  Widget _buildCarInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.add_circle_outline,
              'İlan Ver',
              'Aracını sat',
              CarSalesColors.sportGradient,
              () => _navigateToAddListing(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.list_alt,
              'İlanlarım',
              'Yönet',
              CarSalesColors.primaryGradient,
              () => _navigateToMyListings(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              isDark,
              Icons.favorite_outline,
              'Favoriler',
              'Kaydedilenler',
              CarSalesColors.goldGradient,
              () {},
            ),
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
        padding: const EdgeInsets.all(16),
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
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sıralama ve Görünüm Bar'ı
        _buildSortAndViewBar(isDark),

        // Kompakt Filtre Bar'ı
        _buildCompactFilterBar(isDark),

        // Aktif Filtreler
        if (_activeFilterCount > 0) _buildActiveFilters(isDark),
      ],
    );
  }

  /// Kompakt filtre bar'ı - dropdown tarzı butonlar
  Widget _buildCompactFilterBar(bool isDark) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Gövde Tipi
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Gövde',
            icon: Icons.directions_car_outlined,
            selectedCount: _selectedBodyTypeIds.length,
            onTap: () => _showBodyTypeSheet(isDark),
          ),
          const SizedBox(width: 8),
          // Yakıt Tipi
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Yakıt',
            icon: Icons.local_gas_station_outlined,
            selectedCount: _selectedFuelTypeIds.length,
            onTap: () => _showFuelTypeSheet(isDark),
          ),
          const SizedBox(width: 8),
          // Vites Tipi
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Vites',
            icon: Icons.settings_outlined,
            selectedCount: _selectedTransmissionIds.length,
            onTap: () => _showTransmissionSheet(isDark),
          ),
          const SizedBox(width: 8),
          // Fiyat Aralığı
          _buildFilterDropdownButton(
            isDark: isDark,
            label: 'Fiyat',
            icon: Icons.attach_money,
            selectedCount: (_priceRange.start > 0 || _priceRange.end < 50000000) ? 1 : 0,
            onTap: () => _showFilterSheet(),
          ),
          const SizedBox(width: 8),
          // Tüm Filtreler
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

  /// Filtre dropdown butonu
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

  /// Gövde tipi seçim sheet'i
  void _showBodyTypeSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSelectionSheet<CarBodyTypeData>(
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

  /// Yakıt tipi seçim sheet'i
  void _showFuelTypeSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSelectionSheet<CarFuelTypeData>(
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

  /// Vites tipi seçim sheet'i
  void _showTransmissionSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSelectionSheet<CarTransmissionData>(
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

  /// Sıralama ve Görünüm Bar'ı
  Widget _buildSortAndViewBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Row(
        children: [
          // Sonuç sayısı
          Expanded(
            child: Text(
              '${_filteredListings.length} araç bulundu',
              style: TextStyle(
                color: CarSalesColors.textSecondary(isDark),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Sıralama dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    size: 16,
                    color: CarSalesColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currentSortOption.label.split(' ').first,
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: CarSalesColors.textSecondary(isDark),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Görünüm toggle
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? CarSalesColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : CarSalesColors.textSecondary(isDark),
        ),
      ),
    );
  }

  /// Sıralama seçenekleri
  void _showSortOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: CarSalesColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sırala',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(isDark),
                    fontSize: 18,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        option.icon,
                        size: 22,
                        color: _currentSortOption == option
                            ? CarSalesColors.primary
                            : CarSalesColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: _currentSortOption == option
                                ? CarSalesColors.primary
                                : CarSalesColors.textPrimary(isDark),
                            fontSize: 15,
                            fontWeight: _currentSortOption == option
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_currentSortOption == option)
                        const Icon(Icons.check, color: CarSalesColors.primary, size: 20),
                    ],
                  ),
                ),
              )),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Aktif filtreler
  Widget _buildActiveFilters(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _clearAllFilters,
                child: const Text(
                  'Temizle',
                  style: TextStyle(
                    color: CarSalesColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Gövde tipi chip'leri
              ..._selectedBodyTypeIds.map((id) {
                final type = _bodyTypesData.firstWhere(
                  (t) => t.id == id,
                  orElse: () => CarBodyTypeData(id: id, name: id),
                );
                return _buildFilterChip(
                  isDark,
                  type.name,
                  () {
                    setState(() {
                      _selectedBodyTypeIds.remove(id);
                      _applyFilter();
                    });
                  },
                );
              }),
              // Yakıt tipi chip'leri
              ..._selectedFuelTypeIds.map((id) {
                final type = _fuelTypesData.firstWhere(
                  (t) => t.id == id,
                  orElse: () => CarFuelTypeData(id: id, name: id),
                );
                return _buildFilterChip(
                  isDark,
                  type.name,
                  () {
                    setState(() {
                      _selectedFuelTypeIds.remove(id);
                      _applyFilter();
                    });
                  },
                  color: type.colorValue,
                );
              }),
              // Vites tipi chip'leri
              ..._selectedTransmissionIds.map((id) {
                final type = _transmissionsData.firstWhere(
                  (t) => t.id == id,
                  orElse: () => CarTransmissionData(id: id, name: id),
                );
                return _buildFilterChip(
                  isDark,
                  type.name,
                  () {
                    setState(() {
                      _selectedTransmissionIds.remove(id);
                      _applyFilter();
                    });
                  },
                );
              }),
              // Marka chip'leri
              ..._selectedBrandIds.map((brandId) {
                final brand = CarBrand.allBrands.firstWhere(
                  (b) => b.id == brandId,
                  orElse: () => CarBrand.allBrands.first,
                );
                return _buildFilterChip(
                  isDark,
                  brand.name,
                  () {
                    setState(() {
                      _selectedBrandIds.remove(brandId);
                      _applyFilter();
                    });
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(bool isDark, String label, VoidCallback onRemove, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? CarSalesColors.primary).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: color ?? CarSalesColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Genel filtre section builder
  Widget _buildFilterSection<T>(
    bool isDark,
    String title,
    List<T> items,
    Set<T> selectedItems,
    String Function(T) getLabel,
    IconData Function(T) getIcon,
    void Function(T) onTap, {
    bool showColor = false,
    Color Function(T)? getColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            title,
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selectedItems.contains(item);
              final itemColor = showColor && getColor != null ? getColor(item) : CarSalesColors.primary;

              return GestureDetector(
                onTap: () => onTap(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? itemColor.withValues(alpha: 0.15)
                        : CarSalesColors.card(isDark),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? itemColor : CarSalesColors.border(isDark),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        getIcon(item),
                        size: 16,
                        color: isSelected ? itemColor : CarSalesColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        getLabel(item),
                        style: TextStyle(
                          color: isSelected ? itemColor : CarSalesColors.textSecondary(isDark),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
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

  /// Icon helper for body types
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

  /// Icon helper for fuel types
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

  /// Icon helper for transmissions
  IconData _getIconDataForTransmission(String? iconName) {
    const iconMap = {
      'settings': Icons.settings,
      'settings_applications': Icons.settings_applications,
      'tune': Icons.tune,
    };
    return iconMap[iconName] ?? Icons.settings;
  }

  /// Data-based filter section builder (for Supabase data)
  Widget _buildFilterSectionData<T>(
    bool isDark,
    String title,
    List<T> items,
    Set<String> selectedIds,
    String Function(T) getLabel,
    IconData Function(T) getIcon,
    void Function(T) onTap, {
    bool showColor = false,
    Color Function(T)? getColor,
    String Function(T)? getId,
  }) {
    // getId fonksiyonu: CarBodyTypeData, CarFuelTypeData, CarTransmissionData için id döndür
    String getItemId(T item) {
      if (item is CarBodyTypeData) return item.id;
      if (item is CarFuelTypeData) return item.id;
      if (item is CarTransmissionData) return item.id;
      return getId?.call(item) ?? item.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            title,
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'Yükleniyor...',
                    style: TextStyle(color: CarSalesColors.textTertiary(isDark)),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemId = getItemId(item);
                    final isSelected = selectedIds.contains(itemId);
                    final itemColor = showColor && getColor != null ? getColor(item) : CarSalesColors.primary;

                    return GestureDetector(
                      onTap: () => onTap(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? itemColor.withValues(alpha: 0.15)
                              : CarSalesColors.card(isDark),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected ? itemColor : CarSalesColors.border(isDark),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getIcon(item),
                              size: 16,
                              color: isSelected ? itemColor : CarSalesColors.textSecondary(isDark),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              getLabel(item),
                              style: TextStyle(
                                color: isSelected ? itemColor : CarSalesColors.textSecondary(isDark),
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
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

  Widget _buildPopularBrands(bool isDark) {
    final popularBrands = CarBrand.popularBrands.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Markalar',
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Arama ikonu
                  GestureDetector(
                    onTap: () => _showBrandSearchSheet(isDark),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: CarSalesColors.surface(isDark),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.search,
                        size: 16,
                        color: CarSalesColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showAllBrandsSheet(isDark),
                child: const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    color: CarSalesColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? CarSalesColors.primary.withValues(alpha: 0.1)
                        : CarSalesColors.card(isDark),
                    borderRadius: BorderRadius.circular(12),
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
                      // Marka logosu
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.network(
                              brand.logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  brand.name.substring(0, 1),
                                  style: const TextStyle(
                                    color: CarSalesColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        brand.name.length > 9
                            ? '${brand.name.substring(0, 7)}..'
                            : brand.name,
                        style: TextStyle(
                          color: isSelected
                              ? CarSalesColors.primary
                              : CarSalesColors.textSecondary(isDark),
                          fontSize: 10,
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

  /// Marka arama sheet'i
  void _showBrandSearchSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BrandSearchSheet(
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

  /// Tüm markalar sheet'i
  void _showAllBrandsSheet(bool isDark) {
    _showBrandSearchSheet(isDark);
  }

  Widget _buildSectionHeader(
    bool isDark,
    String title,
    String actionText,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Row(
              children: [
                Text(
                  actionText,
                  style: const TextStyle(
                    color: CarSalesColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: CarSalesColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedListings(bool isDark) {
    if (_isLoading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Sadece gerçek verileri kullan - demo veri kullanma
    // Featured listesi boşsa recent listesinden al
    final sourceListings = _featuredListings.isNotEmpty
        ? _featuredListings
        : _recentListings;

    if (sourceListings.isEmpty) {
      return const SizedBox.shrink();
    }

    final featuredListings = sourceListings.map((e) => _convertToCarListing(e)).toList();

    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: featuredListings.length,
        itemBuilder: (context, index) {
          final car = featuredListings[index];
          return _buildFeaturedListingCard(car, isDark);
        },
      ),
    );
  }

  Widget _buildFeaturedListingCard(CarListing car, bool isDark) {
    return GestureDetector(
      onTap: () => _navigateToDetail(car),
      child: Container(
        width: 220,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    car.images.first,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: CarSalesColors.surface(isDark),
                      child: Icon(
                        Icons.directions_car,
                        color: CarSalesColors.textTertiary(isDark),
                        size: 48,
                      ),
                    ),
                  ),
                ),
                // Premium badge
                if (car.isPremiumListing)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: CarSalesColors.goldGradient,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Favorite button
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: CarSalesColors.accent,
                      size: 18,
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
                    car.fullName,
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: CarSalesColors.textTertiary(isDark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${car.year}',
                        style: TextStyle(
                          color: CarSalesColors.textSecondary(isDark),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.speed,
                        size: 12,
                        color: CarSalesColors.textTertiary(isDark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        car.formattedMileage,
                        style: TextStyle(
                          color: CarSalesColors.textSecondary(isDark),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        car.formattedPrice,
                        style: const TextStyle(
                          color: CarSalesColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (car.isPriceNegotiable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CarSalesColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Pazarlık',
                            style: TextStyle(
                              color: CarSalesColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
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

  Widget _buildRecentListings(bool isDark) {
    // Sadece gerçek verileri kullan - demo veri kullanma
    final listings = _filteredListings.isNotEmpty
        ? _filteredListings.map((e) => _convertToCarListing(e)).toList()
        : _recentListings.map((e) => _convertToCarListing(e)).toList();

    if (_isLoading) {
      return SliverToBoxAdapter(
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
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Seçili filtrelere uygun ilan bulunamadı',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _clearAllFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CarSalesColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Henüz ilan bulunamadı',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Grid veya List görünümüne göre
    if (_isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final car = listings[index];
              return _buildGridCard(car, isDark);
            },
            childCount: listings.length,
          ),
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      car.images.first,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: CarSalesColors.surface(isDark),
                        child: Icon(
                          Icons.directions_car,
                          color: CarSalesColors.textTertiary(isDark),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  if (car.isPremiumListing)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.fullName,
                      style: TextStyle(
                        color: CarSalesColors.textPrimary(isDark),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${car.year} · ${_formatMileage(car.mileage)}',
                      style: TextStyle(
                        color: CarSalesColors.textSecondary(isDark),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatPrice(car.price),
                      style: const TextStyle(
                        color: CarSalesColors.primary,
                        fontSize: 14,
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              child: Image.network(
                car.images.first,
                width: 140,
                height: 130,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 140,
                  height: 130,
                  color: CarSalesColors.surface(isDark),
                  child: Icon(
                    Icons.directions_car,
                    color: CarSalesColors.textTertiary(isDark),
                    size: 40,
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (car.isPremiumListing)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Specs row
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildSpecChip(isDark, '${car.year}'),
                        _buildSpecChip(isDark, car.formattedMileage),
                        _buildSpecChip(isDark, car.fuelType.label),
                        _buildSpecChip(isDark, car.transmission.label),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Price and location
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (car.location.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: CarSalesColors.textTertiary(isDark),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    car.location,
                                    style: TextStyle(
                                      color: CarSalesColors.textTertiary(isDark),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: CarSalesColors.textSecondary(isDark),
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton(bool isDark) {
    return Positioned(
      right: 20,
      bottom: 100,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: GestureDetector(
              onTap: _navigateToAddListing,
              child: Container(
                width: 64,
                height: 64,
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
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          );
        },
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
      builder: (context) => _AdvancedFilterSheet(
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

// Custom painters
class _BackgroundPainter extends CustomPainter {
  final bool isDark;
  final double animationValue;
  final double scrollOffset;

  _BackgroundPainter({
    required this.isDark,
    required this.animationValue,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Animated circles in background
    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i * 0.33) % 1.0;
      final x = size.width * (0.1 + 0.8 * math.sin(progress * math.pi * 2 + i));
      final y = (size.height * 0.2 - scrollOffset * 0.1).clamp(0, size.height * 0.5);
      final radius = 100.0 + 50 * math.sin(progress * math.pi * 2);

      paint.color = (isDark
          ? CarSalesColors.primary
          : CarSalesColors.primaryLight).withValues(alpha: 0.05);

      canvas.drawCircle(Offset(x, y + i * 100), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        scrollOffset != oldDelegate.scrollOffset;
  }
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Marka arama ve seçme sheet'i
class _BrandSearchSheet extends StatefulWidget {
  final bool isDark;
  final Set<String> selectedBrandIds;
  final void Function(String) onBrandSelected;

  const _BrandSearchSheet({
    required this.isDark,
    required this.selectedBrandIds,
    required this.onBrandSelected,
  });

  @override
  State<_BrandSearchSheet> createState() => _BrandSearchSheetState();
}

class _BrandSearchSheetState extends State<_BrandSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCountry = 'Tümü';

  final List<String> _countries = ['Tümü', 'Almanya', 'Japonya', 'ABD', 'G. Kore', 'Fransa', 'İtalya', 'İngiltere'];

  List<CarBrand> get _filteredBrands {
    var brands = CarBrand.allBrands;

    // Ülke filtresi
    if (_selectedCountry != 'Tümü') {
      brands = brands.where((b) => b.country == _selectedCountry).toList();
    }

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      brands = brands
          .where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return brands;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: CarSalesColors.card(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: CarSalesColors.border(widget.isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Marka Seç',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(widget.isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.selectedBrandIds.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '${widget.selectedBrandIds.length} Seçili',
                      style: const TextStyle(
                        color: CarSalesColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Arama
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Marka ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: CarSalesColors.surface(widget.isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // Ülke filtreleri
          Container(
            height: 44,
            margin: const EdgeInsets.only(top: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _countries.length,
              itemBuilder: (context, index) {
                final country = _countries[index];
                final isSelected = _selectedCountry == country;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCountry = country),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CarSalesColors.primary
                          : CarSalesColors.surface(widget.isDark),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      country,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : CarSalesColors.textSecondary(widget.isDark),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Marka listesi
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredBrands.length,
              itemBuilder: (context, index) {
                final brand = _filteredBrands[index];
                final isSelected = widget.selectedBrandIds.contains(brand.id);

                return GestureDetector(
                  onTap: () {
                    widget.onBrandSelected(brand.id);
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CarSalesColors.primary.withValues(alpha: 0.1)
                          : CarSalesColors.surface(widget.isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? CarSalesColors.primary
                            : CarSalesColors.border(widget.isDark),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              brand.logoUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  brand.name.substring(0, 1),
                                  style: const TextStyle(
                                    color: CarSalesColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          brand.name.length > 8
                              ? '${brand.name.substring(0, 7)}..'
                              : brand.name,
                          style: TextStyle(
                            color: isSelected
                                ? CarSalesColors.primary
                                : CarSalesColors.textPrimary(widget.isDark),
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: CarSalesColors.primary,
                            size: 14,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Alt buton
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CarSalesColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.selectedBrandIds.isEmpty
                        ? 'Kapat'
                        : '${widget.selectedBrandIds.length} Marka Seçildi - Uygula',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gelişmiş filtre sheet'i
class _AdvancedFilterSheet extends StatefulWidget {
  final bool isDark;
  final Set<String> selectedBodyTypeIds;
  final Set<String> selectedFuelTypeIds;
  final Set<String> selectedTransmissionIds;
  final Set<String> selectedBrandIds;
  final RangeValues priceRange;
  final RangeValues yearRange;
  final RangeValues mileageRange;
  final List<CarBodyTypeData> bodyTypesData;
  final List<CarFuelTypeData> fuelTypesData;
  final List<CarTransmissionData> transmissionsData;
  final void Function(
    Set<String>,
    Set<String>,
    Set<String>,
    Set<String>,
    RangeValues,
    RangeValues,
    RangeValues,
  ) onApply;
  final VoidCallback onClear;

  const _AdvancedFilterSheet({
    required this.isDark,
    required this.selectedBodyTypeIds,
    required this.selectedFuelTypeIds,
    required this.selectedTransmissionIds,
    required this.selectedBrandIds,
    required this.priceRange,
    required this.yearRange,
    required this.mileageRange,
    required this.bodyTypesData,
    required this.fuelTypesData,
    required this.transmissionsData,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late Set<String> _bodyTypeIds;
  late Set<String> _fuelTypeIds;
  late Set<String> _transmissionIds;
  late Set<String> _brandIds;
  late RangeValues _priceRange;
  late RangeValues _yearRange;
  late RangeValues _mileageRange;

  @override
  void initState() {
    super.initState();
    _bodyTypeIds = Set.from(widget.selectedBodyTypeIds);
    _fuelTypeIds = Set.from(widget.selectedFuelTypeIds);
    _transmissionIds = Set.from(widget.selectedTransmissionIds);
    _brandIds = Set.from(widget.selectedBrandIds);
    _priceRange = widget.priceRange;
    _yearRange = widget.yearRange;
    _mileageRange = widget.mileageRange;
  }

  String _formatPrice(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatMileage(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_bodyTypeIds.isNotEmpty) count++;
    if (_fuelTypeIds.isNotEmpty) count++;
    if (_transmissionIds.isNotEmpty) count++;
    if (_brandIds.isNotEmpty) count++;
    if (_priceRange.start > 0 || _priceRange.end < 50000000) count++;
    if (_yearRange.start > 2010 || _yearRange.end < DateTime.now().year) count++;
    if (_mileageRange.start > 0 || _mileageRange.end < 500000) count++;
    return count;
  }

  void _clearAll() {
    setState(() {
      _bodyTypeIds.clear();
      _fuelTypeIds.clear();
      _transmissionIds.clear();
      _brandIds.clear();
      _priceRange = const RangeValues(0, 50000000);
      _yearRange = RangeValues(2010, DateTime.now().year.toDouble());
      _mileageRange = const RangeValues(0, 500000);
    });
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: CarSalesColors.card(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: CarSalesColors.border(widget.isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: CarSalesColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Gelişmiş Filtreler',
                      style: TextStyle(
                        color: CarSalesColors.textPrimary(widget.isDark),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_activeFilterCount > 0)
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text(
                      'Temizle',
                      style: TextStyle(
                        color: CarSalesColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Filtreler
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fiyat Aralığı
                  _buildSectionTitle('Fiyat Aralığı'),
                  _buildRangeSlider(
                    value: _priceRange,
                    min: 0,
                    max: 50000000,
                    divisions: 100,
                    onChanged: (value) => setState(() => _priceRange = value),
                    formatLabel: _formatPrice,
                    suffix: ' TL',
                  ),

                  const SizedBox(height: 24),

                  // Yıl Aralığı
                  _buildSectionTitle('Model Yılı'),
                  _buildRangeSlider(
                    value: _yearRange,
                    min: 2000,
                    max: DateTime.now().year.toDouble(),
                    divisions: DateTime.now().year - 2000,
                    onChanged: (value) => setState(() => _yearRange = value),
                    formatLabel: (v) => v.toInt().toString(),
                    suffix: '',
                  ),

                  const SizedBox(height: 24),

                  // Kilometre Aralığı
                  _buildSectionTitle('Kilometre'),
                  _buildRangeSlider(
                    value: _mileageRange,
                    min: 0,
                    max: 500000,
                    divisions: 100,
                    onChanged: (value) => setState(() => _mileageRange = value),
                    formatLabel: _formatMileage,
                    suffix: ' km',
                  ),

                  const SizedBox(height: 24),

                  // Gövde Tipi
                  _buildSectionTitle('Gövde Tipi'),
                  _buildChipGroupData<CarBodyTypeData>(
                    items: widget.bodyTypesData,
                    selectedIds: _bodyTypeIds,
                    getLabel: (t) => t.name,
                    getIcon: (t) => _getIconDataForBodyType(t.icon),
                    getId: (t) => t.id,
                    onTap: (t) => setState(() {
                      if (_bodyTypeIds.contains(t.id)) {
                        _bodyTypeIds.remove(t.id);
                      } else {
                        _bodyTypeIds.add(t.id);
                      }
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Yakıt Tipi
                  _buildSectionTitle('Yakıt Tipi'),
                  _buildChipGroupData<CarFuelTypeData>(
                    items: widget.fuelTypesData,
                    selectedIds: _fuelTypeIds,
                    getLabel: (t) => t.name,
                    getIcon: (t) => _getIconDataForFuelType(t.icon),
                    getId: (t) => t.id,
                    onTap: (t) => setState(() {
                      if (_fuelTypeIds.contains(t.id)) {
                        _fuelTypeIds.remove(t.id);
                      } else {
                        _fuelTypeIds.add(t.id);
                      }
                    }),
                    getColor: (t) => t.colorValue,
                  ),

                  const SizedBox(height: 24),

                  // Vites Tipi
                  _buildSectionTitle('Vites Tipi'),
                  _buildChipGroupData<CarTransmissionData>(
                    items: widget.transmissionsData,
                    selectedIds: _transmissionIds,
                    getLabel: (t) => t.name,
                    getIcon: (t) => _getIconDataForTransmission(t.icon),
                    getId: (t) => t.id,
                    onTap: (t) => setState(() {
                      if (_transmissionIds.contains(t.id)) {
                        _transmissionIds.remove(t.id);
                      } else {
                        _transmissionIds.add(t.id);
                      }
                    }),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Alt butonlar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CarSalesColors.card(widget.isDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // İptal butonu
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CarSalesColors.textPrimary(widget.isDark),
                        side: BorderSide(color: CarSalesColors.border(widget.isDark)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'İptal',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Uygula butonu
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(
                          _bodyTypeIds,
                          _fuelTypeIds,
                          _transmissionIds,
                          _brandIds,
                          _priceRange,
                          _yearRange,
                          _mileageRange,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CarSalesColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _activeFilterCount > 0
                                ? 'Uygula ($_activeFilterCount)'
                                : 'Uygula',
                            style: const TextStyle(
                              fontSize: 16,
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
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: CarSalesColors.textPrimary(widget.isDark),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRangeSlider({
    required RangeValues value,
    required double min,
    required double max,
    required int divisions,
    required void Function(RangeValues) onChanged,
    required String Function(double) formatLabel,
    required String suffix,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CarSalesColors.surface(widget.isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${formatLabel(value.start)}$suffix',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(widget.isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '-',
              style: TextStyle(
                color: CarSalesColors.textSecondary(widget.isDark),
                fontSize: 18,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CarSalesColors.surface(widget.isDark),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${formatLabel(value.end)}$suffix',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(widget.isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: CarSalesColors.primary,
            inactiveTrackColor: CarSalesColors.border(widget.isDark),
            thumbColor: CarSalesColors.primary,
            overlayColor: CarSalesColors.primary.withValues(alpha: 0.2),
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          ),
          child: RangeSlider(
            values: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildChipGroupData<T>({
    required List<T> items,
    required Set<String> selectedIds,
    required String Function(T) getLabel,
    required IconData Function(T) getIcon,
    required String Function(T) getId,
    required void Function(T) onTap,
    Color Function(T)? getColor,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Yükleniyor...',
          style: TextStyle(color: CarSalesColors.textTertiary(widget.isDark)),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final itemId = getId(item);
        final isSelected = selectedIds.contains(itemId);
        final color = getColor?.call(item) ?? CarSalesColors.primary;

        return GestureDetector(
          onTap: () => onTap(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : CarSalesColors.surface(widget.isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : CarSalesColors.border(widget.isDark),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getIcon(item),
                  size: 18,
                  color: isSelected ? color : CarSalesColors.textSecondary(widget.isDark),
                ),
                const SizedBox(width: 8),
                Text(
                  getLabel(item),
                  style: TextStyle(
                    color: isSelected ? color : CarSalesColors.textSecondary(widget.isDark),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check, size: 16, color: color),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Filtre seçim sheet'i - kompakt multi-select
class _FilterSelectionSheet<T> extends StatefulWidget {
  final bool isDark;
  final String title;
  final List<T> items;
  final Set<String> selectedIds;
  final String Function(T) getLabel;
  final IconData Function(T) getIcon;
  final String Function(T) getId;
  final Color Function(T)? getColor;
  final void Function(Set<String>) onChanged;

  const _FilterSelectionSheet({
    required this.isDark,
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.getLabel,
    required this.getIcon,
    required this.getId,
    this.getColor,
    required this.onChanged,
  });

  @override
  State<_FilterSelectionSheet<T>> createState() => _FilterSelectionSheetState<T>();
}

class _FilterSelectionSheetState<T> extends State<_FilterSelectionSheet<T>> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CarSalesColors.card(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: CarSalesColors.border(widget.isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(widget.isDark),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _selected.clear());
                        },
                        child: const Text(
                          'Temizle',
                          style: TextStyle(color: CarSalesColors.accent),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        widget.onChanged(_selected);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CarSalesColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text('Uygula${_selected.isNotEmpty ? ' (${_selected.length})' : ''}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Items
          Flexible(
            child: widget.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final id = widget.getId(item);
                      final isSelected = _selected.contains(id);
                      final color = widget.getColor?.call(item) ?? CarSalesColors.primary;

                      return ListTile(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(id);
                            } else {
                              _selected.add(id);
                            }
                          });
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : CarSalesColors.surface(widget.isDark),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? color : CarSalesColors.border(widget.isDark),
                            ),
                          ),
                          child: Icon(
                            widget.getIcon(item),
                            size: 20,
                            color: isSelected ? color : CarSalesColors.textSecondary(widget.isDark),
                          ),
                        ),
                        title: Text(
                          widget.getLabel(item),
                          style: TextStyle(
                            color: CarSalesColors.textPrimary(widget.isDark),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: color)
                            : Icon(
                                Icons.circle_outlined,
                                color: CarSalesColors.border(widget.isDark),
                              ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

