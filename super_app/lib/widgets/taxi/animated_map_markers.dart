import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class AnimatedMapMarkers {
  static Future<BitmapDescriptor> createCustomMarker({
    required String assetPath,
    required Size size,
  }) async {
    final Uint8List markerIcon = await _getBytesFromAsset(
      assetPath,
      size.width.toInt(),
    );
    return BitmapDescriptor.bytes(markerIcon);
  }

  static Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  // 3D Taksi Marker
  static Future<BitmapDescriptor> createTaxiMarker({
    double rotation = 0,
    Color color = Colors.amber,
    double size = 100,
  }) async {
    try {
      // Önce custom marker'ı dene
      final marker = await createCustomMarker(
        assetPath: 'assets/images/taxi_3d_icon.png',
        size: Size(size, size),
      );
      return marker;
    } catch (e) {
      debugPrint('Error loading taxi marker: $e');
      // Fallback: Programatik olarak taksi ikonu oluştur
      return await _createProgrammaticTaxiMarker(color: color, size: size);
    }
  }

  // Programatik taksi marker (fallback)
  static Future<BitmapDescriptor> _createProgrammaticTaxiMarker({
    Color color = Colors.amber,
    double size = 80,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 8;

    // Gölge
    canvas.drawCircle(center + const Offset(2, 2), radius, shadowPaint);

    // Ana daire
    canvas.drawCircle(center, radius, paint);

    // İç beyaz daire
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.7, innerPaint);

    // Araba ikonu (basit)
    final carPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Araba gövdesi
    final carBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size * 0.5, height: size * 0.25),
      const Radius.circular(4),
    );
    canvas.drawRRect(carBody, carPaint);

    // Araba üstü
    final carTop = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center - Offset(0, size * 0.08),
        width: size * 0.3,
        height: size * 0.15,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(carTop, carPaint);

    // Tekerlekler
    final wheelPaint = Paint()..color = Colors.black87;
    canvas.drawCircle(
      center + Offset(-size * 0.15, size * 0.12),
      size * 0.05,
      wheelPaint,
    );
    canvas.drawCircle(
      center + Offset(size * 0.15, size * 0.12),
      size * 0.05,
      wheelPaint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // 3D Passenger/Pickup Marker
  static Future<BitmapDescriptor> createPickupMarker({double size = 90}) async {
    try {
      return await createCustomMarker(
        assetPath: 'assets/images/passenger_3d_icon.png',
        size: Size(size, size),
      );
    } catch (e) {
      debugPrint('Error loading pickup marker: $e');
      // Fallback: Programatik yeşil pin
      return await _createProgrammaticPinMarker(
        color: Colors.green,
        size: size,
        icon: Icons.person_pin_circle,
      );
    }
  }

  // 3D Dropoff Marker
  static Future<BitmapDescriptor> createDropoffMarker({
    double size = 90,
  }) async {
    return await _createProgrammaticPinMarker(
      color: Colors.red,
      size: size,
      icon: Icons.flag_rounded,
    );
  }

  // 3D Customer Marker (Pulse effect container)
  static Future<BitmapDescriptor> createCustomerMarker({
    Color color = Colors.blue,
    double size = 90,
  }) async {
    try {
      return await createCustomMarker(
        assetPath: 'assets/images/passenger_3d_icon.png',
        size: Size(size, size),
      );
    } catch (e) {
      debugPrint('Error loading customer marker: $e');
      return await _createProgrammaticPinMarker(
        color: color,
        size: size,
        icon: Icons.person,
      );
    }
  }

  // Programatik pin marker
  static Future<BitmapDescriptor> _createProgrammaticPinMarker({
    required Color color,
    required double size,
    IconData icon = Icons.place,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Gölge
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(
      Offset(size / 2 + 2, size - 10),
      8,
      shadowPaint,
    );

    // Pin gövdesi (damla şekli)
    final pinPaint = Paint()..color = color;
    final path = Path();
    final centerX = size / 2;
    final topY = size * 0.1;
    final bottomY = size * 0.85;
    final radius = size * 0.35;

    // Üst yarım daire
    path.addArc(
      Rect.fromCircle(center: Offset(centerX, topY + radius), radius: radius),
      3.14159, // pi
      3.14159,
    );

    // Sağ kenar (aşağı doğru daralma)
    path.quadraticBezierTo(
      centerX + radius,
      topY + radius * 1.5,
      centerX,
      bottomY,
    );

    // Sol kenar
    path.quadraticBezierTo(
      centerX - radius,
      topY + radius * 1.5,
      centerX - radius,
      topY + radius,
    );

    path.close();
    canvas.drawPath(path, pinPaint);

    // İç beyaz daire
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(centerX, topY + radius),
      radius * 0.6,
      innerPaint,
    );

    // İkon (basit nokta)
    final iconPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(centerX, topY + radius),
      radius * 0.3,
      iconPaint,
    );

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // Helper to calculate bearing between two points
  static double calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    double startLatRad = _degreesToRadians(startLat);
    double startLngRad = _degreesToRadians(startLng);
    double endLatRad = _degreesToRadians(endLat);
    double endLngRad = _degreesToRadians(endLng);

    double dLng = endLngRad - startLngRad;
    double y = math.sin(dLng) * math.cos(endLatRad);
    double x =
        math.cos(startLatRad) * math.sin(endLatRad) -
        math.sin(startLatRad) * math.cos(endLatRad) * math.cos(dLng);

    double bearingRad = math.atan2(y, x);
    return (_radiansToDegrees(bearingRad) + 360) % 360;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  static double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  /// İki nokta arasındaki mesafeyi metre cinsinden hesaplar (Haversine formülü)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // metre cinsinden

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}

