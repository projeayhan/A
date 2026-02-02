import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/taxi_service.dart';

/// Ride State
class RideState {
  final Map<String, dynamic>? currentRide;
  final Map<String, dynamic>? driver;
  final bool isLoading;
  final String? error;
  final double? driverLatitude;
  final double? driverLongitude;
  final List<Map<String, dynamic>> rideHistory;

  RideState({
    this.currentRide,
    this.driver,
    this.isLoading = false,
    this.error,
    this.driverLatitude,
    this.driverLongitude,
    this.rideHistory = const [],
  });

  RideState copyWith({
    Map<String, dynamic>? currentRide,
    Map<String, dynamic>? driver,
    bool? isLoading,
    String? error,
    double? driverLatitude,
    double? driverLongitude,
    List<Map<String, dynamic>>? rideHistory,
    bool clearRide = false,
    bool clearError = false,
  }) {
    return RideState(
      currentRide: clearRide ? null : (currentRide ?? this.currentRide),
      driver: clearRide ? null : (driver ?? this.driver),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      driverLatitude: clearRide ? null : (driverLatitude ?? this.driverLatitude),
      driverLongitude: clearRide ? null : (driverLongitude ?? this.driverLongitude),
      rideHistory: rideHistory ?? this.rideHistory,
    );
  }

  String? get rideStatus => currentRide?['status'];
  String? get rideId => currentRide?['id'];
  String? get driverId => currentRide?['driver_id'];
  bool get hasActiveRide => currentRide != null &&
      !['completed', 'cancelled_by_user', 'cancelled_by_driver', 'no_driver_found'].contains(rideStatus);
}

/// Ride Notifier
class RideNotifier extends StateNotifier<RideState> {
  RealtimeChannel? _rideChannel;
  RealtimeChannel? _driverLocationChannel;

  RideNotifier() : super(RideState());

  /// Aktif sürüşü kontrol et
  Future<void> checkActiveRide() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final ride = await TaxiService.getActiveRide();

