import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Rental Stats Model
class RentalStats {
  final int totalCars;
  final int availableCars;
  final int rentedCars;
  final int maintenanceCars;
  final int pendingBookings;
  final int activeBookings;
  final double todayRevenue;
  final double monthlyRevenue;

  const RentalStats({
    required this.totalCars,
    required this.availableCars,
    required this.rentedCars,
    required this.maintenanceCars,
    required this.pendingBookings,
    required this.activeBookings,
    required this.todayRevenue,
    required this.monthlyRevenue,
  });

  factory RentalStats.empty() => const RentalStats(
        totalCars: 0,
        availableCars: 0,
        rentedCars: 0,
        maintenanceCars: 0,
        pendingBookings: 0,
        activeBookings: 0,
        todayRevenue: 0,
        monthlyRevenue: 0,
      );
}

// Rental Booking View Model (for display)
class RentalBookingView {
  final String id;
  final String bookingNumber;
  final String carId;
  final String carName;
  final String carImage;
  final String companyId;
  final String companyName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String pickupLocationName;
  final String dropoffLocationName;
  final DateTime pickupDate;
  final DateTime dropoffDate;
  final double dailyRate;
  final int rentalDays;
  final double totalPrice;
  final double commissionAmount;
  final double netAmount;
  final double depositAmount;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final String? cancellationReason;
  final String? driverLicenseNumber;
  final String? notes;

  const RentalBookingView({
    required this.id,
    required this.bookingNumber,
    required this.carId,
    required this.carName,
    required this.carImage,
    required this.companyId,
    required this.companyName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.pickupLocationName,
    required this.dropoffLocationName,
    required this.pickupDate,
    required this.dropoffDate,
    required this.dailyRate,
    required this.rentalDays,
    required this.totalPrice,
    required this.commissionAmount,
    required this.netAmount,
    required this.depositAmount,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.cancellationReason,
    this.driverLicenseNumber,
    this.notes,
    this.packageName,
    this.additionalServices = const [],
  });

  final String? packageName;
  final List<String> additionalServices;

