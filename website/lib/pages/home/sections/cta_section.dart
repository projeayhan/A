import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../widgets/robot/robot_mascot.dart';
import '../../../widgets/robot/robot_painter.dart';
import '../../../widgets/buttons/glow_button.dart';
import '../../../widgets/effects/gradient_text.dart';

class CtaSection extends StatelessWidget {
  const CtaSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceDark,
            AppColors.backgroundDark,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 60,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              RobotMascot(
                size: isMobile ? 100 : 130,
                state: RobotState.waving,
                expression: RobotExpression.happy,
                glowColor: AppColors.primaryLight,
              ),
              const SizedBox(height: 32),
              GradientText(
                text: 'Hayatınızı Kolaylaştırın',
                style: AppTypography.responsiveHeading(isMobile),
                colors: const [Colors.white, AppColors.primaryLight],
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'SuperCyp\'i bugün indirin ve Kuzey Kıbrıs\'ın en kapsamlı platformundan yararlanın.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDarkSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  GlowButton(
                    label: 'Uygulamayı İndir',
                    icon: Icons.download_rounded,
                    gradient: const [AppColors.primary, AppColors.primaryLight],
                    onTap: () => context.go(AppRoutes.download),
                  ),
                  GlowButton(
                    label: 'İşletme Kaydı',
                    icon: Icons.business_rounded,
                    gradient: const [AppColors.cyan, AppColors.primary],
                    outlined: true,
                    onTap: () => context.go(AppRoutes.business),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
