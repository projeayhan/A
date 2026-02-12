import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'landing_page.dart';

class SuperCypWebsite extends StatelessWidget {
  const SuperCypWebsite({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SuperCyp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      home: const LandingPage(),
    );
  }
}