  factory RentalBookingView.fromJson(Map<String, dynamic> json) {
    final car = json['rental_cars'] as Map<String, dynamic>?;
    final company = json['rental_companies'] as Map<String, dynamic>?;
    final pickupLoc = json['pickup_location'] as Map<String, dynamic>?;
    final dropoffLoc = json['dropoff_location'] as Map<String, dynamic>?;

    return RentalBookingView(
      id: json['id'] ?? '',
      bookingNumber: json['booking_number'] ?? '',
      carId: json['car_id'] ?? '',
      carName: car != null ? '${car['brand']} ${car['model']}' : '',
      carImage: car?['image_url'] ?? '',
      companyId: json['company_id'] ?? '',
      companyName: company?['company_name'] ?? '',
      customerId: json['user_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerEmail: json['customer_email'] ?? '',
      pickupLocationName: pickupLoc?['name'] ?? '',
      dropoffLocationName: dropoffLoc?['name'] ?? '',
      pickupDate: DateTime.tryParse(json['pickup_date'] ?? '') ?? DateTime.now(),
      dropoffDate: DateTime.tryParse(json['dropoff_date'] ?? '') ?? DateTime.now(),
      dailyRate: (json['daily_rate'] as num?)?.toDouble() ?? 0,
      rentalDays: json['rental_days'] ?? 0,
      totalPrice: (json['total_amount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      cancellationReason: json['cancellation_reason'],
      driverLicenseNumber: json['driver_license_no'],
      notes: json['customer_notes'],
      packageName: json['package_name'],
      additionalServices: json['additional_services'] != null
          ? List<String>.from(json['additional_services'])
          : const [],
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'confirmed':
        return 'Onaylandı';
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal';
      case 'no_show':
        return 'Gelmedi';
      default:
        return status;
    }
  }
}

// Rental Car View Model (for admin)
class RentalCarView {
  final String id;
  final String companyId;
  final String companyName;
  final String brandName;
  final String model;
  final int year;
  final String category;
  final String transmission;
  final String fuelType;
  final int seats;
  final int doors;
  final double dailyPrice;
  final double weeklyPrice;
  final double monthlyPrice;
  final String thumbnailUrl;
  final double rating;
  final int reviewCount;
  final String status;
  final String color;
  final String licensePlate;
  final int mileage;
  final double fuelLevel;
  final bool isPremium;
  final String? currentLocationName;
  final double? discountPercentage;

  const RentalCarView({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.brandName,
    required this.model,
    required this.year,
    required this.category,
    required this.transmission,
    required this.fuelType,
    required this.seats,
    required this.doors,
    required this.dailyPrice,
    required this.weeklyPrice,
    required this.monthlyPrice,
    required this.thumbnailUrl,
    required this.rating,
    required this.reviewCount,
    required this.status,
    required this.color,
    required this.licensePlate,
    required this.mileage,
    required this.fuelLevel,
    required this.isPremium,
    this.currentLocationName,
    this.discountPercentage,
  });

  factory RentalCarView.fromJson(Map<String, dynamic> json) {
    final company = json['rental_companies'] as Map<String, dynamic>?;
    final location = json['rental_locations'] as Map<String, dynamic>?;

    return RentalCarView(
      id: json['id'] ?? '',
      companyId: json['company_id'] ?? '',
      companyName: company?['company_name'] ?? '',
      brandName: json['brand'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] ?? 0,
      category: _getCategoryDisplay(json['category'] ?? ''),
      transmission: json['transmission'] == 'automatic' ? 'Otomatik' : 'Manuel',
      fuelType: _getFuelTypeDisplay(json['fuel_type'] ?? ''),
      seats: json['seats'] ?? 0,
      doors: json['doors'] ?? 0,
      dailyPrice: (json['daily_price'] as num?)?.toDouble() ?? 0,
      weeklyPrice: (json['weekly_price'] as num?)?.toDouble() ?? 0,
      monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
      thumbnailUrl: json['image_url'] ?? '',
      rating: 0,
      reviewCount: 0,
      status: json['status'] ?? 'available',
      color: json['vehicle_color'] ?? '',
      licensePlate: json['plate'] ?? '',
      mileage: 0,
      fuelLevel: 1.0,
      isPremium: json['category'] == 'luxury' || json['category'] == 'sports',
      currentLocationName: location?['name'],
      discountPercentage: null,
    );
  }

  static String _getCategoryDisplay(String category) {
    switch (category) {
      case 'economy':
        return 'Ekonomik';
      case 'compact':
        return 'Kompakt';
      case 'midsize':
        return 'Orta';
      case 'fullsize':
        return 'Büyük';
      case 'suv':
        return 'SUV';
      case 'luxury':
        return 'Lüks';
      case 'van':
        return 'Van';
      case 'minivan':
        return 'Minivan';
      default:
        return category;
    }
  }

  static String _getFuelTypeDisplay(String fuelType) {
    switch (fuelType) {
      case 'gasoline':
        return 'Benzin';
      case 'diesel':
        return 'Dizel';
      case 'hybrid':
        return 'Hibrit';
      case 'electric':
        return 'Elektrik';
      default:
        return fuelType;
    }
  }

  String get fullName => '$brandName $model';

  String get statusDisplay {
    switch (status) {
      case 'available':
        return 'Müsait';
      case 'rented':
        return 'Kirada';
      case 'maintenance':
        return 'Bakımda';
      case 'reserved':
        return 'Rezerveli';
      default:
        return status;
    }
  }
}

// Rental Location View Model
class RentalLocationView {
  final String id;
  final String companyId;
  final String companyName;
  final String name;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String phone;
  final String workingHours;
  final bool isAirport;
  final bool is24Hours;
  final bool isActive;
  final int availableCarCount;
  final int totalCarCount;

  const RentalLocationView({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.name,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.workingHours,
    required this.isAirport,
    required this.is24Hours,
    required this.isActive,
    required this.availableCarCount,
    required this.totalCarCount,
  });

  factory RentalLocationView.fromJson(Map<String, dynamic> json) {
    final company = json['rental_companies'] as Map<String, dynamic>?;
    final openTime = json['opening_time'] ?? '09:00';
    final closeTime = json['closing_time'] ?? '18:00';
    final is24 = json['is_24_hours'] ?? false;

    return RentalLocationView(
      id: json['id'] ?? '',
      companyId: json['company_id'] ?? '',
      companyName: company?['company_name'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      phone: json['phone'] ?? '',
      workingHours: is24 ? '7/24' : '$openTime - $closeTime',
      isAirport: json['is_airport'] ?? false,
      is24Hours: is24,
      isActive: json['is_active'] ?? true,
      availableCarCount: 0,
      totalCarCount: 0,
    );
  }
}

// Rental Company View Model
class RentalCompanyView {
  final String id;
  final String userId;
  final String companyName;
  final String? taxNumber;
  final String? logoUrl;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final double rating;
  final int totalBookings;
  final int totalReviews;
  final double commissionRate;
  final bool isApproved;
  final bool isActive;
  final DateTime createdAt;

  const RentalCompanyView({
    required this.id,
    required this.userId,
    required this.companyName,
    this.taxNumber,
    this.logoUrl,
    this.phone,
    this.email,
    this.address,
    this.city,
    required this.rating,
    required this.totalBookings,
    required this.totalReviews,
    required this.commissionRate,
    required this.isApproved,
    required this.isActive,
    required this.createdAt,
  });

  factory RentalCompanyView.fromJson(Map<String, dynamic> json) {
    return RentalCompanyView(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      companyName: json['company_name'] ?? '',
      taxNumber: json['tax_number'],
      logoUrl: json['logo_url'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      city: json['city'],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalBookings: json['total_bookings'] ?? 0,
      totalReviews: json['total_reviews'] ?? 0,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 15,
      isApproved: json['is_approved'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ==================== PROVIDERS ====================

// Stats Provider
final rentalStatsProvider = FutureProvider<RentalStats>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    // Get car counts by status
    final carsResponse = await client.from('rental_cars').select('status');
    final cars = List<Map<String, dynamic>>.from(carsResponse);

    int totalCars = cars.length;
    int availableCars = cars.where((c) => c['status'] == 'available').length;
    int rentedCars = cars.where((c) => c['status'] == 'rented').length;
    int maintenanceCars = cars.where((c) => c['status'] == 'maintenance').length;

    // Get booking counts
    final bookingsResponse = await client.from('rental_bookings').select('status, total_amount, created_at');
    final bookings = List<Map<String, dynamic>>.from(bookingsResponse);

    int pendingBookings = bookings.where((b) => b['status'] == 'pending').length;
    int activeBookings = bookings.where((b) => b['status'] == 'active').length;

    // Calculate revenue
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    double todayRevenue = 0;
    double monthlyRevenue = 0;

    for (final booking in bookings) {
      if (booking['status'] == 'completed' || booking['status'] == 'active') {
        final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0;
        final createdAt = DateTime.tryParse(booking['created_at'] ?? '');

        if (createdAt != null) {
          if (createdAt.isAfter(todayStart)) {
            todayRevenue += amount;
          }
          if (createdAt.isAfter(monthStart)) {
            monthlyRevenue += amount;
          }
        }
      }
    }

    return RentalStats(
      totalCars: totalCars,
      availableCars: availableCars,
      rentedCars: rentedCars,
      maintenanceCars: maintenanceCars,
      pendingBookings: pendingBookings,
      activeBookings: activeBookings,
      todayRevenue: todayRevenue,
      monthlyRevenue: monthlyRevenue,
    );
  } catch (e) {
    return RentalStats.empty();
  }
});

// Bookings Provider
final recentBookingsProvider = FutureProvider<List<RentalBookingView>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client
        .from('rental_bookings')
        .select('''
          *,
          rental_cars(brand, model, image_url),
          rental_companies(company_name),
          pickup_location:rental_locations!pickup_location_id(name),
          dropoff_location:rental_locations!dropoff_location_id(name)
        ''')
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response)
        .map((json) => RentalBookingView.fromJson(json))
        .toList();
  } catch (e) {
    return [];
  }
});

// All Cars Provider
final allCarsProvider = FutureProvider<List<RentalCarView>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client
        .from('rental_cars')
        .select('''
          *,
          rental_companies(company_name),
          rental_locations(name)
        ''')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((json) => RentalCarView.fromJson(json))
        .toList();
  } catch (e) {
    return [];
  }
});

