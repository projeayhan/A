import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_product_model.dart';
import 'supabase_service.dart';

/// Market service - Grocery stores like Migros, A101
/// Uses delivery zone filtering (unlike store_service which has no zone check)
class MarketService {
  static SupabaseClient get _client => SupabaseService.client;

  // Tüm marketleri getir (teslimat bölgesi filtreli)
  static Future<List<Store>> getMarkets({
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      // Müşteri konumu varsa, teslimat bölgesi içindeki marketleri getir
      if (customerLat != null && customerLon != null) {
        final deliveryRangeResponse = await _client
            .rpc('get_stores_in_delivery_range', params: {
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
            });

        final deliverableMarketIds = (deliveryRangeResponse as List)
            .map((json) => json['merchant_id'] as String)
            .toList();

        if (deliverableMarketIds.isEmpty) return [];

        final response = await _client
            .from('merchants')
            .select()
            .inFilter('id', deliverableMarketIds)
            .eq('type', 'market')
            .eq('is_approved', true)
            .order('rating', ascending: false);

        return (response as List)
            .map((json) => Store.fromMerchant(json))
            .toList();
      }

      // Konum yoksa tüm marketleri getir
      final response = await _client
          .from('merchants')
          .select()
          .eq('type', 'market')
          .eq('is_approved', true)
          .order('rating', ascending: false);

      return (response as List)
          .map((json) => Store.fromMerchant(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching markets: $e');
      return [];
    }
  }

  // Öne çıkan marketleri getir (teslimat bölgesi filtreli)
  static Future<List<Store>> getFeaturedMarkets({
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      if (customerLat != null && customerLon != null) {
        final deliveryRangeResponse = await _client
            .rpc('get_stores_in_delivery_range', params: {
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
            });

        final deliverableMarketIds = (deliveryRangeResponse as List)
            .map((json) => json['merchant_id'] as String)
            .toList();

        if (deliverableMarketIds.isEmpty) return [];

        final response = await _client
            .from('merchants')
            .select()
            .inFilter('id', deliverableMarketIds)
            .eq('type', 'market')
            .eq('is_approved', true)
            .order('rating', ascending: false)
            .limit(10);

        return (response as List)
            .map((json) => Store.fromMerchant(json))
            .toList();
      }

      final response = await _client
          .from('merchants')
          .select()
          .eq('type', 'market')
          .eq('is_approved', true)
          .order('rating', ascending: false)
          .limit(10);

      return (response as List)
          .map((json) => Store.fromMerchant(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching featured markets: $e');
      return [];
    }
  }

  // Market ID'lerini getir (type='market' olan merchant'lar, teslimat bölgesi filtreli)
  static Future<List<String>> _getMarketIds({
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      if (customerLat != null && customerLon != null) {
        final deliveryRangeResponse = await _client
            .rpc('get_stores_in_delivery_range', params: {
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
            });

        final deliverableMarketIds = (deliveryRangeResponse as List)
            .map((json) => json['merchant_id'] as String)
            .toList();

        if (deliverableMarketIds.isEmpty) return [];

        final response = await _client
            .from('merchants')
            .select('id')
            .inFilter('id', deliverableMarketIds)
            .eq('type', 'market')
            .eq('is_approved', true);

        return (response as List).map((json) => json['id'] as String).toList();
      }

      final response = await _client
          .from('merchants')
          .select('id')
          .eq('type', 'market')
          .eq('is_approved', true);

      return (response as List).map((json) => json['id'] as String).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching market ids: $e');
      return [];
    }
  }

  // Markete göre ürünleri getir
  static Future<List<StoreProduct>> getProductsByMarket(String marketId) async {
    try {
      final response = await _client
          .from('products')
          .select('*, product_categories(id, name, sort_order)')
          .eq('merchant_id', marketId)
          .eq('is_available', true)
          .order('sold_count', ascending: false);

      return (response as List).map((json) {
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
    } catch (e) {
      if (kDebugMode) print('Error fetching products by market: $e');
      return [];
    }
  }

  // Market ara (teslimat bölgesi filtreli)
  static Future<List<Store>> searchMarkets(
    String query, {
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      if (customerLat != null && customerLon != null) {
        final deliveryRangeResponse = await _client
            .rpc('get_stores_in_delivery_range', params: {
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
            });

        final deliverableMarketIds = (deliveryRangeResponse as List)
            .map((json) => json['merchant_id'] as String)
            .toList();

        if (deliverableMarketIds.isEmpty) return [];

        final response = await _client
            .from('merchants')
            .select()
            .inFilter('id', deliverableMarketIds)
            .eq('type', 'market')
            .eq('is_approved', true)
            .ilike('business_name', '%$query%')
            .order('rating', ascending: false)
            .limit(20);

        return (response as List)
            .map((json) => Store.fromMerchant(json))
            .toList();
      }

      final response = await _client
          .from('merchants')
          .select()
          .eq('type', 'market')
          .eq('is_approved', true)
          .ilike('business_name', '%$query%')
          .order('rating', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => Store.fromMerchant(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error searching markets: $e');
      return [];
    }
  }

  // İndirimli ürünler (sadece market ürünleri)
  static Future<List<StoreProduct>> getMarketDeals({
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      final marketIds = await _getMarketIds(
        customerLat: customerLat,
        customerLon: customerLon,
      );
      if (marketIds.isEmpty) return [];

      final response = await _client
          .from('products')
          .select()
          .inFilter('merchant_id', marketIds)
          .eq('is_available', true)
          .not('original_price', 'is', null)
          .order('sold_count', ascending: false)
          .limit(20);

      return (response as List).map((json) {
        return StoreProduct.fromJson(json, storeName: '');
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching market deals: $e');
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
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('MarketService.createOrder Error: User not logged in');
        return null;
      }

      final orderNumber = 'MK${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      if (kDebugMode) print('MarketService.createOrder: Creating order $orderNumber for market $merchantId');

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
            'payment_status': 'paid',
            'status': 'pending',
          })
          .select()
          .single();

      if (kDebugMode) print('MarketService.createOrder: Order created successfully - $orderNumber');
      return response;
    } catch (e) {
      if (kDebugMode) print('MarketService.createOrder Error: $e');
      rethrow;
    }
  }
}
