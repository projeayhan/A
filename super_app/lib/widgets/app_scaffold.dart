import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_responsive.dart';
import '../core/router/app_router.dart';
import '../core/providers/navigation_provider.dart';

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

    return Scaffold(
      body: child,
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
