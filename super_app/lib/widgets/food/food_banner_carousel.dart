import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../screens/food/restaurant_detail_screen.dart';
import '../../screens/food/food_item_detail_screen.dart';

class FoodBannerCarousel extends StatefulWidget {
  final double height;
  final Duration autoScrollDuration;

  const FoodBannerCarousel({
    super.key,
    this.height = 160,
    this.autoScrollDuration = const Duration(seconds: 3),
  });

  @override
  State<FoodBannerCarousel> createState() => _FoodBannerCarouselState();
}

class _FoodBannerCarouselState extends State<FoodBannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    try {
      final response = await Supabase.instance.client
          .from('banners')
          .select()
          .eq('is_active', true)
          .eq('category', 'food')
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _banners = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        if (_banners.length > 1) {
          _startAutoScroll();
        }
      }
    } catch (e) {
      debugPrint('Error loading food banners: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(widget.autoScrollDuration, (timer) {
      if (_pageController.hasClients && _banners.isNotEmpty && mounted) {
        final nextPage = (_currentPage + 1) % _banners.length;
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

  void _resumeAutoScroll() {
    if (_banners.length > 1) {
      _startAutoScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onPanDown: (_) => _stopAutoScroll(),
      onPanEnd: (_) => _resumeAutoScroll(),
      onPanCancel: () => _resumeAutoScroll(),
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _banners.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final banner = _banners[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildBannerItem(banner),
                );
              },
            ),
          ),
          if (_banners.length > 1) ...[
            const SizedBox(height: 12),
            _buildPageIndicators(),
          ],
        ],
      ),
    );
  }

  void _onBannerTap(Map<String, dynamic> banner) async {
    final linkType = banner['link_type'] as String?;
    final linkId = banner['link_id'] as String?;
    final linkUrl = banner['link_url'] as String?;

    if (linkType == null && linkUrl == null) return;

    switch (linkType) {
      case 'restaurant':
        if (linkId != null) {
          // Restoran bilgilerini çek
          try {
            final restaurant = await Supabase.instance.client
                .from('merchants')
                .select()
                .eq('id', linkId)
                .maybeSingle();

            if (restaurant != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RestaurantDetailScreen(
                    restaurantId: linkId,
                    name: restaurant['business_name'] ?? '',
                    imageUrl: restaurant['logo_url'] ?? '',
                    rating: (restaurant['rating'] as num?)?.toDouble() ?? 4.5,
                    categories: restaurant['category_tags']?.toString() ?? '',
                    deliveryTime: '${restaurant['delivery_time'] ?? 30} dk',
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error loading restaurant: $e');
          }
        }
        break;

      case 'menu_item':
        if (linkId != null) {
          // Menu item ve restoran bilgilerini çek
          try {
            final menuItem = await Supabase.instance.client
                .from('menu_items')
                .select('*, merchants(business_name)')
                .eq('id', linkId)
                .maybeSingle();

            if (menuItem != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FoodItemDetailScreen(
                    itemId: linkId,
                    name: menuItem['name'] ?? '',
                    description: menuItem['description'] ?? '',
                    price: (menuItem['price'] as num?)?.toDouble() ?? 0,
                    imageUrl: menuItem['image_url'] ?? '',
                    rating: (menuItem['average_rating'] as num?)?.toDouble() ?? 4.5,
                    restaurantName: menuItem['merchants']?['business_name'] ?? '',
                    deliveryTime: '30-45 dk',
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error loading menu item: $e');
          }
        }
        break;

      case 'external':
        if (linkUrl != null) {
          final uri = Uri.tryParse(linkUrl);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;

      default:
        // link_url varsa external olarak aç
        if (linkUrl != null) {
          final uri = Uri.tryParse(linkUrl);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
    }
  }

  Widget _buildBannerItem(Map<String, dynamic> banner) {
    final imageUrl = banner['image_url'] as String?;
    final title = banner['title'] as String? ?? 'Özel Fırsat';
    final description = banner['description'] as String? ?? 'Hemen Keşfet';
    final hasLink = banner['link_type'] != null || banner['link_url'] != null;

    return GestureDetector(
      onTap: hasLink ? () => _onBannerTap(banner) : null,
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (imageUrl != null)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                memCacheHeight: 300,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Content
            Positioned(
              top: 20,
              left: 20,
              bottom: 20,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FIRSAT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  Row(
                    children: [
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: 0.8),
            const Color(0xFFFF8C5A),
          ],
        ),
      ),
      child: const Icon(Icons.restaurant, size: 48, color: Colors.white24),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _banners.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentPage == index
                ? const Color(0xFFFF6B35)
                : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
