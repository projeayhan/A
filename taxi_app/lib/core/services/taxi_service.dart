import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Taksi Surucu Servisi - Modern ve Temiz
class TaxiService {
  static SupabaseClient get _client => SupabaseService.client;

  // ==================== DRIVER PROFILE CACHE ====================

  static Map<String, dynamic>? _cachedDriverProfile;
  static DateTime? _cacheTimestamp;
  static const _cacheTtl = Duration(seconds: 60);

  /// Cache'i temizle (profil guncellemelerinde kullanilir)
  static void invalidateProfileCache() {
    _cachedDriverProfile = null;
    _cacheTimestamp = null;
  }

  // ==================== DRIVER PROFILE ====================

  /// Surucu profilini getir (60s cache ile)
  static Future<Map<String, dynamic>?> getDriverProfile({bool forceRefresh = false}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;

    // Cache kontrolu
    if (!forceRefresh &&
        _cachedDriverProfile != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTtl) {
      return _cachedDriverProfile;
    }

    try {
      final response = await _client
          .from('taxi_drivers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      _cachedDriverProfile = response;
      _cacheTimestamp = DateTime.now();
      return response;
    } catch (e) {
      debugPrint('getDriverProfile error: $e');
      return null;
    }
  }

  /// Surucu profili olustur
  static Future<Map<String, dynamic>?> createDriverProfile({
    required String fullName,
    required String phone,
    required String tcNo,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehiclePlate,
    required String vehicleColor,
    required int vehicleYear,
    required String vehicleType,
    String? email,
  }) async {
    // Oturumun kurulması için kısa bekleme
    await Future.delayed(const Duration(milliseconds: 500));

    // Oturumu yenile
    await SupabaseService.client.auth.refreshSession();

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      debugPrint('createDriverProfile error: userId is null - session not established');
      return null;
    }

    final userEmail = email ?? SupabaseService.currentUser?.email;
    debugPrint('Creating driver profile for userId: $userId, email: $userEmail');

    try {
      // taxi_drivers tablosuna ekle
      final response = await _client
          .from('taxi_drivers')
          .insert({
            'user_id': userId,
            'full_name': fullName,
            'phone': phone,
            'tc_no': tcNo,
            'email': userEmail,
            'vehicle_brand': vehicleBrand,
            'vehicle_model': vehicleModel,
            'vehicle_plate': vehiclePlate,
            'vehicle_color': vehicleColor,
            'vehicle_year': vehicleYear,
            'vehicle_type': vehicleType,
            'status': 'pending',
            'is_online': false,
            'is_verified': false,
            'rating': 0.0,
            'total_ratings': 0,
            'total_rides': 0,
            'total_earnings': 0.0,
          })
          .select()
          .single();

      debugPrint('Driver profile created successfully: ${response['id']}');

      // Admin panel icin partner_applications tablosuna da ekle
      try {
        await _client.from('partner_applications').insert({
          'user_id': userId,
          'application_type': 'taxi',
          'status': 'pending',
          'full_name': fullName,
          'phone': phone,
          'email': userEmail,
          'tc_no': tcNo,
          'vehicle_brand': vehicleBrand,
          'vehicle_model': vehicleModel,
          'vehicle_plate': vehiclePlate,
          'vehicle_color': vehicleColor,
          'vehicle_year': vehicleYear,
          'vehicle_type': vehicleType,
        });
        debugPrint('Partner application created for taxi driver');
      } catch (e) {
        debugPrint('Partner application insert error (non-critical): $e');
      }

      return response;
    } catch (e) {
      debugPrint('createDriverProfile error: $e');
      debugPrint('userId was: $userId');
      return null;
    }
  }

  /// Surucu profilini guncelle
  static Future<bool> updateDriverProfile(Map<String, dynamic> updates) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      await _client
          .from('taxi_drivers')
          .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', driver['id']);