// All Locations Provider
final allLocationsProvider = FutureProvider<List<RentalLocationView>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client
        .from('rental_locations')
        .select('''
          *,
          rental_companies(company_name)
        ''')
        .order('name');

    return List<Map<String, dynamic>>.from(response)
        .map((json) => RentalLocationView.fromJson(json))
        .toList();
  } catch (e) {
    return [];
  }
});

// All Companies Provider
final allCompaniesProvider = FutureProvider<List<RentalCompanyView>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    final response = await client
        .from('rental_companies')
        .select('*')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((json) => RentalCompanyView.fromJson(json))
        .toList();
  } catch (e) {
    return [];
  }
});

// ==================== ACTIONS ====================

// Update Booking Status
Future<bool> updateBookingStatus(
  SupabaseClient client,
  String bookingId,
  String newStatus, {
  String? cancellationReason,
}) async {
  try {
    final data = <String, dynamic>{
      'status': newStatus,
    };

    if (newStatus == 'confirmed') {
      data['confirmed_at'] = DateTime.now().toIso8601String();
    } else if (newStatus == 'cancelled') {
      data['cancelled_at'] = DateTime.now().toIso8601String();
      if (cancellationReason != null) {
        data['cancellation_reason'] = cancellationReason;
      }
    }

    await client.from('rental_bookings').update(data).eq('id', bookingId);
    return true;
  } catch (e) {
    return false;
  }
}

// Update Car Status
Future<bool> updateCarStatus(
  SupabaseClient client,
  String carId,
  String newStatus,
) async {
  try {
    await client.from('rental_cars').update({'status': newStatus}).eq('id', carId);
    return true;
  } catch (e) {
    return false;
  }
}

// Approve/Reject Company
Future<bool> updateCompanyApproval(
  SupabaseClient client,
  String companyId,
  bool isApproved,
) async {
  try {
    await client.from('rental_companies').update({'is_approved': isApproved}).eq('id', companyId);
    return true;
  } catch (e) {
    return false;
  }
}

// Toggle Location Active Status
Future<bool> toggleLocationActive(
  SupabaseClient client,
  String locationId,
  bool isActive,
) async {
  try {
    await client.from('rental_locations').update({'is_active': isActive}).eq('id', locationId);
    return true;
  } catch (e) {
    return false;
  }
}
