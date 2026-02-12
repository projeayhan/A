import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class GradientText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;
  const GradientText(this.text, {super.key, this.style, this.colors = const [AppColors.primary, AppColors.cyan, AppColors.primaryLight]});

  @override
  State<GradientText> createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
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
        final shift = _controller.value * 2;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: widget.colors,
            begin: Alignment(-1 + shift, 0),
            end: Alignment(1 + shift, 0),
            tileMode: TileMode.mirror,
          ).createShader(bounds),
          child: Text(widget.text, style: (widget.style ?? Theme.of(context).textTheme.displayLarge)?.copyWith(color: Colors.white)),
        );
      },
    );
  }
}
