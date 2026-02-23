import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'audit_service.dart';

final businessProxyServiceProvider = Provider<BusinessProxyService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final audit = ref.watch(auditServiceProvider);
  return BusinessProxyService(supabase, audit);
});

class BusinessProxyService {
  final SupabaseClient _supabase;
  final AuditService _audit;

  BusinessProxyService(this._supabase, this._audit);

  // ═══════════════════════════════════════════════════════════
  // ─── Merchant (Restaurant/Market/Store) Operations ───
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> searchMerchants(String query) async {
    try {
      return await _supabase
          .from('merchants')
          .select('id, business_name, type, phone, email, is_open, is_approved, logo_url')
          .or('business_name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
          .limit(20);
    } catch (e) {
      if (kDebugMode) print('Error searching merchants: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMerchantById(String merchantId) async {
    return await _supabase.from('merchants').select().eq('id', merchantId).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getMerchantOrders(String merchantId, {int limit = 50}) async {
    return await _supabase
        .from('orders')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, {String? merchantId}) async {
    final oldOrder = await _supabase.from('orders').select('status').eq('id', orderId).single();
    await _supabase.from('orders').update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);

    await _audit.logBusinessAction(
      action: 'order_status_change',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      oldData: {'status': oldOrder['status']},
      newData: {'status': newStatus},
    );
  }

  Future<List<Map<String, dynamic>>> getMenuItems(String merchantId) async {
    return await _supabase
        .from('menu_items')
        .select()
        .eq('merchant_id', merchantId)
        .order('sort_order');
  }

  Future<void> updateMenuItem(String itemId, Map<String, dynamic> updates, {String? merchantId}) async {
    await _supabase.from('menu_items').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);

    await _audit.logBusinessAction(
      action: 'menu_item_update',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      newData: updates,
    );
  }

  Future<List<Map<String, dynamic>>> getStoreProducts(String storeId) async {
    return await _supabase
        .from('store_products')
        .select()
        .eq('merchant_id', storeId)
        .order('created_at', ascending: false);
  }

  Future<void> toggleMerchantOpen(String merchantId, bool isOpen) async {
    await _supabase.from('merchants').update({
      'is_open': isOpen,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', merchantId);

    await _audit.logBusinessAction(
      action: isOpen ? 'merchant_opened' : 'merchant_closed',
      businessId: merchantId,
      businessType: 'merchant',
      newData: {'is_open': isOpen},
    );
  }

  // ─── Menu CRUD ───

  Future<Map<String, dynamic>> createMenuItem(String merchantId, Map<String, dynamic> data) async {
    final result = await _supabase.from('menu_items').insert({
      'merchant_id': merchantId,
      ...data,
      'is_available': true,
      'sort_order': 0,
    }).select().single();

    await _audit.logBusinessAction(
      action: 'menu_item_create',
      businessId: merchantId,
      businessType: 'merchant',
      newData: data,
    );
    return result;
  }

  Future<void> updateMenuItemFull(String itemId, Map<String, dynamic> data, {String? merchantId}) async {
    final old = await _supabase.from('menu_items').select().eq('id', itemId).single();
    await _supabase.from('menu_items').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', itemId);

    await _audit.logBusinessAction(
      action: 'menu_item_update',
      businessId: merchantId ?? old['merchant_id'] ?? '',
      businessType: 'merchant',
      oldData: {'name': old['name'], 'price': old['price']},
      newData: data,
    );
  }

  Future<void> deleteMenuItem(String itemId, {String? merchantId}) async {
    final old = await _supabase.from('menu_items').select('name, merchant_id').eq('id', itemId).single();
    await _supabase.from('menu_items').delete().eq('id', itemId);

    await _audit.logBusinessAction(
      action: 'menu_item_delete',
      businessId: merchantId ?? old['merchant_id'] ?? '',
      businessType: 'merchant',
      oldData: {'name': old['name']},
    );
  }

  // ─── Menu Categories ───

  Future<List<Map<String, dynamic>>> getMenuCategories(String merchantId) async {
    return await _supabase
        .from('menu_categories')
        .select()
        .eq('merchant_id', merchantId)
        .order('sort_order');
  }

  Future<Map<String, dynamic>> createMenuCategory(String merchantId, String name, {int sortOrder = 0}) async {
    final result = await _supabase.from('menu_categories').insert({
      'merchant_id': merchantId,
      'name': name,
      'sort_order': sortOrder,
      'is_active': true,
    }).select().single();

    await _audit.logBusinessAction(
      action: 'menu_category_create',
      businessId: merchantId,
      businessType: 'merchant',
      newData: {'name': name},
    );
    return result;
  }

  Future<void> updateMenuCategory(String categoryId, String name, {String? merchantId}) async {
    await _supabase.from('menu_categories').update({'name': name}).eq('id', categoryId);
    await _audit.logBusinessAction(
      action: 'menu_category_update',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      newData: {'name': name},
    );
  }

  Future<void> deleteMenuCategory(String categoryId, {String? merchantId}) async {
    await _supabase.from('menu_categories').delete().eq('id', categoryId);
    await _audit.logBusinessAction(
      action: 'menu_category_delete',
      businessId: merchantId ?? '',
      businessType: 'merchant',
    );
  }

  Future<void> reorderMenuCategories(String merchantId, List<Map<String, dynamic>> items) async {
    for (int i = 0; i < items.length; i++) {
      await _supabase.from('menu_categories').update({'sort_order': i}).eq('id', items[i]['id']);
    }
  }

  // ─── Product CRUD ───

  Future<Map<String, dynamic>> createProduct(String merchantId, Map<String, dynamic> data) async {
    final result = await _supabase.from('store_products').insert({
      'merchant_id': merchantId,
      ...data,
      'is_available': true,
    }).select().single();

    await _audit.logBusinessAction(
      action: 'product_create',
      businessId: merchantId,
      businessType: 'merchant',
      newData: data,
    );
    return result;
  }

  Future<void> updateProductFull(String productId, Map<String, dynamic> data, {String? merchantId}) async {
    final old = await _supabase.from('store_products').select().eq('id', productId).single();
    await _supabase.from('store_products').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', productId);

    await _audit.logBusinessAction(
      action: 'product_update',
      businessId: merchantId ?? old['merchant_id'] ?? '',
      businessType: 'merchant',
      oldData: {'name': old['name'], 'price': old['price']},
      newData: data,
    );
  }

  Future<void> deleteProduct(String productId, {String? merchantId}) async {
    final old = await _supabase.from('store_products').select('name, merchant_id').eq('id', productId).single();
    await _supabase.from('store_products').delete().eq('id', productId);

    await _audit.logBusinessAction(
      action: 'product_delete',
      businessId: merchantId ?? old['merchant_id'] ?? '',
      businessType: 'merchant',
      oldData: {'name': old['name']},
    );
  }

  Future<void> updateProductStock(String productId, int newStock, {String? merchantId}) async {
    final old = await _supabase.from('store_products').select('stock').eq('id', productId).single();
    await _supabase.from('store_products').update({'stock': newStock}).eq('id', productId);

    await _audit.logBusinessAction(
      action: 'product_stock_update',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      oldData: {'stock': old['stock']},
      newData: {'stock': newStock},
    );
  }

  // ─── Product Categories ───

  Future<List<Map<String, dynamic>>> getProductCategories(String merchantId) async {
    return await _supabase
        .from('product_categories')
        .select()
        .or('merchant_id.eq.$merchantId,merchant_id.is.null')
        .order('sort_order');
  }

  Future<Map<String, dynamic>> createProductCategory(String merchantId, String name, {int sortOrder = 0}) async {
    final result = await _supabase.from('product_categories').insert({
      'merchant_id': merchantId,
      'name': name,
      'sort_order': sortOrder,
    }).select().single();

    await _audit.logBusinessAction(
      action: 'product_category_create',
      businessId: merchantId,
      businessType: 'merchant',
      newData: {'name': name},
    );
    return result;
  }

  Future<void> updateProductCategory(String categoryId, String name, {String? merchantId}) async {
    await _supabase.from('product_categories').update({'name': name}).eq('id', categoryId);
    await _audit.logBusinessAction(
      action: 'product_category_update',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      newData: {'name': name},
    );
  }

  Future<void> deleteProductCategory(String categoryId, {String? merchantId}) async {
    await _supabase.from('product_categories').delete().eq('id', categoryId);
    await _audit.logBusinessAction(
      action: 'product_category_delete',
      businessId: merchantId ?? '',
      businessType: 'merchant',
    );
  }

  Future<void> reorderProductCategories(String merchantId, List<Map<String, dynamic>> items) async {
    for (int i = 0; i < items.length; i++) {
      await _supabase.from('product_categories').update({'sort_order': i}).eq('id', items[i]['id']);
    }
  }

  // ─── Working Hours ───

  Future<List<Map<String, dynamic>>> getMerchantWorkingHours(String merchantId) async {
    return await _supabase
        .from('merchant_working_hours')
        .select()
        .eq('merchant_id', merchantId)
        .order('day_of_week');
  }

  Future<void> updateMerchantWorkingHours(String merchantId, List<Map<String, dynamic>> hours) async {
    for (final h in hours) {
      await _supabase.from('merchant_working_hours').upsert({
        'merchant_id': merchantId,
        'day_of_week': h['day_of_week'],
        'is_open': h['is_open'],
        'open_time': h['open_time'],
        'close_time': h['close_time'],
      });
    }
    await _audit.logBusinessAction(
      action: 'working_hours_update',
      businessId: merchantId,
      businessType: 'merchant',
      newData: {'hours_count': hours.length},
    );
  }

  // ─── Reviews ───

  Future<List<Map<String, dynamic>>> getMerchantReviews(String merchantId, {String? statusFilter}) async {
    if (statusFilter == 'replied') {
      return await _supabase
          .from('reviews')
          .select()
          .eq('merchant_id', merchantId)
          .not('merchant_reply', 'is', null)
          .order('created_at', ascending: false)
          .limit(100);
    } else if (statusFilter == 'unreplied') {
      return await _supabase
          .from('reviews')
          .select()
          .eq('merchant_id', merchantId)
          .isFilter('merchant_reply', null)
          .order('created_at', ascending: false)
          .limit(100);
    }
    return await _supabase
        .from('reviews')
        .select()
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false)
        .limit(100);
  }

  Future<void> replyToReview(String reviewId, String replyText, {String? merchantId}) async {
    await _supabase.from('reviews').update({
      'merchant_reply': replyText,
      'replied_at': DateTime.now().toIso8601String(),
    }).eq('id', reviewId);

    await _audit.logBusinessAction(
      action: 'review_reply',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      newData: {'reply': replyText},
    );
  }

  // ─── Order Detail & Management ───

  Future<Map<String, dynamic>?> getOrderWithDetails(String orderId) async {
    return await _supabase
        .from('orders')
        .select('*, couriers(id, full_name, phone, vehicle_type, vehicle_plate, is_online, is_busy)')
        .eq('id', orderId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getOrderMessages(String orderId) async {
    return await _supabase
        .from('order_messages')
        .select()
        .eq('order_id', orderId)
        .order('created_at');
  }

  Future<void> sendOrderMessage(String orderId, String merchantId, String message) async {
    await _supabase.from('order_messages').insert({
      'order_id': orderId,
      'merchant_id': merchantId,
      'sender_type': 'support',
      'sender_name': 'Destek (işletme adına)',
      'message': message,
    });
    await _audit.logBusinessAction(
      action: 'order_message_send',
      businessId: merchantId,
      businessType: 'merchant',
      newData: {'order_id': orderId, 'message': message},
    );
  }

  Future<void> rejectOrder(String orderId, String reason, {String? merchantId}) async {
    await _supabase.from('orders').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'cancelled_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);

    await _audit.logBusinessAction(
      action: 'order_reject',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      newData: {'status': 'cancelled', 'reason': reason},
    );
  }

  Future<void> assignCourierToOrder(String orderId, String courierId, {String? merchantId}) async {
    await _supabase.from('orders').update({
      'courier_id': courierId,
      'courier_assigned_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);

    await _audit.logBusinessAction(
      action: 'order_courier_assign',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      newData: {'order_id': orderId, 'courier_id': courierId},
    );
  }

  // ─── Finance ───

  Future<Map<String, dynamic>> getMerchantFinance(String merchantId, DateTime startDate, DateTime endDate) async {
    final orders = await _supabase
        .from('orders')
        .select('id, order_number, total_amount, status, payment_method, commission_rate, created_at')
        .eq('merchant_id', merchantId)
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String())
        .order('created_at', ascending: false);

    double totalRevenue = 0;
    double totalCommission = 0;
    double cashRevenue = 0;
    double cardRevenue = 0;
    int completedOrders = 0;
    int cancelledOrders = 0;

    for (final o in orders) {
      final status = o['status'] ?? '';
      if (status == 'cancelled') {
        cancelledOrders++;
        continue;
      }
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      final commissionRate = (o['commission_rate'] as num?)?.toDouble() ?? 15;
      totalRevenue += amount;
      totalCommission += amount * (commissionRate / 100);
      completedOrders++;

      final method = o['payment_method'] ?? 'card';
      if (method == 'cash') {
        cashRevenue += amount;
      } else {
        cardRevenue += amount;
      }
    }

    return {
      'total_revenue': totalRevenue,
      'total_commission': totalCommission,
      'net_revenue': totalRevenue - totalCommission,
      'cash_revenue': cashRevenue,
      'card_revenue': cardRevenue,
      'completed_orders': completedOrders,
      'cancelled_orders': cancelledOrders,
      'transactions': orders,
    };
  }

  // ─── Couriers ───

  Future<List<Map<String, dynamic>>> getMerchantCouriers(String merchantId) async {
    return await _supabase
        .from('couriers')
        .select('id, full_name, phone, vehicle_type, vehicle_plate, status, is_online, is_busy, current_order_id, rating, total_deliveries')
        .eq('merchant_id', merchantId)
        .order('full_name');
  }

  // ─── Merchant Settings ───

  Future<Map<String, dynamic>?> getMerchantSettings(String merchantId) async {
    return await _supabase
        .from('merchant_settings')
        .select()
        .eq('merchant_id', merchantId)
        .maybeSingle();
  }

  Future<void> updateMerchantSettings(String merchantId, Map<String, dynamic> data) async {
    final existing = await getMerchantSettings(merchantId);
    if (existing != null) {
      await _supabase.from('merchant_settings').update({
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('merchant_id', merchantId);
    } else {
      await _supabase.from('merchant_settings').insert({
        'merchant_id': merchantId,
        ...data,
      });
    }

    await _audit.logBusinessAction(
      action: 'merchant_settings_update',
      businessId: merchantId,
      businessType: 'merchant',
      newData: data,
    );
  }

  Future<void> updateMerchantInfo(String merchantId, Map<String, dynamic> data) async {
    final old = await _supabase.from('merchants').select('business_name, phone, email').eq('id', merchantId).single();
    await _supabase.from('merchants').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', merchantId);

    await _audit.logBusinessAction(
      action: 'merchant_info_update',
      businessId: merchantId,
      businessType: 'merchant',
      oldData: old,
      newData: data,
    );
  }

  // ─── Bulk Stock Update ───

  Future<void> bulkUpdateStock(List<Map<String, dynamic>> updates, {String? merchantId}) async {
    for (final u in updates) {
      await _supabase.from('store_products').update({
        'stock': u['stock'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', u['id']);
    }

    await _audit.logBusinessAction(
      action: 'bulk_stock_update',
      businessId: merchantId ?? '',
      businessType: 'merchant',
      newData: {'updated_count': updates.length},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ─── Rental Operations ───
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> searchRentalCompanies(String query) async {
    try {
      return await _supabase
          .from('rental_companies')
          .select('id, name, phone, email, status, logo_url')
          .or('name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
          .limit(20);
    } catch (e) {
      if (kDebugMode) print('Error searching rental companies: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRentalBookings(String companyId, {int limit = 50}) async {
    return await _supabase
        .from('rental_bookings')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus, {String? companyId}) async {
    final old = await _supabase.from('rental_bookings').select('status').eq('id', bookingId).single();
    await _supabase.from('rental_bookings').update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);

    await _audit.logBusinessAction(
      action: 'booking_status_change',
      businessId: companyId ?? '',
      businessType: 'rental',
      oldData: {'status': old['status']},
      newData: {'status': newStatus},
    );
  }

  Future<List<Map<String, dynamic>>> getRentalVehicles(String companyId) async {
    return await _supabase
        .from('rental_cars')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
  }

  // ─── Rental Vehicle CRUD ───

  Future<Map<String, dynamic>> createRentalVehicle(String companyId, Map<String, dynamic> data) async {
    final result = await _supabase.from('rental_cars').insert({
      'company_id': companyId,
      ...data,
    }).select().single();

    await _audit.logBusinessAction(
      action: 'rental_vehicle_create',
      businessId: companyId,
      businessType: 'rental',
      newData: data,
    );
    return result;
  }

  Future<void> updateRentalVehicleFull(String vehicleId, Map<String, dynamic> data, {String? companyId}) async {
    final old = await _supabase.from('rental_cars').select().eq('id', vehicleId).single();
    await _supabase.from('rental_cars').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', vehicleId);

    await _audit.logBusinessAction(
      action: 'rental_vehicle_update',
      businessId: companyId ?? old['company_id'] ?? '',
      businessType: 'rental',
      oldData: {'brand': old['brand'], 'model': old['model']},
      newData: data,
    );
  }

  Future<void> deleteRentalVehicle(String vehicleId, {String? companyId}) async {
    final old = await _supabase.from('rental_cars').select('brand, model, company_id').eq('id', vehicleId).single();
    await _supabase.from('rental_cars').delete().eq('id', vehicleId);

    await _audit.logBusinessAction(
      action: 'rental_vehicle_delete',
      businessId: companyId ?? old['company_id'] ?? '',
      businessType: 'rental',
      oldData: {'brand': old['brand'], 'model': old['model']},
    );
  }

  // ─── Rental Booking CRUD ───

  Future<Map<String, dynamic>> createManualBooking(String companyId, Map<String, dynamic> data) async {
    final result = await _supabase.from('rental_bookings').insert({
      'company_id': companyId,
      ...data,
      'status': 'pending',
    }).select().single();

    await _audit.logBusinessAction(
      action: 'booking_create',
      businessId: companyId,
      businessType: 'rental',
      newData: data,
    );
    return result;
  }

  Future<void> updateBookingFull(String bookingId, Map<String, dynamic> data, {String? companyId}) async {
    await _supabase.from('rental_bookings').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);

    await _audit.logBusinessAction(
      action: 'booking_update',
      businessId: companyId ?? '',
      businessType: 'rental',
      newData: data,
    );
  }

  Future<void> cancelBooking(String bookingId, String reason, {String? companyId}) async {
    await _supabase.from('rental_bookings').update({
      'status': 'cancelled',
      'cancel_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);

    await _audit.logBusinessAction(
      action: 'booking_cancel',
      businessId: companyId ?? '',
      businessType: 'rental',
      newData: {'status': 'cancelled', 'reason': reason},
    );
  }

  // ─── Rental Locations ───

  Future<List<Map<String, dynamic>>> getRentalLocations(String companyId) async {
    return await _supabase
        .from('rental_locations')
        .select()
        .eq('company_id', companyId)
        .order('name');
  }

  Future<Map<String, dynamic>> createRentalLocation(String companyId, Map<String, dynamic> data) async {
    final result = await _supabase.from('rental_locations').insert({
      'company_id': companyId,
      ...data,
    }).select().single();

    await _audit.logBusinessAction(
      action: 'rental_location_create',
      businessId: companyId,
      businessType: 'rental',
      newData: data,
    );
    return result;
  }

  Future<void> updateRentalLocation(String locationId, Map<String, dynamic> data, {String? companyId}) async {
    await _supabase.from('rental_locations').update(data).eq('id', locationId);
    await _audit.logBusinessAction(
      action: 'rental_location_update',
      businessId: companyId ?? '',
      businessType: 'rental',
      newData: data,
    );
  }

  Future<void> deleteRentalLocation(String locationId, {String? companyId}) async {
    await _supabase.from('rental_locations').delete().eq('id', locationId);
    await _audit.logBusinessAction(
      action: 'rental_location_delete',
      businessId: companyId ?? '',
      businessType: 'rental',
    );
  }

  Future<void> toggleLocationActive(String locationId, bool isActive, {String? companyId}) async {
    await _supabase.from('rental_locations').update({'is_active': isActive}).eq('id', locationId);
    await _audit.logBusinessAction(
      action: 'rental_location_toggle',
      businessId: companyId ?? '',
      businessType: 'rental',
      newData: {'is_active': isActive},
    );
  }

  // ─── Rental Packages ───

  Future<List<Map<String, dynamic>>> getRentalPackages(String companyId) async {
    return await _supabase
        .from('rental_packages')
        .select()
        .eq('company_id', companyId)
        .order('name');
  }

  Future<void> updateRentalPackage(String packageId, Map<String, dynamic> data, {String? companyId}) async {
    await _supabase.from('rental_packages').update(data).eq('id', packageId);
    await _audit.logBusinessAction(
      action: 'rental_package_update',
      businessId: companyId ?? '',
      businessType: 'rental',
      newData: data,
    );
  }

  Future<void> togglePackageActive(String packageId, bool isActive, {String? companyId}) async {
    await _supabase.from('rental_packages').update({'is_active': isActive}).eq('id', packageId);
    await _audit.logBusinessAction(
      action: 'rental_package_toggle',
      businessId: companyId ?? '',
      businessType: 'rental',
      newData: {'is_active': isActive},
    );
  }

  // ─── Rental Additional Services ───

  Future<List<Map<String, dynamic>>> getRentalServices(String companyId) async {
    return await _supabase
        .from('rental_services')
        .select()
        .eq('company_id', companyId)
        .order('name');
  }

  Future<Map<String, dynamic>> createRentalService(String companyId, Map<String, dynamic> data) async {
    final result = await _supabase.from('rental_services').insert({
      'company_id': companyId,
      ...data,
    }).select().single();

    await _audit.logBusinessAction(
      action: 'rental_service_create',
      businessId: companyId,
      businessType: 'rental',
      newData: data,
    );
    return result;
  }

  Future<void> updateRentalService(String serviceId, Map<String, dynamic> data, {String? companyId}) async {
    await _supabase.from('rental_services').update(data).eq('id', serviceId);
    await _audit.logBusinessAction(
      action: 'rental_service_update',
      businessId: companyId ?? '',
      businessType: 'rental',
      newData: data,
    );
  }

  Future<void> deleteRentalService(String serviceId, {String? companyId}) async {
    await _supabase.from('rental_services').delete().eq('id', serviceId);
    await _audit.logBusinessAction(
      action: 'rental_service_delete',
      businessId: companyId ?? '',
      businessType: 'rental',
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ─── Emlak Operations ───
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> searchRealtors(String query) async {
    try {
      return await _supabase
          .from('realtors')
          .select('id, full_name, company_name, phone, email, status')
          .or('full_name.ilike.%$query%,company_name.ilike.%$query%,phone.ilike.%$query%')
          .limit(20);
    } catch (e) {
      if (kDebugMode) print('Error searching realtors: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProperties(String realtorId) async {
    return await _supabase
        .from('properties')
        .select()
        .eq('user_id', realtorId)
        .order('created_at', ascending: false);
  }

  Future<void> updatePropertyStatus(String propertyId, String newStatus, {String? realtorId}) async {
    final old = await _supabase.from('properties').select('status').eq('id', propertyId).single();
    await _supabase.from('properties').update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', propertyId);

    await _audit.logBusinessAction(
      action: 'property_status_change',
      businessId: realtorId ?? '',
      businessType: 'emlak',
      oldData: {'status': old['status']},
      newData: {'status': newStatus},
    );
  }

  // ─── Property CRUD ───

  Future<Map<String, dynamic>> createProperty(String realtorId, Map<String, dynamic> data) async {
    final result = await _supabase.from('properties').insert({
      'user_id': realtorId,
      ...data,
      'status': 'active',
    }).select().single();

    await _audit.logBusinessAction(
      action: 'property_create',
      businessId: realtorId,
      businessType: 'emlak',
      newData: data,
    );
    return result;
  }

  Future<void> updatePropertyFull(String propertyId, Map<String, dynamic> data, {String? realtorId}) async {
    final old = await _supabase.from('properties').select('title, price').eq('id', propertyId).single();
    await _supabase.from('properties').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', propertyId);

    await _audit.logBusinessAction(
      action: 'property_update',
      businessId: realtorId ?? '',
      businessType: 'emlak',
      oldData: {'title': old['title'], 'price': old['price']},
      newData: data,
    );
  }

  Future<void> deleteProperty(String propertyId, {String? realtorId}) async {
    final old = await _supabase.from('properties').select('title').eq('id', propertyId).single();
    await _supabase.from('properties').delete().eq('id', propertyId);

    await _audit.logBusinessAction(
      action: 'property_delete',
      businessId: realtorId ?? '',
      businessType: 'emlak',
      oldData: {'title': old['title']},
    );
  }

  // ─── Property Appointments ───

  Future<List<Map<String, dynamic>>> getPropertyAppointments(String realtorId) async {
    return await _supabase
        .from('appointments')
        .select('*, properties(title)')
        .eq('realtor_id', realtorId)
        .order('appointment_date', ascending: false);
  }

  Future<void> confirmAppointment(String appointmentId, {String? responseNote, String? realtorId}) async {
    await _supabase.from('appointments').update({
      'status': 'confirmed',
      'response_note': responseNote,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', appointmentId);

    await _audit.logBusinessAction(
      action: 'appointment_confirm',
      businessId: realtorId ?? '',
      businessType: 'emlak',
      newData: {'status': 'confirmed', 'note': responseNote},
    );
  }

  Future<void> cancelAppointment(String appointmentId, {String? reason, String? realtorId}) async {
    await _supabase.from('appointments').update({
      'status': 'cancelled',
      'cancel_reason': reason,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', appointmentId);

    await _audit.logBusinessAction(
      action: 'appointment_cancel',
      businessId: realtorId ?? '',
      businessType: 'emlak',
      newData: {'status': 'cancelled', 'reason': reason},
    );
  }

  Future<void> completeAppointment(String appointmentId, {String? realtorId}) async {
    await _supabase.from('appointments').update({
      'status': 'completed',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', appointmentId);

    await _audit.logBusinessAction(
      action: 'appointment_complete',
      businessId: realtorId ?? '',
      businessType: 'emlak',
      newData: {'status': 'completed'},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ─── Car Sales Operations ───
  // ═══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> searchDealers(String query) async {
    try {
      return await _supabase
          .from('car_dealers')
          .select('id, name, phone, email, status, logo_url')
          .or('name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
          .limit(20);
    } catch (e) {
      if (kDebugMode) print('Error searching dealers: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCarListings(String dealerId) async {
    return await _supabase
        .from('car_listings')
        .select()
        .eq('dealer_id', dealerId)
        .order('created_at', ascending: false);
  }

  Future<void> updateCarListingStatus(String listingId, String newStatus, {String? dealerId}) async {
    final old = await _supabase.from('car_listings').select('status').eq('id', listingId).single();
    await _supabase.from('car_listings').update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', listingId);

    await _audit.logBusinessAction(
      action: 'car_listing_status_change',
      businessId: dealerId ?? '',
      businessType: 'car_sales',
      oldData: {'status': old['status']},
      newData: {'status': newStatus},
    );
  }

  // ─── Car Listing CRUD ───

  Future<Map<String, dynamic>> createCarListing(String dealerId, Map<String, dynamic> data) async {
    final result = await _supabase.from('car_listings').insert({
      'dealer_id': dealerId,
      ...data,
      'status': 'active',
    }).select().single();

    await _audit.logBusinessAction(
      action: 'car_listing_create',
      businessId: dealerId,
      businessType: 'car_sales',
      newData: data,
    );
    return result;
  }

  Future<void> updateCarListingFull(String listingId, Map<String, dynamic> data, {String? dealerId}) async {
    final old = await _supabase.from('car_listings').select('brand, model, price').eq('id', listingId).single();
    await _supabase.from('car_listings').update({
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', listingId);

    await _audit.logBusinessAction(
      action: 'car_listing_update',
      businessId: dealerId ?? '',
      businessType: 'car_sales',
      oldData: {'brand': old['brand'], 'model': old['model'], 'price': old['price']},
      newData: data,
    );
  }

  Future<void> deleteCarListing(String listingId, {String? dealerId}) async {
    final old = await _supabase.from('car_listings').select('brand, model').eq('id', listingId).single();
    await _supabase.from('car_listings').delete().eq('id', listingId);

    await _audit.logBusinessAction(
      action: 'car_listing_delete',
      businessId: dealerId ?? '',
      businessType: 'car_sales',
      oldData: {'brand': old['brand'], 'model': old['model']},
    );
  }

  Future<List<Map<String, dynamic>>> getCarBrands() async {
    try {
      return await _supabase.from('car_brands').select().order('name');
    } catch (e) {
      return [];
    }
  }

  // ─── Car Contact Requests ───

  Future<List<Map<String, dynamic>>> getContactRequests(String dealerId) async {
    return await _supabase
        .from('car_contact_requests')
        .select('*, car_listings(brand, model, year)')
        .eq('dealer_id', dealerId)
        .order('created_at', ascending: false);
  }

  Future<void> updateContactRequestStatus(String requestId, String status, {String? notes, String? dealerId}) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (notes != null) updates['notes'] = notes;

    await _supabase.from('car_contact_requests').update(updates).eq('id', requestId);

    await _audit.logBusinessAction(
      action: 'contact_request_update',
      businessId: dealerId ?? '',
      businessType: 'car_sales',
      newData: updates,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ─── Taxi/Courier View-only Operations ───
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getTaxiRideById(String rideId) async {
    return await _supabase.from('taxi_rides').select().eq('id', rideId).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getTaxiRides(String driverId, {int limit = 50}) async {
    return await _supabase
        .from('taxi_rides')
        .select()
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<Map<String, dynamic>?> getTaxiDriverById(String driverId) async {
    return await _supabase.from('taxi_drivers').select().eq('id', driverId).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> searchTaxiDrivers(String query) async {
    try {
      return await _supabase
          .from('taxi_drivers')
          .select('id, full_name, phone, email, status, vehicle_plate, rating')
          .or('full_name.ilike.%$query%,phone.ilike.%$query%,vehicle_plate.ilike.%$query%')
          .limit(20);
    } catch (e) {
      if (kDebugMode) print('Error searching taxi drivers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getOrderWithCourier(String orderId) async {
    return await _supabase
        .from('orders')
        .select('*, couriers(full_name, phone, status)')
        .eq('id', orderId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getCourierDeliveries(String courierId, {int limit = 50}) async {
    return await _supabase
        .from('orders')
        .select()
        .eq('courier_id', courierId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<Map<String, dynamic>?> getCourierById(String courierId) async {
    return await _supabase.from('couriers').select().eq('id', courierId).maybeSingle();
  }

  Future<List<Map<String, dynamic>>> searchCouriers(String query) async {
    try {
      return await _supabase
          .from('couriers')
          .select('id, full_name, phone, email, status, work_mode, rating')
          .or('full_name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
          .limit(20);
    } catch (e) {
      if (kDebugMode) print('Error searching couriers: $e');
      return [];
    }
  }
}
