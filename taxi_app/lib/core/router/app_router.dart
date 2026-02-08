import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/pending_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/rides/rides_screen.dart';
import '../../screens/rides/ride_detail_screen.dart';
import '../../screens/earnings/earnings_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/reviews_screen.dart';
import '../../screens/profile/emergency_contacts_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isPending = authState.status == AuthStatus.pendingApproval;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';
      final isPendingPage = state.matchedLocation == '/pending';

      if (authState.status == AuthStatus.initial || authState.status == AuthStatus.loading) {
        return null;
      }

      if (isPending && !isPendingPage) {
        return '/pending';
      }

      if (!isLoggedIn && !isPending && !isLoggingIn && !isRegistering) {
        return '/login';
      }

      if (isLoggedIn && (isLoggingIn || isRegistering || isPendingPage)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/rides',
            builder: (context, state) => const RidesScreen(),
          ),
          GoRoute(
            path: '/rides/:id',
            builder: (context, state) => RideDetailScreen(
              rideId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/earnings',
            builder: (context, state) => const EarningsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/reviews',
            builder: (context, state) => const ReviewsScreen(),
          ),
          GoRoute(
            path: '/emergency-contacts',
            builder: (context, state) => const EmergencyContactsScreen(),
          ),
        ],
      ),
    ],
  );
});

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const MainBottomNav(),
    );
  }
}

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int currentIndex = 0;
    if (location.startsWith('/rides')) {
      currentIndex = 1;
    } else if (location.startsWith('/earnings')) {
      currentIndex = 2;
    } else if (location.startsWith('/profile')) {
      currentIndex = 3;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.home_outlined, Icons.home, 'Ana Sayfa', '/', currentIndex),
              _buildNavItem(context, 1, Icons.local_taxi_outlined, Icons.local_taxi, 'Yolculuklar', '/rides', currentIndex),
              _buildNavItem(context, 2, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Kazanç', '/earnings', currentIndex),
              _buildNavItem(context, 3, Icons.person_outline, Icons.person, 'Profil', '/profile', currentIndex),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    String route,
    int currentIndex,
  ) {
    final isActive = currentIndex == index;

    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC107).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF212121) : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF212121) : Colors.grey,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
