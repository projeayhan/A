import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/ai_chat_service.dart';

class FloatingAIAssistant extends StatefulWidget {
  const FloatingAIAssistant({super.key});

  @override
  State<FloatingAIAssistant> createState() => _FloatingAIAssistantState();
}

class _FloatingAIAssistantState extends State<FloatingAIAssistant>
    with TickerProviderStateMixin {
  late AnimationController _walkController;
  late AnimationController _glowController;
  late AnimationController _moveController;
  late AnimationController _hoverController;

  late Animation<double> _legAnimation;
  late Animation<double> _armAnimation;
  late Animation<double> _bodyBounceAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _horizontalAnimation;
  late Animation<double> _hoverScaleAnimation;

  bool _isHovered = false;
  bool _movingRight = true;
  Offset _position = const Offset(16, 160);
  bool _isManualPosition = false;
  bool _isChatOpen = false;

  // Proactive message state
  bool _showProactiveMessage = false;
  String _proactiveMessage = '';
  String _proactiveEmoji = '🍽️';
  Timer? _proactiveTimer;
  bool _proactiveMessageDismissed = false;

  @override
  void initState() {
    super.initState();

    _walkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _legAnimation = Tween<double>(begin: -0.25, end: 0.25).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.easeInOut),
    );

    _armAnimation = Tween<double>(begin: 0.15, end: -0.15).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.easeInOut),
    );

    _bodyBounceAnimation = Tween<double>(begin: 0, end: 2).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _moveController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _horizontalAnimation = Tween<double>(begin: 16, end: 120).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.linear),
    );

    _moveController.addListener(() {
      if (!_isManualPosition && !_isChatOpen) {
        setState(() {
          _movingRight = _moveController.status == AnimationStatus.forward;
        });
      }
    });

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _hoverScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );

    // Start proactive message timer
    _startProactiveMessageTimer();
  }

  void _startProactiveMessageTimer() {
    // Show proactive message after 5 seconds, then every 2 minutes
    _proactiveTimer = Timer(const Duration(seconds: 5), () {
      _fetchAndShowProactiveMessage();
    });
  }

  Future<void> _fetchAndShowProactiveMessage() async {
    if (_isChatOpen || _proactiveMessageDismissed || !mounted) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      final response = await Supabase.instance.client.rpc(
        'ai_get_proactive_message',
        params: {'p_user_id': userId},
      );

      if (response != null && response.isNotEmpty && mounted) {
        final data = response[0];
        setState(() {
          _proactiveMessage = data['message'] ?? 'Bugün ne yemek istersin?';
          _proactiveEmoji = data['emoji'] ?? '🍽️';
          _showProactiveMessage = true;
        });

        // Auto hide after 8 seconds
        Timer(const Duration(seconds: 8), () {
          if (mounted && !_isChatOpen) {
            setState(() => _showProactiveMessage = false);
          }
        });

        // Schedule next proactive message in 2 minutes
        _proactiveTimer = Timer(const Duration(minutes: 2), () {
          if (!_proactiveMessageDismissed) {
            _fetchAndShowProactiveMessage();
          }
        });
      }
    } catch (e) {
      // Silently fail - proactive messages are not critical
      debugPrint('Proactive message error: $e');
    }
  }

  void _dismissProactiveMessage() {
    setState(() {
      _showProactiveMessage = false;
      _proactiveMessageDismissed = true;
    });
    _proactiveTimer?.cancel();
  }

  @override
  void dispose() {
    _walkController.dispose();
    _glowController.dispose();
    _moveController.dispose();
    _hoverController.dispose();
    _proactiveTimer?.cancel();
    super.dispose();
  }

  void _onTap() {
    setState(() => _isChatOpen = true);
    _walkController.stop();
    _moveController.stop();

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _AIChatDialog(
        onClose: () => Navigator.of(context).pop(),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isChatOpen = false);
        if (!_isManualPosition) {
          _moveController.repeat(reverse: true);
        }
        _walkController.repeat(reverse: true);
      }
    });
  }

  void _onHoverStart() {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _onHoverEnd() {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_horizontalAnimation, _walkController, _glowAnimation, _hoverScaleAnimation]),
      builder: (context, child) {
        final xPos = _isManualPosition || _isChatOpen ? _position.dx : _horizontalAnimation.value;

        return Positioned(
          right: xPos,
          bottom: _position.dy,
          child: GestureDetector(
            onPanStart: (_) {
              setState(() => _isManualPosition = true);
              _walkController.stop();
              _moveController.stop();
            },
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  _position.dx - details.delta.dx,
                  _position.dy - details.delta.dy,
                );
              });
            },
            onPanEnd: (_) {
              if (!_isChatOpen) {
                _walkController.repeat(reverse: true);
              }
            },
            onTap: _onTap,
            child: MouseRegion(
              onEnter: (_) => _onHoverStart(),
              onExit: (_) => _onHoverEnd(),
              cursor: SystemMouseCursors.click,
              child: Transform.scale(
                scale: _hoverScaleAnimation.value,
                child: SizedBox(
                  width: 60,
                  height: 130,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 10,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFF00D4FF).withAlpha((100 * _glowAnimation.value).toInt()),
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Transform.translate(
                            offset: Offset(0, _isChatOpen ? 0 : -_bodyBounceAnimation.value),
                            child: Transform.flip(
                              flipX: !_movingRight,
                              child: _buildFuturisticRobot(),
                            ),
                          ),
                        ),
                      ),
                      if (_isHovered && !_isChatOpen && !_showProactiveMessage)
                        Positioned(
                          top: 0,
                          left: -50,
                          right: -50,
                          child: Center(child: _buildSpeechBubble()),
                        ),
                      // Proactive message bubble
                      if (_showProactiveMessage && !_isChatOpen)
                        Positioned(
                          top: -10,
                          left: -100,
                          right: -100,
                          child: Center(child: _buildProactiveMessageBubble()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFuturisticRobot() {
    return SizedBox(
      width: 55,
      height: 85,
      child: CustomPaint(
        painter: _FuturisticRobotPainter(
          walkAnimation: _isChatOpen ? 0 : _legAnimation.value,
          armAnimation: _isChatOpen ? 0 : _armAnimation.value,
          glowIntensity: _glowAnimation.value,
          isHovered: _isHovered,
          isChatOpen: _isChatOpen,
        ),
      ),
    );
  }

  Widget _buildSpeechBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00D4FF).withAlpha(150), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF00D4FF).withAlpha(60), blurRadius: 12, spreadRadius: 1),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF00FF88), blurRadius: 5)],
                  ),
                ),
                const SizedBox(width: 5),
                const Flexible(
                  child: Text(
                    'Yardim?',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(size: const Size(12, 7), painter: _BubbleTailPainter()),
        ],
      ),
    );
  }

  Widget _buildProactiveMessageBubble() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          _dismissProactiveMessage();
          _onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FF88).withAlpha(180), width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FF88).withAlpha(80), blurRadius: 16, spreadRadius: 2),
                  BoxShadow(color: const Color(0xFF00D4FF).withAlpha(40), blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_proactiveEmoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _proactiveMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF00FF88)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Konuşalım!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _dismissProactiveMessage,
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white.withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CustomPaint(size: const Size(14, 8), painter: _ProactiveBubbleTailPainter()),
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16213e), Color(0xFF0f0f23)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00D4FF).withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(size.width / 2, size.height);
    borderPath.lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProactiveBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF16213e), Color(0xFF0f0f23)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = const Color(0xFF00FF88).withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(size.width / 2, size.height);
    borderPath.lineTo(size.width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FuturisticRobotPainter extends CustomPainter {
  final double walkAnimation;
  final double armAnimation;
  final double glowIntensity;
  final bool isHovered;
  final bool isChatOpen;

  _FuturisticRobotPainter({
    required this.walkAnimation,
    required this.armAnimation,
    required this.glowIntensity,
    required this.isHovered,
    required this.isChatOpen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final scale = size.height / 140;
    final metalDark = const Color(0xFF2d3436);
    final metalMid = const Color(0xFF636e72);
    final metalLight = const Color(0xFFb2bec3);
    final glowColor = isHovered ? const Color(0xFF00FF88) : const Color(0xFF00D4FF);
    final glowColorDim = glowColor.withAlpha((150 * glowIntensity).toInt());

    _drawLeg(canvas, centerX - 10 * scale, size.height - 45 * scale, walkAnimation, metalDark, metalMid, glowColor, scale);
    _drawLeg(canvas, centerX + 10 * scale, size.height - 45 * scale, -walkAnimation, metalDark, metalMid, glowColor, scale);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, size.height - 65 * scale), width: 32 * scale, height: 36 * scale),
      Radius.circular(6 * scale),
    );
    canvas.drawRRect(bodyRect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [metalLight, metalMid, metalDark]).createShader(bodyRect.outerRect));
    canvas.drawRRect(bodyRect, Paint()..color = glowColorDim..style = PaintingStyle.stroke..strokeWidth = 1.2);

    final chestCenter = Offset(centerX, size.height - 65 * scale);
    canvas.drawCircle(chestCenter, 10 * scale, Paint()..shader = RadialGradient(colors: [glowColor, glowColor.withAlpha((100 * glowIntensity).toInt()), Colors.transparent]).createShader(Rect.fromCircle(center: chestCenter, radius: 12 * scale)));
    canvas.drawCircle(chestCenter, 5 * scale, Paint()..color = glowColor);
    canvas.drawCircle(chestCenter, 2 * scale, Paint()..color = Colors.white);

    _drawArm(canvas, centerX - 20 * scale, size.height - 73 * scale, armAnimation, metalDark, metalMid, glowColor, scale);
    _drawArm(canvas, centerX + 20 * scale, size.height - 73 * scale, -armAnimation, metalDark, metalMid, glowColor, scale);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, size.height - 85 * scale), width: 10 * scale, height: 6 * scale), Radius.circular(2 * scale)), Paint()..color = metalDark);

    _drawHead(canvas, centerX, size.height - 105 * scale, metalDark, metalMid, metalLight, glowColor, glowIntensity, isHovered, scale);
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

  void _drawHead(Canvas canvas, double x, double y, Color dark, Color mid, Color light, Color glow, double glowIntensity, bool isHovered, double scale) {
    final headPath = Path();
    headPath.moveTo(x - 14 * scale, y + 12 * scale);
    headPath.lineTo(x - 18 * scale, y - 4 * scale);
    headPath.quadraticBezierTo(x - 18 * scale, y - 16 * scale, x - 8 * scale, y - 18 * scale);
    headPath.lineTo(x + 8 * scale, y - 18 * scale);
    headPath.quadraticBezierTo(x + 18 * scale, y - 16 * scale, x + 18 * scale, y - 4 * scale);
    headPath.lineTo(x + 14 * scale, y + 12 * scale);
    headPath.close();

    canvas.drawPath(headPath, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, mid, dark]).createShader(Rect.fromCenter(center: Offset(x, y), width: 36 * scale, height: 32 * scale)));
    canvas.drawPath(headPath, Paint()..color = glow.withAlpha((100 * glowIntensity).toInt())..style = PaintingStyle.stroke..strokeWidth = 1.2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 2 * scale), width: 28 * scale, height: 18 * scale), Radius.circular(4 * scale)), Paint()..color = const Color(0xFF0a0a0f));

    if (isHovered) {
      final leftEyePath = Path()..moveTo(x - 10 * scale, y)..quadraticBezierTo(x - 6 * scale, y - 5 * scale, x - 3 * scale, y);
      canvas.drawPath(leftEyePath, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
      final rightEyePath = Path()..moveTo(x + 3 * scale, y)..quadraticBezierTo(x + 6 * scale, y - 5 * scale, x + 10 * scale, y);
      canvas.drawPath(rightEyePath, Paint()..color = glow..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    } else {
      canvas.drawLine(Offset(x - 10 * scale, y - 2 * scale), Offset(x + 10 * scale, y - 2 * scale), Paint()..color = glow..strokeWidth = 2.5..strokeCap = StrokeCap.round..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * glowIntensity));
      canvas.drawCircle(Offset(x - 5 * scale, y - 2 * scale), 1.5 * scale, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x + 5 * scale, y - 2 * scale), 1.5 * scale, Paint()..color = Colors.white);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 23 * scale), width: 3 * scale, height: 10 * scale), Radius.circular(1.5 * scale)), Paint()..color = mid);
    canvas.drawCircle(Offset(x, y - 28 * scale), 4 * scale, Paint()..color = glow.withAlpha((200 * glowIntensity).toInt())..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(x, y - 28 * scale), 2.5 * scale, Paint()..color = glow);
    canvas.drawCircle(Offset(x, y - 28 * scale), 1 * scale, Paint()..color = Colors.white);

    _drawEarPanel(canvas, x - 20 * scale, y - 4 * scale, glow, glowIntensity, scale);
    _drawEarPanel(canvas, x + 20 * scale, y - 4 * scale, glow, glowIntensity, scale);
  }

  void _drawEarPanel(Canvas canvas, double x, double y, Color glow, double glowIntensity, double scale) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 5 * scale, height: 14 * scale), Radius.circular(1.5 * scale)), Paint()..color = const Color(0xFF2d3436));
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(x, y - 4 * scale + (i * 4 * scale)), 1 * scale, Paint()..color = glow.withAlpha((150 * glowIntensity).toInt()));
    }
  }

  @override
  bool shouldRepaint(_FuturisticRobotPainter oldDelegate) {
    return oldDelegate.walkAnimation != walkAnimation || oldDelegate.armAnimation != armAnimation || oldDelegate.glowIntensity != glowIntensity || oldDelegate.isHovered != isHovered || oldDelegate.isChatOpen != isChatOpen;
  }
}

