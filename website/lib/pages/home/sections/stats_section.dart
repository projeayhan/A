import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/effects/animated_counter.dart';
import '../../../widgets/robot/robot_mascot.dart';
import '../../../widgets/robot/robot_painter.dart';

class StatsSection extends StatelessWidget {
  const StatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Container(
      color: AppColors.backgroundLight,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Text(
                'Rakamlarla SuperCyp',
                style: AppTypography.responsiveHeading(isMobile).copyWith(
                  color: AppColors.textOnLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Robot celebrating
              Center(
                child: RobotMascot(
                  size: isMobile ? 100 : 130,
                  state: RobotState.celebrating,
                  expression: RobotExpression.excited,
                  glowColor: AppColors.primary,
                ),
              ),
              const SizedBox(height: 40),
              // Stats row
              Wrap(
                spacing: isMobile ? 24 : 48,
                runSpacing: 32,
                alignment: WrapAlignment.center,
                children: [
                  const AnimatedCounter(
                    targetValue: 8,
                    label: 'Hizmet',
                    color: AppColors.primary,
                  ),
                  const AnimatedCounter(
                    targetValue: 69,
                    label: 'Ekran',
                    color: AppColors.cyan,
                  ),
                  const AnimatedCounter(
                    targetValue: 3,
                    label: 'Uygulama',
                    color: AppColors.food,
                  ),
                  const AnimatedCounter(
                    targetValue: 5,
                    label: 'Yönetim Paneli',
                    color: AppColors.carRental,
                  ),
                ].animate(interval: 200.ms).fadeIn(duration: 500.ms).slideY(begin: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
