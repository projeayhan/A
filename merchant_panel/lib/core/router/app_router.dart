import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../shared/widgets/merchant_shell.dart';
import '../../shared/screens/dashboard_screen.dart';
import '../../shared/screens/orders_screen.dart';
import '../../shared/screens/order_detail_screen.dart';
import '../../shared/screens/reviews_screen.dart';
import '../../shared/screens/finance_screen.dart';
import '../../shared/screens/reports_screen.dart';
import '../../shared/screens/settings_screen.dart';
import '../../shared/screens/notifications_screen.dart';
import '../../features/restaurant/screens/menu_screen.dart';
import '../../features/store/screens/products_screen.dart';
import '../../features/store/screens/inventory_screen.dart';
import '../../features/store/screens/categories_screen.dart';
import '../../shared/screens/couriers_screen.dart';
import '../../shared/screens/messages_screen.dart';
import '../../features/support/screens/ai_chat_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = Supabase.instance.client;

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentUser != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      // Merchant type bazlı route guard
      // Bu kontrol MerchantShell içinde daha iyi yapılır çünkü
      // merchant verisi async yükleniyor

      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main App Shell
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MerchantShell(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: DashboardScreen()),
          ),

          // Orders
          GoRoute(
            path: '/orders',
            name: 'orders',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: OrdersScreen()),
            routes: [
              GoRoute(
                path: ':orderId',
                name: 'order-detail',
                builder:
                    (context, state) => OrderDetailScreen(
                      orderId: state.pathParameters['orderId']!,
                    ),
              ),
            ],
          ),

          // Restaurant Routes
          GoRoute(
            path: '/menu',
            name: 'menu',
            pageBuilder:
                (context, state) => const NoTransitionPage(child: MenuScreen()),
          ),

          // Store Routes
          GoRoute(
            path: '/products',
            name: 'products',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ProductsScreen()),
          ),
          GoRoute(
            path: '/inventory',
            name: 'inventory',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: InventoryScreen()),
          ),
          GoRoute(
            path: '/categories',
            name: 'categories',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: CategoriesScreen()),
          ),

          // Shared Routes
          GoRoute(
            path: '/reviews',
            name: 'reviews',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ReviewsScreen()),
          ),
          GoRoute(
            path: '/finance',
            name: 'finance',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: FinanceScreen()),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ReportsScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: NotificationsScreen()),
          ),
          GoRoute(
            path: '/messages',
            name: 'messages',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: MessagesScreen()),
          ),
          GoRoute(
            path: '/couriers',
            name: 'couriers',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: CouriersScreen()),
          ),

          // Support Routes
          GoRoute(
            path: '/support/ai-chat',
            name: 'ai-chat',
            builder: (context, state) => const AiChatScreen(),
          ),
        ],
      ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Sayfa Bulunamadi',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  state.error?.message ?? 'Bilinmeyen bir hata olustu',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Ana Sayfaya Don'),
                ),
              ],
            ),
          ),
        ),
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((AuthState _) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
