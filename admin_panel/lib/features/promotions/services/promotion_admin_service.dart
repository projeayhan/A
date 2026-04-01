import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/log_service.dart';
import '../../../core/services/supabase_service.dart';

// ==================== MODELS ====================

/// Unified promotion request across all sectors.
class PromotionRequest {
  final String id;
  final String sector; // 'carSales' | 'realEstate' | 'jobs'
  final String listingId;
  final String listingTitle;
  final String merchantId;
  final String merchantName;
  final String promotionType; // 'featured' | 'premium'
  final int durationDays;
  final double amount;
  final String status; // 'pending' | 'active' | 'cancelled'
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? adminNote;

  const PromotionRequest({
    required this.id,
    required this.sector,
    required this.listingId,
    required this.listingTitle,
    required this.merchantId,
    required this.merchantName,
    required this.promotionType,
    required this.durationDays,
    required this.amount,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.approvedAt,
    this.adminNote,
  });

  String get promotionTypeLabel => promotionType == 'premium' ? 'Premium' : 'Öne Çıkar';
  String get statusLabel {
    switch (status) {
      case 'pending': return 'Bekliyor';
      case 'active': return 'Aktif';
      case 'expired': return 'Sona Erdi';
      case 'cancelled': return 'İptal';
      default: return status;
    }
  }
}

// ==================== SERVICE ====================

class PromotionAdminService {
  static final _client = SupabaseService.client;

  /// Fetch pending promotion requests across all three sectors.
  static Future<List<PromotionRequest>> getPendingRequests({
    String? sector,
    String? statusFilter, // 'pending' | 'active' | null (all)
  }) async {
    final results = <PromotionRequest>[];

    if (sector == null || sector == 'carSales') {
      results.addAll(await _getCarSalesRequests(statusFilter: statusFilter));
    }
    if (sector == null || sector == 'realEstate') {
      results.addAll(await _getRealEstateRequests(statusFilter: statusFilter));
    }
    if (sector == null || sector == 'jobs') {
      results.addAll(await _getJobRequests(statusFilter: statusFilter));
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  static Future<List<PromotionRequest>> _getCarSalesRequests({String? statusFilter}) async {
    try {
      var query = _client
          .from('car_listing_promotions')
          .select(
            'id, listing_id, user_id, promotion_type, duration_days, amount_paid, status, payment_status, created_at, started_at, expires_at',
          );

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      } else {
        query = query.inFilter('status', ['active', 'expired', 'cancelled']);
      }

      final response = await query.order('created_at', ascending: false).limit(200);

      return (response as List).map((row) {
        return PromotionRequest(
          id: row['id'] as String,
          sector: 'carSales',
          listingId: row['listing_id'] as String,
          listingTitle: 'Araç İlanı',
          merchantId: row['user_id'] as String,
          merchantName: 'Galeri',
          promotionType: row['promotion_type'] as String,
          durationDays: row['duration_days'] as int,
          amount: (row['amount_paid'] as num?)?.toDouble() ?? 0,
          status: row['status'] as String,
          paymentStatus: row['payment_status'] as String? ?? 'pending',
          createdAt: DateTime.parse(row['created_at'] as String),
          approvedAt: row['started_at'] != null ? DateTime.parse(row['started_at'] as String) : null,
          adminNote: null,
        );
      }).toList();
    } catch (e, st) {
      LogService.error('Failed to fetch car sales promotion requests', error: e, stackTrace: st, source: 'promotion_admin_service:_getCarSalesRequests');
      return [];
    }
  }

  static Future<List<PromotionRequest>> _getRealEstateRequests({String? statusFilter}) async {
    try {
      var query = _client
          .from('property_promotions')
          .select(
            'id, property_id, user_id, promotion_type, duration_days, amount_paid, status, payment_status, created_at, started_at, expires_at',
          );

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      } else {
        query = query.inFilter('status', ['active', 'expired', 'cancelled']);
      }

      final response = await query.order('created_at', ascending: false).limit(200);

      return (response as List).map((row) {
        return PromotionRequest(
          id: row['id'] as String,
          sector: 'realEstate',
          listingId: row['property_id'] as String,
          listingTitle: 'Emlak İlanı',
          merchantId: row['user_id'] as String,
          merchantName: 'Emlakçı',
          promotionType: row['promotion_type'] as String,
          durationDays: row['duration_days'] as int,
          amount: (row['amount_paid'] as num?)?.toDouble() ?? 0,
          status: row['status'] as String,
          paymentStatus: row['payment_status'] as String? ?? 'pending',
          createdAt: DateTime.parse(row['created_at'] as String),
          approvedAt: row['started_at'] != null ? DateTime.parse(row['started_at'] as String) : null,
          adminNote: null,
        );
      }).toList();
    } catch (e, st) {
      LogService.error('Failed to fetch real estate promotion requests', error: e, stackTrace: st, source: 'promotion_admin_service:_getRealEstateRequests');
      return [];
    }
  }

