import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/restaurant_service.dart';
import 'address_provider.dart';

// Tüm restoranlar provider (teslimat bölgesi filtreli)
final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await RestaurantService.getRestaurants(
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Restoran kategorileri provider
final restaurantCategoriesProvider = FutureProvider<List<RestaurantCategory>>((ref) async {
  return await RestaurantService.getCategories();
});

// Kategoriye göre restoranlar provider (teslimat bölgesi filtreli)
final restaurantsByCategoryProvider = FutureProvider.family<List<Restaurant>, String?>((ref, category) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  if (category == null || category.isEmpty || category == 'Tümü') {
    return await RestaurantService.getRestaurants(
      customerLat: selectedAddress?.latitude,
      customerLon: selectedAddress?.longitude,
    );
  }
  return await RestaurantService.getRestaurantsByCategory(
    category,
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Tek restoran provider
final restaurantByIdProvider = FutureProvider.family<Restaurant?, String>((ref, id) async {
  return await RestaurantService.getRestaurantById(id);
});

// Restoran menüsü provider
final menuItemsProvider = FutureProvider.family<List<MenuItem>, String>((ref, restaurantId) async {
  return await RestaurantService.getMenuItems(restaurantId);
});

// Restoran arama provider (teslimat bölgesi filtreli)
final restaurantSearchProvider = FutureProvider.family<List<Restaurant>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await RestaurantService.searchRestaurants(
    query,
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Popüler restoranlar provider (teslimat bölgesi filtreli)
final popularRestaurantsProvider = FutureProvider<List<Restaurant>>((ref) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await RestaurantService.getPopularRestaurants(
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Seçili kategori state provider
final selectedRestaurantCategoryProvider = StateProvider<String?>((ref) => null);
