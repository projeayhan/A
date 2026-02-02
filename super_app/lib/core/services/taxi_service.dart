import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Taksi servisi - Supabase ile iletişim
class TaxiService {
  static final _client = Supabase.instance.client;

  // ==================== VEHICLE TYPES ====================

  /// Araç tiplerini getir
  static Future<List<Map<String, dynamic>>> getVehicleTypes() async {
    final response = await _client
        .from('vehicle_types')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== RIDE OPERATIONS ====================

  /// Yeni sürüş talebi oluştur
  static Future<Map<String, dynamic>> createRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String vehicleTypeId,
    required double estimatedFare,
    required double distanceKm,
    required int durationMinutes,
    String? customerName,
    String? customerPhone,
    String? scheduledAt,
    String? promoCode,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    // Kullanıcı bilgilerini auth.users'dan al
    final userName =
        user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        user.email?.split('@').first ??
        'Müşteri';
    final userPhone = user.userMetadata?['phone'] ?? user.phone ?? '';

    final rideData = {
      'user_id': user.id,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'dropoff_address': dropoffAddress,
      'fare': estimatedFare,
      'distance_km': distanceKm,
      'duration_minutes': durationMinutes,
      'customer_name': customerName ?? userName,
      'customer_phone': customerPhone ?? userPhone,
      'status': 'pending',
    };

    final response = await _client
        .from('taxi_rides')
        .insert(rideData)
        .select()
        .single();

    return response;
  }

  /// Sürüş detaylarını getir
  static Future<Map<String, dynamic>?> getRide(String rideId) async {
    final response = await _client
        .from('taxi_rides')
        .select('''
          *,
          driver:taxi_drivers(
            id,
            full_name,
            phone,
            rating,
            total_rides,
            current_latitude,
            current_longitude,
            vehicle_brand,
            vehicle_model,
            vehicle_color,
            vehicle_plate,
            vehicle_year,
            profile_photo_url
          )
        ''')
        .eq('id', rideId)
        .maybeSingle();

    return response;
  }

  /// Kullanıcının aktif sürüşünü getir
  static Future<Map<String, dynamic>?> getActiveRide() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('taxi_rides')
        .select('''
          *,
          driver:taxi_drivers(
            id,
            full_name,
            phone,
            rating,
            total_rides,
            current_latitude,
            current_longitude,
            vehicle_brand,
            vehicle_model,
            vehicle_color,
            vehicle_plate,
            vehicle_year,
            profile_photo_url
          )
        ''')
        .eq('user_id', userId)
        .inFilter('status', ['pending', 'accepted', 'arrived', 'in_progress'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  /// Sürüşü iptal et
  static Future<void> cancelRide(String rideId, {String? reason}) async {
    await _client
        .from('taxi_rides')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancellation_reason': reason,
        })
        .eq('id', rideId);
  }

  /// Sürüşü puanla
  static Future<void> rateRide({
    required String rideId,
    required int rating,
    String? comment,
    double? tipAmount,
  }) async {
    await _client
        .from('taxi_rides')
        .update({
          'rating': rating,
          'rating_comment': comment,
          if (tipAmount != null) 'tip_amount': tipAmount,
        })
        .eq('id', rideId);

    // Sürücü rating'ini güncelle
    final ride = await getRide(rideId);
    if (ride != null && ride['driver_id'] != null) {
      await _updateDriverRating(ride['driver_id']);
    }
  }

  /// Sürücü rating'ini güncelle
  static Future<void> _updateDriverRating(String driverId) async {
    final rides = await _client
        .from('taxi_rides')
        .select('rating')
        .eq('driver_id', driverId)
        .not('rating', 'is', null);

    if (rides.isNotEmpty) {
      double totalRating = 0;
      for (final ride in rides) {
        totalRating += (ride['rating'] as num).toDouble();
      }
      final avgRating = totalRating / rides.length;

      await _client
          .from('taxi_drivers')
          .update({'rating': avgRating, 'total_rides': rides.length})
          .eq('id', driverId);
    }
  }

