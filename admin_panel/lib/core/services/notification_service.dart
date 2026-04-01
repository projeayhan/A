import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_panel/core/services/log_service.dart';
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
  final int rentalCompanies;
  final int pendingCarListings;

  PendingApplicationCounts({
    this.taxiDrivers = 0,
    this.couriers = 0,
    this.merchants = 0,
    this.realtors = 0,
    this.carDealers = 0,
    this.rentalCompanies = 0,
    this.pendingCarListings = 0,
  });

  int get total => taxiDrivers + couriers + merchants + realtors + carDealers + rentalCompanies + pendingCarListings;

  PendingApplicationCounts copyWith({
    int? taxiDrivers,
    int? couriers,
    int? merchants,
    int? realtors,
    int? carDealers,
    int? rentalCompanies,
    int? pendingCarListings,
  }) {
    return PendingApplicationCounts(
      taxiDrivers: taxiDrivers ?? this.taxiDrivers,
      couriers: couriers ?? this.couriers,
      merchants: merchants ?? this.merchants,
      realtors: realtors ?? this.realtors,
      carDealers: carDealers ?? this.carDealers,
      rentalCompanies: rentalCompanies ?? this.rentalCompanies,
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
  RealtimeChannel? _rentalCompanyChannel;
  RealtimeChannel? _carListingsChannel;
  int _previousTotal = 0;
  bool _isInitialized = false;
  Timer? _refreshDebounce;

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
    // Sadece INSERT ve UPDATE dinliyoruz — DELETE badge sayısını düşürmek için
    // yeterli değil ama çok nadir olduğundan periyodik refresh ile karşılanır.
    // INSERT: yeni başvuru geldi, UPDATE: status değişti (approve/reject)

    _realtorChannel = _supabase
        .channel('realtor_applications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'realtor_applications',
          callback: (payload) => _onNewApplication('realtor', payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'realtor_applications',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();

    _partnerChannel = _supabase
        .channel('partner_applications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'partner_applications',
          callback: (payload) => _onNewApplication('partner', payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'partner_applications',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();

    _courierChannel = _supabase
        .channel('couriers_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'couriers',
          callback: (payload) => _onNewApplication('courier', payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'couriers',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();

    _merchantChannel = _supabase
        .channel('merchants_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'merchants',
          callback: (payload) => _onNewApplication('merchant', payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'merchants',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();

    _carDealerChannel = _supabase
        .channel('car_dealer_applications_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'car_dealer_applications',
          callback: (payload) => _onNewApplication('car_dealer', payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'car_dealer_applications',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();

    _rentalCompanyChannel = _supabase
        .channel('rental_companies_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rental_companies',
          callback: (payload) => _onNewApplication('rental_company', payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'rental_companies',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();

    _carListingsChannel = _supabase
        .channel('car_listings_admin_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'car_listings',
          callback: (payload) => _onNewCarListing(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'car_listings',
          callback: (_) => _debouncedRefresh(),
        )
        .subscribe();
  }

  /// Birden fazla event art arda geldiğinde tek bir refreshCounts çağrısı yapar
  void _debouncedRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(seconds: 2), () => refreshCounts());
  }

  void _onNewApplication(String type, PostgresChangePayload payload) {
    // Debounce ile sayıları yenile
    _debouncedRefresh();

    // Yeni başvuru ve pending ise ses çal
    final newRecord = payload.newRecord;
    final status = newRecord['status'] ??
        (newRecord['is_approved'] == false ? 'pending' : 'approved');

    if (status == 'pending') {
      playNotificationSound();
    }
  }

  void _onNewCarListing(PostgresChangePayload payload) {
    // Debounce ile sayıları yenile
    _debouncedRefresh();

    // Pending ise ses çal
    final newRecord = payload.newRecord;
    final status = newRecord['status'];

    if (status == 'pending') {
      playNotificationSound();
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
        _getRentalCompanyPendingCount(),
        _getPendingCarListingsCount(),
      ]);

      final newCounts = PendingApplicationCounts(
        taxiDrivers: results[0],
        couriers: results[1],
        merchants: results[2],
        realtors: results[3],
        carDealers: results[4],
        rentalCompanies: results[5],
        pendingCarListings: results[6],
      );

      // Yeni başvuru geldiyse ses çal
      if (newCounts.total > _previousTotal && _previousTotal > 0) {
        playNotificationSound();
      }

      _previousTotal = newCounts.total;
      state = newCounts;
    } catch (e, st) {
      LogService.error('Error refreshing notification counts', error: e, stackTrace: st, source: 'notification_service.dart:_refresh');
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
    } catch (e, st) {
      LogService.error('Notification count error', error: e, stackTrace: st, source: 'notification_service.dart:_getPartnerPendingCount');
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
    } catch (e, st) {
      LogService.error('Notification count error', error: e, stackTrace: st, source: 'notification_service.dart:_getCourierPendingCount');
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
    } catch (e, st) {
      LogService.error('Notification count error', error: e, stackTrace: st, source: 'notification_service.dart:_getMerchantPendingCount');
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
    } catch (e, st) {
      LogService.error('Notification count error', error: e, stackTrace: st, source: 'notification_service.dart:_getRealtorPendingCount');
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
    } catch (e, st) {
      LogService.error('Notification count error', error: e, stackTrace: st, source: 'notification_service.dart:_getCarDealerPendingCount');
      return 0;
    }
  }

  Future<int> _getRentalCompanyPendingCount() async {
    try {
      final response = await _supabase
          .from('rental_companies')
          .select('id')
          .eq('is_approved', false);
      return (response as List).length;
    } catch (e, st) {
      LogService.error('Notification count error', error: e, stackTrace: st, source: 'notification_service.dart:_getRentalCompanyPendingCount');
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
    } catch (e, st) {
      LogService.error('Notification count error', error: e, stackTrace: st, source: 'notification_service.dart:_getPendingCarListingsCount');
      return 0;
    }
  }

  /// Bildirim sesi çal
  void playNotificationSound() {
    if (kIsWeb) {
      try {
        _jsPlayNotificationSound();
      } catch (e, st) {
        LogService.error('Error playing notification sound', error: e, stackTrace: st, source: 'notification_service.dart:playNotificationSound');
      }
    }
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _realtorChannel?.unsubscribe();
    _partnerChannel?.unsubscribe();
    _courierChannel?.unsubscribe();
    _merchantChannel?.unsubscribe();
    _carDealerChannel?.unsubscribe();
    _rentalCompanyChannel?.unsubscribe();
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
