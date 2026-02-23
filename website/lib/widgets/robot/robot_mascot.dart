import 'dart:math';
import 'package:flutter/material.dart';
import 'robot_painter.dart';
import 'robot_speech_bubble.dart';
import '../../core/theme/app_colors.dart';

enum RobotState { idle, talking, walking, celebrating, pointing, waving }

class RobotMascot extends StatefulWidget {
  final double size;
  final RobotState state;
  final RobotProp prop;
  final Color glowColor;
  final String? message;
  final bool showBubble;
  final RobotExpression expression;
  final bool flipHorizontal;

  const RobotMascot({
    super.key,
    this.size = 160,
    this.state = RobotState.idle,
    this.prop = RobotProp.none,
    this.glowColor = AppColors.cyan,
    this.message,
    this.showBubble = false,
    this.expression = RobotExpression.normal,
    this.flipHorizontal = false,
  });

  @override
  State<RobotMascot> createState() => _RobotMascotState();
}

class _RobotMascotState extends State<RobotMascot>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _secondaryController;

  @override
  void initState() {
    super.initState();
    _primaryController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _secondaryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_primaryController, _secondaryController]),
      builder: (context, child) {
        final t = _primaryController.value;
        final t2 = _secondaryController.value;
        final params = _getAnimationParams(t, t2);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speech bubble
            if (widget.showBubble && widget.message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RobotSpeechBubble(
                  message: widget.message!,
                  accentColor: widget.glowColor,
                  isVisible: widget.showBubble,
                ),
              ),
            // Robot
            Transform(
              alignment: Alignment.center,
              transform: widget.flipHorizontal
                  ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0)
                  : Matrix4.identity(),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(widget.size, widget.size * 1.2),
                  painter: RobotPainter(
                    leftArmAngle: params.leftArmAngle,
                    rightArmAngle: params.rightArmAngle,
                    leftLegAngle: params.leftLegAngle,
                    rightLegAngle: params.rightLegAngle,
                    headTilt: params.headTilt,
                    mouthOpen: params.mouthOpen,
                    bodyOffsetY: params.bodyOffsetY,
                    expression: widget.expression,
                    prop: widget.prop,
                    glowColor: widget.glowColor,
                    glowIntensity: params.glowIntensity,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _AnimParams _getAnimationParams(double t, double t2) {
    switch (widget.state) {
      case RobotState.idle:
        return _AnimParams(
          leftArmAngle: sin(t * 2 * pi) * 0.05,
          rightArmAngle: sin(t * 2 * pi + 0.5) * 0.05,
          leftLegAngle: 0,
          rightLegAngle: 0,
          headTilt: sin(t * 2 * pi) * 0.03,
          mouthOpen: 0,
          bodyOffsetY: sin(t * 2 * pi) * 2,
          glowIntensity: 0.4 + sin(t * 2 * pi) * 0.2,
        );

      case RobotState.talking:
        return _AnimParams(
          leftArmAngle: sin(t * 2 * pi) * 0.15,
          rightArmAngle: sin(t * 2 * pi + 1) * 0.2,
          leftLegAngle: 0,
          rightLegAngle: 0,
          headTilt: sin(t * 2 * pi * 0.5) * 0.05,
          mouthOpen: (sin(t2 * 2 * pi) + 1) / 2, // 0-1 rapid
          bodyOffsetY: sin(t * 2 * pi) * 1.5,
          glowIntensity: 0.6 + sin(t * 2 * pi) * 0.3,
        );

      case RobotState.walking:
        return _AnimParams(
          leftArmAngle: sin(t * 2 * pi) * 0.3,
          rightArmAngle: sin(t * 2 * pi + pi) * 0.3,
          leftLegAngle: sin(t * 2 * pi) * 0.35,
          rightLegAngle: sin(t * 2 * pi + pi) * 0.35,
          headTilt: sin(t * 2 * pi) * 0.04,
          mouthOpen: 0,
          bodyOffsetY: (sin(t * 4 * pi).abs()) * 3,
          glowIntensity: 0.5,
        );

      case RobotState.celebrating:
        return _AnimParams(
          leftArmAngle: -0.8 + sin(t * 4 * pi) * 0.2,
          rightArmAngle: -0.8 + sin(t * 4 * pi + 1) * 0.2,
          leftLegAngle: sin(t * 4 * pi) * 0.15,
          rightLegAngle: sin(t * 4 * pi + pi) * 0.15,
          headTilt: sin(t * 4 * pi) * 0.08,
          mouthOpen: 0.7,
          bodyOffsetY: -(sin(t * 4 * pi).abs()) * 6,
          glowIntensity: 0.8 + sin(t * 4 * pi) * 0.2,
        );

      case RobotState.pointing:
        return _AnimParams(
          leftArmAngle: sin(t * 2 * pi) * 0.05,
          rightArmAngle: -0.6 + sin(t * 2 * pi) * 0.08,
          leftLegAngle: 0,
          rightLegAngle: 0,
          headTilt: -0.08 + sin(t * 2 * pi) * 0.02,
          mouthOpen: 0,
          bodyOffsetY: sin(t * 2 * pi) * 1.5,
          glowIntensity: 0.5,
        );

      case RobotState.waving:
        return _AnimParams(
          leftArmAngle: sin(t * 2 * pi) * 0.05,
          rightArmAngle: -0.7 + sin(t * 4 * pi) * 0.3,
          leftLegAngle: 0,
          rightLegAngle: 0,
          headTilt: sin(t * 2 * pi) * 0.06,
          mouthOpen: 0,
          bodyOffsetY: sin(t * 2 * pi) * 2,
          glowIntensity: 0.6 + sin(t * 2 * pi) * 0.2,
        );
    }
  }
}

class _AnimParams {
  final double leftArmAngle;
  final double rightArmAngle;
  final double leftLegAngle;
  final double rightLegAngle;
  final double headTilt;
  final double mouthOpen;
  final double bodyOffsetY;
  final double glowIntensity;

  _AnimParams({
    required this.leftArmAngle,
    required this.rightArmAngle,
    required this.leftLegAngle,
    required this.rightLegAngle,
    required this.headTilt,
    required this.mouthOpen,
    required this.bodyOffsetY,
    required this.glowIntensity,
  });
}
