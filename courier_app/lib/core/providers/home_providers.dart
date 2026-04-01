import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/courier_service.dart';
import '../services/log_service.dart';
import '../services/push_notification_service.dart';

// Work Mode enum
enum WorkMode { platform, restaurant, both }

// Kurye verisi state class
class CourierDataState {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> assignedOrders;
  final List<Map<String, dynamic>> pendingOrders;
  final List<Map<String, dynamic>> activeOrders;
  final List<Map<String, dynamic>> courierRequests;
  final bool isLoading;

  const CourierDataState({
    this.profile,
    this.assignedOrders = const [],
    this.pendingOrders = const [],
    this.activeOrders = const [],
    this.courierRequests = const [],
    this.isLoading = true,
  });

  bool get isOnline => profile?['is_online'] == true;

  WorkMode get workMode {
    final mode = profile?['work_mode'] as String?;
    switch (mode) {
      case 'platform':
        return WorkMode.platform;
      case 'restaurant':
        return WorkMode.restaurant;
      case 'both':
      default:
        return WorkMode.both;
    }
  }

  CourierDataState copyWith({
    Map<String, dynamic>? profile,
    List<Map<String, dynamic>>? assignedOrders,
    List<Map<String, dynamic>>? pendingOrders,
    List<Map<String, dynamic>>? activeOrders,
    List<Map<String, dynamic>>? courierRequests,
    bool? isLoading,
  }) {
    return CourierDataState(
      profile: profile ?? this.profile,
      assignedOrders: assignedOrders ?? this.assignedOrders,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      activeOrders: activeOrders ?? this.activeOrders,
      courierRequests: courierRequests ?? this.courierRequests,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Tek bir ana profil provider - tüm kurye verilerini yönetir
final courierDataProvider = NotifierProvider<CourierDataNotifier, CourierDataState>(
  CourierDataNotifier.new,
);

class CourierDataNotifier extends Notifier<CourierDataState> {
  RealtimeChannel? _profileChannel;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _requestsChannel;
  String? _courierId;
  Timer? _refreshTimer;
  Timer? _requestsRefreshTimer;

  @override
  CourierDataState build() {
    // Cleanup on dispose
    ref.onDispose(() {
      _profileChannel?.unsubscribe();
      _ordersChannel?.unsubscribe();
      _requestsChannel?.unsubscribe();
      _refreshTimer?.cancel();
      _requestsRefreshTimer?.cancel();
    });

    // Initialize
    _init();
    return const CourierDataState();
  }

  Future<void> _init() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    // İlk veri yükleme
    await _loadAllData();

    // Profil değişikliklerini dinle
    _profileChannel = supabase.channel('profile_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'couriers',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => _loadProfile(),
      ).subscribe();

    // Sipariş ve request subscriptions'ı kur
    await _setupOrderSubscriptions();

    // Siparişler için periyodik yenileme (3 saniyede bir)
    // Realtime RLS limitasyonu nedeniyle polling gerekli
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (state.isOnline) {
        _loadOrders(); // Atanan siparişleri kontrol et
        _loadPendingOrders();
      }
    });

    // Courier requests için daha sık yenileme (5 saniyede bir)
    // Realtime çalışmasa bile teklifler hızlıca görünsün
    _requestsRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state.isOnline && _courierId != null) {
        _loadRequests();
      }
    });
  }

  // Y6+O8: async + await unsubscribe + sabit channel adı
  Future<void> _setupOrderSubscriptions() async {
    if (_courierId == null) return;
    final supabase = Supabase.instance.client;

    // Mevcut subscriptions'ı temizle (await ile)
    await _ordersChannel?.unsubscribe();
    await _requestsChannel?.unsubscribe();

    // Sipariş değişikliklerini dinle
    // NOT: courier_id filtresi kullanmıyoruz çünkü sipariş atandığında
    // eski değer NULL olduğu için filter çalışmıyor
    _ordersChannel = supabase.channel('orders_courier_$_courierId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (payload) {
          LogService.info('Realtime order event received: ${payload.eventType}', source: 'HomeProviders:_setupOrderSubscriptions');

          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;

          // String'e çevirerek karşılaştır (tip uyumsuzluğunu önle)
          final newCourierId = newRecord['courier_id']?.toString();
          final oldCourierId = oldRecord['courier_id']?.toString();
          final myCourierId = _courierId;

          LogService.info('Order courier check: new=$newCourierId, old=$oldCourierId, me=$myCourierId', source: 'HomeProviders:_setupOrderSubscriptions');

          // Bu kuryeyle ilgili bir değişiklik mi kontrol et
          if (newCourierId == myCourierId || oldCourierId == myCourierId) {
            LogService.info('Order change detected for this courier: ${newRecord['order_number']}', source: 'HomeProviders:_setupOrderSubscriptions');

            // Yeni sipariş atandıysa bildirim göster
            if (oldCourierId == null && newCourierId == myCourierId) {
              LogService.info('New order assigned to this courier!', source: 'HomeProviders:_setupOrderSubscriptions');
              _showOrderAssignedNotification(newRecord);
            }

            _loadOrders();
          }
        },
      ).subscribe((status, [error]) {
        LogService.info('Orders subscription status: $status, error: $error', source: 'HomeProviders:_setupOrderSubscriptions');
      });

    // Courier requests dinle - INSERT için özel kanal
    // O8: timestamp kaldırıldı, sabit channel adı kullanılıyor
    _requestsChannel = supabase.channel('requests_$_courierId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'courier_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'courier_id',
          value: _courierId,
        ),
        callback: (payload) {
          LogService.info('New courier request received: ${payload.newRecord}', source: 'HomeProviders:_setupOrderSubscriptions');
          _loadRequests();
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'courier_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'courier_id',
          value: _courierId,
        ),
        callback: (_) => _loadRequests(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'courier_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'courier_id',
          value: _courierId,
        ),
        callback: (_) => _loadRequests(),
      ).subscribe((status, [error]) {
        LogService.info('Courier requests subscription status: $status, error: $error', source: 'HomeProviders:_setupOrderSubscriptions');
      });
  }

  Future<void> _loadAllData() async {
    await _loadProfile();
    if (_courierId != null) {
      await Future.wait([
        _loadOrders(),
        _loadPendingOrders(),
        _loadRequests(),
      ]);
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadProfile() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await supabase
          .from('couriers')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      _courierId = profile?['id'] as String?;
      // Y2: PII guard — courier_id ve profil verisi (TC, IBAN, telefon içerir)
      if (kDebugMode) debugPrint('_loadProfile: courier_id = $_courierId');
      if (kDebugMode) debugPrint('_loadProfile: profile = $profile');
      state = state.copyWith(profile: profile);

      // Profile yüklendikten sonra subscriptions'ı kur
      if (_courierId != null) {
        await _setupOrderSubscriptions();
      }
    } catch (e, st) {
      LogService.error('Load profile error', error: e, stackTrace: st, source: 'HomeProviders:_loadProfile');
    }
  }

  Future<void> _loadOrders() async {
    if (_courierId == null) {
      LogService.info('_loadOrders: _courierId is null, skipping', source: 'HomeProviders:_loadOrders');
      return;
    }
    final supabase = Supabase.instance.client;

    try {
      // Y2: PII guard — courierId içeriyor
      if (kDebugMode) debugPrint('_loadOrders: Loading orders for courier $_courierId sorted by distance');

      // RPC ile mesafeye göre sıralı siparişleri al
      final sortedOrders = await supabase.rpc('get_courier_orders_by_distance', params: {
        'p_courier_id': _courierId,
      });

      // RPC sonucunu UI'ın beklediği formata dönüştür
      final assignedOrders = (sortedOrders as List).map((order) {
        return {
          'id': order['id'],
          'order_number': order['order_number'],
          'status': order['status'],
          'delivery_address': order['delivery_address'],
          'delivery_lat': order['delivery_latitude'],
          'delivery_lon': order['delivery_longitude'],
          'delivery_fee': order['delivery_fee'],
          'distance_km': order['distance_km'],
          'estimated_minutes': order['estimated_minutes'],
          'merchants': {
            'business_name': order['merchant_name'],
            'address': order['merchant_address'],
            'latitude': order['merchant_latitude'],
            'longitude': order['merchant_longitude'],
          },
        };
      }).toList();

      LogService.info('_loadOrders: Found ${assignedOrders.length} assigned orders (sorted by distance)', source: 'HomeProviders:_loadOrders');
      for (var order in assignedOrders) {
        // Y2: PII guard — sipariş numarası içeriyor
        if (kDebugMode) debugPrint('  - Order: ${order['order_number']} status: ${order['status']} distance: ${order['distance_km']} km');
      }

      // Active orders
      final activeOrders = await CourierService.getActiveOrders(_courierId!);
      LogService.info('_loadOrders: Found ${activeOrders.length} active orders', source: 'HomeProviders:_loadOrders');

      state = state.copyWith(
        assignedOrders: List<Map<String, dynamic>>.from(assignedOrders),
        activeOrders: activeOrders,
      );
    } catch (e, st) {
      LogService.error('Load orders error', error: e, stackTrace: st, source: 'HomeProviders:_loadOrders');
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      final pendingOrders = await CourierService.getPendingOrders();
      state = state.copyWith(pendingOrders: pendingOrders);
    } catch (e, st) {
      LogService.error('Load pending orders error', error: e, stackTrace: st, source: 'HomeProviders:_loadPendingOrders');
    }
  }

  Future<void> _loadRequests() async {
    if (_courierId == null) return;
    final supabase = Supabase.instance.client;

    try {
      // RPC fonksiyonu kullan - RLS sorununu bypass eder
      final response = await supabase
          .rpc('get_courier_pending_requests', params: {
            'p_courier_id': _courierId,
          });

      // Response'u uygun formata dönüştür
      final requests = (response as List).map((r) {
        return {
          'id': r['id'],
          'order_id': r['order_id'],
          'courier_id': r['courier_id'],
          'status': r['status'],
          'distance_km': r['distance_km'],
          'estimated_duration_min': r['estimated_duration_min'],
          'delivery_fee': r['delivery_fee'],
          'offered_at': r['offered_at'],
          'expires_at': r['expires_at'],
          'responded_at': r['responded_at'],
          'created_at': r['created_at'],
          'orders': r['order_data'],
          'merchants': r['merchant_data'],
        };
      }).toList();

      // orders içine merchants'ı da ekle (mevcut UI beklentisi için)
      for (var req in requests) {
        if (req['orders'] != null) {
          req['orders']['merchants'] = req['merchants'];
        }
      }

      state = state.copyWith(courierRequests: List<Map<String, dynamic>>.from(requests));
    } catch (e, st) {
      LogService.error('Load requests error', error: e, stackTrace: st, source: 'HomeProviders:_loadRequests');
    }
  }

  Future<void> refresh() async {
    await _loadAllData();
  }

  Future<void> refreshOrders() async {
    await Future.wait([
      _loadOrders(),
      _loadPendingOrders(),
    ]);
  }

  Future<void> refreshRequests() async {
    await _loadRequests();
  }

  /// Yeni sipariş atandığında local bildirim göster
  void _showOrderAssignedNotification(Map<String, dynamic> orderData) {
    final orderNumber = orderData['order_number'] as String? ?? '';
    final merchants = orderData['merchants'] as Map<String, dynamic>?;
    final merchantName = merchants?['business_name'] as String?;

    LogService.info('New order assigned: #$orderNumber from $merchantName', source: 'HomeProviders:_showOrderAssignedNotification');

    // Push notification service ile bildirim göster
    pushNotificationService.showOrderAssignedNotification(
      orderNumber: orderNumber,
      merchantName: merchantName,
    );
  }
}

