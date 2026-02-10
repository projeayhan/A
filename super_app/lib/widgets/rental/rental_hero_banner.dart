import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RentalHeroBanner extends StatefulWidget {
  final double height;
  final Duration autoScrollDuration;

  const RentalHeroBanner({
    super.key,
    this.height = 280,
    this.autoScrollDuration = const Duration(seconds: 3),
  });

  @override
  State<RentalHeroBanner> createState() => _RentalHeroBannerState();
}

class _RentalHeroBannerState extends State<RentalHeroBanner> {
  final PageController _pageController = PageController();
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
          .eq('category', 'rental')
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _banners = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        // Birden fazla banner varsa otomatik kaydırmayı başlat
        if (_banners.length > 1) {
          _startAutoScroll();
        }
      }
    } catch (e) {
      debugPrint('Error loading rental banners: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(widget.autoScrollDuration, (timer) {
      if (_pageController.hasClients && _banners.isNotEmpty) {
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
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_banners.isEmpty) {
      return _buildDefaultBanner();
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
                return _buildBannerItem(banner);
              },
            ),
          ),
          if (_banners.length > 1) ...[
            const SizedBox(height: 16),
            _buildPageIndicators(),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800',
            fit: BoxFit.cover,
            memCacheWidth: 400,
            memCacheHeight: 200,
            placeholder: (_, __) => Container(
              color: Colors.grey[800],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.directions_car, size: 80, color: Colors.white24),
            ),
          ),
          _buildGradientOverlay(),
          _buildBannerContent('Premium Araç Kiralama', 'Lüks deneyim, uygun fiyat'),
        ],
      ),
    );
  }

  Widget _buildBannerItem(Map<String, dynamic> banner) {
    final imageUrl = banner['image_url'] as String?;
    final title = banner['title'] as String? ?? 'Araç Kiralama';
    final description = banner['description'] as String? ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 400,
            memCacheHeight: 200,
            placeholder: (_, __) => Container(
              color: Colors.grey[800],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.directions_car, size: 80, color: Colors.white24),
            ),
          )
        else
          Container(
            color: Colors.grey[800],
            child: const Icon(Icons.directions_car, size: 80, color: Colors.white24),
          ),

        // Gradient Overlay
        _buildGradientOverlay(),

        // Content
        _buildBannerContent(title, description),
      ],
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.6),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerContent(String title, String description) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF256AF4), Color(0xFF5B8DEF)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'PREMIUM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
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
                ? const Color(0xFF256AF4)
                : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