      if (ride != null) {
        state = state.copyWith(
          currentRide: ride,
          driver: ride['driver'],
          isLoading: false,
        );

        // Subscribe to updates
        _subscribeToRide(ride['id']);
        if (ride['driver_id'] != null) {
          _subscribeToDriverLocation(ride['driver_id']);
        }
      } else {
        state = state.copyWith(isLoading: false, clearRide: true);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Yeni sürüş talebi oluştur
  Future<bool> requestRide({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    String? pickupName,
    required double destinationLatitude,
    required double destinationLongitude,
    required String destinationAddress,
    String? destinationName,
    required String vehicleTypeId,
    required String paymentType,
    String? promotionId,
    double? estimatedDistanceKm,
    int? estimatedDurationMinutes,
    String? routePolyline,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await TaxiService.requestRide(
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        pickupAddress: pickupAddress,
        pickupName: pickupName,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        destinationAddress: destinationAddress,
        destinationName: destinationName,
        vehicleTypeId: vehicleTypeId,
        paymentType: paymentType,
        promotionId: promotionId,
        estimatedDistanceKm: estimatedDistanceKm,
        estimatedDurationMinutes: estimatedDurationMinutes,
        routePolyline: routePolyline,
      );

      final rideData = response['data'] as Map<String, dynamic>;
      state = state.copyWith(
        currentRide: rideData,
        isLoading: false,
      );

      _subscribeToRide(rideData['id']);
      return true;
    } catch (e) {
      // Hata mesajını kullanıcı dostu hale getir
      String errorMessage = e.toString();
      if (errorMessage.contains('401') || errorMessage.contains('Invalid JWT') || errorMessage.contains('Invalid token')) {
        errorMessage = 'Oturum süresi dolmuş. Lütfen tekrar giriş yapın.';
      } else if (errorMessage.contains('Failed to request ride')) {
        errorMessage = 'Sürüş talebi oluşturulamadı. Lütfen tekrar deneyin.';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  /// Sürüşü iptal et
  Future<bool> cancelRide({String? reason, String? note}) async {
    if (state.rideId == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await TaxiService.cancelRide(
        state.rideId!,
        reason: reason ?? note,
      );

      _unsubscribeAll();
      state = state.copyWith(isLoading: false, clearRide: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Sürüşü puanla
  Future<bool> rateRide({
    required int rating,
    List<String>? feedbackTags,
    String? comment,
    double? tipAmount,
  }) async {
    if (state.rideId == null) return false;

    try {
      await TaxiService.rateRide(
        rideId: state.rideId!,
        rating: rating,
        comment: comment ?? (feedbackTags?.join(', ')),
        tipAmount: tipAmount,
      );

      _unsubscribeAll();
      state = state.copyWith(clearRide: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Sürüş geçmişini yükle
  Future<void> loadRideHistory() async {
    try {
      final history = await TaxiService.getRideHistory();
      state = state.copyWith(rideHistory: history);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Mevcut sürüş state'ini temizle
  void clearRide() {
    _unsubscribeAll();
    state = state.copyWith(clearRide: true, clearError: true);
  }

  /// Sürüş değişikliklerini dinle
  void _subscribeToRide(String rideId) {
    _rideChannel?.unsubscribe();
    _rideChannel = TaxiService.subscribeToRide(rideId, (newData) {
      state = state.copyWith(currentRide: newData);

      // Sürücü atandıysa konum takibini başlat
      final driverId = newData['driver_id'];
      if (driverId != null && _driverLocationChannel == null) {
        _subscribeToDriverLocation(driverId);
      }

      // Sürüş tamamlandı veya iptal edildiyse
      if (['completed', 'cancelled_by_user', 'cancelled_by_driver', 'no_driver_found']
          .contains(newData['status'])) {
        // Subscriptions devam etsin ki rating yapılabilsin
      }
    });
  }

  /// Sürücü konumunu dinle
  void _subscribeToDriverLocation(String driverId) {
    _driverLocationChannel?.unsubscribe();
    _driverLocationChannel = TaxiService.subscribeToDriverLocation(
      driverId,
      (lat, lng) {
        state = state.copyWith(
          driverLatitude: lat,
          driverLongitude: lng,
        );
      },
    );
  }

  void _unsubscribeAll() {
    _rideChannel?.unsubscribe();
    _driverLocationChannel?.unsubscribe();
    _rideChannel = null;
    _driverLocationChannel = null;
  }

  @override
  void dispose() {
    _unsubscribeAll();
    super.dispose();
  }
}

/// Provider
final rideProvider = StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier();
});

/// Vehicle Types Provider
final vehicleTypesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return TaxiService.getVehicleTypes();
});

/// Nearby Drivers Provider
final nearbyDriversProvider = FutureProvider.family<List<Map<String, dynamic>>, Map<String, dynamic>>((ref, params) async {
  return TaxiService.findNearbyDrivers(
    latitude: (params['latitude'] as num).toDouble(),
    longitude: (params['longitude'] as num).toDouble(),
    radiusKm: (params['radius_km'] as num?)?.toDouble() ?? 5,
    vehicleTypeId: params['vehicle_type_id'],
  );
});

/// Fare Calculation Provider
final fareCalculationProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  return TaxiService.calculateFare(
    pickupLatitude: (params['pickup_latitude'] as num).toDouble(),
    pickupLongitude: (params['pickup_longitude'] as num).toDouble(),
    destinationLatitude: (params['destination_latitude'] as num).toDouble(),
    destinationLongitude: (params['destination_longitude'] as num).toDouble(),
    vehicleTypeId: params['vehicle_type_id'],
    promotionCode: params['promotion_code'],
  );
});

/// Saved Locations Provider
final savedLocationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return TaxiService.getSavedLocations();
});

/// Recent Locations Provider
final recentLocationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return TaxiService.getRecentLocations();
});

/// Feedback Tags Provider
final feedbackTagsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, category) async {
  return TaxiService.getFeedbackTags(category: category);
});

/// Active Promotions Provider
final activePromotionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return TaxiService.getActivePromotions();
});

/// Driver Promotions Provider
final driverPromotionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return TaxiService.getDriverPromotions();
});
