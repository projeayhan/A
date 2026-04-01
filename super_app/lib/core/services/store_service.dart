import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_category_model.dart';
import '../../models/store/store_product_model.dart';
import 'supabase_service.dart';
import '../utils/cache_helper.dart';
import 'package:super_app/core/services/log_service.dart';

class StoreService {
  static SupabaseClient get _client => SupabaseService.client;
  static final _cache = CacheManager();

  // Kategorileri getir
  static Future<List<StoreCategory>> getCategories() async {
    return _cache.getOrFetch<List<StoreCategory>>(
      'store_categories',
      ttl: const Duration(minutes: 30),
      fetcher: () async {
        try {
          final response = await _client
              .from('store_categories')
              .select()
              .eq('is_active', true)
              .order('sort_order');

          return (response as List)
              .map((json) => StoreCategory.fromJson(json))
              .toList();
        } catch (e, st) {
          LogService.error('Error fetching categories', error: e, stackTrace: st, source: 'StoreService:getCategories');
          return [];
        }
      },
    );
  }

  // Tüm mağazaları getir (teslimat bölgesi kontrolü YOK - tüm KKTC'ye kargo ile hizmet verir)
  static Future<List<Store>> getStores({
    double? customerLat,
    double? customerLon,
  }) async {
    return _cache.getOrFetch<List<Store>>(
      'stores_all',
      ttl: const Duration(minutes: 30),
      fetcher: () async {
        try {
          // Mağazalar için bölge kontrolü yok - tüm onaylı mağazaları getir
          final response = await _client
              .from('merchants')
              .select('*, products(count)')
              .eq('type', 'store')
              .eq('is_approved', true)
              .order('rating', ascending: false);

          return (response as List)
              .map((json) => Store.fromMerchant(json))
              .toList();
        } catch (e, st) {
          LogService.error('Error fetching stores', error: e, stackTrace: st, source: 'StoreService:getStores');
          return [];
        }
      },
    );
  }

  // Kategoriye göre mağazaları getir (teslimat bölgesi kontrolü YOK)
  static Future<List<Store>> getStoresByCategory(
    String categoryId, {
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      // Mağazalar için bölge kontrolü yok
      final response = await _client
          .from('merchants')
          .select('*, products(count)')
          .eq('type', 'store')
          .eq('is_approved', true)
          .contains('store_category_ids', [categoryId])
          .order('rating', ascending: false);

      return (response as List)
          .map((json) => Store.fromMerchant(json))
          .toList();
    } catch (e, st) {
      LogService.error('Error fetching stores by category', error: e, stackTrace: st, source: 'StoreService:getStoresByCategory');
      return [];
    }
  }

  // Öne çıkan mağazaları getir (teslimat bölgesi kontrolü YOK)
  static Future<List<Store>> getFeaturedStores({
    double? customerLat,
    double? customerLon,
  }) async {
    return _cache.getOrFetch<List<Store>>(
      'stores_featured',
      ttl: const Duration(minutes: 30),
      fetcher: () async {
        try {
          // Mağazalar için bölge kontrolü yok
          final response = await _client
              .from('merchants')
              .select('*, products(count)')
              .eq('type', 'store')
              .eq('is_approved', true)
              .order('rating', ascending: false)
              .limit(10);

          return (response as List)
              .map((json) => Store.fromMerchant(json))
              .toList();
        } catch (e, st) {
          LogService.error('Error fetching featured stores', error: e, stackTrace: st, source: 'StoreService:getFeaturedStores');
          return [];
        }
      },
    );
  }

  // Mağaza ID'lerini getir (type='store' olan merchant'lar)
  static Future<List<String>> _getStoreIds() async {
    try {
      final response = await _client
          .from('merchants')
          .select('id')
          .eq('type', 'store')
          .eq('is_approved', true);

      return (response as List).map((json) => json['id'] as String).toList();
    } catch (e, st) {
      LogService.error('Error fetching store ids', error: e, stackTrace: st, source: 'StoreService:_getStoreIds');
      return [];
    }
  }

