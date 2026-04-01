import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'log_service.dart';
import 'supabase_service.dart';
import '../../models/ride_models.dart';

/// Taksi Surucu Servisi - Modern ve Temiz
class TaxiService {
  static SupabaseClient get _client => SupabaseService.client;

  // ==================== DRIVER PROFILE CACHE ====================

  static Map<String, dynamic>? _cachedDriverProfile;
  static DateTime? _cacheTimestamp;
  static const _cacheTtl = Duration(seconds: 300);

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
    } catch (e, st) {
      LogService.error('getDriverProfile error', error: e, stackTrace: st, source: 'TaxiService:getDriverProfile');
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
    required List<String> vehicleTypes,
    String? email,
  }) async {
    // Oturumun kurulmasını bekle (max 3 saniye)
    for (var i = 0; i < 6; i++) {
      if (SupabaseService.currentUser != null) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    // Hala oturum yoksa yenilemeyi dene
    if (SupabaseService.currentUser == null) {
      try {
        await SupabaseService.client.auth.refreshSession();
      } catch (e, st) { LogService.error('refreshSession error', error: e, stackTrace: st, source: 'TaxiService:createDriverProfile'); }
    }

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      LogService.error('createDriverProfile error: userId is null - session not established', source: 'TaxiService:createDriverProfile');
      return null;
    }

    final userEmail = email ?? SupabaseService.currentUser?.email;
    if (kDebugMode) {
      debugPrint('Creating driver profile for userId: $userId, email: $userEmail');
    }

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
            'vehicle_types': vehicleTypes,
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

      if (kDebugMode) {
        debugPrint('Driver profile created successfully: ${response['id']}');
      }

      // users tablosunda ad soyad güncelle (super_app girişinde yönlendirme kontrolü için)
      try {
        final parcalar = fullName.split(' ');
        final ad = parcalar.first;
        final soyad = parcalar.length > 1 ? parcalar.sublist(1).join(' ') : '';
        await _client
            .from('users')
            .update({
              'first_name': ad,
              'last_name': soyad,
              'phone': phone,
            })
            .eq('id', userId);
      } catch (e, st) {
        LogService.error('users table update error', error: e, stackTrace: st, source: 'TaxiService:createDriverProfile');
      }

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
          'vehicle_type': vehicleTypes.join(','),
        });
        LogService.info('Partner application created for taxi driver', source: 'TaxiService:createDriverProfile');
      } catch (e, st) {
        LogService.error('Partner application insert error (non-critical)', error: e, stackTrace: st, source: 'TaxiService:createDriverProfile');
      }

      return response;
    } catch (e, st) {
      LogService.error('createDriverProfile error', error: e, stackTrace: st, source: 'TaxiService:createDriverProfile');
      return null;
    }
  }

  /// Surucu profilini guncelle
  static Future<bool> updateDriverProfile(Map<String, dynamic> updates) async {
    const allowedFields = {
      'bank_name', 'bank_iban', 'bank_account_holder', 'phone',
      'vehicle_brand', 'vehicle_model', 'vehicle_plate', 'vehicle_color',
      'vehicle_year', 'vehicle_types', 'profile_photo_url',
      'notification_settings',
    };

    final filtered = Map<String, dynamic>.fromEntries(
      updates.entries.where((e) => allowedFields.contains(e.key)),
    );
    if (filtered.isEmpty) return false;

    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      await _client
          .from('taxi_drivers')
          .update({...filtered, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', driver['id']);

      invalidateProfileCache();
      return true;
    } catch (e, st) {
      LogService.error('updateDriverProfile error', error: e, stackTrace: st, source: 'TaxiService:updateDriverProfile');
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
    } catch (e, st) {
      LogService.error('updateOnlineStatus error', error: e, stackTrace: st, source: 'TaxiService:updateOnlineStatus');
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
    } catch (e, st) {
      LogService.error('updateLocation error', error: e, stackTrace: st, source: 'TaxiService:updateLocation');
      return false;
    }
  }

  // ==================== RIDE REQUESTS ====================

  /// Bekleyen surusleri getir (son 5 dakika, kategori filtreli)
  static Future<List<Map<String, dynamic>>> getPendingRides({
    List<String>? driverVehicleTypes,
  }) async {
    try {
      final fiveMinutesAgo = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String();

      var query = _client
          .from('taxi_rides')
          .select()
          .eq('status', 'pending')
          .isFilter('driver_id', null)
          .gte('created_at', fiveMinutesAgo);

      // Sürücünün araç kategorilerine göre filtrele
      if (driverVehicleTypes != null && driverVehicleTypes.isNotEmpty) {
        query = query.inFilter('vehicle_type', driverVehicleTypes);
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      LogService.error('getPendingRides error', error: e, stackTrace: st, source: 'TaxiService:getPendingRides');
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
    } catch (e, st) {
      LogService.error('getActiveRides error', error: e, stackTrace: st, source: 'TaxiService:getActiveRides');
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
    } catch (e, st) {
      LogService.error('getRide error', error: e, stackTrace: st, source: 'TaxiService:getRide');
      return null;
    }
  }

  // ==================== RIDE ACTIONS ====================

  /// Surusi kabul et
  static Future<bool> acceptRide(String rideId) async {
    final driver = await getDriverProfile();
    if (driver == null) {
      LogService.error('acceptRide: Driver profile not found', source: 'TaxiService:acceptRide');
      return false;
    }

    try {
      // Once surusun hala pending oldugundan emin ol
      final ride = await getRide(rideId);
      if (ride == null || ride['status'] != 'pending') {
        LogService.error('acceptRide: Ride not pending or not found', source: 'TaxiService:acceptRide');
        return false;
      }

      final result = await _client
          .from('taxi_rides')
          .update({
            'driver_id': driver['id'],
            'status': 'accepted',
            'accepted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('status', 'pending') // Sadece pending ise guncelle
          .select('id');

      if ((result as List).isEmpty) {
        LogService.error('acceptRide: Ride already taken or not found', source: 'TaxiService:acceptRide');
        return false;
      }

      LogService.info('acceptRide: Success - ride $rideId accepted by driver ${driver['id']}', source: 'TaxiService:acceptRide');
      return true;
    } catch (e, st) {
      LogService.error('acceptRide error', error: e, stackTrace: st, source: 'TaxiService:acceptRide');
      return false;
    }
  }

  /// Varisa ulasti (Musteri bekleme noktasina)
  static Future<bool> arriveAtPickup(String rideId) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      final result = await _client
          .from('taxi_rides')
          .update({
            'status': 'arrived',
            'arrived_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driver['id'])
          .select('id');

      if ((result as List).isEmpty) return false;
      return true;
    } catch (e, st) {
      LogService.error('arriveAtPickup error', error: e, stackTrace: st, source: 'TaxiService:arriveAtPickup');
      return false;
    }
  }

  /// Yolculugu baslat (Musteri alindi)
  static Future<bool> startRide(String rideId) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      final now = DateTime.now().toIso8601String();
      final result = await _client
          .from('taxi_rides')
          .update({
            'status': 'in_progress',
            'picked_up_at': now,  // taxi_app native field
            'started_at': now,    // super_app compatibility
            'updated_at': now,
          })
          .eq('id', rideId)
          .eq('driver_id', driver['id'])
          .select('id');

      if ((result as List).isEmpty) return false;
      return true;
    } catch (e, st) {
      LogService.error('startRide error', error: e, stackTrace: st, source: 'TaxiService:startRide');
      return false;
    }
  }

  /// Yolculugu tamamla (atomik RPC ile race condition onlenir)
  static Future<bool> completeRide(String rideId) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      // Surusi tamamla ve istatistikleri atomik olarak guncelle (tek DB transaction)
      await _client.rpc('complete_ride_and_update_stats', params: {
        'p_ride_id': rideId,
        'p_driver_id': driver['id'],
      });

      invalidateProfileCache();

      return true;
    } catch (e, st) {
      LogService.error('completeRide error', error: e, stackTrace: st, source: 'TaxiService:completeRide');

      // RPC mevcut degil veya basarisiz olduysa fallback: en azindan ride'i tamamla
      try {
        final result = await _client
            .from('taxi_rides')
            .update({
              'status': 'completed',
              'completed_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', rideId)
            .eq('driver_id', driver['id'])
            .select('id, fare');

        if ((result as List).isEmpty) return false;

        final fare = (result.first['fare'] as num?)?.toDouble() ?? 0;

        // Atomik kazanc guncellemesi (total_rides ayri RPC ile)
        try {
          await _client.rpc('increment_driver_stats', params: {
            'p_driver_id': driver['id'],
            'p_amount': fare,
          });
        } catch (rpcError, st) {
          LogService.error('increment_driver_stats error (non-critical)', error: rpcError, stackTrace: st, source: 'TaxiService:completeRide');
          // Stat guncelleme basarisiz olsa bile ride tamamlandi sayilir
        }

        invalidateProfileCache();
        return true;
      } catch (fallbackError, st) {
        LogService.error('completeRide fallback error', error: fallbackError, stackTrace: st, source: 'TaxiService:completeRide');
        return false;
      }
    }
  }

  /// Surusi iptal et (surucu tarafindan)
  static Future<bool> cancelRide(String rideId, {String? reason}) async {
    final driver = await getDriverProfile();
    if (driver == null) return false;

    try {
      final result = await _client
          .from('taxi_rides')
          .update({
            'status': 'cancelled_by_driver',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason ?? 'Surucu tarafindan iptal edildi',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('driver_id', driver['id'])
          .select('id');

      if ((result as List).isEmpty) return false;
      return true;
    } catch (e, st) {
      LogService.error('cancelRide error', error: e, stackTrace: st, source: 'TaxiService:cancelRide');
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
    } catch (e, st) {
      LogService.error('getCompletedRides error', error: e, stackTrace: st, source: 'TaxiService:getCompletedRides');
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
    } catch (e, st) {
      LogService.error('getRideHistory error', error: e, stackTrace: st, source: 'TaxiService:getRideHistory');
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
    } catch (e, st) {
      LogService.error('getCommissionRate error', error: e, stackTrace: st, source: 'TaxiService:getCommissionRate');
      return 20.0;
    }
  }

  /// Kazanc ozeti
  static Future<EarningsSummary> getEarningsSummary() async {
    final driver = await getDriverProfile();
    if (driver == null) {
      return EarningsSummary.empty();
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

      return EarningsSummary(
        today: calculateTotal(todayRides),
        week: calculateTotal(weekRides),
        month: calculateTotal(monthRides),
        total: totalEarnings,
        commissionRate: commissionRate,
        commissionAmount: commissionAmount,
        netEarnings: netEarnings,
        todayRides: todayRides.length,
        weekRides: weekRides.length,
        monthRides: monthRides.length,
        totalRides: driver['total_rides'] as int? ?? 0,
        rating: (driver['rating'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e, st) {
      LogService.error('getEarningsSummary error', error: e, stackTrace: st, source: 'TaxiService:getEarningsSummary');
      return EarningsSummary(
        today: 0.0,
        week: 0.0,
        month: 0.0,
        total: (driver['total_earnings'] as num?)?.toDouble() ?? 0.0,
        commissionRate: 20.0,
        commissionAmount: 0.0,
        netEarnings: 0.0,
        todayRides: 0,
        weekRides: 0,
        monthRides: 0,
        totalRides: driver['total_rides'] as int? ?? 0,
        rating: (driver['rating'] as num?)?.toDouble() ?? 0.0,
      );
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
    } catch (e, st) {
      LogService.error('getDailyEarnings error', error: e, stackTrace: st, source: 'TaxiService:getDailyEarnings');
      return [];
    }
  }

  // ==================== REALTIME SUBSCRIPTIONS ====================

  /// Yeni surus taleplerine abone ol (sunucu tarafinda filtre ile bant genisligi azaltilir)
  static RealtimeChannel subscribeToNewRides(
    void Function(Map<String, dynamic> ride) onNewRide,
  ) {
    return _client
        .channel('driver_pending_rides')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'taxi_rides',
          // Sunucu tarafinda filtre: sadece 'pending' durumundaki surusler iletilir
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'pending',
          ),
          callback: (payload) {
            final newRide = payload.newRecord;
            // Istemci tarafinda ek dogrulama (sunucu filtresi yeterli olmayan durumlarda)
            if (newRide['status'] == 'pending' &&
                newRide['driver_id'] == null) {
              LogService.info('New ride request received: ${newRide['id']}', source: 'TaxiService:subscribeToNewRides');
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
            LogService.info('Ride $rideId updated: ${payload.newRecord['status']}', source: 'TaxiService:subscribeToRide');
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
    } catch (e, st) {
      LogService.error('getDriverReviews error', error: e, stackTrace: st, source: 'TaxiService:getDriverReviews');
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
        LogService.error('replyToReview: Ride not found or not belonging to driver', source: 'TaxiService:replyToReview');
        return false;
      }

      // Zaten cevap verilmiş mi?
      if (existing['driver_reply'] != null && existing['driver_reply'].toString().isNotEmpty) {
        LogService.error('replyToReview: Already replied to this review', source: 'TaxiService:replyToReview');
        return false;
      }

      final replyData = {
        'driver_reply': reply,
        'driver_reply_at': DateTime.now().toIso8601String(),
      };

      // taxi_rides tablosuna yaz (taxi_app kendi okumasi icin)
      await _client
          .from('taxi_rides')
          .update(replyData)
          .eq('id', rideId)
          .eq('driver_id', driver['id']);

      // super_app driver_review_details tablosuna da yaz (musteri gorsun)
      try {
        await _client
            .from('driver_review_details')
            .update(replyData)
            .eq('ride_id', rideId);
      } catch (e, st) {
        LogService.error('replyToReview driver_review_details update error', error: e, stackTrace: st, source: 'TaxiService:replyToReview');
      }

      return true;
    } catch (e, st) {
      LogService.error('replyToReview error', error: e, stackTrace: st, source: 'TaxiService:replyToReview');
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
    } catch (e, st) {
      LogService.error('getEarningsHistory error', error: e, stackTrace: st, source: 'TaxiService:getEarningsHistory');
      return [];
    }
  }

  // ==================== DOCUMENTS ====================

  /// Partner application ID'sini getir
  static Future<String?> _getApplicationId() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('partner_applications')
          .select('id')
          .eq('user_id', userId)
          .eq('application_type', 'taxi')
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e, st) {
      LogService.error('getApplicationId error', error: e, stackTrace: st, source: 'TaxiService:getApplicationId');
      return null;
    }
  }

  /// Belgeleri getir
  static Future<List<Map<String, dynamic>>> getDocuments() async {
    final appId = await _getApplicationId();
    if (appId == null) return [];

    try {
      final response = await _client
          .from('partner_documents')
          .select()
          .eq('application_id', appId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      LogService.error('getDocuments error', error: e, stackTrace: st, source: 'TaxiService:getDocuments');
      return [];
    }
  }

  /// Belge yukle
  static Future<bool> uploadDocument({
    required String type,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    final appId = await _getApplicationId();
    if (userId == null || appId == null) return false;

    try {
      // Storage'a yukle
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'documents/$userId/${type}_${DateTime.now().millisecondsSinceEpoch}_$safeName';

      await _client.storage.from('images').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final url = _client.storage.from('images').getPublicUrl(path);

      // Mevcut belge var mi kontrol et
      final existing = await _client
          .from('partner_documents')
          .select('id')
          .eq('application_id', appId)
          .eq('type', type)
          .maybeSingle();

      if (existing != null) {
        await _client.from('partner_documents').update({
          'url': url,
          'status': 'pending',
          'rejection_reason': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing['id']);
      } else {
        await _client.from('partner_documents').insert({
          'application_id': appId,
          'type': type,
          'url': url,
          'status': 'pending',
        });
      }

      return true;
    } catch (e, st) {
      LogService.error('uploadDocument error', error: e, stackTrace: st, source: 'TaxiService:uploadDocument');
      return false;
    }
  }
}
