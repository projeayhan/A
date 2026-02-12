import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/responsive/responsive_builder.dart';
import '../widgets/section_header.dart';
import '../widgets/glass_card.dart';

class TechnologySection extends StatelessWidget {
  const TechnologySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: ContentWrapper(
        child: Column(
          children: [
            const SectionHeader(title: 'Teknoloji', subtitle: 'En son teknolojilerle gelistirildi'),
            // Orbit graphic
            const _OrbitGraphic(),
            const SizedBox(height: 48),
            // Counters row
            ResponsiveBuilder(
              builder: (context, device, width) {
                final counters = [
                  _CounterData(8, 'Hizmet'),
                  _CounterData(5, 'Panel'),
                  _CounterData(3, 'Uygulama'),
                  _CounterData(0, '7/24 AI'),
                ];

                return Row(
                  children: counters.asMap().entries.map((e) {
                    final c = e.value;
                    final fontSize = device == DeviceType.mobile ? 24.0 : 36.0;
                    final labelSize = device == DeviceType.mobile ? 11.0 : 14.0;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: e.key > 0 ? 8 : 0),
                        child: GlassCard(
                          padding: EdgeInsets.symmetric(vertical: device == DeviceType.mobile ? 16 : 24, horizontal: 8),
                          child: Column(
                            children: [
                              if (c.value == 0)
                                Text('7/24', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: fontSize))
                              else
                                TweenAnimationBuilder<int>(
                                  tween: IntTween(begin: 0, end: c.value),
                                  duration: const Duration(seconds: 2),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, _) => Text(
                                    '$val+',
                                    style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: fontSize),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(c.label, style: TextStyle(color: AppColors.textMuted, fontSize: labelSize), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(duration: 600.ms);
              },
            ),
            const SizedBox(height: 40),
            // Tech features
            ResponsiveBuilder(
              builder: (context, device, width) {
                final features = [
                  _TechFeature(Icons.psychology, 'Yapay Zeka', 'OpenAI destekli akilli asistan, dogal dil ile siparis ve oneri', [AppColors.primary, AppColors.cyan]),
                  _TechFeature(Icons.speed, 'Gercek Zamanli', 'Canli siparis takibi, anlik bildirimler, sofor konumu', [AppColors.green, AppColors.cyan]),
                  _TechFeature(Icons.devices, 'Coklu Platform', 'iOS, Android, Web - tek kod tabani, her yerde calisin', [AppColors.orange, const Color(0xFFFBBF24)]),
                  _TechFeature(Icons.record_voice_over, 'Sesli Komut', 'Telsiz modu ile konusarak siparis, iptal ve takip', [AppColors.pink, const Color(0xFFF472B6)]),
                  _TechFeature(Icons.shield, 'Guvenlik', 'Uctan uca sifreleme, guvenli odeme altyapisi', [AppColors.cyan, AppColors.primary]),
                  _TechFeature(Icons.cloud, 'Bulut Altyapisi', 'Supabase ile olceklenebilir, hizli ve guvenilir', [const Color(0xFF3B82F6), const Color(0xFF60A5FA)]),
                ];

                final crossCount = device == DeviceType.mobile ? 1 : (device == DeviceType.tablet ? 2 : 3);
                final ratio = device == DeviceType.mobile ? 3.2 : 1.6;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: ratio,
                  ),
                  itemCount: features.length,
                  itemBuilder: (context, index) {
                    final f = features[index];
                    return GlassCard(
                      gradientColors: f.gradient,
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: f.gradient),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: f.gradient.first.withAlpha(40), blurRadius: 16)],
                            ),
                            child: Icon(f.icon, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(f.desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: (index * 100).ms).fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
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

class _OrbitGraphic extends StatefulWidget {
  const _OrbitGraphic();

  @override
  State<_OrbitGraphic> createState() => _OrbitGraphicState();
}

class _OrbitGraphicState extends State<_OrbitGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _outerItems = [
    _OrbitItem(Icons.restaurant, AppColors.foodGradient),
    _OrbitItem(Icons.local_taxi, AppColors.taxiGradient),
    _OrbitItem(Icons.real_estate_agent, AppColors.realEstateGradient),
    _OrbitItem(Icons.directions_car, AppColors.carSalesGradient),
    _OrbitItem(Icons.car_rental, AppColors.rentalGradient),
    _OrbitItem(Icons.shopping_bag, AppColors.marketGradient),
  ];

  static const _innerItems = [
    _OrbitItem(Icons.psychology, [AppColors.primary, AppColors.cyan]),
    _OrbitItem(Icons.shield, [AppColors.cyan, AppColors.primary]),
    _OrbitItem(Icons.cloud, [Color(0xFF3B82F6), Color(0xFF60A5FA)]),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final outerRadius = isMobile ? 105.0 : 140.0;
    final innerRadius = outerRadius * 0.55;
    final containerSize = outerRadius * 2 + 70;

    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: outerRadius * 2, height: outerRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withAlpha(25), width: 1),
                ),
              ),
              // Inner ring
              Container(
                width: innerRadius * 2, height: innerRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cyan.withAlpha(20), width: 1),
                ),
              ),
              // Center logo
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 24, spreadRadius: 4)],
                ),
                child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24))),
              ),
              // Outer orbit items
              ..._outerItems.asMap().entries.map((e) {
                final angle = _controller.value * 2 * pi + (e.key * 2 * pi / _outerItems.length);
                return Transform.translate(
                  offset: Offset(cos(angle) * outerRadius, sin(angle) * outerRadius),
                  child: _OrbitIcon(gradient: e.value.gradient, icon: e.value.icon, size: 38),
                );
              }),
              // Inner orbit items (counter-clockwise)
              ..._innerItems.asMap().entries.map((e) {
                final angle = -_controller.value * 2 * pi + (e.key * 2 * pi / _innerItems.length);
                return Transform.translate(
                  offset: Offset(cos(angle) * innerRadius, sin(angle) * innerRadius),
                  child: _OrbitIcon(gradient: e.value.gradient, icon: e.value.icon, size: 32),
                );
              }),
            ],
          );
        },
      ),
    ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}

class _OrbitIcon extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final double size;
  const _OrbitIcon({required this.gradient, required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: gradient.first.withAlpha(40), blurRadius: 12)],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class _OrbitItem {
  final IconData icon;
  final List<Color> gradient;
  const _OrbitItem(this.icon, this.gradient);
}

class _CounterData {
  final int value;
  final String label;
  const _CounterData(this.value, this.label);
}

class _TechFeature {
  final IconData icon;
  final String title, desc;
  final List<Color> gradient;
  const _TechFeature(this.icon, this.title, this.desc, this.gradient);
}
