import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class SuperCypWebsite extends StatelessWidget {
  const SuperCypWebsite({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SuperCyp - Tek Uygulama, Sınırsız Hizmet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
    );
  }
}
