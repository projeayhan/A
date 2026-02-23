import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/constants/service_data.dart';
import '../../../widgets/phone_mockup/phone_frame.dart';
import '../../../widgets/phone_mockup/screen_carousel.dart';
import '../../../widgets/robot/robot_mascot.dart';
import '../../../widgets/robot/robot_painter.dart';

class ServiceDetailSection extends StatelessWidget {
  final ServiceInfo service;
  final bool isDark;
  final bool reversed; // text left, mockup right vs opposite
  final List<Widget> mockupScreens;
  final RobotProp robotProp;

  const ServiceDetailSection({
    super.key,
    required this.service,
    this.isDark = false,
    this.reversed = false,
    required this.mockupScreens,
    this.robotProp = RobotProp.none,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isMobile
              ? _buildMobile(context)
              : _buildDesktop(context),
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final content = _buildContent(false);
    final mockup = _buildMockup(false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: reversed
          ? [
              Expanded(flex: 5, child: mockup),
              const SizedBox(width: 60),
              Expanded(flex: 5, child: content),
            ]
          : [
              Expanded(flex: 5, child: content),
              const SizedBox(width: 60),
              Expanded(flex: 5, child: mockup),
            ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Column(
      children: [
        _buildContent(true),
        const SizedBox(height: 32),
        _buildMockup(true),
      ],
    );
  }

  Widget _buildContent(bool isMobile) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Robot
        RobotMascot(
          size: isMobile ? 100 : 120,
          state: RobotState.talking,
          expression: RobotExpression.happy,
          prop: robotProp,
          glowColor: service.color,
          showBubble: true,
          message: service.robotMessage,
        ),
        const SizedBox(height: 24),
        // Service icon + name
        Row(
          mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: service.gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(service.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Text(
              service.name,
              style: AppTypography.headingLarge.copyWith(
                color: isDark ? AppColors.textOnDark : AppColors.textOnLight,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).slideX(begin: reversed ? 0.1 : -0.1),
        const SizedBox(height: 14),
        // Description
        Text(
          service.longDesc,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textOnDarkSecondary
                : AppColors.textOnLightSecondary,
          ),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
        ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
        const SizedBox(height: 24),
        // Features list
        ...service.features.asMap().entries.map((entry) {
          final i = entry.key;
          final feature = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: service.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_rounded,
                      color: service.color, size: 16),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    feature,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textOnDark
                          : AppColors.textOnLight,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(
                delay: Duration(milliseconds: 150 + 80 * i),
                duration: 400.ms,
              ).slideX(begin: reversed ? 0.05 : -0.05);
        }),
      ],
    );
  }

  Widget _buildMockup(bool isMobile) {
    final phoneWidth = isMobile ? 220.0 : 260.0;
    return Center(
      child: SizedBox(
        height: phoneWidth * 2.05 + 30,
        child: PhoneFrame(
          width: phoneWidth,
          child: ScreenCarousel(screens: mockupScreens),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: reversed ? -0.1 : 0.1);
  }
}
