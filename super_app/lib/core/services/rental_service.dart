import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../../models/rental/rental_models.dart';

class RentalService {
  static final _client = SupabaseService.client;

  /// Tüm kiralama şirketlerinin aktif araçlarını getirir
  static Future<List<RentalCar>> getAvailableCars({
    CarCategory? category,
    String? locationId,
  }) async {
    try {
      var query = _client
          .from('rental_cars')
          .select('''
            *,
            rental_companies(id, company_name, logo_url, rating, review_count),
            rental_locations(id, name, city)
          ''')
          .eq('is_active', true)
          .eq('status', 'available');

      if (category != null) {
        query = query.eq('category', _categoryToString(category));
      }

      if (locationId != null) {
        query = query.eq('location_id', locationId);
      }

      final response = await query.order('daily_price');

      return (response as List).map((car) => _mapToRentalCar(car)).toList();
    } catch (e) {
      debugPrint('Error fetching cars: $e');
      return [];
    }
  }

  /// Belirli tarihlerde müsait araçları getirir (rezervasyon çakışması kontrolü ile)
  static Future<List<RentalCar>> getAvailableCarsForDates({
    required DateTime pickupDate,
    required DateTime dropoffDate,
    CarCategory? category,
    String? locationId,
  }) async {
    try {
      // Önce tüm aktif araçları getir
      final cars = await getAvailableCars(category: category, locationId: locationId);

      if (cars.isEmpty) return [];

      // Seçilen tarihlerde çakışan rezervasyonları getir
      final conflictingBookings = await _client
          .from('rental_bookings')
          .select('car_id')
          .neq('status', 'cancelled')
          .neq('status', 'completed')
          .lte('pickup_date', dropoffDate.toIso8601String())
          .gte('dropoff_date', pickupDate.toIso8601String());

      final bookedCarIds = (conflictingBookings as List)
          .map((b) => b['car_id'] as String)
          .toSet();

      // Çakışan rezervasyonu olmayan araçları filtrele
      return cars.where((car) => !bookedCarIds.contains(car.id)).toList();
    } catch (e) {
      debugPrint('Error fetching available cars for dates: $e');
      return [];
    }
  }

  /// Araç detayını getirir
  static Future<RentalCar?> getCarById(String carId) async {
    try {
      final response = await _client
          .from('rental_cars')
          .select('''
            *,
            rental_companies(id, company_name, logo_url, rating, review_count),
            rental_locations(id, name, city)
          ''')
          .eq('id', carId)
          .maybeSingle();

      if (response == null) return null;
      return _mapToRentalCar(response);
    } catch (e) {
      debugPrint('Error fetching car: $e');
      return null;
    }
  }

