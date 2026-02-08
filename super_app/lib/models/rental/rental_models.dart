// Premium Car Rental Models
// Designed with international standards for a luxury car rental experience

enum CarCategory {
  economy,
  compact,
  sedan,
  suv,
  luxury,
  sports,
  electric,
  van,
}

enum TransmissionType {
  automatic,
  manual,
}

enum FuelType {
  petrol,
  diesel,
  electric,
  hybrid,
}

enum RentalStatus {
  available,
  rented,
  maintenance,
  reserved,
}

class CarBrand {
  final String id;
  final String name;
  final String logoUrl;
  final bool isPremium;

  const CarBrand({
    required this.id,
    required this.name,
    required this.logoUrl,
    this.isPremium = false,
  });

  static const List<CarBrand> popularBrands = [
    CarBrand(id: 'mercedes', name: 'Mercedes-Benz', logoUrl: 'assets/brands/mercedes.png', isPremium: true),
    CarBrand(id: 'bmw', name: 'BMW', logoUrl: 'assets/brands/bmw.png', isPremium: true),
    CarBrand(id: 'audi', name: 'Audi', logoUrl: 'assets/brands/audi.png', isPremium: true),
    CarBrand(id: 'porsche', name: 'Porsche', logoUrl: 'assets/brands/porsche.png', isPremium: true),
    CarBrand(id: 'tesla', name: 'Tesla', logoUrl: 'assets/brands/tesla.png', isPremium: true),
    CarBrand(id: 'toyota', name: 'Toyota', logoUrl: 'assets/brands/toyota.png'),
    CarBrand(id: 'volkswagen', name: 'Volkswagen', logoUrl: 'assets/brands/vw.png'),
    CarBrand(id: 'honda', name: 'Honda', logoUrl: 'assets/brands/honda.png'),
    CarBrand(id: 'ford', name: 'Ford', logoUrl: 'assets/brands/ford.png'),
    CarBrand(id: 'hyundai', name: 'Hyundai', logoUrl: 'assets/brands/hyundai.png'),
  ];
}

class CarFeature {
  final String id;
  final String name;
  final String icon;

  const CarFeature({
    required this.id,
    required this.name,
    required this.icon,
  });

  static const List<CarFeature> allFeatures = [
    CarFeature(id: 'ac', name: 'Klima', icon: 'ac_unit'),
    CarFeature(id: 'bluetooth', name: 'Bluetooth', icon: 'bluetooth'),
    CarFeature(id: 'gps', name: 'GPS Navigasyon', icon: 'gps_fixed'),
    CarFeature(id: 'usb', name: 'USB Şarj', icon: 'usb'),
    CarFeature(id: 'sunroof', name: 'Sunroof', icon: 'wb_sunny'),
    CarFeature(id: 'leather', name: 'Deri Koltuk', icon: 'airline_seat_legroom_extra'),
    CarFeature(id: 'camera', name: 'Geri Görüş Kamerası', icon: 'camera_rear'),
    CarFeature(id: 'parking', name: 'Park Sensörü', icon: 'local_parking'),
    CarFeature(id: 'cruise', name: 'Cruise Control', icon: 'speed'),
    CarFeature(id: 'heated_seats', name: 'Isıtmalı Koltuk', icon: 'hot_tub'),
    CarFeature(id: 'apple_carplay', name: 'Apple CarPlay', icon: 'phone_iphone'),
    CarFeature(id: 'android_auto', name: 'Android Auto', icon: 'android'),
  ];
}

class RentalCar {
  final String id;
  final String brandId;
  final String brandName;
  final String model;
  final int year;
  final CarCategory category;
  final TransmissionType transmission;
  final FuelType fuelType;
  final int seats;
  final int doors;
  final int luggage; // Bagaj kapasitesi (bavul sayısı)
  final double dailyPrice;
  final double weeklyPrice;
  final double monthlyPrice;
  final List<String> imageUrls;
  final String thumbnailUrl;
  final List<String> featureIds;
  final double rating;
  final int reviewCount;
  final RentalStatus status;
  final String? currentLocationId;
  final String color;
  final String licensePlate;
  final int mileage;
  final double fuelLevel; // 0.0 - 1.0
  final bool isPremium;
  final bool hasUnlimitedMileage;
  final double? discountPercentage;
  final String companyId; // Kiralama şirketi ID
  final String? companyName; // Kiralama şirketi adı
  final String? companyLogo; // Kiralama şirketi logosu
  final double depositAmount; // Depozito tutarı

