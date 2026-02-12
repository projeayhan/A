import 'package:flutter/material.dart';
import 'widgets/particle_background.dart';
import 'widgets/nav_bar.dart';
import 'sections/hero_section.dart';
import 'sections/ai_showcase_section.dart';
import 'sections/services_section.dart';
import 'sections/mobile_apps_section.dart';
import 'sections/business_panels_section.dart';
import 'sections/technology_section.dart';
import 'sections/footer_section.dart';
import 'widgets/section_divider.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();

  final _sectionKeys = <String, GlobalKey>{
    'hero': GlobalKey(),
    'ai': GlobalKey(),
    'services': GlobalKey(),
    'apps': GlobalKey(),
    'panels': GlobalKey(),
    'tech': GlobalKey(),
  };

  void _scrollToSection(String key) {
    final context = _sectionKeys[key]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const ParticleBackground(),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              NavBar(
                scrollController: _scrollController,
                onNavTap: _scrollToSection,
              ),
              SliverToBoxAdapter(child: HeroSection(key: _sectionKeys['hero'], onExplore: () => _scrollToSection('services'))),
              const SliverToBoxAdapter(child: SectionDivider()),
              SliverToBoxAdapter(child: AiShowcaseSection(key: _sectionKeys['ai'])),
              const SliverToBoxAdapter(child: SectionDivider()),
              SliverToBoxAdapter(child: ServicesSection(key: _sectionKeys['services'])),
              const SliverToBoxAdapter(child: SectionDivider()),
              SliverToBoxAdapter(child: MobileAppsSection(key: _sectionKeys['apps'])),
              const SliverToBoxAdapter(child: SectionDivider()),
              SliverToBoxAdapter(child: BusinessPanelsSection(key: _sectionKeys['panels'])),
              const SliverToBoxAdapter(child: SectionDivider()),
              SliverToBoxAdapter(child: TechnologySection(key: _sectionKeys['tech'])),
              SliverToBoxAdapter(child: FooterSection(onScrollTop: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic))),
            ],
          ),
        ],
      ),
    );
  }
}