/// Gelişmiş marker animator - Uber/Bolt tarzı smooth hareket
class MarkerAnimator {
  double _currentLat;
  double _currentLng;
  double _currentRotation;

  Timer? _animationTimer;

  // Animasyon ayarları
  final int animationDurationMs;
  final int frameRateMs;
  final AnimationCurve curve;

  final Function(double lat, double lng, double rotation) onUpdate;

  MarkerAnimator({
    required double initialLat,
    required double initialLng,
    double initialRotation = 0,
    required this.onUpdate,
    this.animationDurationMs = 1000, // 1 saniye
    this.frameRateMs = 16, // ~60fps
    this.curve = AnimationCurve.easeInOut,
  })  : _currentLat = initialLat,
        _currentLng = initialLng,
        _currentRotation = initialRotation;

  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  double get currentRotation => _currentRotation;

  void animateTo(double targetLat, double targetLng, {double? targetRotation}) {
    _animationTimer?.cancel();

    // Çok küçük hareketleri atla
    final distance = AnimatedMapMarkers.calculateDistance(
      _currentLat,
      _currentLng,
      targetLat,
      targetLng,
    );

    if (distance < 1) {
      // 1 metreden az hareket
      return;
    }

    final startLat = _currentLat;
    final startLng = _currentLng;
    final startRotation = _currentRotation;

    // Rotasyonu hesapla veya verilen değeri kullan
    final calculatedRotation = targetRotation ??
        AnimatedMapMarkers.calculateBearing(
          startLat,
          startLng,
          targetLat,
          targetLng,
        );

    // Rotasyon farkını normalize et (-180 ile 180 arasında)
    double rotationDiff = calculatedRotation - startRotation;
    if (rotationDiff > 180) rotationDiff -= 360;
    if (rotationDiff < -180) rotationDiff += 360;

    final int totalSteps = animationDurationMs ~/ frameRateMs;
    int step = 0;
    final startTime = DateTime.now().millisecondsSinceEpoch;

    _animationTimer = Timer.periodic(
      Duration(milliseconds: frameRateMs),
      (timer) {
        step++;
        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        double t = (elapsed / animationDurationMs).clamp(0.0, 1.0);

        // Easing curve uygula
        t = curve.transform(t);

        // Animasyon bitti
        if (step >= totalSteps || t >= 1.0) {
          timer.cancel();
          _currentLat = targetLat;
          _currentLng = targetLng;
          _currentRotation = calculatedRotation;
          onUpdate(targetLat, targetLng, calculatedRotation);
          return;
        }

        // Lerp (Linear Interpolation)
        final lat = startLat + (targetLat - startLat) * t;
        final lng = startLng + (targetLng - startLng) * t;
        final rotation = startRotation + rotationDiff * t;

        _currentLat = lat;
        _currentLng = lng;
        _currentRotation = rotation;

        onUpdate(lat, lng, rotation);
      },
    );
  }

