import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/dealer/dealer_application_screen.dart';
import '../../screens/panel/dealer_panel_screen.dart';
import '../../screens/listings/add_listing_screen.dart';
import '../../screens/listings/listing_detail_screen.dart';

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
    final isLoginRoute = state.matchedLocation == '/login';
    final isRegisterRoute = state.matchedLocation == '/register';
    final isApplicationRoute = state.matchedLocation == '/application';

    // Giriş yapmamış ve korunan sayfaya gitmeye çalışıyorsa
    if (!isLoggedIn && !isLoginRoute && !isRegisterRoute && !isApplicationRoute) {
      return '/login';
    }

    return null;
  },
  routes: [
    // Login
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),

    // Register
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // Application (Başvuru)
    GoRoute(
      path: '/application',
      name: 'application',
      builder: (context, state) => const DealerApplicationScreen(),
    ),

    // Panel (Ana Ekran)
    GoRoute(
      path: '/panel',
      name: 'panel',
      builder: (context, state) => const DealerPanelScreen(),
    ),

    // Add Listing
    GoRoute(
      path: '/add-listing',
      name: 'add-listing',
      builder: (context, state) => const AddListingScreen(),
    ),

    // Edit Listing
    GoRoute(
      path: '/edit-listing/:id',
      name: 'edit-listing',
      builder: (context, state) {
        final listingId = state.pathParameters['id']!;
        return AddListingScreen(listingId: listingId);
      },
    ),

    // Listing Detail
    GoRoute(
      path: '/listing/:id',
      name: 'listing-detail',
      builder: (context, state) {
        final listingId = state.pathParameters['id']!;
        return ListingDetailScreen(listingId: listingId);
      },
    ),
  ],
);
