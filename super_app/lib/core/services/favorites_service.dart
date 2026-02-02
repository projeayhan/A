import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class FavoritesService {
  static SupabaseClient get _client => SupabaseService.client;

  // Get current user ID
  static String? get currentUserId => _client.auth.currentUser?.id;

  // Favorileri getir (merchant_id listesi)
  static Future<List<String>> getFavoriteMerchantIds() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('favorites')
          .select('merchant_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => row['merchant_id'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching favorites: $e');
      return [];
    }
  }

  // Favori merchant ekle (restaurant veya store)
  static Future<bool> addFavorite(String merchantId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _client.from('favorites').insert({
        'user_id': userId,
        'merchant_id': merchantId,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('Error adding favorite: $e');
      // Duplicate key error is OK
      return false;
    }
  }

  // Favori merchant sil
  static Future<bool> removeFavorite(String merchantId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('merchant_id', merchantId);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error removing favorite: $e');
      return false;
    }
  }

  // Merchant favorilerde mi kontrol et
  static Future<bool> isFavorite(String merchantId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final response = await _client
          .from('favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('merchant_id', merchantId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Toggle favorite (ekle veya çıkar)
  static Future<bool> toggleFavorite(String merchantId) async {
    final isFav = await isFavorite(merchantId);
    if (isFav) {
      return await removeFavorite(merchantId);
    } else {
      return await addFavorite(merchantId);
    }
  }

  // ============================================
  // LEGACY API - for backwards compatibility with other providers
  // These methods are kept for product, property, job favorites etc.
  // ============================================

  // Legacy: Get all favorites with item_type filtering (returns empty list - not supported in new schema)
  static Future<List<Map<String, dynamic>>> getFavorites(String userId) async {
    // Legacy API - favorites table no longer has item_type/item_data columns
    // Return empty list for backwards compatibility
    return [];
  }

  // Legacy: Add favorite with item type (no-op for backwards compatibility)
  static Future<bool> addFavoriteWithType({
    required String userId,
    required String itemId,
    required String itemType,
    required Map<String, dynamic> itemData,
  }) async {
    // For restaurant/store types, use the merchant favorites
    if (itemType == 'restaurant' || itemType == 'store') {
      return await addFavorite(itemId);
    }
    // For other types (product, property, etc.), this is a no-op
    // as the new schema doesn't support item_type
    return true;
  }

  // Legacy: Remove favorite with item type (no-op for backwards compatibility)
  static Future<bool> removeFavoriteWithType({
    required String userId,
    required String itemId,
    required String itemType,
  }) async {
    // For restaurant/store types, use the merchant favorites
    if (itemType == 'restaurant' || itemType == 'store') {
      return await removeFavorite(itemId);
    }
    // For other types, this is a no-op
    return true;
  }
}
