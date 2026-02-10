import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AddToCartAnimation extends StatefulWidget {
  final Widget child;
  final GlobalKey cartIconKey;
  final VoidCallback onAnimationComplete;
  final String? imageUrl;

  const AddToCartAnimation({
    super.key,
    required this.child,
    required this.cartIconKey,
    required this.onAnimationComplete,
    this.imageUrl,
  });

  @override
  State<AddToCartAnimation> createState() => _AddToCartAnimationState();
}

class _AddToCartAnimationState extends State<AddToCartAnimation> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Overlay'de gösterilecek animasyonlu ürün - Geliştirilmiş versiyon
class FlyingCartItem extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final String? imageUrl;
  final VoidCallback onComplete;
  final double itemSize;

  const FlyingCartItem({
    super.key,
    required this.startPosition,
    required this.endPosition,
    this.imageUrl,
    required this.onComplete,
    this.itemSize = 80, // Daha büyük varsayılan boyut
  });

  @override
  State<FlyingCartItem> createState() => _FlyingCartItemState();
}

class _FlyingCartItemState extends State<FlyingCartItem>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  // Parabolik yol için kontrol noktası
  late Offset _controlPoint;

  @override
  void initState() {
    super.initState();

    // Ana kontrol - 800ms daha uzun süre
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // İlerleme animasyonu
    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Boyut animasyonu - başta büyüsün, sonra küçülsün
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_controller);

    // Dönme animasyonu - 360 derece dönsün
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Opaklık - son %20'de kaybolsun
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    // Parabolik yol için kontrol noktası hesapla
    // Yukarı doğru kavisli bir yol çizecek
    final midX = (widget.startPosition.dx + widget.endPosition.dx) / 2;
    final minY = math.min(widget.startPosition.dy, widget.endPosition.dy);
    _controlPoint = Offset(
      midX,
      minY - 150, // Yukarı doğru 150px kavis
    );

    _startAnimation();
  }

  // Quadratic Bezier curve hesaplama
  Offset _calculateBezierPoint(double t) {
    final start = widget.startPosition;
    final end = widget.endPosition;
    final control = _controlPoint;

    // B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
    final u = 1 - t;
    final tt = t * t;
    final uu = u * u;

    return Offset(
      uu * start.dx + 2 * u * t * control.dx + tt * end.dx,
      uu * start.dy + 2 * u * t * control.dy + tt * end.dy,
    );
  }

  void _startAnimation() async {
    await _controller.forward();
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final position = _calculateBezierPoint(_progressAnimation.value);
        final size = widget.itemSize * _scaleAnimation.value;

        return Positioned(
          left: position.dx - size / 2,
          top: position.dy - size / 2,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(size * 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC6D13).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.15),
                  child: Stack(
                    children: [
                      // Ürün resmi veya ikon
                      Positioned.fill(
                        child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                errorWidget: (_, __, ___) => _buildFallbackIcon(size),
                              )
                            : _buildFallbackIcon(size),
                      ),
                      // Parlak overlay efekti
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.3),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.1),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
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

  Widget _buildFallbackIcon(double size) {
    return Container(
      color: const Color(0xFFFFF3E0),
      child: Icon(
        Icons.fastfood,
        color: const Color(0xFFEC6D13),
        size: size * 0.5,
      ),
    );
  }
}

// Sepet ikonu için geliştirilmiş bounce animasyonu
class CartIconBounce extends StatefulWidget {
  final Widget child;
  final AnimationController? controller;

  const CartIconBounce({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  State<CartIconBounce> createState() => CartIconBounceState();
}

class CartIconBounceState extends State<CartIconBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this,
        );

    // Daha belirgin bounce efekti
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 0.9)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.9, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    // Hafif sallama efekti
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.03), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.03), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.03, end: 0.0), weight: 20),
    ]).animate(_controller);
  }

  void bounce() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _shakeAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

// Parçacık efekti - sepete eklendiğinde patlama efekti
class CartAddParticles extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const CartAddParticles({
    super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<CartAddParticles> createState() => _CartAddParticlesState();
}

class _CartAddParticlesState extends State<CartAddParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Rastgele parçacıklar oluştur
    final random = math.Random();
    for (int i = 0; i < 12; i++) {
      _particles.add(_Particle(
        angle: (i / 12) * 2 * math.pi + random.nextDouble() * 0.3,
        speed: 80 + random.nextDouble() * 60,
        size: 6 + random.nextDouble() * 6,
        color: i % 2 == 0
            ? const Color(0xFFEC6D13)
            : const Color(0xFFFFA726),
      ));
    }

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((particle) {
            final progress = _controller.value;
            final distance = particle.speed * progress;
            final x = widget.position.dx + math.cos(particle.angle) * distance;
            final y = widget.position.dy + math.sin(particle.angle) * distance;
            final opacity = (1 - progress).clamp(0.0, 1.0);
            final size = particle.size * (1 - progress * 0.5);

            return Positioned(
              left: x - size / 2,
              top: y - size / 2,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: particle.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: particle.color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;

  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

// Geliştirilmiş Helper class
class CartAnimationHelper {
  static OverlayEntry? _overlayEntry;
  static OverlayEntry? _particleEntry;

  static void animateToCart({
    required BuildContext context,
    required GlobalKey startKey,
    required GlobalKey endKey,
    String? imageUrl,
    VoidCallback? onComplete,
  }) {
    // Get positions
    final RenderBox? startBox =
        startKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? endBox =
        endKey.currentContext?.findRenderObject() as RenderBox?;

    if (startBox == null || endBox == null) {
      onComplete?.call();
      return;
    }

    final startSize = startBox.size;
    final endSize = endBox.size;

    // Merkez noktalarını hesapla
    final startPosition = startBox.localToGlobal(
      Offset(startSize.width / 2, startSize.height / 2),
    );
    final endPosition = endBox.localToGlobal(
      Offset(endSize.width / 2, endSize.height / 2),
    );

    // Create flying item overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => FlyingCartItem(
        startPosition: startPosition,
        endPosition: endPosition,
        imageUrl: imageUrl,
        itemSize: 90, // Daha büyük boyut
        onComplete: () {
          _overlayEntry?.remove();
          _overlayEntry = null;

          // Parçacık efekti ekle
          _particleEntry = OverlayEntry(
            builder: (context) => CartAddParticles(
              position: endPosition,
              onComplete: () {
                _particleEntry?.remove();
                _particleEntry = null;
                onComplete?.call();
              },
            ),
          );
          Overlay.of(context).insert(_particleEntry!);
        },
      ),
    );

    // Insert overlay
    Overlay.of(context).insert(_overlayEntry!);
  }
}
