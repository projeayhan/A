import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== RIDES ====================

final driverRidesProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String driverId, String? status, int? days})>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);
    var query = client
        .from('taxi_rides')
        .select('*')
        .eq('driver_id', params.driverId);

    if (params.status != null && params.status != 'all') {
      query = query.eq('status', params.status!);
    }

    if (params.days != null) {
      final fromDate = DateTime.now().subtract(Duration(days: params.days!));
      query = query.gte('created_at', fromDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== EARNINGS ====================

final driverEarningsProvider = FutureProvider.family<Map<String, dynamic>, ({String driverId, String period})>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);

    int days;
    switch (params.period) {
      case 'week':
        days = 7;
      case 'month':
        days = 30;
      case 'quarter':
        days = 90;
      case 'year':
        days = 365;
      default:
        days = 30;
    }

    final fromDate = DateTime.now().subtract(Duration(days: days));

    final rides = await client
        .from('taxi_rides')
        .select('fare, tip_amount, status, created_at')
        .eq('driver_id', params.driverId)
        .eq('status', 'completed')
        .gte('created_at', fromDate.toIso8601String())
        .order('created_at', ascending: true);

    final rideList = List<Map<String, dynamic>>.from(rides);

    double totalFare = 0;
    double totalTips = 0;
    Map<String, double> dailyEarnings = {};

    for (final ride in rideList) {
      final fare = (ride['fare'] as num?)?.toDouble() ?? 0;
      final tip = (ride['tip_amount'] as num?)?.toDouble() ?? 0;
      totalFare += fare;
      totalTips += tip;

      final date = DateTime.parse(ride['created_at']).toLocal();
      final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyEarnings[dayKey] = (dailyEarnings[dayKey] ?? 0) + fare + tip;
    }

    // Driver stats from profile
    final driverData = await client
        .from('taxi_drivers')
        .select('total_earnings, total_rides, rating')
        .eq('id', params.driverId)
        .maybeSingle();

    final commissionRate = 0.20; // Default commission rate
    final commission = totalFare * commissionRate;
    final netEarnings = totalFare - commission + totalTips;

    // Tolls are stored in payments table, not available here
    double totalTolls = 0;

    return {
      'total_fare': totalFare,
      'total_tips': totalTips,
      'total_tolls': totalTolls,
      'commission': commission,
      'commission_rate': commissionRate,
      'net_earnings': netEarnings,
      'ride_count': rideList.length,
      'daily_earnings': dailyEarnings,
      'all_time_earnings': (driverData?['total_earnings'] as num?)?.toDouble() ?? 0,
      'all_time_rides': driverData?['total_rides'] ?? 0,
      'rating': (driverData?['rating'] as num?)?.toDouble() ?? 0,
    };
  },
);

// ==================== DRIVER DETAIL ====================

final driverDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, driverId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('taxi_drivers')
        .select('*')
        .eq('id', driverId)
        .maybeSingle();
    return response;
  },
);

// ==================== DRIVER DOCUMENTS ====================
// Uses partner_documents table (driver_documents doesn't exist).
// partner_documents uses application_id, so we first look up the partner application
// for the given driver, then fetch documents by application_id.

final driverDocumentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, driverId) async {
    final client = ref.watch(supabaseProvider);

    // Look up the partner application for this driver
    final application = await client
        .from('partner_applications')
        .select('id')
        .eq('user_id', driverId)
        .order('created_at', ascending: false)
        .maybeSingle();

    if (application == null) {
      return <Map<String, dynamic>>[];
    }

    final response = await client
        .from('partner_documents')
        .select('*')
        .eq('application_id', application['id'] as String)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== RIDE EARNINGS HISTORY ====================

final rideEarningsHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String driverId, String period})>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);

    int days;
    switch (params.period) {
      case 'week':
        days = 7;
      case 'month':
        days = 30;
      case 'quarter':
        days = 90;
      case 'year':
        days = 365;
      default:
        days = 30;
    }

    final fromDate = DateTime.now().subtract(Duration(days: days));

    final rides = await client
        .from('taxi_rides')
        .select('id, fare, tip_amount, distance_km, duration_minutes, pickup_address, dropoff_address, created_at, completed_at')
        .eq('driver_id', params.driverId)
        .eq('status', 'completed')
        .gte('created_at', fromDate.toIso8601String())
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rides);
  },
);
