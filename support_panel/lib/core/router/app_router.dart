import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/support_auth_service.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/tickets/screens/tickets_screen.dart';
import '../../features/tickets/screens/ticket_detail_screen.dart';
import '../../features/customers/screens/customer_search_screen.dart';
import '../../features/customers/screens/customer_360_screen.dart';
import '../../features/business_proxy/screens/business_search_screen.dart';
import '../../features/business_proxy/screens/business_operations_screen.dart';
import '../../features/live_chat/screens/live_chat_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/widgets/support_shell.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/';
  static const String tickets = '/tickets';
  static const String ticketDetail = '/tickets/:id';
  static const String customers = '/customers';
  static const String customerDetail = '/customers/:id';
  static const String liveChat = '/live-chat';
  static const String businesses = '/businesses';
  static const String businessOps = '/businesses/:id';
  static const String settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final agentState = ref.watch(currentAgentProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final isLoggedIn = agentState.value != null;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isLoginRoute) return AppRoutes.login;
      if (isLoggedIn && isLoginRoute) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => SupportShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.tickets,
            name: 'tickets',
            pageBuilder: (context, state) => const NoTransitionPage(child: TicketsScreen()),
          ),
          GoRoute(
            path: AppRoutes.ticketDetail,
            name: 'ticket-detail',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: TicketDetailScreen(ticketId: id));
            },
          ),
          GoRoute(
            path: AppRoutes.customers,
            name: 'customers',
            pageBuilder: (context, state) => const NoTransitionPage(child: CustomerSearchScreen()),
          ),
          GoRoute(
            path: AppRoutes.customerDetail,
            name: 'customer-detail',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoTransitionPage(child: Customer360Screen(customerId: id));
            },
          ),
          GoRoute(
            path: AppRoutes.liveChat,
            name: 'live-chat',
            pageBuilder: (context, state) => const NoTransitionPage(child: LiveChatScreen()),
          ),
          GoRoute(
            path: AppRoutes.businesses,
            name: 'businesses',
            pageBuilder: (context, state) => const NoTransitionPage(child: BusinessSearchScreen()),
          ),
          GoRoute(
            path: AppRoutes.businessOps,
            name: 'business-ops',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: BusinessOperationsScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: SupportSettingsScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Sayfa Bulunamadı', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(state.matchedLocation),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Ana Sayfaya Dön'),
            ),
          ],
        ),
      ),
    ),
  );
});
