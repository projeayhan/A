import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/car_models.dart';
import '../../providers/dealer_provider.dart';
import '../../services/notification_sound_service.dart';

/// Araç Satış Panel Ana Ekranı - Responsive Web Panel
class DealerPanelScreen extends ConsumerStatefulWidget {
  const DealerPanelScreen({super.key});

  @override
  ConsumerState<DealerPanelScreen> createState() => _DealerPanelScreenState();
}

class _DealerPanelScreenState extends ConsumerState<DealerPanelScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  RealtimeChannel? _listingsChannel;

  // Performans sayfası state değişkenleri
  int _selectedTimePeriod = 1; // 0: 7 gün, 1: 30 gün, 2: 90 gün
  String? _selectedListingForGraph;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _listingsChannel?.unsubscribe();
    super.dispose();
  }

  /// Supabase Realtime subscription for car_listings
  /// Automatically refreshes when listings are updated (e.g., approved by admin)
  void _setupRealtimeSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _listingsChannel = Supabase.instance.client
        .channel('car_listings_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'car_listings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // İlan güncellendiğinde provider'ları yenile
            ref.invalidate(userListingsProvider);
            ref.invalidate(listingsByStatusProvider);
            ref.invalidate(activeListingsProvider);
            ref.invalidate(pendingListingsProvider);
            ref.invalidate(soldListingsProvider);
            ref.invalidate(dashboardStatsProvider);
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isMobile ? _buildDrawer() : null,
      body: Row(
        children: [
          // Sidebar - Desktop & Tablet
          if (!isMobile)
            _buildSidebar(isCollapsed: isTablet),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(isMobile),

                // Content
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E293B),
      child: _buildSidebarContent(isCollapsed: false),
    );
  }

  Widget _buildSidebar({bool isCollapsed = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 80 : 260,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: _buildSidebarContent(isCollapsed: isCollapsed),
    );
  }

  Widget _buildSidebarContent({required bool isCollapsed}) {
    return Column(
      children: [
        // Logo Header
        Container(
          height: 70,
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 16 : 20),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white10),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: CarSalesColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Araç Satış Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Navigation Items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Text(
                      'ANA MENÜ',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard', isCollapsed),
                _buildNavItem(1, Icons.directions_car_rounded, 'İlanlarım', isCollapsed),

                const SizedBox(height: 16),
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Text(
                      'PAZARLAMA',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                _buildNavItem(2, Icons.analytics_rounded, 'Performans', isCollapsed),

                const SizedBox(height: 16),
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Text(
                      'AYARLAR',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                _buildNavItem(3, Icons.person_rounded, 'Profil', isCollapsed),
                _buildNavItem(4, Icons.settings_rounded, 'Ayarlar', isCollapsed),
              ],
            ),
          ),
        ),

        // Logout Button
        Container(
          padding: EdgeInsets.all(isCollapsed ? 12 : 16),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white10),
            ),
          ),
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 8 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    const Text(
                      'Çıkış Yap',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isCollapsed) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            NotificationSoundService.initializeAudio();
            setState(() => _selectedIndex = index);
            if (MediaQuery.of(context).size.width < 768) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? CarSalesColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: CarSalesColors.primary.withValues(alpha: 0.3)) : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isSelected ? CarSalesColors.primary : Colors.white60,
                  size: 22,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    final dealerProfile = ref.watch(dealerProfileProvider);
    final profile = dealerProfile.valueOrNull;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF1E293B)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),

          if (!isMobile)
            Text(
              _getPageTitle(),
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

          const Spacer(),

          // Yeni İlan Butonu
          _buildTopBarButton(Icons.add_circle_rounded, 'Yeni İlan', () => context.push('/add-listing')),
          const SizedBox(width: 8),

          // Bildirimler
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF64748B)),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Profil
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: CarSalesColors.primary,
                  child: Text(
                    (profile?.displayName ?? 'S')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.displayName ?? 'Satıcı',
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      profile?.city ?? '',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: CarSalesColors.primaryGradient,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard';
      case 1: return 'İlanlarım';
      case 2: return 'Performans';
      case 3: return 'Profil';
      case 4: return 'Ayarlar';
      default: return 'Dashboard';
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardContent();
      case 1: return _buildListingsContent();
      case 2: return _buildPerformanceContent();
      case 3: return _buildProfileContent();
      case 4: return _buildSettingsContent();
      default: return _buildDashboardContent();
    }
  }

  // ==================== DASHBOARD ====================
  Widget _buildDashboardContent() {
    final dashboardStats = ref.watch(dashboardStatsProvider);
    final stats = dashboardStats.valueOrNull ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: CarSalesColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hoş Geldiniz!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'İşte bugünkü özet bilgileriniz',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.white, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(
                    'Aktif İlanlar',
                    '${stats['active_listings'] ?? 0}',
                    Icons.check_circle,
                    CarSalesColors.success,
                  ),
                  _buildStatCard(
                    'Bekleyen İlanlar',
                    '${stats['pending_listings'] ?? 0}',
                    Icons.hourglass_empty,
                    CarSalesColors.secondary,
                  ),
                  _buildStatCard(
                    'Toplam Görüntülenme',
                    '${stats['total_views'] ?? 0}',
                    Icons.visibility,
                    CarSalesColors.primary,
                  ),
                  _buildStatCard(
                    'Aktif Promosyonlar',
                    '${stats['active_promotions'] ?? 0}',
                    Icons.star,
                    const Color(0xFFD97706),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Hızlı İşlemler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickAction(
                Icons.add_circle,
                'Yeni İlan',
                CarSalesColors.primary,
                () => context.push('/add-listing'),
              ),
              _buildQuickAction(
                Icons.star,
                'İlan Öne Çıkar',
                const Color(0xFFD97706),
                () => setState(() => _selectedIndex = 3),
              ),
              _buildQuickAction(
                Icons.message,
                'Mesajlar',
                CarSalesColors.success,
                () => setState(() => _selectedIndex = 2),
              ),
              _buildQuickAction(
                Icons.analytics,
                'Performans',
                const Color(0xFF8B5CF6),
                () => setState(() => _selectedIndex = 4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== İLANLARIM ====================
  Widget _buildListingsContent() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: CarSalesColors.primary,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: CarSalesColors.primary,
              tabs: const [
                Tab(text: 'Aktif'),
                Tab(text: 'Bekleyen'),
                Tab(text: 'Satıldı'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildListingsTab(CarListingStatus.active),
                _buildListingsTab(CarListingStatus.pending),
                _buildListingsTab(CarListingStatus.sold),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsTab(CarListingStatus status) {
    final listingsAsync = ref.watch(listingsByStatusProvider(status));

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz ilan yok',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/add-listing'),
                  icon: const Icon(Icons.add),
                  label: const Text('İlan Ekle'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return _buildListingCard(listing);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Widget _buildListingCard(CarListing listing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/listing/${listing.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Resim
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: listing.images.isNotEmpty
                    ? Image.network(
                        listing.images.first,
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Icon(Icons.directions_car, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.directions_car, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),

              // Bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.formattedMileage} • ${listing.fuelType.label} • ${listing.transmission.label}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          listing.formattedPrice,
                          style: const TextStyle(
                            color: CarSalesColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        // Badges
                        if (listing.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Premium',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        else if (listing.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CarSalesColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Öne Çıkan',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // İstatistikler
              Column(
                children: [
                  _buildMiniStat(Icons.visibility, '${listing.viewCount}'),
                  const SizedBox(height: 8),
                  _buildMiniStat(Icons.favorite, '${listing.favoriteCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ==================== PERFORMANS ====================

  // Dönem günlerine çevir
  int _getSelectedDays() {
    switch (_selectedTimePeriod) {
      case 0:
        return 7;
      case 1:
        return 30;
      case 2:
        return 90;
      default:
        return 30;
    }
  }

  Widget _buildPerformanceContent() {
    final days = _getSelectedDays();
    final performanceStats = ref.watch(listingPerformanceStatsProvider(days));

    return performanceStats.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Veriler yüklenirken hata oluştu: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(listingPerformanceStatsProvider(days)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final listingStatsList = (data['listings'] as List<Map<String, dynamic>>?) ?? [];
        final totals = (data['totals'] as Map<String, dynamic>?) ?? {};
        final previousTotals = (data['previousTotals'] as Map<String, dynamic>?) ?? {};

        // Toplam istatistikler
        final totalViews = (totals['views'] as int?) ?? 0;
        final totalFavorites = (totals['favorites'] as int?) ?? 0;
        final totalContacts = (totals['contacts'] as int?) ?? 0;
        final prevTotalViews = (previousTotals['views'] as int?) ?? 0;
        final prevTotalFavorites = (previousTotals['favorites'] as int?) ?? 0;
        final prevTotalContacts = (previousTotals['contacts'] as int?) ?? 0;

        // Değişim oranları hesapla
        final viewsChange = prevTotalViews > 0 ? ((totalViews - prevTotalViews) / prevTotalViews * 100) : 0.0;
        final favoritesChange = prevTotalFavorites > 0 ? ((totalFavorites - prevTotalFavorites) / prevTotalFavorites * 100) : 0.0;
        final contactsChange = prevTotalContacts > 0 ? ((totalContacts - prevTotalContacts) / prevTotalContacts * 100) : 0.0;
        final conversionRate = totalViews > 0 ? (totalContacts / totalViews * 100) : 0.0;
        final prevConversionRate = prevTotalViews > 0 ? (prevTotalContacts / prevTotalViews * 100) : 0.0;
        final conversionChange = prevConversionRate > 0 ? ((conversionRate - prevConversionRate) / prevConversionRate * 100) : 0.0;

        // En iyi 5 ve düşük performanslı ilanlar
        final topListingStats = listingStatsList.take(5).toList();
        final lowPerformingStats = listingStatsList.where((l) => (l['views'] as int? ?? 0) < 10).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zaman Filtresi
              _buildTimeFilterChips(),
              const SizedBox(height: 24),

              // Özet Kartları
              _buildPerformanceSectionTitle('Performans Özeti'),
              const SizedBox(height: 16),
              _buildPerformanceSummaryCards(
                totalViews: totalViews,
                totalFavorites: totalFavorites,
                totalContacts: totalContacts,
                conversionRate: conversionRate,
                viewsChange: viewsChange,
                favoritesChange: favoritesChange,
                contactsChange: contactsChange,
                conversionChange: conversionChange,
              ),

              const SizedBox(height: 32),

              // İlan Bazlı Performans Tablosu
              _buildPerformanceSectionTitle('İlan Bazlı Performans'),
              const SizedBox(height: 16),
              _buildListingPerformanceTable(listingStatsList),

              const SizedBox(height: 32),

              // En İyi 5 İlan
              if (topListingStats.isNotEmpty) ...[
                _buildPerformanceSectionTitle('🏆 En İyi Performans Gösteren İlanlar'),
                const SizedBox(height: 16),
                _buildTopListingsSection(topListingStats),
                const SizedBox(height: 32),
              ],

              // Düşük Performanslı İlanlar
              if (lowPerformingStats.isNotEmpty) ...[
                _buildPerformanceSectionTitle('⚠️ Dikkat Gerektiren İlanlar'),
                const SizedBox(height: 16),
                _buildLowPerformingListingsSection(lowPerformingStats),
                const SizedBox(height: 32),
              ],

              // Grafik Alanı
              if (listingStatsList.isNotEmpty) ...[
                _buildPerformanceSectionTitle('📈 Görüntülenme Trendi'),
                const SizedBox(height: 16),
                _buildViewsGraphSection(listingStatsList),
                const SizedBox(height: 32),
              ],

              // Aktif Promosyonlar Bölümü
              _buildPerformanceSectionTitle('🌟 Aktif Promosyonlar'),
              const SizedBox(height: 16),
              _buildActivePromotionsSection(),
            ],
          ),
        );
      },
    );
  }

  // Zaman Filtresi Chips
  Widget _buildTimeFilterChips() {
    final periods = ['7 Gün', '30 Gün', '3 Ay'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          const Text(
            'Dönem:',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          ...List.generate(periods.length, (index) {
            final isSelected = _selectedTimePeriod == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(periods[index]),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedTimePeriod = index);
                  }
                },
                selectedColor: CarSalesColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
              ),
            );
          }),
        ],
      ),
    );
  }

  // Bölüm Başlığı
  Widget _buildPerformanceSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
      ),
    );
  }

  // Özet Kartları
  Widget _buildPerformanceSummaryCards({
    required int totalViews,
    required int totalFavorites,
    required int totalContacts,
    required double conversionRate,
    required double viewsChange,
    required double favoritesChange,
    required double contactsChange,
    required double conversionChange,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildStatCardWithChange(
              'Toplam Görüntülenme',
              '$totalViews',
              Icons.visibility_rounded,
              const Color(0xFF3B82F6),
              viewsChange,
            ),
            _buildStatCardWithChange(
              'Favorilere Eklenme',
              '$totalFavorites',
              Icons.favorite_rounded,
              const Color(0xFFEF4444),
              favoritesChange,
            ),
            _buildStatCardWithChange(
              'İletişim Talebi',
              '$totalContacts',
              Icons.phone_rounded,
              const Color(0xFF8B5CF6),
              contactsChange,
            ),
            _buildStatCardWithChange(
              'Dönüşüm Oranı',
              '%${conversionRate.toStringAsFixed(1)}',
              Icons.trending_up_rounded,
              const Color(0xFF10B981),
              conversionChange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCardWithChange(String title, String value, IconData icon, Color color, double change) {
    final isPositive = change >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 14,
                    ),
                    Text(
                      '${change.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // İlan Bazlı Performans Tablosu
  Widget _buildListingPerformanceTable(List<Map<String, dynamic>> listingStatsList) {
    if (listingStatsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Henüz aktif ilanınız bulunmuyor',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Tablo Başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('İlan', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                Expanded(child: Text('Görüntülenme', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                Expanded(child: Text('Favori', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                Expanded(child: Text('İletişim', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                Expanded(child: Text('Dönüşüm', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                SizedBox(width: 80, child: Text('Trend', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
                SizedBox(width: 90, child: Text('İşlem', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)), textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tablo Satırları
          ...listingStatsList.take(10).map((listingStats) {
            final views = listingStats['views'] as int? ?? 0;
            final favorites = listingStats['favorites'] as int? ?? 0;
            final contacts = listingStats['contacts'] as int? ?? 0;
            final conversion = views > 0 ? (contacts / views * 100) : 0.0;
            final prevViews = listingStats['previousViews'] as int? ?? 0;
            final trend = prevViews > 0 ? ((views - prevViews) / prevViews * 100) : 0.0;

            return _buildListingTableRow(listingStats, views, favorites, contacts, conversion, trend);
          }),
        ],
      ),
    );
  }

  Widget _buildListingTableRow(Map<String, dynamic> listingStats, int views, int favorites, int contacts, double conversion, double trend) {
    final listingId = listingStats['id'] as String? ?? '';
    final images = (listingStats['images'] as List?)?.cast<String>() ?? [];
    final title = listingStats['title'] as String? ?? '';
    final brandName = listingStats['brand_name'] as String? ?? '';
    final modelName = listingStats['model_name'] as String? ?? '';
    final year = listingStats['year'] as int? ?? 0;
    final isPositiveTrend = trend >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // İlan Bilgisi
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.directions_car, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.directions_car, color: Color(0xFF94A3B8)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : '$brandName $modelName',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$brandName $modelName - $year',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Görüntülenme
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility, size: 14, color: Color(0xFF3B82F6)),
                const SizedBox(width: 4),
                Text('$views', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Favori
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Text('$favorites', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // İletişim
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, size: 14, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 4),
                Text('$contacts', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Dönüşüm
          Expanded(
            child: Text(
              '%${conversion.toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          // Mini Trend
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositiveTrend ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                    size: 14,
                    color: isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${trend.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPositiveTrend ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Öne Çıkar butonu
          SizedBox(
            width: 90,
            child: Center(
              child: TextButton(
                onPressed: () => _showPromotionModalForPerformance(listingId, title.isNotEmpty ? title : '$brandName $modelName'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text(
                  'Öne Çıkar',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // En İyi 5 İlan Bölümü
  Widget _buildTopListingsSection(List<Map<String, dynamic>> topListingStats) {
    if (topListingStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF3B82F6).withValues(alpha: 0.05), const Color(0xFF8B5CF6).withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: topListingStats.asMap().entries.map((entry) {
          final index = entry.key;
          final listingStats = entry.value;
          final listingId = listingStats['id'] as String? ?? '';
          final images = (listingStats['images'] as List?)?.cast<String>() ?? [];
          final title = listingStats['title'] as String? ?? '';
          final brandName = listingStats['brand_name'] as String? ?? '';
          final modelName = listingStats['model_name'] as String? ?? '';
          final year = listingStats['year'] as int? ?? 0;
          final views = listingStats['views'] as int? ?? 0;
          final favorites = listingStats['favorites'] as int? ?? 0;
          final contacts = listingStats['contacts'] as int? ?? 0;

          return Container(
            margin: EdgeInsets.only(bottom: index < topListingStats.length - 1 ? 12 : 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sıralama rozeti
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: index == 0
                          ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                          : index == 1
                              ? [const Color(0xFFC0C0C0), const Color(0xFF808080)]
                              : index == 2
                                  ? [const Color(0xFFCD7F32), const Color(0xFF8B4513)]
                                  : [const Color(0xFF3B82F6), const Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Resim
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.directions_car, color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.directions_car, color: Color(0xFF94A3B8)),
                        ),
                ),
                const SizedBox(width: 12),
                // Başlık
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : '$brandName $modelName',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$brandName $modelName - $year',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // İstatistikler ve Öne Çıkar butonu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildColoredMiniStat(Icons.visibility, '$views', const Color(0xFF3B82F6)),
                        const SizedBox(width: 12),
                        _buildColoredMiniStat(Icons.favorite, '$favorites', const Color(0xFFEF4444)),
                        const SizedBox(width: 12),
                        _buildColoredMiniStat(Icons.phone, '$contacts', const Color(0xFF8B5CF6)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _showPromotionModalForPerformance(listingId, title.isNotEmpty ? title : '$brandName $modelName'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: const Color(0xFFF59E0B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        'Öne Çıkar',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildColoredMiniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 12)),
      ],
    );
  }

  // Düşük Performanslı İlanlar
  Widget _buildLowPerformingListingsSection(List<Map<String, dynamic>> lowPerformingStats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Düşük Performanslı İlanlar',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                  Text(
                    'Bu ilanlar son dönemde az ilgi gördü',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...lowPerformingStats.take(3).map((listingStats) {
            final listingId = listingStats['id'] as String? ?? '';
            final images = (listingStats['images'] as List?)?.cast<String>() ?? [];
            final title = listingStats['title'] as String? ?? '';
            final brandName = listingStats['brand_name'] as String? ?? '';
            final modelName = listingStats['model_name'] as String? ?? '';
            final views = listingStats['views'] as int? ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: images.isNotEmpty
                        ? Image.network(
                            images.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(Icons.directions_car, size: 20, color: Color(0xFF94A3B8)),
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(Icons.directions_car, size: 20, color: Color(0xFF94A3B8)),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isNotEmpty ? title : '$brandName $modelName',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Sadece $views görüntülenme',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showPromotionModalForPerformance(listingId, title.isNotEmpty ? title : '$brandName $modelName'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text(
                      'Öne Çıkar',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Grafik Alanı
  Widget _buildViewsGraphSection(List<Map<String, dynamic>> listingStatsList) {
    // Seçili ilan yoksa ilk ilanı seç
    final selectedId = _selectedListingForGraph ?? (listingStatsList.isNotEmpty ? listingStatsList.first['id'] as String? : null);

    if (listingStatsList.isEmpty || selectedId == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Grafik için ilan bulunamadı',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final selectedListingStats = listingStatsList.firstWhere(
      (l) => l['id'] == selectedId,
      orElse: () => listingStatsList.first,
    );

    final images = (selectedListingStats['images'] as List?)?.cast<String>() ?? [];
    final title = selectedListingStats['title'] as String? ?? '';
    final brandName = selectedListingStats['brand_name'] as String? ?? '';
    final modelName = selectedListingStats['model_name'] as String? ?? '';
    final dailyViews = (selectedListingStats['dailyViews'] as List?)?.cast<int>() ?? List.filled(7, 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İlan Seçici
          Row(
            children: [
              const Text('İlan:', style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedId,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: listingStatsList.take(10).map((listingStats) {
                      final itemTitle = listingStats['title'] as String? ?? '';
                      final itemBrand = listingStats['brand_name'] as String? ?? '';
                      final itemModel = listingStats['model_name'] as String? ?? '';
                      return DropdownMenuItem<String>(
                        value: listingStats['id'] as String?,
                        child: Text(
                          itemTitle.isNotEmpty ? itemTitle : '$itemBrand $itemModel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedListingForGraph = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Seçili ilan bilgisi
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: images.isNotEmpty
                    ? Image.network(
                        images.first,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.directions_car, color: Color(0xFF94A3B8)),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.directions_car, color: Color(0xFF94A3B8)),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : '$brandName $modelName',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Son 7 günlük görüntülenme trendi',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Mini bar grafik
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final value = dailyViews[index];
                final maxValue = dailyViews.reduce((a, b) => a > b ? a : b);
                final height = maxValue > 0 ? (value / maxValue * 70) : 0.0;
                final date = DateTime.now().subtract(Duration(days: 6 - index));
                final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

                return SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$value',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: height.clamp(4.0, 70.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [CarSalesColors.primary, CarSalesColors.primary.withValues(alpha: 0.7)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayNames[date.weekday - 1],
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // Aktif Promosyonlar Bölümü
  Widget _buildActivePromotionsSection() {
    final activePromotions = ref.watch(activePromotionsProvider);

    return activePromotions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Promosyonlar yüklenemedi'),
      data: (promotions) {
        if (promotions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.rocket_launch, size: 48, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'İlanlarınızı Öne Çıkarın!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Promosyon ile ilanlarınız 5x daha fazla görüntülenir',
                  style: TextStyle(color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  icon: const Icon(Icons.star, size: 18),
                  label: const Text('Hemen Başla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: promotions.map((promo) => _buildModernPromotionCard(promo)).toList(),
        );
      },
    );
  }

  Widget _buildModernPromotionCard(CarListingPromotion promo) {
    final listing = promo.listing;
    final isPremium = promo.promotionType == 'premium';
    final daysLeft = promo.expiresAt.difference(DateTime.now()).inDays;
    final hoursLeft = promo.expiresAt.difference(DateTime.now()).inHours % 24;
    final totalDays = promo.durationDays;
    final progressPercent = ((totalDays - daysLeft) / totalDays).clamp(0.0, 1.0);

    // İstatistik hesaplamaları
    final viewsBefore = promo.viewsBefore;
    final viewsDuring = promo.viewsDuring;
    final contactsBefore = promo.contactsBefore;
    final contactsDuring = promo.contactsDuring;

    double viewsChange = 0;
    double contactsChange = 0;

    if (viewsBefore > 0) {
      viewsChange = ((viewsDuring - viewsBefore) / viewsBefore) * 100;
    } else if (viewsDuring > 0) {
      viewsChange = 100;
    }

    if (contactsBefore > 0) {
      contactsChange = ((contactsDuring - contactsBefore) / contactsBefore) * 100;
    } else if (contactsDuring > 0) {
      contactsChange = 100;
    }

    // Renkler
    final gradientColors = isPremium
        ? [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]
        : [const Color(0xFFF59E0B), const Color(0xFFD97706)];

    final badgeColor = isPremium ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B);
    final badgeText = isPremium ? 'PREMIUM' : 'ÖNE ÇIKAN';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header - Gradient Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPremium ? Icons.diamond : Icons.star,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Kalan süre
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: daysLeft <= 2
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        daysLeft > 0 ? '$daysLeft gün $hoursLeft saat' : '$hoursLeft saat kaldı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress Bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: ((1 - progressPercent) * 100).toInt().clamp(1, 100),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                    ),
                  ),
                ),
                if (progressPercent < 1)
                  Expanded(
                    flex: (progressPercent * 100).toInt().clamp(0, 99),
                    child: const SizedBox(),
                  ),
              ],
            ),
          ),

          // İlan Bilgisi
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Araç Resmi
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 80,
                    height: 60,
                    color: const Color(0xFFF1F5F9),
                    child: listing?.images.isNotEmpty == true
                        ? Image.network(
                            listing!.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car,
                              color: Color(0xFF94A3B8),
                            ),
                          )
                        : const Icon(
                            Icons.directions_car,
                            color: Color(0xFF94A3B8),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // İlan Detayı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing?.title ?? 'İlan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (listing != null)
                        Text(
                          '${listing.year} • ${_formatPrice(listing.price)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // İstatistikler
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Görüntülenme
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.visibility_outlined,
                    label: 'Görüntülenme',
                    before: viewsBefore,
                    during: viewsDuring,
                    change: viewsChange,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFFE2E8F0),
                ),
                // İletişim
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.phone_outlined,
                    label: 'İletişim',
                    before: contactsBefore,
                    during: contactsDuring,
                    change: contactsChange,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),

          // Aksiyon Butonları
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // İlanı Gör
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // İlan detayına git
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('İlanı Gör'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Süre Uzat
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Süre uzatma modalı
                      if (listing != null) {
                        _showPromotionModalForPerformance(listing.id, listing.title);
                      }
                    },
                    icon: Icon(Icons.add_circle_outline, size: 16, color: badgeColor),
                    label: Text('Uzat', style: TextStyle(color: badgeColor)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: badgeColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // İptal
                SizedBox(
                  width: 44,
                  child: IconButton(
                    onPressed: () => _showCancelPromotionDialog(promo),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      foregroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    tooltip: 'İptal Et',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required int before,
    required int during,
    required double change,
    required Color color,
  }) {
    final isPositive = change >= 0;
    final changeColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$before',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 12, color: Color(0xFF94A3B8)),
            ),
            Text(
              '$during',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: changeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 12,
                color: changeColor,
              ),
              const SizedBox(width: 2),
              Text(
                '${isPositive ? '+' : ''}${change.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: changeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCancelPromotionDialog(CarListingPromotion promo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Promosyonu İptal Et'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu promosyonu iptal etmek istediğinize emin misiniz?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'İptal edilen promosyonlar için iade yapılmaz.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(dealerServiceProvider).cancelPromotion(promo.id);
                ref.invalidate(activePromotionsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Promosyon iptal edildi'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M ₺';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K ₺';
    }
    return '${price.toStringAsFixed(0)} ₺';
  }

  // Promosyon modal - Performans sayfası için
  Future<void> _showPromotionModalForPerformance(String listingId, String listingTitle) async {
    // Önce loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fiyatları çek
      final prices = await ref.read(promotionPricesProvider.future);

      if (!mounted) return;
      Navigator.pop(context); // Loading'i kapat

      final featured = prices.where((p) => p.promotionType == 'featured').toList();
      final premium = prices.where((p) => p.promotionType == 'premium').toList();

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'İlanı Öne Çıkar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              listingTitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Öne Çıkarma Paketleri
                        const Text(
                          '⭐ Öne Çıkarma',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'İlanınız arama sonuçlarında üst sıralarda görünür',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        if (featured.isEmpty)
                          const Text('Paket bulunamadı', style: TextStyle(color: Color(0xFF94A3B8)))
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: featured.map((price) => _buildPromotionOption(
                              price,
                              CarSalesColors.primary,
                              listingId,
                            )).toList(),
                          ),

                        const SizedBox(height: 24),

                        // Premium Paketleri
                        const Text(
                          '👑 Premium',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'İlanınız altın çerçeve ile öne çıkar ve en üstte görünür',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        if (premium.isEmpty)
                          const Text('Paket bulunamadı', style: TextStyle(color: Color(0xFF94A3B8)))
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: premium.map((price) => _buildPromotionOption(
                              price,
                              const Color(0xFFD97706),
                              listingId,
                            )).toList(),
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
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Loading'i kapat

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Promosyon fiyatları yüklenemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPromotionOption(PromotionPrice price, Color color, String listingId) {
    return InkWell(
      onTap: () => _purchasePromotion(listingId, price),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '${price.durationDays} Gün',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            if (price.hasDiscount)
              Text(
                '${price.price.toStringAsFixed(0)} TL',
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            Text(
              price.formattedPrice,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Seç',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchasePromotion(String listingId, PromotionPrice price) async {
    Navigator.pop(context); // Modal'ı kapat

    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Promosyon Satın Al'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${price.promotionType == 'premium' ? 'Premium' : 'Öne Çıkarma'} - ${price.durationDays} Gün',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Fiyat: ${price.formattedPrice}',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu promosyonu satın almak istediğinize emin misiniz?',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
            ),
            child: const Text('Satın Al'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Promosyon satın al
        await ref.read(dealerServiceProvider).createPromotion(
          listingId: listingId,
          promotionType: price.promotionType,
          durationDays: price.durationDays,
          amountPaid: price.discountedPrice,
        );

        if (mounted) {
          Navigator.pop(context); // Loading'i kapat

          // Başarı mesajı
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${price.promotionType == 'premium' ? 'Premium' : 'Öne Çıkarma'} promosyonu başarıyla aktifleştirildi!',
                    ),
                  ),
                ],
              ),
              backgroundColor: CarSalesColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );

          // Provider'ları yenile
          ref.invalidate(activePromotionsProvider);
          ref.invalidate(listingPerformanceStatsProvider(_getSelectedDays()));
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Loading'i kapat

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ==================== PROFİL ====================
  Widget _buildProfileContent() {
    final dealerProfile = ref.watch(dealerProfileProvider);

    return dealerProfile.when(
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('Profil bulunamadı'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Profil Kartı
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: CarSalesColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        profile.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: CarSalesColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.dealerType.label,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    if (profile.isVerified) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: CarSalesColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: CarSalesColors.success, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Doğrulanmış',
                              style: TextStyle(
                                color: CarSalesColors.success,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildProfileStat('İlan', '${profile.totalListings}'),
                        _buildProfileStat('Satış', '${profile.totalSold}'),
                        _buildProfileStat('Puan', profile.averageRating.toStringAsFixed(1)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: CarSalesColors.primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ==================== AYARLAR ====================
  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ayarlar',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildSettingsSection('Hesap', [
            _buildSettingsTile(Icons.person, 'Profil Bilgileri', () {}),
            _buildSettingsTile(Icons.lock, 'Şifre Değiştir', () {}),
            _buildSettingsTile(Icons.notifications, 'Bildirim Ayarları', () {}),
          ]),
          const SizedBox(height: 16),
          _buildSettingsSection('Destek', [
            _buildSettingsTile(Icons.help, 'Yardım Merkezi', () {}),
            _buildSettingsTile(Icons.chat, 'Bize Ulaşın', () {}),
            _buildSettingsTile(Icons.info, 'Hakkında', () {}),
          ]),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: CarSalesColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  // ==================== LOGOUT ====================
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }
}
