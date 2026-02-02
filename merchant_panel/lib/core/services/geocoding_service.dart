import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _apiKey = 'AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ';

  /// Koordinattan adres al (Reverse Geocoding)
  static Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&language=tr'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // En detaylı adresi al
          final result = data['results'][0];
          return result['formatted_address'] as String?;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Geocoding error: $e');
      return null;
    }
  }

  /// Koordinattan kısa adres al (mahalle, ilçe, şehir)
  static Future<String?> getShortAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&language=tr'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // Adres bileşenlerini al
          final components = data['results'][0]['address_components'] as List;

          String? neighborhood;
          String? district;
          String? city;
          String? country;

          for (final component in components) {
            final types = component['types'] as List;
            if (types.contains('neighborhood') || types.contains('sublocality')) {
              neighborhood = component['long_name'];
            } else if (types.contains('administrative_area_level_2')) {
              district = component['long_name'];
            } else if (types.contains('administrative_area_level_1') || types.contains('locality')) {
              city = component['long_name'];
            } else if (types.contains('country')) {
              country = component['long_name'];
            }
          }

          // Kısa adres oluştur
          final parts = <String>[];
          if (neighborhood != null) parts.add(neighborhood);
          if (district != null) parts.add(district);
          if (city != null) parts.add(city);
          if (country != null && country != 'Türkiye') parts.add(country);

          return parts.isNotEmpty ? parts.join(', ') : null;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Short geocoding error: $e');
      return null;
    }
  }

  /// Adresten koordinat al (Geocoding)
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&language=tr'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'lat': location['lat'] as double,
            'lng': location['lng'] as double,
          };
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Geocoding error: $e');
      return null;
    }
  }
}
