import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/service_data.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/robot/robot_mascot.dart';
import '../../widgets/robot/robot_painter.dart';
import '../../widgets/buttons/glow_button.dart';
import '../../widgets/cards/panel_card.dart';
import '../../widgets/cards/feature_card.dart';
import '../../widgets/effects/gradient_text.dart';

class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      sections: const [
        _BusinessHeroSection(),
        _PanelsShowcaseSection(),
        _BenefitsSection(),
        _JoinCtaSection(),
      ],
    );
  }
}

class _BusinessHeroSection extends StatelessWidget {
  const _BusinessHeroSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      constraints: BoxConstraints(minHeight: isMobile ? 500 : 550),
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
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RobotMascot(
                size: isMobile ? 120 : 150,
                state: RobotState.talking,
                expression: RobotExpression.happy,
                prop: RobotProp.briefcase,
                glowColor: AppColors.primaryLight,
                showBubble: true,
                message: 'İşletmeniz için hazırız!',
              ),
              const SizedBox(height: 32),
              GradientText(
                text: 'İşletmenizi Büyütün',
                style: AppTypography.responsiveDisplay(isMobile),
                colors: const [Colors.white, AppColors.primaryLight],
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'SuperCyp platformuna katılın, binlerce müşteriye ulaşın. '
                'Özel yönetim panelleriyle işletmenizi dijitalleştirin.',
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

class _PanelsShowcaseSection extends StatelessWidget {
  const _PanelsShowcaseSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final crossCount = isMobile ? 1 : width < 1024 ? 2 : 3;

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
              Text(
                'Yönetim Panelleri',
                style: AppTypography.responsiveHeading(isMobile).copyWith(
                  color: AppColors.textOnLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Her hizmet için özel tasarlanmış yönetim panelleri',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textOnLightSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: isMobile ? 1.3 : 0.85,
                ),
                itemCount: ServiceData.panels.where((p) => p.id != 'admin').length,
                itemBuilder: (context, index) {
                  final panel = ServiceData.panels.where((p) => p.id != 'admin').elementAt(index);
                  return PanelCard(
                    name: panel.name,
                    description: panel.description,
                    icon: panel.icon,
                    color: panel.color,
                    gradient: panel.gradient,
                    url: panel.url,
                    features: panel.features,
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: 100 * index),
                        duration: 400.ms,
                      ).slideY(begin: 0.1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    final benefits = [
      (Icons.receipt_long_rounded, 'Sipariş Yönetimi', 'Gerçek zamanlı sipariş takibi ve yönetimi', AppColors.food),
      (Icons.analytics_rounded, 'Müşteri Analitiği', 'Müşteri davranışları ve satış raporları', AppColors.primary),
      (Icons.menu_book_rounded, 'Menü & Ürün', 'Kolay menü düzenleme ve ürün güncelleme', AppColors.market),
      (Icons.bar_chart_rounded, 'Finansal Raporlar', 'Gelir, gider ve kâr analizleri', AppColors.carRental),
      (Icons.notifications_rounded, 'Bildirimler', 'Anlık sipariş ve müşteri bildirimleri', AppColors.taxi),
      (Icons.store_rounded, 'Çoklu Şube', 'Birden fazla şubeyi tek panelden yönetin', AppColors.emlak),
    ];

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
                'Platform Avantajları',
                style: AppTypography.responsiveHeading(isMobile).copyWith(
                  color: AppColors.textOnDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: benefits.asMap().entries.map((entry) {
                  final i = entry.key;
                  final b = entry.value;
                  return SizedBox(
                    width: isMobile ? double.infinity : 360,
                    child: FeatureCard(
                      icon: b.$1,
                      title: b.$2,
                      description: b.$3,
                      color: b.$4,
                      isDark: true,
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: 80 * i),
                          duration: 400.ms,
                        ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinCtaSection extends StatelessWidget {
  const _JoinCtaSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceDark, AppColors.backgroundDark],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 60,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              RobotMascot(
                size: isMobile ? 100 : 120,
                state: RobotState.waving,
                expression: RobotExpression.happy,
                glowColor: AppColors.cyan,
                showBubble: true,
                message: 'Hemen başvurun, platformumuza katılın!',
              ),
              const SizedBox(height: 32),
              GradientText(
                text: 'Platformumuza Katılın',
                style: AppTypography.responsiveHeading(isMobile),
                colors: const [Colors.white, AppColors.cyan],
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Restoran, mağaza, emlak ofisi veya galeri — hangi sektörde olursanız olun, '
                'SuperCyp platformunda yerinizi alın.',
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
                children: ServiceData.panels.where((p) => p.id != 'admin').map((panel) {
                  return GlowButton(
                    label: panel.name.replaceAll(' Paneli', '').replaceAll('Restoran & Mağaza', 'Restoran'),
                    icon: panel.icon,
                    gradient: panel.gradient,
                    fontSize: 14,
                    onTap: () {},
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
