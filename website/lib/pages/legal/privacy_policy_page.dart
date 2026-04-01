import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/page_shell.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return PageShell(
      sections: [
        Container(
          color: AppColors.backgroundDark,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 60,
            vertical: 60,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gizlilik Politikası',
                    style: AppTypography.responsiveDisplay(isMobile).copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Son güncelleme: 28 Mart 2026',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textOnDarkMuted,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ..._sections.map((s) => _buildSection(s['title']!, s['body']!)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headingSmall.copyWith(
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textOnDarkSecondary,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, String>> _sections = [
    {
      'title': '1. Toplanan Veriler',
      'body':
          'SuperCyp uygulamasını kullandığınızda ad, e-posta adresi, telefon numarası ve konum bilgileri gibi kişisel verilerinizi toplarız. Bu veriler hizmetlerimizi sunmak, siparişlerinizi işlemek ve deneyiminizi kişiselleştirmek için kullanılır.',
    },
    {
      'title': '2. Verilerin Kullanımı',
      'body':
          'Topladığımız verileri şu amaçlarla kullanırız: sipariş ve teslimat işlemleri, müşteri desteği, uygulama geliştirme, güvenlik önlemleri ve yasal yükümlülükler. Verileriniz açık onayınız olmadan üçüncü taraflarla pazarlama amacıyla paylaşılmaz.',
    },
    {
      'title': '3. Veri Güvenliği',
      'body':
          'Kişisel verilerinizin güvenliğini sağlamak için endüstri standardı şifreleme, güvenli sunucular ve erişim kontrolleri kullanırız. Ödeme bilgileri doğrudan ödeme işlemcimiz tarafından güvenli bir şekilde işlenir ve sunucularımızda saklanmaz.',
    },
    {
      'title': '4. Çerezler ve İzleme',
      'body':
          'Web sitemizde ve uygulamamızda kullanıcı deneyimini iyileştirmek için çerezler ve benzer teknolojiler kullanılabilir. Tarayıcı ayarlarınızdan çerezleri devre dışı bırakabilirsiniz, ancak bu bazı özelliklerin çalışmasını etkileyebilir.',
    },
    {
      'title': '5. Üçüncü Taraf Hizmetler',
      'body':
          'Hizmetlerimizi sunmak için harita servisleri, ödeme işlemcileri ve analitik araçları gibi üçüncü taraf hizmetlerden yararlanırız. Bu hizmet sağlayıcılar kendi gizlilik politikalarına tabidir.',
    },
    {
      'title': '6. Kullanıcı Hakları',
      'body':
          'Kişisel verilerinize erişim, düzeltme, silme veya taşınabilirlik talep etme hakkına sahipsiniz. Bu haklarınızı kullanmak için info@supercyp.com adresinden bizimle iletişime geçebilirsiniz.',
    },
    {
      'title': '7. Veri Saklama',
      'body':
          'Kişisel verilerinizi hizmetlerimizi sunmak için gerekli olduğu süre boyunca saklarız. Hesabınızı sildiğinizde, yasal yükümlülüklerimiz saklı kalmak kaydıyla verileriniz makul bir süre içinde silinir.',
    },
    {
      'title': '8. İletişim',
      'body':
          'Gizlilik politikamız hakkında sorularınız için info@supercyp.com adresinden bize ulaşabilirsiniz. Politikamızda yapılacak değişiklikler bu sayfada yayımlanacaktır.',
    },
  ];
}
