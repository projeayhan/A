import 'package:flutter/material.dart';

class RobotPainter extends CustomPainter {
  final double glowIntensity;
  final bool isHovered;
  final Color glowColor;
  final double mouthOpen;
  final double leftArmAngle;
  final double rightArmAngle;
  final double headTilt;

  RobotPainter({
    required this.glowIntensity,
    this.isHovered = false,
    this.glowColor = const Color(0xFF00D4FF),
    this.mouthOpen = 0,
    this.leftArmAngle = 0.15,
    this.rightArmAngle = -0.15,
    this.headTilt = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final scale = size.height / 140;
    final metalDark = const Color(0xFF2d3436);
    final metalMid = const Color(0xFF636e72);
    final metalLight = const Color(0xFFb2bec3);
    final glow = glowColor;
    final glowDim = glow.withAlpha((150 * glowIntensity).toInt());

    // Legs (idle stance)
    _drawLeg(canvas, centerX - 10 * scale, size.height - 45 * scale, 0, metalDark, metalMid, glow, scale);
    _drawLeg(canvas, centerX + 10 * scale, size.height - 45 * scale, 0, metalDark, metalMid, glow, scale);

    // Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, size.height - 65 * scale), width: 32 * scale, height: 36 * scale),
      Radius.circular(6 * scale),
    );
    canvas.drawRRect(bodyRect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [metalLight, metalMid, metalDark]).createShader(bodyRect.outerRect));
    canvas.drawRRect(bodyRect, Paint()..color = glowDim..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Chest glow
    final chestCenter = Offset(centerX, size.height - 65 * scale);
    canvas.drawCircle(chestCenter, 10 * scale, Paint()..shader = RadialGradient(colors: [glow, glow.withAlpha((100 * glowIntensity).toInt()), Colors.transparent]).createShader(Rect.fromCircle(center: chestCenter, radius: 12 * scale)));
    canvas.drawCircle(chestCenter, 5 * scale, Paint()..color = glow);
    canvas.drawCircle(chestCenter, 2 * scale, Paint()..color = Colors.white);

    // Arms (animated)
    _drawArm(canvas, centerX - 20 * scale, size.height - 73 * scale, leftArmAngle, metalDark, metalMid, glow, scale);
    _drawArm(canvas, centerX + 20 * scale, size.height - 73 * scale, rightArmAngle, metalDark, metalMid, glow, scale);

    // Neck
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, size.height - 85 * scale), width: 10 * scale, height: 6 * scale), Radius.circular(2 * scale)), Paint()..color = metalDark);

    // Head (with tilt)
    canvas.save();
    final headCenterY = size.height - 105 * scale;
    canvas.translate(centerX, headCenterY);
    canvas.rotate(headTilt);
    canvas.translate(-centerX, -headCenterY);
    _drawHead(canvas, centerX, headCenterY, metalDark, metalMid, metalLight, glow, glowIntensity, isHovered, scale);
    canvas.restore();
  }

  void _drawLeg(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-4 * scale, 0, 8 * scale, 20 * scale), Radius.circular(2 * scale)), Paint()..shader = LinearGradient(colors: [mid, dark], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(Rect.fromLTWH(-4 * scale, 0, 8 * scale, 20 * scale)));
    canvas.drawCircle(Offset(0, 20 * scale), 4 * scale, Paint()..color = dark);
    canvas.drawCircle(Offset(0, 20 * scale), 2 * scale, Paint()..color = glow.withAlpha(100));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-3 * scale, 20 * scale, 6 * scale, 18 * scale), Radius.circular(2 * scale)), Paint()..color = dark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-6 * scale, 36 * scale, 12 * scale, 5 * scale), Radius.circular(2 * scale)), Paint()..color = mid);
    canvas.drawCircle(Offset(0, 38 * scale), 1.5 * scale, Paint()..color = glow);
    canvas.restore();
  }

  void _drawArm(Canvas canvas, double x, double y, double angle, Color dark, Color mid, Color glow, double scale) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, 5 * scale, Paint()..color = mid);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-3 * scale, 0, 6 * scale, 16 * scale), Radius.circular(2 * scale)), Paint()..color = dark);
    canvas.drawCircle(Offset(0, 16 * scale), 3 * scale, Paint()..color = mid);
    canvas.drawCircle(Offset(0, 16 * scale), 1.5 * scale, Paint()..color = glow.withAlpha(80));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-2.5 * scale, 16 * scale, 5 * scale, 14 * scale), Radius.circular(2 * scale)), Paint()..color = dark);
    canvas.drawCircle(Offset(0, 32 * scale), 4 * scale, Paint()..color = mid);
    canvas.drawCircle(Offset(0, 32 * scale), 1.5 * scale, Paint()..color = glow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.restore();
  }

  void _drawHead(Canvas canvas, double x, double y, Color dark, Color mid, Color light, Color glow, double intensity, bool hovered, double scale) {
    final headPath = Path()
      ..moveTo(x - 14 * scale, y + 12 * scale)
      ..lineTo(x - 18 * scale, y - 4 * scale)
      ..quadraticBezierTo(x - 18 * scale, y - 16 * scale, x - 8 * scale, y - 18 * scale)
      ..lineTo(x + 8 * scale, y - 18 * scale)
      ..quadraticBezierTo(x + 18 * scale, y - 16 * scale, x + 18 * scale, y - 4 * scale)
      ..lineTo(x + 14 * scale, y + 12 * scale)
      ..close();

    canvas.drawPath(headPath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, mid, dark]).createShader(Rect.fromCenter(center: Offset(x, y), width: 36 * scale, height: 32 * scale)));
    canvas.drawPath(headPath, Paint()..color = glow.withAlpha((100 * intensity).toInt())..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Visor
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 2 * scale), width: 28 * scale, height: 18 * scale), Radius.circular(4 * scale)), Paint()..color = const Color(0xFF0a0a0f));

    // Eyes
    if (hovered) {
      final leftEye = Path()..moveTo(x - 10 * scale, y)..quadraticBezierTo(x - 6 * scale, y - 5 * scale, x - 3 * scale, y);
      canvas.drawPath(leftEye, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
      final rightEye = Path()..moveTo(x + 3 * scale, y)..quadraticBezierTo(x + 6 * scale, y - 5 * scale, x + 10 * scale, y);
      canvas.drawPath(rightEye, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    } else {
      canvas.drawLine(Offset(x - 10 * scale, y - 2 * scale), Offset(x + 10 * scale, y - 2 * scale), Paint()..color = glow..strokeWidth = 2.5..strokeCap = StrokeCap.round..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * intensity));
      canvas.drawCircle(Offset(x - 5 * scale, y - 2 * scale), 1.5 * scale, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x + 5 * scale, y - 2 * scale), 1.5 * scale, Paint()..color = Colors.white);
    }

    // Mouth (talking animation)
    if (mouthOpen > 0.05) {
      final mouthHeight = 4 * scale * mouthOpen;
      final mouthWidth = 10 * scale * (0.6 + 0.4 * mouthOpen);
      final mouthY = y + 6 * scale;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, mouthY), width: mouthWidth, height: mouthHeight),
          Radius.circular(2 * scale),
        ),
        Paint()..color = glow.withAlpha((200 * intensity).toInt()),
      );
      // Inner mouth glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, mouthY), width: mouthWidth * 0.6, height: mouthHeight * 0.5),
          Radius.circular(1 * scale),
        ),
        Paint()..color = Colors.white.withAlpha((120 * mouthOpen).toInt()),
      );
    }

    // Antenna
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 23 * scale), width: 3 * scale, height: 10 * scale), Radius.circular(1.5 * scale)), Paint()..color = mid);
    canvas.drawCircle(Offset(x, y - 28 * scale), 4 * scale, Paint()..color = glow.withAlpha((200 * intensity).toInt())..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(x, y - 28 * scale), 2.5 * scale, Paint()..color = glow);
    canvas.drawCircle(Offset(x, y - 28 * scale), 1 * scale, Paint()..color = Colors.white);

    // Ears
    _drawEar(canvas, x - 20 * scale, y - 4 * scale, glow, intensity, scale);
    _drawEar(canvas, x + 20 * scale, y - 4 * scale, glow, intensity, scale);
  }

  void _drawEar(Canvas canvas, double x, double y, Color glow, double intensity, double scale) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 5 * scale, height: 14 * scale), Radius.circular(1.5 * scale)), Paint()..color = const Color(0xFF2d3436));
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(x, y - 4 * scale + (i * 4 * scale)), 1 * scale, Paint()..color = glow.withAlpha((150 * intensity).toInt()));
    }
  }

  @override
  bool shouldRepaint(RobotPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity ||
      oldDelegate.isHovered != isHovered ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.mouthOpen != mouthOpen ||
      oldDelegate.leftArmAngle != leftArmAngle ||
      oldDelegate.rightArmAngle != rightArmAngle ||
      oldDelegate.headTilt != headTilt;
}
