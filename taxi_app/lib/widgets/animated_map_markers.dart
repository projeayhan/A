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
      return await createCustomMarker(
        assetPath: 'assets/images/taxi_3d_icon.png',
        size: Size(size, size),
      );
    } catch (e) {
      debugPrint('Error loading taxi marker: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
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
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  // 3D Dropoff Marker
  static Future<BitmapDescriptor> createDropoffMarker({
    double size = 90,
  }) async {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  // 3D Customer Marker
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
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
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
}

// Helper class to animate marker movement smoothly
class MarkerAnimator {
  double _currentLat;
  double _currentLng;
  double _currentRotation;

  Timer? _animationTimer;
  static const int _animationSteps = 60; // ~1 second animation duration

  final Function(double lat, double lng, double rotation) onUpdate;

  MarkerAnimator({
    required double initialLat,
    required double initialLng,
    double initialRotation = 0,
    required this.onUpdate,
  }) : _currentLat = initialLat,
       _currentLng = initialLng,
       _currentRotation = initialRotation;

  void animateTo(double targetLat, double targetLng) {
    _animationTimer?.cancel();

    // If very close, just snap to avoid micro-movements
    if ((_currentLat - targetLat).abs() < 0.00001 &&
        (_currentLng - targetLng).abs() < 0.00001) {
      return;
    }

    final startLat = _currentLat;
    final startLng = _currentLng;
    final startRotation = _currentRotation;

    final targetRotation = AnimatedMapMarkers.calculateBearing(
      startLat,
      startLng,
      targetLat,
      targetLng,
    );

    // Handle rotation wrapping (e.g. 350 -> 10 degrees)
    double rotationDiff = targetRotation - startRotation;
    if (rotationDiff > 180) rotationDiff -= 360;
    if (rotationDiff < -180) rotationDiff += 360;

    int step = 0;
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      step++;
      final t = step / _animationSteps; // Normalized time 0.0 -> 1.0

      // End animation
      if (step > _animationSteps) {
        timer.cancel();
        _currentLat = targetLat;
        _currentLng = targetLng;
        _currentRotation = targetRotation;
        onUpdate(targetLat, targetLng, targetRotation);
        return;
      }

      // Linear interpolation (Lerp)
      final lat = startLat + (targetLat - startLat) * t;
      final lng = startLng + (targetLng - startLng) * t;
      final rotation = startRotation + rotationDiff * t;

      _currentLat = lat;
      _currentLng = lng;
      _currentRotation = rotation;

      onUpdate(lat, lng, rotation);
    });
  }

  void dispose() {
    _animationTimer?.cancel();
  }
}
