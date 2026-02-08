import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/rental/rental_models.dart';
import 'booking_screen.dart';
import 'all_reviews_screen.dart';

class CarDetailScreen extends StatefulWidget {
  final RentalCar car;
  final RentalLocation? pickupLocation;
  final RentalLocation? dropoffLocation;
  final DateTime? pickupDate;
  final DateTime? dropoffDate;
  // \u00D6zel adres bilgileri
  final bool isPickupCustomAddress;
  final bool isDropoffCustomAddress;
  final String? pickupCustomAddress;
  final String? dropoffCustomAddress;
  final String? pickupCustomAddressNote;
  final String? dropoffCustomAddressNote;

  const CarDetailScreen({
    super.key,
    required this.car,
    this.pickupLocation,
    this.dropoffLocation,
    this.pickupDate,
    this.dropoffDate,
    this.isPickupCustomAddress = false,
    this.isDropoffCustomAddress = false,
    this.pickupCustomAddress,
    this.dropoffCustomAddress,
    this.pickupCustomAddressNote,
    this.dropoffCustomAddressNote,
  });

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final PageController _imageController = PageController();
  int _currentImageIndex = 0;
  bool _isFavorite = false;

  // Reviews data
  List<RentalReview> _reviews = [];
  RatingsSummary? _ratingsSummary;
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _mainController.forward();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final response = await Supabase.instance.client
          .from('rental_reviews')
          .select('*')
          .eq('company_id', widget.car.companyId)
          .eq('is_approved', true)
          .eq('is_hidden', false)
          .order('created_at', ascending: false)
          .limit(10);

      final reviews = (response as List)
          .map((json) => RentalReview.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _ratingsSummary = RatingsSummary.fromReviews(reviews);
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? const Color(0xFFE53935) : Colors.white,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                setState(() => _isFavorite = !_isFavorite);
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Car Image Hero Section
              SliverToBoxAdapter(
                child: _buildHeroSection(car, size, theme),
              ),

              // Car Info Section
              SliverToBoxAdapter(
                child: _buildCarInfoSection(car, theme),
              ),

              // Features Section
              SliverToBoxAdapter(
                child: _buildFeaturesSection(car, theme),
              ),

              // Specifications Section
              SliverToBoxAdapter(
                child: _buildSpecificationsSection(car, theme),
              ),

              // Reviews Section
              SliverToBoxAdapter(
                child: _buildReviewsSection(car, theme),
              ),

              // Bottom Padding for Book Button
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),

