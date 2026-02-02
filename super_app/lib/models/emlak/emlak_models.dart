// Emlak (Real Estate) Models - Premium Design
import 'package:flutter/material.dart';

/// Dynamic Property Type Model - DB'den çekilir
class PropertyTypeModel {
  final String id;
  final String name;
  final String label;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  const PropertyTypeModel({
    required this.id,
    required this.name,
    required this.label,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory PropertyTypeModel.fromJson(Map<String, dynamic> json) {
    return PropertyTypeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      label: json['label'] as String? ?? json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  IconData get iconData {
    switch (icon?.toLowerCase() ?? name.toLowerCase()) {
      case 'apartment':
      case 'daire':
        return Icons.apartment;
      case 'villa':
        return Icons.villa;
      case 'residence':
      case 'rezidans':
        return Icons.business;
      case 'land':
      case 'arsa':
        return Icons.landscape;
      case 'office':
      case 'ofis':
        return Icons.work_outline;
      case 'shop':
      case 'dükkan':
      case 'dukkan':
        return Icons.storefront;
      case 'building':
      case 'bina':
        return Icons.domain;
      case 'penthouse':
        return Icons.roofing;
      default:
        return Icons.home;
    }
  }
}

/// Dynamic Amenity Model - DB'den çekilir
class AmenityModel {
  final String id;
  final String name;
  final String label;
  final String? icon;
  final String? category;
  final int sortOrder;
  final bool isActive;

  const AmenityModel({
    required this.id,
    required this.name,
    required this.label,
    this.icon,
    this.category,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    return AmenityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      label: json['label'] as String? ?? json['name'] as String,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  IconData get iconData {
    switch (icon?.toLowerCase() ?? name.toLowerCase()) {
      case 'parking':
      case 'otopark':
        return Icons.local_parking;
      case 'pool':
      case 'havuz':
        return Icons.pool;
      case 'gym':
      case 'spor salonu':
        return Icons.fitness_center;
      case 'security':
      case 'güvenlik':
        return Icons.security;
      case 'elevator':
      case 'asansör':
        return Icons.elevator;
      case 'balcony':
      case 'balkon':
        return Icons.balcony;
      case 'garden':
      case 'bahçe':
        return Icons.yard;
      case 'terrace':
      case 'teras':
        return Icons.deck;
      case 'furniture':
      case 'eşyalı':
        return Icons.chair;
      case 'air_conditioning':
      case 'klima':
        return Icons.ac_unit;
      case 'heating':
      case 'ısıtma':
        return Icons.thermostat;
      case 'internet':
        return Icons.wifi;
      case 'smart_home':
      case 'akıllı ev':
        return Icons.home_max;
      default:
        return Icons.check_circle;
    }
  }
}

/// Property type enumeration - Fallback için korunuyor
enum PropertyType {
  apartment('Daire', Icons.apartment),
  villa('Villa', Icons.villa),
  residence('Rezidans', Icons.business),
  land('Arsa', Icons.landscape),
  office('Ofis', Icons.work_outline),
  shop('Dükkan', Icons.storefront),
  building('Bina', Icons.domain),
  penthouse('Penthouse', Icons.roofing);

  final String label;
  final IconData icon;
  const PropertyType(this.label, this.icon);
}

/// Listing type - Sale or Rent
enum ListingType {
  sale('Satılık', Color(0xFF10B981)),
  rent('Kiralık', Color(0xFF3B82F6));

  final String label;
  final Color color;
  const ListingType(this.label, this.color);
}

/// Property status
enum PropertyStatus {
  active('Aktif'),
  pending('Onay Bekliyor'),
  sold('Satıldı'),
  rented('Kiralandı'),
  reserved('Rezerve'),
  rejected('Reddedildi');

  final String label;
  const PropertyStatus(this.label);
}

/// Sort options for property listing
enum SortOption {
  newest('En Yeni', Icons.access_time),
  oldest('En Eski', Icons.history),
  priceLowToHigh('Fiyat (Düşük-Yüksek)', Icons.trending_down),
  priceHighToLow('Fiyat (Yüksek-Düşük)', Icons.trending_up),
  areaLargest('Alan (Büyük-Küçük)', Icons.square_foot),
  areaSmallest('Alan (Küçük-Büyük)', Icons.crop_square),
  roomsMore('Oda Sayısı (Çok-Az)', Icons.bed),
  roomsLess('Oda Sayısı (Az-Çok)', Icons.single_bed);

  final String label;
  final IconData icon;
  const SortOption(this.label, this.icon);
}

/// Property feature model
class PropertyFeature {
  final IconData icon;
  final String label;
  final String value;

  const PropertyFeature({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Agent/Owner model
class PropertyAgent {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? imageUrl;
  final String? company;
  final double rating;
  final int totalListings;
  final int totalReviews;
  final bool isVerified;
  final bool isRealtor; // Emlakçı mı, bireysel mi?

  const PropertyAgent({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.imageUrl,
    this.company,
    this.rating = 0,
    this.totalListings = 0,
    this.totalReviews = 0,
    this.isVerified = false,
    this.isRealtor = false,
  });

  /// Supabase user profile'dan PropertyAgent oluştur
  factory PropertyAgent.fromJson(Map<String, dynamic> json, String ownerId) {
    // Emlakçı bilgisi varsa onu kullan (realtor bir liste olabilir, ilk elemanı al)
    final realtorRaw = json['realtor'];
    Map<String, dynamic>? realtorData;

    if (realtorRaw is List && realtorRaw.isNotEmpty) {
      realtorData = realtorRaw.first as Map<String, dynamic>?;
    } else if (realtorRaw is Map<String, dynamic>) {
      realtorData = realtorRaw;
    }

    if (realtorData != null && realtorData['status'] == 'approved') {
      return PropertyAgent(
        id: ownerId,
        name: realtorData['company_name'] as String? ?? json['full_name'] as String? ?? 'Emlakçı',
        phone: realtorData['phone'] as String? ?? json['phone'] as String? ?? '',
        email: realtorData['email'] as String? ?? json['email'] as String?,
        imageUrl: realtorData['profile_image'] as String? ?? json['avatar_url'] as String?,
        company: realtorData['company_name'] as String?,
        rating: (realtorData['average_rating'] as num?)?.toDouble() ?? 0,
        totalListings: realtorData['total_sales'] as int? ?? 0,
        totalReviews: realtorData['total_reviews'] as int? ?? 0,
        isVerified: realtorData['is_verified'] as bool? ?? false,
        isRealtor: true,
      );
    }

    // Bireysel ilan sahibi
    return PropertyAgent(
      id: ownerId,
      name: json['full_name'] as String? ?? 'İlan Sahibi',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      imageUrl: json['avatar_url'] as String?,
      company: null,
      rating: 0,
      totalListings: 0,
      totalReviews: 0,
      isVerified: false,
      isRealtor: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'phone': phone,
      'email': email,
      'avatar_url': imageUrl,
      'company': company,
      'rating': rating,
      'total_listings': totalListings,
      'is_verified': isVerified,
    };
  }
}

/// Location model
class PropertyLocation {
  final String city;
  final String district;
  final String neighborhood;
  final String? address;
  final double? latitude;
  final double? longitude;

  const PropertyLocation({
    required this.city,
    required this.district,
    required this.neighborhood,
    this.address,
    this.latitude,
    this.longitude,
  });

  String get fullAddress => '$neighborhood, $district, $city';
  String get shortAddress => '$district, $city';
}

/// Main Property model
class Property {
  final String id;
  final String userId;
  final String title;
  final String description;
  final PropertyType type;
  final ListingType listingType;
  final PropertyStatus status;
  final double price;
  final String? currency;
  final PropertyLocation location;
  final PropertyAgent? agent;
  final List<String> images;
  final int rooms;
  final int bathrooms;
  final int squareMeters;
  final int? floor;
  final int? totalFloors;
  final int? buildingAge;
  final bool hasParking;
  final bool hasBalcony;
  final bool hasFurniture;
  final bool hasPool;
  final bool hasGym;
  final bool hasSecurity;
  final bool hasElevator;
  final bool isSmartHome;
  final List<String> amenities;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int viewCount;
  final int favoriteCount;
  final bool isFeatured;
  final bool isPremium;

  const Property({
    required this.id,
    this.userId = '',
    required this.title,
    required this.description,
    required this.type,
    required this.listingType,
    required this.status,
    required this.price,
    this.currency = 'TL',
    required this.location,
    this.agent,
    required this.images,
    required this.rooms,
    required this.bathrooms,
    required this.squareMeters,
    this.floor,
    this.totalFloors,
    this.buildingAge,
    this.hasParking = false,
    this.hasBalcony = false,
    this.hasFurniture = false,
    this.hasPool = false,
    this.hasGym = false,
    this.hasSecurity = false,
    this.hasElevator = false,
    this.isSmartHome = false,
    this.amenities = const [],
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.isFeatured = false,
    this.isPremium = false,
  });

  /// Supabase JSON'dan Property oluştur
  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: PropertyType.values.firstWhere(
        (e) => e.name == json['property_type'],
        orElse: () => PropertyType.apartment,
      ),
      listingType: ListingType.values.firstWhere(
        (e) => e.name == json['listing_type'],
        orElse: () => ListingType.sale,
      ),
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.pending,
      ),
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'TL',
      location: PropertyLocation(
        city: json['city'] as String? ?? '',
        district: json['district'] as String? ?? '',
        neighborhood: json['neighborhood'] as String? ?? '',
        address: json['address'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      ),
      agent: json['owner_profile'] != null
          ? PropertyAgent.fromJson(json['owner_profile'] as Map<String, dynamic>, json['user_id'] as String)
          : null,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      rooms: json['rooms'] as int? ?? 0,
      bathrooms: json['bathrooms'] as int? ?? 0,
      squareMeters: json['square_meters'] as int? ?? 0,
      floor: json['floor'] as int?,
      totalFloors: json['total_floors'] as int?,
      buildingAge: json['building_age'] as int?,
      hasParking: json['has_parking'] as bool? ?? false,
      hasBalcony: json['has_balcony'] as bool? ?? false,
      hasFurniture: json['has_furniture'] as bool? ?? false,
      hasPool: json['has_pool'] as bool? ?? false,
      hasGym: json['has_gym'] as bool? ?? false,
      hasSecurity: json['has_security'] as bool? ?? false,
      hasElevator: json['has_elevator'] as bool? ?? false,
      isSmartHome: json['is_smart_home'] as bool? ?? false,
      amenities: (json['amenities'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  /// Property'yi Supabase JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'property_type': type.name,
      'listing_type': listingType.name,
      'status': status.name,
      'price': price,
      'currency': currency,
      'city': location.city,
      'district': location.district,
      'neighborhood': location.neighborhood,
      'address': location.address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'rooms': rooms,
      'bathrooms': bathrooms,
      'square_meters': squareMeters,
      'floor': floor,
      'total_floors': totalFloors,
      'building_age': buildingAge,
      'has_parking': hasParking,
      'has_balcony': hasBalcony,
      'has_furniture': hasFurniture,
      'has_pool': hasPool,
      'has_gym': hasGym,
      'has_security': hasSecurity,
      'has_elevator': hasElevator,
      'is_smart_home': isSmartHome,
      'amenities': amenities,
      'images': images,
      'is_featured': isFeatured,
      'is_premium': isPremium,
    };
  }

  /// Kopyalama metodu
  Property copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    PropertyType? type,
    ListingType? listingType,
    PropertyStatus? status,
    double? price,
    String? currency,
    PropertyLocation? location,
    PropertyAgent? agent,
    List<String>? images,
    int? rooms,
    int? bathrooms,
    int? squareMeters,
    int? floor,
    int? totalFloors,
    int? buildingAge,
    bool? hasParking,
    bool? hasBalcony,
    bool? hasFurniture,
    bool? hasPool,
    bool? hasGym,
    bool? hasSecurity,
    bool? hasElevator,
    bool? isSmartHome,
    List<String>? amenities,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    int? favoriteCount,
    bool? isFeatured,
    bool? isPremium,
  }) {
    return Property(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      listingType: listingType ?? this.listingType,
      status: status ?? this.status,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      location: location ?? this.location,
      agent: agent ?? this.agent,
      images: images ?? this.images,
      rooms: rooms ?? this.rooms,
      bathrooms: bathrooms ?? this.bathrooms,
      squareMeters: squareMeters ?? this.squareMeters,
      floor: floor ?? this.floor,
      totalFloors: totalFloors ?? this.totalFloors,
      buildingAge: buildingAge ?? this.buildingAge,
      hasParking: hasParking ?? this.hasParking,
      hasBalcony: hasBalcony ?? this.hasBalcony,
      hasFurniture: hasFurniture ?? this.hasFurniture,
      hasPool: hasPool ?? this.hasPool,
      hasGym: hasGym ?? this.hasGym,
      hasSecurity: hasSecurity ?? this.hasSecurity,
      hasElevator: hasElevator ?? this.hasElevator,
      isSmartHome: isSmartHome ?? this.isSmartHome,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFeatured: isFeatured ?? this.isFeatured,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M $currency';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K $currency';
    }
    return '${price.toStringAsFixed(0)} $currency';
  }

  String get fullFormattedPrice {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted $currency';
  }

  List<PropertyFeature> get features => [
    PropertyFeature(icon: Icons.bed_outlined, label: 'Oda', value: '$rooms+1'),
    PropertyFeature(icon: Icons.bathtub_outlined, label: 'Banyo', value: '$bathrooms'),
    PropertyFeature(icon: Icons.square_foot, label: 'm²', value: '$squareMeters'),
    if (floor != null)
      PropertyFeature(icon: Icons.stairs, label: 'Kat', value: '$floor/$totalFloors'),
  ];
}

/// Search filter model
class PropertyFilter {
  final PropertyType? type;
  final ListingType? listingType;
  final double? minPrice;
  final double? maxPrice;
  final int? minRooms;
  final int? maxRooms;
  final int? minSquareMeters;
  final int? maxSquareMeters;
  final String? city;
  final String? district;
  final bool? hasParking;
  final bool? hasPool;
  final bool? hasFurniture;

  const PropertyFilter({
    this.type,
    this.listingType,
    this.minPrice,
    this.maxPrice,
    this.minRooms,
    this.maxRooms,
    this.minSquareMeters,
    this.maxSquareMeters,
    this.city,
    this.district,
    this.hasParking,
    this.hasPool,
    this.hasFurniture,
  });

  PropertyFilter copyWith({
    PropertyType? type,
    ListingType? listingType,
    double? minPrice,
    double? maxPrice,
    int? minRooms,
    int? maxRooms,
    int? minSquareMeters,
    int? maxSquareMeters,
    String? city,
    String? district,
    bool? hasParking,
    bool? hasPool,
    bool? hasFurniture,
  }) {
    return PropertyFilter(
      type: type ?? this.type,
      listingType: listingType ?? this.listingType,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRooms: minRooms ?? this.minRooms,
      maxRooms: maxRooms ?? this.maxRooms,
      minSquareMeters: minSquareMeters ?? this.minSquareMeters,
      maxSquareMeters: maxSquareMeters ?? this.maxSquareMeters,
      city: city ?? this.city,
      district: district ?? this.district,
      hasParking: hasParking ?? this.hasParking,
      hasPool: hasPool ?? this.hasPool,
      hasFurniture: hasFurniture ?? this.hasFurniture,
    );
  }
}

// Note: EmlakDemoData class has been removed - all data now comes from Supabase

/// Emlak theme colors with full dark mode support
class EmlakColors {
  // Primary gradient - Premium cyan/blue
  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color primaryLight = Color(0xFF38BDF8);

  // Secondary - Elegant teal
  static const Color secondary = Color(0xFF14B8A6);
  static const Color secondaryDark = Color(0xFF0D9488);

  // Accent - Warm gold for premium items
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFBBF24);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF0EA5E9),
    Color(0xFF06B6D4),
  ];

  static const List<Color> premiumGradient = [
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  static const List<Color> darkGradient = [
    Color(0xFF1E293B),
    Color(0xFF0F172A),
  ];

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ============ LIGHT MODE COLORS ============
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // ============ DARK MODE COLORS ============
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF1E293B);

  // ============ HELPER METHODS ============
  static Color background(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textTertiary(bool isDark) => isDark ? textTertiaryDark : textTertiaryLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color divider(bool isDark) => isDark ? dividerDark : dividerLight;

  // Input/Form colors
  static Color inputBackground(bool isDark) => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color inputBorder(bool isDark) => isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
  static Color inputBorderFocused(bool isDark) => primary;

  // Overlay colors
  static Color overlayBackground(bool isDark) => isDark
      ? const Color(0xFF0F172A).withValues(alpha: 0.8)
      : Colors.black.withValues(alpha: 0.5);

  // Shimmer/Skeleton loading colors
  static Color shimmerBase(bool isDark) => isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  static Color shimmerHighlight(bool isDark) => isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);
}