  void snapTo(double lat, double lng, {double? rotation}) {
    _animationTimer?.cancel();
    _currentLat = lat;
    _currentLng = lng;
    if (rotation != null) {
      _currentRotation = rotation;
    }
    onUpdate(_currentLat, _currentLng, _currentRotation);
  }

  void dispose() {
    _animationTimer?.cancel();
  }
}

/// Animasyon eğrileri
enum AnimationCurve {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  spring,
}

extension AnimationCurveExtension on AnimationCurve {
  double transform(double t) {
    switch (this) {
      case AnimationCurve.linear:
        return t;
      case AnimationCurve.easeIn:
        return t * t;
      case AnimationCurve.easeOut:
        return 1 - (1 - t) * (1 - t);
      case AnimationCurve.easeInOut:
        return t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
      case AnimationCurve.spring:
        // Hafif bir spring efekti
        const c4 = (2 * math.pi) / 3;
        return t == 0
            ? 0
            : t == 1
                ? 1
                : math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1;
    }
  }
}

/// Rota üzerinde taksi hareketi için gelişmiş controller
class TaxiRouteAnimator {
  final List<LatLng> routePoints;
  final Function(double lat, double lng, double rotation) onPositionUpdate;
  final Function(int currentIndex, int totalPoints)? onProgressUpdate;

  int _currentPointIndex = 0;
  Timer? _movementTimer;
  MarkerAnimator? _markerAnimator;
  bool _isAnimating = false;

  // Hız ayarları (m/s cinsinden)
  double _speedMetersPerSecond = 13.9; // ~50 km/h

  TaxiRouteAnimator({
    required this.routePoints,
    required this.onPositionUpdate,
    this.onProgressUpdate,
    double initialSpeedKmh = 50,
  }) : _speedMetersPerSecond = initialSpeedKmh * 1000 / 3600 {
    if (routePoints.isNotEmpty) {
      _markerAnimator = MarkerAnimator(
        initialLat: routePoints.first.latitude,
        initialLng: routePoints.first.longitude,
        onUpdate: onPositionUpdate,
        curve: AnimationCurve.easeInOut,
      );
    }
  }

  bool get isAnimating => _isAnimating;
  int get currentPointIndex => _currentPointIndex;
  int get totalPoints => routePoints.length;
  double get progress =>
      routePoints.isEmpty ? 0 : _currentPointIndex / routePoints.length;

  /// Hızı km/h cinsinden ayarla
  void setSpeedKmh(double kmh) {
    _speedMetersPerSecond = kmh * 1000 / 3600;
  }

  /// Rota animasyonunu başlat
  void startAnimation() {
    if (routePoints.length < 2) return;
    _isAnimating = true;
    _moveToNextPoint();
  }

  /// Animasyonu duraklat
  void pauseAnimation() {
    _isAnimating = false;
    _movementTimer?.cancel();
  }

  /// Animasyonu devam ettir
  void resumeAnimation() {
    if (_currentPointIndex < routePoints.length - 1) {
      _isAnimating = true;
      _moveToNextPoint();
    }
  }

  /// Belirli bir noktaya zıpla
  void jumpToPoint(int index) {
    if (index >= 0 && index < routePoints.length) {
      _currentPointIndex = index;
      final point = routePoints[index];
      _markerAnimator?.snapTo(point.latitude, point.longitude);
      onProgressUpdate?.call(_currentPointIndex, routePoints.length);
    }
  }

