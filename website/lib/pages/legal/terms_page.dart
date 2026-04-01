import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/page_shell.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
                    'Kullanım Koşulları',
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
      'title': '1. Hizmet Tanımı',
      'body':
          'SuperCyp, yemek siparişi, taksi, kurye, emlak, araç satış ve kiralama ile iş ilanları hizmetlerini tek bir platformda sunan bir süper uygulama platformudur. Bu koşullar, SuperCyp uygulamasını ve web sitesini kullanımınızı düzenler.',
    },
    {
      'title': '2. Hesap Oluşturma',
      'body':
          'Hizmetlerimizi kullanmak için bir hesap oluşturmanız gerekir. Hesap bilgilerinizin doğru ve güncel olmasından siz sorumlusunuz. Hesabınızın güvenliğini sağlamak ve yetkisiz erişimi önlemek sizin yükümlülüğünüzdedir.',
    },
    {
      'title': '3. Hizmet Kullanımı',
      'body':
          'Platformumuzu yalnızca yasal amaçlar için kullanmayı kabul edersiniz. Hizmetlerimizi kötüye kullanma, başkalarının haklarını ihlal etme veya platformun güvenliğini tehlikeye atma girişimlerinde bulunmayacaksınız.',
    },
    {
      'title': '4. Siparişler ve Ödemeler',
      'body':
          'Verdiğiniz siparişler bağlayıcıdır. Ödeme, sipariş onaylandığında işlenir. Fiyatlar hizmet sağlayıcı tarafından belirlenir ve platform komisyonu dahil olabilir. İptal ve iade politikaları hizmet türüne göre değişir.',
    },
    {
      'title': '5. İşletme Sorumlulukları',
      'body':
          'Platformumuzda hizmet sunan işletmeler, sundukları ürün ve hizmetlerin kalitesinden sorumludur. SuperCyp, aracı platform olarak işletmeler ile kullanıcılar arasındaki iletişimi kolaylaştırır.',
    },
    {
      'title': '6. Fikri Mülkiyet',
      'body':
          'SuperCyp markası, logosu, yazılımı ve içeriği telif hakkı ile korunmaktadır. Platformdaki içerikleri izinsiz kopyalama, dağıtma veya değiştirme yasaktır.',
    },
    {
      'title': '7. Sorumluluk Sınırlaması',
      'body':
          'SuperCyp, platform üzerinden sunulan üçüncü taraf hizmetlerinin kalitesi, güvenliği veya yasallığı konusunda garanti vermez. Platformun kesintisiz veya hatasız çalışacağını garanti etmiyoruz.',
    },
    {
      'title': '8. Değişiklikler',
      'body':
          'Bu kullanım koşullarını önceden bildirimde bulunarak değiştirme hakkını saklı tutarız. Güncellenmiş koşullar bu sayfada yayımlanacak ve platformu kullanmaya devam etmeniz yeni koşulları kabul ettiğiniz anlamına gelir.',
    },
    {
      'title': '9. İletişim',
      'body':
          'Kullanım koşullarımız hakkında sorularınız için info@supercyp.com adresinden bize ulaşabilirsiniz.',
    },
  ];
}
