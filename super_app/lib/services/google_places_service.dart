import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;
  // Nominatim sonuçları için koordinatlar (opsiyonel)
  final double? latitude;
  final double? longitude;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
    this.latitude,
    this.longitude,
  });

  // Koordinatlar mevcut mu? (Nominatim sonuçları için true)
  bool get hasCoordinates => latitude != null && longitude != null;

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting['main_text'] ?? json['description'] ?? '',
      secondaryText: structuredFormatting['secondary_text'] ?? '',
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final result = json['result'] ?? json;
    final geometry = result['geometry'] ?? {};
    final location = geometry['location'] ?? {};

    return PlaceDetails(
      placeId: result['place_id'] ?? '',
      name: result['name'] ?? '',
      formattedAddress: result['formatted_address'] ?? '',
      latitude: (location['lat'] ?? 0.0).toDouble(),
      longitude: (location['lng'] ?? 0.0).toDouble(),
    );
  }
}

class DirectionsResult {
  final double distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final String polyline;
  final List<LatLng> routePoints;

  DirectionsResult({
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.polyline,
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

class GooglePlacesService {
  static const String _apiKey = 'AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ';
  static const String _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const Duration _httpTimeout = Duration(seconds: 10);

  // Autocomplete - adres tamamlama
  // Önce Nominatim (OSM) dene, başarısız olursa Google API kullan
  static Future<List<PlacePrediction>> getAutocompletePredictions({
    required String input,
    String? sessionToken,
    String language = 'tr',
    String? location, // lat,lng format
    int radius = 100000, // 100km radius
    String? components, // country:cy gibi - KKTC için boş bırakıyoruz
  }) async {
    if (input.isEmpty) return [];

    // Önce Nominatim (OpenStreetMap) dene - ücretsiz ve KKTC desteği var
    final nominatimResults = await _getAutocompleteFromNominatim(
      input: input,
      location: location,
    );
    if (nominatimResults.isNotEmpty) {
      return nominatimResults;
    }

    // Google Places API fallback
    final params = <String, String>{
      'input': input,
      'key': _apiKey,
      'language': language,
    };

    if (sessionToken != null) {
      params['sessiontoken'] = sessionToken;
    }

    // Location-based arama (KKTC bölgesi için)
    if (location != null) {
      params['location'] = location;
      params['radius'] = radius.toString();
      params['strictbounds'] = 'false'; // Bölge dışı sonuçlara da izin ver
    }

    // Components kısıtlaması - sadece belirtilmişse ekle
    if (components != null && components.isNotEmpty) {
      params['components'] = components;
    }

    final uri = Uri.parse('$_placesBaseUrl/autocomplete/json').replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions.map((p) => PlacePrediction.fromJson(p)).toList();
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        } else {
          if (kDebugMode) print('Places API Error: ${data['status']} - ${data['error_message'] ?? ''}');
          return [];
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching autocomplete predictions: $e');
    }

    return [];
  }

  // Nominatim (OpenStreetMap) autocomplete - KKTC desteği var
  static Future<List<PlacePrediction>> _getAutocompleteFromNominatim({
    required String input,
    String? location,
  }) async {
    try {
      // KKTC bölgesi için viewbox (sınırlayıcı kutu)
      // Kuzey Kıbrıs koordinatları: yaklaşık 35.0-35.7 lat, 32.3-34.6 lng
      final params = {
        'q': input,
        'format': 'json',
        'addressdetails': '1',
        'limit': '10',
        'accept-language': 'tr',
        // KKTC bölgesine öncelik ver
        'viewbox': '32.3,35.7,34.6,35.0',
        'bounded': '0', // Bölge dışı sonuçlara da izin ver
      };

      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'SuperApp/1.0'},
      ).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;

        if (data.isNotEmpty) {
          return data.map<PlacePrediction>((item) {
            final address = item['address'] as Map<String, dynamic>? ?? {};

            // Ana metin - en spesifik bilgi
            String mainText = item['name'] ?? '';
            if (mainText.isEmpty) {
              mainText = address['road'] ??
                        address['neighbourhood'] ??
                        address['suburb'] ??
                        item['display_name']?.toString().split(',').first ?? '';
            }

            // İkincil metin - şehir/bölge bilgisi
            final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
            final state = address['state'] ?? '';
            String secondaryText = [city, state].where((s) => s.isNotEmpty).join(', ');

            // Yer türleri
            List<String> types = [];
            final osmType = item['type']?.toString() ?? '';
            if (osmType.contains('restaurant') || osmType.contains('cafe')) {
              types.add('restaurant');
            } else if (osmType.contains('hospital') || osmType.contains('clinic')) {
              types.add('hospital');
            } else if (osmType.contains('school') || osmType.contains('university')) {
              types.add('school');
            } else if (osmType.contains('hotel')) {
              types.add('lodging');
            }

            return PlacePrediction(
              placeId: 'osm_${item['osm_id']}',
              description: item['display_name'] ?? '',
              mainText: mainText,
              secondaryText: secondaryText,
              types: types,
              // Nominatim koordinatları doğrudan döndürüyor
              latitude: double.tryParse(item['lat']?.toString() ?? ''),
              longitude: double.tryParse(item['lon']?.toString() ?? ''),
            );
          }).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching Nominatim predictions: $e');
    }

    return [];
  }

  // Place Details - seçilen yerin detaylarını al (koordinat dahil)
  static Future<PlaceDetails?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
    String language = 'tr',
  }) async {
    // OSM (Nominatim) sonucu ise Nominatim'den detay al
    if (placeId.startsWith('osm_')) {
      return _getPlaceDetailsFromNominatim(placeId);
    }

    // Google Places API
    final params = {
      'place_id': placeId,
      'key': _apiKey,
      'language': language,
      'fields': 'place_id,name,formatted_address,geometry',
    };

    if (sessionToken != null) {
      params['sessiontoken'] = sessionToken;
    }

    final uri = Uri.parse('$_placesBaseUrl/details/json').replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data);
        } else {
          if (kDebugMode) print('Place Details API Error: ${data['status']}');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching place details: $e');
    }

    return null;
  }

  // Nominatim'den yer detayları al
  static Future<PlaceDetails?> _getPlaceDetailsFromNominatim(String placeId) async {
    try {
      // osm_123456 formatından ID'yi çıkar
      final osmId = placeId.replaceFirst('osm_', '');

      final params = {
        'osm_ids': 'N$osmId,W$osmId,R$osmId', // Node, Way veya Relation olabilir
        'format': 'json',
        'addressdetails': '1',
        'accept-language': 'tr',
      };

      final uri = Uri.parse('https://nominatim.openstreetmap.org/lookup')
          .replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'SuperApp/1.0'},
      ).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;

        if (data.isNotEmpty) {
          final item = data[0];
          return PlaceDetails(
            placeId: placeId,
            name: item['name'] ?? item['display_name']?.toString().split(',').first ?? '',
            formattedAddress: item['display_name'] ?? '',
            latitude: double.tryParse(item['lat']?.toString() ?? '') ?? 0,
            longitude: double.tryParse(item['lon']?.toString() ?? '') ?? 0,
          );
        }
      }

      // Lookup başarısız olursa, search ile dene
      final searchParams = {
        'q': osmId,
        'format': 'json',
        'limit': '1',
        'accept-language': 'tr',
      };

      final searchUri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(queryParameters: searchParams);

      final searchResponse = await http.get(
        searchUri,
        headers: {'User-Agent': 'SuperApp/1.0'},
      ).timeout(_httpTimeout);

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body) as List;
        if (searchData.isNotEmpty) {
          final item = searchData[0];
          return PlaceDetails(
            placeId: placeId,
            name: item['name'] ?? item['display_name']?.toString().split(',').first ?? '',
            formattedAddress: item['display_name'] ?? '',
            latitude: double.tryParse(item['lat']?.toString() ?? '') ?? 0,
            longitude: double.tryParse(item['lon']?.toString() ?? '') ?? 0,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching Nominatim place details: $e');
    }

    return null;
  }

  // Supabase Edge Function URL for directions
  static const String _directionsEdgeFunction = 'https://mzgtvdgwxrlhgjboolys.supabase.co/functions/v1/directions';

  // Directions API - Supabase Edge Function (CORS-free proxy to OSRM)
  static Future<DirectionsResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
    String language = 'tr',
  }) async {
    try {
      final params = {
        'origin_lat': originLat.toString(),
        'origin_lng': originLng.toString(),
        'dest_lat': destLat.toString(),
        'dest_lng': destLng.toString(),
      };

      final uri = Uri.parse(_directionsEdgeFunction).replace(queryParameters: params);
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

        final distanceKm = distanceMeters / 1000;
        final durationMin = (durationSeconds / 60).round();

        String distanceText;
        if (distanceKm >= 1) {
          distanceText = '${distanceKm.toStringAsFixed(1)} km';
        } else {
          distanceText = '${distanceMeters.round()} m';
        }

        String durationText;
        if (durationMin >= 60) {
          final hours = durationMin ~/ 60;
          final mins = durationMin % 60;
          durationText = '$hours sa $mins dk';
        } else {
          durationText = '$durationMin dk';
        }

        return DirectionsResult(
          distanceMeters: distanceMeters,
          distanceText: distanceText,
          durationSeconds: durationSeconds,
          durationText: durationText,
          polyline: '',
          routePoints: routePoints,
        );
      } else {
        if (kDebugMode) print('Directions Edge Function Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching directions from edge function: $e');
    }

    return null;
  }

  // Polyline decode - Google'ın encoded polyline'ını çöz
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      // Latitude
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      // Longitude
      shift = 0;
      result = 0;
      while (true) {
        int b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
        if (b < 0x20) break;
      }
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  // Geocoding - koordinattan adres al
  static Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
    String language = 'tr',
  }) async {
    final params = {
      'latlng': '$latitude,$longitude',
      'key': _apiKey,
      'language': language,
    };

    final uri = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json')
        .replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          if (results.isNotEmpty) {
            return results[0]['formatted_address'];
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error reverse geocoding: $e');
    }

    return null;
  }

  // Session token oluştur - autocomplete maliyetini düşürmek için
  static String generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