  const RentalCar({
    required this.id,
    required this.brandId,
    required this.brandName,
    required this.model,
    required this.year,
    required this.category,
    required this.transmission,
    required this.fuelType,
    required this.seats,
    required this.doors,
    required this.luggage,
    required this.dailyPrice,
    required this.weeklyPrice,
    required this.monthlyPrice,
    required this.imageUrls,
    required this.thumbnailUrl,
    required this.featureIds,
    required this.rating,
    required this.reviewCount,
    required this.status,
    this.currentLocationId,
    required this.color,
    required this.licensePlate,
    required this.mileage,
    required this.fuelLevel,
    this.isPremium = false,
    this.hasUnlimitedMileage = true,
    this.discountPercentage,
    this.companyId = 'demo_company',
    this.companyName,
    this.companyLogo,
    this.depositAmount = 0,
  });

  String get fullName => '$brandName $model';

  double get discountedDailyPrice {
    if (discountPercentage != null && discountPercentage! > 0) {
      return dailyPrice * (1 - discountPercentage! / 100);
    }
    return dailyPrice;
  }

  String get categoryName {
    switch (category) {
      case CarCategory.economy:
        return 'Ekonomik';
      case CarCategory.compact:
        return 'Kompakt';
      case CarCategory.sedan:
        return 'Sedan';
      case CarCategory.suv:
        return 'SUV';
      case CarCategory.luxury:
        return 'Lüks';
      case CarCategory.sports:
        return 'Spor';
      case CarCategory.electric:
        return 'Elektrikli';
      case CarCategory.van:
        return 'Van';
    }
  }

  String get transmissionName {
    switch (transmission) {
      case TransmissionType.automatic:
        return 'Otomatik';
      case TransmissionType.manual:
        return 'Manuel';
    }
  }

  String get fuelTypeName {
    switch (fuelType) {
      case FuelType.petrol:
        return 'Benzin';
      case FuelType.diesel:
        return 'Dizel';
      case FuelType.electric:
        return 'Elektrik';
      case FuelType.hybrid:
        return 'Hibrit';
    }
  }
}

class RentalLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final String workingHours;
  final bool isAirport;
  final bool is24Hours;
  final List<String> availableCarIds;

  const RentalLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.workingHours,
    this.isAirport = false,
    this.is24Hours = false,
    this.availableCarIds = const [],
  });
}

class RentalPackage {
  final String id;
  final String tier;
  final String name;
  final String description;
  final double dailyPrice;
  final List<String> includedServices;
  final bool isPopular;
  final String iconName;

  const RentalPackage({
    required this.id,
    this.tier = 'basic',
    required this.name,
    required this.description,
    required this.dailyPrice,
    required this.includedServices,
    this.isPopular = false,
    required this.iconName,
  });

  factory RentalPackage.fromJson(Map<String, dynamic> json) {
    final services = json['included_services'];
    List<String> servicesList = [];
    if (services is List) {
      servicesList = services.map((e) => e.toString()).toList();
    }
    return RentalPackage(
      id: json['id'] as String,
      tier: json['tier'] as String? ?? 'basic',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dailyPrice: (json['daily_price'] as num?)?.toDouble() ?? 0,
      includedServices: servicesList,
      isPopular: json['is_popular'] as bool? ?? false,
      iconName: json['icon'] as String? ?? 'directions_car',
    );
  }
}

class RentalBooking {
  final String id;
  final String carId;
  final String userId;
  final String pickupLocationId;
  final String dropoffLocationId;
  final DateTime pickupDate;
  final DateTime dropoffDate;
  final String packageId;
  final List<String> additionalServices;
  final double totalPrice;
  final double depositAmount;
  final BookingStatus status;
  final DateTime createdAt;
  final String? cancellationReason;
  final String? driverLicenseNumber;
  final String? notes;

  const RentalBooking({
    required this.id,
    required this.carId,
    required this.userId,
    required this.pickupLocationId,
    required this.dropoffLocationId,
    required this.pickupDate,
    required this.dropoffDate,
    required this.packageId,
    required this.additionalServices,
    required this.totalPrice,
    required this.depositAmount,
    required this.status,
    required this.createdAt,
    this.cancellationReason,
    this.driverLicenseNumber,
    this.notes,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
  });

  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;