  // ==================== RIDE HISTORY ====================

  /// Sürüş geçmişini getir
  static Future<List<Map<String, dynamic>>> getRideHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('taxi_rides')
        .select('''
          *,
          driver:taxi_drivers(
            id,
            full_name,
            rating,
            vehicle_brand,
            vehicle_model,
            vehicle_plate,
            vehicle_color,
            vehicle_year,
            profile_photo_url
          )
        ''')
        .eq('user_id', userId)
        .inFilter('status', ['completed', 'cancelled'])
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== NEARBY DRIVERS ====================

  /// Yakındaki sürücüleri getir
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    String? vehicleTypeId,
  }) async {
    // Basit bir bounding box sorgusu
    final latDelta = radiusKm / 111.0; // 1 derece ~ 111 km
    final lngDelta = radiusKm / (111.0 * cosDegrees(latitude));

    final response = await _client
        .from('taxi_drivers')
        .select()
        .eq('is_online', true)
        .eq('status', 'approved')
        .gte('current_latitude', latitude - latDelta)
        .lte('current_latitude', latitude + latDelta)
        .gte('current_longitude', longitude - lngDelta)
        .lte('current_longitude', longitude + lngDelta)
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Cos fonksiyonu (derece cinsinden)
  static double cosDegrees(double degrees) {
    return cos(degrees * 3.141592653589793 / 180);
  }

  static double cos(double radians) {
    // Taylor serisi yaklaşımı
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -radians * radians / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  // ==================== REALTIME SUBSCRIPTIONS ====================

  /// Sürüş güncellemelerini dinle
  static RealtimeChannel subscribeToRide(
    String rideId,
    void Function(Map<String, dynamic>) onUpdate,
  ) {
    debugPrint('Subscribing to ride updates for: $rideId');

    return _client
        .channel('ride_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'taxi_rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            debugPrint('Ride update payload received: ${payload.newRecord}');
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Sürücü konumunu dinle
  static RealtimeChannel subscribeToDriverLocation(
    String driverId,
    void Function(double lat, double lng) onLocationUpdate,
  ) {
    return _client
        .channel('driver_location_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'taxi_drivers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: driverId,
          ),
          callback: (payload) {
            final lat = payload.newRecord['current_latitude'] as double?;
            final lng = payload.newRecord['current_longitude'] as double?;
            if (lat != null && lng != null) {
              onLocationUpdate(lat, lng);
            }
          },
        )
        .subscribe();
  }

  /// Subscription'ı kapat
  static Future<void> unsubscribe(RealtimeChannel channel) async {
    await channel.unsubscribe();
  }

  // ==================== SAVED LOCATIONS ====================

  /// Kayıtlı konumları getir
  static Future<List<Map<String, dynamic>>> getSavedLocations() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('saved_locations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Konum kaydet
  static Future<void> saveLocation({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String type, // 'home', 'work', 'other'
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await _client.from('saved_locations').insert({
      'user_id': userId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
    });
  }

  /// Kayıtlı konumu sil
  static Future<void> deleteSavedLocation(String locationId) async {
    await _client.from('saved_locations').delete().eq('id', locationId);
  }

  // ==================== FARE CALCULATION ====================

  /// Tahmini ücret hesapla (basit)
  static double calculateFareSimple({
    required double distanceKm,
    required int durationMinutes,
    required double baseFare,
    required double perKmRate,
    required double perMinuteRate,
    double? surgeMultiplier,
  }) {
    final surge = surgeMultiplier ?? 1.0;
    final fare =
        (baseFare +
            (distanceKm * perKmRate) +
            (durationMinutes * perMinuteRate)) *
        surge;
    return (fare * 100).round() / 100; // 2 decimal places
  }

  /// Ücret hesapla (API ile)
  static Future<Map<String, dynamic>> calculateFare({
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    String? vehicleTypeId,
    String? promotionCode,
  }) async {
    // Basit hesaplama - gerçek API olmadan
    final vehicleTypes = await getVehicleTypes();
    final vehicle = vehicleTypeId != null
        ? vehicleTypes.firstWhere(
            (v) => v['id'] == vehicleTypeId,
            orElse: () => vehicleTypes.first,
          )
        : vehicleTypes.first;

    // Haversine ile mesafe hesapla
    final distance = _calculateDistance(
      pickupLatitude,
      pickupLongitude,
      destinationLatitude,
      destinationLongitude,
    );

    // Tahmini süre (ortalama 30 km/h şehir içi)
    final duration = (distance / 30 * 60).round();

    final baseFare = (vehicle['base_fare'] as num?)?.toDouble() ?? 15.0;
    final perKm = (vehicle['per_km_rate'] as num?)?.toDouble() ?? 5.0;
    final perMin = (vehicle['per_minute_rate'] as num?)?.toDouble() ?? 0.5;

    final fare = baseFare + (distance * perKm) + (duration * perMin);

    return {
      'fare': (fare * 100).round() / 100,
      'distance_km': (distance * 100).round() / 100,
      'duration_minutes': duration,
      'vehicle_type': vehicle,
    };
  }

  /// Haversine mesafe hesaplama
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double deg) => deg * 3.141592653589793 / 180;
  static double _sin(double x) {
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _cos(double x) =>
      cos(x * 3.141592653589793 / 180 * 180 / 3.141592653589793);
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _atan(double x) {
    double result = x;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  // ==================== LEGACY COMPATIBILITY ====================

  /// requestRide - provider uyumluluğu için
  static Future<Map<String, dynamic>> requestRide({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    String? pickupName,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationAddress,
    String? destinationName,
    required String vehicleTypeId,
    required String paymentType,
    String? promotionId,
    double? estimatedDistanceKm,
    int? estimatedDurationMinutes,
    String? routePolyline,
  }) async {
    final ride = await createRide(
      pickupLat: pickupLatitude,
      pickupLng: pickupLongitude,
      pickupAddress: pickupAddress,
      dropoffLat: destinationLatitude,
      dropoffLng: destinationLongitude,
      dropoffAddress: destinationAddress,
      vehicleTypeId: vehicleTypeId,
      estimatedFare:
          estimatedDistanceKm != null && estimatedDurationMinutes != null
          ? calculateFareSimple(
              distanceKm: estimatedDistanceKm,
              durationMinutes: estimatedDurationMinutes,
              baseFare: 15,
              perKmRate: 5,
              perMinuteRate: 0.5,
            )
          : 0,
      distanceKm: estimatedDistanceKm ?? 0,
      durationMinutes: estimatedDurationMinutes ?? 0,
    );
    return {'data': ride};
  }

  /// findNearbyDrivers - provider uyumluluğu için
  static Future<List<Map<String, dynamic>>> findNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    String? vehicleTypeId,
  }) async {
    return getNearbyDrivers(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      vehicleTypeId: vehicleTypeId,
    );
  }

  /// Son konumları getir
  static Future<List<Map<String, dynamic>>> getRecentLocations() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('taxi_rides')
          .select('dropoff_address, dropoff_lat, dropoff_lng, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(10);

      final seen = <String>{};
      final result = <Map<String, dynamic>>[];

      for (final ride in response) {
        final address = ride['dropoff_address'] as String?;
        if (address != null && !seen.contains(address)) {
          seen.add(address);
          result.add({
            'id': address.hashCode.toString(),
            'name': address.split(',').first,
            'address': address,
            'latitude': ride['dropoff_lat'],
            'longitude': ride['dropoff_lng'],
            'type': 'recent',
          });
        }
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Feedback tags getir (veritabanından)
  static Future<List<Map<String, dynamic>>> getFeedbackTags({
    String? category,
  }) async {
    debugPrint('TaxiService: getFeedbackTags called with category: $category');
    try {
      var query = _client
          .from('taxi_feedback_tags')
          .select()
          .eq('is_active', true);

      if (category != null) {
        query = query.eq('category', category);
      }

      debugPrint('TaxiService: Executing feedback tags query...');
      final response = await query.order('sort_order');
      debugPrint(
        'TaxiService: Feedback tags query completed. Count: ${response.length}',
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('TaxiService: Error fetching feedback tags: $e');
      // Fallback - varsayılan etiketler
      return [
        {
          'id': '1',
          'tag_key': 'clean_vehicle',
          'tag_text_tr': 'Temiz araç',
          'category': category ?? 'positive',
        },
        {
          'id': '2',
          'tag_key': 'safe_driving',
          'tag_text_tr': 'Güvenli sürüş',
          'category': category ?? 'positive',
        },
        {
          'id': '3',
          'tag_key': 'polite_driver',
          'tag_text_tr': 'Nazik sürücü',
          'category': category ?? 'positive',
        },
        {
          'id': '4',
          'tag_key': 'on_time',
          'tag_text_tr': 'Zamanında varış',
          'category': category ?? 'positive',
        },
      ];
    }
  }

  /// Aktif promosyonları getir
  static Future<List<Map<String, dynamic>>> getActivePromotions() async {
    return [];
  }

  /// Sürücü promosyonlarını getir
  static Future<List<Map<String, dynamic>>> getDriverPromotions() async {
    return [];
  }

  // ==================== DRIVER OPERATIONS ====================

  /// Sürücü olarak oturum aç
  static Future<Map<String, dynamic>?> getDriverProfile() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('taxi_drivers')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return response;
  }

  /// ID'ye göre sürücü bilgisi getir
  static Future<Map<String, dynamic>?> getDriverById(String driverId) async {
    try {
      final response = await _client
          .from('taxi_drivers')
          .select()
          .eq('id', driverId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('TaxiService: Error getting driver by ID: $e');
      return null;
    }
  }

  /// Sürücü olarak kayıt ol
  static Future<Map<String, dynamic>?> registerAsDriver({
    required String fullName,
    required String phone,
    required String vehiclePlate,
    required String vehicleModel,
    String? vehicleColor,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli');

    // Önce mevcut kayıt var mı kontrol et
    final existing = await getDriverProfile();
    if (existing != null) {
      throw Exception('Zaten sürücü olarak kayıtlısınız');
    }

    final response = await _client
        .from('taxi_drivers')
        .insert({
          'user_id': userId,
          'full_name': fullName,
          'phone': phone,
          'vehicle_plate': vehiclePlate,
          'vehicle_model': vehicleModel,
          'vehicle_color': vehicleColor,
          'status': 'pending', // Onay bekliyor
          'is_online': false,
          'rating': 5.0,
          'total_rides': 0,
        })
        .select()
        .single();

    return response;
  }

  /// Sürücü konumunu güncelle
  static Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    await _client
        .from('taxi_drivers')
        .update({
          'current_latitude': latitude,
          'current_longitude': longitude,
          'last_location_update': DateTime.now().toIso8601String(),
        })
        .eq('id', driverId);
  }

  /// Sürücü online durumunu güncelle
  static Future<void> updateDriverOnlineStatus({
    required String driverId,
    required bool isOnline,
  }) async {
    await _client
        .from('taxi_drivers')
        .update({
          'is_online': isOnline,
          if (isOnline) 'last_online_at': DateTime.now().toIso8601String(),
        })
        .eq('id', driverId);
  }

  /// Bekleyen sürüş taleplerini getir (sürücü için)
  static Future<List<Map<String, dynamic>>> getPendingRideRequests({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / (111.0 * cosDegrees(latitude));

    final response = await _client
        .from('taxi_rides')
        .select('''
          *,
          user:profiles(
            id,
            full_name,
            avatar_url,
            phone
          )
        ''')
        .eq('status', 'pending')
        .isFilter('driver_id', null)
        .gte('pickup_lat', latitude - latDelta)
        .lte('pickup_lat', latitude + latDelta)
        .gte('pickup_lng', longitude - lngDelta)
        .lte('pickup_lng', longitude + lngDelta)
        .order('created_at', ascending: true)
        .limit(10);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Sürüşü kabul et (sürücü)
  static Future<Map<String, dynamic>?> acceptRide({
    required String rideId,
    required String driverId,
  }) async {
    // Önce sürüşün hala pending olduğunu kontrol et
    final currentRide = await _client
        .from('taxi_rides')
        .select()
        .eq('id', rideId)
        .eq('status', 'pending')
        .maybeSingle();

    if (currentRide == null) {
      return null; // Sürüş artık mevcut değil veya başka sürücü aldı
    }

    // Sürüşü kabul et
    final response = await _client
        .from('taxi_rides')
        .update({
          'driver_id': driverId,
          'status': 'accepted',
          'accepted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', rideId)
        .eq('status', 'pending')
        .select('''
          *,
          driver:taxi_drivers(
            id,
            full_name,
            phone,
            rating,
            total_rides,
            current_latitude,
            current_longitude,
            vehicle_brand,
            vehicle_model,
            vehicle_color,
            vehicle_plate,
            vehicle_year,
            profile_photo_url
          )
        ''')
        .maybeSingle();

    return response;
  }

  /// Müşteriye vardığını bildir (sürücü)
  static Future<void> arriveAtPickup(String rideId) async {
    await _client
        .from('taxi_rides')
        .update({
          'status': 'arrived',
          'arrived_at': DateTime.now().toIso8601String(),
        })
        .eq('id', rideId);
  }

  /// Yolculuğu başlat (sürücü)
  static Future<void> startRide(String rideId) async {
    await _client
        .from('taxi_rides')
        .update({
          'status': 'in_progress',
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', rideId);
  }

  /// Yolculuğu tamamla (sürücü)
  static Future<void> completeRide(String rideId) async {
    await _client
        .from('taxi_rides')
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', rideId);
  }

  /// Sürücünün aktif sürüşünü getir
  static Future<Map<String, dynamic>?> getDriverActiveRide(
    String driverId,
  ) async {
    final response = await _client
        .from('taxi_rides')
        .select('''
          *,
          user:profiles(
            id,
            full_name,
            avatar_url,
            phone
          )
        ''')
        .eq('driver_id', driverId)
        .inFilter('status', ['accepted', 'arrived', 'in_progress'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  /// Müşteri konumunu dinle (sürücü için)
  static RealtimeChannel subscribeToCustomerLocation(
    String rideId,
    void Function(double lat, double lng) onLocationUpdate,
  ) {
    return _client
        .channel('customer_location_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'taxi_rides',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: rideId,
          ),
          callback: (payload) {
            final lat = payload.newRecord['customer_lat'] as double?;
            final lng = payload.newRecord['customer_lng'] as double?;
            if (lat != null && lng != null) {
              onLocationUpdate(lat, lng);
            }
          },
        )
        .subscribe();
  }

  /// Yeni sürüş taleplerini dinle (sürücü için)
  static RealtimeChannel subscribeToNewRideRequests(
    void Function(Map<String, dynamic>) onNewRide,
  ) {
    return _client
        .channel('new_rides')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'taxi_rides',
          callback: (payload) {
            if (payload.newRecord['status'] == 'pending') {
              onNewRide(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  // ==================== DRIVER REVIEWS ====================

  /// Detaylı değerlendirme kaydet (etiketlerle birlikte)
  static Future<void> rateRideWithDetails({
    required String rideId,
    required int rating,
    String? comment,
    double? tipAmount,
    List<String>? feedbackTags,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) throw Exception('Kullanıcı oturumu bulunamadı');

    // taxi_rides tablosunu güncelle
    await _client
        .from('taxi_rides')
        .update({
          'rating': rating,
          'rating_comment': comment,
          if (tipAmount != null && tipAmount > 0) 'tip_amount': tipAmount,
        })
        .eq('id', rideId);

    // Ride bilgilerini al
    final ride = await getRide(rideId);
    if (ride == null) throw Exception('Sürüş bulunamadı');

    final driverId = ride['driver_id'] as String?;
    if (driverId == null) throw Exception('Sürücü bulunamadı');

    // Müşteri adını al
    final user = SupabaseService.currentUser;
    final customerName =
        user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        ride['customer_name'] ??
        'Müşteri';

    // driver_review_details kaydı oluştur
    await _client.from('driver_review_details').upsert({
      'ride_id': rideId,
      'driver_id': driverId,
      'customer_id': userId,
      'customer_name': customerName,
      'feedback_tags': feedbackTags ?? [],
    }, onConflict: 'ride_id');
  }

  /// Sürücü değerlendirmelerini getir
  static Future<List<Map<String, dynamic>>> getDriverReviews({
    required String driverId,
    int? ratingFilter,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from('driver_review_details')
        .select('''
          *,
          ride:taxi_rides(
            id,
            rating,
            rating_comment,
            tip_amount,
            pickup_address,
            dropoff_address,
            fare,
            completed_at
          )
        ''')
        .eq('driver_id', driverId)
        .eq('is_visible', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    var reviews = List<Map<String, dynamic>>.from(response);

    // Rating filtresi uygula (client-side)
    if (ratingFilter != null) {
      reviews = reviews.where((r) {
        final ride = r['ride'] as Map<String, dynamic>?;
        return ride?['rating'] == ratingFilter;
      }).toList();
    }

    return reviews;
  }

  /// Sürücü değerlendirme istatistiklerini getir
  static Future<Map<String, dynamic>?> getDriverRatingStats(
    String driverId,
  ) async {
    final response = await _client
        .from('taxi_drivers')
        .select('''
          id,
          rating,
          total_ratings,
          total_rides,
          rating_count_5,
          rating_count_4,
          rating_count_3,
          rating_count_2,
          rating_count_1,
          rating_30d,
          total_ratings_30d
        ''')
        .eq('id', driverId)
        .maybeSingle();

    return response;
  }

  /// Değerlendirmeye cevap ver
  static Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    await _client
        .from('driver_review_details')
        .update({
          'driver_reply': reply,
          'driver_replied_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId);
  }

  /// Cevabı güncelle
  static Future<void> updateReviewReply({
    required String reviewId,
    required String reply,
  }) async {
    await replyToReview(reviewId: reviewId, reply: reply);
  }

  /// Cevabı sil
  static Future<void> deleteReviewReply(String reviewId) async {
    await _client
        .from('driver_review_details')
        .update({
          'driver_reply': null,
          'driver_replied_at': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId);
  }

  /// Yeni değerlendirme bildirimlerini dinle (sürücü için)
  static RealtimeChannel subscribeToDriverRatings(
    String driverId,
    void Function(Map<String, dynamic>) onNewRating,
  ) {
    return _client
        .channel('driver_ratings_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'driver_review_details',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            onNewRating(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Değerlendirme cevap bildirimlerini dinle (müşteri için)
  static RealtimeChannel subscribeToReviewReplies(
    String customerId,
    void Function(Map<String, dynamic>) onReply,
  ) {
    return _client
        .channel('review_replies_$customerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_review_details',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: customerId,
          ),
          callback: (payload) {
            final oldReply = payload.oldRecord['driver_reply'];
            final newReply = payload.newRecord['driver_reply'];
            if (oldReply == null && newReply != null) {
              onReply(payload.newRecord);
            }
          },
        )
        .subscribe();
  }
}
