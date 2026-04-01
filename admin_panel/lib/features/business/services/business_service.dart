import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/sector_type.dart';
import '../../../core/services/supabase_service.dart';

/// Sektör bazlı işletme veri servisi
class BusinessService {
  final SupabaseClient _client;

  BusinessService(this._client);

  /// İşletme listesini getirir
  Future<({List<Map<String, dynamic>> data, int totalCount})> fetchBusinesses({
    required SectorType sector,
    String searchQuery = '',
    String statusFilter = 'all',
    int page = 0,
    int pageSize = 25,
  }) async {
    var query = _client.from(sector.tableName).select();

    // Shared table filter (food/market/store share merchants table)
    if (sector.merchantTypeFilter != null) {
      query = query.eq('type', sector.merchantTypeFilter!);
    }

    // Status filter - merchants tablosunda status yok, is_approved kullanıyor
    if (statusFilter != 'all') {
      if (sector == SectorType.food || sector == SectorType.market || sector == SectorType.store) {
        // merchants: is_approved boolean
        if (statusFilter == 'active') {
          query = query.eq('is_approved', true);
        } else if (statusFilter == 'inactive') {
          query = query.eq('is_approved', false);
        }
      } else {
        query = query.eq('status', statusFilter);
      }
    }

    // Search
    if (searchQuery.isNotEmpty) {
      final nameCol = sector.nameField;
      query = query.or('$nameCol.ilike.%$searchQuery%,email.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
    }

    // Pagination & ordering
    final response = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final data = List<Map<String, dynamic>>.from(response);

    return (
      data: data,
      totalCount: data.length < pageSize ? page * pageSize + data.length : (page + 1) * pageSize + 1,
    );
  }

  /// Tek işletme detayını getirir
  Future<Map<String, dynamic>?> fetchBusinessDetail({
    required SectorType sector,
    required String id,
  }) async {
    final response = await _client
        .from(sector.tableName)
        .select()
        .eq(sector.idField, id)
        .maybeSingle();

    if (response == null) return null;

    // Reviews tablosundan canlı puan ortalaması hesapla
    try {
      final reviewTable = sector.reviewTableName;
      final merchantCol = sector.reviewMerchantColumn;
      if (reviewTable != null && merchantCol != null) {
        final reviews = await _client
            .from(reviewTable)
            .select('rating')
            .eq(merchantCol, id);
        final reviewList = List<Map<String, dynamic>>.from(reviews);
        if (reviewList.isNotEmpty) {
          double total = 0;
          for (final r in reviewList) {
            total += (r['rating'] as num?)?.toDouble() ?? 0;
          }
          response['_live_rating'] = total / reviewList.length;
          response['_live_review_count'] = reviewList.length;
        }
      }
    } catch (_) {
      // reviews tablosu yoksa veya hata olursa sessizce devam et
    }

    return response;
  }

  /// İşletme istatistiklerini getirir
  Future<Map<String, dynamic>> fetchBusinessStats({
    required SectorType sector,
    required String id,
  }) async {
    // Fetch real stats from the business record
    final record = await _client
        .from(sector.tableName)
        .select()
        .eq(sector.idField, id)
        .maybeSingle();

    if (record == null) {
      return {
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'avgRating': 0.0,
        'reviewCount': 0,
      };
    }

    switch (sector) {
      case SectorType.food:
      case SectorType.market:
      case SectorType.store:
        return {
          'totalOrders': (record['total_orders'] as num?)?.toInt() ?? 0,
          'totalRevenue': 0.0,
          'avgRating': (record['rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': (record['review_count'] as num?)?.toInt() ?? 0,
        };
      case SectorType.taxi:
        return {
          'totalOrders': (record['total_rides'] as num?)?.toInt() ?? 0,
          'totalRevenue': (record['total_earnings'] as num?)?.toDouble() ?? 0.0,
          'avgRating': (record['rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': 0,
        };
      case SectorType.carRental:
        return {
          'totalOrders': (record['total_bookings'] as num?)?.toInt() ?? 0,
          'totalRevenue': 0.0,
          'avgRating': (record['rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': (record['review_count'] as num?)?.toInt() ?? 0,
        };
      case SectorType.realEstate:
        return {
          'totalOrders': ((record['total_sales'] as num?)?.toInt() ?? 0) + ((record['total_rentals'] as num?)?.toInt() ?? 0),
          'totalRevenue': 0.0,
          'avgRating': (record['average_rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': (record['total_reviews'] as num?)?.toInt() ?? 0,
        };
      case SectorType.carSales:
        return {
          'totalOrders': (record['total_listings'] as num?)?.toInt() ?? 0,
          'totalRevenue': 0.0,
          'avgRating': (record['average_rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': (record['total_reviews'] as num?)?.toInt() ?? 0,
        };
      case SectorType.jobs:
        return {
          'totalOrders': (record['active_listings'] as num?)?.toInt() ?? 0,
          'totalRevenue': 0.0,
          'avgRating': 0.0,
          'reviewCount': 0,
        };
    }
  }
}

/// BusinessService provider
final businessServiceProvider = Provider<BusinessService>((ref) {
  final client = ref.watch(supabaseProvider);
  return BusinessService(client);
});

/// İşletme listesi provider - sector bazlı
final businessListProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int totalCount}),
    ({SectorType sector, String search, String status, int page, int pageSize})>(
  (ref, params) {
    final service = ref.watch(businessServiceProvider);
    return service.fetchBusinesses(
      sector: params.sector,
      searchQuery: params.search,
      statusFilter: params.status,
      page: params.page,
      pageSize: params.pageSize,
    );
  },
);

/// Tek işletme detay provider
final businessDetailProvider = FutureProvider.family<Map<String, dynamic>?, ({SectorType sector, String id})>(
  (ref, params) {
    final service = ref.watch(businessServiceProvider);
    return service.fetchBusinessDetail(sector: params.sector, id: params.id);
  },
);