  int get rentalDays => dropoffDate.difference(pickupDate).inDays;

  bool get canCancel => status == BookingStatus.pending || status == BookingStatus.confirmed;

  /// İki tarih aralığının çakışıp çakışmadığını kontrol eder
  bool overlapsWithDates(DateTime checkPickup, DateTime checkDropoff) {
    // İptal edilmiş veya tamamlanmış rezervasyonları hariç tut
    if (status == BookingStatus.cancelled || status == BookingStatus.completed) {
      return false;
    }
    // Tarih aralıkları çakışıyor mu?
    return pickupDate.isBefore(checkDropoff) && dropoffDate.isAfter(checkPickup);
  }
}

enum BookingStatus {
  pending,
  confirmed,
  active,
  completed,
  cancelled,
}

class AdditionalService {
  final String id;
  final String name;
  final String description;
  final double dailyPrice;
  final String priceType;
  final String iconName;

  const AdditionalService({
    required this.id,
    required this.name,
    required this.description,
    required this.dailyPrice,
    this.priceType = 'per_day',
    required this.iconName,
  });

  factory AdditionalService.fromJson(Map<String, dynamic> json) {
    return AdditionalService(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dailyPrice: (json['price'] as num?)?.toDouble() ?? 0,
      priceType: json['price_type'] as String? ?? 'per_day',
      iconName: json['icon'] as String? ?? 'build',
    );
  }
}

