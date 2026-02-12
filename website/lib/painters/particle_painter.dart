import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  double x, y, vx, vy, radius, opacity;
  Particle({required this.x, required this.y, required this.vx, required this.vy, required this.radius, required this.opacity});
}

class ShootingStar {
  double x, y, vx, vy, life, maxLife, length;
  ShootingStar({required this.x, required this.y, required this.vx, required this.vy, required this.life, required this.maxLife, required this.length});
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final List<ShootingStar> shootingStars;
  final double animationValue;
  final Color color;

  ParticlePainter({required this.particles, this.shootingStars = const [], required this.animationValue, this.color = const Color(0xFF6366F1)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final connectionPaint = Paint()..strokeWidth = 0.5;
    const maxDist = 150.0;

    for (final p in particles) {
      paint.color = color.withAlpha((p.opacity * 255).toInt());
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }

    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final dx = particles[i].x - particles[j].x;
        final dy = particles[i].y - particles[j].y;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < maxDist) {
          final alpha = ((1 - dist / maxDist) * 0.15 * 255).toInt();
          connectionPaint.color = color.withAlpha(alpha);
          canvas.drawLine(Offset(particles[i].x, particles[i].y), Offset(particles[j].x, particles[j].y), connectionPaint);
        }
      }
    }

    // Shooting stars with glowing trails
    for (final s in shootingStars) {
      final progress = s.life / s.maxLife;
      final alpha = (progress < 0.3 ? progress / 0.3 : (1 - progress) / 0.7).clamp(0.0, 1.0);
      final tailX = s.x - s.vx * s.length;
      final tailY = s.y - s.vy * s.length;

      final starPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withAlpha((alpha * 220).toInt()),
            color.withAlpha((alpha * 120).toInt()),
            color.withAlpha(0),
          ],
        ).createShader(Rect.fromPoints(Offset(s.x, s.y), Offset(tailX, tailY)))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(s.x, s.y), Offset(tailX, tailY), starPaint);
      canvas.drawCircle(
        Offset(s.x, s.y), 2,
        Paint()..color = Colors.white.withAlpha((alpha * 255).toInt())..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}
