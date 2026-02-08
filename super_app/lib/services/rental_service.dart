import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RentalService {
  static final RentalService _instance = RentalService._internal();
  factory RentalService() => _instance;
  RentalService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ==================== LOCATIONS ====================

  /// Get all active rental locations
  Future<List<Map<String, dynamic>>> getLocations({String? city}) async {
    var query = _client
        .from('rental_locations')
        .select('*, rental_companies(company_name, logo_url)')
        .eq('is_active', true);

    if (city != null) {
      query = query.eq('city', city);
    }

    final response = await query.order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get unique cities with rental locations
  Future<List<String>> getCities() async {
    final response = await _client
        .from('rental_locations')
        .select('city')
        .eq('is_active', true);

    final cities = <String>{};
    for (final row in response) {
      if (row['city'] != null) {
        cities.add(row['city'] as String);
      }
    }
    return cities.toList()..sort();
  }

  // ==================== CARS ====================

  /// Get available cars for date range
  Future<List<Map<String, dynamic>>> getAvailableCars({
    required DateTime pickupDate,
    required DateTime dropoffDate,
    String? city,
    String? category,
    double? minPrice,
    double? maxPrice,
  }) async {
    final response = await _client.rpc(
      'get_available_rental_cars',
      params: {
        'p_pickup_date': pickupDate.toIso8601String(),
        'p_dropoff_date': dropoffDate.toIso8601String(),
        'p_city': city,
        'p_category': category,
        'p_min_price': minPrice,
        'p_max_price': maxPrice,
      },
    );

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get car details by ID
  Future<Map<String, dynamic>?> getCarDetails(String carId) async {
    final response = await _client
        .from('rental_cars')
        .select('''
          *,
          rental_companies(id, company_name, logo_url, rating, phone, email),
          rental_locations(id, name, address, city, is_airport, is_24_hours)
        ''')
        .eq('id', carId)
        .maybeSingle();

    return response;
  }

  /// Get cars by company
  Future<List<Map<String, dynamic>>> getCarsByCompany(String companyId) async {
    final response = await _client
        .from('rental_cars')
        .select('*, rental_locations(name, city)')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('daily_price');

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== COMPANIES ====================

  /// Get approved rental companies
  Future<List<Map<String, dynamic>>> getCompanies({String? city}) async {
    var query = _client
        .from('rental_companies')
        .select('*')
        .eq('is_approved', true)
        .eq('is_active', true);

    if (city != null) {
      query = query.eq('city', city);
    }

    final response = await query.order('rating', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get company details
  Future<Map<String, dynamic>?> getCompanyDetails(String companyId) async {
    final response = await _client
        .from('rental_companies')
        .select('*')
        .eq('id', companyId)
        .maybeSingle();

    return response;
  }

  // ==================== SERVICES ====================

  /// Get packages for a company
  Future<List<Map<String, dynamic>>> getCompanyPackages(String companyId) async {
    final response = await _client
        .from('rental_packages')
        .select('*')
        .eq('company_id', companyId)
        .eq('is_active', true)
        .order('sort_order');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get additional services for a company
  Future<List<Map<String, dynamic>>> getCompanyServices(String companyId) async {
    final response = await _client
        .from('rental_services')
        .select('*')
        .eq('company_id', companyId)
        .eq('is_active', true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== BOOKINGS ====================

  /// Create a new booking
  Future<Map<String, dynamic>?> createBooking({
    required String carId,
    required String companyId,
    String? pickupLocationId,
    String? dropoffLocationId,
    required DateTime pickupDate,
    required DateTime dropoffDate,
    required double dailyRate,
    required int rentalDays,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    String? driverLicenseNo,
    DateTime? driverLicenseExpiry,
    List<Map<String, dynamic>>? selectedServices,
    double? servicesTotal,
    double? insuranceTotal,
    double? depositAmount,
    String? customerNotes,
    String? paymentMethod,
    // Package fields
    String? packageId,
    String? packageTier,
    String? packageName,
    double? packageDailyPrice,
    // Custom address fields
    bool isPickupCustomAddress = false,
    String? pickupCustomAddress,
    String? pickupCustomAddressNotes,
    bool isDropoffCustomAddress = false,
    String? dropoffCustomAddress,
    String? dropoffCustomAddressNotes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final data = {
      'user_id': userId,
      'car_id': carId,
      'company_id': companyId,
      'pickup_location_id': pickupLocationId,
      'dropoff_location_id': dropoffLocationId,
      'pickup_date': pickupDate.toIso8601String(),
      'dropoff_date': dropoffDate.toIso8601String(),
      'daily_rate': dailyRate,
      'rental_days': rentalDays,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'driver_license_no': driverLicenseNo,
      'driver_license_expiry': driverLicenseExpiry?.toIso8601String(),
      'selected_services': selectedServices ?? [],
      'services_total': servicesTotal ?? 0,
      'insurance_total': insuranceTotal ?? 0,
      'deposit_amount': depositAmount ?? 0,
      'customer_notes': customerNotes,
      'payment_method': paymentMethod ?? 'card',
      'package_id': packageId,
      'package_tier': packageTier,
      'package_name': packageName,
      'package_daily_price': packageDailyPrice ?? 0,
      'status': 'pending',
      'payment_status': 'pending',
      // Custom address fields
      'is_pickup_custom_address': isPickupCustomAddress,
      'pickup_custom_address': pickupCustomAddress,
      'pickup_custom_address_notes': pickupCustomAddressNotes,
      'is_dropoff_custom_address': isDropoffCustomAddress,
      'dropoff_custom_address': dropoffCustomAddress,
      'dropoff_custom_address_notes': dropoffCustomAddressNotes,
    };

    final response = await _client
        .from('rental_bookings')
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Get user's bookings
  Future<List<Map<String, dynamic>>> getUserBookings({
    String? status,
    int limit = 50,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return [];
    }

    var query = _client
        .from('rental_bookings')
        .select('''
          *,
          rental_cars(brand, model, year, image_url, category),
          rental_companies(company_name, logo_url, phone),
          pickup_location:rental_locations!pickup_location_id(name, address, city),
          dropoff_location:rental_locations!dropoff_location_id(name, address, city)
        ''')
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get booking details
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    final response = await _client
        .from('rental_bookings')
        .select('''
          *,
          rental_cars(*),
          rental_companies(company_name, logo_url, phone, email),
          pickup_location:rental_locations!pickup_location_id(*),
          dropoff_location:rental_locations!dropoff_location_id(*)
        ''')
        .eq('id', bookingId)
        .maybeSingle();

    return response;
  }

  /// Cancel a booking
  Future<bool> cancelBooking(String bookingId, String reason) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return false;
    }

    try {
      await _client
          .from('rental_bookings')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason,
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId)
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'confirmed']);

      return true;
    } catch (e) {
      if (kDebugMode) print('Error cancelling booking: $e');
      return false;
    }
  }

  // ==================== REVIEWS ====================

  /// Create a review for a completed booking
  Future<bool> createReview({
    required String bookingId,
    required String companyId,
    required String carId,
    required int overallRating,
    int? carConditionRating,
    int? cleanlinessRating,
    int? serviceRating,
    int? valueRating,
    String? comment,
    List<String>? pros,
    List<String>? cons,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return false;
    }

    try {
      await _client.from('rental_reviews').insert({
        'booking_id': bookingId,
        'company_id': companyId,
        'car_id': carId,
        'user_id': userId,
        'overall_rating': overallRating,
        'car_condition_rating': carConditionRating,
        'cleanliness_rating': cleanlinessRating,
        'service_rating': serviceRating,
        'value_rating': valueRating,
        'comment': comment,
        'pros': pros,
        'cons': cons,
      });

      return true;
    } catch (e) {
      if (kDebugMode) print('Error creating review: $e');
      return false;
    }
  }

  /// Get reviews for a company
  Future<List<Map<String, dynamic>>> getCompanyReviews(
    String companyId, {
    int limit = 20,
  }) async {
    final response = await _client
        .from('rental_reviews')
        .select('*, rental_cars(brand, model)')
        .eq('company_id', companyId)
        .eq('is_approved', true)
        .eq('is_hidden', false)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Check if user has already reviewed a booking
  Future<bool> hasReviewedBooking(String bookingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return false;
    }

    final response = await _client
        .from('rental_reviews')
        .select('id')
        .eq('booking_id', bookingId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  // ==================== REALTIME ====================

  /// Subscribe to booking status changes
  Stream<Map<String, dynamic>> subscribeToBooking(String bookingId) {
    return _client
        .from('rental_bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .map((list) => list.isNotEmpty ? list.first : {});
  }

  /// Subscribe to all user bookings
  Stream<List<Map<String, dynamic>>> subscribeToUserBookings() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _client
        .from('rental_bookings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);
  }
}