          // Bottom Book Button
          _buildBottomBookButton(car, theme),
        ],
      ),
    );
  }

  Widget _buildHeroSection(RentalCar car, Size size, ThemeData theme) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: SizedBox(
              height: size.height * 0.4,
              child: Stack(
                children: [
                  // Car Images PageView
                  PageView.builder(
                    controller: _imageController,
                    onPageChanged: (index) {
                      setState(() => _currentImageIndex = index);
                    },
                    itemCount: car.imageUrls.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        car.imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.directions_car,
                              size: 120,
                              color: Colors.grey,
                            ),
                          );
                        },
                      );
                    },
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
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                            theme.scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.3, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Premium Badge
                  if (car.isPremium)
                    Positioned(
                      top: 100,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'PREMIUM',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Image Indicators
                  if (car.imageUrls.length > 1)
                    Positioned(
                      bottom: 60,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          car.imageUrls.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImageIndex == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? theme.colorScheme.primary
                                  : Colors.grey.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
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
      },
    );
  }

  Widget _buildCarInfoSection(RentalCar car, ThemeData theme) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Model
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Company badge
                            if (car.companyName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (car.companyLogo != null && car.companyLogo!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.network(
                                              car.companyLogo!,
                                              width: 18,
                                              height: 18,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(Icons.business, size: 14,
                                                      color: theme.colorScheme.primary),
                                            ),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Icon(Icons.business, size: 14,
                                              color: theme.colorScheme.primary),
                                        ),
                                      Text(
                                        car.companyName!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Text(
                              car.brandName,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              car.model,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    car.year.toString(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(car.category)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    car.categoryName,
                                    style: TextStyle(
                                      color: _getCategoryColor(car.category),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Rating
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.star,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                car.rating.toString(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${car.reviewCount} yorum',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Specs
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickSpec(
                            Icons.speed,
                            car.transmissionName,
                            '\u015Eanz\u0131man',
                            theme,
                          ),
                          _buildVerticalDivider(),
                          _buildQuickSpec(
                            Icons.local_gas_station,
                            car.fuelTypeName,
                            'Yak\u0131t',
                            theme,
                          ),
                          _buildVerticalDivider(),
                          _buildQuickSpec(
                            Icons.event_seat,
                            '${car.seats}',
                            'Koltuk',
                            theme,
                          ),
                          _buildVerticalDivider(),
                          _buildQuickSpec(
                            Icons.luggage,
                            '${car.luggage}',
                            'Bavul',
                            theme,
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
      },
    );
  }

  Widget _buildQuickSpec(IconData icon, String value, String label, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 50,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildFeaturesSection(RentalCar car, ThemeData theme) {
    final features = CarFeature.allFeatures
        .where((f) => car.featureIds.contains(f.id))
        .toList();

    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 1.2),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u00D6zellikler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: features.map((feature) {
                      return Chip(
                        avatar: Icon(
                          _getFeatureIcon(feature.icon),
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        label: Text(
                          feature.name,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                        backgroundColor: theme.cardColor,
                        side: BorderSide(color: AppColors.borderLight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecificationsSection(RentalCar car, ThemeData theme) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 1.4),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teknik \u00D6zellikler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildSpecRow('Marka', car.brandName, theme),
                          _buildSpecDivider(),
                          _buildSpecRow('Model', car.model, theme),
                          _buildSpecDivider(),
                          _buildSpecRow('Y\u0131l', car.year.toString(), theme),
                          _buildSpecDivider(),
                          _buildSpecRow('Renk', car.color, theme),
                          _buildSpecDivider(),
                          _buildSpecRow('Kap\u0131 Say\u0131s\u0131', '${car.doors} kap\u0131', theme),
                          _buildSpecDivider(),
                          _buildSpecRow('Kilometre', '${car.mileage} km', theme),
                          _buildSpecDivider(),
                          _buildSpecRow(
                            'S\u0131n\u0131rs\u0131z Km',
                            car.hasUnlimitedMileage ? 'Evet' : 'Hay\u0131r',
                            theme,
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
      },
    );
  }

  Widget _buildSpecRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecDivider() {
    return Divider(
      color: Colors.grey.shade200,
      height: 1,
    );
  }

  Widget _buildReviewsSection(RentalCar car, ThemeData theme) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 1.6),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yorumlar & Puanlar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllReviewsScreen(
                                companyId: car.companyId,
                                companyName: car.companyName ?? 'Firma',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'T\u00FCm\u00FCn\u00FC G\u00F6r',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating summary card
                  _isLoadingReviews
                      ? _buildLoadingRatingSummary(theme)
                      : _buildRatingSummaryCard(theme),

                  // Recent reviews
                  if (!_isLoadingReviews && _reviews.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Son Yorumlar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._reviews.take(3).map((review) => _buildReviewCard(review, theme)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingRatingSummary(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildRatingSummaryCard(ThemeData theme) {
    final summary = _ratingsSummary;
    final rating = summary?.averageRating ?? widget.car.rating;
    final reviewCount = summary?.totalReviews ?? widget.car.reviewCount;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    if (rating >= starValue) {
                      return Icon(Icons.star, color: theme.colorScheme.primary, size: 16);
                    } else if (rating >= starValue - 0.5) {
                      return Icon(Icons.star_half, color: theme.colorScheme.primary, size: 16);
                    } else {
                      return Icon(Icons.star_border, color: theme.colorScheme.primary, size: 16);
                    }
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$reviewCount yorum',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  _buildRatingBar('5', summary?.getPercentage(5) ?? 0, theme),
                  _buildRatingBar('4', summary?.getPercentage(4) ?? 0, theme),
                  _buildRatingBar('3', summary?.getPercentage(3) ?? 0, theme),
                  _buildRatingBar('2', summary?.getPercentage(2) ?? 0, theme),
                  _buildRatingBar('1', summary?.getPercentage(1) ?? 0, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(RentalReview review, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: review.userAvatar != null
                      ? NetworkImage(review.userAvatar!)
                      : null,
                  child: review.userAvatar == null
                      ? Text(
                          (review.userName ?? 'A')[0].toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName ?? 'Anonim',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        review.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.overallRating ? Icons.star : Icons.star_border,
                      color: theme.colorScheme.primary,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (review.companyReply != null && review.companyReply!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Firma Yan\u0131t\u0131',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      review.companyReply!,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double percentage, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
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

  Widget _buildBottomBookButton(RentalCar car, ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Price Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (car.discountPercentage != null &&
                      car.discountPercentage! > 0)
                    Text(
                      '\u20BA${car.dailyPrice.toInt()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\u20BA${car.discountedDailyPrice.toInt()}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/g\u00FCn',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Book Button
            ElevatedButton(
              onPressed: () => _navigateToBooking(car),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\u015Eimdi Kirala',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBooking(RentalCar car) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BookingScreen(
              car: car,
              initialPickupLocation: widget.pickupLocation,
              initialDropoffLocation: widget.dropoffLocation,
              initialPickupDate: widget.pickupDate,
              initialDropoffDate: widget.dropoffDate,
              initialIsPickupCustomAddress: widget.isPickupCustomAddress,
              initialIsDropoffCustomAddress: widget.isDropoffCustomAddress,
              initialPickupCustomAddress: widget.pickupCustomAddress,
              initialDropoffCustomAddress: widget.dropoffCustomAddress,
              initialPickupCustomAddressNote: widget.pickupCustomAddressNote,
              initialDropoffCustomAddressNote: widget.dropoffCustomAddressNote,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Color _getCategoryColor(CarCategory category) {
    switch (category) {
      case CarCategory.luxury:
        return const Color(0xFF1976D2);
      case CarCategory.sports:
        return const Color(0xFFE53935);
      case CarCategory.electric:
        return const Color(0xFF4CAF50);
      case CarCategory.suv:
        return const Color(0xFF2196F3);
      default:
        return AppColors.textSecondaryLight;
    }
  }

  IconData _getFeatureIcon(String iconName) {
    switch (iconName) {
      case 'ac_unit':
        return Icons.ac_unit;
      case 'bluetooth':
        return Icons.bluetooth;
      case 'gps_fixed':
        return Icons.gps_fixed;
      case 'usb':
        return Icons.usb;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'airline_seat_legroom_extra':
        return Icons.airline_seat_legroom_extra;
      case 'camera_rear':
        return Icons.camera_rear;
      case 'local_parking':
        return Icons.local_parking;
      case 'speed':
        return Icons.speed;
      case 'hot_tub':
        return Icons.hot_tub;
      case 'phone_iphone':
        return Icons.phone_iphone;
      case 'android':
        return Icons.android;
      default:
        return Icons.check_circle;
    }
  }
}
