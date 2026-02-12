import 'dart:math';
import 'package:flutter/material.dart';
import '../painters/particle_painter.dart';
import '../core/theme/app_colors.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final List<ShootingStar> _shootingStars = [];
  final _random = Random();
  Size _size = Size.zero;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 100))..repeat();
    _controller.addListener(_update);
  }

  void _initParticles(Size size) {
    if (_size == size) return;
    _size = size;
    _particles.clear();
    final count = size.width < 768 ? 25 : 45;
    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        vx: (_random.nextDouble() - 0.5) * 0.4,
        vy: (_random.nextDouble() - 0.5) * 0.3,
        radius: _random.nextDouble() * 1.5 + 0.5,
        opacity: _random.nextDouble() * 0.4 + 0.1,
      ));
    }
  }

  void _update() {
    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      if (p.x < 0) p.x = _size.width;
      if (p.x > _size.width) p.x = 0;
      if (p.y < 0) p.y = _size.height;
      if (p.y > _size.height) p.y = 0;
    }

    _frameCount++;
    if (_frameCount > 80 + _random.nextInt(120)) {
      _spawnShootingStar();
      _frameCount = 0;
    }

    _shootingStars.removeWhere((s) => s.life >= s.maxLife);
    for (final s in _shootingStars) {
      s.x += s.vx;
      s.y += s.vy;
      s.life += 1;
    }
  }

  void _spawnShootingStar() {
    if (_size == Size.zero) return;
    final angle = _random.nextDouble() * 0.8 + 0.2;
    final speed = _random.nextDouble() * 5 + 4;
    final goRight = _random.nextBool();
    _shootingStars.add(ShootingStar(
      x: goRight ? _random.nextDouble() * _size.width * 0.3 : _size.width * 0.7 + _random.nextDouble() * _size.width * 0.3,
      y: _random.nextDouble() * _size.height * 0.4,
      vx: cos(angle) * speed * (goRight ? 1 : -1),
      vy: sin(angle) * speed,
      life: 0,
      maxLife: 40 + _random.nextDouble() * 40,
      length: 12 + _random.nextDouble() * 18,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _initParticles(Size(constraints.maxWidth, constraints.maxHeight));
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: ParticlePainter(
                particles: _particles,
                shootingStars: _shootingStars,
                animationValue: _controller.value,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}
