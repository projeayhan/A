import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnimatedCounter extends StatefulWidget {
  final int targetValue;
  final String suffix;
  final String label;
  final Color color;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.targetValue,
    this.suffix = '',
    required this.label,
    required this.color,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(
      begin: 0,
      end: widget.targetValue.toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_animation.value.toInt()}${widget.suffix}',
              style: GoogleFonts.inter(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: widget.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        );
      },
    );
  }
}
