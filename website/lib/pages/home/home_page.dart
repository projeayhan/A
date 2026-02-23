import 'package:flutter/material.dart';
import '../../widgets/page_shell.dart';
import 'sections/hero_section.dart';
import 'sections/services_overview_section.dart';
import 'sections/features_section.dart';
import 'sections/stats_section.dart';
import 'sections/cta_section.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageShell(
      sections: [
        HeroSection(),
        ServicesOverviewSection(),
        FeaturesSection(),
        StatsSection(),
        CtaSection(),
      ],
    );
  }
}
