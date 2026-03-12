import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/car_models.dart';
import '../services/dealer_service.dart';
import '../services/listing_service.dart';

// ==================== SERVİS PROVİDERLARI ====================

final dealerServiceProvider = Provider<DealerService>((ref) {
  return DealerService();
});

final listingServiceProvider = Provider<ListingService>((ref) {
  return ListingService();
});

// ==================== DEALER PROVİDERLARI ====================

/// Satıcı profili
final dealerProfileProvider = FutureProvider<CarDealer?>((ref) async {
  final service = ref.watch(dealerServiceProvider);
  return service.getDealerProfile();
});

/// Satıcı mı kontrolü
final isDealerProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(dealerServiceProvider);
  return service.isDealer();
});

/// Başvuru durumu
final applicationStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(dealerServiceProvider);
  return service.getApplicationStatus();
});

/// Dashboard istatistikleri
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(dealerServiceProvider);
  return service.getDashboardStats();
});

// ==================== İLAN PROVİDERLARI ====================

/// Markalar
final brandsProvider = FutureProvider<List<CarBrand>>((ref) async {
  final service = ref.watch(listingServiceProvider);
  return service.getBrands();
});

/// Popüler markalar
final popularBrandsProvider = FutureProvider<List<CarBrand>>((ref) async {
  final service = ref.watch(listingServiceProvider);
  return service.getBrands(popularOnly: true);
});

/// Özellikler
final featuresProvider = FutureProvider<List<CarFeature>>((ref) async {
  final service = ref.watch(listingServiceProvider);
  return service.getFeatures();
});

/// Kategoriye göre özellikler
final featuresByCategoryProvider = FutureProvider.family<List<CarFeature>, String>((ref, category) async {
  final service = ref.watch(listingServiceProvider);
  return service.getFeatures(category: category);
});

/// Kullanıcının tüm ilanları
final userListingsProvider = FutureProvider<List<CarListing>>((ref) async {
  final service = ref.watch(listingServiceProvider);
  return service.getUserListings();
});

/// Duruma göre ilanlar
final listingsByStatusProvider = FutureProvider.family<List<CarListing>, CarListingStatus?>((ref, status) async {
  final service = ref.watch(listingServiceProvider);
  return service.getUserListings(status: status);
});

/// Aktif ilanlar
final activeListingsProvider = FutureProvider<List<CarListing>>((ref) async {
  final service = ref.watch(listingServiceProvider);
  return service.getUserListings(status: CarListingStatus.active);
});

/// Bekleyen ilanlar
final pendingListingsProvider = FutureProvider<List<CarListing>>((ref) async {
  final service = ref.watch(listingServiceProvider);
  return service.getUserListings(status: CarListingStatus.pending);
});

/// Satılan ilanlar
final soldListingsProvider = FutureProvider<List<CarListing>>((ref) async {
  final service = ref.watch(listingServiceProvider);
  return service.getUserListings(status: CarListingStatus.sold);
});

/// İlan detayı
final listingDetailProvider = FutureProvider.family<CarListing?, String>((ref, listingId) async {
  final service = ref.watch(listingServiceProvider);
  return service.getListingById(listingId);
});

// ==================== PERFORMANS İSTATİSTİKLERİ ====================

/// Performans istatistikleri için family provider
/// [days] parametresi ile dönem seçilebilir (7, 30, 90)
final listingPerformanceStatsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  final service = ref.watch(dealerServiceProvider);
  return service.getListingPerformanceStats(days: days);
});

// ==================== DEĞERLENDİRMELER ====================

/// Galeri değerlendirmeleri
final dealerReviewsProvider = FutureProvider<List<CarDealerReview>>((ref) async {
  final service = ref.watch(dealerServiceProvider);
  return service.getDealerReviews();
});

/// Değerlendirme istatistikleri
final reviewStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(dealerServiceProvider);
  return service.getReviewStats();
});