  /// Realtime konum güncellemesi (backend'den gelen)
  void updateRealPosition(double lat, double lng) {
    // Rotadaki en yakın noktayı bul
    int nearestIndex = _findNearestPointIndex(lat, lng);
    if (nearestIndex > _currentPointIndex) {
      _currentPointIndex = nearestIndex;
    }

    // Marker'ı animate et
    _markerAnimator?.animateTo(lat, lng);
    onProgressUpdate?.call(_currentPointIndex, routePoints.length);
  }

  int _findNearestPointIndex(double lat, double lng) {
    double minDistance = double.infinity;
    int nearestIndex = _currentPointIndex;

    // Sadece mevcut indexten sonrasına bak (geriye gitmesin)
    for (int i = _currentPointIndex; i < routePoints.length; i++) {
      final point = routePoints[i];
      final distance = AnimatedMapMarkers.calculateDistance(
        lat,
        lng,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  void _moveToNextPoint() {
    if (!_isAnimating || _currentPointIndex >= routePoints.length - 1) {
      _isAnimating = false;
      return;
    }

    final currentPoint = routePoints[_currentPointIndex];
    final nextPoint = routePoints[_currentPointIndex + 1];

    // İki nokta arasındaki mesafe
    final distance = AnimatedMapMarkers.calculateDistance(
      currentPoint.latitude,
      currentPoint.longitude,
      nextPoint.latitude,
      nextPoint.longitude,
    );

    // Bu mesafeyi katetmek için gereken süre (ms)
    final durationMs = (distance / _speedMetersPerSecond * 1000).round();

    // Marker'ı animate et
    _markerAnimator?.animateTo(
      nextPoint.latitude,
      nextPoint.longitude,
    );

    // Süre bitince bir sonraki noktaya geç
    _movementTimer = Timer(Duration(milliseconds: durationMs), () {
      _currentPointIndex++;
      onProgressUpdate?.call(_currentPointIndex, routePoints.length);

      if (_currentPointIndex < routePoints.length - 1) {
        _moveToNextPoint();
      } else {
        _isAnimating = false;
      }
    });
  }

  void dispose() {
    _movementTimer?.cancel();
    _markerAnimator?.dispose();
  }
}

/// Realtime taksi takip sistemi - Backend ile senkronize çalışır
class RealtimeTaxiTracker {
  final String rideId;
  final Function(double lat, double lng, double rotation) onLocationUpdate;
  final Function(int etaMinutes)? onEtaUpdate;
  final Function(double progressPercent)? onProgressUpdate;

  MarkerAnimator? _markerAnimator;
  List<LatLng> _routePoints = [];
  int _currentRouteIndex = 0;

  double _lastLat = 0;
  double _lastLng = 0;
  DateTime? _lastUpdateTime;

  // Tahminler için
  double _averageSpeedMps = 8.3; // ~30 km/h varsayılan şehir içi hız
  final List<double> _recentSpeeds = [];

  RealtimeTaxiTracker({
    required this.rideId,
    required this.onLocationUpdate,
    this.onEtaUpdate,
    this.onProgressUpdate,
    double? initialLat,
    double? initialLng,
  }) {
    if (initialLat != null && initialLng != null) {
      _lastLat = initialLat;
      _lastLng = initialLng;
      _markerAnimator = MarkerAnimator(
        initialLat: initialLat,
        initialLng: initialLng,
        onUpdate: onLocationUpdate,
        animationDurationMs: 1500, // Backend update aralığına uygun
        curve: AnimationCurve.easeOut,
      );
    }
  }

  /// Rota noktalarını ayarla
  void setRoutePoints(List<LatLng> points) {
    _routePoints = points;
  }

  /// Backend'den gelen konum güncellemesi
  void updateLocation(double lat, double lng) {
    final now = DateTime.now();

    // Hız hesapla (ortalama hız tahmini için)
    if (_lastUpdateTime != null && _lastLat != 0) {
      final timeDiffSeconds = now.difference(_lastUpdateTime!).inMilliseconds / 1000;
      if (timeDiffSeconds > 0) {
        final distance = AnimatedMapMarkers.calculateDistance(
          _lastLat,
          _lastLng,
          lat,
          lng,
        );
        final speed = distance / timeDiffSeconds;

        // Makul hız değerlerini kaydet (1-40 m/s arası, ~3.6-144 km/h)
        if (speed > 1 && speed < 40) {
          _recentSpeeds.add(speed);
          if (_recentSpeeds.length > 10) {
            _recentSpeeds.removeAt(0);
          }
          // Ortalama hızı güncelle
          _averageSpeedMps =
              _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
        }
      }
    }

    _lastLat = lat;
    _lastLng = lng;
    _lastUpdateTime = now;

    // Animator yoksa oluştur
    _markerAnimator ??= MarkerAnimator(
      initialLat: lat,
      initialLng: lng,
      onUpdate: onLocationUpdate,
      animationDurationMs: 1500,
      curve: AnimationCurve.easeOut,
    );

    // Smooth animate
    _markerAnimator!.animateTo(lat, lng);

    // Rota progress güncelle
    _updateRouteProgress(lat, lng);
  }

  void _updateRouteProgress(double lat, double lng) {
    if (_routePoints.isEmpty) return;

    // En yakın rota noktasını bul
    double minDist = double.infinity;
    int nearestIdx = _currentRouteIndex;

    for (int i = _currentRouteIndex; i < _routePoints.length; i++) {
      final dist = AnimatedMapMarkers.calculateDistance(
        lat,
        lng,
        _routePoints[i].latitude,
        _routePoints[i].longitude,
      );
      if (dist < minDist) {
        minDist = dist;
        nearestIdx = i;
      }
    }

    _currentRouteIndex = nearestIdx;

    // Progress yüzdesi
    final progressPercent = _routePoints.isNotEmpty
        ? (_currentRouteIndex / _routePoints.length) * 100
        : 0.0;
    onProgressUpdate?.call(progressPercent);

    // ETA hesapla
    _calculateAndUpdateEta(lat, lng);
  }

  void _calculateAndUpdateEta(double currentLat, double currentLng) {
    if (_routePoints.isEmpty || onEtaUpdate == null) return;

    // Kalan mesafeyi hesapla
    double remainingDistance = 0;
    for (int i = _currentRouteIndex; i < _routePoints.length - 1; i++) {
      remainingDistance += AnimatedMapMarkers.calculateDistance(
        _routePoints[i].latitude,
        _routePoints[i].longitude,
        _routePoints[i + 1].latitude,
        _routePoints[i + 1].longitude,
      );
    }

    // ETA = mesafe / ortalama hız (dakika cinsinden)
    if (_averageSpeedMps > 0) {
      final etaSeconds = remainingDistance / _averageSpeedMps;
      final etaMinutes = (etaSeconds / 60).ceil();
      onEtaUpdate!(etaMinutes);
    }
  }

  /// Mevcut konum
  LatLng? get currentPosition =>
      _lastLat != 0 ? LatLng(_lastLat, _lastLng) : null;

  /// Tahmini hız (km/h)
  double get estimatedSpeedKmh => _averageSpeedMps * 3.6;

  void dispose() {
    _markerAnimator?.dispose();
  }
}

/// Pulse efektli marker overlay widget
class PulsingMarkerOverlay extends StatefulWidget {
  final LatLng position;
  final Color color;
  final double size;
  final Widget? child;

  const PulsingMarkerOverlay({
    super.key,
    required this.position,
    this.color = Colors.blue,
    this.size = 100,
    this.child,
  });

  @override
  State<PulsingMarkerOverlay> createState() => _PulsingMarkerOverlayState();
}

class _PulsingMarkerOverlayState extends State<PulsingMarkerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
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
          alignment: Alignment.center,
          children: [
            // Pulse circle
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: _opacityAnimation.value),
                ),
              ),
            ),
            // Center marker
            if (widget.child != null) widget.child!,
          ],
        );
      },
    );
  }
}

class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
