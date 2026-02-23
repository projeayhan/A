import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AnimatedGradientBg extends StatefulWidget {
  final Widget child;

  const AnimatedGradientBg({super.key, required this.child});

  @override
  State<AnimatedGradientBg> createState() => _AnimatedGradientBgState();
}

class _AnimatedGradientBgState extends State<AnimatedGradientBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
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
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                sin(_controller.value * 2 * pi),
                cos(_controller.value * 2 * pi),
              ),
              end: Alignment(
                cos(_controller.value * 2 * pi + 1),
                sin(_controller.value * 2 * pi + 1),
              ),
              colors: [
                AppColors.backgroundDark,
                AppColors.surfaceDark,
                const Color(0xFF0C1222),
                AppColors.backgroundDark,
              ],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
