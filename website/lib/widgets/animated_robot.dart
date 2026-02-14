import 'dart:math';
import 'package:flutter/material.dart';
import '../painters/robot_painter.dart';
import '../core/theme/app_colors.dart';

class AnimatedRobot extends StatefulWidget {
  final double size;
  final bool isTalking;
  const AnimatedRobot({super.key, this.size = 200, this.isTalking = true});

  @override
  State<AnimatedRobot> createState() => _AnimatedRobotState();
}

class _AnimatedRobotState extends State<AnimatedRobot> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _colorController;
  late AnimationController _floatController;
  late AnimationController _talkController;
  late AnimationController _gestureController;
  bool _isHovered = false;

  static const _glowColors = [AppColors.cyan, AppColors.primary, AppColors.green];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _colorController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _talkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))..repeat(reverse: true);
    _gestureController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _colorController.dispose();
    _floatController.dispose();
    _talkController.dispose();
    _gestureController.dispose();
    super.dispose();
  }

  Color _getCurrentGlowColor() {
    final t = _colorController.value * _glowColors.length;
    final i = t.floor() % _glowColors.length;
    final next = (i + 1) % _glowColors.length;
    return Color.lerp(_glowColors[i], _glowColors[next], t - t.floor())!;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: Listenable.merge([_glowController, _colorController, _floatController, _talkController, _gestureController]),
        builder: (context, _) {
          final floatOffset = sin(_floatController.value * pi) * 8;
          final g = _gestureController.value;
          final talking = widget.isTalking;

          // Mouth
          final mouthOpen = talking
              ? _talkController.value * (0.5 + 0.5 * sin(g * pi * 17).abs())
              : 0.0;

          // Arms: gesture when talking, idle when not
          final leftArmBase = 0.15;
          final rightArmBase = -0.15;
          double leftArm, rightArm;
          if (talking) {
            leftArm = leftArmBase + sin(g * pi * 2) * 0.6;
            rightArm = rightArmBase + sin(g * pi * 2 + pi * 0.7) * 0.5;
          } else {
            // Idle: arms slightly out, gentle sway
            leftArm = leftArmBase + sin(g * pi * 2) * 0.08;
            rightArm = rightArmBase + sin(g * pi * 2 + pi) * 0.08;
          }

          // Head tilt
          final headTilt = talking
              ? sin(g * pi * 2 * 1.5) * 0.08
              : sin(g * pi * 2 * 0.5) * 0.03;

          return Transform.translate(
            offset: Offset(0, floatOffset),
            child: ClipRect(
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: RobotPainter(
                  glowIntensity: 0.5 + _glowController.value * 0.5,
                  isHovered: _isHovered,
                  glowColor: _getCurrentGlowColor(),
                  mouthOpen: mouthOpen,
                  leftArmAngle: leftArm,
                  rightArmAngle: rightArm,
                  headTilt: headTilt,
                ),
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
