import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emlakci_panel/core/services/log_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/application_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/listings/screens/listings_screen.dart';
import '../../features/listings/screens/add_property_screen.dart';
import '../../features/listings/screens/property_detail_screen.dart';
import '../../features/appointments/screens/appointments_screen.dart';
import '../../features/crm/screens/clients_screen.dart';
import '../../features/crm/screens/client_detail_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/promotions/screens/promotions_screen.dart';
import '../../features/banner_ads/screens/banner_ads_screen.dart';
import '../../shared/widgets/emlak_shell.dart';

/// Route path constants
class AppRoutes {
  static const String login = '/login';
  static const String application = '/application';
  static const String dashboard = '/dashboard';
  static const String listings = '/listings';
  static const String addListing = '/listings/add';
  static const String listingDetail = '/listings/:id';
  static const String appointments = '/appointments';
  static const String clients = '/clients';
  static const String clientDetail = '/clients/:id';
  static const String analytics = '/analytics';
  static const String chat = '/chat';
  static const String chatDetail = '/chat/:id';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String promotions = '/promotions';
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

/// Cache for realtor role check to avoid repeated DB queries per navigation event
bool? _cachedIsRealtor;
String? _cachedIsRealtorUserId;

/// Check whether the current user has an approved realtor record
Future<bool> _checkIsRealtor() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    _cachedIsRealtor = null;
    _cachedIsRealtorUserId = null;
    return false;
  }
  // Return cached value if it belongs to the same user session
  if (_cachedIsRealtorUserId == user.id && _cachedIsRealtor != null) {
    return _cachedIsRealtor!;
  }
  try {
    final response = await Supabase.instance.client
        .from('realtors')
        .select('id')
        .eq('user_id', user.id)
        .eq('status', 'approved')
        .maybeSingle();
    _cachedIsRealtor = response != null;
    _cachedIsRealtorUserId = user.id;
    return _cachedIsRealtor!;
  } catch (e, st) {
    LogService.error('Realtor check failed', error: e, stackTrace: st, source: 'AppRouter:_isRealtor');
    return false;
  }
}

/// Emlakci Panel Router
final appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  refreshListenable: _authNotifier,
  redirect: (context, state) async {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isLoginRoute = state.matchedLocation == AppRoutes.login;
    final isApplicationRoute = state.matchedLocation == AppRoutes.application;

    // Not logged in and trying to access a protected route
    if (!isLoggedIn && !isLoginRoute && !isApplicationRoute) {
      return AppRoutes.login;
    }

    // Logged in — verify the user actually has a realtor role before
    // granting access to any panel route.
    if (isLoggedIn && !isLoginRoute && !isApplicationRoute) {
      final hasRealtorRole = await _checkIsRealtor();
      if (!hasRealtorRole) {
        // Invalidate cache so a fresh check runs after the user logs out
        _cachedIsRealtor = null;
        _cachedIsRealtorUserId = null;
        await Supabase.instance.client.auth.signOut();
        return AppRoutes.login;
      }
    }

    // Logged in and on login page -> redirect to dashboard
    if (isLoggedIn && isLoginRoute) {
      return AppRoutes.dashboard;
    }

    return null;
  },
  routes: [
    // Auth routes (outside shell)
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const RealtorLoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.application,
      name: 'application',
      builder: (context, state) => const RealtorApplicationScreen(),
    ),

    // Shell route for all panel screens
    ShellRoute(
      builder: (context, state, child) => EmlakShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.listings,
          name: 'listings',
          builder: (context, state) => const ListingsScreen(),
          routes: [
            GoRoute(
              path: 'add',
              name: 'add-listing',
              builder: (context, state) => const AddPropertyScreen(),
            ),
            GoRoute(
              path: ':id',
              name: 'listing-detail',
              builder: (context, state) {
                final propertyId = state.pathParameters['id']!;
                return PropertyDetailScreen(propertyId: propertyId);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.appointments,
          name: 'appointments',
          builder: (context, state) => const AppointmentsScreen(),
        ),
        GoRoute(
          path: AppRoutes.clients,
          name: 'clients',
          builder: (context, state) => const ClientsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              name: 'client-detail',
              builder: (context, state) {
                final clientId = state.pathParameters['id']!;
                return ClientDetailScreen(clientId: clientId);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.analytics,
          name: 'analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: AppRoutes.chat,
          name: 'chat',
          builder: (context, state) => const ChatListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              name: 'chat-detail',
              builder: (context, state) {
                final conversationId = state.pathParameters['id']!;
                return ChatScreen(conversationId: conversationId);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.profile,
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.promotions,
          name: 'promotions',
          builder: (context, state) => const EmlakPromotionsScreen(),
        ),
        GoRoute(
          path: '/banner-ads',
          name: 'banner-ads',
          builder: (context, state) => const BannerAdsScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
