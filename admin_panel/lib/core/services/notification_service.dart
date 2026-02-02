import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// JavaScript fonksiyonu çağırma
@JS('playNotificationSound')
external void _jsPlayNotificationSound();

/// Bekleyen başvuru sayılarını tutan model
class PendingApplicationCounts {
  final int taxiDrivers;
  final int couriers;
  final int merchants;
  final int realtors;
  final int carDealers;
  final int pendingCarListings;

  PendingApplicationCounts({
    this.taxiDrivers = 0,
    this.couriers = 0,
    this.merchants = 0,
    this.realtors = 0,
    this.carDealers = 0,
    this.pendingCarListings = 0,
  });

  int get total => taxiDrivers + couriers + merchants + realtors + carDealers + pendingCarListings;

  PendingApplicationCounts copyWith({
    int? taxiDrivers,
    int? couriers,
    int? merchants,
    int? realtors,
    int? carDealers,
    int? pendingCarListings,
  }) {
    return PendingApplicationCounts(
      taxiDrivers: taxiDrivers ?? this.taxiDrivers,
      couriers: couriers ?? this.couriers,
      merchants: merchants ?? this.merchants,
      realtors: realtors ?? this.realtors,
      carDealers: carDealers ?? this.carDealers,
      pendingCarListings: pendingCarListings ?? this.pendingCarListings,
    );
  }
}

/// Bildirim servisi - bekleyen başvuruları takip eder ve ses çalar
class NotificationService extends StateNotifier<PendingApplicationCounts> {
  final SupabaseClient _supabase;
  RealtimeChannel? _realtorChannel;
  RealtimeChannel? _partnerChannel;
  RealtimeChannel? _courierChannel;
  RealtimeChannel? _merchantChannel;
  RealtimeChannel? _carDealerChannel;
  RealtimeChannel? _carListingsChannel;
  int _previousTotal = 0;
  bool _isInitialized = false;

  NotificationService(this._supabase) : super(PendingApplicationCounts()) {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // İlk yükleme
    await refreshCounts();

    // Real-time subscription'lar
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    // Emlakçı başvuruları için realtime
    _realtorChannel = _supabase
        .channel('realtor_applications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'realtor_applications',
          callback: (payload) {
            _onNewApplication('realtor', payload);
          },
        )
        .subscribe();

    // Partner başvuruları için realtime
    _partnerChannel = _supabase
        .channel('partner_applications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'partner_applications',
          callback: (payload) {
            _onNewApplication('partner', payload);
          },
        )
        .subscribe();

    // Kurye başvuruları için realtime
    _courierChannel = _supabase
        .channel('couriers_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'couriers',
          callback: (payload) {
            _onNewApplication('courier', payload);
          },
        )
        .subscribe();

    // Merchant değişiklikleri için realtime
    _merchantChannel = _supabase
        .channel('merchants_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'merchants',
          callback: (payload) {
            _onNewApplication('merchant', payload);
          },
        )
        .subscribe();

    // Car Dealer başvuruları için realtime
    _carDealerChannel = _supabase
        .channel('car_dealer_applications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'car_dealer_applications',
          callback: (payload) {
            _onNewApplication('car_dealer', payload);
          },
        )
        .subscribe();

    // Araç ilanları için realtime (yeni ilan geldiğinde)
    _carListingsChannel = _supabase
        .channel('car_listings_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'car_listings',
          callback: (payload) {
            _onNewCarListing(payload);
          },
        )
        .subscribe();
  }

  void _onNewApplication(String type, PostgresChangePayload payload) {
    // Sayıları yenile
    refreshCounts();

    // Yeni başvuru ise ses çal
    if (payload.eventType == PostgresChangeEvent.insert) {
      final newRecord = payload.newRecord;
      final status = newRecord['status'] ??
          (newRecord['is_approved'] == false ? 'pending' : 'approved');

      if (status == 'pending') {
        playNotificationSound();
      }
    }
  }

  void _onNewCarListing(PostgresChangePayload payload) {
    // Sayıları yenile
    refreshCounts();

    // Yeni ilan eklendiyse ve pending durumundaysa ses çal
    if (payload.eventType == PostgresChangeEvent.insert) {
      final newRecord = payload.newRecord;
      final status = newRecord['status'];

      if (status == 'pending') {
        playNotificationSound();
      }
    }
  }

  Future<void> refreshCounts() async {
    try {
      // Paralel olarak tüm sayıları çek
      final results = await Future.wait([
        _getPartnerPendingCount('taxi'),
        _getCourierPendingCount(),
        _getMerchantPendingCount(),
        _getRealtorPendingCount(),
        _getCarDealerPendingCount(),
        _getPendingCarListingsCount(),
      ]);

      final newCounts = PendingApplicationCounts(
        taxiDrivers: results[0],
        couriers: results[1],
        merchants: results[2],
        realtors: results[3],
        carDealers: results[4],
        pendingCarListings: results[5],
      );

      // Yeni başvuru geldiyse ses çal
      if (newCounts.total > _previousTotal && _previousTotal > 0) {
        playNotificationSound();
      }

      _previousTotal = newCounts.total;
      state = newCounts;
    } catch (e) {
      debugPrint('Error refreshing notification counts: $e');
    }
  }

  Future<int> _getPartnerPendingCount(String type) async {
    try {
      final response = await _supabase
          .from('partner_applications')
          .select('id')
          .eq('status', 'pending')
          .eq('application_type', type);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCourierPendingCount() async {
    try {
      final response = await _supabase
          .from('couriers')
          .select('id')
          .eq('status', 'pending');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getMerchantPendingCount() async {
    try {
      final response = await _supabase
          .from('merchants')
          .select('id')
          .eq('is_approved', false);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getRealtorPendingCount() async {
    try {
      final response = await _supabase
          .from('realtor_applications')
          .select('id')
          .eq('status', 'pending');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCarDealerPendingCount() async {
    try {
      final response = await _supabase
          .from('car_dealer_applications')
          .select('id')
          .eq('status', 'pending');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getPendingCarListingsCount() async {
    try {
      final response = await _supabase
          .from('car_listings')
          .select('id')
          .eq('status', 'pending');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Bildirim sesi çal
  void playNotificationSound() {
    if (kIsWeb) {
      try {
        _jsPlayNotificationSound();
      } catch (e) {
        debugPrint('Error playing notification sound: $e');
      }
    }
  }

  @override
  void dispose() {
    _realtorChannel?.unsubscribe();
    _partnerChannel?.unsubscribe();
    _courierChannel?.unsubscribe();
    _merchantChannel?.unsubscribe();
    _carDealerChannel?.unsubscribe();
    _carListingsChannel?.unsubscribe();
    super.dispose();
  }
}

/// Provider
final notificationServiceProvider =
    StateNotifierProvider<NotificationService, PendingApplicationCounts>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return NotificationService(supabase);
});

/// Toplam bekleyen başvuru sayısı
final totalPendingCountProvider = Provider<int>((ref) {
  final counts = ref.watch(notificationServiceProvider);
  return counts.total;
});

/// Başvuru tiplerine göre sayılar
final pendingApplicationCountsProvider = Provider<PendingApplicationCounts>((ref) {
  return ref.watch(notificationServiceProvider);
});
