import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/router/app_router.dart';
import '../../widgets/robot/robot_mascot.dart';
import '../../widgets/robot/robot_painter.dart';
import '../../widgets/buttons/glow_button.dart';
import '../../widgets/effects/gradient_text.dart';
import '../../widgets/page_shell.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return PageShell(
      sections: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RobotMascot(
                  size: isMobile ? 120 : 160,
                  state: RobotState.idle,
                  expression: RobotExpression.normal,
                  glowColor: AppColors.primary,
                  showBubble: true,
                  message: 'Aradığınız sayfa bulunamadı!',
                ),
                const SizedBox(height: 32),
                GradientText(
                  text: '404',
                  style: AppTypography.displayLarge.copyWith(fontSize: 80),
                  colors: const [AppColors.primary, AppColors.cyan],
                ),
                const SizedBox(height: 12),
                Text(
                  'Sayfa Bulunamadı',
                  style: AppTypography.headingLarge.copyWith(
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aradığınız sayfa mevcut değil veya taşınmış olabilir.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textOnDarkSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                GlowButton(
                  label: 'Ana Sayfaya Dön',
                  icon: Icons.home_rounded,
                  gradient: const [AppColors.primary, AppColors.primaryLight],
                  onTap: () => context.go(AppRoutes.home),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
