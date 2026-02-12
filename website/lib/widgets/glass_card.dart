import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;

  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.borderRadius = 20, this.gradientColors, this.onTap});

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradientColors ?? [AppColors.primary, AppColors.cyan];
    return MouseRegion(
      onEnter: (_) { setState(() => _isHovered = true); _shimmerController.repeat(); },
      onExit: (_) { setState(() => _isHovered = false); _shimmerController.stop(); },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: _isHovered ? (Matrix4.identity()..scale(1.02)..translate(0.0, -4.0)) : Matrix4.identity(),
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  gradient: _isHovered
                      ? SweepGradient(
                          colors: [
                            colors.first.withAlpha(10),
                            colors.first.withAlpha(180),
                            colors.last.withAlpha(180),
                            colors.first.withAlpha(10),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                          transform: GradientRotation(_shimmerController.value * 2 * pi),
                        )
                      : null,
                  color: _isHovered ? null : AppColors.glassBorder,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius - 1.5),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: widget.padding,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isHovered
                              ? [AppColors.glassFillHover, AppColors.glassFill]
                              : [AppColors.glassFill, const Color(0x05FFFFFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(widget.borderRadius - 1.5),
                        boxShadow: _isHovered
                            ? [
                                BoxShadow(color: colors.first.withAlpha(25), blurRadius: 30, spreadRadius: 5),
                                BoxShadow(color: colors.last.withAlpha(10), blurRadius: 60),
                              ]
                            : null,
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
