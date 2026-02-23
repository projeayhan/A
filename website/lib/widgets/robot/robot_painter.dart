import 'dart:math';
import 'package:flutter/material.dart';

enum RobotExpression { normal, happy, winking, excited }

enum RobotProp { none, phone, tray, shoppingBag, taxiCap, key, briefcase, scooter }

class RobotPainter extends CustomPainter {
  final double leftArmAngle;
  final double rightArmAngle;
  final double leftLegAngle;
  final double rightLegAngle;
  final double headTilt;
  final double mouthOpen; // 0.0 - 1.0
  final double bodyOffsetY;
  final RobotExpression expression;
  final RobotProp prop;
  final Color glowColor;
  final double glowIntensity;

  RobotPainter({
    this.leftArmAngle = 0,
    this.rightArmAngle = 0,
    this.leftLegAngle = 0,
    this.rightLegAngle = 0,
    this.headTilt = 0,
    this.mouthOpen = 0,
    this.bodyOffsetY = 0,
    this.expression = RobotExpression.normal,
    this.prop = RobotProp.none,
    this.glowColor = const Color(0xFF00D4FF),
    this.glowIntensity = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + bodyOffsetY;
    final scale = size.width / 120; // base design is 120 wide

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);

    // Glow
    _drawGlow(canvas);

    // Legs
    _drawLeg(canvas, -15, 20, leftLegAngle, isLeft: true);
    _drawLeg(canvas, 15, 20, rightLegAngle, isLeft: false);

    // Body
    _drawBody(canvas);

    // Arms
    _drawArm(canvas, -30, -5, leftArmAngle, isLeft: true);
    _drawArm(canvas, 30, -5, rightArmAngle, isLeft: false);

    // Props (drawn relative to hands)
    if (prop != RobotProp.none) _drawProp(canvas);

    // Head
    canvas.save();
    canvas.rotate(headTilt);
    _drawHead(canvas);
    canvas.restore();

    canvas.restore();
  }

  void _drawGlow(Canvas canvas) {
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.15 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(Offset.zero, 45, glowPaint);
  }