  /// Tüm lokasyonları getirir
  static Future<List<RentalLocation>> getLocations() async {
    try {
      final response = await _client
          .from('rental_locations')
          .select('*')
          .eq('is_active', true)
          .order('name');

      return (response as List).map((loc) => RentalLocation(
        id: loc['id'],
        name: loc['name'] ?? '',
        address: loc['address'] ?? '',
        latitude: (loc['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (loc['longitude'] as num?)?.toDouble() ?? 0,
        phone: loc['phone'] ?? '',
        workingHours: loc['working_hours'] ?? '08:00 - 20:00',
        isAirport: loc['is_airport'] ?? false,
        is24Hours: loc['is_24_hours'] ?? false,
      )).toList();
    } catch (e) {
      debugPrint('Error fetching locations: $e');
      return [];
    }
  }

  /// Rezervasyon oluşturur
  static Future<String?> createBooking({
    required String carId,
    required String companyId,
    required String pickupLocationId,
    required String dropoffLocationId,
    required DateTime pickupDate,
    required DateTime dropoffDate,
    required String packageId,
    required List<String> additionalServices,
    required double totalPrice,
    required double depositAmount,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? driverLicenseNo,
    String? notes,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Rezervasyon numarası oluştur
      final bookingNumber = 'BK-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // Kiralama gün sayısı
      final rentalDays = dropoffDate.difference(pickupDate).inDays;
      if (rentalDays < 1) throw Exception('Invalid rental period');

      final response = await _client.from('rental_bookings').insert({
        'car_id': carId,
        'company_id': companyId,
        'user_id': userId,
        'pickup_location_id': pickupLocationId,
        'dropoff_location_id': dropoffLocationId,
        'pickup_date': pickupDate.toIso8601String(),
        'dropoff_date': dropoffDate.toIso8601String(),
        'rental_days': rentalDays,
        'daily_rate': totalPrice / rentalDays,
        'subtotal': totalPrice,
        'total_amount': totalPrice,
        'net_amount': totalPrice,
        'deposit_amount': depositAmount,
        'status': 'pending', // Şirket onayı bekliyor
        'payment_status': 'pending',
        'booking_number': bookingNumber,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'driver_license_no': driverLicenseNo,
        'customer_notes': notes,
      }).select('id').single();

      return response['id'] as String;
    } catch (e) {
      debugPrint('Error creating booking: $e');
      return null;
    }
  }

  /// Kullanıcının rezervasyonlarını getirir
  static Future<List<RentalBooking>> getMyBookings() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('rental_bookings')
          .select('''
            *,
            rental_cars(brand, model, plate, image_url),
            pickup_location:rental_locations!pickup_location_id(name, city),
            dropoff_location:rental_locations!dropoff_location_id(name, city)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((b) => _mapToRentalBooking(b)).toList();
    } catch (e) {
      debugPrint('Error fetching bookings: $e');
      return [];
    }
  }

  /// Rezervasyonu iptal eder
  static Future<bool> cancelBooking(String bookingId, String reason) async {
    try {
      await _client.from('rental_bookings').update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', bookingId);

      return true;
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      return false;
    }
  }

  // Helper: Map database row to RentalCar model
  static RentalCar _mapToRentalCar(Map<String, dynamic> car) {
    final company = car['rental_companies'] as Map<String, dynamic>?;

    return RentalCar(
      id: car['id'],
      brandId: car['brand']?.toString().toLowerCase() ?? '',
      brandName: car['brand'] ?? '',
      model: car['model'] ?? '',
      year: car['year'] ?? DateTime.now().year,
      category: _stringToCategory(car['category']),
      transmission: car['transmission'] == 'automatic'
          ? TransmissionType.automatic
          : TransmissionType.manual,
      fuelType: _stringToFuelType(car['fuel_type']),
      seats: car['seats'] ?? 5,
      doors: car['doors'] ?? 4,
      luggage: car['luggage_capacity'] ?? 2,
      dailyPrice: (car['daily_price'] as num?)?.toDouble() ?? 0,
      weeklyPrice: (car['daily_price'] as num?)?.toDouble() ?? 0 * 6,
      monthlyPrice: (car['daily_price'] as num?)?.toDouble() ?? 0 * 25,
      imageUrls: car['image_url'] != null ? [car['image_url']] : [],
      thumbnailUrl: car['image_url'] ?? '',
      featureIds: _parseFeatures(car['features']),
      rating: (company?['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (company?['review_count'] as num?)?.toInt() ?? 0,
      status: RentalStatus.available,
      color: car['color'] ?? 'Unknown',
      licensePlate: car['plate'] ?? '',
      mileage: car['mileage'] ?? 0,
      fuelLevel: 1.0,
      isPremium: car['category'] == 'luxury' || car['category'] == 'suv',
      hasUnlimitedMileage: true,
      discountPercentage: (car['discount_percentage'] as num?)?.toDouble(),
      companyId: company?['id'] ?? '',
      companyName: company?['company_name'],
      companyLogo: company?['logo_url'] as String?,
      depositAmount: (car['deposit_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  // Helper: Map database row to RentalBooking model
  static RentalBooking _mapToRentalBooking(Map<String, dynamic> b) {
    return RentalBooking(
      id: b['id'],
      carId: b['car_id'],
      userId: b['user_id'],
      pickupLocationId: b['pickup_location_id'] ?? '',
      dropoffLocationId: b['dropoff_location_id'] ?? '',
      pickupDate: DateTime.parse(b['pickup_date']),
      dropoffDate: DateTime.parse(b['dropoff_date']),
      packageId: b['package_id'] ?? 'basic',
      additionalServices: [],
      totalPrice: (b['total_amount'] as num?)?.toDouble() ?? 0,
      depositAmount: (b['deposit_amount'] as num?)?.toDouble() ?? 0,
      status: _stringToBookingStatus(b['status']),
      createdAt: DateTime.parse(b['created_at']),
      cancellationReason: b['cancellation_reason'],
      driverLicenseNumber: b['driver_license_no'],
      notes: b['customer_notes'],
      customerName: b['customer_name'],
      customerPhone: b['customer_phone'],
      customerEmail: b['customer_email'],
    );
  }

  // Helper functions
  static String _categoryToString(CarCategory category) {
    switch (category) {
      case CarCategory.economy: return 'economy';
      case CarCategory.compact: return 'compact';
      case CarCategory.sedan: return 'midsize';
      case CarCategory.suv: return 'suv';
      case CarCategory.luxury: return 'luxury';
      case CarCategory.sports: return 'luxury';
      case CarCategory.electric: return 'economy';
      case CarCategory.van: return 'van';
    }
  }

  static CarCategory _stringToCategory(String? category) {
    switch (category) {
      case 'economy': return CarCategory.economy;
      case 'compact': return CarCategory.compact;
      case 'midsize': return CarCategory.sedan;
      case 'fullsize': return CarCategory.sedan;
      case 'suv': return CarCategory.suv;
      case 'luxury': return CarCategory.luxury;
      case 'van': return CarCategory.van;
      default: return CarCategory.economy;
    }
  }

  static FuelType _stringToFuelType(String? type) {
    switch (type) {
      case 'petrol':
      case 'gasoline': return FuelType.petrol;
      case 'diesel': return FuelType.diesel;
      case 'electric': return FuelType.electric;
      case 'hybrid': return FuelType.hybrid;
      default: return FuelType.petrol;
    }
  }

  static BookingStatus _stringToBookingStatus(String? status) {
    switch (status) {
      case 'pending': return BookingStatus.pending;
      case 'confirmed': return BookingStatus.confirmed;
      case 'active': return BookingStatus.active;
      case 'completed': return BookingStatus.completed;
      case 'cancelled': return BookingStatus.cancelled;
      default: return BookingStatus.pending;
    }
  }

  static List<String> _parseFeatures(dynamic features) {
    if (features == null) return [];
    if (features is List) return features.cast<String>();
    if (features is String) {
      try {
        return features.split(',').map((f) => f.trim()).toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }
}
