import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ==================== MODELLer ====================

class CarSalesStats {
  final int totalListings;
  final int pendingListings;
  final int activeListings;
  final int soldListings;
  final int totalDealers;
  final int pendingApplications;
  final int totalBrands;

  CarSalesStats({
    required this.totalListings,
    required this.pendingListings,
    required this.activeListings,
    required this.soldListings,
    required this.totalDealers,
    required this.pendingApplications,
    required this.totalBrands,
  });

  factory CarSalesStats.empty() => CarSalesStats(
    totalListings: 0,
    pendingListings: 0,
    activeListings: 0,
    soldListings: 0,
    totalDealers: 0,
    pendingApplications: 0,
    totalBrands: 0,
  );
}

class CarListing {
  final String id;
  final String title;
  final String brandName;
  final String modelName;
  final int year;
  final double price;
  final String status;
  final List<String> images;
  final String? city;
  final String? district;
  final int mileage;
  final String fuelType;
  final String transmission;
  final DateTime createdAt;

  CarListing({
    required this.id,
    required this.title,
    required this.brandName,
    required this.modelName,
    required this.year,
    required this.price,
    required this.status,
    required this.images,
    this.city,
    this.district,
    required this.mileage,
    required this.fuelType,
    required this.transmission,
    required this.createdAt,
  });

