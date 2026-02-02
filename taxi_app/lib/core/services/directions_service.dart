import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DirectionsResult {
  final double distanceMeters;
  final int durationSeconds;
  final List<LatLng> routePoints;

  DirectionsResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.routePoints,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

class DirectionsService {
  static const String _edgeFunctionUrl =
      'https://mzgtvdgwxrlhgjboolys.supabase.co/functions/v1/directions';

  static Future<DirectionsResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final params = {
        'origin_lat': originLat.toString(),
        'origin_lng': originLng.toString(),
        'dest_lat': destLat.toString(),
        'dest_lng': destLng.toString(),
      };

      final uri = Uri.parse(_edgeFunctionUrl).replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final distanceMeters = (data['distance_meters'] as num).toDouble();
        final durationSeconds = (data['duration_seconds'] as num).toInt();
        final routePointsData = data['route_points'] as List;

        final routePoints = routePointsData.map<LatLng>((point) {
          return LatLng(
            (point['latitude'] as num).toDouble(),
            (point['longitude'] as num).toDouble(),
          );
        }).toList();

        return DirectionsResult(
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          routePoints: routePoints,
        );
      } else {
        debugPrint('Directions API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching directions: $e');
    }

    return null;
  }
}
