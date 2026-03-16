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

    // Status filter
    if (statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    // Search
    if (searchQuery.isNotEmpty) {
      query = query.or('name.ilike.%$searchQuery%,email.ilike.%$searchQuery%,phone.ilike.%$searchQuery%');
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
    return response;
  }

  /// İşletme istatistiklerini getirir
  Future<Map<String, dynamic>> fetchBusinessStats({
    required SectorType sector,
    required String id,
  }) async {
    // Placeholder - sektöre göre farklı istatistikler dönecek
    return {
      'totalOrders': 0,
      'totalRevenue': 0.0,
      'avgRating': 0.0,
      'reviewCount': 0,
    };
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
