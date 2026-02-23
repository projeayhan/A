import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Emlakçı (Realtor) Servisi
/// Emlakçı başvuruları, profil yönetimi, müşteri ve randevu işlemleri
class RealtorService {
  static final RealtorService _instance = RealtorService._internal();
  factory RealtorService() => _instance;
  RealtorService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== BAŞVURU İŞLEMLERİ ====================

  /// Emlakçı başvurusu yap
  Future<Map<String, dynamic>?> submitApplication({
    required String fullName,
    required String phone,
    required String email,
    String? companyName,
    String? licenseNumber,
    String? taxNumber,
    int experienceYears = 0,
    List<String>? specialization,
    List<String>? workingCities,
    String? idDocumentUrl,
    String? licenseDocumentUrl,
    String? taxDocumentUrl,
    String? applicantMessage,
  }) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    // Mevcut başvuru var mı kontrol et
    final existing = await _client
        .from('realtor_applications')
        .select('id, status')
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null && existing['status'] == 'pending') {
      throw Exception('Zaten bekleyen bir başvurunuz var');
    }

    final response = await _client.from('realtor_applications').insert({
      'user_id': _userId,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'company_name': companyName,
      'license_number': licenseNumber,
      'tax_number': taxNumber,
      'experience_years': experienceYears,
      'specialization': specialization,
      'working_cities': workingCities,
      'id_document_url': idDocumentUrl,
      'license_document_url': licenseDocumentUrl,
      'tax_document_url': taxDocumentUrl,
      'applicant_message': applicantMessage,
      'status': 'pending',
    }).select().single();

    return response;
  }

  /// Başvuru durumunu kontrol et
  Future<Map<String, dynamic>?> getApplicationStatus() async {
    if (_userId == null) return null;

    final response = await _client
        .from('realtor_applications')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  /// Başvuruyu güncelle (sadece pending durumunda)
  Future<Map<String, dynamic>?> updateApplication(
    String applicationId,
    Map<String, dynamic> updates,
  ) async {
    if (_userId == null) return null;

    final response = await _client
        .from('realtor_applications')
        .update(updates)
        .eq('id', applicationId)
        .eq('user_id', _userId!)
        .eq('status', 'pending')
        .select()
        .single();

    return response;
  }

  // ==================== PROFİL İŞLEMLERİ ====================

  /// Emlakçı profili var mı kontrol et
  Future<bool> isRealtor() async {
    if (_userId == null) return false;

    final response = await _client
        .from('realtors')
        .select('id, status')
        .eq('user_id', _userId!)
        .eq('status', 'approved')
        .maybeSingle();

    return response != null;
  }

  /// Emlakçı profilini getir
  Future<Map<String, dynamic>?> getRealtorProfile() async {
    if (_userId == null) return null;

    final response = await _client
        .from('realtors')
        .select()
        .eq('user_id', _userId!)
        .maybeSingle();

    return response;
  }

  /// Emlakçı profilini ID ile getir (public)
  Future<Map<String, dynamic>?> getRealtorById(String realtorId) async {
    final response = await _client
        .from('realtors')
        .select()
        .eq('id', realtorId)
        .eq('status', 'approved')
        .maybeSingle();

    return response;
  }

  /// Emlakçı profilini güncelle
  Future<Map<String, dynamic>?> updateRealtorProfile(
    Map<String, dynamic> updates,
  ) async {
    if (_userId == null) return null;

    final response = await _client
        .from('realtors')
        .update(updates)
        .eq('user_id', _userId!)
        .select()
        .single();

    return response;
  }

  /// Tüm onaylı emlakçıları listele
  Future<List<Map<String, dynamic>>> getApprovedRealtors({
    String? city,
    String? specialization,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('realtors')
        .select()
        .eq('status', 'approved');

    if (city != null) {
      query = query.eq('city', city);
    }

    final response = await query
        .order('average_rating', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // ==================== RANDEVU İŞLEMLERİ ====================

  /// Emlakçının randevularını getir (appointments tablosundan - SuperCyp'ten gelen randevular)
  Future<List<Map<String, dynamic>>> getAppointments({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
    bool activeOnly = true,
  }) async {
    if (_userId == null) return [];

    // 1. Müşteri randevuları (appointments tablosu)
    var customerQuery = _client
        .from('appointments')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district),
          requester:user_profiles!requester_id (full_name, phone, email, avatar_url)
        ''')
        .eq('owner_id', _userId!);

    if (status != null) {
      customerQuery = customerQuery.eq('status', status);
    } else if (activeOnly) {
      customerQuery = customerQuery.inFilter('status', ['pending', 'confirmed']);
    }

    if (fromDate != null) {
      customerQuery = customerQuery.gte('appointment_date', fromDate.toIso8601String().split('T').first);
    }
    if (toDate != null) {
      customerQuery = customerQuery.lte('appointment_date', toDate.toIso8601String().split('T').first);
    }

    final customerResponse = await customerQuery
        .order('appointment_date', ascending: true)
        .order('appointment_time', ascending: true)
        .limit(limit);

    final customerAppointments = (customerResponse as List)
        .cast<Map<String, dynamic>>()
        .map((a) => {...a, 'source': 'customer'})
        .toList();

    // 2. Kendi randevuları (realtor_appointments tablosu)
    final realtorId = await _getRealtorId();
    List<Map<String, dynamic>> realtorAppointments = [];

    if (realtorId != null) {
      var realtorQuery = _client
          .from('realtor_appointments')
          .select('''
            *,
            properties:property_id (id, title, images, price, city, district),
            client:realtor_clients!client_id (name, phone, email)
          ''')
          .eq('realtor_id', realtorId);

      if (status != null) {
        realtorQuery = realtorQuery.eq('status', status);
      } else if (activeOnly) {
        realtorQuery = realtorQuery.inFilter('status', ['scheduled', 'confirmed']);
      }

      if (fromDate != null) {
        realtorQuery = realtorQuery.gte('scheduled_at', fromDate.toIso8601String());
      }
      if (toDate != null) {
        realtorQuery = realtorQuery.lte('scheduled_at', toDate.toIso8601String());
      }

      final realtorResponse = await realtorQuery
          .order('scheduled_at', ascending: true)
          .limit(limit);

      realtorAppointments = (realtorResponse as List)
          .cast<Map<String, dynamic>>()
          .map((a) {
            // Normalize: scheduled_at → appointment_date/appointment_time
            final scheduledAt = DateTime.tryParse(a['scheduled_at'] ?? '');
            return {
              ...a,
              'source': 'realtor',
              'appointment_date': scheduledAt?.toIso8601String().split('T').first,
              'appointment_time': scheduledAt != null
                  ? '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}'
                  : null,
            };
          })
          .toList();
    }

    // Birleştir ve tarihe göre sırala
    final all = [...customerAppointments, ...realtorAppointments];
    all.sort((a, b) {
      final dateA = a['appointment_date'] as String? ?? '';
      final dateB = b['appointment_date'] as String? ?? '';
      final cmp = dateA.compareTo(dateB);
      if (cmp != 0) return cmp;
      final timeA = a['appointment_time']?.toString() ?? '';
      final timeB = b['appointment_time']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });

    return all.take(limit).toList();
  }

  /// Bugünkü randevuları getir (her iki tablodan)
  Future<List<Map<String, dynamic>>> getTodayAppointments() async {
    if (_userId == null) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayStr = today.toIso8601String().split('T').first;

    // 1. Müşteri randevuları
    final customerResponse = await _client
        .from('appointments')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district),
          requester:user_profiles!requester_id (full_name, phone, email, avatar_url)
        ''')
        .eq('owner_id', _userId!)
        .eq('appointment_date', todayStr)
        .inFilter('status', ['pending', 'confirmed'])
        .order('appointment_time', ascending: true);

    final customerAppointments = (customerResponse as List)
        .cast<Map<String, dynamic>>()
        .map((a) => {...a, 'source': 'customer'})
        .toList();

    // 2. Kendi randevuları
    final realtorId = await _getRealtorId();
    List<Map<String, dynamic>> realtorAppointments = [];

    if (realtorId != null) {
      final realtorResponse = await _client
          .from('realtor_appointments')
          .select('''
            *,
            properties:property_id (id, title, images, price, city, district),
            client:realtor_clients!client_id (name, phone, email)
          ''')
          .eq('realtor_id', realtorId)
          .gte('scheduled_at', today.toIso8601String())
          .lt('scheduled_at', tomorrow.toIso8601String())
          .inFilter('status', ['scheduled', 'confirmed'])
          .order('scheduled_at', ascending: true);

      realtorAppointments = (realtorResponse as List)
          .cast<Map<String, dynamic>>()
          .map((a) {
            final scheduledAt = DateTime.tryParse(a['scheduled_at'] ?? '');
            return {
              ...a,
              'source': 'realtor',
              'appointment_date': todayStr,
              'appointment_time': scheduledAt != null
                  ? '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}'
                  : null,
            };
          })
          .toList();
    }

    final all = [...customerAppointments, ...realtorAppointments];
    all.sort((a, b) {
      final timeA = a['appointment_time']?.toString() ?? '';
      final timeB = b['appointment_time']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });

    return all;
  }

  /// Randevu ekle
  Future<Map<String, dynamic>?> addAppointment({
    required String title,
    required DateTime scheduledAt,
    String? description,
    String? appointmentType,
    int durationMinutes = 60,
    String? clientId,
    String? propertyId,
    String? location,
    String? locationType,
    String? meetingLink,
    String? notes,
  }) async {
    final realtorId = await _getRealtorId();
    if (realtorId == null) {
      throw Exception('Emlakçı profili bulunamadı');
    }

    final response = await _client.from('realtor_appointments').insert({
      'realtor_id': realtorId,
      'title': title,
      'scheduled_at': scheduledAt.toIso8601String(),
      'description': description,
      'appointment_type': appointmentType,
      'duration_minutes': durationMinutes,
      'client_id': clientId,
      'property_id': propertyId,
      'location': location,
      'location_type': locationType,
      'meeting_link': meetingLink,
      'notes': notes,
      'status': 'scheduled',
    }).select().single();

    return response;
  }

  /// Randevu güncelle - source'a göre doğru tabloyu günceller
  Future<Map<String, dynamic>?> updateAppointment(
    String appointmentId,
    Map<String, dynamic> updates, {
    String source = 'customer',
  }) async {
    if (_userId == null) return null;

    updates['updated_at'] = DateTime.now().toIso8601String();

    if (source == 'realtor') {
      // Emlakçının kendi oluşturduğu randevu
      final realtorId = await _getRealtorId();
      if (realtorId == null) return null;
      final response = await _client
          .from('realtor_appointments')
          .update(updates)
          .eq('id', appointmentId)
          .eq('realtor_id', realtorId)
          .select()
          .single();
      return response;
    } else {
      // Müşteriden gelen randevu
      final response = await _client
          .from('appointments')
          .update(updates)
          .eq('id', appointmentId)
          .eq('owner_id', _userId!)
          .select()
          .single();
      return response;
    }
  }

  /// Randevu onayla
  Future<bool> confirmAppointment(String appointmentId, String? responseNote, {String source = 'customer'}) async {
    final result = await updateAppointment(appointmentId, {
      'status': 'confirmed',
      'response_note': responseNote,
    }, source: source);
    return result != null;
  }

  /// Randevu iptal et
  Future<bool> cancelAppointment(String appointmentId, String? reason, {String source = 'customer'}) async {
    final result = await updateAppointment(appointmentId, {
      'status': 'cancelled',
      'response_note': reason,
    }, source: source);
    return result != null;
  }

  /// Randevuyu tamamla
  Future<bool> completeAppointment(String appointmentId, String? outcome, {String source = 'customer'}) async {
    final result = await updateAppointment(appointmentId, {
      'status': 'completed',
      'response_note': outcome,
    }, source: source);
    return result != null;
  }

  // ==================== İSTATİSTİKLER ====================

  /// Dashboard istatistiklerini getir
  Future<Map<String, dynamic>> getDashboardStats() async {
    final realtorId = await _getRealtorId();
    if (realtorId == null) {
      return {
        'active_listings': 0,
        'pending_listings': 0,
        'total_clients': 0,
        'potential_clients': 0,
        'today_appointments': 0,
        'this_week_appointments': 0,
        'total_views': 0,
        'total_messages': 0,
      };
    }

    // İlan sayıları
    final activeListings = await _client
        .from('properties')
        .select('id')
        .eq('user_id', _userId!)
        .eq('status', 'active')
        .count();

    final pendingListings = await _client
        .from('properties')
        .select('id')
        .eq('user_id', _userId!)
        .eq('status', 'pending')
        .count();

    // Müşteri sayıları
    final totalClients = await _client
        .from('realtor_clients')
        .select('id')
        .eq('realtor_id', realtorId)
        .count();

    final potentialClients = await _client
        .from('realtor_clients')
        .select('id')
        .eq('realtor_id', realtorId)
        .eq('status', 'potential')
        .count();

    // Randevu sayıları - hem müşteri (appointments) hem emlakçının kendi (realtor_appointments)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
    final weekEnd = DateTime(now.year, now.month, now.day + 7).toIso8601String().split('T').first;

    // Müşteri randevuları
    final todayCustomerAppts = await _client
        .from('appointments')
        .select('id')
        .eq('owner_id', _userId!)
        .eq('appointment_date', today)
        .count();

    final weekCustomerAppts = await _client
        .from('appointments')
        .select('id')
        .eq('owner_id', _userId!)
        .gte('appointment_date', today)
        .lt('appointment_date', weekEnd)
        .count();

    // Emlakçının kendi randevuları
    final todayRealtorAppts = await _client
        .from('realtor_appointments')
        .select('id')
        .eq('realtor_id', realtorId)
        .gte('scheduled_at', '${today}T00:00:00')
        .lt('scheduled_at', '${today}T23:59:59')
        .count();

    final weekRealtorAppts = await _client
        .from('realtor_appointments')
        .select('id')
        .eq('realtor_id', realtorId)
        .gte('scheduled_at', '${today}T00:00:00')
        .lt('scheduled_at', '${weekEnd}T00:00:00')
        .count();

    return {
      'active_listings': activeListings.count,
      'pending_listings': pendingListings.count,
      'total_clients': totalClients.count,
      'potential_clients': potentialClients.count,
      'today_appointments': todayCustomerAppts.count + todayRealtorAppts.count,
      'this_week_appointments': weekCustomerAppts.count + weekRealtorAppts.count,
      'total_views': 0,
      'total_messages': 0,
    };
  }

  /// İlan bazlı performans istatistiklerini getir
  /// [days] - Kaç günlük veri çekilecek (7, 30, 90)
  Future<Map<String, dynamic>> getPropertyPerformanceStats({int days = 30}) async {
    if (_userId == null) {
      return {'properties': [], 'totals': {}, 'previousTotals': {}};
    }

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final previousStartDate = startDate.subtract(Duration(days: days));

    try {
      // Kullanıcının ilanlarını al
      final propertiesResponse = await _client
          .from('properties')
          .select('id, title, images, city, district, status, view_count, favorite_count, is_featured, is_premium')
          .eq('user_id', _userId!)
          .eq('status', 'active');

      final properties = (propertiesResponse as List).cast<Map<String, dynamic>>();

      if (properties.isEmpty) {
        return {'properties': [], 'totals': {}, 'previousTotals': {}};
      }

      final propertyIds = properties.map((p) => p['id'] as String).toList();

      // Bu dönem görüntülenme sayıları (property_views tablosundan)
      final viewsResponse = await _client
          .from('property_views')
          .select('property_id')
          .inFilter('property_id', propertyIds)
          .gte('viewed_at', startDate.toIso8601String());

      final viewsList = (viewsResponse as List).cast<Map<String, dynamic>>();

      // İlan bazlı görüntülenme sayısı
      final Map<String, int> viewsPerProperty = {};
      for (var view in viewsList) {
        final propId = view['property_id'] as String;
        viewsPerProperty[propId] = (viewsPerProperty[propId] ?? 0) + 1;
      }

      // Önceki dönem görüntülenme sayıları
      final prevViewsResponse = await _client
          .from('property_views')
          .select('property_id')
          .inFilter('property_id', propertyIds)
          .gte('viewed_at', previousStartDate.toIso8601String())
          .lt('viewed_at', startDate.toIso8601String());

      final prevViewsList = (prevViewsResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> prevViewsPerProperty = {};
      for (var view in prevViewsList) {
        final propId = view['property_id'] as String;
        prevViewsPerProperty[propId] = (prevViewsPerProperty[propId] ?? 0) + 1;
      }

      // Bu dönem favori sayıları (property_favorites tablosundan)
      final favoritesResponse = await _client
          .from('property_favorites')
          .select('property_id')
          .inFilter('property_id', propertyIds)
          .gte('created_at', startDate.toIso8601String());

      final favoritesList = (favoritesResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> favoritesPerProperty = {};
      for (var fav in favoritesList) {
        final propId = fav['property_id'] as String;
        favoritesPerProperty[propId] = (favoritesPerProperty[propId] ?? 0) + 1;
      }

      // Önceki dönem favori sayıları
      final prevFavoritesResponse = await _client
          .from('property_favorites')
          .select('property_id')
          .inFilter('property_id', propertyIds)
          .gte('created_at', previousStartDate.toIso8601String())
          .lt('created_at', startDate.toIso8601String());

      final prevFavoritesList = (prevFavoritesResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> prevFavoritesPerProperty = {};
      for (var fav in prevFavoritesList) {
        final propId = fav['property_id'] as String;
        prevFavoritesPerProperty[propId] = (prevFavoritesPerProperty[propId] ?? 0) + 1;
      }

      // Bu dönem randevu sayıları (appointments tablosundan - ilan ziyaret randevuları)
      final appointmentsResponse = await _client
          .from('appointments')
          .select('property_id')
          .inFilter('property_id', propertyIds)
          .gte('created_at', startDate.toIso8601String());

      final appointmentsList = (appointmentsResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> appointmentsPerProperty = {};
      for (var apt in appointmentsList) {
        final propId = apt['property_id'] as String;
        appointmentsPerProperty[propId] = (appointmentsPerProperty[propId] ?? 0) + 1;
      }

      // Önceki dönem randevu sayıları
      final prevAppointmentsResponse = await _client
          .from('appointments')
          .select('property_id')
          .inFilter('property_id', propertyIds)
          .gte('created_at', previousStartDate.toIso8601String())
          .lt('created_at', startDate.toIso8601String());

      final prevAppointmentsList = (prevAppointmentsResponse as List).cast<Map<String, dynamic>>();

      final Map<String, int> prevAppointmentsPerProperty = {};
      for (var apt in prevAppointmentsList) {
        final propId = apt['property_id'] as String;
        prevAppointmentsPerProperty[propId] = (prevAppointmentsPerProperty[propId] ?? 0) + 1;
      }

      // Günlük görüntülenme verileri (grafik için)
      final dailyViewsResponse = await _client
          .from('property_views')
          .select('property_id, viewed_at')
          .inFilter('property_id', propertyIds)
          .gte('viewed_at', now.subtract(const Duration(days: 7)).toIso8601String())
          .order('viewed_at', ascending: true);

      final dailyViewsList = (dailyViewsResponse as List).cast<Map<String, dynamic>>();

      // İlan bazlı günlük görüntülenme
      final Map<String, Map<String, int>> dailyViewsPerProperty = {};
      for (var view in dailyViewsList) {
        final propId = view['property_id'] as String;
        final viewedAt = DateTime.parse(view['viewed_at'] as String);
        final dayKey = '${viewedAt.year}-${viewedAt.month.toString().padLeft(2, '0')}-${viewedAt.day.toString().padLeft(2, '0')}';

        dailyViewsPerProperty[propId] ??= {};
        dailyViewsPerProperty[propId]![dayKey] = (dailyViewsPerProperty[propId]![dayKey] ?? 0) + 1;
      }

      // Tüm verileri birleştir
      final List<Map<String, dynamic>> propertyStats = [];
      int totalViews = 0;
      int totalFavorites = 0;
      int totalAppointments = 0;
      int prevTotalViews = 0;
      int prevTotalFavorites = 0;
      int prevTotalAppointments = 0;

      for (var property in properties) {
        final propId = property['id'] as String;
        final views = viewsPerProperty[propId] ?? 0;
        final prevViews = prevViewsPerProperty[propId] ?? 0;
        final favorites = favoritesPerProperty[propId] ?? 0;
        final prevFavorites = prevFavoritesPerProperty[propId] ?? 0;
        final appointments = appointmentsPerProperty[propId] ?? 0;
        final prevAppointments = prevAppointmentsPerProperty[propId] ?? 0;

        totalViews += views;
        totalFavorites += favorites;
        totalAppointments += appointments;
        prevTotalViews += prevViews;
        prevTotalFavorites += prevFavorites;
        prevTotalAppointments += prevAppointments;

        // Son 7 günlük veriyi diziye çevir
        final List<int> last7DaysViews = [];
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          last7DaysViews.add(dailyViewsPerProperty[propId]?[dayKey] ?? 0);
        }

        propertyStats.add({
          'id': propId,
          'title': property['title'],
          'images': property['images'] ?? [],
          'city': property['city'] ?? '',
          'district': property['district'] ?? '',
          'views': views,
          'previousViews': prevViews,
          'favorites': favorites,
          'previousFavorites': prevFavorites,
          'appointments': appointments,
          'previousAppointments': prevAppointments,
          'dailyViews': last7DaysViews,
          'is_featured': property['is_featured'] as bool? ?? false,
          'is_premium': property['is_premium'] as bool? ?? false,
        });
      }

      // Görüntülenmeye göre sırala
      propertyStats.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));

      return {
        'properties': propertyStats,
        'totals': {
          'views': totalViews,
          'favorites': totalFavorites,
          'appointments': totalAppointments,
        },
        'previousTotals': {
          'views': prevTotalViews,
          'favorites': prevTotalFavorites,
          'appointments': prevTotalAppointments,
        },
      };
    } catch (e) {
      debugPrint('Performans istatistikleri alınamadı: $e');
      return {'properties': [], 'totals': {}, 'previousTotals': {}};
    }
  }

  // ==================== AKTİVİTE LOGLARI ====================

  /// Son aktiviteleri getir
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 20}) async {
    final realtorId = await _getRealtorId();
    if (realtorId == null) return [];

    final response = await _client
        .from('realtor_activity_logs')
        .select()
        .eq('realtor_id', realtorId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Aktivite kaydet
  Future<void> logActivity({
    required String activityType,
    required String title,
    String? description,
    String? entityType,
    String? entityId,
  }) async {
    final realtorId = await _getRealtorId();
    if (realtorId == null) return;

    try {
      await _client.from('realtor_activity_logs').insert({
        'realtor_id': realtorId,
        'activity_type': activityType,
        'title': title,
        'description': description,
        'entity_type': entityType,
        'entity_id': entityId,
      });
    } catch (e) {
      // Log hatası önemsiz
    }
  }

  // ==================== YARDIMCI METODLAR ====================

  /// Kullanıcının emlakçı ID'sini getir
  Future<String?> _getRealtorId() async {
    if (_userId == null) return null;

    final response = await _client
        .from('realtors')
        .select('id')
        .eq('user_id', _userId!)
        .maybeSingle();

    return response?['id'] as String?;
  }

  /// Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ==================== PROMOSYON/ÖNE ÇIKARMA ====================

  /// Promosyon fiyatlarını getir
  Future<List<Map<String, dynamic>>> getPromotionPrices() async {
    try {
      final response = await _client
          .from('promotion_prices')
          .select()
          .eq('is_active', true)
          .order('promotion_type')
          .order('duration_days');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Promosyon fiyatları alınamadı: $e');
      return [];
    }
  }

  /// İlanın aktif promosyonlarını getir
  Future<List<Map<String, dynamic>>> getPropertyPromotions(String propertyId) async {
    try {
      final response = await _client
          .from('property_promotions')
          .select()
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Promosyonlar alınamadı: $e');
      return [];
    }
  }

  /// Kullanıcının tüm aktif promosyonlarını getir
  Future<List<Map<String, dynamic>>> getActivePromotions() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('property_promotions')
          .select('''
            *,
            properties:property_id (
              id, title, images, city, district
            )
          ''')
          .eq('user_id', _userId!)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('expires_at', ascending: true);

      final promotions = (response as List).cast<Map<String, dynamic>>();

      // Her promosyon için görüntülenme istatistiklerini hesapla
      final enrichedPromotions = <Map<String, dynamic>>[];
      for (final promo in promotions) {
        final propertyData = promo['properties'] as Map<String, dynamic>?;
        final propertyId = promo['property_id'] as String?;
        final startDate = promo['started_at'] != null
            ? DateTime.parse(promo['started_at'])
            : DateTime.now();

        int viewsBefore = 0;
        int viewsDuring = 0;

        if (propertyId != null) {
          // Promosyon öncesi 7 günlük görüntülenme
          final beforeStart = startDate.subtract(const Duration(days: 7));
          try {
            final beforeViews = await _client
                .from('property_views')
                .select('id')
                .eq('property_id', propertyId)
                .gte('viewed_at', beforeStart.toIso8601String())
                .lt('viewed_at', startDate.toIso8601String());
            viewsBefore = (beforeViews as List).length;
          } catch (_) {}

          // Promosyon süresince görüntülenme
          try {
            final duringViews = await _client
                .from('property_views')
                .select('id')
                .eq('property_id', propertyId)
                .gte('viewed_at', startDate.toIso8601String());
            viewsDuring = (duringViews as List).length;
          } catch (_) {}
        }

        enrichedPromotions.add({
          ...promo,
          'property_title': propertyData?['title'] ?? 'İlan',
          'property_images': propertyData?['images'] ?? [],
          'start_date': promo['started_at'],
          'end_date': promo['expires_at'],
          'views_before': viewsBefore,
          'views_during': viewsDuring,
        });
      }

      return enrichedPromotions;
    } catch (e) {
      debugPrint('Aktif promosyonlar alınamadı: $e');
      return [];
    }
  }

  /// Kullanıcının tüm promosyon geçmişini getir
  Future<List<Map<String, dynamic>>> getPromotionHistory() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('property_promotions')
          .select('''
            *,
            properties:property_id (
              id, title, images, city, district
            )
          ''')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Promosyon geçmişi alınamadı: $e');
      return [];
    }
  }

  /// İlan için aktif promosyon var mı kontrol et
  Future<Map<String, dynamic>?> getActivePromotion(String propertyId) async {
    try {
      final response = await _client
          .from('property_promotions')
          .select()
          .eq('property_id', propertyId)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('expires_at', ascending: false)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Aktif promosyon kontrolü başarısız: $e');
      return null;
    }
  }

  /// Promosyon oluştur (ödeme sonrası aktif edilecek)
  Future<Map<String, dynamic>?> createPromotion({
    required String propertyId,
    required String promotionType, // 'featured' veya 'premium'
    required int durationDays,
    required double amountPaid,
    String? paymentMethod,
    String? paymentReference,
  }) async {
    if (_userId == null) return null;

    try {
      // Önce mevcut görüntülenme ve randevu sayısını al
      final property = await _client
          .from('properties')
          .select('view_count')
          .eq('id', propertyId)
          .single();

      final viewsBefore = property['view_count'] as int? ?? 0;

      // Randevu sayısını al
      final appointmentsResponse = await _client
          .from('appointments')
          .select('id')
          .eq('property_id', propertyId)
          .count();

      final appointmentsBefore = appointmentsResponse.count;

      // Promosyon oluştur
      final expiresAt = DateTime.now().add(Duration(days: durationDays));

      final response = await _client
          .from('property_promotions')
          .insert({
            'property_id': propertyId,
            'user_id': _userId,
            'promotion_type': promotionType,
            'duration_days': durationDays,
            'started_at': DateTime.now().toIso8601String(),
            'expires_at': expiresAt.toIso8601String(),
            'amount_paid': amountPaid,
            'payment_method': paymentMethod,
            'payment_reference': paymentReference,
            'status': 'active',
            'views_before': viewsBefore,
            'appointments_before': appointmentsBefore,
          })
          .select()
          .single();

      // Property'yi güncelle
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (promotionType == 'featured') {
        updateData['is_featured'] = true;
      } else if (promotionType == 'premium') {
        updateData['is_featured'] = true;
        updateData['is_premium'] = true;
      }

      await _client
          .from('properties')
          .update(updateData)
          .eq('id', propertyId);

      // Aktivite logla
      await logActivity(
        activityType: 'promotion_created',
        title: promotionType == 'premium' ? 'Premium Promosyon Başlatıldı' : 'Öne Çıkarma Başlatıldı',
        description: '$durationDays günlük promosyon aktif edildi',
        entityType: 'property',
        entityId: propertyId,
      );

      return response;
    } catch (e) {
      debugPrint('Promosyon oluşturulamadı: $e');
      return null;
    }
  }

  /// Promosyonu iptal et
  Future<bool> cancelPromotion(String promotionId, {String? reason}) async {
    try {
      final promotion = await _client
          .from('property_promotions')
          .select('property_id, promotion_type')
          .eq('id', promotionId)
          .single();

      await _client
          .from('property_promotions')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancellation_reason': reason,
          })
          .eq('id', promotionId);

      // Property'nin promosyon durumunu kontrol et ve güncelle
      final propertyId = promotion['property_id'] as String;
      await _updatePropertyPromotionStatus(propertyId);

      return true;
    } catch (e) {
      debugPrint('Promosyon iptal edilemedi: $e');
      return false;
    }
  }

  /// Property'nin promosyon durumunu güncelle
  Future<void> _updatePropertyPromotionStatus(String propertyId) async {
    try {
      // Aktif featured promosyon var mı?
      final featuredPromo = await _client
          .from('property_promotions')
          .select('id')
          .eq('property_id', propertyId)
          .inFilter('promotion_type', ['featured', 'premium'])
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      // Aktif premium promosyon var mı?
      final premiumPromo = await _client
          .from('property_promotions')
          .select('id')
          .eq('property_id', propertyId)
          .eq('promotion_type', 'premium')
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      await _client
          .from('properties')
          .update({
            'is_featured': featuredPromo != null,
            'is_premium': premiumPromo != null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', propertyId);
    } catch (e) {
      debugPrint('Property promosyon durumu güncellenemedi: $e');
    }
  }

  /// Promosyon istatistiklerini güncelle (görüntülenme artınca çağrılır)
  Future<void> incrementPromotionViews(String propertyId) async {
    try {
      await _client.rpc('increment_promotion_views', params: {
        'p_property_id': propertyId,
      });
    } catch (e) {
      // Sessizce devam et
    }
  }
}
