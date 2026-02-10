import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/store_colors.dart';

class CampaignItem {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final List<Color> gradientColors;

  const CampaignItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.gradientColors,
  });

  // Veriler Supabase'den yüklenir
  static List<CampaignItem> get mockCampaigns => [];
}

class CampaignCarousel extends StatefulWidget {
  final List<CampaignItem> campaigns;
  final Function(CampaignItem)? onTap;

  const CampaignCarousel({
    super.key,
    required this.campaigns,
    this.onTap,
  });

  @override
  State<CampaignCarousel> createState() => _CampaignCarouselState();
}

class _CampaignCarouselState extends State<CampaignCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && mounted) {
        final nextPage = (_currentPage + 1) % widget.campaigns.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoPlay() {
    _timer?.cancel();
  }

  void _resumeAutoPlay() {
    if (widget.campaigns.length > 1) {
      _startAutoPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (_) => _stopAutoPlay(),
      onPanEnd: (_) => _resumeAutoPlay(),
      onPanCancel: () => _resumeAutoPlay(),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: widget.campaigns.length,
              itemBuilder: (context, index) {
              final campaign = widget.campaigns[index];
              return GestureDetector(
                onTap: () => widget.onTap?.call(campaign),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: campaign.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: campaign.gradientColors.first.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        bottom: -20,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: campaign.imageUrl,
                            width: 180,
                            height: 180,
                            fit: BoxFit.cover,
                            imageBuilder: (context, imageProvider) => Image(
                              image: imageProvider,
                              width: 180,
                              height: 180,
                              fit: BoxFit.cover,
                              color: Colors.white.withValues(alpha: 0.2),
                              colorBlendMode: BlendMode.overlay,
                            ),
                            placeholder: (_, __) => const SizedBox(width: 180, height: 180),
                            errorWidget: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              campaign.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: context.heading1Size + 4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              campaign.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: context.bodySize,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Keşfet',
                                style: TextStyle(
                                  color: campaign.gradientColors.first,
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.bodySmallSize,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.campaigns.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? StoreColors.primary
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
