import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../pages/home/home_page.dart';
import '../../pages/services/services_page.dart';
import '../../pages/business/business_page.dart';
import '../../pages/download/download_page.dart';
import '../../pages/legal/privacy_policy_page.dart';
import '../../pages/legal/terms_page.dart';
import '../../pages/not_found/not_found_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String services = '/hizmetler';
  static const String business = '/isletmeler';
  static const String download = '/indir';
  static const String privacy = '/gizlilik';
  static const String terms = '/kosullar';
}

CustomTransitionPage _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  errorPageBuilder: (context, state) => _fadePage(state, const NotFoundPage()),
  routes: [
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) => _fadePage(state, const HomePage()),
    ),
    GoRoute(
      path: AppRoutes.services,
      pageBuilder: (context, state) => _fadePage(state, const ServicesPage()),
    ),
    GoRoute(
      path: AppRoutes.business,
      pageBuilder: (context, state) => _fadePage(state, const BusinessPage()),
    ),
    GoRoute(
      path: AppRoutes.download,
      pageBuilder: (context, state) => _fadePage(state, const DownloadPage()),
    ),
    GoRoute(
      path: AppRoutes.privacy,
      pageBuilder: (context, state) => _fadePage(state, const PrivacyPolicyPage()),
    ),
    GoRoute(
      path: AppRoutes.terms,
      pageBuilder: (context, state) => _fadePage(state, const TermsPage()),
    ),
  ],
);
