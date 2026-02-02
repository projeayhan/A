import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/cars/cars_screen.dart';
import '../features/cars/car_detail_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/bookings/booking_detail_screen.dart';
import '../features/locations/locations_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/reviews/reviews_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/dashboard';
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
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/cars',
            builder: (context, state) => const CarsScreen(),
          ),
          GoRoute(
            path: '/cars/:id',
            builder: (context, state) => CarDetailScreen(
              carId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) => const BookingsScreen(),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/bookings/:id',
            builder: (context, state) => BookingDetailScreen(
              bookingId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/locations',
            builder: (context, state) => const LocationsScreen(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/reviews',
            builder: (context, state) => const ReviewsScreen(),
          ),
        ],
      ),
    ],
  );
});
