import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/delivery_service.dart';

class CartItem {
  final String id;
  final String name;
  final String? description;
  final String? extra;
  final double price;
  final int quantity;
  final String imageUrl;
  final String? merchantId;
  final String? merchantName;
  final String? storeId;
  final String? storeName;
  final String type; // 'food' or 'store'

  const CartItem({
    required this.id,
    required this.name,
    this.description,
    this.extra,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.merchantId,
    this.merchantName,
    this.storeId,
    this.storeName,
    this.type = 'food',
  });

  CartItem copyWith({
    String? id,
    String? name,
    String? description,
    String? extra,
    double? price,
    int? quantity,
    String? imageUrl,
    String? merchantId,
    String? merchantName,
    String? storeId,
    String? storeName,
    String? type,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      extra: extra ?? this.extra,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      type: type ?? this.type,
    );
  }

  double get totalPrice => price * quantity;
}

class CartState {
  final List<CartItem> items;
  final bool isLoading;
  final double? dynamicDeliveryFee;
  final double? deliveryDistanceKm;
  final int? estimatedDeliveryMin;
  final String? deliveryZoneName;
  final bool deliveryFeeLoading;
  final bool canDeliver;
  final String? deliveryError;
  final double? minOrderAmount;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.dynamicDeliveryFee,
    this.deliveryDistanceKm,
    this.estimatedDeliveryMin,
    this.deliveryZoneName,
    this.deliveryFeeLoading = false,
    this.canDeliver = true,
    this.deliveryError,
    this.minOrderAmount,
  });

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    double? dynamicDeliveryFee,
    double? deliveryDistanceKm,
    int? estimatedDeliveryMin,
    String? deliveryZoneName,
    bool? deliveryFeeLoading,
    bool? canDeliver,
    String? deliveryError,
    double? minOrderAmount,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      dynamicDeliveryFee: dynamicDeliveryFee ?? this.dynamicDeliveryFee,
      deliveryDistanceKm: deliveryDistanceKm ?? this.deliveryDistanceKm,
      estimatedDeliveryMin: estimatedDeliveryMin ?? this.estimatedDeliveryMin,
      deliveryZoneName: deliveryZoneName ?? this.deliveryZoneName,
      deliveryFeeLoading: deliveryFeeLoading ?? this.deliveryFeeLoading,
      canDeliver: canDeliver ?? this.canDeliver,
      deliveryError: deliveryError ?? this.deliveryError,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee {
    if (subtotal <= 0) return 0;
    return dynamicDeliveryFee ?? 15.0;
  }

  double get total => subtotal + deliveryFee;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  String? get merchantId => items.isNotEmpty ? items.first.merchantId : null;

  String? get merchantName => items.isNotEmpty ? items.first.merchantName : null;
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(CartItem item) {
    // Match by id first, then by name+merchant to prevent duplicates from different searches
    var existingIndex = state.items.indexWhere((i) => i.id == item.id);
    if (existingIndex < 0) {
      existingIndex = state.items.indexWhere((i) =>
          i.name == item.name && i.merchantId == item.merchantId);
    }

    if (existingIndex >= 0) {
      final updatedItems = [...state.items];
      final existingItem = updatedItems[existingIndex];
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + item.quantity,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != itemId).toList(),
    );
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final updatedItems = state.items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void incrementQuantity(String itemId) {
    final item = state.items.firstWhere((i) => i.id == itemId);
    updateQuantity(itemId, item.quantity + 1);
  }

  void decrementQuantity(String itemId) {
    final item = state.items.firstWhere((i) => i.id == itemId);
    updateQuantity(itemId, item.quantity - 1);
  }

  void clearCart() {
    state = const CartState();
  }

  Future<void> calculateDeliveryFee({
    required double customerLat,
    required double customerLon,
  }) async {
    final merchantId = state.merchantId;
    if (merchantId == null || state.items.isEmpty) return;

    state = state.copyWith(deliveryFeeLoading: true);

    try {
      final estimate = await DeliveryService.getDeliveryEstimate(
        merchantId: merchantId,
        customerLat: customerLat,
        customerLon: customerLon,
        subtotal: state.subtotal,
      );

      if (estimate != null) {
        state = CartState(
          items: state.items,
          isLoading: false,
          dynamicDeliveryFee: estimate.deliveryFee,
          deliveryDistanceKm: estimate.distanceKm,
          estimatedDeliveryMin: estimate.estimatedMinutes,
          deliveryZoneName: estimate.zoneName,
          deliveryFeeLoading: false,
          canDeliver: estimate.canDeliver,
          deliveryError: estimate.errorMessage,
          minOrderAmount: estimate.minOrderAmount,
        );
      } else {
        state = state.copyWith(deliveryFeeLoading: false);
      }
    } catch (e) {
      debugPrint('calculateDeliveryFee error: $e');
      state = state.copyWith(deliveryFeeLoading: false);
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});

// Convenience providers
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).total;
});
