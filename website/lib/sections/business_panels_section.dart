import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/responsive/responsive_builder.dart';
import '../widgets/section_header.dart';
import '../widgets/glass_card.dart';

class BusinessPanelsSection extends StatelessWidget {
  const BusinessPanelsSection({super.key});

  static const _panels = [
    _Panel('Admin Panel', 'Tum sistemi tek merkezden yonetin', Icons.admin_panel_settings, AppColors.adminGradient, 'https://admin-panel-tau-wine.vercel.app'),
    _Panel('Restoran & Magaza Paneli', 'Menu, siparis ve musteri yonetimi', Icons.storefront, AppColors.foodGradient, 'https://merchant-panel-wine.vercel.app'),
    _Panel('Emlakci Paneli', 'Emlak ilan ve portfoy yonetimi', Icons.real_estate_agent, AppColors.realEstateGradient, 'https://emlakci-panel.vercel.app'),
    _Panel('Arac Satis Paneli', 'Arac ilan ve galeri yonetimi', Icons.directions_car, AppColors.carSalesGradient, 'https://arac-satis-panel.vercel.app'),
    _Panel('Rent a Car Paneli', 'Filo ve rezervasyon yonetimi', Icons.car_rental, AppColors.rentalGradient, 'https://rent-a-car-panel.vercel.app'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: ContentWrapper(
        child: Column(
          children: [
            const SectionHeader(title: 'Isletme Panelleri', subtitle: 'Isletmenizi profesyonelce yonetin'),
            ResponsiveBuilder(
              builder: (context, device, width) {
                if (device == DeviceType.mobile) {
                  return Column(
                    children: _panels.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PanelCard(panel: e.value),
                    ).animate(delay: (e.key * 100).ms).fadeIn(duration: 400.ms).slideX(begin: e.key.isEven ? -0.05 : 0.05, end: 0)).toList(),
                  );
                }

                // Desktop/Tablet: top row 3, bottom row 2 centered
                return Column(
                  children: [
                    Row(
                      children: _panels.take(3).toList().asMap().entries.map((e) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: e.key > 0 ? 16 : 0),
                          child: _PanelCard(panel: e.value),
                        ),
                      ).animate(delay: (e.key * 120).ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0)).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _panels.skip(3).toList().asMap().entries.map((e) => SizedBox(
                        width: (width - 16) / 3,
                        child: Padding(
                          padding: EdgeInsets.only(left: e.key > 0 ? 16 : 0),
                          child: _PanelCard(panel: e.value),
                        ),
                      ).animate(delay: ((e.key + 3) * 120).ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0)).toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel {
  final String title, description;
  final IconData icon;
  final List<Color> gradient;
  final String url;
  const _Panel(this.title, this.description, this.icon, this.gradient, this.url);
}

class _PanelCard extends StatelessWidget {
  final _Panel panel;
  const _PanelCard({required this.panel});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: panel.gradient,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: panel.gradient),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: panel.gradient.first.withAlpha(50), blurRadius: 20)],
            ),
            child: Icon(panel.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          Text(panel.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(panel.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(panel.url)),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Giris Yap'),
              style: OutlinedButton.styleFrom(
                foregroundColor: panel.gradient.first,
                side: BorderSide(color: panel.gradient.first.withAlpha(80)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
