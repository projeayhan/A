import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_sales/car_sales_models.dart';

/// AI Moderasyon sonucu
class CarModerationResult {
  final bool success;
  final String result;
  final int? score;
  final bool? isAppropriate;
  final List<String> flags;
  final String? reason;
  final bool autoApproved;

  CarModerationResult({
    required this.success,
    required this.result,
    this.score,
    this.isAppropriate,
    this.flags = const [],
    this.reason,
    this.autoApproved = false,
  });

  factory CarModerationResult.fromJson(Map<String, dynamic> json) {
    return CarModerationResult(
      success: json['success'] as bool? ?? false,
      result: json['result'] as String? ?? json['moderation_status'] as String? ?? 'pending',
      score: json['score'] as int? ?? json['ai_score'] as int?,
      isAppropriate: json['is_appropriate'] as bool?,
      flags: (json['flags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      reason: json['reason'] as String? ?? json['ai_reason'] as String?,
      autoApproved: json['auto_approved'] as bool? ?? false,
    );
  }

  bool get isApproved => result == 'approved';
  bool get isRejected => result == 'rejected';
  bool get needsReview => result == 'manual_review' || result == 'pending';
}

/// Araç Satış Servisi - Supabase Entegrasyonu
/// Super App için araç ilanı işlemleri
class CarSalesService {
  static final CarSalesService _instance = CarSalesService._internal();
  static CarSalesService get instance => _instance;
  factory CarSalesService() => _instance;
  CarSalesService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== MARKALAR ====================

  /// Markaları Supabase'den getir
  Future<List<CarBrandData>> getBrands({bool popularOnly = false}) async {
    try {
      var query = _client
          .from('car_brands')
          .select()
          .eq('is_active', true);

      if (popularOnly) {
        query = query.eq('is_popular', true);
      }

      final response = await query.order('sort_order');

      return (response as List)
          .map((json) => CarBrandData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getBrands error: $e');
      return [];
    }
  }

  // ==================== ÖZELLİKLER ====================

  /// Özellikleri getir
  Future<List<CarFeatureData>> getFeatures({String? category}) async {
    try {
      var query = _client
          .from('car_features')
          .select()
          .eq('is_active', true);

      if (category != null) {
        query = query.eq('category', category);
      }

      final response = await query.order('sort_order');

      return (response as List)
          .map((json) => CarFeatureData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getFeatures error: $e');
      return [];
    }
  }

  // ==================== FİLTRE TİPLERİ ====================

  /// Gövde tiplerini getir
  Future<List<CarBodyTypeData>> getBodyTypes() async {
    try {
      final response = await _client
          .from('car_body_types')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => CarBodyTypeData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getBodyTypes error: $e');
      return [];
    }
  }

  /// Yakıt tiplerini getir
  Future<List<CarFuelTypeData>> getFuelTypes() async {
    try {
      final response = await _client
          .from('car_fuel_types')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => CarFuelTypeData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getFuelTypes error: $e');
      return [];
    }
  }

  /// Vites tiplerini getir
  Future<List<CarTransmissionData>> getTransmissions() async {
    try {
      final response = await _client
          .from('car_transmissions')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => CarTransmissionData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getTransmissions error: $e');
      return [];
    }
  }

  // ==================== İLANLAR ====================

  /// Aktif ilanları getir (ana sayfa için)
  Future<List<CarListingData>> getActiveListings({
    String? brandId,
    CarBodyType? bodyType,
    CarFuelType? fuelType,
    String? city,
    double? minPrice,
    double? maxPrice,
    int? minYear,
    int? maxYear,
    int? maxMileage,
    bool featuredOnly = false,
    String sortBy = 'newest',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from('car_listings')
          .select('''
            *,
            dealer:dealer_id (
              id, business_name, owner_name, phone, city, is_verified
            )
          ''')
          .eq('status', 'active');

      if (brandId != null) {
        query = query.eq('brand_id', brandId);
      }
      if (bodyType != null) {
        query = query.eq('body_type', bodyType.name);
      }
      if (fuelType != null) {
        query = query.eq('fuel_type', fuelType.name);
      }
      if (city != null) {
        query = query.eq('city', city);
      }
      if (minPrice != null) {
        query = query.gte('price', minPrice);
      }
      if (maxPrice != null) {
        query = query.lte('price', maxPrice);
      }
      if (minYear != null) {
        query = query.gte('year', minYear);
      }
      if (maxYear != null) {
        query = query.lte('year', maxYear);
      }
      if (maxMileage != null) {
        query = query.lte('mileage', maxMileage);
      }
      if (featuredOnly) {
        query = query.eq('is_featured', true);
      }

      // Sıralama ve sayfalama
      dynamic response;
      switch (sortBy) {
        case 'price_asc':
          response = await query.order('price', ascending: true).range(offset, offset + limit - 1);
          break;
        case 'price_desc':
          response = await query.order('price', ascending: false).range(offset, offset + limit - 1);
          break;
        case 'year_desc':
          response = await query.order('year', ascending: false).range(offset, offset + limit - 1);
          break;
        case 'mileage_asc':
          response = await query.order('mileage', ascending: true).range(offset, offset + limit - 1);
          break;
        case 'newest':
        default:
          response = await query
              .order('is_premium', ascending: false)
              .order('is_featured', ascending: false)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
      }

      return (response as List)
          .map((json) => CarListingData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getActiveListings error: $e');
      return [];
    }
  }

  /// Öne çıkan ilanları getir
  Future<List<CarListingData>> getFeaturedListings({int limit = 10}) async {
    return getActiveListings(featuredOnly: true, limit: limit);
  }

  /// Premium ilanları getir
  Future<List<CarListingData>> getPremiumListings({int limit = 10}) async {
    try {
      final response = await _client
          .from('car_listings')
          .select('''
            *,
            dealer:dealer_id (
              id, business_name, owner_name, phone, city, is_verified
            )
          ''')
          .eq('status', 'active')
          .eq('is_premium', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CarListingData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getPremiumListings error: $e');
      return [];
    }
  }

  /// İlan detayını getir
  Future<CarListingData?> getListingById(String listingId) async {
    try {
      final response = await _client
          .from('car_listings')
          .select('''
            *,
            dealer:dealer_id (*)
          ''')
          .eq('id', listingId)
          .single();

      // Görüntülenme kaydet
      _recordView(listingId);

      return CarListingData.fromJson(response);
    } catch (e) {
      debugPrint('CarSalesService.getListingById error: $e');
      return null;
    }
  }

  /// Görüntülenme kaydet (internal)
  Future<void> _recordView(String listingId) async {
    try {
      await _client.rpc('increment_car_listing_view', params: {
        'p_listing_id': listingId,
        'p_user_id': _userId,
      });
    } catch (e) {
      // Sessiz hata - görüntülenme kaydı kritik değil
    }
  }

  /// Görüntülenme kaydet (public)
  Future<void> recordView(String listingId) => _recordView(listingId);

  // ==================== KULLANICI İLANLARI ====================

  /// Kullanıcının ilanlarını getir
  Future<List<CarListingData>> getMyListings({
    CarListingStatus? status,
    int limit = 50,
  }) async {
    if (_userId == null) return [];

    try {
      var query = _client
          .from('car_listings')
          .select()
          .eq('user_id', _userId!);

      if (status != null) {
        query = query.eq('status', status.name);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CarListingData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getMyListings error: $e');
      return [];
    }
  }

  /// Yeni ilan oluştur
  Future<CarListingData?> createListing(Map<String, dynamic> data) async {
    if (_userId == null) throw Exception('Kullanıcı oturumu bulunamadı');

    try {
      // Dealer ID'yi al
      final dealer = await _client
          .from('car_dealers')
          .select('id')
          .eq('user_id', _userId!)
          .eq('status', 'active')
          .maybeSingle();

      data['user_id'] = _userId;
      data['dealer_id'] = dealer?['id'];
      data['status'] = 'pending';

      final response = await _client
          .from('car_listings')
          .insert(data)
          .select()
          .single();

      final listing = CarListingData.fromJson(response);

      // AI Moderasyon çağır (arka planda)
      _moderateListing(listing.id);

      return listing;
    } catch (e) {
      debugPrint('CarSalesService.createListing error: $e');
      rethrow;
    }
  }

  /// AI Moderasyon Edge Function çağır
  Future<CarModerationResult?> _moderateListing(String listingId) async {
    try {
      final response = await _client.functions.invoke(
        'moderate-listing',
        body: {'type': 'car', 'listing_id': listingId},
      );

      if (response.status == 200 && response.data != null) {
        return CarModerationResult.fromJson(response.data as Map<String, dynamic>);
      }

      debugPrint('Car moderation response: ${response.status} - ${response.data}');
      return null;
    } catch (e) {
      debugPrint('CarSalesService._moderateListing error: $e');
      return null;
    }
  }

  /// Moderasyon sonucunu al
  Future<CarModerationResult?> getModerationResult(String listingId) async {
    try {
      final response = await _client
          .from('content_moderation')
          .select()
          .eq('listing_type', 'car')
          .eq('listing_id', listingId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return CarModerationResult.fromJson(response);
    } catch (e) {
      debugPrint('CarSalesService.getModerationResult error: $e');
      return null;
    }
  }

  /// Araç resmi yükle
  Future<String?> uploadCarImage(Uint8List bytes, String fileName) async {
    if (_userId == null) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'car_listings/$_userId/${timestamp}_$fileName';

      await _client.storage.from('images').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final publicUrl = _client.storage.from('images').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('CarSalesService.uploadCarImage error: $e');
      return null;
    }
  }

  /// İlanı güncelle
  Future<CarListingData?> updateListing(String listingId, Map<String, dynamic> updates) async {
    if (_userId == null) return null;

    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      final response = await _client
          .from('car_listings')
          .update(updates)
          .eq('id', listingId)
          .eq('user_id', _userId!)
          .select()
          .single();

      return CarListingData.fromJson(response);
    } catch (e) {
      debugPrint('CarSalesService.updateListing error: $e');
      return null;
    }
  }

  /// İlanı sil
  Future<bool> deleteListing(String listingId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('car_listings')
          .delete()
          .eq('id', listingId)
          .eq('user_id', _userId!);

      return true;
    } catch (e) {
      debugPrint('CarSalesService.deleteListing error: $e');
      return false;
    }
  }

  /// İlanı satıldı olarak işaretle
  Future<bool> markAsSold(String listingId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('car_listings')
          .update({
            'status': 'sold',
            'sold_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listingId)
          .eq('user_id', _userId!);

      return true;
    } catch (e) {
      debugPrint('CarSalesService.markAsSold error: $e');
      return false;
    }
  }

  // ==================== FAVORİLER ====================

  /// Favorilere ekle
  Future<bool> addToFavorites(String listingId) async {
    if (_userId == null) return false;

    try {
      await _client.from('car_favorites').insert({
        'listing_id': listingId,
        'user_id': _userId,
      });
      return true;
    } catch (e) {
      debugPrint('CarSalesService.addToFavorites error: $e');
      return false;
    }
  }

  /// Favorilerden kaldır
  Future<bool> removeFromFavorites(String listingId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('car_favorites')
          .delete()
          .eq('listing_id', listingId)
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      debugPrint('CarSalesService.removeFromFavorites error: $e');
      return false;
    }
  }

  /// Favori mi kontrol et
  Future<bool> isFavorite(String listingId) async {
    if (_userId == null) return false;

    try {
      final response = await _client
          .from('car_favorites')
          .select('id')
          .eq('listing_id', listingId)
          .eq('user_id', _userId!)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Favori ilanları getir
  Future<List<CarListingData>> getFavoriteListings() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('car_favorites')
          .select('''
            listing:listing_id (
              *,
              dealer:dealer_id (
                id, business_name, owner_name, phone, city, is_verified
              )
            )
          ''')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      return (response as List)
          .where((item) => item['listing'] != null)
          .map((item) => CarListingData.fromJson(item['listing']))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.getFavoriteListings error: $e');
      return [];
    }
  }

  // ==================== İLETİŞİM ====================

  /// İletişim talebi gönder
  Future<bool> sendContactRequest({
    required String listingId,
    required String name,
    required String phone,
    String? email,
    String? message,
  }) async {
    try {
      await _client.from('car_contact_requests').insert({
        'listing_id': listingId,
        'user_id': _userId,
        'name': name,
        'phone': phone,
        'email': email,
        'message': message,
        'status': 'new',
      });
      return true;
    } catch (e) {
      debugPrint('CarSalesService.sendContactRequest error: $e');
      return false;
    }
  }

  // ==================== ARAMA ====================

  /// Araç ara
  Future<List<CarListingData>> searchListings(String query, {int limit = 20}) async {
    try {
      final response = await _client
          .from('car_listings')
          .select('''
            *,
            dealer:dealer_id (
              id, business_name, owner_name, phone, city, is_verified
            )
          ''')
          .eq('status', 'active')
          .or('title.ilike.%$query%,brand_name.ilike.%$query%,model_name.ilike.%$query%')
          .order('is_premium', ascending: false)
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CarListingData.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('CarSalesService.searchListings error: $e');
      return [];
    }
  }
}

// ==================== VERİ MODELLERİ ====================

/// Marka verisi (Supabase'den gelen)
class CarBrandData {
  final String id;
  final String name;
  final String? logoUrl;
  final String? country;
  final bool isPremium;
  final bool isPopular;
  final int sortOrder;

  CarBrandData({
    required this.id,
    required this.name,
    this.logoUrl,
    this.country,
    this.isPremium = false,
    this.isPopular = false,
    this.sortOrder = 0,
  });

  factory CarBrandData.fromJson(Map<String, dynamic> json) {
    return CarBrandData(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      country: json['country'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Özellik verisi
class CarFeatureData {
  final String id;
  final String name;
  final String category;
  final String? icon;

  CarFeatureData({
    required this.id,
    required this.name,
    required this.category,
    this.icon,
  });

  factory CarFeatureData.fromJson(Map<String, dynamic> json) {
    return CarFeatureData(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      icon: json['icon'] as String?,
    );
  }
}

/// Gövde tipi verisi (Supabase'den gelen)
class CarBodyTypeData {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  CarBodyTypeData({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarBodyTypeData.fromJson(Map<String, dynamic> json) {
    return CarBodyTypeData(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarBodyTypeData && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Yakıt tipi verisi (Supabase'den gelen)
class CarFuelTypeData {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;

  CarFuelTypeData({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarFuelTypeData.fromJson(Map<String, dynamic> json) {
    return CarFuelTypeData(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Color get colorValue {
    if (color == null || color!.isEmpty) return const Color(0xFF6B7280);
    try {
      return Color(int.parse(color!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF6B7280);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarFuelTypeData && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Vites tipi verisi (Supabase'den gelen)
class CarTransmissionData {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  CarTransmissionData({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarTransmissionData.fromJson(Map<String, dynamic> json) {
    return CarTransmissionData(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarTransmissionData && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Satıcı verisi
class CarDealerData {
  final String id;
  final String? businessName;
  final String ownerName;
  final String phone;
  final String city;
  final bool isVerified;

  CarDealerData({
    required this.id,
    this.businessName,
    required this.ownerName,
    required this.phone,
    required this.city,
    this.isVerified = false,
  });

  factory CarDealerData.fromJson(Map<String, dynamic> json) {
    return CarDealerData(
      id: json['id'] as String,
      businessName: json['business_name'] as String?,
      ownerName: json['owner_name'] as String,
      phone: json['phone'] as String,
      city: json['city'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  String get displayName => businessName ?? ownerName;
}

/// İlan verisi (Supabase'den gelen)
class CarListingData {
  final String id;
  final String? dealerId;
  final String userId;
  final String title;
  final String? description;
  final String brandId;
  final String brandName;
  final String modelName;
  final int year;
  final String bodyType;
  final String fuelType;
  final String transmission;
  final String traction;
  final int? engineCc;
  final int? horsepower;
  final int mileage;
  final String? exteriorColor;
  final String? interiorColor;
  final String condition;
  final double price;
  final bool isPriceNegotiable;
  final bool isExchangeAccepted;
  final List<String> images;
  final List<String> features;
  final String? city;
  final String? district;
  final String status;
  final bool isFeatured;
  final bool isPremium;
  final int viewCount;
  final int favoriteCount;
  final DateTime createdAt;
  final CarDealerData? dealer;

  CarListingData({
    required this.id,
    this.dealerId,
    required this.userId,
    required this.title,
    this.description,
    required this.brandId,
    required this.brandName,
    required this.modelName,
    required this.year,
    required this.bodyType,
    required this.fuelType,
    required this.transmission,
    this.traction = 'fwd',
    this.engineCc,
    this.horsepower,
    required this.mileage,
    this.exteriorColor,
    this.interiorColor,
    this.condition = 'good',
    required this.price,
    this.isPriceNegotiable = false,
    this.isExchangeAccepted = false,
    this.images = const [],
    this.features = const [],
    this.city,
    this.district,
    this.status = 'pending',
    this.isFeatured = false,
    this.isPremium = false,
    this.viewCount = 0,
    this.favoriteCount = 0,
    required this.createdAt,
    this.dealer,
  });

  factory CarListingData.fromJson(Map<String, dynamic> json) {
    return CarListingData(
      id: json['id'] as String,
      dealerId: json['dealer_id'] as String?,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      brandId: json['brand_id'] as String,
      brandName: json['brand_name'] as String? ?? '',
      modelName: json['model_name'] as String? ?? '',
      year: json['year'] as int,
      bodyType: json['body_type'] as String? ?? 'sedan',
      fuelType: json['fuel_type'] as String? ?? 'petrol',
      transmission: json['transmission'] as String? ?? 'manual',
      traction: json['traction'] as String? ?? 'fwd',
      engineCc: json['engine_cc'] as int?,
      horsepower: json['horsepower'] as int?,
      mileage: json['mileage'] as int,
      exteriorColor: json['exterior_color'] as String?,
      interiorColor: json['interior_color'] as String?,
      condition: json['condition'] as String? ?? 'good',
      price: (json['price'] as num).toDouble(),
      isPriceNegotiable: json['is_price_negotiable'] as bool? ?? false,
      isExchangeAccepted: json['is_exchange_accepted'] as bool? ?? false,
      images: (json['images'] as List?)?.cast<String>() ?? [],
      features: (json['features'] as List?)?.cast<String>() ?? [],
      city: json['city'] as String?,
      district: json['district'] as String?,
      status: json['status'] as String? ?? 'pending',
      isFeatured: json['is_featured'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      dealer: json['dealer'] != null
          ? CarDealerData.fromJson(json['dealer'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Tam araç adı
  String get fullName => '$brandName $modelName $year';

  /// Formatlı fiyat
  String get formattedPrice {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted TL';
  }

  /// Formatlı kilometre
  String get formattedMileage {
    final formatted = mileage.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted km';
  }

  /// İlan yaşı
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inMinutes} dakika önce';
    }
  }

  /// Body type enum'a çevir
  CarBodyType get bodyTypeEnum {
    try {
      return CarBodyType.values.firstWhere((e) => e.name == bodyType);
    } catch (_) {
      return CarBodyType.sedan;
    }
  }

  /// Fuel type enum'a çevir
  CarFuelType get fuelTypeEnum {
    try {
      return CarFuelType.values.firstWhere((e) => e.name == fuelType);
    } catch (_) {
      return CarFuelType.petrol;
    }
  }

  /// Transmission enum'a çevir
  CarTransmission get transmissionEnum {
    try {
      return CarTransmission.values.firstWhere((e) => e.name == transmission);
    } catch (_) {
      return CarTransmission.manual;
    }
  }

  /// Status enum'a çevir
  CarListingStatus get statusEnum {
    try {
      return CarListingStatus.values.firstWhere((e) => e.name == status);
    } catch (_) {
      return CarListingStatus.pending;
    }
  }
}
