import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== RENTAL CARS ====================

final rentalCompanyCarsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, companyId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('rental_cars')
        .select('*, rental_locations(name, city)')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== BOOKINGS ====================

final rentalCompanyBookingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, companyId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('rental_bookings')
        .select('*, rental_cars(brand, model, plate_number, image_url), rental_locations!pickup_location_id(name), rental_locations!dropoff_location_id(name)')
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== LOCATIONS ====================

final rentalCompanyLocationsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, companyId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('rental_locations')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== PACKAGES & SERVICES ====================

final rentalCompanyPackagesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, companyId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('rental_packages')
        .select()
        .eq('company_id', companyId)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  },
);

final rentalCompanyServicesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, companyId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('rental_services')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  },
);

// ==================== FINANCE ====================

typedef RentalFinanceParams = ({String companyId, String period});

final rentalCompanyFinanceProvider = FutureProvider.family<Map<String, dynamic>, RentalFinanceParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);

    final bookings = await client
        .from('rental_bookings')
        .select('total_amount, status, payment_status, payment_method, rental_days, created_at')
        .eq('company_id', params.companyId);
    final bookingList = List<Map<String, dynamic>>.from(bookings);

    double totalRevenue = 0;
    int completedCount = 0;
    int totalRentalDays = 0;
    for (final b in bookingList) {
      final status = b['status'] as String? ?? '';
      if (status == 'completed' || status == 'active') {
        totalRevenue += (b['total_amount'] as num?)?.toDouble() ?? 0;
        totalRentalDays += (b['rental_days'] as num?)?.toInt() ?? 0;
        if (status == 'completed') completedCount++;
      }
    }

    // Get company for commission rate
    final company = await client
        .from('rental_companies')
        .select('commission_rate')
        .eq('id', params.companyId)
        .maybeSingle();
    final commissionRate = (company?['commission_rate'] as num?)?.toDouble() ?? 15.0;
    final commission = totalRevenue * commissionRate / 100;

    return {
      'total_revenue': totalRevenue,
      'commission': commission,
      'commission_rate': commissionRate,
      'net_revenue': totalRevenue - commission,
      'completed_bookings': completedCount,
      'total_bookings': bookingList.length,
      'total_rental_days': totalRentalDays,
      'avg_booking_value': bookingList.isNotEmpty ? totalRevenue / bookingList.where((b) => b['status'] == 'completed' || b['status'] == 'active').length : 0,
      'bookings': bookingList,
    };
  },
);

// ==================== CALENDAR ====================

typedef RentalCalendarParams = ({String companyId, DateTime start, DateTime end});

final rentalCalendarBookingsProvider = FutureProvider.family<List<Map<String, dynamic>>, RentalCalendarParams>(
  (ref, params) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('rental_bookings')
        .select('*, rental_cars(brand, model, plate_number)')
        .eq('company_id', params.companyId)
        .gte('pickup_date', params.start.toIso8601String())
        .lte('dropoff_date', params.end.toIso8601String())
        .order('pickup_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  },
);
