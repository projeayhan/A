import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Promosyon Tipi
enum PromotionType {
  percentage, // Yüzde indirim
  fixed, // Sabit indirim
  freeRide, // Ücretsiz yolculuk
  cashback, // Geri ödeme
}

// Promosyon Modeli
class TaxiPromotion {
  final String id;
  final String code;
  final String title;
  final String description;
  final PromotionType type;
  final double value; // Yüzde veya sabit miktar
  final double? minAmount; // Minimum sipariş tutarı
  final double? maxDiscount; // Maksimum indirim tutarı
  final DateTime validFrom;
  final DateTime validUntil;
  final int? usageLimit; // Toplam kullanım limiti
  final int? userUsageLimit; // Kullanıcı başına limit
  final int usedCount; // Kullanılma sayısı
  final bool isActive;
  final String? imageUrl;
  final Color color;
  final List<String>? applicableVehicleTypes;

  const TaxiPromotion({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    this.minAmount,
    this.maxDiscount,
    required this.validFrom,
    required this.validUntil,
    this.usageLimit,
    this.userUsageLimit,
    this.usedCount = 0,
    this.isActive = true,
    this.imageUrl,
    required this.color,
    this.applicableVehicleTypes,
  });

  bool get isValid {
    final now = DateTime.now();
    return isActive && now.isAfter(validFrom) && now.isBefore(validUntil);
  }

  bool get isExpiringSoon {
    final now = DateTime.now();
    final difference = validUntil.difference(now);
    return difference.inDays <= 3 && difference.inDays >= 0;
  }

  String get formattedDiscount {
    switch (type) {
      case PromotionType.percentage:
        return '%${value.toInt()} İndirim';
      case PromotionType.fixed:
        return '${value.toStringAsFixed(0)}₺ İndirim';
      case PromotionType.freeRide:
        return 'Ücretsiz Yolculuk';
      case PromotionType.cashback:
        return '%${value.toInt()} Geri Ödeme';
    }
  }

  String get remainingTime {
    final now = DateTime.now();
    final difference = validUntil.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün kaldı';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat kaldı';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika kaldı';
    } else {
      return 'Süresi doldu';
    }
  }

  double calculateDiscount(double originalPrice) {
    if (!isValid) return 0;

    if (minAmount != null && originalPrice < minAmount!) return 0;

    double discount;
    switch (type) {
      case PromotionType.percentage:
      case PromotionType.cashback:
        discount = originalPrice * (value / 100);
        break;
      case PromotionType.fixed:
        discount = value;
        break;
      case PromotionType.freeRide:
        discount = originalPrice;
        break;
    }

    if (maxDiscount != null && discount > maxDiscount!) {
      discount = maxDiscount!;
    }

    return discount;
  }

  IconData get icon {
    switch (type) {
      case PromotionType.percentage:
        return Icons.percent;
      case PromotionType.fixed:
        return Icons.money_off;
      case PromotionType.freeRide:
        return Icons.local_taxi;
      case PromotionType.cashback:
        return Icons.account_balance_wallet;
    }
  }
}

// Promosyon State
class TaxiPromotionState {
  final List<TaxiPromotion> promotions;
  final TaxiPromotion? selectedPromotion;
  final bool isLoading;
  final String? error;

  const TaxiPromotionState({
    this.promotions = const [],
    this.selectedPromotion,
    this.isLoading = false,
    this.error,
  });

  List<TaxiPromotion> get activePromotions {
    return promotions.where((p) => p.isValid).toList();
  }

  List<TaxiPromotion> get expiringSoonPromotions {
    return promotions.where((p) => p.isValid && p.isExpiringSoon).toList();
  }

  TaxiPromotionState copyWith({
    List<TaxiPromotion>? promotions,
    TaxiPromotion? selectedPromotion,
    bool clearSelectedPromotion = false,
    bool? isLoading,
    String? error,
  }) {
    return TaxiPromotionState(
      promotions: promotions ?? this.promotions,
      selectedPromotion:
          clearSelectedPromotion ? null : (selectedPromotion ?? this.selectedPromotion),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Promosyon Notifier
class TaxiPromotionNotifier extends StateNotifier<TaxiPromotionState> {
  TaxiPromotionNotifier() : super(const TaxiPromotionState()) {
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    // Supabase'den promosyonlar yüklenecek
    // Şimdilik boş liste
  }

  void selectPromotion(TaxiPromotion? promotion) {
    if (promotion == null) {
      state = state.copyWith(clearSelectedPromotion: true);
    } else {
      state = state.copyWith(selectedPromotion: promotion);
    }
  }

  void clearSelectedPromotion() {
    state = state.copyWith(clearSelectedPromotion: true);
  }

  bool applyPromoCode(String code) {
    final upperCode = code.toUpperCase().trim();
    try {
      final promotion = state.promotions.firstWhere(
        (p) => p.code.toUpperCase() == upperCode && p.isValid,
      );
      selectPromotion(promotion);
      return true;
    } catch (_) {
      return false;
    }
  }

  TaxiPromotion? getPromotionByCode(String code) {
    final upperCode = code.toUpperCase().trim();
    try {
      return state.promotions.firstWhere(
        (p) => p.code.toUpperCase() == upperCode,
      );
    } catch (_) {
      return null;
    }
  }
}

// Provider tanımları
final taxiPromotionProvider =
    StateNotifierProvider<TaxiPromotionNotifier, TaxiPromotionState>((ref) {
  return TaxiPromotionNotifier();
});

// Convenience providers
final activePromotionsProvider = Provider<List<TaxiPromotion>>((ref) {
  return ref.watch(taxiPromotionProvider).activePromotions;
});

final selectedPromotionProvider = Provider<TaxiPromotion?>((ref) {
  return ref.watch(taxiPromotionProvider).selectedPromotion;
});

final expiringSoonPromotionsProvider = Provider<List<TaxiPromotion>>((ref) {
  return ref.watch(taxiPromotionProvider).expiringSoonPromotions;
});
