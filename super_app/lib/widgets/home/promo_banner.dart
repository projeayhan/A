import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/banner_provider.dart';

// Banner için optimize edilmiş resim boyutları
const int _bannerWidth = 800;
const int _bannerHeight = 400;

/// Resim URL'ini banner boyutlarına göre optimize eder
/// Supabase Storage için transformation parametreleri ekler
String _getOptimizedImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=$_bannerWidth';
  }

  // Supabase Storage URL'i ise transformation ekle
  if (url.contains('supabase') && url.contains('/storage/')) {
    final uri = Uri.parse(url);
    // /object/public/ yerine /render/image/public/ kullan (transformation için)
    String path = uri.path;
    if (path.contains('/object/public/')) {
      path = path.replaceFirst('/object/public/', '/render/image/public/');
    }
    return uri.replace(
      path: path,
      queryParameters: {
        ...uri.queryParameters,
        'width': _bannerWidth.toString(),
        'height': _bannerHeight.toString(),
        'resize': 'cover',
        'quality': '80',
      },
    ).toString();
  }

  return url;
}

class PromoBanner extends ConsumerStatefulWidget {
  const PromoBanner({super.key});

  @override
  ConsumerState<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends ConsumerState<PromoBanner> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(int bannerCount) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients && bannerCount > 1 && mounted) {
        final nextPage = (_currentPage + 1) % bannerCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  void _resumeAutoScroll(int bannerCount) {
    if (bannerCount > 1) {
      _startAutoScroll(bannerCount);
    }
  }

  void _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider);

    return bannersAsync.when(
      loading: () => _buildPlaceholder(),
      error: (_, __) => _buildDefaultAppBanner(),
      data: (banners) {
        if (banners.isEmpty) {
          return _buildDefaultAppBanner();
        }
        if (banners.length == 1) {
          return _buildAppBannerItem(banners.first);
        }
        return _buildAppBannerCarousel(banners);
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey[300],
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildDefaultAppBanner() {
    return _buildAppBannerContent(
      imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=$_bannerWidth',
      title: 'İlk siparişe özel ',
      highlight: '%50 indirim',
      subtitle: 'Hemen Keşfet',
      onTap: null,
    );
  }

  Widget _buildAppBannerItem(AppBanner banner) {
    return _buildAppBannerContent(
      imageUrl: banner.imageUrl,
      title: banner.title,
      highlight: null,
      subtitle: banner.description ?? 'Hemen Keşfet',
      onTap: banner.linkUrl != null ? () => _openLink(banner.linkUrl) : null,
    );
  }

  Widget _buildAppBannerCarousel(List<AppBanner> banners) {
    // Otomatik kaydırmayı başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _autoScrollTimer == null) {
        _startAutoScroll(banners.length);
      }
    });

    return GestureDetector(
      onPanDown: (_) => _stopAutoScroll(),
      onPanEnd: (_) => _resumeAutoScroll(banners.length),
      onPanCancel: () => _resumeAutoScroll(banners.length),
      child: Column(
        children: [
          SizedBox(
            height: 176,
            child: PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final banner = banners[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildAppBannerContent(
                    imageUrl: banner.imageUrl,
                    title: banner.title,
                    highlight: null,
                    subtitle: banner.description ?? 'Hemen Keşfet',
                    onTap: banner.linkUrl != null
                        ? () => _openLink(banner.linkUrl)
                        : null,
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
              banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentPage == index
                      ? AppColors.primary
                      : Colors.grey[300],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBannerContent({
    required String? imageUrl,
    required String title,
    String? highlight,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 176,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Image - otomatik boyutlandırma ile
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                _getOptimizedImageUrl(imageUrl),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: _bannerWidth,
                cacheHeight: _bannerHeight,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.8),
                          const Color(0xFF60A5FA),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Gradient overlays
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E3A5F).withValues(alpha: 0.8),
                    AppColors.primary.withValues(alpha: 0.4),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),

            // Badge
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'SÜPER FIRSAT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              left: 20,
              bottom: 20,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlight != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          TextSpan(
                            text: highlight,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFACC15),
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
