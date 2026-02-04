import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/banner_provider.dart';
import '../../screens/food/restaurant_detail_screen.dart';
import '../../screens/food/food_item_detail_screen.dart';
import '../../screens/store/store_detail_screen.dart';
import '../../screens/store/store_product_detail_screen.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_product_model.dart';

// Banner için optimize edilmiş resim boyutları
const int _bannerWidth = 800;
const int _bannerHeight = 400;

/// Resim URL'ini banner boyutlarına göre optimize eder
String _getOptimizedImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=$_bannerWidth';
  }

  // Supabase Storage URL'i ise transformation ekle
  if (url.contains('supabase') && url.contains('/storage/')) {
    final uri = Uri.parse(url);
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

/// Tüm hizmetler için kullanılabilir genel banner carousel widget'ı
class GenericBannerCarousel extends ConsumerStatefulWidget {
  final FutureProvider<List<AppBanner>> bannerProvider;
  final double height;
  final Color? primaryColor;
  final String? defaultTitle;
  final String? defaultSubtitle;
  final String? defaultImageUrl;

  const GenericBannerCarousel({
    super.key,
    required this.bannerProvider,
    this.height = 180,
    this.primaryColor,
    this.defaultTitle,
    this.defaultSubtitle,
    this.defaultImageUrl,
  });

  @override
  ConsumerState<GenericBannerCarousel> createState() =>
      _GenericBannerCarouselState();
}

class _GenericBannerCarouselState extends ConsumerState<GenericBannerCarousel> {
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

  /// Banner tıklandığında ilgili sayfaya yönlendirir
  Future<void> _onBannerTap(AppBanner banner) async {
    final linkType = banner.linkType;
    final linkId = banner.linkId;
    final linkUrl = banner.linkUrl;

    if (linkType == null && linkUrl == null) return;

    switch (linkType) {
      case 'restaurant':
        if (linkId != null) {
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

      case 'store':
        if (linkId != null) {
          try {
            final storeData = await Supabase.instance.client
                .from('merchants')
                .select()
                .eq('id', linkId)
                .maybeSingle();

            if (storeData != null && mounted) {
              final store = Store.fromMerchant(storeData);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreDetailScreen(store: store),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error loading store: $e');
          }
        }
        break;

      case 'product':
        if (linkId != null) {
          try {
            final productData = await Supabase.instance.client
                .from('products')
                .select('*, merchants(business_name)')
                .eq('id', linkId)
                .maybeSingle();

            if (productData != null && mounted) {
              final product = StoreProduct.fromJson(
                productData,
                storeName: productData['merchants']?['business_name'],
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreProductDetailScreen(product: product),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error loading product: $e');
          }
        }
        break;

      case 'external':
      default:
        if (linkUrl != null) {
          _openLink(linkUrl);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(widget.bannerProvider);

    return bannersAsync.when(
      loading: () => _buildPlaceholder(),
      error: (_, __) => _buildDefaultBanner(),
      data: (banners) {
        if (banners.isEmpty) {
          return _buildDefaultBanner();
        }
        if (banners.length == 1) {
          return _buildBannerItem(banners.first);
        }
        return _buildBannerCarousel(banners);
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[300],
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    if (widget.defaultTitle == null) {
      return const SizedBox.shrink();
    }
    return _buildBannerContent(
      imageUrl: widget.defaultImageUrl,
      title: widget.defaultTitle!,
      subtitle: widget.defaultSubtitle ?? 'Keşfet',
      onTap: null,
    );
  }

  Widget _buildBannerItem(AppBanner banner) {
    return _buildBannerContent(
      imageUrl: banner.imageUrl,
      title: banner.title,
      subtitle: banner.description ?? 'Hemen Keşfet',
      onTap: banner.hasLink ? () => _onBannerTap(banner) : null,
    );
  }

  Widget _buildBannerCarousel(List<AppBanner> banners) {
    // Otomatik kaydırmayı başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _autoScrollTimer == null) {
        _startAutoScroll(banners.length);
      }
    });

    final primaryColor = widget.primaryColor ?? AppColors.primary;

    return GestureDetector(
      onPanDown: (_) => _stopAutoScroll(),
      onPanEnd: (_) => _resumeAutoScroll(banners.length),
      onPanCancel: () => _resumeAutoScroll(banners.length),
      child: Column(
        children: [
          SizedBox(
            height: widget.height,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildBannerContent(
                    imageUrl: banner.imageUrl,
                    title: banner.title,
                    subtitle: banner.description ?? 'Hemen Keşfet',
                    onTap: banner.hasLink ? () => _onBannerTap(banner) : null,
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
                  color: _currentPage == index ? primaryColor : Colors.grey[300],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerContent({
    required String? imageUrl,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final primaryColor = widget.primaryColor ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
                          primaryColor.withValues(alpha: 0.8),
                          primaryColor.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),

            // Content
            Positioned(
              left: 16,
              bottom: 16,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                        size: 14,
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
