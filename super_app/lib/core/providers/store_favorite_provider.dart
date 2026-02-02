import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/store/store_model.dart';
import '../services/favorites_service.dart';
import '../services/supabase_service.dart';

// Favori Mağaza Modeli
class FavoriteStore {
  final String id;
  final String name;
  final String logoUrl;
  final String coverUrl;
  final String category;
  final double rating;
  final int followerCount;
  final int productCount;
  final DateTime addedAt;

  const FavoriteStore({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.coverUrl,
    required this.category,
    required this.rating,
    required this.followerCount,
    required this.productCount,
    required this.addedAt,
  });

  factory FavoriteStore.fromStore(Store store) {
    // categoryId'yi kategori adına çevir
    final categoryNames = {
      '1': 'Elektronik',
      '2': 'Moda',
      '3': 'Ev & Yaşam',
      '4': 'Kozmetik',
      '5': 'Spor',
      '6': 'Kitap',
      '7': 'Oyuncak',
      '8': 'Mağaza',
    };

    return FavoriteStore(
      id: store.id,
      name: store.name,
      logoUrl: store.logoUrl,
      coverUrl: store.coverUrl,
      category: categoryNames[store.categoryId] ?? 'Diğer',
      rating: store.rating,
      followerCount: store.followerCount,
      productCount: store.productCount,
      addedAt: DateTime.now(),
    );
  }

  factory FavoriteStore.fromJson(Map<String, dynamic> json) {
    return FavoriteStore(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logoUrl'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      category: json['category'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      followerCount: json['followerCount'] ?? 0,
      productCount: json['productCount'] ?? 0,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'category': category,
      'rating': rating,
      'followerCount': followerCount,
      'productCount': productCount,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

// Mağaza Favori State
class StoreFavoriteState {
  final List<FavoriteStore> favorites;
  final bool isLoading;

  const StoreFavoriteState({this.favorites = const [], this.isLoading = false});

  bool isFavorite(String storeId) {
    return favorites.any((s) => s.id == storeId);
  }

  StoreFavoriteState copyWith({
    List<FavoriteStore>? favorites,
    bool? isLoading,
  }) {
    return StoreFavoriteState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Mağaza Favori Notifier
class StoreFavoriteNotifier extends StateNotifier<StoreFavoriteState> {
  StoreFavoriteNotifier() : super(const StoreFavoriteState()) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true);

    // Get favorite merchant IDs from database
    final favoriteMerchantIds = await FavoritesService.getFavoriteMerchantIds();

    // Load store details for each favorite merchant
    final List<FavoriteStore> storeFavorites = [];
    for (final merchantId in favoriteMerchantIds) {
      try {
        final storeData = await SupabaseService.client
            .from('merchants')
            .select('id, business_name, logo_url, cover_url, rating, type')
            .eq('id', merchantId)
            .eq('type', 'store')
            .maybeSingle();

        if (storeData != null) {
          storeFavorites.add(FavoriteStore(
            id: storeData['id'],
            name: storeData['business_name'] ?? '',
            logoUrl: storeData['logo_url'] ?? '',
            coverUrl: storeData['cover_url'] ?? '',
            category: 'Mağaza',
            rating: (storeData['rating'] as num?)?.toDouble() ?? 0.0,
            followerCount: 0,
            productCount: 0,
            addedAt: DateTime.now(),
          ));
        }
      } catch (e) {
        // Skip if error
      }
    }

    state = state.copyWith(favorites: storeFavorites, isLoading: false);
  }

  Future<void> toggleFavorite(Store store) async {
    if (state.isFavorite(store.id)) {
      await removeFavorite(store.id);
    } else {
      await addFavorite(store);
    }
  }

  Future<void> addFavorite(Store store) async {
    if (state.isFavorite(store.id)) return;

    final favoriteStore = FavoriteStore.fromStore(store);
    // Optimistic Update
    state = state.copyWith(favorites: [...state.favorites, favoriteStore]);

    await FavoritesService.addFavorite(store.id);
  }

  Future<void> removeFavorite(String storeId) async {
    // Optimistic Update
    state = state.copyWith(
      favorites: state.favorites.where((s) => s.id != storeId).toList(),
    );

    await FavoritesService.removeFavorite(storeId);
  }

  void clearAll() {
    state = state.copyWith(favorites: []);
  }
}

// Store Favorite Provider
final storeFavoriteProvider =
    StateNotifierProvider<StoreFavoriteNotifier, StoreFavoriteState>((ref) {
      return StoreFavoriteNotifier();
    });

// Convenience provider - belirli bir mağazanın favori durumu
final isStoreFavoriteProvider = Provider.family<bool, String>((ref, storeId) {
  return ref.watch(storeFavoriteProvider).isFavorite(storeId);
});

// Favori mağaza sayısı
final favoriteStoreCountProvider = Provider<int>((ref) {
  return ref.watch(storeFavoriteProvider).favorites.length;
});
