import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/responsive/responsive_builder.dart';
import '../widgets/section_header.dart';
import '../widgets/glass_card.dart';
import '../widgets/glow_button.dart';

class MobileAppsSection extends StatelessWidget {
  const MobileAppsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: ContentWrapper(
        child: Column(
          children: [
            const SectionHeader(title: 'Mobil Uygulamalar', subtitle: 'Her platformda yaninizdayiz'),
            ResponsiveBuilder(
              builder: (context, device, width) {
                final apps = [
                  _AppInfo('SuperCyp', 'Yemek, taksi, market ve daha fazlasi tek uygulamada', Icons.apps, [AppColors.primary, AppColors.cyan], true, 'https://mzgtvdgwxrlhgjboolys.supabase.co/storage/v1/object/public/apks/supercyp.apk'),
                  _AppInfo('SuperCyp Sofor', 'Taksi soforleri icin guclu uygulama', Icons.local_taxi, AppColors.taxiGradient, false, 'https://mzgtvdgwxrlhgjboolys.supabase.co/storage/v1/object/public/apks/supercyp-sofor.apk'),
                  _AppInfo('SuperCyp Kurye', 'Teslimat kuryesi uygulamasi', Icons.delivery_dining, AppColors.courierGradient, false, 'https://mzgtvdgwxrlhgjboolys.supabase.co/storage/v1/object/public/apks/supercyp-kurye.apk'),
                ];

                if (device == DeviceType.mobile) {
                  return Column(
                    children: apps.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _AppCard(app: e.value),
                    ).animate(delay: (e.key * 150).ms).fadeIn().slideY(begin: 0.05, end: 0)).toList(),
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: apps.asMap().entries.map((e) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: e.key > 0 ? 16 : 0),
                        child: _AppCard(app: e.value),
                      ),
                    ).animate(delay: (e.key * 150).ms).fadeIn().slideY(begin: 0.05, end: 0)).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppInfo {
  final String name, description;
  final IconData icon;
  final List<Color> gradient;
  final bool isPrimary;
  final String apkUrl;
  const _AppInfo(this.name, this.description, this.icon, this.gradient, this.isPrimary, this.apkUrl);
}

class _AppCard extends StatelessWidget {
  final _AppInfo app;
  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: app.gradient,
      child: Column(
        children: [
          // Phone mockup
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [app.gradient.first.withAlpha(30), app.gradient.last.withAlpha(10)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: app.gradient),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: app.gradient.first.withAlpha(60), blurRadius: 20)],
                    ),
                    child: Icon(app.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(app.name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(app.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4), textAlign: TextAlign.center),
          const Spacer(),
          const SizedBox(height: 20),
          GlowButton(
            text: 'APK Indir',
            icon: Icons.download_rounded,
            gradientColors: app.gradient,
            onPressed: () => launchUrl(Uri.parse(app.apkUrl), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 12),
          if (app.isPrimary)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StoreBadge('App Store', Icons.apple),
                const SizedBox(width: 12),
                _StoreBadge('Google Play', Icons.shop),
              ],
            )
          else
            const SizedBox(height: 38),
        ],
      ),
    );
  }
}

class _StoreBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _StoreBadge(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