  // Tek ürün getir (ID ile)
  static Future<StoreProduct?> getProductById(String productId) async {
    return _cache.getOrFetch<StoreProduct?>(
      'store_product_$productId',
      ttl: const Duration(minutes: 15),
      fetcher: () async {
        try {
          final response = await _client
              .from('products')
              .select('*, merchants(business_name)')
              .eq('id', productId)
              .maybeSingle();
          if (response == null) return null;
          final merchantData = response['merchants'];
          final storeName = merchantData != null ? merchantData['business_name'] as String? ?? '' : '';
          return StoreProduct.fromJson(response, storeName: storeName);
        } catch (e, st) {
          LogService.error('Error fetching product by id', error: e, stackTrace: st, source: 'StoreService:getProductById');
          return null;
        }
      },
    );
  }

  // Tek mağaza getir (ID ile)
  static Future<Store?> getStoreById(String storeId) async {
    return _cache.getOrFetch<Store?>(
      'store_detail_$storeId',
      ttl: const Duration(minutes: 15),
      fetcher: () async {
        try {
          final response = await _client
              .from('merchants')
              .select()
              .eq('id', storeId)
              .eq('type', 'store')
              .maybeSingle();
          if (response == null) return null;
          return Store.fromJson(response);
        } catch (e, st) {
          LogService.error('Error fetching store by id', error: e, stackTrace: st, source: 'StoreService:getStoreById');
          return null;
        }
      },
    );
  }

  // Tüm ürünleri getir (sadece type='store' olan merchant'ların ürünleri)
  static Future<List<StoreProduct>> getProducts() async {
    try {
      final storeIds = await _getStoreIds();
      if (storeIds.isEmpty) return [];

      final response = await _client
          .from('products')
          .select()
          .inFilter('merchant_id', storeIds)
          .eq('is_available', true)
          .order('sold_count', ascending: false);

      return (response as List).map((json) {
        return StoreProduct.fromJson(json, storeName: '');
      }).toList();
    } catch (e, st) {
      LogService.error('Error fetching products', error: e, stackTrace: st, source: 'StoreService:getProducts');
      return [];
    }
  }

  // Mağazaya göre ürünleri getir
  static Future<List<StoreProduct>> getProductsByStore(String storeId) async {
    return _cache.getOrFetch<List<StoreProduct>>(
      'store_products_$storeId',
      ttl: const Duration(minutes: 15),
      fetcher: () async {
        try {
          final response = await _client
              .from('products')
              .select('*, product_categories(id, name, sort_order)')
              .eq('merchant_id', storeId)
              .eq('is_available', true)
              .order('sold_count', ascending: false);

          return (response as List).map((json) {
            // Extract category name and sort_order from joined data
            final categoryData = json['product_categories'];
            final categoryName = categoryData != null ? categoryData['name'] as String? : null;
            final categorySortOrder = categoryData != null ? (categoryData['sort_order'] as int?) ?? 999 : 999;
            return StoreProduct.fromJson(
              json,
              storeName: '',
              categoryName: categoryName,
              categorySortOrder: categorySortOrder,
            );
          }).toList();
        } catch (e, st) {
          LogService.error('Error fetching products by store', error: e, stackTrace: st, source: 'StoreService:getProductsByStore');
          return [];
        }
      },
    );
  }

  // Kategoriye göre ürünleri getir (sadece mağaza ürünleri)
  static Future<List<StoreProduct>> getProductsByCategory(String categoryId) async {
    try {
      final storeIds = await _getStoreIds();
      if (storeIds.isEmpty) return [];

      final response = await _client
          .from('products')
          .select()
          .eq('category_id', categoryId)
          .inFilter('merchant_id', storeIds)
          .eq('is_available', true)
          .order('sold_count', ascending: false);

      return (response as List).map((json) {
        return StoreProduct.fromJson(json, storeName: '');
      }).toList();
    } catch (e, st) {
      LogService.error('Error fetching products by category', error: e, stackTrace: st, source: 'StoreService:getProductsByCategory');
      return [];
    }
  }

