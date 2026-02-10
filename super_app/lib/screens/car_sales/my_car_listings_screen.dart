import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../services/car_sales_service.dart';
import '../../widgets/moderation_feedback_widget.dart';
import 'car_detail_screen.dart';
import 'add_car_listing_screen.dart';

class MyCarListingsScreen extends StatefulWidget {
  const MyCarListingsScreen({super.key});

  @override
  State<MyCarListingsScreen> createState() => _MyCarListingsScreenState();
}

class _MyCarListingsScreenState extends State<MyCarListingsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;

  List<CarListing> _activeListings = [];
  List<CarListing> _pendingListings = [];
  List<CarListing> _rejectedListings = [];
  List<CarListing> _soldListings = [];
  bool _isLoading = true;

  // İstatistikler
  int _totalViews = 0;
  int _totalFavorites = 0;
  int _totalContacts = 0;

  // Moderasyon bilgileri cache'i
  final Map<String, ModerationInfo> _moderationCache = {};

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    _loadMyListings();
  }

  Future<void> _loadMyListings() async {
    try {
      final service = CarSalesService.instance;
      final allListings = await service.getMyListings();

      if (mounted) {
        setState(() {
          _activeListings = allListings
              .where((l) => l.status == 'active')
              .map((l) => l.toCarListing())
              .toList();
          _pendingListings = allListings
              .where((l) => l.status == 'pending')
              .map((l) => l.toCarListing())
              .toList();
          _rejectedListings = allListings
              .where((l) => l.status == 'rejected')
              .map((l) => l.toCarListing())
              .toList();
          _soldListings = allListings
              .where((l) => l.status == 'sold')
              .map((l) => l.toCarListing())
              .toList();

          // İstatistikleri hesapla
          _totalViews = allListings.fold(0, (sum, l) => sum + l.viewCount);
          _totalFavorites = allListings.fold(0, (sum, l) => sum + l.favoriteCount);
          _totalContacts = 0;
          _isLoading = false;
        });
      }

      _loadModerationInfo();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadModerationInfo() async {
    final carService = CarSalesService();

    for (final listing in [..._pendingListings, ..._rejectedListings]) {
      try {
        final result = await carService.getModerationResult(listing.id);
        if (result != null && mounted) {
          setState(() {
            _moderationCache[listing.id] = ModerationInfo(
              status: ModerationStatus.fromString(result.result),
              score: result.score,
              reason: result.reason,
              flags: result.flags,
            );
          });
        }
      } catch (e) {
        // Hata durumunda sessizce devam et
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  int get _totalListings => _activeListings.length + _pendingListings.length + _rejectedListings.length + _soldListings.length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CarSalesColors.background(isDark),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              _buildStatsCards(isDark),
              _buildTabBar(isDark),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildListingsTab(_activeListings, isDark, 'active'),
                    _buildListingsTab(_pendingListings, isDark, 'pending'),
                    _buildListingsTab(_rejectedListings, isDark, 'rejected'),
                    _buildListingsTab(_soldListings, isDark, 'sold'),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(isDark),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CarSalesColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                color: CarSalesColors.textPrimary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İlanlarım',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(isDark),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_totalListings toplam ilan',
                  style: TextStyle(
                    color: CarSalesColors.textSecondary(isDark),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showOptionsMenu(isDark),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CarSalesColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.more_vert,
                color: CarSalesColors.textPrimary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              isDark,
              Icons.visibility,
              '12.5K',
              'Görüntülenme',
              CarSalesColors.primaryGradient,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              isDark,
              Icons.favorite,
              '847',
              'Favori',
              CarSalesColors.sportGradient,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              isDark,
              Icons.message,
              '156',
              'Mesaj',
              CarSalesColors.goldGradient,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    bool isDark,
    IconData icon,
    String value,
    String label,
    List<Color> gradient,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: CarSalesColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: CarSalesColors.textSecondary(isDark),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Aktif'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_activeListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bekleyen'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_pendingListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Red'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rejectedListings.isNotEmpty
                        ? CarSalesColors.accent.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_rejectedListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Satıldı'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_soldListings.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTab(List<CarListing> listings, bool isDark, String type) {
    if (listings.isEmpty) {
      return _buildEmptyState(isDark, type);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        return _buildListingCard(listings[index], isDark, type, index);
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String type) {
    String message;
    IconData icon;

    switch (type) {
      case 'active':
        message = 'Aktif ilanınız bulunmuyor';
        icon = Icons.directions_car;
        break;
      case 'pending':
        message = 'Onay bekleyen ilanınız yok';
        icon = Icons.hourglass_empty;
        break;
      case 'rejected':
        message = 'Reddedilen ilanınız yok';
        icon = Icons.cancel_outlined;
        break;
      case 'sold':
        message = 'Henüz satış yapmadınız';
        icon = Icons.sell;
        break;
      default:
        message = 'İlan bulunamadı';
        icon = Icons.inbox;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CarSalesColors.surface(isDark),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: CarSalesColors.textTertiary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: CarSalesColors.textSecondary(isDark),
              fontSize: 16,
            ),
          ),
          if (type == 'active') ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _navigateToAddListing(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: CarSalesColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'İlan Oluştur',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

  Widget _buildListingCard(CarListing car, bool isDark, String type, int index) {
    return Dismissible(
      key: Key(car.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CarSalesColors.accent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Sil',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmationDialog(car, isDark);
      },
      onDismissed: (direction) {
        _deleteListing(car, type, index);
      },
      child: GestureDetector(
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
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: car.images.first,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 160,
                        color: CarSalesColors.surface(isDark),
                        child: Icon(
                          Icons.directions_car,
                          size: 48,
                          color: CarSalesColors.textTertiary(isDark),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(type),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(type),
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getStatusLabel(type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _showListingOptions(car, isDark, type, index),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
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
                        Text(
                          car.formattedPrice,
                          style: const TextStyle(
                            color: CarSalesColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CarSalesColors.surface(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            isDark,
                            Icons.visibility,
                            '${car.viewCount}',
                            'Görüntülenme',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: CarSalesColors.border(isDark),
                          ),
                          _buildStatItem(
                            isDark,
                            Icons.favorite,
                            '${car.favoriteCount}',
                            'Favori',
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: CarSalesColors.border(isDark),
                          ),
                          _buildStatItem(
                            isDark,
                            Icons.message,
                            '${car.contactCount}',
                            'Mesaj',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: CarSalesColors.textTertiary(isDark),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              car.timeAgo,
                              style: TextStyle(
                                color: CarSalesColors.textTertiary(isDark),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildActionButton(
                              isDark,
                              Icons.edit,
                              'Düzenle',
                              () => _editListing(car),
                            ),
                            const SizedBox(width: 8),
                            if (type == 'active')
                              _buildActionButton(
                                isDark,
                                Icons.check_circle,
                                'Satıldı',
                                () => _markAsSold(car, index),
                                isPrimary: true,
                              ),
                            if (type == 'rejected')
                              _buildActionButton(
                                isDark,
                                Icons.info_outline,
                                'Detay',
                                () => _showModerationDetails(car, isDark),
                                isDestructive: true,
                              ),
                            if (type != 'active' && type != 'rejected')
                              _buildActionButton(
                                isDark,
                                Icons.delete_outline,
                                'Sil',
                                () => _confirmAndDeleteListing(car, type, index),
                                isDestructive: true,
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
    );
  }

  Widget _buildStatItem(bool isDark, IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: CarSalesColors.textSecondary(isDark)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: CarSalesColors.textPrimary(isDark),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: CarSalesColors.textTertiary(isDark),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    bool isDark,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isPrimary = false,
    bool isDestructive = false,
  }) {
    Color bgColor;
    Color textColor;

    if (isPrimary) {
      bgColor = CarSalesColors.success;
      textColor = Colors.white;
    } else if (isDestructive) {
      bgColor = CarSalesColors.accent.withValues(alpha: 0.1);
      textColor = CarSalesColors.accent;
    } else {
      bgColor = CarSalesColors.surface(isDark);
      textColor = CarSalesColors.textSecondary(isDark);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: (isPrimary || isDestructive)
              ? null
              : Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddListing,
      backgroundColor: CarSalesColors.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Yeni İlan',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String type) {
    switch (type) {
      case 'active':
        return CarSalesColors.success;
      case 'pending':
        return CarSalesColors.secondary;
      case 'rejected':
        return CarSalesColors.accent;
      case 'sold':
        return CarSalesColors.textTertiary(false);
      default:
        return CarSalesColors.primary;
    }
  }

  IconData _getStatusIcon(String type) {
    switch (type) {
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.cancel;
      case 'sold':
        return Icons.sell;
      default:
        return Icons.info;
    }
  }

  String _getStatusLabel(String type) {
    switch (type) {
      case 'active':
        return 'Aktif';
      case 'pending':
        return 'Onay Bekliyor';
      case 'rejected':
        return 'Reddedildi';
      case 'sold':
        return 'Satıldı';
      default:
        return '';
    }
  }

  void _showModerationDetails(CarListing car, bool isDark) {
    final info = _moderationCache[car.id];
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Moderasyon bilgisi yüklenemedi'),
          backgroundColor: CarSalesColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showModerationFeedbackDialog(
      context,
      info: info,
      onEditPressed: () => _editListing(car),
    );
  }

  void _navigateToDetail(CarListing car) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CarDetailScreen(car: car),
      ),
    );
  }

  void _navigateToAddListing() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddCarListingScreen(),
      ),
    );
  }

  void _editListing(CarListing car) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${car.fullName} düzenleniyor...'),
        backgroundColor: CarSalesColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    // Navigate to edit screen with car data
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddCarListingScreen(),
      ),
    );
  }

  void _markAsSold(CarListing car, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CarSalesColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CarSalesColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sell,
                color: CarSalesColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Satıldı Olarak İşaretle',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '"${car.fullName}" ilanını satıldı olarak işaretlemek istediğinize emin misiniz?\n\nBu işlem ilanı "Satıldı" sekmesine taşıyacaktır.',
          style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _activeListings.removeAt(index);
                _soldListings.insert(0, car);
              });
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(child: Text('İlan satıldı olarak işaretlendi')),
                    ],
                  ),
                  backgroundColor: CarSalesColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'Geri Al',
                    textColor: Colors.white,
                    onPressed: () {
                      setState(() {
                        _soldListings.remove(car);
                        _activeListings.insert(index.clamp(0, _activeListings.length), car);
                      });
                    },
                  ),
                ),
              );
              // Switch to sold tab
              _tabController.animateTo(2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CarSalesColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, color: Colors.white, size: 18),
            label: const Text('Onayla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(CarListing car, bool isDark) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CarSalesColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CarSalesColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever,
                color: CarSalesColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'İlanı Sil',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '"${car.fullName}" ilanını silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz!',
          style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'İptal',
              style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CarSalesColors.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete, color: Colors.white, size: 18),
            label: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _deleteListing(CarListing car, String type, int index) {
    HapticFeedback.mediumImpact();

    late List<CarListing> targetList;
    switch (type) {
      case 'active':
        targetList = _activeListings;
        break;
      case 'pending':
        targetList = _pendingListings;
        break;
      case 'sold':
        targetList = _soldListings;
        break;
    }

    setState(() {
      targetList.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('İlan silindi')),
          ],
        ),
        backgroundColor: CarSalesColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Geri Al',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              targetList.insert(index.clamp(0, targetList.length), car);
            });
          },
        ),
      ),
    );
  }

  void _confirmAndDeleteListing(CarListing car, String type, int index) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await _showDeleteConfirmationDialog(car, isDark);
    if (confirmed) {
      _deleteListing(car, type, index);
    }
  }

  void _showListingOptions(CarListing car, bool isDark, String type, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CarSalesColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CarSalesColors.border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CarSalesColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: CarSalesColors.primary),
              ),
              title: Text(
                'İlanı Düzenle',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Bilgileri güncelle',
                style: TextStyle(color: CarSalesColors.textTertiary(isDark)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _editListing(car);
              },
            ),
            if (type == 'active') ...[
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CarSalesColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sell, color: CarSalesColors.success),
                ),
                title: Text(
                  'Satıldı Olarak İşaretle',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Satıldı sekmesine taşı',
                  style: TextStyle(color: CarSalesColors.textTertiary(isDark)),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _markAsSold(car, index);
                },
              ),
            ],
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CarSalesColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.share, color: CarSalesColors.primary),
              ),
              title: Text(
                'İlanı Paylaş',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Sosyal medyada paylaş',
                style: TextStyle(color: CarSalesColors.textTertiary(isDark)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Paylaşım linki kopyalandı'),
                    backgroundColor: CarSalesColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CarSalesColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: CarSalesColors.accent),
              ),
              title: const Text(
                'İlanı Sil',
                style: TextStyle(
                  color: CarSalesColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Kalıcı olarak kaldır',
                style: TextStyle(color: CarSalesColors.textTertiary(isDark)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _confirmAndDeleteListing(car, type, index);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CarSalesColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CarSalesColors.border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.analytics, color: CarSalesColors.primary),
              title: Text(
                'İstatistikler',
                style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: CarSalesColors.primary),
              title: Text(
                'Ayarlar',
                style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.help, color: CarSalesColors.primary),
              title: Text(
                'Yardım',
                style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