      invalidateProfileCache();
      return true;
    } catch (e) {
      debugPrint('updateDriverProfile error: $e');
      return false;
    }
  }

  // ==================== ONLINE STATUS & LOCATION ====================

  /// Online/Offline durumunu guncelle
  static Future<bool> updateOnlineStatus(bool isOnline) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      await _client
          .from('taxi_drivers')
          .update({
            'is_online': isOnline,
            'last_online_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driver['id']);

      invalidateProfileCache();
      return true;
    } catch (e) {
      debugPrint('updateOnlineStatus error: $e');
      return false;
    }
  }

  /// Konum guncelle
  static Future<bool> updateLocation(double latitude, double longitude) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      await _client
          .from('taxi_drivers')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'location_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driver['id']);

      return true;
    } catch (e) {
      debugPrint('updateLocation error: $e');
      return false;
    }
  }

  // ==================== RIDE REQUESTS ====================

  /// Bekleyen surusleri getir (son 5 dakika)
  static Future<List<Map<String, dynamic>>> getPendingRides() async {
    try {
      final fiveMinutesAgo = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String();

      final response = await _client
          .from('taxi_rides')
          .select()
          .eq('status', 'pending')
          .isFilter('driver_id', null)
          .gte('created_at', fiveMinutesAgo)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getPendingRides error: $e');
      return [];
    }
  }

  /// Aktif surusleri getir (surucu icin)
  static Future<List<Map<String, dynamic>>> getActiveRides() async {
    final driver = await getDriverProfile();
    if (driver == null) return [];

    try {
      final response = await _client
          .from('taxi_rides')
          .select()
          .eq('driver_id', driver['id'])
          .inFilter('status', ['accepted', 'arrived', 'in_progress'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getActiveRides error: $e');
      return [];
    }
  }

  /// Aktif surusi getir (tek)
  static Future<Map<String, dynamic>?> getActiveRide() async {
    final rides = await getActiveRides();
    return rides.isNotEmpty ? rides.first : null;
  }

  /// Surus detayini getir
  static Future<Map<String, dynamic>?> getRide(String rideId) async {
    try {
      final response = await _client
          .from('taxi_rides')
          .select()
          .eq('id', rideId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('getRide error: $e');
      return null;
    }
  }

  // ==================== RIDE ACTIONS ====================

  /// Surusi kabul et
  static Future<bool> acceptRide(String rideId) async {
    final driver = await getDriverProfile();
    if (driver == null) {
      debugPrint('acceptRide: Driver profile not found');
      return false;
    }

    try {
      // Once surusun hala pending oldugundan emin ol
      final ride = await getRide(rideId);
      if (ride == null || ride['status'] != 'pending') {
        debugPrint('acceptRide: Ride not pending or not found');
        return false;
      }

      await _client
          .from('taxi_rides')
          .update({
            'driver_id': driver['id'],
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('status', 'pending'); // Sadece pending ise guncelle

      debugPrint(
        'acceptRide: Success - ride $rideId accepted by driver ${driver['id']}',
      );
      return true;
    } catch (e) {
      debugPrint('acceptRide error: $e');
      return false;
    }
  }

  /// Varisa ulasti (Musteri bekleme noktasina)
  static Future<bool> arriveAtPickup(String rideId) async {
    try {
      await _client
          .from('taxi_rides')
          .update({
            'status': 'arrived',
            'arrived_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      return true;
    } catch (e) {
      debugPrint('arriveAtPickup error: $e');
      return false;
    }
  }

  /// Yolculugu baslat (Musteri alindi)
  static Future<bool> startRide(String rideId) async {
    try {
      await _client
          .from('taxi_rides')
          .update({
            'status': 'in_progress',
            'picked_up_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      return true;
    } catch (e) {
      debugPrint('startRide error: $e');
      return false;
    }
  }

  /// Yolculugu tamamla
  static Future<bool> completeRide(String rideId) async {
    try {
      // Surus detayini al
      final ride = await getRide(rideId);
      if (ride == null) return false;

      final fare = (ride['fare'] as num?)?.toDouble() ?? 0;

      // Surusi tamamla
      await _client
          .from('taxi_rides')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      // Surucu istatistiklerini guncelle
      final driver = await getDriverProfile();
      if (driver != null) {
        await _client
            .from('taxi_drivers')
            .update({
              'total_rides': (driver['total_rides'] ?? 0) + 1,
              'total_earnings':
                  ((driver['total_earnings'] as num?)?.toDouble() ?? 0) + fare,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', driver['id']);

        invalidateProfileCache();
      }

      return true;
    } catch (e) {
      debugPrint('completeRide error: $e');
      return false;
    }
  }

  /// Surusi iptal et (surucu tarafindan)
  static Future<bool> cancelRide(String rideId, {String? reason}) async {
    try {
      await _client
          .from('taxi_rides')
          .update({
            'status': 'cancelled_by_driver',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason ?? 'Surucu tarafindan iptal edildi',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId);

      return true;
    } catch (e) {
      debugPrint('cancelRide error: $e');
      return false;
    }
  }

  // ==================== RIDE HISTORY & EARNINGS ====================

  /// Tamamlanan surusleri getir
  static Future<List<Map<String, dynamic>>> getCompletedRides({
    int limit = 50,
    int offset = 0,
  }) async {
    final driver = await getDriverProfile();
    if (driver == null) return [];

    try {
      final response = await _client
          .from('taxi_rides')
          .select()
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getCompletedRides error: $e');
      return [];
    }
  }

  /// Surus gecmisi (tum durumlar)
  static Future<List<Map<String, dynamic>>> getRideHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final driver = await getDriverProfile();
    if (driver == null) return [];

    try {
      final response = await _client
          .from('taxi_rides')
          .select()
          .eq('driver_id', driver['id'])
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getRideHistory error: $e');
      return [];
    }
  }

  /// Komisyon oranini getir
  static Future<double> getCommissionRate() async {
    try {
      final response = await _client
          .from('system_settings')
          .select('value')
          .eq('key', 'taxi_commission_rate')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        return double.tryParse(response['value'].toString()) ?? 20.0;
      }
      return 20.0; // Varsayilan %20
    } catch (e) {
      debugPrint('getCommissionRate error: $e');
      return 20.0;
    }
  }

  /// Kazanc ozeti
  static Future<Map<String, dynamic>> getEarningsSummary() async {
    final driver = await getDriverProfile();
    if (driver == null) {
      return {
        'today': 0.0,
        'week': 0.0,
        'month': 0.0,
        'total': 0.0,
        'commission_rate': 20.0,
        'commission_amount': 0.0,
        'net_earnings': 0.0,
        'today_rides': 0,
        'week_rides': 0,
        'month_rides': 0,
        'total_rides': 0,
        'rating': 5.0,
      };
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Bugunun surusleri
      final todayRides = await _client
          .from('taxi_rides')
          .select('fare')
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .gte('completed_at', today.toIso8601String());

      // Haftanin surusleri
      final weekRides = await _client
          .from('taxi_rides')
          .select('fare')
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .gte('completed_at', weekStart.toIso8601String());

      // Ayin surusleri
      final monthRides = await _client
          .from('taxi_rides')
          .select('fare')
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .gte('completed_at', monthStart.toIso8601String());

      double calculateTotal(List<dynamic> rides) {
        return rides.fold<double>(0, (sum, ride) {
          final fare = ride['fare'];
          return sum + (fare is num ? fare.toDouble() : 0.0);
        });
      }

      // Tum zamanlarin surusleri (Total tutarlilik icin DB'den hesapla)
      final allTimeRides = await _client
          .from('taxi_rides')
          .select('fare')
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .not('completed_at', 'is', null);

      final totalEarnings = calculateTotal(allTimeRides);

      final commissionRate = await getCommissionRate();
      final commissionAmount = totalEarnings * (commissionRate / 100);
      final netEarnings = totalEarnings - commissionAmount;

      return {
        'today': calculateTotal(todayRides),
        'week': calculateTotal(weekRides),
        'month': calculateTotal(monthRides),
        'total': totalEarnings,
        'commission_rate': commissionRate,
        'commission_amount': commissionAmount,
        'net_earnings': netEarnings,
        'today_rides': todayRides.length,
        'week_rides': weekRides.length,
        'month_rides': monthRides.length,
        'total_rides': driver['total_rides'] ?? 0,
        'rating': (driver['rating'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      debugPrint('getEarningsSummary error: $e');
      return {
        'today': 0.0,
        'week': 0.0,
        'month': 0.0,
        'total': (driver['total_earnings'] as num?)?.toDouble() ?? 0.0,
        'commission_rate': 20.0,
        'commission_amount': 0.0,
        'net_earnings': 0.0,
        'today_rides': 0,
        'week_rides': 0,
        'month_rides': 0,
        'total_rides': driver['total_rides'] ?? 0,
        'rating': (driver['rating'] as num?)?.toDouble() ?? 0.0,
      };
    }
  }

  /// Gunluk kazanc detayi (grafik icin)
  static Future<List<Map<String, dynamic>>> getDailyEarnings({
    int days = 7,
  }) async {
    final driver = await getDriverProfile();
    if (driver == null) return [];

    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final response = await _client
          .from('taxi_rides')
          .select('fare, completed_at')
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .gte('completed_at', startDate.toIso8601String())
          .order('completed_at', ascending: true);

      // Gunlere gore grupla
      final Map<String, double> dailyTotals = {};
      for (var ride in response) {
        final date = DateTime.parse(ride['completed_at'] as String);
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + fare;
      }

      return dailyTotals.entries
          .map((e) => {'date': e.key, 'amount': e.value})
          .toList();
    } catch (e) {
      debugPrint('getDailyEarnings error: $e');
      return [];
    }
  }

  // ==================== REALTIME SUBSCRIPTIONS ====================

  /// Yeni surus taleplerine abone ol
  static RealtimeChannel subscribeToNewRides(
    void Function(Map<String, dynamic> ride) onNewRide,
  ) {
    return _client
        .channel(
          'driver_pending_rides_${DateTime.now().millisecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'taxi_rides',
          callback: (payload) {
            final newRide = payload.newRecord;
            if (newRide['status'] == 'pending' &&
                newRide['driver_id'] == null) {
              debugPrint('New ride request received: ${newRide['id']}');
              onNewRide(newRide);
            }
          },
        )
        .subscribe();
  }

  /// Belirli bir surusu dinle
  static RealtimeChannel subscribeToRide(
    String rideId,
    void Function(Map<String, dynamic> ride) onUpdate,
  ) {
    return _client
        .channel('driver_ride_$rideId')
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
            debugPrint('Ride $rideId updated: ${payload.newRecord['status']}');
            onUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  // ==================== UTILITY ====================

  /// Mesafe hesapla (km)
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  // ==================== DRIVER REVIEWS ====================

  /// Sürücünün değerlendirmelerini getir
  static Future<List<Map<String, dynamic>>> getDriverReviews() async {
    final driver = await getDriverProfile();
    if (driver == null) return [];

    try {
      final response = await _client
          .from('taxi_rides')
          .select('id, rating, rating_comment, completed_at, customer_name, feedback_tags, driver_reply, driver_reply_at')
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .not('rating', 'is', null)
          .order('completed_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getDriverReviews error: $e');
      return [];
    }
  }

  /// Sürücü yoruma cevap ver (sadece 1 kez)
  static Future<bool> replyToReview({
    required String rideId,
    required String reply,
  }) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      // Önce mevcut cevabı kontrol et
      final existing = await _client
          .from('taxi_rides')
          .select('driver_reply')
          .eq('id', rideId)
          .eq('driver_id', driver['id'])
          .maybeSingle();

      if (existing == null) {
        debugPrint('replyToReview: Ride not found or not belonging to driver');
        return false;
      }

      // Zaten cevap verilmiş mi?
      if (existing['driver_reply'] != null && existing['driver_reply'].toString().isNotEmpty) {
        debugPrint('replyToReview: Already replied to this review');
        return false;
      }

      // Cevabı kaydet
      await _client
          .from('taxi_rides')
          .update({
            'driver_reply': reply,
            'driver_reply_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driver['id']);

      return true;
    } catch (e) {
      debugPrint('replyToReview error: $e');
      return false;
    }
  }

  /// Kazanc gecmisi (ride bazli)
  static Future<List<Map<String, dynamic>>> getEarningsHistory({
    int limit = 30,
  }) async {
    final driver = await getDriverProfile();
    if (driver == null) return [];

    try {
      final response = await _client
          .from('taxi_rides')
          .select('id, ride_number, fare, completed_at, created_at')
          .eq('driver_id', driver['id'])
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(
        response.map(
          (r) => {
            'id': r['id'],
            'ride_number': r['ride_number'],
            'amount': r['fare'],
            'created_at': r['completed_at'] ?? r['created_at'],
          },
        ),
      );
    } catch (e) {
      debugPrint('getEarningsHistory error: $e');
      return [];
    }
  }
}
