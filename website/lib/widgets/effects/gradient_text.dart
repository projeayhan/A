import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;
  final TextAlign? textAlign;

  const GradientText({
    super.key,
    required this.text,
    required this.style,
    required this.colors,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
      ).createShader(bounds),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
