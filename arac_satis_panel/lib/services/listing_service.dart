import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arac_satis_panel/core/services/log_service.dart';
import '../models/car_models.dart';

/// Araç İlanı Servisi
/// İlan CRUD işlemleri
class ListingService {
  static final ListingService _instance = ListingService._internal();
  static ListingService get instance => _instance;
  factory ListingService() => _instance;
  ListingService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== MARKA VE ÖZELLİKLER ====================

  /// Markaları getir
  Future<List<CarBrand>> getBrands({bool popularOnly = false}) async {
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
          .map((json) => CarBrand.fromJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('Markalar alınamadı', error: e, stackTrace: st, source: 'ListingService:getBrands');
      return [];
    }
  }

  /// Özellikleri getir
  Future<List<CarFeature>> getFeatures({String? category}) async {
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
          .map((json) => CarFeature.fromJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('Özellikler alınamadı', error: e, stackTrace: st, source: 'ListingService:getFeatures');
      return [];
    }
  }

  // ==================== İLAN LİSTELEME ====================

  /// Kullanıcının ilanlarını getir
  Future<List<CarListing>> getUserListings({
    CarListingStatus? status,
    int limit = 50,
    int offset = 0,
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
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => CarListing.fromJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('İlanlar alınamadı', error: e, stackTrace: st, source: 'ListingService:getUserListings');
      return [];
    }
  }

  /// İlan detayını getir
  Future<CarListing?> getListingById(String listingId) async {
    try {
      final response = await _client
          .from('car_listings')
          .select('''
            *,
            dealer:dealer_id (*)
          ''')
          .eq('id', listingId)
          .single();

      return CarListing.fromJson(response);
    } catch (e, st) {
      LogService.error('İlan alınamadı', error: e, stackTrace: st, source: 'ListingService:getListingById');
      return null;
    }
  }

  // ==================== İLAN OLUŞTURMA / GÜNCELLEME ====================

  /// Yeni ilan oluştur
  Future<CarListing?> createListing(CarListing listing) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    try {
      // Dealer ID'yi al
      final dealer = await _client
          .from('car_dealers')
          .select('id')
          .eq('user_id', _userId!)
          .maybeSingle();

      final data = listing.toJson();
      data['user_id'] = _userId;
      data['dealer_id'] = dealer?['id'];
      data['status'] = 'pending';
      data.remove('id');
      data.remove('created_at');
      data.remove('updated_at');

      final response = await _client
          .from('car_listings')
          .insert(data)
          .select()
          .single();

      return CarListing.fromJson(response);
    } catch (e, st) {
      LogService.error('İlan oluşturulamadı', error: e, stackTrace: st, source: 'ListingService:createListing');
      rethrow;
    }
  }

  /// İlanı güncelle
  Future<CarListing?> updateListing(String listingId, Map<String, dynamic> updates) async {
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

      return CarListing.fromJson(response);
    } catch (e, st) {
      LogService.error('İlan güncellenemedi', error: e, stackTrace: st, source: 'ListingService:updateListing');
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
    } catch (e, st) {
      LogService.error('İlan silinemedi', error: e, stackTrace: st, source: 'ListingService:deleteListing');
      return false;
    }
  }

  // ==================== İLAN DURUMU ====================

  /// İlanı satıldı olarak işaretle
  Future<bool> markAsSold(String listingId) async {
    try {
      await _client
          .from('car_listings')
          .update({
            'status': 'sold',
            'sold_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listingId)
          .eq('user_id', _userId!);

      return true;
    } catch (e, st) {
      LogService.error('İlan satıldı olarak işaretlenemedi', error: e, stackTrace: st, source: 'ListingService:markAsSold');
      return false;
    }
  }

  /// İlanı tekrar yayınla
  Future<bool> republishListing(String listingId) async {
    try {
      await _client
          .from('car_listings')
          .update({
            'status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', listingId)
          .eq('user_id', _userId!);

      return true;
    } catch (e, st) {
      LogService.error('İlan tekrar yayınlanamadı', error: e, stackTrace: st, source: 'ListingService:republishListing');
      return false;
    }
  }

  // ==================== GÖRÜNTÜLENME ====================

  /// Görüntülenme kaydet
  Future<void> recordView(String listingId, {String? sessionId}) async {
    try {
      await _client.rpc('increment_car_listing_view', params: {
        'p_listing_id': listingId,
        'p_user_id': _userId,
        'p_session_id': sessionId,
      });
    } catch (e, st) {
      LogService.error('Görüntülenme kaydedilemedi', error: e, stackTrace: st, source: 'ListingService:recordView');
    }
  }
}
