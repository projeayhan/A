/// Araç Satış Modeli Tanımlamaları

import 'dart:ui';

// ==================== ENUM'LAR ====================

/// Araç Kasa Tipleri
enum CarBodyType {
  sedan('Sedan', 'directions_car'),
  hatchback('Hatchback', 'directions_car'),
  suv('SUV', 'directions_car'),
  crossover('Crossover', 'directions_car'),
  coupe('Coupe', 'sports_motorsports'),
  convertible('Cabrio', 'directions_car'),
  stationWagon('Station Wagon', 'directions_car'),
  pickup('Pickup', 'local_shipping'),
  van('Van', 'airport_shuttle'),
  minivan('Minivan', 'airport_shuttle'),
  sports('Spor', 'sports_motorsports'),
  luxury('Lüks', 'star');

  final String label;
  final String icon;
  const CarBodyType(this.label, this.icon);

  String get displayName => label;

  static CarBodyType? fromString(String? value) {
    if (value == null) return null;
    return CarBodyType.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Yakıt Tipleri
enum CarFuelType {
  petrol('Benzin', Color(0xFFEF4444)),
  diesel('Dizel', Color(0xFF1E293B)),
  electric('Elektrik', Color(0xFF22C55E)),
  hybrid('Hibrit', Color(0xFF3B82F6)),
  pluginHybrid('Plug-in Hibrit', Color(0xFF8B5CF6)),
  lpg('LPG', Color(0xFFF97316));

  final String label;
  final Color color;
  const CarFuelType(this.label, this.color);

  String get displayName => label;

  static CarFuelType? fromString(String? value) {
    if (value == null) return null;
    return CarFuelType.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Vites Tipleri
enum CarTransmission {
  automatic('Otomatik'),
  manual('Manuel'),
  semiAutomatic('Yarı Otomatik');

  final String label;
  const CarTransmission(this.label);

  String get displayName => label;

  static CarTransmission? fromString(String? value) {
    if (value == null) return null;
    return CarTransmission.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Çekiş Tipleri
enum CarTraction {
  fwd('Önden Çekiş'),
  rwd('Arkadan Çekiş'),
  awd('AWD'),
  fourWd('4WD');

  final String label;
  const CarTraction(this.label);

  String get displayName => label;

  static CarTraction? fromString(String? value) {
    if (value == null) return null;
    return CarTraction.values.where((e) => e.name == value).firstOrNull;
  }
}

/// İlan Durumu
enum CarListingStatus {
  pending('Onay Bekliyor', Color(0xFFF59E0B)),
  active('Aktif', Color(0xFF22C55E)),
  sold('Satıldı', Color(0xFF64748B)),
  reserved('Rezerve', Color(0xFF3B82F6)),
  expired('Süresi Doldu', Color(0xFFEF4444)),
  rejected('Reddedildi', Color(0xFFEF4444));

  final String label;
  final Color color;
  const CarListingStatus(this.label, this.color);

  static CarListingStatus? fromString(String? value) {
    if (value == null) return null;
    return CarListingStatus.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Araç Durumu
enum CarCondition {
  brandNew('Sıfır', Color(0xFF22C55E)),
  likeNew('Sıfır Gibi', Color(0xFF10B981)),
  excellent('Mükemmel', Color(0xFF3B82F6)),
  good('İyi', Color(0xFF6366F1)),
  fair('Orta', Color(0xFFF59E0B)),
  needsRepair('Onarım Gerekli', Color(0xFFEF4444));

  final String label;
  final Color color;
  const CarCondition(this.label, this.color);

  String get displayName => label;

  static CarCondition? fromString(String? value) {
    if (value == null) return null;
    return CarCondition.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Satıcı Tipi
enum DealerType {
  individual('Bireysel'),
  dealer('Galeri'),
  authorizedDealer('Yetkili Bayi');

  final String label;
  const DealerType(this.label);

  static DealerType? fromString(String? value) {
    if (value == null) return null;
    return DealerType.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Sıralama Seçenekleri
enum CarSortOption {
  newest('En Yeni'),
  oldest('En Eski'),
  priceLowToHigh('Fiyat (Düşükten Yükseğe)'),
  priceHighToLow('Fiyat (Yüksekten Düşüğe)'),
  mileageLowToHigh('KM (Düşükten Yükseğe)'),
  mileageHighToLow('KM (Yüksekten Düşüğe)'),
  yearNewToOld('Yıl (Yeniden Eskiye)'),
  yearOldToNew('Yıl (Eskiden Yeniye)');

  final String label;
  const CarSortOption(this.label);
}

// ==================== RENK SINIFI ====================

/// Araç Satış Renk Paleti
class CarSalesColors {
  // Ana Renkler
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFFF59E0B);
  static const Color accent = Color(0xFFDC2626);
  static const Color success = Color(0xFF10B981);

  // Light Mode
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFE2E8F0);

  // Dark Mode
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF64748B);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF334155);

  // Helper Methods
  static Color background(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textTertiary(bool isDark) => isDark ? textTertiaryDark : textTertiaryLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;

  // Gradients
  static const List<Color> primaryGradient = [Color(0xFF1E40AF), Color(0xFF3B82F6)];
  static const List<Color> premiumGradient = [Color(0xFF0F172A), Color(0xFF1E293B)];
  static const List<Color> goldGradient = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const List<Color> sportGradient = [Color(0xFFDC2626), Color(0xFFF97316)];
}

// ==================== MODEL SINIFLARI ====================

/// Araç Markası
class CarBrand {
  final String id;
  final String name;
  final String? logoUrl;
  final String? country;
  final bool isPremium;
  final bool isPopular;
  final int sortOrder;
  final bool isActive;

  const CarBrand({
    required this.id,
    required this.name,
    this.logoUrl,
    this.country,
    this.isPremium = false,
    this.isPopular = false,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarBrand.fromJson(Map<String, dynamic> json) {
    return CarBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      country: json['country'] as String?,
      isPremium: json['is_premium'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'country': country,
      'is_premium': isPremium,
      'is_popular': isPopular,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}

/// Araç Özelliği
class CarFeature {
  final String id;
  final String name;
  final String category;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  const CarFeature({
    required this.id,
    required this.name,
    required this.category,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CarFeature.fromJson(Map<String, dynamic> json) {
    return CarFeature(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'icon': icon,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }
}

/// Araç Satıcısı / Galeri
class CarDealer {
  final String id;
  final String userId;
  final DealerType dealerType;
  final String? businessName;
  final String ownerName;
  final String phone;
  final String? email;
  final String? taxNumber;
  final String city;
  final String? district;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? logoUrl;
  final String? coverUrl;
  final List<String> galleryImages;
  final Map<String, dynamic>? workingHours;
  final int totalListings;
  final int activeListings;
  final int totalSold;
  final double averageRating;
  final int totalReviews;
  final int responseRate;
  final int avgResponseTime;
  final String status;
  final bool isVerified;
  final bool isPremiumDealer;
  final String membershipType;
  final DateTime? membershipStartsAt;
  final DateTime? membershipExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CarDealer({
    required this.id,
    required this.userId,
    required this.dealerType,
    this.businessName,
    required this.ownerName,
    required this.phone,
    this.email,
    this.taxNumber,
    required this.city,
    this.district,
    this.address,
    this.latitude,
    this.longitude,
    this.logoUrl,
    this.coverUrl,
    this.galleryImages = const [],
    this.workingHours,
    this.totalListings = 0,
    this.activeListings = 0,
    this.totalSold = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.responseRate = 0,
    this.avgResponseTime = 0,
    this.status = 'pending',
    this.isVerified = false,
    this.isPremiumDealer = false,
    this.membershipType = 'free',
    this.membershipStartsAt,
    this.membershipExpiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CarDealer.fromJson(Map<String, dynamic> json) {
    return CarDealer(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dealerType: DealerType.fromString(json['dealer_type'] as String?) ?? DealerType.individual,
      businessName: json['business_name'] as String?,
      ownerName: json['owner_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      taxNumber: json['tax_number'] as String?,
      city: json['city'] as String,
      district: json['district'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      galleryImages: (json['gallery_images'] as List?)?.cast<String>() ?? [],
      workingHours: json['working_hours'] as Map<String, dynamic>?,
      totalListings: json['total_listings'] as int? ?? 0,
      activeListings: json['active_listings'] as int? ?? 0,
      totalSold: json['total_sold'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      responseRate: json['response_rate'] as int? ?? 0,
      avgResponseTime: json['avg_response_time'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      isVerified: json['is_verified'] as bool? ?? false,
      isPremiumDealer: json['is_premium_dealer'] as bool? ?? false,
      membershipType: json['membership_type'] as String? ?? 'free',
      membershipStartsAt: json['membership_starts_at'] != null
          ? DateTime.parse(json['membership_starts_at'] as String)
          : null,
      membershipExpiresAt: json['membership_expires_at'] != null
          ? DateTime.parse(json['membership_expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'dealer_type': dealerType.name,
      'business_name': businessName,
      'owner_name': ownerName,
      'phone': phone,
      'email': email,
      'tax_number': taxNumber,
      'city': city,
      'district': district,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'logo_url': logoUrl,
      'cover_url': coverUrl,
      'gallery_images': galleryImages,
      'working_hours': workingHours,
      'total_listings': totalListings,
      'active_listings': activeListings,
      'total_sold': totalSold,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'response_rate': responseRate,
      'avg_response_time': avgResponseTime,
      'status': status,
      'is_verified': isVerified,
      'is_premium_dealer': isPremiumDealer,
      'membership_type': membershipType,
      'membership_starts_at': membershipStartsAt?.toIso8601String(),
      'membership_expires_at': membershipExpiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayName => businessName ?? ownerName;
}

/// Araç İlanı
class CarListing {
  final String id;
  final String? dealerId;
  final String userId;
  final String title;
  final String? description;
  final String brandId;
  final String brandName;
  final String modelName;
  final int year;
  final CarBodyType bodyType;
  final CarFuelType fuelType;
  final CarTransmission transmission;
  final CarTraction traction;
  final int? engineCc;
  final int? horsepower;
  final int mileage;
  final String? exteriorColor;
  final String? interiorColor;
  final CarCondition condition;
  final int previousOwners;
  final bool hasOriginalPaint;
  final bool hasAccidentHistory;
  final bool hasWarranty;
  final String? warrantyDetails;
  final String? damageReport;
  final String? plateCity;
  final String? serviceHistory;
  final double price;
  final String currency;
  final bool isPriceNegotiable;
  final bool isExchangeAccepted;
  final List<String> images;
  final String? videoUrl;
  final List<String> features;
  final String? location;
  final String? city;
  final String? district;
  final CarListingStatus status;
  final String? rejectionReason;
  final bool isFeatured;
  final bool isPremium;
  final DateTime? featuredUntil;
  final DateTime? premiumUntil;
  final int viewCount;
  final int favoriteCount;
  final int contactCount;
  final int shareCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final DateTime? soldAt;
  final DateTime? expiresAt;

  // İlişkili veriler
  final CarDealer? dealer;

  const CarListing({
    required this.id,
    this.dealerId,
    required this.userId,
    required this.title,
    this.description,
    required this.brandId,
    required this.brandName,
    required this.modelName,
    required this.year,
    required this.bodyType,
    required this.fuelType,
    required this.transmission,
    this.traction = CarTraction.fwd,
    this.engineCc,
    this.horsepower,
    required this.mileage,
    this.exteriorColor,
    this.interiorColor,
    this.condition = CarCondition.good,
    this.previousOwners = 1,
    this.hasOriginalPaint = true,
    this.hasAccidentHistory = false,
    this.hasWarranty = false,
    this.warrantyDetails,
    this.damageReport,
    this.plateCity,
    this.serviceHistory,
    required this.price,
    this.currency = 'TRY',
    this.isPriceNegotiable = false,
    this.isExchangeAccepted = false,
    this.images = const [],
    this.videoUrl,
    this.features = const [],
    this.location,
    this.city,
    this.district,
    this.status = CarListingStatus.pending,
    this.rejectionReason,
    this.isFeatured = false,
    this.isPremium = false,
    this.featuredUntil,
    this.premiumUntil,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.contactCount = 0,
    this.shareCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.soldAt,
    this.expiresAt,
    this.dealer,
  });

  factory CarListing.fromJson(Map<String, dynamic> json) {
    return CarListing(
      id: json['id'] as String,
      dealerId: json['dealer_id'] as String?,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      brandId: json['brand_id'] as String,
      brandName: json['brand_name'] as String,
      modelName: json['model_name'] as String,
      year: json['year'] as int,
      bodyType: CarBodyType.fromString(json['body_type'] as String?) ?? CarBodyType.sedan,
      fuelType: CarFuelType.fromString(json['fuel_type'] as String?) ?? CarFuelType.petrol,
      transmission: CarTransmission.fromString(json['transmission'] as String?) ?? CarTransmission.manual,
      traction: CarTraction.fromString(json['traction'] as String?) ?? CarTraction.fwd,
      engineCc: json['engine_cc'] as int?,
      horsepower: json['horsepower'] as int?,
      mileage: json['mileage'] as int,
      exteriorColor: json['exterior_color'] as String?,
      interiorColor: json['interior_color'] as String?,
      condition: CarCondition.fromString(json['condition'] as String?) ?? CarCondition.good,
      previousOwners: json['previous_owners'] as int? ?? 1,
      hasOriginalPaint: json['has_original_paint'] as bool? ?? true,
      hasAccidentHistory: json['has_accident_history'] as bool? ?? false,
      hasWarranty: json['has_warranty'] as bool? ?? false,
      warrantyDetails: json['warranty_details'] as String?,
      damageReport: json['damage_report'] as String?,
      plateCity: json['plate_city'] as String?,
      serviceHistory: json['service_history'] as String?,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'TRY',
      isPriceNegotiable: json['is_price_negotiable'] as bool? ?? false,
      isExchangeAccepted: json['is_exchange_accepted'] as bool? ?? false,
      images: (json['images'] as List?)?.cast<String>() ?? [],
      videoUrl: json['video_url'] as String?,
      features: (json['features'] as List?)?.cast<String>() ?? [],
      location: json['location'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      status: CarListingStatus.fromString(json['status'] as String?) ?? CarListingStatus.pending,
      rejectionReason: json['rejection_reason'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      featuredUntil: json['featured_until'] != null
          ? DateTime.parse(json['featured_until'] as String)
          : null,
      premiumUntil: json['premium_until'] != null
          ? DateTime.parse(json['premium_until'] as String)
          : null,
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      contactCount: json['contact_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      soldAt: json['sold_at'] != null
          ? DateTime.parse(json['sold_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      dealer: json['dealer'] != null
          ? CarDealer.fromJson(json['dealer'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dealer_id': dealerId,
      'user_id': userId,
      'title': title,
      'description': description,
      'brand_id': brandId,
      'brand_name': brandName,
      'model_name': modelName,
      'year': year,
      'body_type': bodyType.name,
      'fuel_type': fuelType.name,
      'transmission': transmission.name,
      'traction': traction.name,
      'engine_cc': engineCc,
      'horsepower': horsepower,
      'mileage': mileage,
      'exterior_color': exteriorColor,
      'interior_color': interiorColor,
      'condition': condition.name,
      'previous_owners': previousOwners,
      'has_original_paint': hasOriginalPaint,
      'has_accident_history': hasAccidentHistory,
      'has_warranty': hasWarranty,
      'warranty_details': warrantyDetails,
      'damage_report': damageReport,
      'plate_city': plateCity,
      'service_history': serviceHistory,
      'price': price,
      'currency': currency,
      'is_price_negotiable': isPriceNegotiable,
      'is_exchange_accepted': isExchangeAccepted,
      'images': images,
      'video_url': videoUrl,
      'features': features,
      'location': location,
      'city': city,
      'district': district,
      'status': status.name,
      'rejection_reason': rejectionReason,
      'is_featured': isFeatured,
      'is_premium': isPremium,
      'featured_until': featuredUntil?.toIso8601String(),
      'premium_until': premiumUntil?.toIso8601String(),
      'view_count': viewCount,
      'favorite_count': favoriteCount,
      'contact_count': contactCount,
      'share_count': shareCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'sold_at': soldAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  /// Tam araç adı
  String get fullName => '$brandName $modelName $year';

  /// Model adı
  String get model => modelName;

  /// Dış renk
  String? get color => exteriorColor;

  /// Plaka
  String? get plateNumber => plateCity;

  /// Motor hacmi
  int? get engineSize => engineCc;

  /// Beygir gücü
  int? get horsePower => horsepower;

  /// Pazarlık
  bool get isNegotiable => isPriceNegotiable;

  /// Formatlı fiyat
  String get formattedPrice {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted TL';
  }

  /// KM formatı
  String get formattedMileage {
    final formatted = mileage.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted km';
  }

  /// İlan yaşı
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else {
      return '${difference.inMinutes} dakika önce';
    }
  }

  CarListing copyWith({
    String? id,
    String? dealerId,
    String? userId,
    String? title,
    String? description,
    String? brandId,
    String? brandName,
    String? modelName,
    int? year,
    CarBodyType? bodyType,
    CarFuelType? fuelType,
    CarTransmission? transmission,
    CarTraction? traction,
    int? engineCc,
    int? horsepower,
    int? mileage,
    String? exteriorColor,
    String? interiorColor,
    CarCondition? condition,
    int? previousOwners,
    bool? hasOriginalPaint,
    bool? hasAccidentHistory,
    bool? hasWarranty,
    String? warrantyDetails,
    String? damageReport,
    String? plateCity,
    String? serviceHistory,
    double? price,
    String? currency,
    bool? isPriceNegotiable,
    bool? isExchangeAccepted,
    List<String>? images,
    String? videoUrl,
    List<String>? features,
    String? location,
    String? city,
    String? district,
    CarListingStatus? status,
    String? rejectionReason,
    bool? isFeatured,
    bool? isPremium,
    DateTime? featuredUntil,
    DateTime? premiumUntil,
    int? viewCount,
    int? favoriteCount,
    int? contactCount,
    int? shareCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? soldAt,
    DateTime? expiresAt,
    CarDealer? dealer,
  }) {
    return CarListing(
      id: id ?? this.id,
      dealerId: dealerId ?? this.dealerId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      modelName: modelName ?? this.modelName,
      year: year ?? this.year,
      bodyType: bodyType ?? this.bodyType,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      traction: traction ?? this.traction,
      engineCc: engineCc ?? this.engineCc,
      horsepower: horsepower ?? this.horsepower,
      mileage: mileage ?? this.mileage,
      exteriorColor: exteriorColor ?? this.exteriorColor,
      interiorColor: interiorColor ?? this.interiorColor,
      condition: condition ?? this.condition,
      previousOwners: previousOwners ?? this.previousOwners,
      hasOriginalPaint: hasOriginalPaint ?? this.hasOriginalPaint,
      hasAccidentHistory: hasAccidentHistory ?? this.hasAccidentHistory,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      warrantyDetails: warrantyDetails ?? this.warrantyDetails,
      damageReport: damageReport ?? this.damageReport,
      plateCity: plateCity ?? this.plateCity,
      serviceHistory: serviceHistory ?? this.serviceHistory,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isPriceNegotiable: isPriceNegotiable ?? this.isPriceNegotiable,
      isExchangeAccepted: isExchangeAccepted ?? this.isExchangeAccepted,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
      features: features ?? this.features,
      location: location ?? this.location,
      city: city ?? this.city,
      district: district ?? this.district,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      isFeatured: isFeatured ?? this.isFeatured,
      isPremium: isPremium ?? this.isPremium,
      featuredUntil: featuredUntil ?? this.featuredUntil,
      premiumUntil: premiumUntil ?? this.premiumUntil,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      contactCount: contactCount ?? this.contactCount,
      shareCount: shareCount ?? this.shareCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      soldAt: soldAt ?? this.soldAt,
      expiresAt: expiresAt ?? this.expiresAt,
      dealer: dealer ?? this.dealer,
    );
  }
}

/// Promosyon Fiyatı
class PromotionPrice {
  final String id;
  final String promotionType;
  final int durationDays;
  final double price;
  final double? discountedPrice;
  final String? description;
  final List<String> benefits;
  final bool isActive;
  final int sortOrder;

  const PromotionPrice({
    required this.id,
    required this.promotionType,
    required this.durationDays,
    required this.price,
    this.discountedPrice,
    this.description,
    this.benefits = const [],
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory PromotionPrice.fromJson(Map<String, dynamic> json) {
    // price string veya num olabilir
    double parsePrice(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return PromotionPrice(
      id: json['id'] as String,
      promotionType: json['promotion_type'] as String,
      durationDays: json['duration_days'] as int,
      price: parsePrice(json['price']),
      discountedPrice: json['discounted_price'] != null ? parsePrice(json['discounted_price']) : null,
      description: json['description'] as String?,
      benefits: (json['benefits'] as List?)?.cast<String>() ?? [],
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  double get effectivePrice => discountedPrice ?? price;

  bool get isFeatured => promotionType == 'featured' || promotionType == 'premium';

  String get formattedPrice {
    final formatted = effectivePrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted TL';
  }

  bool get hasDiscount => discountedPrice != null && discountedPrice! < price;

  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((price - discountedPrice!) / price) * 100).round();
  }
}

/// Aktif Promosyon
class CarListingPromotion {
  final String id;
  final String listingId;
  final String userId;
  final String promotionType;
  final int durationDays;
  final DateTime startedAt;
  final DateTime expiresAt;
  final double? amountPaid;
  final String? currency;
  final String? paymentMethod;
  final String? paymentReference;
  final String status;
  final int viewsBefore;
  final int viewsDuring;
  final int contactsBefore;
  final int contactsDuring;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // İlişkili veriler
  final CarListing? listing;

  const CarListingPromotion({
    required this.id,
    required this.listingId,
    required this.userId,
    required this.promotionType,
    required this.durationDays,
    required this.startedAt,
    required this.expiresAt,
    this.amountPaid,
    this.currency,
    this.paymentMethod,
    this.paymentReference,
    this.status = 'active',
    this.viewsBefore = 0,
    this.viewsDuring = 0,
    this.contactsBefore = 0,
    this.contactsDuring = 0,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
    this.updatedAt,
    this.listing,
  });

  factory CarListingPromotion.fromJson(Map<String, dynamic> json) {
    return CarListingPromotion(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      userId: json['user_id'] as String,
      promotionType: json['promotion_type'] as String,
      durationDays: json['duration_days'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      amountPaid: (json['amount_paid'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentReference: json['payment_reference'] as String?,
      status: json['status'] as String? ?? 'active',
      viewsBefore: json['views_before'] as int? ?? 0,
      viewsDuring: json['views_during'] as int? ?? 0,
      contactsBefore: json['contacts_before'] as int? ?? 0,
      contactsDuring: json['contacts_during'] as int? ?? 0,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      listing: json['car_listings'] != null
          ? CarListing.fromJson(json['car_listings'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActive => status == 'active' && expiresAt.isAfter(DateTime.now());

  bool get isFeatured => promotionType == 'featured' || promotionType == 'premium';

  DateTime get endDate => expiresAt;

  int get daysRemaining {
    if (!isActive) return 0;
    return expiresAt.difference(DateTime.now()).inDays;
  }

  double get viewsIncrease {
    if (viewsBefore == 0) return viewsDuring > 0 ? 100 : 0;
    return ((viewsDuring - viewsBefore) / viewsBefore) * 100;
  }
}

/// İletişim Talebi
class CarContactRequest {
  final String id;
  final String listingId;
  final String? dealerId;
  final String? userId;
  final String name;
  final String phone;
  final String? email;
  final String? message;
  final String status;
  final DateTime? repliedAt;
  final String? replyMessage;
  final DateTime createdAt;

  const CarContactRequest({
    required this.id,
    required this.listingId,
    this.dealerId,
    this.userId,
    required this.name,
    required this.phone,
    this.email,
    this.message,
    this.status = 'new',
    this.repliedAt,
    this.replyMessage,
    required this.createdAt,
  });

  factory CarContactRequest.fromJson(Map<String, dynamic> json) {
    return CarContactRequest(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      dealerId: json['dealer_id'] as String?,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'new',
      repliedAt: json['replied_at'] != null
          ? DateTime.parse(json['replied_at'] as String)
          : null,
      replyMessage: json['reply_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
