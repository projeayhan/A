import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/admin_auth_service.dart';
import '../../core/services/admin_log_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/router/app_router.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(currentAdminProvider);
    final currentRoute = GoRouterState.of(context).matchedLocation;
    // Bildirim servisini başlat ve bekleyen başvuru sayısını al
    final pendingCounts = ref.watch(notificationServiceProvider);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isCollapsed ? 80 : 280,
            child: _buildSidebar(currentRoute, adminAsync, pendingCounts),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(adminAsync),

                // Content
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(String currentRoute, AsyncValue<AdminUser?> adminAsync, PendingApplicationCounts pendingCounts) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.surfaceLight, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 72,
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 16 : 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OdaBase',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(color: AppColors.surfaceLight, height: 1),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: AppRoutes.dashboard,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.people_rounded,
                  label: 'Kullanıcılar',
                  route: AppRoutes.users,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.store_rounded,
                  label: 'İşletmeler',
                  route: AppRoutes.merchants,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.delivery_dining_rounded,
                  label: 'Partnerler',
                  route: AppRoutes.partners,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.assignment_rounded,
                  label: 'Basvurular',
                  route: AppRoutes.applications,
                  currentRoute: currentRoute,
                  badgeCount: pendingCounts.total,
                ),
                _buildNavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Siparişler',
                  route: AppRoutes.orders,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Finans',
                  route: AppRoutes.finance,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.notifications_active_rounded,
                  label: 'Bildirimler',
                  route: AppRoutes.notifications,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.gavel_rounded,
                  label: 'Yaptırımlar',
                  route: AppRoutes.sanctions,
                  currentRoute: currentRoute,
                ),

                // YONETIM Section
                if (!_isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                    child: Text(
                      'YONETIM',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                _buildNavItem(
                  icon: Icons.attach_money_rounded,
                  label: 'Fiyatlandirma',
                  route: AppRoutes.pricing,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.image_rounded,
                  label: 'Bannerlar',
                  route: AppRoutes.banners,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.receipt_rounded,
                  label: 'Faturalar',
                  route: AppRoutes.invoices,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.trending_up_rounded,
                  label: 'Surge Pricing',
                  route: AppRoutes.surge,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.payments_rounded,
                  label: 'Kazanclar',
                  route: AppRoutes.earnings,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.history_rounded,
                  label: 'Log Kayıtları',
                  route: AppRoutes.logs,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.security_rounded,
                  label: 'Güvenlik',
                  route: AppRoutes.security,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.monitor_heart_rounded,
                  label: 'Sistem Sağlığı',
                  route: AppRoutes.systemHealth,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.support_agent_rounded,
                  label: 'AI Destek',
                  route: AppRoutes.aiSupport,
                  currentRoute: currentRoute,
                ),

                // ARAÇ KİRALAMA Section
                if (!_isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                    child: Text(
                      'ARAÇ KİRALAMA',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                _buildNavItem(
                  icon: Icons.car_rental_rounded,
                  label: 'Kiralama Paneli',
                  route: AppRoutes.rentalDashboard,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.directions_car_rounded,
                  label: 'Araçlar',
                  route: AppRoutes.rentalVehicles,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.event_note_rounded,
                  label: 'Rezervasyonlar',
                  route: AppRoutes.rentalBookings,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.location_on_rounded,
                  label: 'Lokasyonlar',
                  route: AppRoutes.rentalLocations,
                  currentRoute: currentRoute,
                ),

                // EMLAK Section
                if (!_isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                    child: Text(
                      'EMLAK',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                _buildNavItem(
                  icon: Icons.home_work_rounded,
                  label: 'Emlak Paneli',
                  route: AppRoutes.emlakDashboard,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.location_city_rounded,
                  label: 'Şehirler',
                  route: AppRoutes.emlakCities,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.map_rounded,
                  label: 'İlçeler',
                  route: AppRoutes.emlakDistricts,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.real_estate_agent_rounded,
                  label: 'İlanlar',
                  route: AppRoutes.emlakListings,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.category_rounded,
                  label: 'Emlak Türleri',
                  route: AppRoutes.emlakPropertyTypes,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.featured_play_list_rounded,
                  label: 'Özellikler',
                  route: AppRoutes.emlakAmenities,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.price_change_rounded,
                  label: 'Fiyatlandırma',
                  route: AppRoutes.emlakPricing,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.tune_rounded,
                  label: 'Emlak Ayarları',
                  route: AppRoutes.emlakSettings,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.assignment_ind_rounded,
                  label: 'Emlakçı Başvuruları',
                  route: AppRoutes.emlakRealtorApplications,
                  currentRoute: currentRoute,
                ),

                // ARAÇ SATIŞ Section
                if (!_isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                    child: Text(
                      'ARAÇ SATIŞ',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                _buildNavItem(
                  icon: Icons.directions_car_filled_rounded,
                  label: 'Araç Satış Paneli',
                  route: AppRoutes.carSalesDashboard,
                  currentRoute: currentRoute,
                  badgeCount: pendingCounts.pendingCarListings,
                ),
                _buildNavItem(
                  icon: Icons.list_alt_rounded,
                  label: 'Araç İlanları',
                  route: AppRoutes.carSalesListings,
                  currentRoute: currentRoute,
                  badgeCount: pendingCounts.pendingCarListings,
                ),
                _buildNavItem(
                  icon: Icons.branding_watermark_rounded,
                  label: 'Markalar',
                  route: AppRoutes.carSalesBrands,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.featured_play_list_rounded,
                  label: 'Araç Özellikleri',
                  route: AppRoutes.carSalesFeatures,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.price_change_rounded,
                  label: 'Öne Çıkarma Fiyatları',
                  route: AppRoutes.carSalesPricing,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.directions_car_outlined,
                  label: 'Gövde Tipleri',
                  route: AppRoutes.carSalesBodyTypes,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.local_gas_station_rounded,
                  label: 'Yakıt Tipleri',
                  route: AppRoutes.carSalesFuelTypes,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Vites Tipleri',
                  route: AppRoutes.carSalesTransmissions,
                  currentRoute: currentRoute,
                ),

                // İŞ İLANLARI Section
                if (!_isCollapsed)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                    child: Text(
                      'İŞ İLANLARI',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),

                _buildNavItem(
                  icon: Icons.work_rounded,
                  label: 'İş İlanları Paneli',
                  route: AppRoutes.jobListingsDashboard,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.category_rounded,
                  label: 'Kategoriler',
                  route: AppRoutes.jobCategories,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.psychology_rounded,
                  label: 'Yetenekler',
                  route: AppRoutes.jobSkills,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Yan Haklar',
                  route: AppRoutes.jobBenefits,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.list_alt_rounded,
                  label: 'İlanlar',
                  route: AppRoutes.jobListingsList,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.business_rounded,
                  label: 'Şirketler',
                  route: AppRoutes.jobCompanies,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.monetization_on_rounded,
                  label: 'Fiyatlandırma',
                  route: AppRoutes.jobPricing,
                  currentRoute: currentRoute,
                ),
                _buildNavItem(
                  icon: Icons.tune_rounded,
                  label: 'Ayarlar',
                  route: AppRoutes.jobSettings,
                  currentRoute: currentRoute,
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: AppColors.surfaceLight),
                ),

                _buildNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Genel Ayarlar',
                  route: AppRoutes.settings,
                  currentRoute: currentRoute,
                ),
              ],
            ),
          ),

          // Collapse Button
          Container(
            padding: const EdgeInsets.all(12),
            child: IconButton(
              onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              icon: Icon(
                _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: AppColors.textSecondary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _audioInitialized = false;

  void _initAudioOnFirstClick() {
    if (!_audioInitialized) {
      _audioInitialized = true;
      // Sessizce AudioContext'i başlat
      try {
        ref.read(notificationServiceProvider.notifier).playNotificationSound();
      } catch (e) {
        // Sessizce devam et
      }
    }
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String route,
    required String currentRoute,
    int badgeCount = 0,
  }) {
    final isSelected = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _initAudioOnFirstClick();
            context.go(route);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 12 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                // Icon with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Badge on the right side when not collapsed
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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

  Widget _buildTopBar(AsyncValue<AdminUser?> adminAsync) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Ara...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Notifications - tıklandığında ses testi yapar
          IconButton(
            onPressed: () {
              final notificationService = ref.read(notificationServiceProvider.notifier);
              notificationService.playNotificationSound();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirim sesi aktif edildi'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: Badge(
              smallSize: 8,
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            tooltip: 'Bildirim sesini test et',
          ),

          const SizedBox(width: 12),

          // Profile
          adminAsync.when(
            data: (admin) => PopupMenuButton<String>(
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        admin?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin?.fullName ?? 'Admin',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          admin?.roleDisplayName ?? 'Yönetici',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Profil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Ayarlar'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: AppColors.error),
                      SizedBox(width: 12),
                      Text(
                        'Çıkış Yap',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'logout') {
                  // Log logout before signing out
                  final logService = ref.read(adminLogServiceProvider);
                  await logService.logLogout();

                  final authService = ref.read(adminAuthServiceProvider);
                  await authService.signOut();
                  ref.read(currentAdminProvider.notifier).clear();
                  if (mounted) {
                    context.go(AppRoutes.login);
                  }
                } else if (value == 'settings') {
                  context.go(AppRoutes.settings);
                }
              },
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Icon(Icons.error),
          ),
        ],
      ),
    );
  }
}
