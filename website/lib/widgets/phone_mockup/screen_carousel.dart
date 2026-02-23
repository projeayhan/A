import 'dart:async';
import 'package:flutter/material.dart';

class ScreenCarousel extends StatefulWidget {
  final List<Widget> screens;
  final Duration autoPlayInterval;

  const ScreenCarousel({
    super.key,
    required this.screens,
    this.autoPlayInterval = const Duration(seconds: 3),
  });

  @override
  State<ScreenCarousel> createState() => _ScreenCarouselState();
}

class _ScreenCarouselState extends State<ScreenCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    if (widget.screens.length <= 1) return;
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      final next = (_currentPage + 1) % widget.screens.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: widget.screens.length,
            itemBuilder: (_, index) => widget.screens[index],
          ),
        ),
        if (widget.screens.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.screens.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == _currentPage ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
