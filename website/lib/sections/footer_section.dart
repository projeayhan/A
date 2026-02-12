import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/responsive/responsive_builder.dart';
import '../painters/wave_painter.dart';

class FooterSection extends StatefulWidget {
  final VoidCallback? onScrollTop;
  const FooterSection({super.key, this.onScrollTop});

  @override
  State<FooterSection> createState() => _FooterSectionState();
}

class _FooterSectionState extends State<FooterSection> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Wave divider
        SizedBox(
          height: 60,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) => CustomPaint(
              painter: WavePainter(animationValue: _waveController.value),
              size: Size.infinite,
            ),
          ),
        ),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: ContentWrapper(
            child: ResponsiveBuilder(
              builder: (context, device, width) {
                if (device == DeviceType.mobile) {
                  return Column(
                    children: [
                      _BrandBlock(),
                      const SizedBox(height: 32),
                      _LinksBlock(),
                      const SizedBox(height: 32),
                      _ContactBlock(),
                      const SizedBox(height: 32),
                      _BottomBar(onScrollTop: widget.onScrollTop),
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _BrandBlock()),
                        const SizedBox(width: 40),
                        Expanded(child: _LinksBlock()),
                        const SizedBox(width: 40),
                        Expanded(child: _ContactBlock()),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _BottomBar(onScrollTop: widget.onScrollTop),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text('SuperCyp', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Yapay zeka destekli super uygulama platformu. Yemek, taksi, market, emlak ve daha fazlasi tek uygulamada.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}

class _LinksBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final links = [
      _FooterLink('Hizmetler', null),
      _FooterLink('Uygulamalar', null),
      _FooterLink('Isletme Panelleri', null),
      _FooterLink('Teknoloji', null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sayfalar', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        ...links.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(l.label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        )),
      ],
    );
  }
}

class _ContactBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Iletisim', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        _ContactRow(Icons.email_outlined, 'info@supercyp.com'),
        const SizedBox(height: 8),
        _ContactRow(Icons.language, 'supercyp.com'),
        const SizedBox(height: 8),
        _ContactRow(Icons.location_on_outlined, 'Kibris'),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback? onScrollTop;
  const _BottomBar({this.onScrollTop});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(color: AppColors.glassBorder, height: 1),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '\u00a9 2026 SuperCyp. Tum haklari saklidir.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (onScrollTop != null)
              InkWell(
                onTap: onScrollTop,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Icon(Icons.keyboard_arrow_up, color: AppColors.textMuted, size: 20),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FooterLink {
  final String label;
  final String? url;
  const _FooterLink(this.label, this.url);
}