  static Future<List<PromotionRequest>> _getJobRequests({String? statusFilter}) async {
    try {
      var query = _client
          .from('job_listing_promotions')
          .select(
            'id, listing_id, user_id, promotion_type, duration_days, amount_paid, status, payment_status, created_at, starts_at',
          );

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      } else {
        query = query.inFilter('status', ['active', 'expired', 'cancelled']);
      }

      final response = await query.order('created_at', ascending: false).limit(200);

      return (response as List).map((row) {
        return PromotionRequest(
          id: row['id'] as String,
          sector: 'jobs',
          listingId: row['listing_id'] as String,
          listingTitle: 'İş İlanı',
          merchantId: row['user_id'] as String,
          merchantName: 'Şirket',
          promotionType: row['promotion_type'] as String,
          durationDays: row['duration_days'] as int,
          amount: (row['amount_paid'] as num?)?.toDouble() ?? 0,
          status: row['status'] as String,
          paymentStatus: row['payment_status'] as String? ?? 'pending',
          createdAt: DateTime.parse(row['created_at'] as String),
          approvedAt: row['starts_at'] != null ? DateTime.parse(row['starts_at'] as String) : null,
          adminNote: null,
        );
      }).toList();
    } catch (e, st) {
      LogService.error('Failed to fetch job promotion requests', error: e, stackTrace: st, source: 'promotion_admin_service:_getJobRequests');
      return [];
    }
  }

  /// Approve a promotion request.
  static Future<void> approveRequest(String id, String sector) async {
    final now = DateTime.now();
    final adminId = _client.auth.currentUser?.id;

    if (sector == 'carSales') {
      // Fetch duration to calculate expiry
      final promo = await _client
          .from('car_listing_promotions')
          .select('duration_days, listing_id, promotion_type')
          .eq('id', id)
          .single();

      final durationDays = promo['duration_days'] as int;
      final expiresAt = now.add(Duration(days: durationDays));
      final promotionType = promo['promotion_type'] as String;

      await _client.from('car_listing_promotions').update({
        'status': 'active',
        'payment_status': 'completed',
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'approved_at': now.toIso8601String(),
        'approved_by': adminId,
      }).eq('id', id);

      // Update listing flags
      final listingId = promo['listing_id'] as String;
      final updateData = <String, dynamic>{
        'updated_at': now.toIso8601String(),
        'is_featured': true,
        'featured_until': expiresAt.toIso8601String(),
      };
      if (promotionType == 'premium') {
        updateData['is_premium'] = true;
        updateData['premium_until'] = expiresAt.toIso8601String();
      }
      await _client.from('car_listings').update(updateData).eq('id', listingId);

    } else if (sector == 'realEstate') {
      final promo = await _client
          .from('property_promotions')
          .select('duration_days, listing_id, promotion_type')
          .eq('id', id)
          .single();

      final durationDays = promo['duration_days'] as int;
      final expiresAt = now.add(Duration(days: durationDays));
      final promotionType = promo['promotion_type'] as String;

      await _client.from('property_promotions').update({
        'status': 'active',
        'payment_status': 'completed',
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'approved_at': now.toIso8601String(),
        'approved_by': adminId,
      }).eq('id', id);

      final listingId = promo['listing_id'] as String;
      final updateData = <String, dynamic>{
        'updated_at': now.toIso8601String(),
        'is_featured': true,
      };
      if (promotionType == 'premium') {
        updateData['is_premium'] = true;
      }
      await _client.from('property_listings').update(updateData).eq('id', listingId);

    } else if (sector == 'jobs') {
      final promo = await _client
          .from('job_listing_promotions')
          .select('duration_days, listing_id, promotion_type')
          .eq('id', id)
          .single();

      final durationDays = promo['duration_days'] as int;
      final expiresAt = now.add(Duration(days: durationDays));
      final promotionType = promo['promotion_type'] as String;

      await _client.from('job_listing_promotions').update({
        'status': 'active',
        'payment_status': 'completed',
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'approved_at': now.toIso8601String(),
        'approved_by': adminId,
      }).eq('id', id);

      final listingId = promo['listing_id'] as String;
      final updateData = <String, dynamic>{
        'updated_at': now.toIso8601String(),
        'is_featured': true,
      };
      if (promotionType == 'premium') {
        updateData['is_premium'] = true;
      }
      try {
        await _client.from('job_listings').update(updateData).eq('id', listingId);
      } catch (e, st) {
        LogService.error('Failed to update job listing flags after promotion approval', error: e, stackTrace: st, source: 'promotion_admin_service:approveRequest');
      }
    }
  }

  /// Reject a promotion request with an optional reason.
  static Future<void> rejectRequest(String id, String sector, {String? reason}) async {
    final adminId = _client.auth.currentUser?.id;
    final table = _tableForSector(sector);

    await _client.from(table).update({
      'status': 'cancelled',
      'payment_status': 'failed',
      'admin_note': reason,
      'approved_by': adminId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Cancel/deactivate an active promotion early.
  static Future<void> cancelPromotion(String id, String sector) async {
    final table = _tableForSector(sector);
    final data = <String, dynamic>{'status': 'cancelled'};
    if (sector != 'jobs') {
      data['cancelled_at'] = DateTime.now().toIso8601String();
      data['cancellation_reason'] = 'Admin tarafından sonlandırıldı';
    }
    await _client.from(table).update(data).eq('id', id);
  }

  /// Count pending requests across all sectors for badge display.
  static Future<int> countPending() async {
    try {
      int total = 0;
      for (final table in ['car_listing_promotions', 'property_promotions', 'job_listing_promotions']) {
        final result = await _client
            .from(table)
            .select('id')
            .eq('status', 'pending')
            .count();
        total += result.count;
      }
      return total;
    } catch (e, st) {
      LogService.error('Failed to count pending promotion requests', error: e, stackTrace: st, source: 'promotion_admin_service:countPending');
      return 0;
    }
  }

  static String _tableForSector(String sector) {
    switch (sector) {
      case 'carSales': return 'car_listing_promotions';
      case 'realEstate': return 'property_promotions';
      case 'jobs': return 'job_listing_promotions';
      default: return 'car_listing_promotions';
    }
  }
}

// ==================== STATS MODEL ====================

class PromotionStats {
  final int totalActive;
  final int totalPremium;
  final int totalFeatured;
  final int expiringSoon; // within 7 days
  final double totalRevenue;

  const PromotionStats({
    required this.totalActive,
    required this.totalPremium,
    required this.totalFeatured,
    required this.expiringSoon,
    required this.totalRevenue,
  });
}

// ==================== STATS SERVICE ====================

extension PromotionAdminServiceStats on PromotionAdminService {
  static Future<PromotionStats> getStats({String? sector}) async {
    final client = SupabaseService.client;
    final tables = sector != null
        ? [PromotionAdminService._tableForSector(sector)]
        : ['car_listing_promotions', 'property_promotions', 'job_listing_promotions'];

    int totalActive = 0;
    int totalPremium = 0;
    int expiringSoon = 0;
    double totalRevenue = 0;

    final soon = DateTime.now().add(const Duration(days: 7)).toIso8601String();

    for (final table in tables) {
      try {
        final rows = await client
            .from(table)
            .select('promotion_type, amount_paid, expires_at')
            .eq('status', 'active');
        for (final row in rows as List) {
          totalActive++;
          totalRevenue += (row['amount_paid'] as num?)?.toDouble() ?? 0;
          if (row['promotion_type'] == 'premium') totalPremium++;
          final exp = row['expires_at'] as String?;
          if (exp != null && exp.compareTo(soon) <= 0) expiringSoon++;
        }
      } catch (e, st) {
        LogService.error('Failed to fetch promotion stats for table: $table', error: e, stackTrace: st, source: 'promotion_admin_service:getStats');
      }
    }

    return PromotionStats(
      totalActive: totalActive,
      totalPremium: totalPremium,
      totalFeatured: totalActive - totalPremium,
      expiringSoon: expiringSoon,
      totalRevenue: totalRevenue,
    );
  }
}

// ==================== PROVIDERS ====================

// param format: "sector:statusFilter" e.g. "carSales:active" or "carSales:all"
final promotionRequestsProvider = FutureProvider.family<List<PromotionRequest>, String>(
  (ref, param) {
    final parts = param.split(':');
    final sector = parts[0].isEmpty ? null : parts[0];
    final statusFilter = parts.length > 1 && parts[1] != 'all' ? parts[1] : null;
    return PromotionAdminService.getPendingRequests(
      sector: sector,
      statusFilter: statusFilter,
    );
  },
);

final promotionStatsProvider = FutureProvider.family<PromotionStats, String?>(
  (ref, sector) => PromotionAdminServiceStats.getStats(sector: sector),
);

final pendingPromotionCountProvider = FutureProvider<int>(
  (_) => PromotionAdminService.countPending(),
);
