import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/rental/rental_models.dart';
import 'booking_screen.dart';
import 'all_reviews_screen.dart';

class CarDetailScreen extends StatefulWidget {
  final RentalCar car;
  final RentalLocation? pickupLocation;
  final RentalLocation? dropoffLocation;
  final DateTime? pickupDate;
  final DateTime? dropoffDate;
  // Özel adres bilgileri
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
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final PageController _imageController = PageController();
  int _currentImageIndex = 0;
  bool _isFavorite = false;

  // Reviews data
  List<RentalReview> _reviews = [];
  RatingsSummary? _ratingsSummary;
  bool _isLoadingReviews = true;

  // Light theme colors
  static const Color _primaryBlue = Color(0xFF1976D2);
  static const Color _backgroundColor = Color(0xFFF5F5F5);
  static const Color _cardColor = Colors.white;
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final response = await Supabase.instance.client
          .from('rental_reviews')
          .select('*, profiles:user_id(full_name, avatar_url)')
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
    _pulseController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Car Image Hero Section
              SliverToBoxAdapter(
                child: _buildHeroSection(car, size),
              ),

              // Car Info Section
              SliverToBoxAdapter(
                child: _buildCarInfoSection(car),
              ),

              // Features Section
              SliverToBoxAdapter(
                child: _buildFeaturesSection(car),
              ),

              // Specifications Section
              SliverToBoxAdapter(
                child: _buildSpecificationsSection(car),
              ),

              // Reviews Section
              SliverToBoxAdapter(
                child: _buildReviewsSection(car),
              ),

              // Bottom Padding for Book Button
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),

          // Top Navigation
          _buildTopNavigation(),

          // Bottom Book Button
          _buildBottomBookButton(car),
        ],
      ),
    );
  }

  Widget _buildHeroSection(RentalCar car, Size size) {
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
                      return AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Image.network(
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
                            _backgroundColor.withValues(alpha: 0.8),
                            _backgroundColor,
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: 0.4),
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
                                  ? _primaryBlue
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

  Widget _buildCarInfoSection(RentalCar car) {
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
                            Text(
                              car.brandName,
                              style: TextStyle(
                                fontSize: 14,
                                color: _textSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              car.model,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
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
                                      color: _textSecondary,
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.star,
                              color: _primaryBlue,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              car.rating.toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              '${car.reviewCount} yorum',
                              style: TextStyle(
                                fontSize: 10,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Specs
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickSpec(
                          Icons.speed,
                          car.transmissionName,
                          'Şanzıman',
                        ),
                        _buildVerticalDivider(),
                        _buildQuickSpec(
                          Icons.local_gas_station,
                          car.fuelTypeName,
                          'Yakıt',
                        ),
                        _buildVerticalDivider(),
                        _buildQuickSpec(
                          Icons.event_seat,
                          '${car.seats}',
                          'Koltuk',
                        ),
                        _buildVerticalDivider(),
                        _buildQuickSpec(
                          Icons.luggage,
                          '${car.luggage}',
                          'Bavul',
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

  Widget _buildQuickSpec(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: _primaryBlue, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: _textSecondary,
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

  Widget _buildFeaturesSection(RentalCar car) {
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
                  const Text(
                    'Özellikler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: features.map((feature) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getFeatureIcon(feature.icon),
                              color: _primaryBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              feature.name,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildSpecificationsSection(RentalCar car) {
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
                  const Text(
                    'Teknik Özellikler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildSpecRow('Marka', car.brandName),
                        _buildSpecDivider(),
                        _buildSpecRow('Model', car.model),
                        _buildSpecDivider(),
                        _buildSpecRow('Yıl', car.year.toString()),
                        _buildSpecDivider(),
                        _buildSpecRow('Renk', car.color),
                        _buildSpecDivider(),
                        _buildSpecRow('Kapı Sayısı', '${car.doors} kapı'),
                        _buildSpecDivider(),
                        _buildSpecRow('Kilometre', '${car.mileage} km'),
                        _buildSpecDivider(),
                        _buildSpecRow(
                          'Sınırsız Km',
                          car.hasUnlimitedMileage ? 'Evet' : 'Hayır',
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

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
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

  Widget _buildReviewsSection(RentalCar car) {
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
                      const Text(
                        'Yorumlar & Puanlar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
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
                        child: const Text(
                          'Tümünü Gör',
                          style: TextStyle(
                            color: _primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating summary card
                  _isLoadingReviews
                      ? _buildLoadingRatingSummary()
                      : _buildRatingSummaryCard(),

                  // Recent reviews
                  if (!_isLoadingReviews && _reviews.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Son Yorumlar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._reviews.take(3).map((review) => _buildReviewCard(review)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingRatingSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(color: _primaryBlue),
      ),
    );
  }

  Widget _buildRatingSummaryCard() {
    final summary = _ratingsSummary;
    final rating = summary?.averageRating ?? widget.car.rating;
    final reviewCount = summary?.totalReviews ?? widget.car.reviewCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  if (rating >= starValue) {
                    return const Icon(Icons.star, color: _primaryBlue, size: 16);
                  } else if (rating >= starValue - 0.5) {
                    return const Icon(Icons.star_half, color: _primaryBlue, size: 16);
                  } else {
                    return const Icon(Icons.star_border, color: _primaryBlue, size: 16);
                  }
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$reviewCount yorum',
                style: TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _buildRatingBar('5', summary?.getPercentage(5) ?? 0),
                _buildRatingBar('4', summary?.getPercentage(4) ?? 0),
                _buildRatingBar('3', summary?.getPercentage(3) ?? 0),
                _buildRatingBar('2', summary?.getPercentage(2) ?? 0),
                _buildRatingBar('1', summary?.getPercentage(1) ?? 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(RentalReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                backgroundImage: review.userAvatar != null
                    ? NetworkImage(review.userAvatar!)
                    : null,
                child: review.userAvatar == null
                    ? Text(
                        (review.userName ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(
                          color: _primaryBlue,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      review.timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.overallRating ? Icons.star : Icons.star_border,
                    color: _primaryBlue,
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
                color: _textSecondary,
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
                color: _primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, size: 16, color: _primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Firma Yanıtı',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.companyReply!,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textSecondary,
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

  Widget _buildRatingBar(String label, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondary,
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
                    color: _primaryBlue,
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

  Widget _buildTopNavigation() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavButton(
              Icons.arrow_back_ios_new,
              () => Navigator.pop(context),
            ),
            Row(
              children: [
                _buildNavButton(Icons.share, () {}),
                const SizedBox(width: 8),
                _buildNavButton(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  () {
                    setState(() => _isFavorite = !_isFavorite);
                  },
                  isActive: _isFavorite,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap,
      {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFFE53935) : Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildBottomBookButton(RentalCar car) {
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
          color: _cardColor,
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
                      '₺${car.dailyPrice.toInt()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₺${car.discountedDailyPrice.toInt()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/gün',
                          style: TextStyle(
                            fontSize: 14,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Book Button
            GestureDetector(
              onTap: () => _navigateToBooking(car),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryBlue.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text(
                      'Şimdi Kirala',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
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
        return _textSecondary;
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
