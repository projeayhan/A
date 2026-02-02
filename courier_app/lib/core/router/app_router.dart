import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/orders/orders_screen.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../screens/earnings/earnings_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/personal_info_screen.dart';
import '../../screens/profile/vehicle_info_screen.dart';
import '../../screens/profile/payment_info_screen.dart';
import '../../screens/profile/notifications_screen.dart';
import '../../screens/profile/help_screen.dart';
import '../../screens/profile/about_screen.dart';
import '../../screens/auth/pending_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String pending = '/pending';
  static const String home = '/';
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:id';
  static const String earnings = '/earnings';
  static const String profile = '/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuth = authState.status == AuthStatus.authenticated;
      final isPending = authState.status == AuthStatus.pendingApproval;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      final isRegistering = state.matchedLocation == AppRoutes.register;
      final isPendingPage = state.matchedLocation == AppRoutes.pending;

      // Onay bekliyor
      if (isPending && !isPendingPage) {
        return AppRoutes.pending;
      }

      // Giriş yapmamış ve login/register sayfasında değil
      if (!isAuth && !isPending && !isLoggingIn && !isRegistering) {
        return AppRoutes.login;
      }

      // Giriş yapmış ve login/register sayfasında
      if (isAuth && (isLoggingIn || isRegistering)) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.pending,
        name: 'pending',
        builder: (context, state) => const PendingScreen(),
      ),

      // Main app with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.orders,
            name: 'orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: AppRoutes.earnings,
            name: 'earnings',
            builder: (context, state) => const EarningsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Order detail (outside shell for full screen)
      GoRoute(
        path: AppRoutes.orderDetail,
        name: 'orderDetail',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          final initialOrderData = state.extra as Map<String, dynamic>?;
          return OrderDetailScreen(orderId: orderId, initialOrderData: initialOrderData);
        },
      ),

      // Profile sub-pages
      GoRoute(
        path: '/profile/personal',
        name: 'personalInfo',
        builder: (context, state) => const PersonalInfoScreen(),
      ),
      GoRoute(
        path: '/profile/vehicle',
        name: 'vehicleInfo',
        builder: (context, state) => const VehicleInfoScreen(),
      ),
      GoRoute(
        path: '/profile/payment',
        name: 'paymentInfo',
        builder: (context, state) => const PaymentInfoScreen(),
      ),
      GoRoute(
        path: '/profile/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/help',
        name: 'help',
        builder: (context, state) => const HelpScreen(),
      ),
      GoRoute(
        path: '/profile/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );
});

// Main shell with bottom navigation
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends ConsumerWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location == AppRoutes.home) currentIndex = 0;
    if (location == AppRoutes.orders) currentIndex = 1;
    if (location == AppRoutes.earnings) currentIndex = 2;
    if (location == AppRoutes.profile) currentIndex = 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Ana Sayfa',
                isActive: currentIndex == 0,
                onTap: () => context.go(AppRoutes.home),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Siparişler',
                isActive: currentIndex == 1,
                onTap: () => context.go(AppRoutes.orders),
              ),
              _NavItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
                label: 'Kazanç',
                isActive: currentIndex == 2,
                onTap: () => context.go(AppRoutes.earnings),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profil',
                isActive: currentIndex == 3,
                onTap: () => context.go(AppRoutes.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFFFF6B00) : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