  void _drawBody(Canvas canvas) {
    // Main body
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-22, -20, 44, 40),
      const Radius.circular(12),
    );
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
      ).createShader(const Rect.fromLTWH(-22, -20, 44, 40));
    canvas.drawRRect(bodyRect, bodyPaint);

    // Body border
    final borderPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(bodyRect, borderPaint);

    // Chest light
    final chestPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(const Offset(0, -5), 4, chestPaint);
    canvas.drawCircle(const Offset(0, -5), 3, Paint()..color = Colors.white.withValues(alpha: 0.9));

    // Belly panel
    final panelRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, 2, 24, 12),
      const Radius.circular(4),
    );
    canvas.drawRRect(panelRect, Paint()..color = const Color(0xFF0F1623));
    // Panel lines
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-8.0 + i * 8, 5),
        Offset(-8.0 + i * 8, 11),
        Paint()
          ..color = glowColor.withValues(alpha: 0.4)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawHead(Canvas canvas) {
    // Head base
    final headRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-20, -50, 40, 30),
      const Radius.circular(14),
    );
    final headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A4557), Color(0xFF2D3748)],
      ).createShader(const Rect.fromLTWH(-20, -50, 40, 30));
    canvas.drawRRect(headRect, headPaint);

    // Head border
    canvas.drawRRect(
      headRect,
      Paint()
        ..color = glowColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Antenna
    canvas.drawLine(
      const Offset(0, -50),
      const Offset(0, -58),
      Paint()
        ..color = const Color(0xFF4A5568)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(0, -59),
      3,
      Paint()..color = glowColor.withValues(alpha: 0.8),
    );
    canvas.drawCircle(
      const Offset(0, -59),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    // Eyes
    _drawEyes(canvas);

    // Mouth
    _drawMouth(canvas);
  }

  void _drawEyes(Canvas canvas) {
    final leftEyeCenter = const Offset(-8, -38);
    final rightEyeCenter = const Offset(8, -38);

    switch (expression) {
      case RobotExpression.normal:
        _drawNormalEye(canvas, leftEyeCenter);
        _drawNormalEye(canvas, rightEyeCenter);
        break;
      case RobotExpression.happy:
        _drawHappyEye(canvas, leftEyeCenter);
        _drawHappyEye(canvas, rightEyeCenter);
        break;
      case RobotExpression.winking:
        _drawNormalEye(canvas, leftEyeCenter);
        _drawWinkEye(canvas, rightEyeCenter);
        break;
      case RobotExpression.excited:
        _drawExcitedEye(canvas, leftEyeCenter);
        _drawExcitedEye(canvas, rightEyeCenter);
        break;
    }
  }

  void _drawNormalEye(Canvas canvas, Offset center) {
    // Outer
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF0F1623));
    // Iris
    canvas.drawCircle(center, 4.5, Paint()..color = glowColor);
    // Pupil
    canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFF0F1623));
    // Highlight
    canvas.drawCircle(
      center + const Offset(1.5, -1.5),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _drawHappyEye(Canvas canvas, Offset center) {
    final path = Path()
      ..moveTo(center.dx - 5, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - 5, center.dx + 5, center.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawWinkEye(Canvas canvas, Offset center) {
    canvas.drawLine(
      center + const Offset(-4, 0),
      center + const Offset(4, 0),
      Paint()
        ..color = glowColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawExcitedEye(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF0F1623));
    canvas.drawCircle(center, 5.5, Paint()..color = glowColor);
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF0F1623));
    canvas.drawCircle(
      center + const Offset(2, -2),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _drawMouth(Canvas canvas) {
    final mouthY = -28.0;
    if (mouthOpen > 0.1) {
      // Open mouth
      final height = 4.0 * mouthOpen;
      final mouthRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(-6, mouthY - height / 2, 12, height),
        Radius.circular(height / 2),
      );
      canvas.drawRRect(mouthRect, Paint()..color = const Color(0xFF0F1623));
      // Tongue hint
      if (mouthOpen > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-3, mouthY, 6, height * 0.4),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFFE53E3E).withValues(alpha: 0.6),
        );
      }
    } else {
      // Closed smile
      final path = Path()
        ..moveTo(-6, mouthY)
        ..quadraticBezierTo(0, mouthY + 3, 6, mouthY);
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor.withValues(alpha: 0.5)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawArm(Canvas canvas, double x, double y, double angle, {required bool isLeft}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    // Upper arm
    final armPaint = Paint()..color = const Color(0xFF2D3748);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, 0, 8, 22),
        const Radius.circular(4),
      ),
      armPaint,
    );

    // Joint
    canvas.drawCircle(
      const Offset(0, 22),
      4,
      Paint()..color = const Color(0xFF4A5568),
    );

    // Hand
    canvas.drawCircle(
      const Offset(0, 28),
      5,
      Paint()..color = const Color(0xFF4A5568),
    );
    // Hand glow
    canvas.drawCircle(
      const Offset(0, 28),
      3,
      Paint()..color = glowColor.withValues(alpha: 0.2),
    );

    canvas.restore();
  }

  void _drawLeg(Canvas canvas, double x, double y, double angle, {required bool isLeft}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    // Upper leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, 0, 10, 18),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF2D3748),
    );

    // Knee joint
    canvas.drawCircle(
      const Offset(0, 18),
      3.5,
      Paint()..color = const Color(0xFF4A5568),
    );

    // Lower leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, 20, 8, 14),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF1A202C),
    );

    // Foot
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(isLeft ? -6 : -3, 34, 9, 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = const Color(0xFF4A5568),
    );

    canvas.restore();
  }

  void _drawProp(Canvas canvas) {
    switch (prop) {
      case RobotProp.phone:
        _drawPhone(canvas);
        break;
      case RobotProp.tray:
        _drawTray(canvas);
        break;
      case RobotProp.shoppingBag:
        _drawShoppingBag(canvas);
        break;
      case RobotProp.taxiCap:
        _drawTaxiCap(canvas);
        break;
      case RobotProp.key:
        _drawKey(canvas);
        break;
      case RobotProp.briefcase:
        _drawBriefcase(canvas);
        break;
      case RobotProp.scooter:
        _drawScooter(canvas);
        break;
      case RobotProp.none:
        break;
    }
  }

  void _drawPhone(Canvas canvas) {
    canvas.save();
    canvas.translate(30 + sin(rightArmAngle) * 10, 20);
    canvas.rotate(rightArmAngle * 0.3);
    // Phone body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -8, 10, 16),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1A1A2E),
    );
    // Screen
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -6, 8, 12),
        const Radius.circular(1),
      ),
      Paint()..color = glowColor.withValues(alpha: 0.3),
    );
    canvas.restore();
  }

  void _drawTray(Canvas canvas) {
    canvas.save();
    canvas.translate(0, -5 + sin(rightArmAngle) * 3);
    // Tray
    final trayPath = Path()
      ..moveTo(-18, 0)
      ..lineTo(-15, -2)
      ..lineTo(15, -2)
      ..lineTo(18, 0)
      ..close();
    canvas.drawPath(trayPath, Paint()..color = const Color(0xFF8B7355));
    // Food items
    canvas.drawCircle(const Offset(-6, -5), 3, Paint()..color = const Color(0xFFE53E3E));
    canvas.drawCircle(const Offset(4, -5), 3, Paint()..color = const Color(0xFFF6AD55));
    canvas.restore();
  }

  void _drawShoppingBag(Canvas canvas) {
    canvas.save();
    canvas.translate(-32 + sin(leftArmAngle) * 5, 18);
    // Bag
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5, -3, 10, 12),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0xFF34D399),
    );
    // Handle
    final handlePath = Path()
      ..moveTo(-3, -3)
      ..quadraticBezierTo(0, -8, 3, -3);
    canvas.drawPath(
      handlePath,
      Paint()
        ..color = const Color(0xFF34D399)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  void _drawTaxiCap(Canvas canvas) {
    // Cap on head
    canvas.save();
    canvas.rotate(headTilt);
    // Brim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-22, -52, 44, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFBBF24),
    );
    // Cap dome
    final capPath = Path()
      ..moveTo(-16, -52)
      ..quadraticBezierTo(0, -62, 16, -52)
      ..close();
    canvas.drawPath(capPath, Paint()..color = const Color(0xFFFBBF24));
    canvas.restore();
  }

  void _drawKey(Canvas canvas) {
    canvas.save();
    canvas.translate(32 + sin(rightArmAngle) * 8, 22);
    canvas.rotate(rightArmAngle * 0.5);
    // Key ring
    canvas.drawCircle(
      Offset.zero,
      4,
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Key shaft
    canvas.drawLine(
      const Offset(4, 0),
      const Offset(12, 0),
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // Key teeth
    canvas.drawLine(
      const Offset(10, 0),
      const Offset(10, 3),
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      const Offset(12, 0),
      const Offset(12, 3),
      Paint()
        ..color = const Color(0xFFD4AF37)
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  void _drawBriefcase(Canvas canvas) {
    canvas.save();
    canvas.translate(-32 + sin(leftArmAngle) * 5, 22);
    // Case body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -2, 14, 10),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF8B6914),
    );
    // Handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -5, 6, 4),
        const Radius.circular(2),
      ),
      Paint()
        ..color = const Color(0xFF8B6914)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Lock
    canvas.drawCircle(
      const Offset(0, 3),
      1.5,
      Paint()..color = const Color(0xFFD4AF37),
    );
    canvas.restore();
  }

  void _drawScooter(Canvas canvas) {
    canvas.save();
    canvas.translate(0, 42);
    // Wheels
    canvas.drawCircle(const Offset(-15, 5), 6, Paint()..color = const Color(0xFF2D3748));
    canvas.drawCircle(const Offset(-15, 5), 3, Paint()..color = const Color(0xFF4A5568));
    canvas.drawCircle(const Offset(15, 5), 6, Paint()..color = const Color(0xFF2D3748));
    canvas.drawCircle(const Offset(15, 5), 3, Paint()..color = const Color(0xFF4A5568));
    // Frame
    canvas.drawLine(
      const Offset(-15, 0),
      const Offset(15, 0),
      Paint()
        ..color = const Color(0xFF22C55E)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Deck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -3, 20, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF22C55E),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RobotPainter oldDelegate) {
    return leftArmAngle != oldDelegate.leftArmAngle ||
        rightArmAngle != oldDelegate.rightArmAngle ||
        leftLegAngle != oldDelegate.leftLegAngle ||
        rightLegAngle != oldDelegate.rightLegAngle ||
        headTilt != oldDelegate.headTilt ||
        mouthOpen != oldDelegate.mouthOpen ||
        bodyOffsetY != oldDelegate.bodyOffsetY ||
        expression != oldDelegate.expression ||
        prop != oldDelegate.prop ||
        glowColor != oldDelegate.glowColor ||
        glowIntensity != oldDelegate.glowIntensity;
  }
}
