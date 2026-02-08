import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/store/store_product_model.dart';
import '../services/delivery_service.dart';

class StoreCartItem {
  final String id;
  final String productId;
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final String imageUrl;
  final String storeId;
  final String storeName;
  final String? unit;

  const StoreCartItem({
    required this.id,
    required this.productId,
    required this.name,
    this.description,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.storeId,
    required this.storeName,
    this.unit,
  });

  StoreCartItem copyWith({
    String? id,
    String? productId,
    String? name,
    String? description,
    double? price,
    int? quantity,
    String? imageUrl,
    String? storeId,
    String? storeName,
    String? unit,
  }) {
    return StoreCartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      unit: unit ?? this.unit,
    );
  }

  double get totalPrice => price * quantity;
}

class StoreCartState {
  final List<StoreCartItem> items;
  final bool isLoading;
  final double? dynamicDeliveryFee;
  final double? deliveryDistanceKm;
  final int? estimatedDeliveryMin;
  final String? deliveryZoneName;
  final bool deliveryFeeLoading;
  final bool canDeliver;
  final String? deliveryError;
  final double? minOrderAmount;

  const StoreCartState({
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

  StoreCartState copyWith({
    List<StoreCartItem>? items,
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
    return StoreCartState(
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
    return dynamicDeliveryFee ?? 19.90;
  }

  double get total => subtotal + deliveryFee;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  // Get items grouped by store
  Map<String, List<StoreCartItem>> get itemsByStore {
    final Map<String, List<StoreCartItem>> grouped = {};
    for (final item in items) {
      if (!grouped.containsKey(item.storeId)) {
        grouped[item.storeId] = [];
      }
      grouped[item.storeId]!.add(item);
    }
    return grouped;
  }

  // Get store name for a store ID
  String? getStoreName(String storeId) {
    final storeItems = items.where((item) => item.storeId == storeId);
    if (storeItems.isNotEmpty) {
      return storeItems.first.storeName;
    }
    return null;
  }
}

class StoreCartNotifier extends StateNotifier<StoreCartState> {
  StoreCartNotifier() : super(const StoreCartState());

  void addItem(StoreCartItem item) {
    // Match by productId+storeId first, then by name+storeId to prevent duplicates from different searches
    var existingIndex = state.items.indexWhere((i) => i.productId == item.productId && i.storeId == item.storeId);
    if (existingIndex < 0) {
      existingIndex = state.items.indexWhere((i) => i.name == item.name && i.storeId == item.storeId);
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

  void addProduct(StoreProduct product, {int quantity = 1}) {
    final item = StoreCartItem(
      id: '${product.storeId}_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      productId: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      quantity: quantity,
      imageUrl: product.imageUrl,
      storeId: product.storeId,
      storeName: product.storeName,
      unit: null,
    );
    addItem(item);
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != itemId).toList(),
    );
  }

  void removeByProductId(String productId, String storeId) {
    state = state.copyWith(
      items: state.items.where((item) => !(item.productId == productId && item.storeId == storeId)).toList(),
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
    state = const StoreCartState();
  }

  void clearStoreItems(String storeId) {
    state = state.copyWith(
      items: state.items.where((item) => item.storeId != storeId).toList(),
    );
  }

  int getProductQuantity(String productId, String storeId) {
    final item = state.items.where((i) => i.productId == productId && i.storeId == storeId).firstOrNull;
    return item?.quantity ?? 0;
  }

  Future<void> calculateDeliveryFee({
    required String storeId,
    required double customerLat,
    required double customerLon,
  }) async {
    if (state.items.isEmpty) return;

    state = state.copyWith(deliveryFeeLoading: true);

    try {
      final estimate = await DeliveryService.getDeliveryEstimate(
        merchantId: storeId,
        customerLat: customerLat,
        customerLon: customerLon,
        subtotal: state.subtotal,
      );

      if (estimate != null) {
        state = StoreCartState(
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
      debugPrint('StoreCart calculateDeliveryFee error: $e');
      state = state.copyWith(deliveryFeeLoading: false);
    }
  }
}

final storeCartProvider = StateNotifierProvider<StoreCartNotifier, StoreCartState>((ref) {
  return StoreCartNotifier();
});

// Convenience providers
final storeCartItemCountProvider = Provider<int>((ref) {
  return ref.watch(storeCartProvider).itemCount;
});

final storeCartTotalProvider = Provider<double>((ref) {
  return ref.watch(storeCartProvider).total;
});
