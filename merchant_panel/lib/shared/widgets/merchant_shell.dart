import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;

import '../../core/theme/app_theme.dart';
import '../../core/models/merchant_models.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_sound_service.dart';
import '../../core/utils/app_dialogs.dart';
import '../screens/couriers_screen.dart';
import 'floating_ai_assistant.dart';

class MerchantShell extends ConsumerStatefulWidget {
  final Widget child;

  const MerchantShell({super.key, required this.child});

  @override
  ConsumerState<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends ConsumerState<MerchantShell> {
  bool _isExpanded = true;
  int _lastNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    // Load merchant data after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantData();
    });
  }

  Future<void> _loadMerchantData() async {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref
          .read(currentMerchantProvider.notifier)
          .loadMerchantByUserId(user.id);
    }
  }

  Future<void> _logout() async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.auth.signOut();
    ref.read(currentMerchantProvider.notifier).clear();
    if (mounted) {
      context.go('/auth/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchant = ref.watch(currentMerchantProvider);
    final pendingOrdersCount = ref.watch(pendingOrdersProvider).length;
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);
    final notifications = ref.watch(notificationsProvider);
    final courierRequests = ref.watch(courierRequestsProvider);
    final pendingCourierRequests = courierRequests.valueOrNull?.length ?? 0;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    // Route guard: Restoran/Mağaza tipine göre yanlış sayfalara erişimi engelle
    final merchantData = merchant.valueOrNull;
    if (merchantData != null) {
      final isRestaurant = merchantData.type == MerchantType.restaurant;

      // Restoran kullanıcısı mağaza sayfalarına giremez
      if (isRestaurant && (currentRoute == '/products' || currentRoute == '/inventory' || currentRoute == '/categories')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/');
        });
      }

      // Mağaza kullanıcısı restoran sayfalarına giremez
      if (!isRestaurant && currentRoute == '/menu') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/');
        });
      }
    }

    // Check for new cancelled order notifications and show snackbar
    if (notifications.isNotEmpty && notifications.length > _lastNotificationCount) {
      final latestNotification = notifications.first;
      if (latestNotification.type == 'order_cancelled' && !latestNotification.isRead) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            AppDialogs.showError(
              context,
              '${latestNotification.title}\n${latestNotification.message}',
            );
          }
        });
      }
    }
    _lastNotificationCount = notifications.length;

    // Determine merchant type for conditional menu items
    final merchantType = merchant.valueOrNull?.type ?? MerchantType.restaurant;
    final isRestaurant = merchantType == MerchantType.restaurant;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ana içerik
          Row(
            children: [
              // Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isExpanded ? 260 : 72,
                child: _buildSidebar(
                  context,
                  currentRoute,
                  isRestaurant,
                  pendingOrdersCount,
                  unreadNotifications,
                  pendingCourierRequests,
                  merchant.valueOrNull,
                ),
              ),

              // Main Content
              Expanded(
                child: Column(
                  children: [
                    // Top Bar
                    _buildTopBar(
                      context,
                      merchant.valueOrNull,
                      unreadNotifications,
                    ),

                    // Content
                    Expanded(child: widget.child),
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

  Widget _buildSidebar(
    BuildContext context,
    String currentRoute,
    bool isRestaurant,
    int pendingOrders,
    int notifications,
    int pendingCourierRequests,
    Merchant? merchant,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 72,
            padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 20 : 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient:
                        isRestaurant
                            ? AppColors.restaurantGradient
                            : AppColors.storeGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isRestaurant ? Icons.restaurant : Icons.store,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant?.businessName ?? 'Isletme',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isRestaurant ? 'Restoran' : 'Magaza',
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
          const Divider(height: 1),

          // Toggle Button
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              icon: Icon(
                _isExpanded ? Icons.chevron_left : Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Siparisler',
                  route: '/orders',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                  badge: pendingOrders > 0 ? pendingOrders : null,
                ),

                // Restaurant specific
                if (isRestaurant) ...[
                  _NavItem(
                    icon: Icons.restaurant_menu_outlined,
                    activeIcon: Icons.restaurant_menu,
                    label: 'Menu',
                    route: '/menu',
                    currentRoute: currentRoute,
                    isExpanded: _isExpanded,
                  ),
                ],

                // Store specific
                if (!isRestaurant) ...[
                  _NavItem(
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2,
                    label: 'Urunler',
                    route: '/products',
                    currentRoute: currentRoute,
                    isExpanded: _isExpanded,
                  ),
                  _NavItem(
                    icon: Icons.warehouse_outlined,
                    activeIcon: Icons.warehouse,
                    label: 'Stok',
                    route: '/inventory',
                    currentRoute: currentRoute,
                    isExpanded: _isExpanded,
                  ),
                  _NavItem(
                    icon: Icons.category_outlined,
                    activeIcon: Icons.category,
                    label: 'Kategoriler',
                    route: '/categories',
                    currentRoute: currentRoute,
                    isExpanded: _isExpanded,
                  ),
                ],

                const SizedBox(height: 8),
                if (_isExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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

                _NavItem(
                  icon: Icons.star_outline,
                  activeIcon: Icons.star,
                  label: 'Yorumlar',
                  route: '/reviews',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet,
                  label: 'Finans',
                  route: '/finance',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                ),
                _NavItem(
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics,
                  label: 'Raporlar',
                  route: '/reports',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                ),
                _NavItem(
                  icon: Icons.delivery_dining_outlined,
                  activeIcon: Icons.delivery_dining,
                  label: 'Kuryeler',
                  route: '/couriers',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                  badge: pendingCourierRequests > 0 ? pendingCourierRequests : null,
                ),
                _NavItem(
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Bildirimler',
                  route: '/notifications',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                  badge: notifications > 0 ? notifications : null,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Ayarlar',
                  route: '/settings',
                  currentRoute: currentRoute,
                  isExpanded: _isExpanded,
                ),
              ],
            ),
          ),

          // Online Status
          Container(
            margin: const EdgeInsets.all(12),
            padding: EdgeInsets.all(_isExpanded ? 12 : 8),
            decoration: BoxDecoration(
              color:
                  merchant?.isOpen == true
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    merchant?.isOpen == true
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  _isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color:
                        merchant?.isOpen == true
                            ? AppColors.success
                            : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      merchant?.isOpen == true ? 'Acik' : 'Kapali',
                      style: TextStyle(
                        color:
                            merchant?.isOpen == true
                                ? AppColors.success
                                : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: merchant?.isOpen ?? false,
                    onChanged: (value) {
                      ref
                          .read(currentMerchantProvider.notifier)
                          .toggleOnlineStatus();
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    Merchant? merchant,
    int notifications,
  ) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Page Title (from route)
          Text(
            _getPageTitle(GoRouterState.of(context).matchedLocation),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Spacer(),

          // Search
          SizedBox(
            width: 300,
            height: 40,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Notifications
          IconButton(
            onPressed: () => context.go('/notifications'),
            icon: badges.Badge(
              showBadge: notifications > 0,
              badgeContent: Text(
                notifications.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 8),

          // Profile
          PopupMenuButton(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  backgroundImage:
                      merchant?.logoUrl != null
                          ? NetworkImage(merchant!.logoUrl!)
                          : null,
                  child:
                      merchant?.logoUrl == null
                          ? Text(
                            merchant?.businessName
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                'M',
                            style: const TextStyle(color: Colors.white),
                          )
                          : null,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
            itemBuilder:
                (context) => <PopupMenuEntry<dynamic>>[
                  PopupMenuItem(
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20),
                        const SizedBox(width: 12),
                        const Text('Profil'),
                      ],
                    ),
                    onTap: () => context.go('/settings'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: AppColors.error),
                        const SizedBox(width: 12),
                        Text(
                          'Cikis Yap',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                    onTap: () => _logout(),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle(String route) {
    switch (route) {
      case '/':
        return 'Dashboard';
      case '/orders':
        return 'Siparisler';
      case '/menu':
        return 'Menu Yonetimi';
      case '/products':
        return 'Urun Yonetimi';
      case '/inventory':
        return 'Stok Yonetimi';
      case '/categories':
        return 'Kategori Yonetimi';
      case '/reviews':
        return 'Yorumlar';
      case '/finance':
        return 'Finans';
      case '/reports':
        return 'Raporlar';
      case '/notifications':
        return 'Bildirimler';
      case '/couriers':
        return 'Kurye Yonetimi';
      case '/settings':
        return 'Ayarlar';
      default:
        return 'Merchant Panel';
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final String currentRoute;
  final bool isExpanded;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.isExpanded,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isActive =
        currentRoute == route ||
        (route != '/' && currentRoute.startsWith(route));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            NotificationSoundService.initializeAudio();
            context.go(route);
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 12 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment:
                  isExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
              children: [
                badges.Badge(
                  showBadge: badge != null && !isExpanded,
                  badgeContent: Text(
                    badge?.toString() ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    size: 22,
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color:
                            isActive
                                ? AppColors.primary
                                : AppColors.textPrimary,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
}
