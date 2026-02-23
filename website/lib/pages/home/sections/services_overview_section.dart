import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/service_data.dart';
import '../../../core/router/app_router.dart';
import '../../../widgets/cards/service_card.dart';

class ServicesOverviewSection extends StatelessWidget {
  const ServicesOverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final isTablet = width >= 768 && width < 1024;
    final crossCount = isMobile ? 2 : isTablet ? 3 : 4;

    return Container(
      color: AppColors.backgroundLight,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // Section header
              Text(
                'Hizmetlerimiz',
                style: AppTypography.responsiveHeading(isMobile).copyWith(
                  color: AppColors.textOnLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '8 farklı hizmet, tek uygulama',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textOnLightSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? 1.1 : 1.2,
                ),
                itemCount: ServiceData.services.length,
                itemBuilder: (context, index) {
                  final service = ServiceData.services[index];
                  return ServiceCard(
                    name: service.name,
                    description: service.shortDesc,
                    icon: service.icon,
                    color: service.color,
                    gradient: service.gradient,
                    onTap: () => context.go(AppRoutes.services),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: 80 * index),
                        duration: const Duration(milliseconds: 400),
                      ).slideY(
                        begin: 0.1,
                        delay: Duration(milliseconds: 80 * index),
                        duration: const Duration(milliseconds: 400),
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