class _AIChatDialog extends StatefulWidget {
  final VoidCallback onClose;
  const _AIChatDialog({required this.onClose});

  @override
  State<_AIChatDialog> createState() => _AIChatDialogState();
}

class _AIChatDialogState extends State<_AIChatDialog> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final existingSessionId = await AiChatService.getActiveSessionId();

    if (existingSessionId != null) {
      _sessionId = existingSessionId;
      final history = await AiChatService.getChatHistory(existingSessionId);
      setState(() {
        _messages.addAll(history.map((msg) => _ChatMessage(
          role: msg['role'],
          content: msg['content'],
          timestamp: DateTime.tryParse(msg['created_at'] ?? ''),
        )));
      });
    } else {
      _messages.add(_ChatMessage(role: 'assistant', content: 'Merhaba! Size nasil yardimci olabilirim?', timestamp: DateTime.now()));
    }

    setState(() => _isInitializing = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: message, timestamp: DateTime.now()));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await AiChatService.sendMessage(message: message, sessionId: _sessionId);

    setState(() {
      _isLoading = false;
      if (response['success'] == true) {
        _sessionId = response['session_id'];
        _messages.add(_ChatMessage(role: 'assistant', content: response['message'], timestamp: DateTime.now()));
      } else {
        final errorMsg = response['error'] ?? 'Bilinmeyen bir hata oluştu';
        _messages.add(_ChatMessage(role: 'assistant', content: 'Üzgünüm, $errorMsg', timestamp: DateTime.now(), isError: true));
      }
    });
    _scrollToBottom();
  }

  Future<void> _startNewChat() async {
    if (_sessionId != null) await AiChatService.closeSession(_sessionId!);
    setState(() {
      _sessionId = null;
      _messages.clear();
      _messages.add(_ChatMessage(role: 'assistant', content: 'Yeni sohbet baslatildi. Size nasil yardimci olabilirim?', timestamp: DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Container(
        width: isMobile ? screenSize.width - 24 : 380,
        height: isMobile ? screenSize.height * 0.75 : 520,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00D4FF).withAlpha(100), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(30), blurRadius: 25, spreadRadius: 3)],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isInitializing
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) return _buildTypingIndicator();
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            if (_messages.length <= 2) _buildQuickActions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(100), blurRadius: 8)],
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Asistan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF00FF88), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF00FF88), blurRadius: 4)])),
                    const SizedBox(width: 5),
                    Text('Cevrimici', style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(150))),
                  ],
                ),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.refresh, color: Colors.white.withAlpha(150), size: 20), onPressed: _startNewChat),
          IconButton(icon: Icon(Icons.close, color: Colors.white.withAlpha(150), size: 20), onPressed: widget.onClose),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(width: 26, height: 26, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.smart_toy, color: Colors.white, size: 16)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isUser ? const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF0099CC)]) : null,
                  color: isUser ? null : const Color(0xFF252540),
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16)),
                  border: isUser ? null : Border.all(color: const Color(0xFF00D4FF).withAlpha(30)),
                ),
                child: Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
            if (isUser) const SizedBox(width: 34),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 26, height: 26, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.smart_toy, color: Colors.white, size: 16)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF252540), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF00D4FF).withAlpha(30))),
            child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => _TypingDot(delay: i * 150))),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final questions = ['Siparis durumu nedir?', 'Yardim almak istiyorum', 'Odeme nasil yapilir?'];
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: questions.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            label: Text(questions[index], style: const TextStyle(fontSize: 10, color: Colors.white)),
            backgroundColor: const Color(0xFF252540),
            side: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () { _messageController.text = questions[index]; _sendMessage(); },
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: const Color(0xFF00D4FF).withAlpha(50)))),
      child: Row(
        children: [
          Expanded(
            child: Theme(
              data: ThemeData.dark().copyWith(
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: Color(0xFF00D4FF),
                  selectionColor: Color(0xFF00D4FF),
                  selectionHandleColor: Color(0xFF00D4FF),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF252540), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00D4FF).withAlpha(30))),
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  cursorColor: const Color(0xFF00D4FF),
                  decoration: InputDecoration(
                    hintText: 'Mesajinizi yazin...',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(120), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00D4FF), Color(0xFF00FF88)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withAlpha(80), blurRadius: 8)]),
            child: IconButton(
              icon: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _controller.repeat(reverse: true); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 7, height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: Color.lerp(const Color(0xFF00D4FF).withAlpha(100), const Color(0xFF00D4FF), _controller.value), shape: BoxShape.circle),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String content;
  final DateTime? timestamp;
  final bool isError;

  _ChatMessage({required this.role, required this.content, this.timestamp, this.isError = false});
}
