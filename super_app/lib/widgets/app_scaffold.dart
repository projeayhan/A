import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_responsive.dart';
import '../core/router/app_router.dart';
import '../core/providers/navigation_provider.dart';
import '../core/providers/ai_context_provider.dart';
import 'floating_ai_assistant.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({
    super.key,
    required this.child,
  });

  // Bottom navigation gösterilmeyecek sayfalar
  static const List<String> _hideBottomNavRoutes = [
    '/food/item/',
    '/food/cart',
    '/food/order-success/',
    '/food/order-tracking/',
    '/store/product/',
    '/emlak/property/',
    '/emlak/add',
    '/car-sales/detail/',
    '/car-sales/add',
    '/car-sales/my-listings',
    '/car-sales/search',
    '/settings',
  ];

  bool _shouldShowBottomNav(String location) {
    for (final route in _hideBottomNavRoutes) {
      if (location.startsWith(route)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final routerState = GoRouterState.of(context);
    final location = routerState.uri.path;
    final showBottomNav = _shouldShowBottomNav(location);

    // Route-based AI context update
    _updateAiContext(ref, location);

    return Scaffold(
      body: Stack(
        children: [
          child,
          const FloatingAIAssistant(),
        ],
      ),
      bottomNavigationBar: showBottomNav ? Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.isMobile ? 8 : 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    ref: ref,
                    index: 0,
                    icon: Icons.home,
                    label: 'Ana Sayfa',
                    isSelected: currentTab == 0,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    ref: ref,
                    index: 1,
                    icon: Icons.favorite,
                    label: 'Favoriler',
                    isSelected: currentTab == 1,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    ref: ref,
                    index: 2,
                    icon: Icons.receipt_long,
                    label: 'Siparişler',
                    isSelected: currentTab == 2,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context: context,
                    ref: ref,
                    index: 3,
                    icon: Icons.person,
                    label: 'Profil',
                    isSelected: currentTab == 3,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ) : null,
    );
  }

  void _updateAiContext(WidgetRef ref, String location) {
    AiScreenContext ctx;

    if (location.startsWith('/food/restaurant/')) {
      // Restaurant detail - entity context set by the screen itself
      return;
    } else if (location.startsWith('/store/detail/')) {
      // Store detail - entity context set by the screen itself
      return;
    } else if (location.startsWith('/grocery/market/')) {
      // Market detail - entity context set by the screen itself
      return;
    } else if (location == '/food' || location == '/food/') {
      ctx = const AiScreenContext(screenType: 'food_home');
    } else if (location == '/market' || location == '/market/') {
      ctx = const AiScreenContext(screenType: 'store_home');
    } else if (location == '/grocery' || location == '/grocery/') {
      ctx = const AiScreenContext(screenType: 'grocery_home');
    } else if (location.startsWith('/store/cart')) {
      ctx = const AiScreenContext(screenType: 'store_cart');
    } else if (location.startsWith('/food/cart')) {
      ctx = const AiScreenContext(screenType: 'food_cart');
    } else if (location == '/' || location.isEmpty) {
      ctx = const AiScreenContext.home();
    } else if (location.startsWith('/favorites')) {
      ctx = const AiScreenContext(screenType: 'favorites');
    } else if (location.startsWith('/orders')) {
      ctx = const AiScreenContext(screenType: 'orders');
    } else if (location.startsWith('/profile')) {
      ctx = const AiScreenContext(screenType: 'profile');
    } else if (location.startsWith('/emlak')) {
      ctx = const AiScreenContext(screenType: 'emlak');
    } else if (location.startsWith('/car-sales')) {
      ctx = const AiScreenContext(screenType: 'car_sales');
    } else if (location.startsWith('/jobs')) {
      ctx = const AiScreenContext(screenType: 'jobs');
    } else {
      ctx = AiScreenContext(screenType: 'other', extra: {'path': location});
    }

    // Only update if changed to avoid unnecessary rebuilds
    final current = ref.read(aiScreenContextProvider);
    if (current.screenType != ctx.screenType ||
        current.entityId != ctx.entityId) {
      // Use Future.microtask to avoid updating provider during build
      Future.microtask(() {
        ref.read(aiScreenContextProvider.notifier).state = ctx;
      });
    }
  }

  Widget _buildNavItem({
    required BuildContext context,
    required WidgetRef ref,
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(currentTabProvider.notifier).state = index;
        // Navigate to corresponding route
        switch (index) {
          case 0:
            context.go(AppRoutes.home);
            break;
          case 1:
            context.go(AppRoutes.favorites);
            break;
          case 2:
            context.go(AppRoutes.ordersMain);
            break;
          case 3:
            context.go(AppRoutes.profile);
            break;
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.isMobile ? 24 : 28,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey[500] : Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
