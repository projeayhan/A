import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_dialogs.dart';
import '../../models/rental/rental_models.dart';
import '../../core/services/rental_service.dart';
import '../../services/location_service.dart';
import 'car_detail_screen.dart';
import 'my_bookings_screen.dart';

class RentalHomeScreen extends StatefulWidget {
  const RentalHomeScreen({super.key});

  @override
  State<RentalHomeScreen> createState() => _RentalHomeScreenState();
}

class _RentalHomeScreenState extends State<RentalHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _carouselController;
  late Animation<double> _heroAnimation;
  late Animation<double> _fadeAnimation;

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  int _selectedCategoryIndex = 0;
  CarCategory? _selectedCategory;
  RentalLocation? _selectedPickupLocation;
  RentalLocation? _selectedDropoffLocation;
  late DateTime _pickupDate;
  late DateTime _dropoffDate;

  // Ozel adres icin degiskenler
  bool _isPickupCustomAddress = false;
  bool _isDropoffCustomAddress = false;
  String _pickupCustomAddress = '';
  String _dropoffCustomAddress = '';
  String _pickupCustomAddressNote = '';
  String _dropoffCustomAddressNote = '';

  List<RentalCar> _cars = [];
  List<RentalLocation> _locations = [];
  // Hero banner carousel icin
  List<Map<String, dynamic>> _heroBanners = [];
  int _currentBannerIndex = 0;
  Timer? _bannerAutoScrollTimer;
  final PageController _bannerPageController = PageController();

  final List<Map<String, dynamic>> _categories = [
    {'category': null, 'name': 'Tumu', 'icon': Icons.apps},
    {'category': CarCategory.luxury, 'name': 'Luks', 'icon': Icons.diamond},
    {'category': CarCategory.sports, 'name': 'Spor', 'icon': Icons.speed},
    {'category': CarCategory.suv, 'name': 'SUV', 'icon': Icons.terrain},
    {
      'category': CarCategory.electric,
      'name': 'Elektrikli',
      'icon': Icons.bolt,
    },
    {
      'category': CarCategory.sedan,
      'name': 'Sedan',
      'icon': Icons.directions_car,
    },
    {
      'category': CarCategory.compact,
      'name': 'Kompakt',
      'icon': Icons.local_taxi,
    },
  ];

  List<RentalCar> get _filteredCars {
    if (_selectedCategory == null) return _cars;
    return _cars.where((car) => car.category == _selectedCategory).toList();
  }

  @override
  void initState() {
    super.initState();

    // Varsayilan tarih degerleri
    _pickupDate = DateTime.now().add(const Duration(days: 1));
    _dropoffDate = DateTime.now().add(const Duration(days: 4));

    // Gercek verileri yukle
    _loadData();

    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _carouselController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _heroAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
      ),
    );

    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });

    _heroController.forward();
    _carouselController.forward();
  }

  Future<void> _loadData() async {
    try {
      // Gercek verileri Supabase'den cek
      final cars = await RentalService.getAvailableCars();
      final locations = await RentalService.getLocations();

      // Rental banner'ini cek
      await _loadRentalBanner();

      debugPrint('=== RENTAL DATA LOADED ===');
      debugPrint('Cars from Supabase: ${cars.length}');
      debugPrint('Locations from Supabase: ${locations.length}');
      for (var car in cars) {
        debugPrint(
            '  - ${car.brandName} ${car.model} (${car.dailyPrice} TL/gun)');
      }

      if (mounted) {
        setState(() {
          _cars = cars;
          _locations = locations;

          // Varsayilan lokasyonlari ayarla
          if (_locations.isNotEmpty) {
            _selectedPickupLocation = _locations.first;
            _selectedDropoffLocation = _locations.first;
          }

        });
      }
    } catch (e) {
      debugPrint('Error loading rental data: $e');
      if (mounted) {
        setState(() {
          _cars = [];
          _locations = [];
        });
      }
    }
  }

  Future<void> _loadRentalBanner() async {
    try {
      final response = await Supabase.instance.client
          .from('banners')
          .select()
          .eq('is_active', true)
          .eq('category', 'rental')
          .order('sort_order', ascending: true);

      if (response.isNotEmpty && mounted) {
        setState(() {
          _heroBanners = List<Map<String, dynamic>>.from(response);
        });
        // Birden fazla banner varsa otomatik kaydirmayi baslat
        if (_heroBanners.length > 1) {
          _startBannerAutoScroll();
        }
      }
    } catch (e) {
      debugPrint('Error loading rental banners: $e');
    }
  }

  void _startBannerAutoScroll() {
    _bannerAutoScrollTimer?.cancel();
    _bannerAutoScrollTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bannerPageController.hasClients &&
          _heroBanners.isNotEmpty &&
          mounted) {
        final nextPage = (_currentBannerIndex + 1) % _heroBanners.length;
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopBannerAutoScroll() {
    _bannerAutoScrollTimer?.cancel();
  }

  void _resumeBannerAutoScroll() {
    if (_heroBanners.length > 1) {
      _startBannerAutoScroll();
    }
  }

  String get _currentBannerTitle {
    if (_heroBanners.isEmpty) return 'Arac Kiralama';
    return _heroBanners[_currentBannerIndex]['title'] as String? ??
        'Arac Kiralama';
  }

  String get _currentBannerSubtitle {
    if (_heroBanners.isEmpty) return 'Luks deneyim, uygun fiyat';
    return _heroBanners[_currentBannerIndex]['description'] as String? ??
        'Luks deneyim, uygun fiyat';
  }

  Widget _buildSingleBannerImage(String imageUrl) {
    return AnimatedBuilder(
      animation: _heroAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            50 * (1 - _heroAnimation.value),
            -_scrollOffset * 0.3,
          ),
          child: Opacity(
            opacity: _heroAnimation.value,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              cacheWidth: 800,
              cacheHeight: 400,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.grey[900]!, Colors.grey[800]!],
                    ),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    size: 120,
                    color: Colors.white24,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _bannerAutoScrollTimer?.cancel();
    _bannerPageController.dispose();
    _heroController.dispose();
    _carouselController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Premium App Bar
            _buildPremiumAppBar(theme, size),

            // Search Card
            SliverToBoxAdapter(child: _buildSearchCard(theme)),

            // Category Selector
            SliverToBoxAdapter(child: _buildCategorySelector(theme)),

            // Featured Car Carousel
            SliverToBoxAdapter(child: _buildFeaturedCarousel(theme, size)),

            // Section Title
            SliverToBoxAdapter(
              child: _buildSectionTitle(theme, 'Populer Araclar'),
            ),

            // Car List (full-width vertical)
            _buildCarList(theme),

            // Premium Packages - paketler artik sirket bazli, booking ekraninda gosteriliyor

            // Bottom Spacing
            SliverToBoxAdapter(
                child: SizedBox(height: context.bottomNavPadding)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar(ThemeData theme, Size size) {
    final double expandedHeight = size.height * 0.35;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Carousel
            _heroBanners.isEmpty
                ? _buildSingleBannerImage(
                    'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800')
                : GestureDetector(
                    onPanDown: (_) => _stopBannerAutoScroll(),
                    onPanEnd: (_) => _resumeBannerAutoScroll(),
                    onPanCancel: () => _resumeBannerAutoScroll(),
                    child: PageView.builder(
                      controller: _bannerPageController,
                      itemCount: _heroBanners.length,
                      onPageChanged: (index) {
                        setState(() => _currentBannerIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final banner = _heroBanners[index];
                        final imageUrl = banner['image_url'] as String? ??
                            'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800';
                        return _buildSingleBannerImage(imageUrl);
                      },
                    ),
                  ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.5),
                    theme.scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),

            // Page Indicators
            if (_heroBanners.length > 1)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _heroBanners.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentBannerIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentBannerIndex == index
                            ? theme.colorScheme.primary
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),

            // Hero Text
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient.createShader(bounds),
                      child: const Text(
                        'PREMIUM',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentBannerTitle,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentBannerSubtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
          ),
          tooltip: 'Rezervasyonlarım',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchCard(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Pickup Location
              _buildLocationField(
                theme: theme,
                icon: _isPickupCustomAddress ? Icons.home : Icons.location_on,
                iconColor: _isPickupCustomAddress
                    ? theme.colorScheme.primary
                    : const Color(0xFF4CAF50),
                label: 'Alis Noktasi',
                value: _isPickupCustomAddress
                    ? _pickupCustomAddress
                    : (_selectedPickupLocation?.name ?? 'Lokasyon Secin'),
                isCustomAddress: _isPickupCustomAddress,
                onTap: () => _showLocationPicker(true),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: theme.dividerColor),
              ),

              // Dropoff Location
              _buildLocationField(
                theme: theme,
                icon: _isDropoffCustomAddress ? Icons.home : Icons.flag,
                iconColor: _isDropoffCustomAddress
                    ? theme.colorScheme.primary
                    : const Color(0xFFE53935),
                label: 'Teslim Noktasi',
                value: _isDropoffCustomAddress
                    ? _dropoffCustomAddress
                    : (_selectedDropoffLocation?.name ?? 'Lokasyon Secin'),
                isCustomAddress: _isDropoffCustomAddress,
                onTap: () => _showLocationPicker(false),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: theme.dividerColor),
              ),

              // Date Selection
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      theme: theme,
                      icon: Icons.calendar_today,
                      label: 'Alis Tarihi',
                      value:
                          '${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}',
                      onTap: () => _selectDate(true),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: theme.dividerColor,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _buildDateField(
                      theme: theme,
                      icon: Icons.event_available,
                      label: 'Teslim Tarihi',
                      value:
                          '${_dropoffDate.day}/${_dropoffDate.month}/${_dropoffDate.year}',
                      onTap: () => _selectDate(false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search Button
              _buildSearchButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isCustomAddress = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    if (isCustomAddress) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Adrese Teslim',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textSecondaryLight),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _searchCars,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Arac Ara',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 24),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategoryIndex == index;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                    _selectedCategory = category['category'];
                  });
                },
                borderRadius: BorderRadius.circular(25),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : theme.cardColor,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : theme.dividerColor,
                    ),
                    boxShadow: isSelected
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        category['icon'],
                        size: 20,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category['name'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCarousel(ThemeData theme, Size size) {
    final premiumCars = _cars.where((car) => car.isPremium).toList();

    return SizedBox(
      height: 280,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.85),
        itemCount: premiumCars.length,
        itemBuilder: (context, index) {
          final car = premiumCars[index];
          return _buildFeaturedCarCard(car, theme);
        },
      ),
    );
  }

  Widget _buildFeaturedCarCard(RentalCar car, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToCarDetail(car),
          borderRadius: BorderRadius.circular(28),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Car Image
                Positioned.fill(
                  child: Image.network(
                    car.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[900],
                        child: const Icon(
                          Icons.directions_car,
                          size: 80,
                          color: Colors.white24,
                        ),
                      );
                    },
                  ),
                ),

                // Gradient Overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                ),

                // Company Badge
                if (car.companyName != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (car.companyLogo != null && car.companyLogo!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                car.companyLogo!,
                                width: 20,
                                height: 20,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.business,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            )
                          else
                            const Icon(Icons.business, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            car.companyName!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Premium Badge
                if (car.isPremium)
                  Positioned(
                    top: car.companyName != null ? 52 : 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.black, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Discount Badge
                if (car.discountPercentage != null &&
                    car.discountPercentage! > 0)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '-${car.discountPercentage!.toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                // Car Info
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCarSpec(Icons.speed, car.transmissionName),
                          const SizedBox(width: 16),
                          _buildCarSpec(
                              Icons.local_gas_station, car.fuelTypeName),
                          const SizedBox(width: 16),
                          _buildCarSpec(Icons.person, '${car.seats} Kisi'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Rating
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                car.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                ' (${car.reviewCount})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          // Price
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (car.discountPercentage != null &&
                                  car.discountPercentage! > 0)
                                Text(
                                  '\u20BA${car.dailyPrice.toInt()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                '\u20BA${car.discountedDailyPrice.toInt()}/gun',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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

  Widget _buildCarSpec(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.white60)),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              'Tumunu Gor',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarList(ThemeData theme) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final car = _filteredCars[index];
            return _buildCarListItem(car, theme, index);
          },
          childCount: _filteredCars.length,
        ),
      ),
    );
  }

  Widget _buildCarListItem(RentalCar car, ThemeData theme, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        child: InkWell(
          onTap: () => _navigateToCarDetail(car),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Car Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    car.thumbnailUrl,
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.directions_car,
                            size: 40,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                // Car Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.fullName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Company name
                      if (car.companyName != null)
                        Row(
                          children: [
                            Icon(Icons.business, size: 12,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              car.companyName!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      if (car.companyName != null)
                        const SizedBox(height: 4),
                      Text(
                        '${car.transmissionName} \u2022 ${car.fuelTypeName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            car.rating.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            ' (${car.reviewCount})',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\u20BA${car.discountedDailyPrice.toInt()}/gun',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationPicker(bool isPickup) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                isPickup ? 'Alis Noktasi Secin' : 'Teslim Noktasi Secin',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

            // Adrese Teslim Secenegi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _showCustomAddressDialog(isPickup);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        const Color(0xFF5B8DEF).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Adrese Teslim',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPickup
                                  ? 'Araci adresinizden teslim alin'
                                  : 'Araci adresinize teslim edelim',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Ayirici
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: Divider(color: theme.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'veya ofis lokasyonu secin',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: theme.dividerColor)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final location = _locations[index];
                  return ListTile(
                    onTap: () {
                      setState(() {
                        if (isPickup) {
                          _selectedPickupLocation = location;
                          _isPickupCustomAddress = false;
                          _pickupCustomAddress = '';
                          _pickupCustomAddressNote = '';
                        } else {
                          _selectedDropoffLocation = location;
                          _isDropoffCustomAddress = false;
                          _dropoffCustomAddress = '';
                          _dropoffCustomAddressNote = '';
                        }
                      });
                      Navigator.pop(context);
                    },
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: location.isAirport
                            ? const Color(0xFF1E88E5)
                                .withValues(alpha: 0.1)
                            : const Color(0xFF4CAF50)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        location.isAirport
                            ? Icons.flight
                            : Icons.location_on,
                        color: location.isAirport
                            ? const Color(0xFF1E88E5)
                            : const Color(0xFF4CAF50),
                      ),
                    ),
                    title: Text(
                      location.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      location.address,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    trailing: location.is24Hours
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '7/24',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomAddressDialog(bool isPickup) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Baslik
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.home_outlined,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPickup ? 'Alis Adresi' : 'Teslim Adresi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Adres secim yontinizi belirleyin',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Secenek 1: Konumumu Kullan
                    _buildAddressOptionCard(
                      theme: theme,
                      icon: Icons.my_location,
                      iconColor: const Color(0xFF4CAF50),
                      title: 'Konumumu Kullan',
                      subtitle:
                          'GPS ile mevcut konumunuzu otomatik alin',
                      onTap: () {
                        Navigator.pop(context);
                        _getCurrentLocationAddress(isPickup);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Secenek 2: Kayitli Adreslerim
                    _buildAddressOptionCard(
                      theme: theme,
                      icon: Icons.bookmark_outline,
                      iconColor: const Color(0xFFFF9800),
                      title: 'Kayitli Adreslerim',
                      subtitle:
                          'Daha once kaydettiginiz adreslerden secin',
                      onTap: () {
                        Navigator.pop(context);
                        _showSavedAddressesDialog(isPickup);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Secenek 3: Yeni Adres Gir
                    _buildAddressOptionCard(
                      theme: theme,
                      icon: Icons.edit_location_alt_outlined,
                      iconColor: AppColors.primary,
                      title: 'Yeni Adres Gir',
                      subtitle: 'Adresi manuel olarak yazin',
                      onTap: () {
                        Navigator.pop(context);
                        _showManualAddressDialog(isPickup);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Bilgi notu
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Adrese teslim hizmeti icin ek ucret uygulanabilir.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressOptionCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // GPS ile konum alma
  Future<void> _getCurrentLocationAddress(bool isPickup) async {
    final theme = Theme.of(context);

    // Loading dialog goster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                const Text('Konum aliniyor...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Konum izni kontrolu
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) Navigator.pop(context);
          _showLocationError('Konum izni reddedildi');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) Navigator.pop(context);
        _showLocationError(
            'Konum izni kalici olarak reddedildi. Ayarlardan izin verin.');
        return;
      }

      // Konum al
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Koordinatlari adrese cevir
      String? address;

      if (kIsWeb) {
        // Web platformunda LocationService kullan (Google Geocoding API)
        address = await LocationService().getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
      } else {
        // Mobilde geocoding paketi kullan
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            address = _formatPlacemark(placemarks.first);
          }
        } catch (e) {
          debugPrint('Geocoding error: $e');
          // Fallback to LocationService
          address = await LocationService().getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );
        }
      }

      if (mounted) Navigator.pop(context); // Loading'i kapat

      if (!mounted) return;

      if (address != null && address.isNotEmpty) {
        _showAddressConfirmDialog(isPickup, address);
      } else {
        _showLocationError('Adres bilgisi alinamadi');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      _showLocationError('Konum alinamadi: ${e.toString()}');
    }
  }

  String _formatPlacemark(Placemark place) {
    final parts = <String>[];

    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.subAdministrativeArea != null &&
        place.subAdministrativeArea!.isNotEmpty) {
      parts.add(place.subAdministrativeArea!);
    }
    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }

    return parts.join(', ');
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        action: SnackBarAction(
          label: 'Manuel Gir',
          textColor: Colors.white,
          onPressed: () => _showManualAddressDialog(true),
        ),
      ),
    );
  }

  // Konum onay dialogu
  void _showAddressConfirmDialog(bool isPickup, String address) {
    final theme = Theme.of(context);
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basari ikonu
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.success,
                        size: 40,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'Konum Bulundu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bulunan adres
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Adres tarifi
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Adres Tarifi (Opsiyonel)',
                      hintText: 'Orn: Mavi binanin onu, 3. kat',
                      prefixIcon: const Icon(Icons.note_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showManualAddressDialog(isPickup);
                          },
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Duzenle'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (isPickup) {
                                _isPickupCustomAddress = true;
                                _pickupCustomAddress = address;
                                _pickupCustomAddressNote =
                                    noteController.text.trim();
                                _selectedPickupLocation = null;
                              } else {
                                _isDropoffCustomAddress = true;
                                _dropoffCustomAddress = address;
                                _dropoffCustomAddressNote =
                                    noteController.text.trim();
                                _selectedDropoffLocation = null;
                              }
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Onayla',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Kayitli adresler dialogu
  void _showSavedAddressesDialog(bool isPickup) async {
    // Kullanicinin kayitli adreslerini cek (saved_locations tablosundan)
    List<Map<String, dynamic>> savedAddresses = [];

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final response = await Supabase.instance.client
            .from('saved_locations')
            .select()
            .eq('user_id', userId)
            .eq('is_active', true)
            .order('is_default', ascending: false)
            .order('sort_order', ascending: true);

        savedAddresses = List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error loading saved addresses: $e');
    }

    if (!mounted) return;

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Kayitli Adreslerim',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualAddressDialog(isPickup,
                          saveAddress: true);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni Ekle'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: savedAddresses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 64,
                            color: theme.dividerColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Kayitli adresiniz yok',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showManualAddressDialog(isPickup,
                                  saveAddress: true);
                            },
                            child: const Text('Yeni Adres Ekle'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: savedAddresses.length,
                      itemBuilder: (context, index) {
                        final addr = savedAddresses[index];
                        final isDefault =
                            addr['is_default'] == true;
                        final addressType =
                            addr['type'] ?? 'other';

                        IconData typeIcon;
                        switch (addressType) {
                          case 'home':
                            typeIcon = Icons.home;
                            break;
                          case 'work':
                            typeIcon = Icons.work;
                            break;
                          default:
                            typeIcon = Icons.location_on;
                        }

                        // Tam adresi olustur
                        final fullAddress =
                            _buildFullAddress(addr);
                        final directions =
                            addr['directions'] ?? '';

                        return ListTile(
                          onTap: () {
                            setState(() {
                              if (isPickup) {
                                _isPickupCustomAddress = true;
                                _pickupCustomAddress =
                                    fullAddress;
                                _pickupCustomAddressNote =
                                    directions;
                                _selectedPickupLocation = null;
                              } else {
                                _isDropoffCustomAddress = true;
                                _dropoffCustomAddress =
                                    fullAddress;
                                _dropoffCustomAddressNote =
                                    directions;
                                _selectedDropoffLocation = null;
                              }
                            });
                            Navigator.pop(context);
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Icon(
                              typeIcon,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  addr['name'] ??
                                      addr['title'] ??
                                      'Adres',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow:
                                      TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.primary,
                                    borderRadius:
                                        BorderRadius.circular(
                                            4),
                                  ),
                                  child: const Text(
                                    'Varsayilan',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            fullAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme
                                .onSurfaceVariant,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Manuel adres giris dialogu
  void _showManualAddressDialog(bool isPickup,
      {bool saveAddress = false}) {
    final theme = Theme.of(context);
    final addressController = TextEditingController(
      text: isPickup ? _pickupCustomAddress : _dropoffCustomAddress,
    );
    final noteController = TextEditingController(
      text: isPickup
          ? _pickupCustomAddressNote
          : _dropoffCustomAddressNote,
    );
    final titleController = TextEditingController();
    bool shouldSave = saveAddress;
    String selectedType = 'home';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      isPickup ? 'Alis Adresi' : 'Teslim Adresi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Adres girisi
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Acik Adres *',
                        hintText:
                            'Mahalle, Cadde/Sokak, No, Ilce/Il',
                        prefixIcon:
                            const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Adres tarifi
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Adres Tarifi (Opsiyonel)',
                        hintText: 'Bina rengi, kat, kapi no vs.',
                        prefixIcon:
                            const Icon(Icons.note_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Adresi kaydet secenegi
                    InkWell(
                      onTap: () {
                        setDialogState(
                            () => shouldSave = !shouldSave);
                      },
                      child: Row(
                        children: [
                          Checkbox(
                            value: shouldSave,
                            onChanged: (v) {
                              setDialogState(
                                  () => shouldSave = v ?? false);
                            },
                            activeColor:
                                theme.colorScheme.primary,
                          ),
                          Text(
                            'Bu adresi kaydet',
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Kaydetme secenekleri
                    if (shouldSave) ...[
                      const SizedBox(height: 12),

                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Adres Basligi',
                          hintText: 'Orn: Evim, Is Yerim',
                          prefixIcon:
                              const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Adres tipi secimi
                      Row(
                        children: [
                          _buildAddressTypeChip(
                            theme,
                            'home',
                            Icons.home,
                            'Ev',
                            selectedType,
                            (type) => setDialogState(
                                () => selectedType = type),
                          ),
                          const SizedBox(width: 8),
                          _buildAddressTypeChip(
                            theme,
                            'work',
                            Icons.work,
                            'Is',
                            selectedType,
                            (type) => setDialogState(
                                () => selectedType = type),
                          ),
                          const SizedBox(width: 8),
                          _buildAddressTypeChip(
                            theme,
                            'other',
                            Icons.location_on,
                            'Diger',
                            selectedType,
                            (type) => setDialogState(
                                () => selectedType = type),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Butonlar
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Iptal'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (addressController.text
                                  .trim()
                                  .isEmpty) {
                                AppDialogs.showWarning(context,
                                    'Lutfen adres girin');
                                return;
                              }

                              final address = addressController
                                  .text
                                  .trim();
                              final note =
                                  noteController.text.trim();

                              // Adresi kaydet
                              if (shouldSave) {
                                await _saveAddress(
                                  title: titleController.text
                                          .trim()
                                          .isEmpty
                                      ? (selectedType == 'home'
                                          ? 'Evim'
                                          : selectedType ==
                                                  'work'
                                              ? 'Is Yerim'
                                              : 'Adresim')
                                      : titleController.text
                                          .trim(),
                                  address: address,
                                  notes: note,
                                  addressType: selectedType,
                                );
                              }

                              if (!mounted) return;

                              setState(() {
                                if (isPickup) {
                                  _isPickupCustomAddress =
                                      true;
                                  _pickupCustomAddress =
                                      address;
                                  _pickupCustomAddressNote =
                                      note;
                                  _selectedPickupLocation =
                                      null;
                                } else {
                                  _isDropoffCustomAddress =
                                      true;
                                  _dropoffCustomAddress =
                                      address;
                                  _dropoffCustomAddressNote =
                                      note;
                                  _selectedDropoffLocation =
                                      null;
                                }
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.primary,
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Kaydet',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressTypeChip(
    ThemeData theme,
    String type,
    IconData icon,
    String label,
    String selectedType,
    Function(String) onSelect,
  ) {
    final isSelected = selectedType == type;
    return InkWell(
      onTap: () => onSelect(type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // saved_locations tablosundan tam adres olustur
  String _buildFullAddress(Map<String, dynamic> addr) {
    final parts = <String>[];

    if (addr['address'] != null &&
        addr['address'].toString().isNotEmpty) {
      parts.add(addr['address'].toString());
    }
    if (addr['address_details'] != null &&
        addr['address_details'].toString().isNotEmpty) {
      parts.add(addr['address_details'].toString());
    }
    if (addr['floor'] != null &&
        addr['floor'].toString().isNotEmpty) {
      parts.add('Kat: ${addr['floor']}');
    }
    if (addr['apartment'] != null &&
        addr['apartment'].toString().isNotEmpty) {
      parts.add('Daire: ${addr['apartment']}');
    }

    return parts.join(', ');
  }

  Future<void> _saveAddress({
    required String title,
    required String address,
    required String notes,
    required String addressType,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // saved_locations tablosuna kaydet (ana uygulama ile uyumlu)
      await Supabase.instance.client.from('saved_locations').insert({
        'user_id': userId,
        'name': title,
        'address': address,
        'directions': notes,
        'type': addressType,
        'is_default': false,
        'is_active': true,
        'sort_order': 0,
      });
    } catch (e) {
      debugPrint('Error saving address: $e');
    }
  }

  Future<void> _selectDate(bool isPickup) async {
    final theme = Theme.of(context);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPickup ? _pickupDate : _dropoffDate,
      firstDate: isPickup ? DateTime.now() : _pickupDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPickup) {
          _pickupDate = picked;
          // Eger iade tarihi alis tarihinden onceyse, iade tarihini guncelle
          if (_dropoffDate.isBefore(picked) ||
              _dropoffDate.isAtSameMomentAs(picked)) {
            _dropoffDate = picked.add(const Duration(days: 1));
          }
        } else {
          _dropoffDate = picked;
        }
      });
    }
  }

  void _searchCars() async {
    int rentalDays = _dropoffDate.difference(_pickupDate).inDays;
    // En az 1 gun olmali
    if (rentalDays < 1) rentalDays = 1;

    // Loading goster
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    List<RentalCar> availableCars = [];

    try {
      // Gercek verilerden musait araclari getir
      debugPrint(
          'Searching cars for dates: $_pickupDate - $_dropoffDate');
      availableCars = await RentalService.getAvailableCarsForDates(
        pickupDate: _pickupDate,
        dropoffDate: _dropoffDate,
        category: _selectedCategory,
      );
      debugPrint(
          'Found ${availableCars.length} available cars from Supabase');
    } catch (e) {
      debugPrint('Error searching cars: $e');
      availableCars = [];
    }

    if (!mounted) return;

    // Loading'i kapat - rootNavigator kullan
    Navigator.of(context, rootNavigator: true).pop();

    // Sonuclari goster
    _showSearchResults(rentalDays, availableCars);
  }

  void _showSearchResults(
      int rentalDays, List<RentalCar> availableCars) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arama Sonuclari',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme
                                      .colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${availableCars.length} arac bulundu \u2022 $rentalDays gun',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          icon: Icon(Icons.close,
                              color: theme.colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Search summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color: theme.dividerColor),
                      ),
                      child: Column(
                        children: [
                          _buildSearchSummaryRow(
                            theme,
                            _isPickupCustomAddress
                                ? Icons.home
                                : Icons.location_on,
                            _isPickupCustomAddress
                                ? theme.colorScheme.primary
                                : const Color(0xFF4CAF50),
                            'Alis',
                            _isPickupCustomAddress
                                ? _pickupCustomAddress
                                : (_selectedPickupLocation
                                        ?.name ??
                                    '-'),
                          ),
                          const SizedBox(height: 8),
                          _buildSearchSummaryRow(
                            theme,
                            _isDropoffCustomAddress
                                ? Icons.home
                                : Icons.flag,
                            _isDropoffCustomAddress
                                ? theme.colorScheme.primary
                                : const Color(0xFFE53935),
                            'Teslim',
                            _isDropoffCustomAddress
                                ? _dropoffCustomAddress
                                : (_selectedDropoffLocation
                                        ?.name ??
                                    '-'),
                          ),
                          const SizedBox(height: 8),
                          _buildSearchSummaryRow(
                            theme,
                            Icons.calendar_today,
                            theme.colorScheme.primary,
                            'Tarih',
                            '${_pickupDate.day}/${_pickupDate.month} - ${_dropoffDate.day}/${_dropoffDate.month}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Car list
              Expanded(
                child: availableCars.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.car_rental,
                              size: 64,
                              color: theme.dividerColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Uygun arac bulunamadi',
                              style: TextStyle(
                                fontSize: 18,
                                color: theme.colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Farkli tarih veya kategori deneyin',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors
                                    .textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20),
                        itemCount: availableCars.length,
                        itemBuilder: (context, index) {
                          final car = availableCars[index];
                          final totalPrice =
                              car.discountedDailyPrice *
                                  rentalDays;
                          return _buildSearchResultCard(
                            theme,
                            car,
                            rentalDays,
                            totalPrice,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSummaryRow(
    ThemeData theme,
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondaryLight),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(
    ThemeData theme,
    RentalCar car,
    int rentalDays,
    double totalPrice,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _navigateToCarDetail(car);
        },
        child: Column(
          children: [
            // Car image and info
            Row(
              children: [
                // Car Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  child: car.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          car.thumbnailUrl,
                          width: 130,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return Container(
                              width: 130,
                              height: 120,
                              color: AppColors.surfaceLight,
                              child: const Icon(
                                Icons.directions_car,
                                color: AppColors
                                    .textSecondaryLight,
                                size: 40,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 130,
                          height: 120,
                          color: AppColors.surfaceLight,
                          child: const Icon(
                            Icons.directions_car,
                            color:
                                AppColors.textSecondaryLight,
                            size: 40,
                          ),
                        ),
                ),

                // Car details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Company name
                        if (car.companyName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.business, size: 12,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  car.companyName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                car.fullName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme
                                      .colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                            if (car.isPremium)
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors
                                      .primaryGradient,
                                  borderRadius:
                                      BorderRadius.circular(
                                          6),
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight:
                                        FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${car.rating}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme
                                    .colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              ' (${car.reviewCount})',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors
                                    .textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildCarChip(theme, Icons.speed,
                                car.transmissionName),
                            _buildCarChip(
                                theme,
                                Icons.local_gas_station,
                                car.fuelTypeName),
                            _buildCarChip(theme,
                                Icons.person, '${car.seats}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Price section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u20BA${car.discountedDailyPrice.toInt()}/gun',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme
                              .colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '\u20BA${totalPrice.toInt()}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color:
                                  theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            ' / $rentalDays gun',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors
                                  .textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Sec',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 18,
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
    );
  }

  Widget _buildCarChip(ThemeData theme, IconData icon, String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _navigateToCarDetail(RentalCar car) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CarDetailScreen(
          car: car,
          pickupLocation: _selectedPickupLocation,
          dropoffLocation: _selectedDropoffLocation,
          pickupDate: _pickupDate,
          dropoffDate: _dropoffDate,
          isPickupCustomAddress: _isPickupCustomAddress,
          isDropoffCustomAddress: _isDropoffCustomAddress,
          pickupCustomAddress: _pickupCustomAddress,
          dropoffCustomAddress: _dropoffCustomAddress,
          pickupCustomAddressNote: _pickupCustomAddressNote,
          dropoffCustomAddressNote: _dropoffCustomAddressNote,
        ),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
