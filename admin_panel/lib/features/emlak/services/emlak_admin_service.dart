import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==================== MODELS ====================

class EmlakCity {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  EmlakCity({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });

  factory EmlakCity.fromJson(Map<String, dynamic> json) {
    return EmlakCity(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class EmlakDistrict {
  final String id;
  final String cityId;
  final String name;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final String? cityName;

  EmlakDistrict({
    required this.id,
    required this.cityId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    this.cityName,
  });

  factory EmlakDistrict.fromJson(Map<String, dynamic> json) {
    return EmlakDistrict(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      cityName: json['emlak_cities'] != null ? json['emlak_cities']['name'] as String? : null,
    );
  }
}

class EmlakPropertyType {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  EmlakPropertyType({
    required this.id,
    required this.name,
    this.icon,
    required this.sortOrder,
    required this.isActive,
  });

  factory EmlakPropertyType.fromJson(Map<String, dynamic> json) {
    return EmlakPropertyType(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class EmlakListing {
  final String id;
  final String title;
  final String? description;
  final String propertyType;
  final String listingType;
  final double price;
  final String? city;
  final String? district;
  final String status;
  final String userId;
  final String? userEmail;
  final String? userPhone;
  final DateTime createdAt;
  final List<String> images;

  EmlakListing({
    required this.id,
    required this.title,
    this.description,
    required this.propertyType,
    required this.listingType,
    required this.price,
    this.city,
    this.district,
    required this.status,
    required this.userId,
    this.userEmail,
    this.userPhone,
    required this.createdAt,
    required this.images,
  });

  factory EmlakListing.fromJson(Map<String, dynamic> json) {
    List<String> imagesList = [];
    if (json['images'] != null) {
      imagesList = (json['images'] as List).cast<String>();
    }

    return EmlakListing(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      propertyType: json['property_type'] as String? ?? '',
      listingType: json['listing_type'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      city: json['city'] as String?,
      district: json['district'] as String?,
      status: json['status'] as String? ?? 'pending',
      userId: json['user_id'] as String? ?? '',
      userEmail: json['user_email'] as String?,
      userPhone: json['user_phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      images: imagesList,
    );
  }
}

class EmlakStats {
  final int totalListings;
  final int pendingListings;
  final int activeListings;
  final int totalCities;
  final int totalDistricts;

  EmlakStats({
    required this.totalListings,
    required this.pendingListings,
    required this.activeListings,
    required this.totalCities,
    required this.totalDistricts,
  });

  factory EmlakStats.empty() => EmlakStats(
        totalListings: 0,
        pendingListings: 0,
        activeListings: 0,
        totalCities: 0,
        totalDistricts: 0,
      );
}

class EmlakAmenity {
  final String id;
  final String name;
  final String? icon;
  final String? category;
  final int sortOrder;
  final bool isActive;

  EmlakAmenity({
    required this.id,
    required this.name,
    this.icon,
    this.category,
    required this.sortOrder,
    required this.isActive,
  });

  factory EmlakAmenity.fromJson(Map<String, dynamic> json) {
    return EmlakAmenity(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class EmlakSetting {
  final String id;
  final String key;
  final dynamic value;
  final String? description;

  EmlakSetting({
    required this.id,
    required this.key,
    required this.value,
    this.description,
  });

  factory EmlakSetting.fromJson(Map<String, dynamic> json) {
    return EmlakSetting(
      id: json['id'] as String,
      key: json['key'] as String,
      value: json['value'],
      description: json['description'] as String?,
    );
  }
}

class PromotionPrice {
  final String id;
  final String promotionType; // 'featured' veya 'premium'
  final int durationDays;
  final double price;
  final double? discountedPrice;
  final bool isActive;
  final DateTime createdAt;

  PromotionPrice({
    required this.id,
    required this.promotionType,
    required this.durationDays,
    required this.price,
    this.discountedPrice,
    required this.isActive,
    required this.createdAt,
  });

  factory PromotionPrice.fromJson(Map<String, dynamic> json) {
    return PromotionPrice(
      id: json['id'] as String,
      promotionType: json['promotion_type'] as String,
      durationDays: json['duration_days'] as int,
      price: (json['price'] as num).toDouble(),
      discountedPrice: json['discounted_price'] != null
          ? (json['discounted_price'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get displayName {
    final typeName = promotionType == 'premium' ? 'Premium' : 'Öne Çıkan';
    return '$typeName - $durationDays Gün';
  }
}

// ==================== SERVICE ====================

class EmlakAdminService {
  final SupabaseClient _client = Supabase.instance.client;

  // Stats
  Future<EmlakStats> getStats() async {
    final totalListings = await _client.from('properties').select('id').count();
    final pendingListings = await _client.from('properties').select('id').eq('status', 'pending').count();
    final activeListings = await _client.from('properties').select('id').eq('status', 'active').count();
    final totalCities = await _client.from('emlak_cities').select('id').count();
    final totalDistricts = await _client.from('emlak_districts').select('id').count();

    return EmlakStats(
      totalListings: totalListings.count,
      pendingListings: pendingListings.count,
      activeListings: activeListings.count,
      totalCities: totalCities.count,
      totalDistricts: totalDistricts.count,
    );
  }

  // Cities
  Future<List<EmlakCity>> getCities() async {
    final response = await _client
        .from('emlak_cities')
        .select()
        .order('sort_order', ascending: true);

    return (response as List).map((json) => EmlakCity.fromJson(json)).toList();
  }

  Future<void> addCity(String name, int sortOrder) async {
    await _client.from('emlak_cities').insert({
      'name': name,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updateCity(String id, {String? name, int? sortOrder, bool? isActive}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (isActive != null) updates['is_active'] = isActive;

    await _client.from('emlak_cities').update(updates).eq('id', id);
  }

  Future<void> deleteCity(String id) async {
    await _client.from('emlak_cities').delete().eq('id', id);
  }

  // Districts
  Future<List<EmlakDistrict>> getDistricts({String? cityId}) async {
    var query = _client.from('emlak_districts').select('*, emlak_cities(name)');

    if (cityId != null) {
      query = query.eq('city_id', cityId);
    }

    final response = await query.order('sort_order', ascending: true);
    return (response as List).map((json) => EmlakDistrict.fromJson(json)).toList();
  }

  Future<void> addDistrict(String cityId, String name, int sortOrder) async {
    await _client.from('emlak_districts').insert({
      'city_id': cityId,
      'name': name,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updateDistrict(String id, {String? name, int? sortOrder, bool? isActive}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (isActive != null) updates['is_active'] = isActive;

    await _client.from('emlak_districts').update(updates).eq('id', id);
  }

  Future<void> deleteDistrict(String id) async {
    await _client.from('emlak_districts').delete().eq('id', id);
  }

  // Property Types
  Future<List<EmlakPropertyType>> getPropertyTypes() async {
    final response = await _client
        .from('emlak_property_types')
        .select()
        .order('sort_order', ascending: true);

    return (response as List).map((json) => EmlakPropertyType.fromJson(json)).toList();
  }

  Future<void> addPropertyType(String name, String? icon, int sortOrder) async {
    await _client.from('emlak_property_types').insert({
      'name': name,
      'label': name, // label = name (Türkçe gösterim)
      'icon': icon,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updatePropertyType(String id, {String? name, String? icon, int? sortOrder, bool? isActive}) async {
    final updates = <String, dynamic>{};
    if (name != null) {
      updates['name'] = name;
      updates['label'] = name; // label = name
    }
    if (icon != null) updates['icon'] = icon;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (isActive != null) updates['is_active'] = isActive;

    await _client.from('emlak_property_types').update(updates).eq('id', id);
  }

  Future<void> deletePropertyType(String id) async {
    await _client.from('emlak_property_types').delete().eq('id', id);
  }

  // Listings
  Future<List<EmlakListing>> getListings({String? status, int limit = 50}) async {
    var query = _client.from('properties').select('*');

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    return (response as List).map((json) => EmlakListing.fromJson(json)).toList();
  }

  Future<void> updateListingStatus(String id, String status) async {
    await _client.from('properties').update({'status': status}).eq('id', id);
  }

  Future<void> deleteListing(String id) async {
    await _client.from('properties').delete().eq('id', id);
  }

  // Amenities
  Future<List<EmlakAmenity>> getAmenities() async {
    final response = await _client
        .from('emlak_amenities')
        .select()
        .order('sort_order', ascending: true);

    return (response as List).map((json) => EmlakAmenity.fromJson(json)).toList();
  }

  Future<void> addAmenity(String name, String? icon, String? category, int sortOrder) async {
    await _client.from('emlak_amenities').insert({
      'name': name,
      'label': name, // label = name
      'icon': icon,
      'category': category,
      'sort_order': sortOrder,
      'is_active': true,
    });
  }

  Future<void> updateAmenity(String id, {String? name, String? icon, String? category, int? sortOrder, bool? isActive}) async {
    final updates = <String, dynamic>{};
    if (name != null) {
      updates['name'] = name;
      updates['label'] = name; // label = name
    }
    if (icon != null) updates['icon'] = icon;
    if (category != null) updates['category'] = category;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (isActive != null) updates['is_active'] = isActive;

    await _client.from('emlak_amenities').update(updates).eq('id', id);
  }

  Future<void> deleteAmenity(String id) async {
    await _client.from('emlak_amenities').delete().eq('id', id);
  }

  // Settings
  Future<List<EmlakSetting>> getSettings() async {
    final response = await _client
        .from('emlak_settings')
        .select()
        .order('key', ascending: true);

    return (response as List).map((json) => EmlakSetting.fromJson(json)).toList();
  }

  Future<void> updateSetting(String id, dynamic value) async {
    await _client.from('emlak_settings').update({'value': value}).eq('id', id);
  }

  Future<void> addSetting(String key, dynamic value, String? description) async {
    await _client.from('emlak_settings').insert({
      'key': key,
      'value': value,
      'description': description,
    });
  }

  Future<void> deleteSetting(String id) async {
    await _client.from('emlak_settings').delete().eq('id', id);
  }

  // Premium listing operations
  Future<void> setListingPremium(String id, bool isPremium) async {
    await _client.from('properties').update({'is_premium': isPremium}).eq('id', id);
  }

  Future<void> setListingFeatured(String id, bool isFeatured) async {
    await _client.from('properties').update({'is_featured': isFeatured}).eq('id', id);
  }

  // Promotion Prices
  Future<List<PromotionPrice>> getPromotionPrices() async {
    final response = await _client
        .from('promotion_prices')
        .select()
        .order('promotion_type', ascending: true)
        .order('duration_days', ascending: true);

    return (response as List).map((json) => PromotionPrice.fromJson(json)).toList();
  }

  Future<void> addPromotionPrice({
    required String promotionType,
    required int durationDays,
    required double price,
    double? discountedPrice,
  }) async {
    await _client.from('promotion_prices').insert({
      'promotion_type': promotionType,
      'duration_days': durationDays,
      'price': price,
      'discounted_price': discountedPrice,
      'is_active': true,
    });
  }

  Future<void> updatePromotionPrice(
    String id, {
    double? price,
    double? discountedPrice,
    bool clearDiscount = false,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (price != null) updates['price'] = price;
    if (discountedPrice != null) {
      updates['discounted_price'] = discountedPrice;
    } else if (clearDiscount) {
      updates['discounted_price'] = null;
    }
    if (isActive != null) updates['is_active'] = isActive;

    await _client.from('promotion_prices').update(updates).eq('id', id);
  }

  Future<void> deletePromotionPrice(String id) async {
    await _client.from('promotion_prices').delete().eq('id', id);
  }

  // Promotion Stats
  Future<Map<String, dynamic>> getPromotionStats() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Aktif promosyonlar
    final activePromotions = await _client
        .from('property_promotions')
        .select('id')
        .eq('status', 'active')
        .gt('expires_at', now.toIso8601String())
        .count();

    // Son 30 günde oluşturulan promosyonlar
    final recentPromotions = await _client
        .from('property_promotions')
        .select('id')
        .gte('created_at', thirtyDaysAgo.toIso8601String())
        .count();

    // Toplam gelir (son 30 gün)
    final revenueData = await _client
        .from('property_promotions')
        .select('amount_paid')
        .gte('created_at', thirtyDaysAgo.toIso8601String())
        .eq('status', 'active');

    double totalRevenue = 0;
    for (final item in revenueData as List) {
      totalRevenue += (item['amount_paid'] as num?)?.toDouble() ?? 0;
    }

    return {
      'active_promotions': activePromotions.count,
      'recent_promotions': recentPromotions.count,
      'total_revenue_30d': totalRevenue,
    };
  }
}

// ==================== PROVIDERS ====================

final emlakAdminServiceProvider = Provider<EmlakAdminService>((ref) {
  return EmlakAdminService();
});

final emlakStatsProvider = FutureProvider<EmlakStats>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getStats();
});

final emlakCitiesProvider = FutureProvider<List<EmlakCity>>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getCities();
});

final emlakDistrictsProvider = FutureProvider.family<List<EmlakDistrict>, String?>((ref, cityId) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getDistricts(cityId: cityId);
});

final emlakPropertyTypesProvider = FutureProvider<List<EmlakPropertyType>>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getPropertyTypes();
});

final emlakListingsProvider = FutureProvider.family<List<EmlakListing>, String?>((ref, status) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getListings(status: status);
});

final pendingListingsProvider = FutureProvider<List<EmlakListing>>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getListings(status: 'pending');
});

final emlakAmenitiesProvider = FutureProvider<List<EmlakAmenity>>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getAmenities();
});

final emlakSettingsProvider = FutureProvider<List<EmlakSetting>>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getSettings();
});

final promotionPricesProvider = FutureProvider<List<PromotionPrice>>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getPromotionPrices();
});

final promotionStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(emlakAdminServiceProvider);
  return service.getPromotionStats();
});