  // Flash deal ürünlerini getir (indirimli ürünler, sadece mağaza ürünleri)
  static Future<List<StoreProduct>> getFlashDeals() async {
    return _cache.getOrFetch<List<StoreProduct>>(
      'store_flash_deals',
      ttl: const Duration(minutes: 5),
      fetcher: () async {
        try {
          final storeIds = await _getStoreIds();
          if (storeIds.isEmpty) return [];

          final response = await _client
              .from('products')
              .select()
              .inFilter('merchant_id', storeIds)
              .eq('is_available', true)
              .not('original_price', 'is', null)
              .order('sold_count', ascending: false)
              .limit(20);

          return (response as List).map((json) {
            return StoreProduct.fromJson(json, storeName: '');
          }).toList();
        } catch (e, st) {
          LogService.error('Error fetching flash deals', error: e, stackTrace: st, source: 'StoreService:getFlashDeals');
          return [];
        }
      },
    );
  }

  // En çok satanları getir (sadece mağaza ürünleri)
  static Future<List<StoreProduct>> getBestSellers() async {
    return _cache.getOrFetch<List<StoreProduct>>(
      'store_best_sellers',
      ttl: const Duration(minutes: 30),
      fetcher: () async {
        try {
          final storeIds = await _getStoreIds();
          if (storeIds.isEmpty) return [];

          final response = await _client
              .from('products')
              .select()
              .inFilter('merchant_id', storeIds)
              .eq('is_available', true)
              .order('sold_count', ascending: false)
              .limit(20);

          return (response as List).map((json) {
            return StoreProduct.fromJson(json, storeName: '');
          }).toList();
        } catch (e, st) {
          LogService.error('Error fetching best sellers', error: e, stackTrace: st, source: 'StoreService:getBestSellers');
          return [];
        }
      },
    );
  }

  // Önerilen ürünleri getir (sadece mağaza ürünleri)
  static Future<List<StoreProduct>> getRecommended() async {
    return _cache.getOrFetch<List<StoreProduct>>(
      'store_recommended',
      ttl: const Duration(minutes: 30),
      fetcher: () async {
        try {
          final storeIds = await _getStoreIds();
          if (storeIds.isEmpty) return [];

          final response = await _client
              .from('products')
              .select()
              .inFilter('merchant_id', storeIds)
              .eq('is_available', true)
              .gte('rating', 4.0)
              .order('rating', ascending: false)
              .limit(20);

          return (response as List).map((json) {
            return StoreProduct.fromJson(json, storeName: '');
          }).toList();
        } catch (e, st) {
          LogService.error('Error fetching recommended', error: e, stackTrace: st, source: 'StoreService:getRecommended');
          return [];
        }
      },
    );
  }

  // Ürün ara (sadece mağaza ürünleri)
  static Future<List<StoreProduct>> searchProducts(String query) async {
    try {
      final storeIds = await _getStoreIds();
      if (storeIds.isEmpty) return [];

      final response = await _client
          .from('products')
          .select()
          .inFilter('merchant_id', storeIds)
          .eq('is_available', true)
          .ilike('name', '%$query%')
          .order('sold_count', ascending: false)
          .limit(50);

      return (response as List).map((json) {
        return StoreProduct.fromJson(json, storeName: '');
      }).toList();
    } catch (e, st) {
      LogService.error('Error searching products', error: e, stackTrace: st, source: 'StoreService:searchProducts');
      return [];
    }
  }

  // Mağaza ara (teslimat bölgesi kontrolü YOK)
  static Future<List<Store>> searchStores(
    String query, {
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      // Mağazalar için bölge kontrolü yok
      final response = await _client
          .from('merchants')
          .select('*, products(count)')
          .eq('type', 'store')
          .eq('is_approved', true)
          .ilike('business_name', '%$query%')
          .order('rating', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => Store.fromMerchant(json))
          .toList();
    } catch (e, st) {
      LogService.error('Error searching stores', error: e, stackTrace: st, source: 'StoreService:searchStores');
      return [];
    }
  }