// Rental Review Model
class RentalReview {
  final String id;
  final String? bookingId;
  final String companyId;
  final String? carId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final int overallRating;
  final int? carConditionRating;
  final int? cleanlinessRating;
  final int? serviceRating;
  final int? valueRating;
  final String? comment;
  final List<String>? pros;
  final List<String>? cons;
  final String? companyReply;
  final DateTime? repliedAt;
  final bool isApproved;
  final bool isHidden;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RentalReview({
    required this.id,
    this.bookingId,
    required this.companyId,
    this.carId,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.overallRating,
    this.carConditionRating,
    this.cleanlinessRating,
    this.serviceRating,
    this.valueRating,
    this.comment,
    this.pros,
    this.cons,
    this.companyReply,
    this.repliedAt,
    this.isApproved = true,
    this.isHidden = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory RentalReview.fromJson(Map<String, dynamic> json) {
    return RentalReview(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String?,
      companyId: json['company_id'] as String,
      carId: json['car_id'] as String?,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? json['profiles']?['full_name'] as String?,
      userAvatar: json['user_avatar'] as String? ?? json['profiles']?['avatar_url'] as String?,
      overallRating: json['overall_rating'] as int,
      carConditionRating: json['car_condition_rating'] as int?,
      cleanlinessRating: json['cleanliness_rating'] as int?,
      serviceRating: json['service_rating'] as int?,
      valueRating: json['value_rating'] as int?,
      comment: json['comment'] as String?,
      pros: json['pros'] != null ? List<String>.from(json['pros']) : null,
      cons: json['cons'] != null ? List<String>.from(json['cons']) : null,
      companyReply: json['company_reply'] as String?,
      repliedAt: json['replied_at'] != null ? DateTime.parse(json['replied_at']) : null,
      isApproved: json['is_approved'] as bool? ?? true,
      isHidden: json['is_hidden'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
      'company_reply': companyReply,
      'replied_at': repliedAt?.toIso8601String(),
      'is_approved': isApproved,
      'is_hidden': isHidden,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} yıl önce';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}

// Rating Summary Model
class RatingsSummary {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution;
  final double? avgCarCondition;
  final double? avgCleanliness;
  final double? avgService;
  final double? avgValue;

  const RatingsSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
    this.avgCarCondition,
    this.avgCleanliness,
    this.avgService,
    this.avgValue,
  });

  factory RatingsSummary.fromReviews(List<RentalReview> reviews) {
    if (reviews.isEmpty) {
      return const RatingsSummary(
        averageRating: 0,
        totalReviews: 0,
        ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }

    final total = reviews.length;
    final sum = reviews.fold<int>(0, (sum, r) => sum + r.overallRating);
    final average = sum / total;

    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final review in reviews) {
      distribution[review.overallRating] = (distribution[review.overallRating] ?? 0) + 1;
    }

    double? avgCarCondition;
    double? avgCleanliness;
    double? avgService;
    double? avgValue;

    final carConditionRatings = reviews.where((r) => r.carConditionRating != null).toList();
    if (carConditionRatings.isNotEmpty) {
      avgCarCondition = carConditionRatings.fold<int>(0, (sum, r) => sum + r.carConditionRating!) / carConditionRatings.length;
    }

    final cleanlinessRatings = reviews.where((r) => r.cleanlinessRating != null).toList();
    if (cleanlinessRatings.isNotEmpty) {
      avgCleanliness = cleanlinessRatings.fold<int>(0, (sum, r) => sum + r.cleanlinessRating!) / cleanlinessRatings.length;
    }

    final serviceRatings = reviews.where((r) => r.serviceRating != null).toList();
    if (serviceRatings.isNotEmpty) {
      avgService = serviceRatings.fold<int>(0, (sum, r) => sum + r.serviceRating!) / serviceRatings.length;
    }

    final valueRatings = reviews.where((r) => r.valueRating != null).toList();
    if (valueRatings.isNotEmpty) {
      avgValue = valueRatings.fold<int>(0, (sum, r) => sum + r.valueRating!) / valueRatings.length;
    }

    return RatingsSummary(
      averageRating: average,
      totalReviews: total,
      ratingDistribution: distribution,
      avgCarCondition: avgCarCondition,
      avgCleanliness: avgCleanliness,
      avgService: avgService,
      avgValue: avgValue,
    );
  }

  double getPercentage(int rating) {
    if (totalReviews == 0) return 0;
    return (ratingDistribution[rating] ?? 0) / totalReviews;
  }
}

// Demo veriler
class RentalDemoData {
  static List<RentalCar> get cars => [
    const RentalCar(
      id: 'car_001',
      brandId: 'mercedes',
      brandName: 'Mercedes-Benz',
      model: 'E-Class',
      year: 2024,
      category: CarCategory.luxury,
      transmission: TransmissionType.automatic,
      fuelType: FuelType.petrol,
      seats: 5,
      doors: 4,
      luggage: 3,
      dailyPrice: 2500,
      weeklyPrice: 15000,
      monthlyPrice: 50000,
      imageUrls: [
        'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800',
        'https://images.unsplash.com/photo-1617531653332-bd46c24f2068?w=800',
      ],
      thumbnailUrl: 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=400',
      featureIds: ['ac', 'bluetooth', 'gps', 'leather', 'sunroof', 'camera', 'parking', 'cruise', 'apple_carplay'],
      rating: 4.9,
      reviewCount: 124,
      status: RentalStatus.available,
      color: 'Obsidian Black',
      licensePlate: '34 ABC 001',
      mileage: 15000,
      fuelLevel: 1.0,
      isPremium: true,
      hasUnlimitedMileage: true,
    ),
    const RentalCar(
      id: 'car_002',
      brandId: 'bmw',
      brandName: 'BMW',
      model: '5 Series',
      year: 2024,
      category: CarCategory.luxury,
      transmission: TransmissionType.automatic,
      fuelType: FuelType.hybrid,
      seats: 5,
      doors: 4,
      luggage: 3,
      dailyPrice: 2300,
      weeklyPrice: 14000,
      monthlyPrice: 48000,
      imageUrls: [
        'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=800',
      ],
      thumbnailUrl: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=400',
      featureIds: ['ac', 'bluetooth', 'gps', 'leather', 'sunroof', 'camera', 'parking', 'cruise', 'android_auto'],
      rating: 4.8,
      reviewCount: 98,
      status: RentalStatus.available,
      color: 'Alpine White',
      licensePlate: '34 DEF 002',
      mileage: 12000,
      fuelLevel: 0.85,
      isPremium: true,
      hasUnlimitedMileage: true,
      discountPercentage: 10,
    ),
    const RentalCar(
      id: 'car_003',
      brandId: 'tesla',
      brandName: 'Tesla',
      model: 'Model 3',
      year: 2024,
      category: CarCategory.electric,
      transmission: TransmissionType.automatic,
      fuelType: FuelType.electric,
      seats: 5,
      doors: 4,
      luggage: 2,
      dailyPrice: 1800,
      weeklyPrice: 11000,
      monthlyPrice: 38000,
      imageUrls: [
        'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=800',
      ],
      thumbnailUrl: 'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=400',
      featureIds: ['ac', 'bluetooth', 'gps', 'camera', 'parking', 'cruise', 'apple_carplay', 'android_auto'],
      rating: 4.9,
      reviewCount: 156,
      status: RentalStatus.available,
      color: 'Pearl White',
      licensePlate: '34 GHI 003',
      mileage: 8000,
      fuelLevel: 0.95,
      isPremium: true,
      hasUnlimitedMileage: true,
    ),
    const RentalCar(
      id: 'car_004',
      brandId: 'porsche',
      brandName: 'Porsche',
      model: '911 Carrera',
      year: 2024,
      category: CarCategory.sports,
      transmission: TransmissionType.automatic,
      fuelType: FuelType.petrol,
      seats: 2,
      doors: 2,
      luggage: 1,
      dailyPrice: 5000,
      weeklyPrice: 30000,
      monthlyPrice: 100000,
      imageUrls: [
        'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=800',
      ],
      thumbnailUrl: 'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=400',
      featureIds: ['ac', 'bluetooth', 'gps', 'leather', 'camera', 'parking', 'cruise'],
      rating: 5.0,
      reviewCount: 42,
      status: RentalStatus.available,
      color: 'Guards Red',
      licensePlate: '34 JKL 004',
      mileage: 5000,
      fuelLevel: 1.0,
      isPremium: true,
      hasUnlimitedMileage: false,
    ),
    const RentalCar(
      id: 'car_005',
      brandId: 'toyota',
      brandName: 'Toyota',
      model: 'Corolla',
      year: 2024,
      category: CarCategory.sedan,
      transmission: TransmissionType.automatic,
      fuelType: FuelType.hybrid,
      seats: 5,
      doors: 4,
      luggage: 2,
      dailyPrice: 800,
      weeklyPrice: 5000,
      monthlyPrice: 18000,
      imageUrls: [
        'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=800',
      ],
      thumbnailUrl: 'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=400',
      featureIds: ['ac', 'bluetooth', 'usb', 'camera', 'parking'],
      rating: 4.6,
      reviewCount: 234,
      status: RentalStatus.available,
      color: 'Silver Metallic',
      licensePlate: '34 MNO 005',
      mileage: 25000,
      fuelLevel: 0.7,
      isPremium: false,
      hasUnlimitedMileage: true,
    ),
    const RentalCar(
      id: 'car_006',
      brandId: 'volkswagen',
      brandName: 'Volkswagen',
      model: 'Golf',
      year: 2024,
      category: CarCategory.compact,
      transmission: TransmissionType.automatic,
      fuelType: FuelType.petrol,
      seats: 5,
      doors: 4,
      luggage: 2,
      dailyPrice: 650,
      weeklyPrice: 4000,
      monthlyPrice: 14000,
      imageUrls: [
        'https://images.unsplash.com/photo-1471444928139-48c5bf5173f8?w=800',
      ],
      thumbnailUrl: 'https://images.unsplash.com/photo-1471444928139-48c5bf5173f8?w=400',
      featureIds: ['ac', 'bluetooth', 'usb', 'parking'],
      rating: 4.5,
      reviewCount: 189,
      status: RentalStatus.available,
      color: 'Tornado Red',
      licensePlate: '34 PQR 006',
      mileage: 30000,
      fuelLevel: 0.9,
      isPremium: false,
      hasUnlimitedMileage: true,
    ),
    const RentalCar(
      id: 'car_007',
      brandId: 'audi',
      brandName: 'Audi',
      model: 'Q7',
      year: 2024,
      category: CarCategory.suv,
      transmission: TransmissionType.automatic,
      fuelType: FuelType.diesel,
      seats: 7,
      doors: 5,
      luggage: 4,
      dailyPrice: 2800,
      weeklyPrice: 17000,
      monthlyPrice: 58000,
      imageUrls: [
        'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?w=800',
      ],
      thumbnailUrl: 'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?w=400',
      featureIds: ['ac', 'bluetooth', 'gps', 'leather', 'sunroof', 'camera', 'parking', 'cruise', 'heated_seats'],
      rating: 4.8,
      reviewCount: 87,
      status: RentalStatus.available,
      color: 'Glacier White',
      licensePlate: '34 STU 007',
      mileage: 18000,
      fuelLevel: 0.8,
      isPremium: true,
      hasUnlimitedMileage: true,
    ),
  ];

  static List<RentalLocation> get locations => [
    const RentalLocation(
      id: 'loc_001',
      name: 'Ercan Havalimanı',
      address: 'Ercan Havalimanı, Lefkoşa',
      latitude: 35.1547,
      longitude: 33.4961,
      phone: '+90 392 123 4567',
      workingHours: '7/24',
      isAirport: true,
      is24Hours: true,
    ),
    const RentalLocation(
      id: 'loc_002',
      name: 'Girne Merkez',
      address: 'Girne Limanı Karşısı, Girne',
      latitude: 35.3364,
      longitude: 33.3182,
      phone: '+90 392 234 5678',
      workingHours: '08:00 - 20:00',
    ),
    const RentalLocation(
      id: 'loc_003',
      name: 'Lefkoşa Merkez',
      address: 'Dereboyu Caddesi, Lefkoşa',
      latitude: 35.1856,
      longitude: 33.3823,
      phone: '+90 392 345 6789',
      workingHours: '08:00 - 19:00',
    ),
    const RentalLocation(
      id: 'loc_004',
      name: 'Gazimağusa',
      address: 'Salamis Yolu, Gazimağusa',
      latitude: 35.1174,
      longitude: 33.9425,
      phone: '+90 392 456 7890',
      workingHours: '08:00 - 18:00',
    ),
  ];

  /// Demo rezervasyonlar - gerçek uygulamada backend'den gelecek
  static List<RentalBooking> get bookings {
    final now = DateTime.now();
    return [
      // Mercedes E-Class - bugünden 3 gün sonrasına kadar rezerveli
      RentalBooking(
        id: 'booking_001',
        carId: 'car_001',
        userId: 'user_001',
        pickupLocationId: 'loc_001',
        dropoffLocationId: 'loc_001',
        pickupDate: now,
        dropoffDate: now.add(const Duration(days: 3)),
        packageId: 'comfort',
        additionalServices: ['gps'],
        totalPrice: 9375,
        depositAmount: 2000,
        status: BookingStatus.active,
        createdAt: now.subtract(const Duration(days: 1)),
        customerName: 'Ahmet Yılmaz',
        customerPhone: '+90 532 111 2233',
        customerEmail: 'ahmet@email.com',
      ),
      // BMW 5 Series - 5 gün sonradan 8 gün sonrasına kadar rezerveli
      RentalBooking(
        id: 'booking_002',
        carId: 'car_002',
        userId: 'user_002',
        pickupLocationId: 'loc_002',
        dropoffLocationId: 'loc_001',
        pickupDate: now.add(const Duration(days: 5)),
        dropoffDate: now.add(const Duration(days: 8)),
        packageId: 'premium',
        additionalServices: ['child_seat', 'additional_driver'],
        totalPrice: 10350,
        depositAmount: 2500,
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 2)),
        customerName: 'Mehmet Demir',
        customerPhone: '+90 533 222 3344',
        customerEmail: 'mehmet@email.com',
      ),
      // Tesla Model 3 - 2 gün sonradan 5 gün sonrasına kadar rezerveli
      RentalBooking(
        id: 'booking_003',
        carId: 'car_003',
        userId: 'user_003',
        pickupLocationId: 'loc_001',
        dropoffLocationId: 'loc_003',
        pickupDate: now.add(const Duration(days: 2)),
        dropoffDate: now.add(const Duration(days: 5)),
        packageId: 'basic',
        additionalServices: ['wifi'],
        totalPrice: 5580,
        depositAmount: 1500,
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(hours: 12)),
        customerName: 'Ayşe Kaya',
        customerPhone: '+90 534 333 4455',
        customerEmail: 'ayse@email.com',
      ),
      // Porsche 911 - 10 gün sonradan 12 gün sonrasına kadar rezerveli
      RentalBooking(
        id: 'booking_004',
        carId: 'car_004',
        userId: 'user_004',
        pickupLocationId: 'loc_002',
        dropoffLocationId: 'loc_002',
        pickupDate: now.add(const Duration(days: 10)),
        dropoffDate: now.add(const Duration(days: 12)),
        packageId: 'premium',
        additionalServices: [],
        totalPrice: 15000,
        depositAmount: 5000,
        status: BookingStatus.pending,
        createdAt: now.subtract(const Duration(hours: 6)),
        customerName: 'Ali Öztürk',
        customerPhone: '+90 535 444 5566',
        customerEmail: 'ali@email.com',
      ),
      // Toyota Corolla - dün tamamlandı (geçmiş rezervasyon)
      RentalBooking(
        id: 'booking_005',
        carId: 'car_005',
        userId: 'user_005',
        pickupLocationId: 'loc_003',
        dropoffLocationId: 'loc_003',
        pickupDate: now.subtract(const Duration(days: 5)),
        dropoffDate: now.subtract(const Duration(days: 1)),
        packageId: 'basic',
        additionalServices: [],
        totalPrice: 3200,
        depositAmount: 800,
        status: BookingStatus.completed,
        createdAt: now.subtract(const Duration(days: 6)),
        customerName: 'Fatma Şahin',
        customerPhone: '+90 536 555 6677',
        customerEmail: 'fatma@email.com',
      ),
      // Volkswagen Golf - iptal edilmiş
      RentalBooking(
        id: 'booking_006',
        carId: 'car_006',
        userId: 'user_006',
        pickupLocationId: 'loc_001',
        dropoffLocationId: 'loc_002',
        pickupDate: now.add(const Duration(days: 1)),
        dropoffDate: now.add(const Duration(days: 4)),
        packageId: 'comfort',
        additionalServices: ['gps'],
        totalPrice: 2437,
        depositAmount: 650,
        status: BookingStatus.cancelled,
        createdAt: now.subtract(const Duration(days: 3)),
        cancellationReason: 'Müşteri iptal etti',
        customerName: 'Hasan Çelik',
        customerPhone: '+90 537 666 7788',
        customerEmail: 'hasan@email.com',
      ),
      // Audi Q7 - bugünden 7 gün sonrasına kadar rezerveli
      RentalBooking(
        id: 'booking_007',
        carId: 'car_007',
        userId: 'user_007',
        pickupLocationId: 'loc_004',
        dropoffLocationId: 'loc_001',
        pickupDate: now,
        dropoffDate: now.add(const Duration(days: 7)),
        packageId: 'premium',
        additionalServices: ['child_seat', 'wifi', 'roof_rack'],
        totalPrice: 29400,
        depositAmount: 3000,
        status: BookingStatus.active,
        createdAt: now.subtract(const Duration(days: 1)),
        customerName: 'Zeynep Arslan',
        customerPhone: '+90 538 777 8899',
        customerEmail: 'zeynep@email.com',
      ),
    ];
  }

