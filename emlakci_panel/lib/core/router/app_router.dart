import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/realtor/realtor_login_screen.dart';
import '../../screens/realtor/realtor_panel_screen.dart';
import '../../screens/realtor/realtor_application_screen.dart';
import '../../screens/realtor/add_property_screen.dart';
import '../../screens/realtor/property_detail_screen.dart';

/// Auth state notifier for router refresh
class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

/// Emlakçı Panel Router
final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isLoginRoute = state.matchedLocation == '/login';
    final isApplicationRoute = state.matchedLocation == '/application';

    // Giriş yapmamış ve login/application dışında bir sayfaya gitmeye çalışıyorsa
    if (!isLoggedIn && !isLoginRoute && !isApplicationRoute) {
      return '/login';
    }

    // Giriş yapmış ve login sayfasındaysa - kontrol login ekranında yapılacak
    // Router senkron olduğu için async kontrol yapamıyoruz
    // Bu yüzden login ekranında emlakçı kontrolü yapılıyor

    return null;
  },
  routes: [
    // Login
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const RealtorLoginScreen(),
    ),

    // Application (Başvuru)
    GoRoute(
      path: '/application',
      name: 'application',
      builder: (context, state) => const RealtorApplicationScreen(),
    ),

    // Panel (Ana Ekran)
    GoRoute(
      path: '/panel',
      name: 'panel',
      builder: (context, state) => const RealtorPanelScreen(),
    ),

    // Add Property
    GoRoute(
      path: '/add-property',
      name: 'add-property',
      builder: (context, state) => const AddPropertyScreen(),
    ),

    // Property Detail
    GoRoute(
      path: '/property/:id',
      name: 'property-detail',
      builder: (context, state) {
        final propertyId = state.pathParameters['id']!;
        return PropertyDetailScreen(propertyId: propertyId);
      },
    ),

  ],
);
