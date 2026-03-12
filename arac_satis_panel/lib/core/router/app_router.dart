import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/dealer/dealer_application_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/listings/listings_screen.dart';
import '../../screens/listings/add_listing_screen.dart';
import '../../screens/listings/listing_detail_screen.dart';
import '../../screens/messages/messages_screen.dart';
import '../../screens/performance/performance_screen.dart';
import '../../screens/reviews/reviews_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../shared/widgets/dealer_shell.dart';

/// Route sabitleri
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String application = '/application';
  static const String dashboard = '/dashboard';
  static const String listings = '/listings';
  static const String addListing = '/listings/add';
  static const String messages = '/messages';
  static const String performance = '/performance';
  static const String reviews = '/reviews';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

/// Auth state notifier for router refresh
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

/// Araç Satış Panel Router
final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final location = state.matchedLocation;

    final publicRoutes = ['/login', '/register', '/application'];
    final isPublicRoute = publicRoutes.contains(location);

    // Giriş yapmamış ve korunan sayfaya gitmeye çalışıyorsa
    if (!isLoggedIn && !isPublicRoute) {
      return '/login';
    }

    // Giriş yapmış ve login sayfasındaysa dashboard'a yönlendir
    if (isLoggedIn && location == '/login') {
      return '/dashboard';
    }

    // Eski /panel URL'sini dashboard'a yönlendir
    if (location == '/panel') {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    // ==================== AUTH ROUTES (Shell dışı) ====================
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/application',
      name: 'application',
      builder: (context, state) => const DealerApplicationScreen(),
    ),

    // Eski /panel route'u için redirect
    GoRoute(
      path: '/panel',
      redirect: (_, __) => '/dashboard',
    ),

    // ==================== SHELL ROUTES (Sidebar + Topbar) ====================
    ShellRoute(
      builder: (context, state, child) => DealerShell(child: child),
      routes: [
        // Dashboard
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),

        // İlanlarım
        GoRoute(
          path: '/listings',
          name: 'listings',
          builder: (context, state) => const ListingsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              name: 'add-listing',
              builder: (context, state) => const AddListingScreen(),
            ),
            GoRoute(
              path: 'edit/:id',
              name: 'edit-listing',
              builder: (context, state) {
                final listingId = state.pathParameters['id']!;
                return AddListingScreen(listingId: listingId);
              },
            ),
            GoRoute(
              path: ':id',
              name: 'listing-detail',
              builder: (context, state) {
                final listingId = state.pathParameters['id']!;
                return ListingDetailScreen(listingId: listingId);
              },
            ),
          ],
        ),

        // Mesajlar
        GoRoute(
          path: '/messages',
          name: 'messages',
          builder: (context, state) => const MessagesScreen(),
          routes: [
            GoRoute(
              path: ':id',
              name: 'chat',
              builder: (context, state) {
                final conversationId = state.pathParameters['id']!;
                return ChatScreen(conversationId: conversationId);
              },
            ),
          ],
        ),

        // Performans
        GoRoute(
          path: '/performance',
          name: 'performance',
          builder: (context, state) => const PerformanceScreen(),
        ),

        // Değerlendirmeler
        GoRoute(
          path: '/reviews',
          name: 'reviews',
          builder: (context, state) => const ReviewsScreen(),
        ),

        // Profil
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),

        // Ayarlar
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
