import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_category_model.dart';
import '../../models/store/store_product_model.dart';
import 'supabase_service.dart';

class StoreService {
  static SupabaseClient get _client => SupabaseService.client;

  // Kategorileri getir
  static Future<List<StoreCategory>> getCategories() async {
    try {
      final response = await _client
          .from('store_categories')
          .select()
          .order('name');

      return (response as List)
          .map((json) => StoreCategory.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching categories: $e');
      return [];
    }
  }

  // Tüm mağazaları getir (teslimat bölgesi kontrolü YOK - tüm KKTC'ye kargo ile hizmet verir)
  static Future<List<Store>> getStores({
    double? customerLat,
    double? customerLon,
  }) async {
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
    } catch (e) {
      if (kDebugMode) print('Error fetching stores: $e');
      return [];
    }
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
          .contains('category_tags', [categoryId])
          .order('rating', ascending: false);

      return (response as List)
          .map((json) => Store.fromMerchant(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching stores by category: $e');
      return [];
    }
  }

  // Öne çıkan mağazaları getir (teslimat bölgesi kontrolü YOK)
  static Future<List<Store>> getFeaturedStores({
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
          .order('rating', ascending: false)
          .limit(10);

      return (response as List)
          .map((json) => Store.fromMerchant(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching featured stores: $e');
      return [];
    }
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
    } catch (e) {
      if (kDebugMode) print('Error fetching store ids: $e');
      return [];
    }
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
    } catch (e) {
      if (kDebugMode) print('Error fetching products: $e');
      return [];
    }
  }

  // Mağazaya göre ürünleri getir
  static Future<List<StoreProduct>> getProductsByStore(String storeId) async {
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
    } catch (e) {
      if (kDebugMode) print('Error fetching products by store: $e');
      return [];
    }
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
    } catch (e) {
      if (kDebugMode) print('Error fetching products by category: $e');
      return [];
    }
  }

  // Flash deal ürünlerini getir (indirimli ürünler, sadece mağaza ürünleri)
  static Future<List<StoreProduct>> getFlashDeals() async {
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
    } catch (e) {
      if (kDebugMode) print('Error fetching flash deals: $e');
      return [];
    }
  }

  // En çok satanları getir (sadece mağaza ürünleri)
  static Future<List<StoreProduct>> getBestSellers() async {
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
    } catch (e) {
      if (kDebugMode) print('Error fetching best sellers: $e');
      return [];
    }
  }

  // Önerilen ürünleri getir (sadece mağaza ürünleri)
  static Future<List<StoreProduct>> getRecommended() async {
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
    } catch (e) {
      if (kDebugMode) print('Error fetching recommended: $e');
      return [];
    }
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
    } catch (e) {
      if (kDebugMode) print('Error searching products: $e');
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
    } catch (e) {
      if (kDebugMode) print('Error searching stores: $e');
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
        if (kDebugMode) print('StoreService.createOrder Error: User not logged in');
        return null;
      }

      // Sipariş numarası oluştur
      final orderNumber = 'SP${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      if (kDebugMode) print('StoreService.createOrder: Creating order $orderNumber for merchant $merchantId');

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

      if (kDebugMode) print('StoreService.createOrder: Order created successfully - $orderNumber');
      return response;
    } catch (e) {
      if (kDebugMode) print('StoreService.createOrder Error: $e');
      rethrow;
    }
  }
}