  /// Belirli tarihlerde müsait araçları getirir
  static List<RentalCar> getAvailableCars({
    required DateTime pickupDate,
    required DateTime dropoffDate,
    CarCategory? category,
    String? locationId,
  }) {
    final allBookings = bookings;

    return cars.where((car) {
      // Önce araç durumu kontrolü
      if (car.status == RentalStatus.maintenance) return false;

      // Kategori filtresi
      if (category != null && car.category != category) return false;

      // Lokasyon filtresi (opsiyonel)
      if (locationId != null && car.currentLocationId != locationId) return false;

      // Bu araç için aktif rezervasyonları kontrol et
      final carBookings = allBookings.where((b) => b.carId == car.id);

      // Hiç rezervasyon yoksa müsait
      if (carBookings.isEmpty) return true;

      // İstenen tarihlerle çakışan rezervasyon var mı?
      for (final booking in carBookings) {
        if (booking.overlapsWithDates(pickupDate, dropoffDate)) {
          return false; // Çakışma var, araç müsait değil
        }
      }

      return true; // Çakışma yok, araç müsait
    }).toList();
  }

  /// Bir aracın belirli tarihlerde müsait olup olmadığını kontrol eder
  static bool isCarAvailable(String carId, DateTime pickupDate, DateTime dropoffDate) {
    final car = cars.firstWhere((c) => c.id == carId, orElse: () => cars.first);

    // Bakımda ise müsait değil
    if (car.status == RentalStatus.maintenance) return false;

    // Rezervasyonları kontrol et
    final carBookings = bookings.where((b) => b.carId == carId);

    for (final booking in carBookings) {
      if (booking.overlapsWithDates(pickupDate, dropoffDate)) {
        return false;
      }
    }

    return true;
  }

  /// Bir aracın rezervasyon takvimini getirir
  static List<RentalBooking> getCarBookings(String carId) {
    return bookings.where((b) => b.carId == carId).toList();
  }
}
