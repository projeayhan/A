import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/admin_auth_service.dart';
import '../../core/services/admin_log_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/router/app_router.dart';
import 'floating_ai_assistant.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShell({super.key, required this.child});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  bool _isCollapsed = false;

  // Collapsible menü grupları için state
  final Map<String, bool> _expandedGroups = {
    'users': true,
    'operations': false,
    'finance': false,
    'food': false,
    'rental': false,
    'emlak': false,
    'carSales': false,
    'jobs': false,
    'system': false,
  };

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(currentAdminProvider);
    final currentRoute = GoRouterState.of(context).matchedLocation;
    // Bildirim servisini başlat ve bekleyen başvuru sayısını al
    final pendingCounts = ref.watch(notificationServiceProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Ana içerik
          Row(
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

          // Floating AI Assistant
          const FloatingAIAssistant(),
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
                          'SuperCyp',
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
                // Dashboard - her zaman görünür
                _buildNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: AppRoutes.dashboard,
                  currentRoute: currentRoute,
                ),

                const SizedBox(height: 8),

                // KULLANICILAR & İŞLETMELER
                _buildNavGroup(
                  groupKey: 'users',
                  icon: Icons.people_rounded,
                  label: 'Kullanıcılar',
                  currentRoute: currentRoute,
                  badgeCount: pendingCounts.total,
                  children: [
                    _NavChild(Icons.people_outline, 'Kullanıcılar', AppRoutes.users),
                    _NavChild(Icons.store_outlined, 'İşletmeler', AppRoutes.merchants),
                    _NavChild(Icons.delivery_dining_outlined, 'Partnerler', AppRoutes.partners),
                    _NavChild(Icons.assignment_outlined, 'Başvurular', AppRoutes.applications, badgeCount: pendingCounts.total),
                  ],
                ),

                // SİPARİŞLER & OPERASYON
                _buildNavGroup(
                  groupKey: 'operations',
                  icon: Icons.receipt_long_rounded,
                  label: 'Operasyon',
                  currentRoute: currentRoute,
                  children: [
                    _NavChild(Icons.receipt_long_outlined, 'Siparişler', AppRoutes.orders),
                    _NavChild(Icons.notifications_outlined, 'Bildirimler', AppRoutes.notifications),
                    _NavChild(Icons.gavel_outlined, 'Yaptırımlar', AppRoutes.sanctions),
                  ],
                ),

                // FİNANS
                _buildNavGroup(
                  groupKey: 'finance',
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Finans',
                  currentRoute: currentRoute,
                  children: [
                    _NavChild(Icons.account_balance_wallet_outlined, 'Genel Bakış', AppRoutes.finance),
                    _NavChild(Icons.payments_outlined, 'Kazançlar', AppRoutes.earnings),
                    _NavChild(Icons.receipt_outlined, 'Faturalar', AppRoutes.invoices),
                    _NavChild(Icons.attach_money_rounded, 'Fiyatlandırma', AppRoutes.pricing),
                    _NavChild(Icons.trending_up_outlined, 'Surge Pricing', AppRoutes.surge),
                  ],
                ),

                // YEMEK & MARKET
                _buildNavGroup(
                  groupKey: 'food',
                  icon: Icons.restaurant_rounded,
                  label: 'Yemek',
                  currentRoute: currentRoute,
                  children: [
                    _NavChild(Icons.category_outlined, 'Restoran Kategorileri', AppRoutes.restaurantCategories),
                  ],
                ),

                // ARAÇ KİRALAMA
                _buildNavGroup(
                  groupKey: 'rental',
                  icon: Icons.car_rental_rounded,
                  label: 'Araç Kiralama',
                  currentRoute: currentRoute,
                  children: [
                    _NavChild(Icons.dashboard_outlined, 'Panel', AppRoutes.rentalDashboard),
                    _NavChild(Icons.directions_car_outlined, 'Araçlar', AppRoutes.rentalVehicles),
                    _NavChild(Icons.event_note_outlined, 'Rezervasyonlar', AppRoutes.rentalBookings),
                    _NavChild(Icons.location_on_outlined, 'Lokasyonlar', AppRoutes.rentalLocations),
                  ],
                ),

                // EMLAK
                _buildNavGroup(
                  groupKey: 'emlak',
                  icon: Icons.home_work_rounded,
                  label: 'Emlak',
                  currentRoute: currentRoute,
                  children: [
                    _NavChild(Icons.dashboard_outlined, 'Panel', AppRoutes.emlakDashboard),
                    _NavChild(Icons.real_estate_agent_outlined, 'İlanlar', AppRoutes.emlakListings),
                    _NavChild(Icons.location_city_outlined, 'Şehirler', AppRoutes.emlakCities),
                    _NavChild(Icons.map_outlined, 'İlçeler', AppRoutes.emlakDistricts),
                    _NavChild(Icons.category_outlined, 'Emlak Türleri', AppRoutes.emlakPropertyTypes),
                    _NavChild(Icons.featured_play_list_outlined, 'Özellikler', AppRoutes.emlakAmenities),
                    _NavChild(Icons.price_change_outlined, 'Fiyatlandırma', AppRoutes.emlakPricing),
                    _NavChild(Icons.tune_outlined, 'Ayarlar', AppRoutes.emlakSettings),
                    _NavChild(Icons.assignment_ind_outlined, 'Emlakçı Başvuruları', AppRoutes.emlakRealtorApplications),
                  ],
                ),

                // ARAÇ SATIŞ
                _buildNavGroup(
                  groupKey: 'carSales',
                  icon: Icons.directions_car_filled_rounded,
                  label: 'Araç Satış',
                  currentRoute: currentRoute,
                  badgeCount: pendingCounts.pendingCarListings,
                  children: [
                    _NavChild(Icons.dashboard_outlined, 'Panel', AppRoutes.carSalesDashboard),
                    _NavChild(Icons.list_alt_outlined, 'İlanlar', AppRoutes.carSalesListings, badgeCount: pendingCounts.pendingCarListings),
                    _NavChild(Icons.branding_watermark_outlined, 'Markalar', AppRoutes.carSalesBrands),
                    _NavChild(Icons.featured_play_list_outlined, 'Özellikler', AppRoutes.carSalesFeatures),
                    _NavChild(Icons.price_change_outlined, 'Fiyatlandırma', AppRoutes.carSalesPricing),
                    _NavChild(Icons.directions_car_outlined, 'Gövde Tipleri', AppRoutes.carSalesBodyTypes),
                    _NavChild(Icons.local_gas_station_outlined, 'Yakıt Tipleri', AppRoutes.carSalesFuelTypes),
                    _NavChild(Icons.settings_outlined, 'Vites Tipleri', AppRoutes.carSalesTransmissions),
                  ],
                ),

                // İŞ İLANLARI
                _buildNavGroup(
                  groupKey: 'jobs',
                  icon: Icons.work_rounded,
                  label: 'İş İlanları',
                  currentRoute: currentRoute,
                  children: [
                    _NavChild(Icons.dashboard_outlined, 'Panel', AppRoutes.jobListingsDashboard),
                    _NavChild(Icons.list_alt_outlined, 'İlanlar', AppRoutes.jobListingsList),
                    _NavChild(Icons.business_outlined, 'Şirketler', AppRoutes.jobCompanies),
                    _NavChild(Icons.category_outlined, 'Kategoriler', AppRoutes.jobCategories),
                    _NavChild(Icons.psychology_outlined, 'Yetenekler', AppRoutes.jobSkills),
                    _NavChild(Icons.card_giftcard_outlined, 'Yan Haklar', AppRoutes.jobBenefits),
                    _NavChild(Icons.monetization_on_outlined, 'Fiyatlandırma', AppRoutes.jobPricing),
                    _NavChild(Icons.tune_outlined, 'Ayarlar', AppRoutes.jobSettings),
                  ],
                ),

                // SİSTEM
                _buildNavGroup(
                  groupKey: 'system',
                  icon: Icons.settings_rounded,
                  label: 'Sistem',
                  currentRoute: currentRoute,
                  children: [
                    _NavChild(Icons.settings_outlined, 'Genel Ayarlar', AppRoutes.settings),
                    _NavChild(Icons.image_outlined, 'Bannerlar', AppRoutes.banners),
                    _NavChild(Icons.security_outlined, 'Güvenlik', AppRoutes.security),
                    _NavChild(Icons.history_outlined, 'Log Kayıtları', AppRoutes.logs),
                    _NavChild(Icons.monitor_heart_outlined, 'Sistem Sağlığı', AppRoutes.systemHealth),
                    _NavChild(Icons.support_agent_outlined, 'AI Destek', AppRoutes.aiSupport),
                  ],
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
            error: (_, _) => const Icon(Icons.error),
          ),
        ],
      ),
    );
  }

  // Collapsible navigation group widget
  Widget _buildNavGroup({
    required String groupKey,
    required IconData icon,
    required String label,
    required String currentRoute,
    required List<_NavChild> children,
    int badgeCount = 0,
  }) {
    final isExpanded = _expandedGroups[groupKey] ?? false;
    final hasActiveChild = children.any((child) => currentRoute == child.route);

    // Eğer aktif child varsa grubu otomatik aç
    if (hasActiveChild && !isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _expandedGroups[groupKey] = true);
      });
    }

    return Column(
      children: [
        // Group Header
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _expandedGroups[groupKey] = !isExpanded);
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: _isCollapsed ? 12 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: hasActiveChild
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: hasActiveChild
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      if (badgeCount > 0 && _isCollapsed)
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
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
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
                          color: hasActiveChild
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: hasActiveChild
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (badgeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(right: 8),
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
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: hasActiveChild
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Children (when expanded and not collapsed)
        if (isExpanded && !_isCollapsed)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: children.map((child) {
                final isSelected = currentRoute == child.route;
                return Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(child.route),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              child.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                child.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (child.badgeCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  child.badgeCount > 99
                                      ? '99+'
                                      : child.badgeCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// Navigation child item data class
class _NavChild {
  final IconData icon;
  final String label;
  final String route;
  final int badgeCount;

  const _NavChild(this.icon, this.label, this.route, {this.badgeCount = 0});
}
