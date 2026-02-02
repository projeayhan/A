import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'food_home_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _confettiController;

  late Animation<double> _checkAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Check mark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
    );

    // Scale animation for the circle
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Fade animation for text
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Start animations in sequence
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _checkController.forward();
    _confettiController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _fadeController.forward();

    // Auto navigate to tracking screen after 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      context.go('/food/order-tracking/${widget.orderId}');
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FoodColors.backgroundDark : Colors.white,
      body: Stack(
        children: [
          // Confetti particles
          ...List.generate(20, (index) => _buildConfettiParticle(index, isDark)),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated success circle
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _checkAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: CheckMarkPainter(
                            progress: _checkAnimation.value,
                            color: Colors.white,
                            strokeWidth: 6,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Animated text
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Siparişiniz Alındı!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Siparişiniz restorana iletildi',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? FoodColors.primary.withValues(alpha: 0.2)
                              : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 18,
                              color: FoodColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sipariş No: #${widget.orderId}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: FoodColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Order info card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.restaurant,
                              'Restoran',
                              'Burger King - Levent',
                              isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              Icons.schedule,
                              'Tahmini Teslimat',
                              '25-35 dakika',
                              isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              Icons.payments,
                              'Toplam Tutar',
                              '${widget.totalAmount.toStringAsFixed(2)} TL',
                              isDark,
                              isHighlighted: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Loading indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FoodColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sipariş takip ekranına yönlendiriliyorsunuz...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isHighlighted
                ? FoodColors.primary.withValues(alpha: 0.1)
                : (isDark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isHighlighted
                ? FoodColors.primary
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted
                      ? FoodColors.primary
                      : (isDark ? Colors.white : Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfettiParticle(int index, bool isDark) {
    final colors = [
      FoodColors.primary,
      const Color(0xFF4ADE80),
      const Color(0xFFFBBF24),
      const Color(0xFF60A5FA),
      const Color(0xFFF472B6),
    ];

    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        final progress = _confettiController.value;
        final size = MediaQuery.of(context).size;

        // Random positions and movements
        final startX = (index * 47 % size.width.toInt()).toDouble();
        final startY = -50.0;
        final endY = size.height + 50;

        final currentY = startY + (endY - startY) * progress;
        final swayX = startX + (index.isEven ? 1 : -1) * 30 * (progress * 3.14).abs();
        final rotation = progress * (index.isEven ? 720 : -720);
        final opacity = progress < 0.8 ? 1.0 : (1 - (progress - 0.8) * 5);

        return Positioned(
          left: swayX,
          top: currentY,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: rotation * 3.14159 / 180,
              child: Container(
                width: 10 + (index % 3) * 4,
                height: 10 + (index % 3) * 4,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  borderRadius: index % 2 == 0
                      ? BorderRadius.circular(2)
                      : BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CheckMarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CheckMarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    // Check mark path points
    final start = Offset(center.dx - 25, center.dy);
    final middle = Offset(center.dx - 5, center.dy + 20);
    final end = Offset(center.dx + 30, center.dy - 20);

    final path = Path();

    if (progress <= 0.5) {
      // Draw first part of check mark
      final currentProgress = progress * 2;
      final currentPoint = Offset.lerp(start, middle, currentProgress)!;
      path.moveTo(start.dx, start.dy);
      path.lineTo(currentPoint.dx, currentPoint.dy);
    } else {
      // Draw complete first part and partial second part
      path.moveTo(start.dx, start.dy);
      path.lineTo(middle.dx, middle.dy);

      final currentProgress = (progress - 0.5) * 2;
      final currentPoint = Offset.lerp(middle, end, currentProgress)!;
      path.lineTo(currentPoint.dx, currentPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckMarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
