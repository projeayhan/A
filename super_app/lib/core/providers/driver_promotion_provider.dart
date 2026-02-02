import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/taxi_service.dart';

/// Taksici Promosyonları State
class DriverPromotionState {
  final List<Map<String, dynamic>> promotions;
  final Map<String, dynamic>? selectedPromotion;
  final bool isLoading;
  final String? error;

  const DriverPromotionState({
    this.promotions = const [],
    this.selectedPromotion,
    this.isLoading = false,
    this.error,
  });

  DriverPromotionState copyWith({
    List<Map<String, dynamic>>? promotions,
    Map<String, dynamic>? selectedPromotion,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return DriverPromotionState(
      promotions: promotions ?? this.promotions,
      selectedPromotion: clearSelection ? null : (selectedPromotion ?? this.selectedPromotion),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Driver Promotion Notifier
class DriverPromotionNotifier extends StateNotifier<DriverPromotionState> {
  DriverPromotionNotifier() : super(const DriverPromotionState());

  /// Promosyonları yükle
  Future<void> loadPromotions() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final promotions = await TaxiService.getDriverPromotions();
      state = state.copyWith(
        promotions: promotions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Promosyon seç
  void selectPromotion(Map<String, dynamic>? promotion) {
    state = state.copyWith(selectedPromotion: promotion);
  }

  /// Seçimi temizle
  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }
}

/// Provider
final driverPromotionProvider = StateNotifierProvider<DriverPromotionNotifier, DriverPromotionState>((ref) {
  return DriverPromotionNotifier();
});

/// Active driver promotions provider (simple)
final activeDriverPromotionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return TaxiService.getDriverPromotions();
});
