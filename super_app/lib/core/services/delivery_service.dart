import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../utils/cache_helper.dart';

class DeliveryEstimate {
  final bool canDeliver;
  final String? zoneName;
  final double deliveryFee;
  final double minOrderAmount;
  final double distanceKm;
  final int estimatedMinutes;
  final bool freeDeliveryEligible;
  final String? errorMessage;

  const DeliveryEstimate({
    required this.canDeliver,
    this.zoneName,
    required this.deliveryFee,
    required this.minOrderAmount,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.freeDeliveryEligible,
    this.errorMessage,
  });
}

class DeliveryService {
  static final _cache = CacheManager();

  static Future<DeliveryEstimate?> getDeliveryEstimate({
    required String merchantId,
    required double customerLat,
    required double customerLon,
    double subtotal = 0,
  }) async {
    // Cache key includes all params to ensure unique estimates
    final cacheKey = 'delivery_${merchantId}_${customerLat.toStringAsFixed(4)}_${customerLon.toStringAsFixed(4)}_${subtotal.toStringAsFixed(0)}';
    return _cache.getOrFetch<DeliveryEstimate?>(
      cacheKey,
      ttl: const Duration(minutes: 10),
      fetcher: () async {
        try {
          final result = await SupabaseService.client.rpc(
            'get_delivery_fee_estimate',
            params: {
              'p_merchant_id': merchantId,
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
              'p_subtotal': subtotal,
            },
          );

          if (result == null || (result as List).isEmpty) return null;

          final data = result[0] as Map<String, dynamic>;

          return DeliveryEstimate(
            canDeliver: data['can_deliver'] as bool? ?? false,
            zoneName: data['zone_name'] as String?,
            deliveryFee: (data['delivery_fee'] as num?)?.toDouble() ?? 0,
            minOrderAmount: (data['min_order_amount'] as num?)?.toDouble() ?? 0,
            distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0,
            estimatedMinutes: (data['estimated_delivery_min'] as num?)?.toInt() ?? 0,
            freeDeliveryEligible: data['free_delivery_eligible'] as bool? ?? false,
            errorMessage: data['error_message'] as String?,
          );
        } catch (e) {
          debugPrint('DeliveryService.getDeliveryEstimate error: $e');
          return null;
        }
      },
    );
  }
}
