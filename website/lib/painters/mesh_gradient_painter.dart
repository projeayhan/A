import 'dart:math';
import 'package:flutter/material.dart';

class MeshGradientPainter extends CustomPainter {
  final double animationValue;
  MeshGradientPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = [
      _Blob(0.3, 0.3, 200, const Color(0xFF6366F1), 0.0),
      _Blob(0.7, 0.4, 180, const Color(0xFF00D4FF), 1.0),
      _Blob(0.5, 0.7, 160, const Color(0xFF8B5CF6), 2.0),
      _Blob(0.2, 0.6, 140, const Color(0xFF00FF88), 3.0),
      _Blob(0.8, 0.2, 120, const Color(0xFFEC4899), 4.0),
    ];

    for (final blob in blobs) {
      final phase = animationValue * 2 * pi + blob.offset;
      final cx = size.width * blob.baseX + cos(phase * 0.7) * 60;
      final cy = size.height * blob.baseY + sin(phase * 0.5) * 40;
      final radius = blob.baseRadius + sin(phase * 1.3) * 20;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [blob.color.withAlpha(40), blob.color.withAlpha(10), Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(MeshGradientPainter oldDelegate) => true;
}

class _Blob {
  final double baseX, baseY, baseRadius;
  final Color color;
  final double offset;
  const _Blob(this.baseX, this.baseY, this.baseRadius, this.color, this.offset);
}
