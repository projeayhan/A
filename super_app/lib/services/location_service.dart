import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static const String _googleApiKey = 'AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ';
  static const Duration _httpTimeout = Duration(seconds: 10);

  // Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _lastPosition;
  String? _lastAddress;

  Position? get lastPosition => _lastPosition;
  String? get lastAddress => _lastAddress;

  /// Konum iznini kontrol et ve iste
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Konum servisinin açık olup olmadığını kontrol et
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Konum iznini kontrol et
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Mevcut konumu al
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        return null;
      }

      LocationSettings settings;
      if (kIsWeb) {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        );
      } else {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        );
      }

      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      return _lastPosition;
    } catch (e) {
      if (kDebugMode) print('Error getting current position: $e');
      return null;
    }
  }

  /// Konum değişikliklerini dinle
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Koordinattan adres al (Google Geocoding API)
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$_googleApiKey&language=tr',
      );

      final response = await http.get(uri).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            _lastAddress = results[0]['formatted_address'];
            return _lastAddress;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error getting address from coordinates: $e');
    }
    return null;
  }

  /// Mevcut konumu ve adresini al
  Future<({Position? position, String? address})> getCurrentLocationWithAddress() async {
    final position = await getCurrentPosition();
    if (position == null) {
      return (position: null, address: null);
    }

    final address = await getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );

    return (position: position, address: address);
  }

  /// İki nokta arasındaki kuş uçuşu mesafeyi hesapla (metre)
  /// NOT: Bu sadece hızlı tahmin için kullanılmalı. Gerçek yol mesafesi için
  /// GooglePlacesService.getDirections() kullanın.
  double calculateStraightLineDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// İki nokta arasındaki GERÇEK YOL mesafesini hesapla (async)
  /// OSRM veya Google Directions API kullanır
  Future<({double distanceMeters, int durationSeconds, String distanceText, String durationText})?> calculateRealDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '$startLng,$startLat;$endLng,$endLat'
          '?overview=false';

      final response = await http.get(Uri.parse(url)).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok') {
          final routes = data['routes'] as List;
          if (routes.isNotEmpty) {
            final route = routes[0];
            final distanceMeters = (route['distance'] as num).toDouble();
            final durationSeconds = (route['duration'] as num).toInt();

            // Format distance text
            final distanceKm = distanceMeters / 1000;
            String distanceText;
            if (distanceKm >= 1) {
              distanceText = '${distanceKm.toStringAsFixed(1)} km';
            } else {
              distanceText = '${distanceMeters.round()} m';
            }

            // Format duration text
            final durationMin = (durationSeconds / 60).round();
            String durationText;
            if (durationMin >= 60) {
              final hours = durationMin ~/ 60;
              final mins = durationMin % 60;
              durationText = '$hours sa $mins dk';
            } else {
              durationText = '$durationMin dk';
            }

            return (
              distanceMeters: distanceMeters,
              durationSeconds: durationSeconds,
              distanceText: distanceText,
              durationText: durationText,
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error calculating real distance: $e');
    }
    return null;
  }

  /// @deprecated Use calculateStraightLineDistance instead
  /// Bu fonksiyon sadece geriye dönük uyumluluk için bırakıldı
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Varsayılan KKTC konumu (Lefkoşa)
  static const double defaultLat = 35.1856;
  static const double defaultLng = 33.3823;
  static const String defaultAddress = 'Lefkoşa, KKTC';
}
