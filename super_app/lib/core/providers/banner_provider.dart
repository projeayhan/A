import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

class AppBanner {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkType; // 'restaurant', 'product', 'menu_item', 'store', 'external'
  final String? linkId;   // Hedef öğenin UUID'si
  final bool isActive;
  final int sortOrder;
  final String category;
  final DateTime? startDate;
  final DateTime? endDate;

  const AppBanner({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.linkUrl,
    this.linkType,
    this.linkId,
    required this.isActive,
    required this.sortOrder,
    this.category = 'home',
    this.startDate,
    this.endDate,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      linkUrl: json['link_url'] as String?,
      linkType: json['link_type'] as String?,
      linkId: json['link_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      category: json['category'] as String? ?? 'home',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
    );
  }

  /// Banner'ın tıklanabilir olup olmadığını kontrol eder
  bool get hasLink => linkType != null || linkUrl != null;

  /// Banner'ın şu an aktif olup olmadığını kontrol eder
  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }
}

/// Kategoriye göre banner getiren family provider
/// Sadece aktif ve tarih aralığı geçerli olan banner'ları getirir
final bannersByCategoryProvider =
    FutureProvider.family<List<AppBanner>, String>((ref, category) async {
  final response = await SupabaseService.client
      .from('banners')
      .select()
      .eq('is_active', true)
      .eq('category', category)
      .order('sort_order', ascending: true);

  final now = DateTime.now();
  final banners = (response as List)
      .map((json) => AppBanner.fromJson(json as Map<String, dynamic>))
      .where((banner) {
        // Tarih filtresini client-side yapalım (daha güvenilir)
        if (banner.startDate != null && now.isBefore(banner.startDate!)) {
          return false; // Henüz başlamamış
        }
        if (banner.endDate != null && now.isAfter(banner.endDate!)) {
          return false; // Süresi dolmuş
        }
        return true;
      })
      .toList();

  return banners;
});

/// Ana sayfa banner'ları (home kategorisi)
/// Sadece aktif ve tarih aralığı geçerli olan banner'ları getirir
final bannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  final response = await SupabaseService.client
      .from('banners')
      .select()
      .eq('is_active', true)
      .eq('category', 'home')
      .order('sort_order', ascending: true);

  final now = DateTime.now();
  final banners = (response as List)
      .map((json) => AppBanner.fromJson(json as Map<String, dynamic>))
      .where((banner) {
        // Tarih filtresini client-side yapalım (daha güvenilir)
        if (banner.startDate != null && now.isBefore(banner.startDate!)) {
          return false; // Henüz başlamamış
        }
        if (banner.endDate != null && now.isAfter(banner.endDate!)) {
          return false; // Süresi dolmuş
        }
        return true;
      })
      .toList();

  return banners;
});

/// Rental banner'ları
final rentalBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return ref.watch(bannersByCategoryProvider('rental').future);
});

/// Food banner'ları
final foodBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return ref.watch(bannersByCategoryProvider('food').future);
});

/// Store banner'ları
final storeBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return ref.watch(bannersByCategoryProvider('store').future);
});

/// Jobs banner'ları
final jobsBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return ref.watch(bannersByCategoryProvider('jobs').future);
});

/// Emlak banner'ları
final emlakBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return ref.watch(bannersByCategoryProvider('emlak').future);
});

/// Car Sales banner'ları
final carSalesBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return ref.watch(bannersByCategoryProvider('car_sales').future);
});

/// Market (Grocery) banner'ları
final marketBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return ref.watch(bannersByCategoryProvider('market').future);
});
