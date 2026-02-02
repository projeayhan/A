import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/store/store_product_model.dart';

// Favori Ürün Modeli
class FavoriteProduct {
  final String id;
  final String name;
  final String imageUrl;
  final double price;
  final double? originalPrice;
  final String storeName;
  final String storeId;
  final double rating;
  final DateTime addedAt;

  const FavoriteProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.originalPrice,
    required this.storeName,
    required this.storeId,
    required this.rating,
    required this.addedAt,
  });

  factory FavoriteProduct.fromProduct(StoreProduct product) {
    return FavoriteProduct(
      id: product.id,
      name: product.name,
      imageUrl: product.imageUrl,
      price: product.price,
      originalPrice: product.originalPrice,
      storeName: product.storeName,
      storeId: product.storeId,
      rating: product.rating,
      addedAt: DateTime.now(),
    );
  }

  factory FavoriteProduct.fromJson(Map<String, dynamic> json) {
    return FavoriteProduct(
      id: json['id'],
      name: json['name'],
      imageUrl: json['imageUrl'] ?? '',
      price: (json['price'] as num).toDouble(),
      originalPrice: json['originalPrice'] != null
          ? (json['originalPrice'] as num).toDouble()
          : null,
      storeName: json['storeName'] ?? '',
      storeId: json['storeId'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'originalPrice': originalPrice,
      'storeName': storeName,
      'storeId': storeId,
      'rating': rating,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

// Ürün Favori State
class ProductFavoriteState {
  final List<FavoriteProduct> favorites;
  final bool isLoading;

  const ProductFavoriteState({
    this.favorites = const [],
    this.isLoading = false,
  });

  bool isFavorite(String productId) {
    return favorites.any((p) => p.id == productId);
  }

  ProductFavoriteState copyWith({
    List<FavoriteProduct>? favorites,
    bool? isLoading,
  }) {
    return ProductFavoriteState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Ürün Favori Notifier
class ProductFavoriteNotifier extends StateNotifier<ProductFavoriteState> {
  ProductFavoriteNotifier() : super(const ProductFavoriteState()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    // Product favorites are stored in local state only (no DB table for products)
    // State is already initialized as empty
  }

  Future<void> toggleFavorite(StoreProduct product) async {
    if (state.isFavorite(product.id)) {
      await removeFavorite(product.id);
    } else {
      await addFavorite(product);
    }
  }

  Future<void> addFavorite(StoreProduct product) async {
    if (state.isFavorite(product.id)) return;

    final favoriteProduct = FavoriteProduct.fromProduct(product);
    // Local state update only (no DB table for product favorites)
    state = state.copyWith(favorites: [...state.favorites, favoriteProduct]);
  }

  Future<void> removeFavorite(String productId) async {
    // Local state update only
    state = state.copyWith(
      favorites: state.favorites.where((p) => p.id != productId).toList(),
    );
  }

  void clearAll() {
    state = state.copyWith(favorites: []);
  }
}

// Product Favorite Provider
final productFavoriteProvider =
    StateNotifierProvider<ProductFavoriteNotifier, ProductFavoriteState>((ref) {
      return ProductFavoriteNotifier();
    });

// Convenience provider - belirli bir ürünün favori durumu
final isProductFavoriteProvider = Provider.family<bool, String>((
  ref,
  productId,
) {
  return ref.watch(productFavoriteProvider).isFavorite(productId);
});

// Favori ürün sayısı
final favoriteProductCountProvider = Provider<int>((ref) {
  return ref.watch(productFavoriteProvider).favorites.length;
});
