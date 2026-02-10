import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/car_sales/car_sales_models.dart';

// Custom painters
class BackgroundPainter extends CustomPainter {
  final bool isDark;
  final double animationValue;
  final double scrollOffset;

  BackgroundPainter({
    required this.isDark,
    required this.animationValue,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Animated circles in background
    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + i * 0.33) % 1.0;
      final x = size.width * (0.1 + 0.8 * math.sin(progress * math.pi * 2 + i));
      final y = (size.height * 0.2 - scrollOffset * 0.1).clamp(0, size.height * 0.5);
      final radius = 100.0 + 50 * math.sin(progress * math.pi * 2);

      paint.color = (isDark
          ? CarSalesColors.primary
          : CarSalesColors.primaryLight).withValues(alpha: 0.05);

      canvas.drawCircle(Offset(x, y + i * 100), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        scrollOffset != oldDelegate.scrollOffset;
  }
}

class CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw grid pattern
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