  // Sipariş oluştur
  static Future<Map<String, dynamic>?> createOrder({
    required String merchantId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
    required String deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryInstructions,
    String paymentMethod = 'card',
    String paymentStatus = 'paid',
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('StoreService.createOrder Error: User not logged in');
        return null;
      }

      // Sipariş numarası oluştur
      final orderNumber = 'SP${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      if (kDebugMode) print('StoreService.createOrder: Creating order $orderNumber for merchant $merchantId');

      // Komisyon oranını belirle
      double commissionRate = 10.0;
      try {
        // Önce işletme özel oranı kontrol et
        final overrideResult = await _client
            .from('merchant_commission_overrides')
            .select('custom_rate')
            .eq('merchant_id', merchantId)
            .maybeSingle();
        if (overrideResult != null) {
          commissionRate = double.tryParse(overrideResult['custom_rate'].toString()) ?? 10.0;
        } else {
          // Merchant tipini al ve sektör bazlı oran bul
          final merchantResult = await _client
              .from('merchants')
              .select('type')
              .eq('id', merchantId)
              .single();
          final sector = merchantResult['type'] == 'market' ? 'market' : 'store';
          final rateResult = await _client
              .from('commission_rates')
              .select('default_rate')
              .eq('sector', sector)
              .eq('is_active', true)
              .maybeSingle();
          if (rateResult != null) {
            commissionRate = double.tryParse(rateResult['default_rate'].toString()) ?? 10.0;
          }
        }
      } catch (e, st) {
        LogService.error('Commission rate lookup failed', error: e, stackTrace: st, source: 'StoreService:createOrder');
      }

      final response = await _client
          .from('orders')
          .insert({
            'order_number': orderNumber,
            'user_id': userId,
            'merchant_id': merchantId,
            'items': items,
            'subtotal': subtotal,
            'delivery_fee': deliveryFee,
            'total_amount': totalAmount,
            'delivery_address': deliveryAddress,
            'delivery_latitude': deliveryLatitude,
            'delivery_longitude': deliveryLongitude,
            'delivery_instructions': deliveryInstructions,
            'payment_method': paymentMethod,
            'payment_status': paymentStatus,
            'status': 'pending',
            'commission_rate': commissionRate,
          })
          .select()
          .single();

      if (kDebugMode) print('StoreService.createOrder: Order created successfully - $orderNumber');
      return response;
    } catch (e, st) {
      LogService.error('StoreService.createOrder Error', error: e, stackTrace: st, source: 'StoreService:createOrder');
      rethrow;
    }
  }

  /// Online ödeme onaylandıktan sonra sipariş ödeme durumunu güncelle.
  static Future<void> updateOrderPaymentStatus(String orderId, String status) async {
    try {
      await _client.from('orders').update({'payment_status': status}).eq('id', orderId);
    } catch (e, st) {
      LogService.error('updateOrderPaymentStatus Error', error: e, stackTrace: st, source: 'StoreService:updateOrderPaymentStatus');
    }
  }

  /// Online ödeme başarısız olduğunda bekleyen siparişi iptal et.
  static Future<void> cancelOrder(String orderId) async {
    try {
      await _client.from('orders').update({
        'status': 'cancelled',
        'payment_status': 'failed',
      }).eq('id', orderId);
    } catch (e, st) {
      LogService.error('cancelOrder Error', error: e, stackTrace: st, source: 'StoreService:cancelOrder');
    }
  }

  /// Realtime invalidation: store_categories değiştiğinde çağır
  static void invalidateCategories() {
    _cache.invalidate('store_categories');
  }

  /// Realtime invalidation: stores değiştiğinde çağır
  static void invalidateStores() {
    _cache.invalidate('stores_all');
    _cache.invalidate('stores_featured');
  }

  /// Realtime invalidation: store_products değiştiğinde çağır
  static void invalidateProducts([String? storeId]) {
    if (storeId != null) {
      _cache.invalidate('store_products_$storeId');
    } else {
      _cache.invalidatePrefix('store_products_');
    }
    _cache.invalidate('store_flash_deals');
    _cache.invalidate('store_best_sellers');
    _cache.invalidate('store_recommended');
  }
}
