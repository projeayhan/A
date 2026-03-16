import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// ==================== ORDERS ====================

final merchantOrdersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('orders')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

Future<void> updateOrderStatus(SupabaseClient client, String orderId, String newStatus) async {
  await client.from('orders').update({'status': newStatus}).eq('id', orderId);
}

// ==================== MENU (food sector) ====================

final merchantMenuCategoriesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('menu_categories')
        .select()
        .eq('merchant_id', merchantId)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  },
);

final merchantMenuItemsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('menu_items')
        .select('*, menu_categories(name)')
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== PRODUCTS (market/store) ====================

final merchantProductsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('products')
        .select('*, product_categories(name)')
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

final merchantProductCategoriesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('product_categories')
        .select()
        .eq('merchant_id', merchantId)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== INVENTORY ====================

final merchantInventoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    // Try products table first, then menu_items
    try {
      final response = await client
          .from('products')
          .select('id, name, stock_quantity, min_stock_level, price, is_active, image_url')
          .eq('merchant_id', merchantId)
          .order('stock_quantity', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      final response = await client
          .from('menu_items')
          .select('id, name, stock_quantity, min_stock_level, price, is_available, image_url')
          .eq('merchant_id', merchantId)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    }
  },
);

// ==================== FINANCE ====================

typedef FinanceParams = ({String merchantId, String period});

final merchantFinanceProvider = FutureProvider.family<Map<String, dynamic>, FinanceParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);

    // Get orders for revenue calculation
    final orders = await client
        .from('orders')
        .select('total_amount, commission_amount, status, created_at')
        .eq('merchant_id', params.merchantId)
        .eq('status', 'completed');

    final orderList = List<Map<String, dynamic>>.from(orders);
    double totalRevenue = 0;
    double totalCommission = 0;
    for (final order in orderList) {
      totalRevenue += (order['total_amount'] as num?)?.toDouble() ?? 0;
      totalCommission += (order['commission_amount'] as num?)?.toDouble() ?? 0;
    }

    return {
      'total_revenue': totalRevenue,
      'total_commission': totalCommission,
      'net_revenue': totalRevenue - totalCommission,
      'order_count': orderList.length,
      'orders': orderList,
    };
  },
);

// ==================== REVIEWS ====================

typedef ReviewParams = ({String entityType, String entityId});

final entityReviewsProvider = FutureProvider.family<List<Map<String, dynamic>>, ReviewParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('reviews')
        .select('*, users(full_name, avatar_url)')
        .eq('entity_type', params.entityType)
        .eq('entity_id', params.entityId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== COURIERS ====================

final merchantCouriersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('courier_assignments')
        .select('*, couriers(full_name, phone, status, avatar_url, rating, total_deliveries)')
        .eq('merchant_id', merchantId);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== MESSAGES ====================

typedef MessageParams = ({String entityType, String entityId});

final entityConversationsProvider = FutureProvider.family<List<Map<String, dynamic>>, MessageParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('conversations')
        .select('*, messages(id, message, sender_type, sender_name, created_at, is_read)')
        .eq('entity_type', params.entityType)
        .eq('entity_id', params.entityId)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== MERCHANT SETTINGS ====================

final merchantSettingsProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('merchants')
        .select()
        .eq('id', merchantId)
        .maybeSingle();
    return response;
  },
);
