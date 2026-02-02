import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class CourierService {
  // Kurye bilgilerini getir
  static Future<Map<String, dynamic>?> getCourierProfile() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await SupabaseService.client
          .from('couriers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('getCourierProfile error: $e');
      return null;
    }
  }

  // Kurye kaydı oluştur
  static Future<bool> createCourierProfile({
    required String fullName,
    required String phone,
    required String tcNo,
    required String vehicleType,
    required String vehiclePlate,
    String? bankName,
    String? bankIban,
    String workMode = 'platform',
    String? merchantId, // Artık sadece istek gönderilecek restoran ID'si
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      // Kurye profilini oluştur (merchant_id olmadan)
      final response = await SupabaseService.client.from('couriers').insert({
        'user_id': userId,
        'full_name': fullName,
        'phone': phone,
        'tc_no': tcNo,
        'vehicle_type': vehicleType,
        'vehicle_plate': vehiclePlate,
        'bank_name': bankName,
        'bank_iban': bankIban,
        'work_mode': workMode,
        'merchant_id': null, // Restoran onaylayana kadar null
        'status': 'pending', // Admin onayı bekliyor
        'is_online': false,
        'rating': 5.0,
        'total_deliveries': 0,
        'total_earnings': 0,
      }).select('id').single();

      // Eğer restoran seçildiyse bağlantı isteği gönder
      if (merchantId != null && response['id'] != null) {
        await sendMerchantConnectionRequest(
          courierId: response['id'],
          merchantId: merchantId,
        );
      }

      return true;
    } catch (e) {
      debugPrint('createCourierProfile error: $e');
      return false;
    }
  }

  // Restorana bağlantı isteği gönder
  static Future<bool> sendMerchantConnectionRequest({
    required String courierId,
    required String merchantId,
    String? message,
  }) async {
    try {
      await SupabaseService.client.from('merchant_courier_requests').insert({
        'courier_id': courierId,
        'merchant_id': merchantId,
        'status': 'pending',
        'message': message,
      });
      return true;
    } catch (e) {
      debugPrint('sendMerchantConnectionRequest error: $e');
      return false;
    }
  }

  // Kurye'nin restoran bağlantı isteklerini getir
  static Future<List<Map<String, dynamic>>> getMerchantConnectionRequests() async {
    final courier = await getCourierProfile();
    if (courier == null) return [];

    try {
      final response = await SupabaseService.client
          .from('merchant_courier_requests')
          .select('*, merchants(id, business_name, logo_url, address)')
          .eq('courier_id', courier['id'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getMerchantConnectionRequests error: $e');
      return [];
    }
  }

  // Profil güncelle
  static Future<bool> updateProfile({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('couriers')
          .update({
            'full_name': fullName,
            'email': email,
            'phone': phone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('updateProfile error: $e');
      return false;
    }
  }

  // Araç bilgilerini güncelle
  static Future<bool> updateVehicleInfo({
    required String vehicleType,
    required String vehiclePlate,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('couriers')
          .update({
            'vehicle_type': vehicleType,
            'vehicle_plate': vehiclePlate,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('updateVehicleInfo error: $e');
      return false;
    }
  }

  // Ödeme bilgilerini güncelle
  static Future<bool> updatePaymentInfo({
    required String bankName,
    required String bankIban,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('couriers')
          .update({
            'bank_name': bankName,
            'bank_iban': bankIban,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('updatePaymentInfo error: $e');
      return false;
    }
  }

  // Bildirim ayarlarını güncelle
  static Future<bool> updateNotificationSettings({
    required bool newOrders,
    required bool orderUpdates,
    required bool promotions,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('couriers')
          .update({
            'notification_new_orders': newOrders,
            'notification_order_updates': orderUpdates,
            'notification_promotions': promotions,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('updateNotificationSettings error: $e');
      return false;
    }
  }

  // Online/Offline durumunu güncelle
  static Future<bool> updateOnlineStatus(bool isOnline) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('couriers')
          .update({
            'is_online': isOnline,
            'last_online_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('updateOnlineStatus error: $e');
      return false;
    }
  }

  // Kurye lokasyonunu güncelle
  static Future<bool> updateLocation(double latitude, double longitude) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('couriers')
          .update({
            'current_latitude': latitude,
            'current_longitude': longitude,
            'location_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('updateLocation error: $e');
      return false;
    }
  }

  // Bekleyen siparişleri getir (work_mode'a göre filtrelenmiş)
  static Future<List<Map<String, dynamic>>> getPendingOrders() async {
    try {
      // Önce kurye profilini al (work_mode ve merchant_id için)
      final courier = await getCourierProfile();
      if (courier == null) return [];

      final workMode = courier['work_mode'] as String? ?? 'both';
      final merchantId = courier['merchant_id'] as String?;

      // Temel sorgu
      var query = SupabaseService.client
          .from('orders')
          .select('*, merchants(business_name, address, logo_url)')
          .eq('status', 'ready') // Hazır siparişler
          .isFilter('courier_id', null); // Henüz kurye atanmamış

      // Work mode'a göre filtrele
      if (workMode == 'restaurant') {
        // Sadece bağlı olduğu restoranın siparişleri
        if (merchantId == null) {
          return []; // Restorana bağlı değilse sipariş göremez
        }
        query = query.eq('merchant_id', merchantId);
      } else if (workMode == 'platform') {
        // Sadece bağlı olmadığı restoranların siparişleri (platform siparişleri)
        if (merchantId != null) {
          query = query.neq('merchant_id', merchantId);
        }
        // merchantId null ise tüm siparişleri görebilir
      }
      // workMode == 'both' ise filtre yok, tüm siparişleri görebilir

      final response = await query.order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getPendingOrders error: $e');
      return [];
    }
  }

  // Aktif siparişleri getir (kuryenin üzerindeki)
  static Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    try {
      // Önce courier_id'yi al
      final courier = await getCourierProfile();
      if (courier == null) return [];

      final response = await SupabaseService.client
          .from('orders')
          .select('*, merchants(business_name, address, logo_url, phone)')
          .eq('courier_id', courier['id'])
          .inFilter('status', ['picked_up', 'delivering'])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getActiveOrders error: $e');
      return [];
    }
  }

  // Siparişi teslim edildi olarak işaretle
  static Future<bool> completeDelivery(String orderId) async {
    try {
      await SupabaseService.client.from('orders').update({
        'status': 'delivered',
        'delivery_status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Kurye istatistiklerini güncelle ve müsait yap
      final courier = await getCourierProfile();
      if (courier != null) {
        await SupabaseService.client.from('couriers').update({
          'total_deliveries': (courier['total_deliveries'] ?? 0) + 1,
          'is_busy': false,
          'current_order_id': null,
        }).eq('id', courier['id']);
      }

      return true;
    } catch (e) {
      debugPrint('completeDelivery error: $e');
      return false;
    }
  }

  // Tamamlanan siparişleri getir (geçmiş)
  static Future<List<Map<String, dynamic>>> getCompletedOrders({
    int limit = 20,
    int offset = 0,
  }) async {
    final courier = await getCourierProfile();
    if (courier == null) return [];

    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('*, merchants(business_name, logo_url)')
          .eq('courier_id', courier['id'])
          .eq('status', 'delivered')
          .order('delivered_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getCompletedOrders error: $e');
      return [];
    }
  }

  // Sipariş detayını getir
  static Future<Map<String, dynamic>?> getOrderDetail(String orderId) async {
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('''
            *,
            merchants(business_name, address, phone, latitude, longitude, logo_url)
          ''')
          .eq('id', orderId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('getOrderDetail error: $e');
      return null;
    }
  }

  // Sipariş durumunu güncelle
  static Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
      };

      // Duruma göre zaman damgası ekle
      switch (status) {
        case 'picked_up':
          updateData['picked_up_at'] = DateTime.now().toIso8601String();
          break;
        case 'delivering':
          // delivering_at sütunu yok, sadece status güncellenir
          break;
        case 'delivered':
          updateData['delivered_at'] = DateTime.now().toIso8601String();
          updateData['delivery_status'] = 'delivered';
          // Kurye istatistiklerini güncelle ve müsait yap
          final courier = await getCourierProfile();
          if (courier != null) {
            // Sipariş ücretini al
            final order = await getOrderDetail(orderId);
            final deliveryFee = (order?['delivery_fee'] as num?)?.toDouble() ?? 0;

            await SupabaseService.client.from('couriers').update({
              'total_deliveries': (courier['total_deliveries'] ?? 0) + 1,
              'total_earnings': (courier['total_earnings'] ?? 0) + deliveryFee,
              'is_busy': false,  // Kurye artık müsait
              'current_order_id': null,  // Aktif sipariş yok
            }).eq('id', courier['id']);
          }
          break;
      }

      await SupabaseService.client
          .from('orders')
          .update(updateData)
          .eq('id', orderId);

      return true;
    } catch (e) {
      debugPrint('updateOrderStatus error: $e');
      return false;
    }
  }

  // Kazanç geçmişi - sadece dış siparişler (kendi restoranı dışı)
  static Future<List<Map<String, dynamic>>> getEarningsHistory({int limit = 50}) async {
    final courier = await getCourierProfile();
    if (courier == null) return [];

    try {
      final merchantId = courier['merchant_id'] as String?;

      // Temel sorgu
      var query = SupabaseService.client
          .from('orders')
          .select('id, order_number, delivery_fee, delivered_at, created_at, merchant_id')
          .eq('courier_id', courier['id'])
          .eq('status', 'delivered');

      // Kurye bir restorana bağlıysa, sadece DIŞ siparişleri göster
      // (kendi restoranından kazanç almaz, maaşlı çalışıyor)
      if (merchantId != null) {
        query = query.neq('merchant_id', merchantId);
      }

      final response = await query
          .order('delivered_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response).map((order) {
        return {
          'order_number': order['order_number'],
          'amount': order['delivery_fee'],
          'created_at': order['delivered_at'] ?? order['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('getEarningsHistory error: $e');
      return [];
    }
  }

  // Çalışma modunu güncelle
  static Future<bool> updateWorkMode(String workMode) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      await SupabaseService.client
          .from('couriers')
          .update({
            'work_mode': workMode,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('updateWorkMode error: $e');
      return false;
    }
  }

  // Sipariş teklifini kabul et - sipariş detaylarını da döndürür
  static Future<Map<String, dynamic>?> acceptCourierRequest(String requestId) async {
    final courier = await getCourierProfile();
    if (courier == null) return null;

    try {
      // RPC fonksiyonu kullan - atomic işlem ve RLS bypass
      final result = await SupabaseService.client
          .rpc('accept_courier_request', params: {
            'p_request_id': requestId,
            'p_courier_id': courier['id'],
          });

      if (result == null) return null;

      final success = result['success'] as bool? ?? false;
      if (!success) {
        debugPrint('acceptCourierRequest failed: ${result['error']}');
        return null;
      }

      // Sipariş detaylarını döndür
      return result['order'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('acceptCourierRequest error: $e');
      return null;
    }
  }

  // Sipariş teklifini reddet
  static Future<bool> rejectCourierRequest(String requestId) async {
    try {
      await SupabaseService.client
          .from('courier_requests')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('rejectCourierRequest error: $e');
      return false;
    }
  }

  // Kazanç özeti - sadece dış siparişler (kendi restoranı dışı)
  static Future<Map<String, dynamic>> getEarningsSummary() async {
    final courier = await getCourierProfile();
    if (courier == null) {
      return {
        'today': 0.0,
        'week': 0.0,
        'month': 0.0,
        'total': 0.0,
        'total_deliveries': 0,
        'avg_rating': 0.0,
        'avg_delivery_time': 0,
      };
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      final merchantId = courier['merchant_id'] as String?;

      // Bugünkü kazanç - sadece dış siparişler
      var todayQuery = SupabaseService.client
          .from('orders')
          .select('delivery_fee, merchant_id')
          .eq('courier_id', courier['id'])
          .eq('status', 'delivered')
          .gte('delivered_at', today.toIso8601String());
      if (merchantId != null) {
        todayQuery = todayQuery.neq('merchant_id', merchantId);
      }
      final todayOrders = await todayQuery;

      // Haftalık kazanç - sadece dış siparişler
      var weekQuery = SupabaseService.client
          .from('orders')
          .select('delivery_fee, merchant_id')
          .eq('courier_id', courier['id'])
          .eq('status', 'delivered')
          .gte('delivered_at', weekStart.toIso8601String());
      if (merchantId != null) {
        weekQuery = weekQuery.neq('merchant_id', merchantId);
      }
      final weekOrders = await weekQuery;

      // Aylık kazanç ve istatistikler - sadece dış siparişler
      var monthQuery = SupabaseService.client
          .from('orders')
          .select('delivery_fee, merchant_id')
          .eq('courier_id', courier['id'])
          .eq('status', 'delivered')
          .gte('delivered_at', monthStart.toIso8601String());
      if (merchantId != null) {
        monthQuery = monthQuery.neq('merchant_id', merchantId);
      }
      final monthOrders = await monthQuery;

      double calculateTotal(List<dynamic> orders) {
        return orders.fold<double>(0, (sum, order) {
          final fee = order['delivery_fee'];
          return sum + (fee is num ? fee.toDouble() : 0.0);
        });
      }

      return {
        'today': calculateTotal(todayOrders),
        'week': calculateTotal(weekOrders),
        'month': calculateTotal(monthOrders),
        'total': (courier['total_earnings'] as num?)?.toDouble() ?? 0.0,
        'total_deliveries': monthOrders.length, // Bu ay kaç dış teslimat yaptı
        'avg_rating': (courier['avg_rating'] as num?)?.toDouble() ?? 0.0,
        'avg_delivery_time': courier['avg_delivery_time'] as int? ?? 0,
      };
    } catch (e) {
      debugPrint('getEarningsSummary error: $e');
      return {
        'today': 0.0,
        'week': 0.0,
        'month': 0.0,
        'total': 0.0,
        'total_deliveries': 0,
        'avg_rating': 0.0,
        'avg_delivery_time': 0,
      };
    }
  }
}
