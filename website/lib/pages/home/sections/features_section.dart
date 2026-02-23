import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../widgets/cards/feature_card.dart';
import '../../../widgets/phone_mockup/phone_frame.dart';
import '../../../widgets/phone_mockup/mock_screens.dart';
import '../../../widgets/robot/robot_mascot.dart';
import '../../../widgets/robot/robot_painter.dart';

class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;

    return Container(
      color: AppColors.backgroundDark,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'Öne Çıkan Özellikler',
                style: AppTypography.responsiveHeading(isMobile).copyWith(
                  color: AppColors.textOnDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Yapay zeka destekli, sesli komutla çalışan süper uygulama',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textOnDarkSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // AI showcase row
              if (!isMobile)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Phone mockup
                    PhoneFrame(
                      width: 240,
                      child: const MockAIChatScreen(),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1),
                    const SizedBox(width: 48),
                    // Features + robot
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RobotMascot(
                            size: 120,
                            state: RobotState.pointing,
                            expression: RobotExpression.excited,
                            prop: RobotProp.phone,
                            glowColor: AppColors.cyan,
                            showBubble: true,
                            message: 'Basılı tut, konuş, bırak! Ben hallederim!',
                          ),
                          const SizedBox(height: 24),
                          _featuresList(),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                Center(
                  child: RobotMascot(
                    size: 120,
                    state: RobotState.pointing,
                    expression: RobotExpression.excited,
                    prop: RobotProp.phone,
                    glowColor: AppColors.cyan,
                    showBubble: true,
                    message: 'Basılı tut, konuş, bırak!',
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: PhoneFrame(
                    width: 200,
                    child: const MockAIChatScreen(),
                  ),
                ),
                const SizedBox(height: 32),
                _featuresList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuresList() {
    final features = [
      (Icons.smart_toy_rounded, 'AI Asistan', 'OpenAI destekli akıllı asistan ile konuşarak sipariş verin', AppColors.cyan),
      (Icons.mic_rounded, 'Sesli Komut', 'Walkie-talkie tarzı basılı tut-konuş + sesli yanıt', AppColors.green),
      (Icons.gps_fixed_rounded, 'Canlı Takip', 'Siparişinizi, taksinizi ve kuryenizi haritada anlık takip edin', AppColors.primary),
      (Icons.fingerprint_rounded, 'Biyometrik Giriş', 'Parmak izi ve Face ID ile güvenli giriş', AppColors.pink),
      (Icons.notifications_active_rounded, 'Anlık Bildirimler', 'Siparişinizin her aşamasından haberdar olun', AppColors.food),
      (Icons.shield_rounded, 'Güvenli Platform', 'Uçtan uca şifreli iletişim ve güvenli ödeme', AppColors.cyan),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: features.asMap().entries.map((entry) {
        final i = entry.key;
        final f = entry.value;
        return SizedBox(
          width: 280,
          child: FeatureCard(
            icon: f.$1,
            title: f.$2,
            description: f.$3,
            color: f.$4,
            isDark: true,
          ).animate().fadeIn(
                delay: Duration(milliseconds: 100 * i),
                duration: const Duration(milliseconds: 400),
              ),
        );
      }).toList(),
    );
  }
}
