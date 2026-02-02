import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const CartState({
    this.items = const [],
    this.isLoading = false,
  });

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => subtotal > 0 ? 15.0 : 0;

  double get total => subtotal + deliveryFee;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  String? get merchantId => items.isNotEmpty ? items.first.merchantId : null;

  String? get merchantName => items.isNotEmpty ? items.first.merchantName : null;
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(CartItem item) {
    final existingIndex = state.items.indexWhere((i) => i.id == item.id);

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
