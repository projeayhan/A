import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== PROPERTY LISTINGS ====================

final realtorPropertiesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, realtorId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('properties')
        .select()
        .eq('user_id', realtorId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== CRM ====================

final realtorClientsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, realtorId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('realtor_clients')
        .select()
        .eq('realtor_id', realtorId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== APPOINTMENTS ====================

final realtorAppointmentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, realtorId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('appointments')
        .select('*, properties(title, city, district, images)')
        .eq('owner_id', realtorId)
        .order('appointment_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== ANALYTICS ====================

typedef EmlakAnalyticsParams = ({String realtorId, int days});

final realtorAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, EmlakAnalyticsParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);

    // Get properties
    final properties = await client
        .from('properties')
        .select('id, title, status, view_count, favorite_count, price, city, created_at')
        .eq('user_id', params.realtorId);
    final propList = List<Map<String, dynamic>>.from(properties);

    int totalViews = 0;
    int totalFavorites = 0;
    int activeCount = 0;
    int soldCount = 0;
    int rentedCount = 0;
    for (final p in propList) {
      totalViews += (p['view_count'] as num?)?.toInt() ?? 0;
      totalFavorites += (p['favorite_count'] as num?)?.toInt() ?? 0;
      final status = p['status'] as String? ?? '';
      if (status == 'active') activeCount++;
      if (status == 'sold') soldCount++;
      if (status == 'rented') rentedCount++;
    }

    // Sort by views for top properties
    final sortedByViews = List<Map<String, dynamic>>.from(propList)
      ..sort((a, b) => ((b['view_count'] as num?) ?? 0).compareTo((a['view_count'] as num?) ?? 0));

    return {
      'total_properties': propList.length,
      'active_count': activeCount,
      'sold_count': soldCount,
      'rented_count': rentedCount,
      'total_views': totalViews,
      'total_favorites': totalFavorites,
      'top_properties': sortedByViews.take(10).toList(),
      'properties': propList,
    };
  },
);
