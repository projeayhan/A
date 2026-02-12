import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/responsive/responsive_builder.dart';
import '../widgets/section_header.dart';

class AiShowcaseSection extends StatelessWidget {
  const AiShowcaseSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: ContentWrapper(
        child: Column(
          children: [
            const SectionHeader(title: 'Yapay Zeka Asistani', subtitle: 'Konusarak siparis verin, oneriler alin'),
            ResponsiveBuilder(
              builder: (context, device, width) {
                if (device == DeviceType.desktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: _PhoneMockup(child: _ChatContent()),
                        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.05, end: 0),
                      ),
                      const SizedBox(width: 48),
                      Expanded(child: _FeatureList()),
                    ],
                  );
                }
                return Column(
                  children: [
                    Center(
                      child: _PhoneMockup(child: _ChatContent()),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0),
                    const SizedBox(height: 40),
                    _FeatureList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final Widget child;
  const _PhoneMockup({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 540,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.surfaceLight, width: 3),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withAlpha(15), blurRadius: 40, spreadRadius: 8),
          BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 30),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Column(
          children: [
            // Notch area
            Container(
              height: 32,
              color: AppColors.surface,
              child: Center(
                child: Container(
                  width: 80, height: 4,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            Expanded(child: child),
            // Home indicator
            Container(
              height: 24,
              color: AppColors.surface,
              child: Center(
                child: Container(
                  width: 50, height: 4,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatContent extends StatefulWidget {
  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
  final _messages = <_ChatMsg>[];
  int _currentIndex = 0;
  Timer? _timer;

  static const _demoMessages = [
    _ChatMsg('Bana yakin restoranlari goster', true),
    _ChatMsg('Yakininizdaki en populer 3 restoran:\n1. Lezzet Duragi  4.8\n2. Kebapci Mehmet  4.7\n3. Pizza House  4.6', false),
    _ChatMsg('Lezzet Duragi\'ndan Adana Kebap istiyorum', true),
    _ChatMsg('Adana Kebap (45 TL) sepetinize eklendi! Siparis onaylansin mi?', false),
    _ChatMsg('Evet, siparis ver', true),
    _ChatMsg('Siparisiz olusturuldu! Tahmini teslimat: 25 dk', false),
  ];

  @override
  void initState() {
    super.initState();
    _addNextMessage();
  }

  void _addNextMessage() {
    if (_currentIndex >= _demoMessages.length) {
      _timer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() { _messages.clear(); _currentIndex = 0; });
        _addNextMessage();
      });
      return;
    }
    _timer = Timer(Duration(milliseconds: _currentIndex == 0 ? 500 : 1500), () {
      if (mounted) {
        setState(() => _messages.add(_demoMessages[_currentIndex]));
        _currentIndex++;
        _addNextMessage();
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SuperCyp AI', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('Aktif', style: TextStyle(color: AppColors.green, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemBuilder: (context, index) => _ChatBubble(msg: _messages[index])
                  .animate().fadeIn(duration: 300.ms).slideX(begin: _messages[index].isUser ? 0.1 : -0.1, end: 0),
            ),
          ),
          // Input bar
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.mic, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Mesaj yazin veya konusun...', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
                Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  const _ChatMsg(this.text, this.isUser);
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser)
            Container(
              width: 24, height: 24, margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan]),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.smart_toy, size: 14, color: Colors.white),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: msg.isUser ? AppColors.primary.withAlpha(40) : AppColors.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(msg.isUser ? 14 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 14),
                ),
                border: Border.all(color: msg.isUser ? AppColors.primary.withAlpha(60) : AppColors.glassBorder),
              ),
              child: Text(msg.text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      _Feature(Icons.record_voice_over, 'Telsiz Modu', 'Robot ikonuna basili tutun, konusun, birakin - siparisiniz hazir', [AppColors.primary, AppColors.cyan]),
      _Feature(Icons.restaurant_menu, 'Konusarak Siparis', 'Dogal dil ile yemek, market alisverisi yapay zekayla', AppColors.foodGradient),
      _Feature(Icons.recommend, 'Akilli Oneriler', 'Damak tadinizi ogrenir, kisiye ozel oneriler sunar', [AppColors.green, AppColors.cyan]),
      _Feature(Icons.delivery_dining, 'Canli Takip', 'Siparisi harita uzerinde gercek zamanli takip edin', AppColors.courierGradient),
      _Feature(Icons.cancel_outlined, 'Kolay Yonetim', 'Tek komutla siparis iptali, degisiklik ve daha fazlasi', [AppColors.pink, const Color(0xFFF472B6)]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Her Sey Sesli Komutla', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 22)),
        const SizedBox(height: 8),
        const Text('Yapay zeka asistanimiz tum hizmetlerimizde yaninizdadir', style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
        const SizedBox(height: 24),
        ...features.asMap().entries.map((e) {
          final f = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.glassFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: f.gradient),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: f.gradient.first.withAlpha(30), blurRadius: 12)],
                    ),
                    child: Icon(f.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(f.desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: (e.key * 150).ms).fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0);
        }),
      ],
    );
  }
}

class _Feature {
  final IconData icon;
  final String title, desc;
  final List<Color> gradient;
  const _Feature(this.icon, this.title, this.desc, this.gradient);
}
