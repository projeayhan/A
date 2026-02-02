import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_category_model.dart';
import '../../models/store/store_product_model.dart';
import '../services/store_service.dart';
import 'address_provider.dart';

// Kategoriler provider
final storeCategoriesProvider = FutureProvider<List<StoreCategory>>((ref) async {
  return await StoreService.getCategories();
});

// Tüm mağazalar provider (teslimat bölgesi filtreli)
final storesProvider = FutureProvider<List<Store>>((ref) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await StoreService.getStores(
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Öne çıkan mağazalar provider (teslimat bölgesi filtreli)
final featuredStoresProvider = FutureProvider<List<Store>>((ref) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await StoreService.getFeaturedStores(
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Kategoriye göre mağazalar provider (teslimat bölgesi filtreli)
final storesByCategoryProvider = FutureProvider.family<List<Store>, String>((ref, categoryId) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  if (categoryId.isEmpty || categoryId == 'all') {
    return await StoreService.getStores(
      customerLat: selectedAddress?.latitude,
      customerLon: selectedAddress?.longitude,
    );
  }
  return await StoreService.getStoresByCategory(
    categoryId,
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Tüm ürünler provider
final storeProductsProvider = FutureProvider<List<StoreProduct>>((ref) async {
  return await StoreService.getProducts();
});

// Mağazaya göre ürünler provider
final productsByStoreProvider = FutureProvider.family<List<StoreProduct>, String>((ref, storeId) async {
  return await StoreService.getProductsByStore(storeId);
});

// Kategoriye göre ürünler provider
final productsByCategoryProvider = FutureProvider.family<List<StoreProduct>, String>((ref, categoryId) async {
  return await StoreService.getProductsByCategory(categoryId);
});

// Flash deals provider
final flashDealsProvider = FutureProvider<List<StoreProduct>>((ref) async {
  return await StoreService.getFlashDeals();
});

// Best sellers provider
final bestSellersProvider = FutureProvider<List<StoreProduct>>((ref) async {
  return await StoreService.getBestSellers();
});

// Recommended products provider
final recommendedProductsProvider = FutureProvider<List<StoreProduct>>((ref) async {
  return await StoreService.getRecommended();
});

// Arama provider
final productSearchProvider = FutureProvider.family<List<StoreProduct>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return await StoreService.searchProducts(query);
});

// Mağaza arama provider (teslimat bölgesi filtreli)
final storeSearchProvider = FutureProvider.family<List<Store>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await StoreService.searchStores(
    query,
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Seçili kategori state provider
final selectedStoreCategoryProvider = StateProvider<String>((ref) => 'all');
