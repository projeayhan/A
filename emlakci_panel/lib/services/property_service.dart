import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/emlak_models.dart';

/// Emlak ilanları için Supabase servis sınıfı
class PropertyService {
  static final PropertyService _instance = PropertyService._internal();
  factory PropertyService() => _instance;
  PropertyService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== İLAN SORGULAMA ====================

  /// Tüm aktif ilanları getir
  Future<List<Property>> getProperties({
    PropertyFilter? filter,
    SortOption sortOption = SortOption.newest,
    int limit = 50,
    int offset = 0,
  }) async {
    // Sıralama alanı ve yönü
    String orderColumn;
    bool ascending;

    switch (sortOption) {
      case SortOption.newest:
        orderColumn = 'created_at';
        ascending = false;
        break;
      case SortOption.oldest:
        orderColumn = 'created_at';
        ascending = true;
        break;
      case SortOption.priceLowToHigh:
        orderColumn = 'price';
        ascending = true;
        break;
      case SortOption.priceHighToLow:
        orderColumn = 'price';
        ascending = false;
        break;
      case SortOption.areaLargest:
        orderColumn = 'square_meters';
        ascending = false;
        break;
      case SortOption.areaSmallest:
        orderColumn = 'square_meters';
        ascending = true;
        break;
      case SortOption.roomsMore:
        orderColumn = 'rooms';
        ascending = false;
        break;
      case SortOption.roomsLess:
        orderColumn = 'rooms';
        ascending = true;
        break;
    }

    // Temel filtreler
    var query = _client.from('properties').select().eq('status', 'active');

    // Ek filtreleri uygula
    if (filter != null) {
      if (filter.type != null) {
        query = query.eq('property_type', filter.type!.name);
      }
      if (filter.listingType != null) {
        query = query.eq('listing_type', filter.listingType!.name);
      }
      if (filter.city != null) {
        query = query.eq('city', filter.city!);
      }
      if (filter.district != null) {
        query = query.eq('district', filter.district!);
      }
      if (filter.minPrice != null) {
        query = query.gte('price', filter.minPrice!);
      }
      if (filter.maxPrice != null) {
        query = query.lte('price', filter.maxPrice!);
      }
      if (filter.minRooms != null) {
        query = query.gte('rooms', filter.minRooms!);
      }
      if (filter.maxRooms != null) {
        query = query.lte('rooms', filter.maxRooms!);
      }
      if (filter.minSquareMeters != null) {
        query = query.gte('square_meters', filter.minSquareMeters!);
      }
      if (filter.maxSquareMeters != null) {
        query = query.lte('square_meters', filter.maxSquareMeters!);
      }
      if (filter.hasParking == true) {
        query = query.eq('has_parking', true);
      }
      if (filter.hasPool == true) {
        query = query.eq('has_pool', true);
      }
      if (filter.hasFurniture == true) {
        query = query.eq('has_furniture', true);
      }
    }

    final response = await query
        .order(orderColumn, ascending: ascending)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => Property.fromJson(json)).toList();
  }

  /// Öne çıkan ilanları getir
  Future<List<Property>> getFeaturedProperties({int limit = 10}) async {
    final response = await _client
        .from('properties')
        .select()
        .eq('status', 'active')
        .eq('is_featured', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Property.fromJson(json)).toList();
  }

  /// Premium ilanları getir
  Future<List<Property>> getPremiumProperties({int limit = 10}) async {
    final response = await _client
        .from('properties')
        .select()
        .eq('status', 'active')
        .eq('is_premium', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Property.fromJson(json)).toList();
  }

  /// İlan detayını getir
  Future<Property?> getPropertyById(String propertyId) async {
    final response = await _client
        .from('properties')
        .select()
        .eq('id', propertyId)
        .maybeSingle();

    if (response == null) return null;
    return Property.fromJson(response);
  }

  /// Arama yap
  Future<List<Property>> searchProperties({
    required String searchQuery,
    PropertyFilter? filter,
    SortOption sortOption = SortOption.newest,
    int limit = 50,
  }) async {
    // Sıralama alanı ve yönü
    String orderColumn;
    bool ascending;

    switch (sortOption) {
      case SortOption.newest:
        orderColumn = 'created_at';
        ascending = false;
        break;
      case SortOption.priceLowToHigh:
        orderColumn = 'price';
        ascending = true;
        break;
      case SortOption.priceHighToLow:
        orderColumn = 'price';
        ascending = false;
        break;
      default:
        orderColumn = 'created_at';
        ascending = false;
    }

    var query = _client
        .from('properties')
        .select()
        .eq('status', 'active')
        .or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%,city.ilike.%$searchQuery%,district.ilike.%$searchQuery%,neighborhood.ilike.%$searchQuery%');

    // Ek filtreleri uygula
    if (filter != null) {
      if (filter.listingType != null) {
        query = query.eq('listing_type', filter.listingType!.name);
      }
      if (filter.type != null) {
        query = query.eq('property_type', filter.type!.name);
      }
      if (filter.minPrice != null) {
        query = query.gte('price', filter.minPrice!);
      }
      if (filter.maxPrice != null) {
        query = query.lte('price', filter.maxPrice!);
      }
    }

    final response = await query
        .order(orderColumn, ascending: ascending)
        .limit(limit);

    return (response as List).map((json) => Property.fromJson(json)).toList();
  }

  // ==================== KULLANICI İLANLARI ====================

  /// Kullanıcının ilanlarını getir
  Future<List<Property>> getUserProperties({
    PropertyStatus? status,
    int limit = 50,
  }) async {
    if (_userId == null) return [];

    var query = _client
        .from('properties')
        .select()
        .eq('user_id', _userId!);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    return (response as List).map((json) => Property.fromJson(json)).toList();
  }

  /// Kullanıcının aktif ilan sayısını getir
  Future<int> getUserActiveListingsCount() async {
    if (_userId == null) return 0;

    final response = await _client
        .from('properties')
        .select('id')
        .eq('user_id', _userId!)
        .eq('status', 'active');

    return (response as List).length;
  }

  // ==================== İLAN İŞLEMLERİ ====================

  /// Yeni ilan oluştur
  Future<Property?> createProperty(Property property) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final data = property.toJson();
    data['user_id'] = _userId;
    data['status'] = 'pending'; // Yeni ilanlar onay bekler

    final response = await _client
        .from('properties')
        .insert(data)
        .select()
        .single();

    return Property.fromJson(response);
  }

  /// İlanı güncelle
  Future<Property?> updateProperty(String propertyId, Map<String, dynamic> updates) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final response = await _client
        .from('properties')
        .update(updates)
        .eq('id', propertyId)
        .eq('user_id', _userId!)
        .select()
        .single();

    return Property.fromJson(response);
  }

  /// İlan durumunu güncelle
  Future<bool> updatePropertyStatus(String propertyId, PropertyStatus status) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('properties')
          .update({'status': status.name})
          .eq('id', propertyId)
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// İlanı sil
  Future<bool> deleteProperty(String propertyId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('properties')
          .delete()
          .eq('id', propertyId)
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== GÖRÜNTÜLEME ====================

  /// İlan görüntüleme kaydet
  Future<void> trackPropertyView(String propertyId) async {
    try {
      await _client.from('property_views').insert({
        'property_id': propertyId,
        'user_id': _userId,
        'device_info': 'mobile',
      });
    } catch (e) {
      // Görüntüleme hatası önemsiz, sessizce geç
    }
  }

  /// İlan görüntüleme istatistiklerini getir
  Future<Map<String, dynamic>> getPropertyViewStats(String propertyId) async {
    if (_userId == null) return {};

    final response = await _client
        .from('property_views')
        .select('viewed_at')
        .eq('property_id', propertyId);

    final views = response as List;

    // Son 7 gün
    final now = DateTime.now();
    final last7Days = views.where((v) {
      final viewDate = DateTime.parse(v['viewed_at']);
      return now.difference(viewDate).inDays <= 7;
    }).length;

    // Son 30 gün
    final last30Days = views.where((v) {
      final viewDate = DateTime.parse(v['viewed_at']);
      return now.difference(viewDate).inDays <= 30;
    }).length;

    return {
      'total': views.length,
      'last_7_days': last7Days,
      'last_30_days': last30Days,
    };
  }

  // ==================== ŞEHİR VE İLÇE ====================

  /// Aktif şehirleri DB'den getir
  Future<List<String>> getCities() async {
    final response = await _client
        .from('emlak_cities')
        .select('name')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List).map((row) => row['name'] as String).toList();
  }

  /// Şehre göre ilçeleri DB'den getir
  Future<List<String>> getDistrictsByCity(String city) async {
    // Önce şehir ID'sini bul
    final cityResponse = await _client
        .from('emlak_cities')
        .select('id')
        .eq('name', city)
        .eq('is_active', true)
        .maybeSingle();

    if (cityResponse == null) return [];

    final cityId = cityResponse['id'] as String;

    // İlçeleri getir
    final response = await _client
        .from('emlak_districts')
        .select('name')
        .eq('city_id', cityId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List).map((row) => row['name'] as String).toList();
  }

  /// Emlak türlerini DB'den getir
  Future<List<Map<String, dynamic>>> getPropertyTypes() async {
    final response = await _client
        .from('emlak_property_types')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// İlan türlerini DB'den getir
  Future<List<Map<String, dynamic>>> getListingTypes() async {
    final response = await _client
        .from('emlak_listing_types')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Özellikleri DB'den getir
  Future<List<Map<String, dynamic>>> getAmenities({String? category}) async {
    var query = _client
        .from('emlak_amenities')
        .select()
        .eq('is_active', true);

    if (category != null) {
      query = query.eq('category', category);
    }

    final response = await query.order('sort_order', ascending: true);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Emlak ayarlarını getir
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client
        .from('emlak_settings')
        .select('key, value');

    final settings = <String, dynamic>{};
    for (final row in response as List) {
      settings[row['key'] as String] = row['value'];
    }
    return settings;
  }

  /// Belirli bir ayarı getir
  Future<dynamic> getSetting(String key) async {
    final response = await _client
        .from('emlak_settings')
        .select('value')
        .eq('key', key)
        .maybeSingle();

    return response?['value'];
  }

  // ==================== BENZER İLANLAR ====================

  /// Benzer ilanları getir
  Future<List<Property>> getSimilarProperties(Property property, {int limit = 4}) async {
    final response = await _client
        .from('properties')
        .select()
        .eq('status', 'active')
        .eq('property_type', property.type.name)
        .eq('listing_type', property.listingType.name)
        .neq('id', property.id)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Property.fromJson(json)).toList();
  }

  // ==================== REALTIME ====================

  /// İlan değişikliklerini dinle
  Stream<List<Property>> streamProperties({PropertyFilter? filter}) {
    return _client
        .from('properties')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => Property.fromJson(json)).toList());
  }

  /// Kullanıcının ilanlarını dinle
  Stream<List<Property>> streamUserProperties() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _client
        .from('properties')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .map((list) => list.map((json) => Property.fromJson(json)).toList());
  }
}
