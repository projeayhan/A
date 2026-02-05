import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_product_model.dart';
import '../services/market_service.dart';
import 'address_provider.dart';

// Tüm marketler provider (teslimat bölgesi filtreli)
final marketsProvider = FutureProvider<List<Store>>((ref) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await MarketService.getMarkets(
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Öne çıkan marketler provider (teslimat bölgesi filtreli)
final featuredMarketsProvider = FutureProvider<List<Store>>((ref) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await MarketService.getFeaturedMarkets(
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Markete göre ürünler provider
final productsByMarketProvider = FutureProvider.family<List<StoreProduct>, String>((ref, marketId) async {
  return await MarketService.getProductsByMarket(marketId);
});

// Market arama provider (teslimat bölgesi filtreli)
final marketSearchProvider = FutureProvider.family<List<Store>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await MarketService.searchMarkets(
    query,
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});

// Market indirimleri provider (teslimat bölgesi filtreli)
final marketDealsProvider = FutureProvider<List<StoreProduct>>((ref) async {
  final selectedAddress = ref.watch(selectedAddressProvider);
  return await MarketService.getMarketDeals(
    customerLat: selectedAddress?.latitude,
    customerLon: selectedAddress?.longitude,
  );
});
