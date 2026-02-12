import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/responsive/responsive_builder.dart';
import '../widgets/section_header.dart';
import '../widgets/glass_card.dart';

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

  static const _services = [
    _Service(Icons.restaurant, 'Yemek Siparisi', 'Binlerce restorandan online siparis verin, AI asistanla konusarak secin', AppColors.foodGradient),
    _Service(Icons.store, 'Restoran & Magaza', 'Isletmenizi tek panelden yonetin - menu, siparis, musteri analizi', AppColors.adminGradient),
    _Service(Icons.local_taxi, 'Taksi', 'Aninda taksi cagirin, gercek zamanli konum takibi, guvenli odeme', AppColors.taxiGradient),
    _Service(Icons.delivery_dining, 'Kurye Teslimat', 'Hizli ve guvenilir kurye teslimat hizmeti, canli siparis takibi', AppColors.courierGradient),
    _Service(Icons.real_estate_agent, 'Emlak', 'Satilik ve kiralik emlak ilanlari, AI ile akilli arama ve filtreleme', AppColors.realEstateGradient),
    _Service(Icons.directions_car, 'Arac Satisi', 'Ikinci el ve sifir arac ilanlari, galeri yonetimi, detayli filtreleme', AppColors.carSalesGradient),
    _Service(Icons.car_rental, 'Arac Kiralama', 'Gunluk ve uzun sureli arac kiralama, filo yonetimi, online rezervasyon', AppColors.rentalGradient),
    _Service(Icons.shopping_bag, 'Market & Magaza', 'Market alisverisi kapiniza gelsin, magaza urunleri, hizli teslimat', AppColors.marketGradient),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: ContentWrapper(
        child: Column(
          children: [
            const SectionHeader(title: 'Hizmetlerimiz', subtitle: 'Her ihtiyaciniz icin tek platform'),
            ResponsiveBuilder(
              builder: (context, device, width) {
                final crossCount = device == DeviceType.mobile ? 1 : (device == DeviceType.tablet ? 2 : 4);
                final ratio = device == DeviceType.mobile ? 2.5 : 0.82;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: ratio,
                  ),
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final s = _services[index];
                    return GlassCard(
                      gradientColors: s.gradient,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // Gradient accent bar
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: s.gradient),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: s.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [BoxShadow(color: s.gradient.first.withAlpha(50), blurRadius: 20, spreadRadius: 2)],
                                    ),
                                    child: Icon(s.icon, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(s.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15), textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  Text(s.desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: (index * 80).ms).fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Service {
  final IconData icon;
  final String title, desc;
  final List<Color> gradient;
  const _Service(this.icon, this.title, this.desc, this.gradient);
}