// Eski provider'lar için uyumluluk (diğer ekranlar kullanıyor olabilir)
final courierProfileProvider = Provider<AsyncValue<Map<String, dynamic>?>>((ref) {
  final data = ref.watch(courierDataProvider);
  if (data.isLoading) return const AsyncValue.loading();
  return AsyncValue.data(data.profile);
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(courierDataProvider).isOnline;
});

final workModeProvider = Provider<WorkMode>((ref) {
  return ref.watch(courierDataProvider).workMode;
});

// Pending orders provider (uyumluluk için)
final pendingOrdersProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final data = ref.watch(courierDataProvider);
  if (data.isLoading) return const AsyncValue.loading();
  return AsyncValue.data(data.pendingOrders);
});

// Active orders provider (uyumluluk için)
final activeOrdersProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final data = ref.watch(courierDataProvider);
  if (data.isLoading) return const AsyncValue.loading();
  return AsyncValue.data(data.activeOrders);
});

// Assigned orders provider (uyumluluk için)
final assignedOrdersProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final data = ref.watch(courierDataProvider);
  if (data.isLoading) return const AsyncValue.loading();
  return AsyncValue.data(data.assignedOrders);
});

// Courier requests provider (uyumluluk için)
final courierRequestsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final data = ref.watch(courierDataProvider);
  if (data.isLoading) return const AsyncValue.loading();
  return AsyncValue.data(data.courierRequests);
});