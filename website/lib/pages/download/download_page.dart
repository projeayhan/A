import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/service_data.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/robot/robot_mascot.dart';
import '../../widgets/robot/robot_painter.dart';
import '../../widgets/buttons/glow_button.dart';
import '../../widgets/effects/gradient_text.dart';
import '../../widgets/phone_mockup/phone_frame.dart';
import '../../widgets/phone_mockup/screen_carousel.dart';
import '../../widgets/phone_mockup/mock_screens.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      sections: const [
        _DownloadHeroSection(),
        _SuperAppSection(),
        _DriverAppSection(),
        _CourierAppSection(),
      ],
    );
  }
}

class _DownloadHeroSection extends StatelessWidget {
  const _DownloadHeroSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 400 : 450),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.backgroundDark, AppColors.surfaceDark],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 60,
        vertical: 60,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RobotMascot(
                size: isMobile ? 120 : 140,
                state: RobotState.talking,
                expression: RobotExpression.excited,
                prop: RobotProp.phone,
                glowColor: AppColors.primaryLight,
                showBubble: true,
                message: 'Hangi uygulamayı indirmek istersiniz?',
              ),
              const SizedBox(height: 32),
              GradientText(
                text: 'Uygulamaları İndir',
                style: AppTypography.responsiveDisplay(isMobile),
                colors: const [Colors.white, AppColors.cyan],
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '3 farklı uygulama — tüketiciler, taksi şoförleri ve kuryeler için',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDarkSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuperAppSection extends StatelessWidget {
  const _SuperAppSection();

  @override
  Widget build(BuildContext context) {
    return _AppDetailSection(
      app: ServiceData.apps[0],
      isDark: false,
      reversed: false,
      mockupScreens: const [
        MockHomeScreen(),
        MockFoodScreen(),
        MockTaxiScreen(),
        MockAIChatScreen(),
        MockEmlakScreen(),
      ],
      robotState: RobotState.celebrating,
      robotProp: RobotProp.phone,
      robotMessage: 'En popüler uygulamamız!',
      badge: '8 Hizmet Tek Uygulamada',
    );
  }
}

class _DriverAppSection extends StatelessWidget {
  const _DriverAppSection();

  @override
  Widget build(BuildContext context) {
    return _AppDetailSection(
      app: ServiceData.apps[1],
      isDark: true,
      reversed: true,
      mockupScreens: const [MockDriverScreen(), MockTaxiScreen()],
      robotState: RobotState.talking,
      robotProp: RobotProp.taxiCap,
      robotMessage: 'Şoförler için özel uygulama!',
    );
  }
}

class _CourierAppSection extends StatelessWidget {
  const _CourierAppSection();

  @override
  Widget build(BuildContext context) {
    return _AppDetailSection(
      app: ServiceData.apps[2],
      isDark: false,
      reversed: false,
      mockupScreens: const [MockCourierScreen(), MockHomeScreen()],
      robotState: RobotState.talking,
      robotProp: RobotProp.scooter,
      robotMessage: 'Kuryeler için hızlı uygulama!',
    );
  }
}

class _AppDetailSection extends StatelessWidget {
  final AppInfo app;
  final bool isDark;
  final bool reversed;
  final List<Widget> mockupScreens;
  final RobotState robotState;
  final RobotProp robotProp;
  final String robotMessage;
  final String? badge;

  const _AppDetailSection({
    required this.app,
    required this.isDark,
    required this.reversed,
    required this.mockupScreens,
    required this.robotState,
    required this.robotProp,
    required this.robotMessage,
    this.badge,
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
          child: isMobile ? _buildMobile() : _buildDesktop(),
        ),
      ),
    );
  }

  Widget _buildDesktop() {
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

  Widget _buildMobile() {
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
        RobotMascot(
          size: isMobile ? 100 : 120,
          state: robotState,
          expression: RobotExpression.happy,
          prop: robotProp,
          glowColor: app.gradient.first,
        ),
        const SizedBox(height: 20),
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: app.gradient),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              badge!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: app.gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(app.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Text(
              app.name,
              style: AppTypography.headingLarge.copyWith(
                color: isDark ? AppColors.textOnDark : AppColors.textOnLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          app.description,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark
                ? AppColors.textOnDarkSecondary
                : AppColors.textOnLightSecondary,
          ),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 20),
        ...app.features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: app.gradient.first, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    f,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textOnDark
                          : AppColors.textOnLight,
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          children: [
            GlowButton(
              label: 'Android APK İndir',
              icon: Icons.android_rounded,
              gradient: app.gradient,
              onTap: () {
                if (app.apkUrl != '#') {
                  launchUrl(Uri.parse(app.apkUrl));
                }
              },
            ),
            GlowButton(
              label: 'App Store (Yakında)',
              icon: Icons.apple_rounded,
              gradient: [Colors.grey.shade700, Colors.grey.shade600],
              outlined: true,
            ),
          ],
        ),
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