  factory CarListing.fromJson(Map<String, dynamic> json) {
    return CarListing(
      id: json['id'] as String,
      title: json['title'] as String,
      brandName: json['brand_name'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      images: (json['images'] as List?)?.cast<String>() ?? [],
      city: json['city'] as String?,
      district: json['district'] as String?,
      mileage: json['mileage'] as int? ?? 0,
      fuelType: json['fuel_type'] as String? ?? '',
      transmission: json['transmission'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CarBrand {
  final String id;
  final String name;
  final String? logoUrl;
  final String? country;
  final bool isPremium;
  final bool isPopular;
  final int sortOrder;
  final bool isActive;

  CarBrand({
    required this.id,
    required this.name,
    this.logoUrl,
    this.country,
    this.isPremium = false,
    this.isPopular = false,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarBrand.fromJson(Map<String, dynamic> json) {
    return CarBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      country: json['country'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CarFeature {
  final String id;
  final String name;
  final String category;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  CarFeature({
    required this.id,
    required this.name,
    required this.category,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarFeature.fromJson(Map<String, dynamic> json) {
    return CarFeature(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CarDealer {
  final String id;
  final String userId;
  final String dealerType;
  final String? businessName;
  final String ownerName;
  final String phone;
  final String? email;
  final String city;
  final String? district;
  final String status;
  final bool isVerified;
  final int totalListings;
  final int activeListings;
  final DateTime createdAt;

  CarDealer({
    required this.id,
    required this.userId,
    required this.dealerType,
    this.businessName,
    required this.ownerName,
    required this.phone,
    this.email,
    required this.city,
    this.district,
    required this.status,
    this.isVerified = false,
    this.totalListings = 0,
    this.activeListings = 0,
    required this.createdAt,
  });

  factory CarDealer.fromJson(Map<String, dynamic> json) {
    return CarDealer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dealerType: json['dealer_type'] as String? ?? 'individual',
      businessName: json['business_name'] as String?,
      ownerName: json['owner_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      city: json['city'] as String,
      district: json['district'] as String?,
      status: json['status'] as String? ?? 'pending',
      isVerified: json['is_verified'] as bool? ?? false,
      totalListings: json['total_listings'] as int? ?? 0,
      activeListings: json['active_listings'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CarDealerApplication {
  final String id;
  final String userId;
  final String dealerType;
  final String? businessName;
  final String ownerName;
  final String phone;
  final String? email;
  final String city;
  final String? district;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;

  CarDealerApplication({
    required this.id,
    required this.userId,
    required this.dealerType,
    this.businessName,
    required this.ownerName,
    required this.phone,
    this.email,
    required this.city,
    this.district,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  factory CarDealerApplication.fromJson(Map<String, dynamic> json) {
    return CarDealerApplication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dealerType: json['dealer_type'] as String? ?? 'individual',
      businessName: json['business_name'] as String?,
      ownerName: json['owner_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      city: json['city'] as String,
      district: json['district'] as String?,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PromotionPrice {
  final String id;
  final String promotionType;
  final int durationDays;
  final double price;
  final double? discountedPrice;
  final String? description;
  final bool isActive;
  final int sortOrder;

  PromotionPrice({
    required this.id,
    required this.promotionType,
    required this.durationDays,
    required this.price,
    this.discountedPrice,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory PromotionPrice.fromJson(Map<String, dynamic> json) {
    return PromotionPrice(
      id: json['id'] as String,
      promotionType: json['promotion_type'] as String,
      durationDays: json['duration_days'] as int,
      price: (json['price'] as num).toDouble(),
      discountedPrice: (json['discounted_price'] as num?)?.toDouble(),
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class CarBodyType {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  CarBodyType({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarBodyType.fromJson(Map<String, dynamic> json) {
    return CarBodyType(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CarFuelType {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;

  CarFuelType({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarFuelType.fromJson(Map<String, dynamic> json) {
    return CarFuelType(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class CarTransmission {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  CarTransmission({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarTransmission.fromJson(Map<String, dynamic> json) {
    return CarTransmission(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// ==================== SERVİS ====================

class CarSalesAdminService {
  final SupabaseClient _client;

  CarSalesAdminService(this._client);

  // İstatistikler
  Future<CarSalesStats> getStats() async {
    try {
      final totalListings = await _client
          .from('car_listings')
          .select('id')
          .count();

      final pendingListings = await _client
          .from('car_listings')
          .select('id')
          .eq('status', 'pending')
          .count();

      final activeListings = await _client
          .from('car_listings')
          .select('id')
          .eq('status', 'active')
          .count();

      final soldListings = await _client
          .from('car_listings')
          .select('id')
          .eq('status', 'sold')
          .count();

      final totalDealers = await _client
          .from('car_dealers')
          .select('id')
          .eq('status', 'active')
          .count();

      final pendingApplications = await _client
          .from('car_dealer_applications')
          .select('id')
          .eq('status', 'pending')
          .count();

      final totalBrands = await _client
          .from('car_brands')
          .select('id')
          .eq('is_active', true)
          .count();

      return CarSalesStats(
        totalListings: totalListings.count,
        pendingListings: pendingListings.count,
        activeListings: activeListings.count,
        soldListings: soldListings.count,
        totalDealers: totalDealers.count,
        pendingApplications: pendingApplications.count,
        totalBrands: totalBrands.count,
      );
    } catch (e) {
      debugPrint('CarSalesAdminService.getStats error: $e');
      return CarSalesStats.empty();
    }
  }

  // İlan İşlemleri
  Future<List<CarListing>> getListings({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _client.from('car_listings').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((e) => CarListing.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getListings error: $e');
      return [];
    }
  }

  Future<List<CarListing>> getPendingListings() async {
    return getListings(status: 'pending', limit: 20);
  }

  Future<void> updateListingStatus(String listingId, String status, {String? rejectionReason}) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (status == 'active') {
      updates['published_at'] = DateTime.now().toIso8601String();
    } else if (status == 'rejected' && rejectionReason != null) {
      updates['rejection_reason'] = rejectionReason;
    }

    await _client
        .from('car_listings')
        .update(updates)
        .eq('id', listingId);
  }

  Future<void> deleteListing(String listingId) async {
    await _client
        .from('car_listings')
        .delete()
        .eq('id', listingId);
  }

  // Marka İşlemleri
  Future<List<CarBrand>> getBrands() async {
    try {
      final response = await _client
          .from('car_brands')
          .select()
          .order('sort_order');

      return (response as List).map((e) => CarBrand.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getBrands error: $e');
      return [];
    }
  }

  Future<void> createBrand(Map<String, dynamic> data) async {
    await _client.from('car_brands').insert(data);
  }

  Future<void> updateBrand(String brandId, Map<String, dynamic> data) async {
    await _client.from('car_brands').update(data).eq('id', brandId);
  }

  Future<void> deleteBrand(String brandId) async {
    await _client.from('car_brands').delete().eq('id', brandId);
  }

  // Özellik İşlemleri
  Future<List<CarFeature>> getFeatures() async {
    try {
      final response = await _client
          .from('car_features')
          .select()
          .order('category')
          .order('sort_order');

      return (response as List).map((e) => CarFeature.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getFeatures error: $e');
      return [];
    }
  }

  Future<void> createFeature(Map<String, dynamic> data) async {
    await _client.from('car_features').insert(data);
  }

  Future<void> updateFeature(String featureId, Map<String, dynamic> data) async {
    await _client.from('car_features').update(data).eq('id', featureId);
  }

  Future<void> deleteFeature(String featureId) async {
    await _client.from('car_features').delete().eq('id', featureId);
  }

  // Satıcı İşlemleri
  Future<List<CarDealer>> getDealers({String? status}) async {
    try {
      var query = _client.from('car_dealers').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((e) => CarDealer.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getDealers error: $e');
      return [];
    }
  }

  Future<void> updateDealerStatus(String dealerId, String status) async {
    await _client
        .from('car_dealers')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', dealerId);
  }

  Future<void> verifyDealer(String dealerId, bool verified) async {
    await _client
        .from('car_dealers')
        .update({
          'is_verified': verified,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', dealerId);
  }

  // Başvuru İşlemleri
  Future<List<CarDealerApplication>> getApplications({String? status}) async {
    try {
      var query = _client.from('car_dealer_applications').select();

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((e) => CarDealerApplication.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getApplications error: $e');
      return [];
    }
  }

  Future<void> approveApplication(String applicationId) async {
    // Başvuruyu al
    final application = await _client
        .from('car_dealer_applications')
        .select()
        .eq('id', applicationId)
        .single();

    // Satıcı oluştur
    await _client.from('car_dealers').insert({
      'user_id': application['user_id'],
      'dealer_type': application['dealer_type'],
      'business_name': application['business_name'],
      'owner_name': application['owner_name'],
      'phone': application['phone'],
      'email': application['email'],
      'city': application['city'],
      'district': application['district'],
      'address': application['address'],
      'status': 'active',
    });

    // Başvuruyu güncelle
    await _client
        .from('car_dealer_applications')
        .update({
          'status': 'approved',
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', applicationId);
  }

  Future<void> rejectApplication(String applicationId, String reason) async {
    await _client
        .from('car_dealer_applications')
        .update({
          'status': 'rejected',
          'rejection_reason': reason,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', applicationId);
  }

  // Fiyatlandırma İşlemleri
  Future<List<PromotionPrice>> getPromotionPrices() async {
    try {
      final response = await _client
          .from('car_promotion_prices')
          .select()
          .order('sort_order');

      return (response as List).map((e) => PromotionPrice.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getPromotionPrices error: $e');
      return [];
    }
  }

  Future<void> createPromotionPrice(Map<String, dynamic> data) async {
    await _client.from('car_promotion_prices').insert(data);
  }

  Future<void> updatePromotionPrice(String priceId, Map<String, dynamic> data) async {
    await _client.from('car_promotion_prices').update(data).eq('id', priceId);
  }

  Future<void> deletePromotionPrice(String priceId) async {
    await _client.from('car_promotion_prices').delete().eq('id', priceId);
  }

  // ==================== GÖVDE TİPİ İŞLEMLERİ ====================

  Future<List<CarBodyType>> getBodyTypes() async {
    try {
      final response = await _client
          .from('car_body_types')
          .select()
          .order('sort_order');

      return (response as List).map((e) => CarBodyType.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getBodyTypes error: $e');
      return [];
    }
  }

  Future<void> createBodyType(Map<String, dynamic> data) async {
    await _client.from('car_body_types').insert(data);
  }

  Future<void> updateBodyType(String id, Map<String, dynamic> data) async {
    await _client.from('car_body_types').update(data).eq('id', id);
  }

  Future<void> deleteBodyType(String id) async {
    await _client.from('car_body_types').delete().eq('id', id);
  }

  // ==================== YAKIT TİPİ İŞLEMLERİ ====================

  Future<List<CarFuelType>> getFuelTypes() async {
    try {
      final response = await _client
          .from('car_fuel_types')
          .select()
          .order('sort_order');

      return (response as List).map((e) => CarFuelType.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getFuelTypes error: $e');
      return [];
    }
  }

  Future<void> createFuelType(Map<String, dynamic> data) async {
    await _client.from('car_fuel_types').insert(data);
  }

  Future<void> updateFuelType(String id, Map<String, dynamic> data) async {
    await _client.from('car_fuel_types').update(data).eq('id', id);
  }

  Future<void> deleteFuelType(String id) async {
    await _client.from('car_fuel_types').delete().eq('id', id);
  }

  // ==================== VİTES TİPİ İŞLEMLERİ ====================

  Future<List<CarTransmission>> getTransmissions() async {
    try {
      final response = await _client
          .from('car_transmissions')
          .select()
          .order('sort_order');

      return (response as List).map((e) => CarTransmission.fromJson(e)).toList();
    } catch (e) {
      debugPrint('CarSalesAdminService.getTransmissions error: $e');
      return [];
    }
  }

  Future<void> createTransmission(Map<String, dynamic> data) async {
    await _client.from('car_transmissions').insert(data);
  }

  Future<void> updateTransmission(String id, Map<String, dynamic> data) async {
    await _client.from('car_transmissions').update(data).eq('id', id);
  }

  Future<void> deleteTransmission(String id) async {
    await _client.from('car_transmissions').delete().eq('id', id);
  }
}

// ==================== PROVIDERlar ====================

final carSalesAdminServiceProvider = Provider<CarSalesAdminService>((ref) {
  return CarSalesAdminService(Supabase.instance.client);
});

final carSalesStatsProvider = FutureProvider<CarSalesStats>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getStats();
});

final pendingCarListingsProvider = FutureProvider<List<CarListing>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getPendingListings();
});

final carBrandsProvider = FutureProvider<List<CarBrand>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getBrands();
});

final carFeaturesProvider = FutureProvider<List<CarFeature>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getFeatures();
});

final carDealersProvider = FutureProvider<List<CarDealer>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getDealers();
});

final pendingDealerApplicationsProvider = FutureProvider<List<CarDealerApplication>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getApplications(status: 'pending');
});

final carPromotionPricesProvider = FutureProvider<List<PromotionPrice>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getPromotionPrices();
});

final recentCarListingsProvider = FutureProvider<List<CarListing>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getListings(limit: 5);
});

final carBodyTypesProvider = FutureProvider<List<CarBodyType>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getBodyTypes();
});

final carFuelTypesProvider = FutureProvider<List<CarFuelType>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getFuelTypes();
});

final carTransmissionsProvider = FutureProvider<List<CarTransmission>>((ref) async {
  final service = ref.watch(carSalesAdminServiceProvider);
  return service.getTransmissions();
});
