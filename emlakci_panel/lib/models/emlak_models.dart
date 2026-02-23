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
      case 'field':
      case 'tarla':
        return Icons.grass;
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
  field('Tarla', Icons.grass),
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
  reserved('Rezerve');

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
  final int totalListings;
  final bool isVerified;

  const PropertyAgent({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.imageUrl,
    this.company,
    this.totalListings = 0,
    this.isVerified = false,
  });

  /// Supabase user profile'dan PropertyAgent oluştur
  factory PropertyAgent.fromJson(Map<String, dynamic> json, String oderId) {
    return PropertyAgent(
      id: oderId,
      name: json['full_name'] as String? ?? 'İlan Sahibi',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      imageUrl: json['avatar_url'] as String?,
      company: json['company'] as String?,
      totalListings: json['total_listings'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
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
  final int? netSquareMeters;
  final String? heatingType;
  final String? facingDirection;
  final String? interiorStatus;
  final String? deedType;
  final String? viewType;
  final bool hasParking;
  final bool hasBalcony;
  final bool hasFurniture;
  final bool hasPool;
  final bool hasGym;
  final bool hasSecurity;
  final bool hasElevator;
  final bool isSmartHome;
  final bool hasGarden;
  final bool hasTerrace;
  final bool hasStorage;
  final bool hasFireplace;
  final bool hasAirConditioning;
  final bool hasGenerator;
  final bool hasSatellite;
  final bool hasInternet;
  final bool hasNaturalGas;
  final bool hasSteelDoor;
  final bool hasVideoIntercom;
  final bool hasAlarm;
  final bool hasParentBathroom;
  final bool hasBuiltinKitchen;
  final bool hasJacuzzi;
  final bool hasSauna;
  final bool hasBarbeque;
  final bool hasDoorman;
  final bool isInComplex;
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
    this.netSquareMeters,
    this.heatingType,
    this.facingDirection,
    this.interiorStatus,
    this.deedType,
    this.viewType,
    this.hasParking = false,
    this.hasBalcony = false,
    this.hasFurniture = false,
    this.hasPool = false,
    this.hasGym = false,
    this.hasSecurity = false,
    this.hasElevator = false,
    this.isSmartHome = false,
    this.hasGarden = false,
    this.hasTerrace = false,
    this.hasStorage = false,
    this.hasFireplace = false,
    this.hasAirConditioning = false,
    this.hasGenerator = false,
    this.hasSatellite = false,
    this.hasInternet = false,
    this.hasNaturalGas = false,
    this.hasSteelDoor = false,
    this.hasVideoIntercom = false,
    this.hasAlarm = false,
    this.hasParentBathroom = false,
    this.hasBuiltinKitchen = false,
    this.hasJacuzzi = false,
    this.hasSauna = false,
    this.hasBarbeque = false,
    this.hasDoorman = false,
    this.isInComplex = false,
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
      netSquareMeters: json['net_square_meters'] as int?,
      heatingType: json['heating_type'] as String?,
      facingDirection: json['facing_direction'] as String?,
      interiorStatus: json['interior_status'] as String?,
      deedType: json['deed_type'] as String?,
      viewType: json['view_type'] as String?,
      hasParking: json['has_parking'] as bool? ?? false,
      hasBalcony: json['has_balcony'] as bool? ?? false,
      hasFurniture: json['has_furniture'] as bool? ?? false,
      hasPool: json['has_pool'] as bool? ?? false,
      hasGym: json['has_gym'] as bool? ?? false,
      hasSecurity: json['has_security'] as bool? ?? false,
      hasElevator: json['has_elevator'] as bool? ?? false,
      isSmartHome: json['is_smart_home'] as bool? ?? false,
      hasGarden: json['has_garden'] as bool? ?? false,
      hasTerrace: json['has_terrace'] as bool? ?? false,
      hasStorage: json['has_storage'] as bool? ?? false,
      hasFireplace: json['has_fireplace'] as bool? ?? false,
      hasAirConditioning: json['has_air_conditioning'] as bool? ?? false,
      hasGenerator: json['has_generator'] as bool? ?? false,
      hasSatellite: json['has_satellite'] as bool? ?? false,
      hasInternet: json['has_internet'] as bool? ?? false,
      hasNaturalGas: json['has_natural_gas'] as bool? ?? false,
      hasSteelDoor: json['has_steel_door'] as bool? ?? false,
      hasVideoIntercom: json['has_video_intercom'] as bool? ?? false,
      hasAlarm: json['has_alarm'] as bool? ?? false,
      hasParentBathroom: json['has_parent_bathroom'] as bool? ?? false,
      hasBuiltinKitchen: json['has_builtin_kitchen'] as bool? ?? false,
      hasJacuzzi: json['has_jacuzzi'] as bool? ?? false,
      hasSauna: json['has_sauna'] as bool? ?? false,
      hasBarbeque: json['has_barbeque'] as bool? ?? false,
      hasDoorman: json['has_doorman'] as bool? ?? false,
      isInComplex: json['is_in_complex'] as bool? ?? false,
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
      'net_square_meters': netSquareMeters,
      'heating_type': heatingType,
      'facing_direction': facingDirection,
      'interior_status': interiorStatus,
      'deed_type': deedType,
      'view_type': viewType,
      'has_parking': hasParking,
      'has_balcony': hasBalcony,
      'has_furniture': hasFurniture,
      'has_pool': hasPool,
      'has_gym': hasGym,
      'has_security': hasSecurity,
      'has_elevator': hasElevator,
      'is_smart_home': isSmartHome,
      'has_garden': hasGarden,
      'has_terrace': hasTerrace,
      'has_storage': hasStorage,
      'has_fireplace': hasFireplace,
      'has_air_conditioning': hasAirConditioning,
      'has_generator': hasGenerator,
      'has_satellite': hasSatellite,
      'has_internet': hasInternet,
      'has_natural_gas': hasNaturalGas,
      'has_steel_door': hasSteelDoor,
      'has_video_intercom': hasVideoIntercom,
      'has_alarm': hasAlarm,
      'has_parent_bathroom': hasParentBathroom,
      'has_builtin_kitchen': hasBuiltinKitchen,
      'has_jacuzzi': hasJacuzzi,
      'has_sauna': hasSauna,
      'has_barbeque': hasBarbeque,
      'has_doorman': hasDoorman,
      'is_in_complex': isInComplex,
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
    int? netSquareMeters,
    String? heatingType,
    String? facingDirection,
    String? interiorStatus,
    String? deedType,
    String? viewType,
    bool? hasParking,
    bool? hasBalcony,
    bool? hasFurniture,
    bool? hasPool,
    bool? hasGym,
    bool? hasSecurity,
    bool? hasElevator,
    bool? isSmartHome,
    bool? hasGarden,
    bool? hasTerrace,
    bool? hasStorage,
    bool? hasFireplace,
    bool? hasAirConditioning,
    bool? hasGenerator,
    bool? hasSatellite,
    bool? hasInternet,
    bool? hasNaturalGas,
    bool? hasSteelDoor,
    bool? hasVideoIntercom,
    bool? hasAlarm,
    bool? hasParentBathroom,
    bool? hasBuiltinKitchen,
    bool? hasJacuzzi,
    bool? hasSauna,
    bool? hasBarbeque,
    bool? hasDoorman,
    bool? isInComplex,
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
      netSquareMeters: netSquareMeters ?? this.netSquareMeters,
      heatingType: heatingType ?? this.heatingType,
      facingDirection: facingDirection ?? this.facingDirection,
      interiorStatus: interiorStatus ?? this.interiorStatus,
      deedType: deedType ?? this.deedType,
      viewType: viewType ?? this.viewType,
      hasParking: hasParking ?? this.hasParking,
      hasBalcony: hasBalcony ?? this.hasBalcony,
      hasFurniture: hasFurniture ?? this.hasFurniture,
      hasPool: hasPool ?? this.hasPool,
      hasGym: hasGym ?? this.hasGym,
      hasSecurity: hasSecurity ?? this.hasSecurity,
      hasElevator: hasElevator ?? this.hasElevator,
      isSmartHome: isSmartHome ?? this.isSmartHome,
      hasGarden: hasGarden ?? this.hasGarden,
      hasTerrace: hasTerrace ?? this.hasTerrace,
      hasStorage: hasStorage ?? this.hasStorage,
      hasFireplace: hasFireplace ?? this.hasFireplace,
      hasAirConditioning: hasAirConditioning ?? this.hasAirConditioning,
      hasGenerator: hasGenerator ?? this.hasGenerator,
      hasSatellite: hasSatellite ?? this.hasSatellite,
      hasInternet: hasInternet ?? this.hasInternet,
      hasNaturalGas: hasNaturalGas ?? this.hasNaturalGas,
      hasSteelDoor: hasSteelDoor ?? this.hasSteelDoor,
      hasVideoIntercom: hasVideoIntercom ?? this.hasVideoIntercom,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      hasParentBathroom: hasParentBathroom ?? this.hasParentBathroom,
      hasBuiltinKitchen: hasBuiltinKitchen ?? this.hasBuiltinKitchen,
      hasJacuzzi: hasJacuzzi ?? this.hasJacuzzi,
      hasSauna: hasSauna ?? this.hasSauna,
      hasBarbeque: hasBarbeque ?? this.hasBarbeque,
      hasDoorman: hasDoorman ?? this.hasDoorman,
      isInComplex: isInComplex ?? this.isInComplex,
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
