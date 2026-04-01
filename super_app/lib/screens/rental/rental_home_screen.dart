import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../models/rental/rental_models.dart';
import '../../core/services/rental_service.dart';
import '../../widgets/common/shimmer_widgets.dart';
import 'car_detail_screen.dart';
import 'my_bookings_screen.dart';
import 'rental_car_cards.dart';
import 'rental_location_picker.dart';
import 'rental_search_results_sheet.dart';

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

  bool _isLoading = true;
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
      if (!mounted) return;
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });

    _heroController.forward();
    _carouselController.forward();
  }

  Future<void> _loadData() async {
    try {
      final cars = await RentalService.getAvailableCars();
      final locations = await RentalService.getLocations();
      await _loadRentalBanner();

      if (mounted) {
        setState(() {
          _cars = cars;
          _locations = locations;
          _isLoading = false;
          if (_locations.isNotEmpty) {
            _selectedPickupLocation ??= _locations.first;
            _selectedDropoffLocation ??= _locations.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading rental data: $e');
      if (mounted) {
        setState(() {
          _cars = [];
          _locations = [];
          _isLoading = false;
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
    _bannerAutoScrollTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) {
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
          offset: Offset(50 * (1 - _heroAnimation.value), -_scrollOffset * 0.3),
          child: Opacity(
            opacity: _heroAnimation.value,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              memCacheHeight: 200,
              placeholder: (_, _) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white24,
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
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
              ),
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

            // Search Pill
            SliverToBoxAdapter(child: _buildSearchPill(theme)),

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
              child: SizedBox(height: context.bottomNavPadding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar(ThemeData theme, Size size) {
    final double expandedHeight = size.height * 0.25;

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
                    'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800',
                  )
                : GestureDetector(
                    onPanDown: (_) => _stopBannerAutoScroll(),
                    onPanEnd: (_) => _resumeBannerAutoScroll(),
                    onPanCancel: () => _resumeBannerAutoScroll(),
                    child: PageView.builder(
                      controller: _bannerPageController,
                      itemCount: _heroBanners.length,
                      onPageChanged: (index) {
                        if (!mounted) return;
                        setState(() => _currentBannerIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final banner = _heroBanners[index];
                        final imageUrl =
                            banner['image_url'] as String? ??
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
                bottom: 70,
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
              left: 16,
              right: 16,
              bottom: 24,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentBannerTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentBannerSubtitle,
                      style: TextStyle(
                        fontSize: 13,
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
        onPressed: () => context.pop(),
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

  String _formatShortDate(DateTime date) {
    final months = [
      'Oca',
      'Sub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Agu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  int get _rentalDays {
    final days = _dropoffDate.difference(_pickupDate).inDays;
    return days < 1 ? 1 : days;
  }

  String get _pickupLocationName {
    if (_isPickupCustomAddress) return _pickupCustomAddress;
    return _selectedPickupLocation?.name ?? 'Lokasyon Secin';
  }

  Widget _buildSearchPill(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(28),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            onTap: _openSearchSheet,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickupLocationName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_formatShortDate(_pickupDate)} - ${_formatShortDate(_dropoffDate)}  ·  $_rentalDays gun',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSearchSheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.cardColor,
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
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Arac Ara',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pickup Location
                      _buildSheetField(
                        theme: theme,
                        icon: _isPickupCustomAddress
                            ? Icons.home
                            : Icons.location_on,
                        iconColor: _isPickupCustomAddress
                            ? theme.colorScheme.primary
                            : AppColors.success,
                        label: 'Alis Noktasi',
                        value: _isPickupCustomAddress
                            ? _pickupCustomAddress
                            : (_selectedPickupLocation?.name ??
                                  'Lokasyon Secin'),
                        onTap: () {
                          Navigator.pop(context);
                          _handleShowLocationPicker(true);
                        },
                      ),
                      const SizedBox(height: 12),
                      // Dropoff Location
                      _buildSheetField(
                        theme: theme,
                        icon: _isDropoffCustomAddress ? Icons.home : Icons.flag,
                        iconColor: _isDropoffCustomAddress
                            ? theme.colorScheme.primary
                            : AppColors.error,
                        label: 'Teslim Noktasi',
                        value: _isDropoffCustomAddress
                            ? _dropoffCustomAddress
                            : (_selectedDropoffLocation?.name ??
                                  'Lokasyon Secin'),
                        onTap: () {
                          Navigator.pop(context);
                          _handleShowLocationPicker(false);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _buildSheetDateField(
                              theme: theme,
                              label: 'Alis Tarihi',
                              value:
                                  '${_pickupDate.day}/${_pickupDate.month}/${_pickupDate.year}',
                              onTap: () async {
                                Navigator.pop(context);
                                await _selectDate(true);
                                if (mounted) _openSearchSheet();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSheetDateField(
                              theme: theme,
                              label: 'Teslim Tarihi',
                              value:
                                  '${_dropoffDate.day}/${_dropoffDate.month}/${_dropoffDate.year}',
                              onTap: () async {
                                Navigator.pop(context);
                                await _selectDate(false);
                                if (mounted) _openSearchSheet();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Duration info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.access_time,
                              color: theme.colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Toplam $_rentalDays gun',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              // Search button
              Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _searchCars();
                    },
                    icon: const Icon(Icons.search, size: 20),
                    label: const Text(
                      'Arac Ara',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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

  Widget _buildSheetField({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetDateField({
    required ThemeData theme,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category['name'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
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
    if (_isLoading) {
      return SizedBox(
        height: 220,
        child: PageView(
          controller: PageController(viewportFraction: 0.85),
          children: const [ShimmerFeaturedCard(), ShimmerFeaturedCard()],
        ),
      );
    }

    final premiumCars = _cars.where((car) => car.isPremium).toList();
    if (premiumCars.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.85),
        itemCount: premiumCars.length,
        itemBuilder: (context, index) {
          final car = premiumCars[index];
          return buildFeaturedCarCard(
            car,
            theme,
            onTap: () => _navigateToCarDetail(car),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildCarList(ThemeData theme) {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const ShimmerCarCard(),
            childCount: 4,
          ),
        ),
      );
    }

    if (_filteredCars.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.directions_car,
                  size: 56,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Arac bulunamadi',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final car = _filteredCars[index];
          return buildCarListItem(
            car,
            theme,
            index,
            onTap: () => _navigateToCarDetail(car),
          );
        }, childCount: _filteredCars.length),
      ),
    );
  }

  // --- Location picker handler methods ---

  void _handleShowLocationPicker(bool isPickup) {
    showRentalLocationPicker(
      context: context,
      isPickup: isPickup,
      locations: _locations,
      onLocationSelected: (location) {
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
      },
      onCustomAddressTap: () => _handleShowCustomAddressDialog(isPickup),
    );
  }

  void _handleShowCustomAddressDialog(bool isPickup) {
    showCustomAddressDialog(
      context: context,
      isPickup: isPickup,
      onUseCurrentLocation: () => _handleGetCurrentLocation(isPickup),
      onShowSavedAddresses: () => _handleShowSavedAddresses(isPickup),
      onManualEntry: () => _handleShowManualAddress(isPickup),
    );
  }

  void _handleGetCurrentLocation(bool isPickup) {
    getCurrentLocationAddress(
      context: context,
      isPickup: isPickup,
      onAddressFound: (address) {
        showAddressConfirmDialog(
          context: context,
          isPickup: isPickup,
          address: address,
          onConfirm:
              ({
                required bool isPickup,
                required String address,
                required String note,
              }) {
                _setCustomAddress(
                  isPickup: isPickup,
                  address: address,
                  note: note,
                );
              },
          onEdit: (isPickup) => _handleShowManualAddress(isPickup),
        );
      },
      onShowManualEntry: (isPickup) => _handleShowManualAddress(isPickup),
    );
  }

  void _handleShowSavedAddresses(bool isPickup) {
    showSavedAddressesDialog(
      context: context,
      isPickup: isPickup,
      onAddressSelected:
          ({
            required bool isPickup,
            required String address,
            required String note,
          }) {
            _setCustomAddress(isPickup: isPickup, address: address, note: note);
          },
      onShowManualEntry: (isPickup, {bool saveAddress = false}) =>
          _handleShowManualAddress(isPickup, saveAddress: saveAddress),
    );
  }

  void _handleShowManualAddress(bool isPickup, {bool saveAddress = false}) {
    showManualAddressDialog(
      context: context,
      isPickup: isPickup,
      currentAddress: isPickup ? _pickupCustomAddress : _dropoffCustomAddress,
      currentNote: isPickup
          ? _pickupCustomAddressNote
          : _dropoffCustomAddressNote,
      saveAddress: saveAddress,
      onAddressConfirmed:
          ({
            required bool isPickup,
            required String address,
            required String note,
          }) {
            _setCustomAddress(isPickup: isPickup, address: address, note: note);
          },
    );
  }

  void _setCustomAddress({
    required bool isPickup,
    required String address,
    required String note,
  }) {
    setState(() {
      if (isPickup) {
        _isPickupCustomAddress = true;
        _pickupCustomAddress = address;
        _pickupCustomAddressNote = note;
        _selectedPickupLocation = null;
      } else {
        _isDropoffCustomAddress = true;
        _dropoffCustomAddress = address;
        _dropoffCustomAddressNote = note;
        _selectedDropoffLocation = null;
      }
    });
  }

  // --- Date & Search methods ---

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
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    List<RentalCar> availableCars = [];

    try {
      // Gercek verilerden musait araclari getir
      debugPrint('Searching cars for dates: $_pickupDate - $_dropoffDate');
      availableCars = await RentalService.getAvailableCarsForDates(
        pickupDate: _pickupDate,
        dropoffDate: _dropoffDate,
        category: _selectedCategory,
      );
      debugPrint('Found ${availableCars.length} available cars from Supabase');
    } catch (e) {
      debugPrint('Error searching cars: $e');
      availableCars = [];
    }

    if (!mounted) return;

    // Loading'i kapat - rootNavigator kullan
    Navigator.of(context, rootNavigator: true).pop();

    // Sonuclari goster
    showRentalSearchResults(
      context: context,
      rentalDays: rentalDays,
      availableCars: availableCars,
      isPickupCustomAddress: _isPickupCustomAddress,
      isDropoffCustomAddress: _isDropoffCustomAddress,
      pickupCustomAddress: _pickupCustomAddress,
      dropoffCustomAddress: _dropoffCustomAddress,
      selectedPickupLocation: _selectedPickupLocation,
      selectedDropoffLocation: _selectedDropoffLocation,
      pickupDate: _pickupDate,
      dropoffDate: _dropoffDate,
      onCarSelected: _navigateToCarDetail,
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
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
