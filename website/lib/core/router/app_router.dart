import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../pages/home/home_page.dart';
import '../../pages/services/services_page.dart';
import '../../pages/business/business_page.dart';
import '../../pages/download/download_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String services = '/hizmetler';
  static const String business = '/isletmeler';
  static const String download = '/indir';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.services,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ServicesPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.business,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const BusinessPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.download,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const DownloadPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
  ],
);
