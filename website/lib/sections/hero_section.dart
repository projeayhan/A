import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../painters/mesh_gradient_painter.dart';
import '../widgets/animated_robot.dart';
import '../widgets/gradient_text.dart';
import '../widgets/glow_button.dart';

class HeroSection extends StatefulWidget {
  final VoidCallback? onExplore;
  const HeroSection({super.key, this.onExplore});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> with SingleTickerProviderStateMixin {
  late AnimationController _meshController;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return SizedBox(
      height: size.height,
      child: Stack(
        children: [
          // Mesh gradient background
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _meshController,
                builder: (context, _) => CustomPaint(
                  painter: MeshGradientPainter(animationValue: _meshController.value),
                ),
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Robot with speech bubble
                const _RobotWithSpeech(),
                const SizedBox(height: 24),
                Image.asset(
                  'assets/images/supercyp_logo.png',
                  width: isMobile ? 180 : 240,
                ),
                const SizedBox(height: 16),
                Text(
                  'Tek Uygulama, Sinirsiz Hizmet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: isMobile ? 16 : 20,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Yapay zeka destekli super uygulama platformu',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                const _CyclingTagline(),
                const SizedBox(height: 32),
                GlowButton(text: 'Kesfet', icon: Icons.arrow_downward_rounded, onPressed: widget.onExplore),
              ],
            ),
          ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
          // Scroll indicator
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: _ScrollIndicator(),
            ),
          ),
        ],
      ),
    );
  }
}

// Robot + cycling speech bubbles
class _RobotWithSpeech extends StatefulWidget {
  const _RobotWithSpeech();

  @override
  State<_RobotWithSpeech> createState() => _RobotWithSpeechState();
}

class _RobotWithSpeechState extends State<_RobotWithSpeech> {
  static const _messages = [
    _SpeechMsg(Icons.record_voice_over, 'Merhaba! Ben SuperCyp AI asistaniyim. Yemekten emlaga, taksiden arac kiralamaya kadar her konuda yardimci oluyorum!'),
    _SpeechMsg(Icons.touch_app, 'Beni kullanmak cok kolay: Robot ikonuna basili tutun, konusun, birakin. Ben hallederim!'),
    _SpeechMsg(Icons.restaurant_menu, '"Bana yakin restoranlari goster" deyin, en iyi secenekleri sunayim. Market alisverisini de ben hallederim!'),
    _SpeechMsg(Icons.real_estate_agent, 'Ev mi ariyorsunuz? "3+1 kiralik daire bul" deyin, size uygun emlak ilanlarini listelerim.'),
    _SpeechMsg(Icons.directions_car, 'Arac almak mi istiyorsunuz? "Satilik SUV goster" deyin, galeri ilanlarini aninda getireyim.'),
    _SpeechMsg(Icons.car_rental, 'Arac kiralamak icin "Yarin icin uygun araclar" deyin, fiyat ve modelleri karsilastirayim.'),
    _SpeechMsg(Icons.local_taxi, 'Taksi mi lazim? "Taksi cagir" deyin, en yakin soforu yonlendireyim ve canli takip edin.'),
    _SpeechMsg(Icons.shopping_bag, 'Magaza urunleri, market alisverisi, kurye teslimat... Tek komutla her sey kapinizda!'),
    _SpeechMsg(Icons.delivery_dining, 'Siparislerinizi canli takip edin. "Siparisin nerede?" diye sorun yeter!'),
    _SpeechMsg(Icons.cancel_outlined, '"Siparisi iptal et" deyin, aninda hallederim. Kolay ve hizli!'),
    _SpeechMsg(Icons.lightbulb, 'Sizi taniyor, damak tadinizi ve tercihlerinizi ogreniyorum. Her seferinde daha iyi oneriler!'),
  ];

  int _currentMsg = 0;
  int _charIndex = 0;
  bool _isTyping = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_charIndex < _messages[_currentMsg].text.length) {
        setState(() => _charIndex++);
      } else {
        timer.cancel();
        setState(() => _isTyping = false);
        // Pause then move to next
        _timer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          setState(() {
            _currentMsg = (_currentMsg + 1) % _messages.length;
            _charIndex = 0;
            _isTyping = true;
          });
          _startTyping();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final msg = _messages[_currentMsg];
    final visibleText = msg.text.substring(0, _charIndex);

    if (isMobile) {
      return Column(
        children: [
          AnimatedRobot(size: 150, isTalking: _isTyping),
          const SizedBox(height: 16),
          _SpeechBubble(icon: msg.icon, text: visibleText, isTyping: _isTyping, maxWidth: 320),
        ],
      );
    }

    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedRobot(size: 180, isTalking: _isTyping),
          const SizedBox(width: 20),
          _SpeechBubble(icon: msg.icon, text: visibleText, isTyping: _isTyping, maxWidth: 360),
        ],
      ),
    );
  }
}

class _SpeechMsg {
  final IconData icon;
  final String text;
  const _SpeechMsg(this.icon, this.text);
}

class _SpeechBubble extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isTyping;
  final double maxWidth;
  const _SpeechBubble({required this.icon, required this.text, required this.isTyping, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(text.isEmpty ? 'empty' : text.substring(0, min(10, text.length))),
        constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(200),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withAlpha(20), blurRadius: 20, spreadRadius: 2),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: text,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.5),
                    ),
                    if (isTyping)
                      TextSpan(
                        text: '|',
                        style: TextStyle(color: AppColors.cyan, fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CyclingTagline extends StatefulWidget {
  const _CyclingTagline();

  @override
  State<_CyclingTagline> createState() => _CyclingTaglineState();
}

class _CyclingTaglineState extends State<_CyclingTagline> {
  int _currentIndex = 0;
  Timer? _timer;

  static const _services = [
    'Yemek Siparisi',
    'Taksi Hizmeti',
    'Emlak Ilanlari',
    'Arac Kiralama',
    'Market Alisverisi',
    'Kurye Teslimat',
    'Arac Satisi',
    'Restoran Yonetimi',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() => _currentIndex = (_currentIndex + 1) % _services.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return SizedBox(
      height: isMobile ? 30 : 36,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          _services[_currentIndex],
          key: ValueKey(_currentIndex),
          style: TextStyle(color: AppColors.cyan, fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ScrollIndicator extends StatefulWidget {
  @override
  State<_ScrollIndicator> createState() => _ScrollIndicatorState();
}

class _ScrollIndicatorState extends State<_ScrollIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, sin(_controller.value * pi) * 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kesfet', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
