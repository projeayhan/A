import 'dart:math';
import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool flipVertical;

  WavePainter({required this.animationValue, this.color = const Color(0xFF6366F1), this.flipVertical = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (flipVertical) {
      canvas.scale(1, -1);
      canvas.translate(0, -size.height);
    }

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 +
          sin((x / size.width * 2 * pi) + (animationValue * 2 * pi)) * 8 +
          sin((x / size.width * 4 * pi) + (animationValue * 2 * pi * 1.5)) * 4;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withAlpha(30), color.withAlpha(5)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}
