import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../widgets/robot/robot_mascot.dart';
import '../../../widgets/robot/robot_painter.dart';
import '../../../widgets/buttons/glow_button.dart';
import '../../../widgets/effects/gradient_text.dart';
import '../../../widgets/effects/animated_gradient_bg.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return AnimatedGradientBg(
      child: Container(
        constraints: BoxConstraints(minHeight: isMobile ? 600 : 700),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 60,
          vertical: 40,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isMobile ? _buildMobile(context) : _buildDesktop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left content
        Expanded(
          flex: 3,
          child: _HeroContent(),
        ),
        const SizedBox(width: 40),
        // Right robot
        Expanded(
          flex: 2,
          child: Center(
            child: RobotMascot(
              size: 200,
              state: RobotState.talking,
              expression: RobotExpression.happy,
              glowColor: AppColors.cyan,
              showBubble: true,
              message: 'Merhaba! Ben SuperCyp AI asistanıyım. Sesli komutla her şeyi halledebilirsiniz!',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RobotMascot(
          size: 140,
          state: RobotState.talking,
          expression: RobotExpression.happy,
          glowColor: AppColors.cyan,
          showBubble: true,
          message: 'Merhaba! 8 hizmet, tek uygulama!',
        ),
        const SizedBox(height: 24),
        _HeroContent(),
      ],
    );
  }
}

class _HeroContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 14),
              const SizedBox(width: 6),
              Text(
                'Kuzey Kıbrıs\'ın Süper Uygulaması',
                style: AppTypography.label.copyWith(
                  color: AppColors.primaryLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Title
        GradientText(
          text: 'Tek Uygulama,\nSınırsız Hizmet',
          style: AppTypography.responsiveDisplay(isMobile).copyWith(
            color: Colors.white,
          ),
          colors: const [Colors.white, AppColors.primaryLight],
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 16),
        // Description
        Text(
          'Yemekten emlağa, taksiden iş ilanlarına — 8 farklı hizmet, '
          'yapay zeka destekli asistan ve sesli komut desteğiyle tek platformda.',
          style: AppTypography.responsiveBody(isMobile).copyWith(
            color: AppColors.textOnDarkSecondary,
          ),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 32),
        // CTAs
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          children: [
            GlowButton(
              label: 'Uygulamayı İndir',
              icon: Icons.download_rounded,
              gradient: const [AppColors.primary, AppColors.primaryLight],
              onTap: () => context.go(AppRoutes.download),
            ),
            GlowButton(
              label: 'Hizmetleri Keşfet',
              icon: Icons.grid_view_rounded,
              gradient: const [AppColors.cyan, AppColors.primary],
              outlined: true,
              onTap: () => context.go(AppRoutes.services),
            ),
          ],
        ),
      ],
    );
  }
}
