import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../widgets/robot/robot_mascot.dart';
import '../../../widgets/robot/robot_painter.dart';
import '../../../widgets/buttons/glow_button.dart';
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
        // Logo with slogan
        Image.asset(
          'assets/images/supercyp_logo.png',
          height: isMobile ? 120 : 160,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),
        // Description
        Text(
          'Yemek, market, taksi, emlak, araç kiralama ve daha fazlası — '
          'yapay zeka destekli asistan ile tek platformda.',
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
