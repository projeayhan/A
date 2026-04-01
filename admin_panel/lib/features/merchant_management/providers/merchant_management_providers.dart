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
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  },
);

// Option groups for a menu item
final menuItemOptionGroupsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, menuItemId) async {
    final client = ref.watch(supabaseProvider);
    final links = await client
        .from('menu_item_option_groups')
        .select('option_group_id')
        .eq('menu_item_id', menuItemId);
    final linkList = List<Map<String, dynamic>>.from(links);
    if (linkList.isEmpty) return [];

    final groupIds = linkList.map((l) => l['option_group_id'] as String).toList();
    final groups = await client
        .from('product_option_groups')
        .select('*, product_options(*)')
        .inFilter('id', groupIds)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(groups);
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
          .select('id, name, stock, low_stock_threshold, price, is_available, image_url')
          .eq('merchant_id', merchantId)
          .order('stock', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      final response = await client
          .from('menu_items')
          .select('id, name, price, is_available, image_url')
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

    // Calculate date filter based on period
    DateTime? startDate;
    final now = DateTime.now();
    switch (params.period) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'quarter':
        startDate = now.subtract(const Duration(days: 90));
        break;
      case 'year':
        startDate = now.subtract(const Duration(days: 365));
        break;
    }

    // Get orders for revenue calculation
    var query = client
        .from('orders')
        .select('total_amount, commission_rate, status, created_at')
        .eq('merchant_id', params.merchantId)
        .eq('status', 'delivered');
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    final orders = await query;

    final orderList = List<Map<String, dynamic>>.from(orders);
    double totalRevenue = 0;
    double totalCommission = 0;
    for (final order in orderList) {
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0;
      final rate = (order['commission_rate'] as num?)?.toDouble() ?? 0;
      totalRevenue += amount;
      totalCommission += amount * rate / 100;
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
    // reviews tablosu merchant_id kullanıyor
    final response = await client
        .from('reviews')
        .select()
        .eq('merchant_id', params.entityId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== COURIERS ====================

final merchantCouriersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, merchantId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('couriers')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== MESSAGES ====================

typedef MessageParams = ({String entityType, String entityId});

final entityConversationsProvider = FutureProvider.family<List<Map<String, dynamic>>, MessageParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);
    // conversations tablosu property_id, buyer_id, seller_id kullanıyor
    // entityType'a göre farklı filtre uygula
    final response = await client
        .from('conversations')
        .select('*, messages(id, content, sender_id, message_type, created_at, is_read)')
        .or('buyer_id.eq.${params.entityId},seller_id.eq.${params.entityId}')
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
