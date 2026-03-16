import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== CAR LISTINGS ====================

final dealerCarListingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, dealerId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('car_listings')
        .select()
        .eq('dealer_id', dealerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== PERFORMANCE ====================

typedef CarPerformanceParams = ({String dealerId, String period});

final dealerPerformanceProvider = FutureProvider.family<Map<String, dynamic>, CarPerformanceParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);

    final listings = await client
        .from('car_listings')
        .select('id, title, brand_name, model_name, year, price, status, view_count, favorite_count, contact_count, city, created_at, sold_at, published_at')
        .eq('dealer_id', params.dealerId);
    final listingList = List<Map<String, dynamic>>.from(listings);

    int totalViews = 0;
    int totalFavorites = 0;
    int totalContacts = 0;
    int activeCount = 0;
    int soldCount = 0;
    int pendingCount = 0;
    for (final l in listingList) {
      totalViews += (l['view_count'] as num?)?.toInt() ?? 0;
      totalFavorites += (l['favorite_count'] as num?)?.toInt() ?? 0;
      totalContacts += (l['contact_count'] as num?)?.toInt() ?? 0;
      final status = l['status'] as String? ?? '';
      if (status == 'active') activeCount++;
      if (status == 'sold') soldCount++;
      if (status == 'pending') pendingCount++;
    }

    // Calculate average sell speed for sold items
    double avgSellDays = 0;
    int soldWithDates = 0;
    for (final l in listingList) {
      if (l['status'] == 'sold' && l['published_at'] != null && l['sold_at'] != null) {
        final published = DateTime.tryParse(l['published_at'] as String);
        final sold = DateTime.tryParse(l['sold_at'] as String);
        if (published != null && sold != null) {
          avgSellDays += sold.difference(published).inDays;
          soldWithDates++;
        }
      }
    }
    if (soldWithDates > 0) avgSellDays = avgSellDays / soldWithDates;

    final sortedByViews = List<Map<String, dynamic>>.from(listingList)
      ..sort((a, b) => ((b['view_count'] as num?) ?? 0).compareTo((a['view_count'] as num?) ?? 0));

    return {
      'total_listings': listingList.length,
      'active_count': activeCount,
      'sold_count': soldCount,
      'pending_count': pendingCount,
      'total_views': totalViews,
      'total_favorites': totalFavorites,
      'total_contacts': totalContacts,
      'avg_sell_days': avgSellDays.round(),
      'top_listings': sortedByViews.take(10).toList(),
      'listings': listingList,
    };
  },
);
