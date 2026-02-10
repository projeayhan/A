import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../core/providers/unified_favorites_provider.dart';
import '../../services/car_sales_service.dart';

class CarDetailScreen extends ConsumerStatefulWidget {
  final CarListing car;

  const CarDetailScreen({super.key, required this.car});

  @override
  ConsumerState<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends ConsumerState<CarDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fabController;
  late AnimationController _parallaxController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final PageController _imagePageController = PageController();
  final ScrollController _scrollController = ScrollController();

  int _currentImageIndex = 0;
  double _scrollOffset = 0;
  bool _showFullDescription = false;
  List<CarListing> _similarCars = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _parallaxController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    );

    _scrollController.addListener(_onScroll);

    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      _fabController.forward();
    });

    // Görüntülenme kaydı
    _recordView();
    _loadSimilarCars();
  }

  Future<void> _loadSimilarCars() async {
    try {
      final listings = await CarSalesService.instance.getActiveListings(
        brandId: widget.car.brand.id,
        limit: 4,
      );
      if (mounted) {
        setState(() {
          _similarCars = listings
              .where((l) => l.id != widget.car.id)
              .take(4)
              .map((l) => l.toCarListing())
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _recordView() async {
    try {
      await CarSalesService.instance.recordView(widget.car.id);
    } catch (_) {
      // Görüntülenme kaydı kritik değil
    }
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fabController.dispose();
    _parallaxController.dispose();
    _imagePageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final car = widget.car;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: CarSalesColors.background(isDark),
        body: Stack(
          children: [
            // Main Content
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Image Gallery with Parallax
                SliverToBoxAdapter(
                  child: _buildImageGallery(isDark, size, car),
                ),

                // Quick Stats Bar
                SliverToBoxAdapter(
                  child: _buildQuickStatsBar(isDark, car),
                ),

                // Price Section
                SliverToBoxAdapter(
                  child: _buildPriceSection(isDark, car),
                ),

                // Key Specifications
                SliverToBoxAdapter(
                  child: _buildKeySpecs(isDark, car),
                ),

                // Description
                SliverToBoxAdapter(
                  child: _buildDescription(isDark, car),
                ),

                // Features Grid
                SliverToBoxAdapter(
                  child: _buildFeaturesSection(isDark, car),
                ),

                // Technical Details
                SliverToBoxAdapter(
                  child: _buildTechnicalDetails(isDark, car),
                ),

                // Seller Info
                SliverToBoxAdapter(
                  child: _buildSellerSection(isDark, car),
                ),

                // Similar Cars
                SliverToBoxAdapter(
                  child: _buildSimilarCars(isDark),
                ),

                // Bottom spacing for FAB
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),

            // Animated App Bar
            _buildAnimatedAppBar(isDark, car),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(bool isDark, Size size, CarListing car) {
    final imageHeight = size.height * 0.45;

    return SizedBox(
      height: imageHeight,
      child: Stack(
        children: [
          // Parallax Image
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, _scrollOffset * 0.4),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: PageView.builder(
                controller: _imagePageController,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemCount: car.images.length,
                itemBuilder: (context, index) {
                  return Hero(
                    tag: index == 0 ? 'car_${car.id}' : 'car_${car.id}_$index',
                    child: CachedNetworkImage(
                      imageUrl: car.images[index],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: CarSalesColors.surface(isDark),
                        child: Icon(
                          Icons.directions_car,
                          size: 80,
                          color: CarSalesColors.textTertiary(isDark),
                        ),
                      ),
                    ),
                  );
                },
              ),
              ),
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
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Premium Badge
          if (car.isPremiumListing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 20,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: CarSalesColors.goldGradient,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CarSalesColors.secondary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'PREMIUM İLAN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Image Counter
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_currentImageIndex + 1} / ${car.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Image Indicators
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(car.images.length, (index) {
                final isActive = index == _currentImageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // 360° View Button (if video exists)
          if (car.videoUrl != null)
            Positioned(
              right: 20,
              bottom: 80,
              child: GestureDetector(
                onTap: () {
                  // Open 360° view or video
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.view_in_ar,
                    color: CarSalesColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAppBar(bool isDark, CarListing car) {
    final showTitle = _scrollOffset > 200;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: showTitle
              ? CarSalesColors.card(isDark)
              : Colors.transparent,
          boxShadow: showTitle
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: showTitle
                        ? CarSalesColors.surface(isDark)
                        : Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: showTitle
                        ? CarSalesColors.textPrimary(isDark)
                        : Colors.white,
                    size: 22,
                  ),
                ),
              ),

              // Title
              Expanded(
                child: AnimatedOpacity(
                  opacity: showTitle ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      car.fullName,
                      style: TextStyle(
                        color: CarSalesColors.textPrimary(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // Share Button
              GestureDetector(
                onTap: () => _shareCarListing(car),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: showTitle
                        ? CarSalesColors.surface(isDark)
                        : Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.share,
                    color: showTitle
                        ? CarSalesColors.textPrimary(isDark)
                        : Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Favorite Button
              _buildFavoriteButton(isDark, showTitle, car),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(bool isDark, bool showTitle, CarListing car) {
    final isFavorite = ref.watch(isCarFavoriteProvider(car.id));

    return GestureDetector(
      onTap: () {
        final favoriteCar = FavoriteCar(
          id: car.id,
          title: car.title,
          imageUrl: car.images.isNotEmpty ? car.images.first : '',
          brand: car.brand.name,
          model: car.modelName,
          year: car.year,
          km: car.mileage,
          price: car.price,
          fuelType: car.fuelType.label,
          transmission: car.transmission.label,
          location: car.location,
          addedAt: DateTime.now(),
        );
        ref.read(carFavoriteProvider.notifier).toggleCar(favoriteCar);
        HapticFeedback.lightImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFavorite
                  ? '${car.title} favorilerden kaldırıldı'
                  : '${car.title} favorilere eklendi',
            ),
            backgroundColor: isFavorite ? Colors.red : CarSalesColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: showTitle
              ? CarSalesColors.surface(isDark)
              : Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(isFavorite),
            color: isFavorite
                ? CarSalesColors.accent
                : showTitle
                    ? CarSalesColors.textPrimary(isDark)
                    : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatsBar(bool isDark, CarListing car) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: CarSalesColors.card(isDark),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildStatItem(
                isDark,
                Icons.calendar_today,
                '${car.year}',
                'Model Yılı',
              ),
              _buildStatDivider(isDark),
              _buildStatItem(
                isDark,
                Icons.speed,
                car.formattedMileage,
                'Kilometre',
              ),
              _buildStatDivider(isDark),
              _buildStatItem(
                isDark,
                car.fuelType.icon,
                car.fuelType.label,
                'Yakıt',
              ),
              _buildStatDivider(isDark),
              _buildStatItem(
                isDark,
                car.transmission.icon,
                car.transmission.label,
                'Vites',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    bool isDark,
    IconData icon,
    String value,
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: CarSalesColors.primary,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: CarSalesColors.textTertiary(isDark),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      color: CarSalesColors.divider(isDark),
    );
  }

  Widget _buildPriceSection(bool isDark, CarListing car) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : CarSalesColors.primaryGradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CarSalesColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fiyat',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      car.fullFormattedPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (car.isPriceNegotiable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.handshake,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pazarlık Olur',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (car.isExchangeAccepted)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Takas Olur',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPriceStatItem(
                  Icons.visibility,
                  '${car.viewCount}',
                  'Görüntülenme',
                ),
                _buildPriceStatItem(
                  Icons.favorite,
                  '${car.favoriteCount}',
                  'Favori',
                ),
                _buildPriceStatItem(
                  Icons.access_time,
                  car.timeAgo,
                  'Yayında',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildKeySpecs(bool isDark, CarListing car) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temel Özellikler',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSpecCard(isDark, 'Marka', car.brand.name, Icons.business),
              _buildSpecCard(isDark, 'Model', car.modelName, Icons.directions_car),
              _buildSpecCard(isDark, 'Kasa Tipi', car.bodyType.label, car.bodyType.icon),
              _buildSpecCard(isDark, 'Motor', '${car.engineCC} cc', Icons.engineering),
              _buildSpecCard(isDark, 'Güç', '${car.horsePower} HP', Icons.bolt),
              _buildSpecCard(isDark, 'Çekiş', car.traction.shortLabel, Icons.all_inclusive),
              _buildSpecCard(isDark, 'Dış Renk', car.exteriorColor.label, Icons.palette),
              _buildSpecCard(isDark, 'İç Renk', car.interiorColor.label, Icons.weekend),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCard(bool isDark, String label, String value, IconData icon) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CarSalesColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: CarSalesColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: CarSalesColors.textTertiary(isDark),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(bool isDark, CarListing car) {
    final description = car.description;
    final shouldTruncate = description.length > 200;
    final displayText = shouldTruncate && !_showFullDescription
        ? '${description.substring(0, 200)}...'
        : description;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Açıklama',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CarSalesColors.card(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CarSalesColors.border(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: TextStyle(
                    color: CarSalesColors.textSecondary(isDark),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                if (shouldTruncate)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showFullDescription = !_showFullDescription;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _showFullDescription ? 'Daha az göster' : 'Devamını oku',
                        style: const TextStyle(
                          color: CarSalesColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(bool isDark, CarListing car) {
    final features = car.features;
    final featuresByCategory = <String, List<CarFeature>>{};

    for (final feature in features) {
      featuresByCategory.putIfAbsent(feature.category, () => []).add(feature);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Donanım & Özellikler',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: CarSalesColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${features.length} özellik',
                  style: const TextStyle(
                    color: CarSalesColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...featuresByCategory.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: CarSalesColors.textSecondary(isDark),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value.map((feature) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: CarSalesColors.card(isDark),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CarSalesColors.border(isDark),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            feature.icon,
                            size: 16,
                            color: CarSalesColors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            feature.name,
                            style: TextStyle(
                              color: CarSalesColors.textPrimary(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetails(bool isDark, CarListing car) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teknik Detaylar',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: CarSalesColors.card(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CarSalesColors.border(isDark)),
            ),
            child: Column(
              children: [
                _buildDetailRow(isDark, 'Durum', car.condition.label, isFirst: true),
                _buildDetailRow(isDark, 'Önceki Sahip', car.previousOwners?.toString() ?? '-'),
                _buildDetailRow(isDark, 'Boyalı Parça', car.hasOriginalPaint ? 'Orijinal' : 'Var'),
                _buildDetailRow(isDark, 'Kaza Kaydı', car.hasAccidentHistory ? 'Var' : 'Yok'),
                _buildDetailRow(isDark, 'Plaka', '${car.plateCity ?? '-'} Plakalı'),
                _buildDetailRow(isDark, 'Garanti', car.hasWarranty ? 'Var' : 'Yok'),
                if (car.warrantyDetails != null)
                  _buildDetailRow(isDark, 'Garanti Detayı', car.warrantyDetails!),
                if (car.serviceHistory != null)
                  _buildDetailRow(isDark, 'Bakım', car.serviceHistory!, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(bool isDark, String label, String value, {bool isFirst = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: CarSalesColors.divider(isDark),
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: CarSalesColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerSection(bool isDark, CarListing car) {
    final seller = car.seller;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Satıcı Bilgileri',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CarSalesColors.card(isDark),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CarSalesColors.border(isDark)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CarSalesColors.surface(isDark),
                        border: Border.all(
                          color: seller.isVerified
                              ? CarSalesColors.success
                              : CarSalesColors.border(isDark),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: seller.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: seller.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  seller.type.icon,
                                  color: CarSalesColors.textSecondary(isDark),
                                  size: 28,
                                ),
                              )
                            : Icon(
                                seller.type.icon,
                                color: CarSalesColors.textSecondary(isDark),
                                size: 28,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  seller.displayName,
                                  style: TextStyle(
                                    color: CarSalesColors.textPrimary(isDark),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (seller.isVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.verified,
                                    color: CarSalesColors.success,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: CarSalesColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  seller.type.label,
                                  style: const TextStyle(
                                    color: CarSalesColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.star,
                                color: CarSalesColors.secondary,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                seller.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: CarSalesColors.textSecondary(isDark),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CarSalesColors.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSellerStat(
                        isDark,
                        '${seller.totalListings}',
                        'İlan',
                      ),
                      _buildSellerStat(
                        isDark,
                        '${seller.soldCount}',
                        'Satış',
                      ),
                      _buildSellerStat(
                        isDark,
                        seller.rating.toStringAsFixed(1),
                        'Puan',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // İletişim Bilgileri
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CarSalesColors.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CarSalesColors.border(isDark)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CarSalesColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.phone,
                          color: CarSalesColors.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Telefon',
                              style: TextStyle(
                                color: CarSalesColors.textTertiary(isDark),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              seller.phone,
                              style: TextStyle(
                                color: CarSalesColors.textPrimary(isDark),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _callSeller(seller.phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: CarSalesColors.success,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.call,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Ara',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  seller.membershipDuration,
                  style: TextStyle(
                    color: CarSalesColors.textTertiary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callSeller(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Widget _buildSellerStat(bool isDark, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: CarSalesColors.textPrimary(isDark),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: CarSalesColors.textTertiary(isDark),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarCars(bool isDark) {
    if (_similarCars.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Benzer İlanlar',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _similarCars.length,
              itemBuilder: (context, index) {
                final car = _similarCars[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => CarDetailScreen(car: car),
                      ),
                    );
                  },
                  child: Container(
                    width: 180,
                    margin: EdgeInsets.only(
                      right: index < _similarCars.length - 1 ? 12 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: CarSalesColors.card(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CarSalesColors.border(isDark)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: car.images.first,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 110,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 110,
                              color: CarSalesColors.surface(isDark),
                              child: Icon(
                                Icons.directions_car,
                                color: CarSalesColors.textTertiary(isDark),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                car.fullName,
                                style: TextStyle(
                                  color: CarSalesColors.textPrimary(isDark),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${car.year} • ${car.formattedMileage}',
                                style: TextStyle(
                                  color: CarSalesColors.textTertiary(isDark),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                car.formattedPrice,
                                style: const TextStyle(
                                  color: CarSalesColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  void _shareCarListing(CarListing car) {
    // Share functionality
    HapticFeedback.lightImpact();
  }
}
