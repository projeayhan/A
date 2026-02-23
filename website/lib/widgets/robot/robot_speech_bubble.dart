import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class RobotSpeechBubble extends StatefulWidget {
  final String message;
  final Color accentColor;
  final bool isVisible;
  final bool alignLeft;
  final double maxWidth;

  const RobotSpeechBubble({
    super.key,
    required this.message,
    this.accentColor = AppColors.cyan,
    this.isVisible = true,
    this.alignLeft = false,
    this.maxWidth = 300,
  });

  @override
  State<RobotSpeechBubble> createState() => _RobotSpeechBubbleState();
}

class _RobotSpeechBubbleState extends State<RobotSpeechBubble>
    with SingleTickerProviderStateMixin {
  String _displayedText = '';
  Timer? _typingTimer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    if (widget.isVisible) {
      _startTyping();
      _fadeController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant RobotSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      _displayedText = '';
      _typingTimer?.cancel();
      _startTyping();
    }
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _fadeController.forward();
        _startTyping();
      } else {
        _fadeController.reverse();
      }
    }
  }

  void _startTyping() {
    int index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (index < widget.message.length) {
        setState(() {
          _displayedText = widget.message.substring(0, index + 1);
        });
        index++;
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: Column(
          crossAxisAlignment:
              widget.alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                _displayedText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textOnDark,
                  height: 1.4,
                ),
              ),
            ),
            // Triangle pointer
            Padding(
              padding: EdgeInsets.only(
                left: widget.alignLeft ? 20 : 0,
                right: widget.alignLeft ? 0 : 20,
              ),
              child: CustomPaint(
                size: const Size(16, 8),
                painter: _TrianglePainter(
                  color: AppColors.surfaceDark.withValues(alpha: 0.9),
                  borderColor: widget.accentColor.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _TrianglePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      color != oldDelegate.color || borderColor != oldDelegate.borderColor;
}
