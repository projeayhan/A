// Premium Car Sales Models - International Standards
// Designed for a luxury automotive marketplace experience

import 'package:flutter/material.dart';

/// Car body type enumeration
enum CarBodyType {
  sedan('Sedan', Icons.directions_car, '🚗'),
  hatchback('Hatchback', Icons.directions_car_filled, '🚙'),
  suv('SUV', Icons.directions_car_filled, '🚙'),
  crossover('Crossover', Icons.directions_car, '🚗'),
  coupe('Coupe', Icons.sports_motorsports, '🏎️'),
  convertible('Cabrio', Icons.wb_sunny, '🚗'),
  wagon('Station Wagon', Icons.local_shipping, '🚗'),
  pickup('Pickup', Icons.local_shipping, '🛻'),
  van('Van', Icons.airport_shuttle, '🚐'),
  minivan('Minivan', Icons.family_restroom, '🚐'),
  sports('Spor', Icons.speed, '🏎️'),
  luxury('Lüks', Icons.diamond, '🚘');

  final String label;
  final IconData icon;
  final String emoji;
  const CarBodyType(this.label, this.icon, this.emoji);
}

/// Fuel type enumeration
enum CarFuelType {
  petrol('Benzin', Icons.local_gas_station, Color(0xFFEF4444)),
  diesel('Dizel', Icons.local_gas_station, Color(0xFF6B7280)),
  electric('Elektrik', Icons.electric_bolt, Color(0xFF10B981)),
  hybrid('Hibrit', Icons.eco, Color(0xFF3B82F6)),
  pluginHybrid('Plug-in Hibrit', Icons.power, Color(0xFF8B5CF6)),
  lpg('LPG', Icons.propane_tank, Color(0xFFF59E0B));

  final String label;
  final IconData icon;
  final Color color;
  const CarFuelType(this.label, this.icon, this.color);
}

/// Transmission type
enum CarTransmission {
  automatic('Otomatik', Icons.settings),
  manual('Manuel', Icons.settings_applications),
  semiAutomatic('Yarı Otomatik', Icons.tune);

  final String label;
  final IconData icon;
  const CarTransmission(this.label, this.icon);
}

/// Traction type
enum CarTraction {
  fwd('Önden Çekiş (FWD)', 'FWD'),
  rwd('Arkadan İtiş (RWD)', 'RWD'),
  awd('4x4 (AWD)', 'AWD'),
  fourWD('4WD', '4WD');

  final String label;
  final String shortLabel;
  const CarTraction(this.label, this.shortLabel);
}

/// Listing status
enum CarListingStatus {
  active('Aktif', Color(0xFF10B981), Icons.check_circle),
  pending('Onay Bekliyor', Color(0xFFF59E0B), Icons.hourglass_empty),
  sold('Satıldı', Color(0xFF6B7280), Icons.sell),
  reserved('Rezerve', Color(0xFF3B82F6), Icons.bookmark),
  expired('Süresi Doldu', Color(0xFFEF4444), Icons.timer_off);

  final String label;
  final Color color;
  final IconData icon;
  const CarListingStatus(this.label, this.color, this.icon);
}

/// Car condition
enum CarCondition {
  brandNew('Sıfır', Color(0xFF10B981)),
  likeNew('Sıfır Gibi', Color(0xFF22C55E)),
  excellent('Mükemmel', Color(0xFF3B82F6)),
  good('İyi', Color(0xFF6366F1)),
  fair('Orta', Color(0xFFF59E0B)),
  needsRepair('Onarım Gerekli', Color(0xFFEF4444));

  final String label;
  final Color color;
  const CarCondition(this.label, this.color);
}

/// Seller type
enum SellerType {
  individual('Bireysel', Icons.person),
  dealer('Galeri', Icons.storefront),
  authorizedDealer('Yetkili Bayi', Icons.verified);

  final String label;
  final IconData icon;
  const SellerType(this.label, this.icon);
}

/// Color options for cars
enum CarColor {
  white('Beyaz', Color(0xFFF8FAFC), Color(0xFF1E293B)),
  black('Siyah', Color(0xFF0F172A), Color(0xFFFFFFFF)),
  silver('Gümüş', Color(0xFFCBD5E1), Color(0xFF1E293B)),
  gray('Gri', Color(0xFF6B7280), Color(0xFFFFFFFF)),
  red('Kırmızı', Color(0xFFEF4444), Color(0xFFFFFFFF)),
  blue('Mavi', Color(0xFF3B82F6), Color(0xFFFFFFFF)),
  green('Yeşil', Color(0xFF22C55E), Color(0xFFFFFFFF)),
  yellow('Sarı', Color(0xFFFACC15), Color(0xFF1E293B)),
  orange('Turuncu', Color(0xFFF97316), Color(0xFFFFFFFF)),
  brown('Kahverengi', Color(0xFF92400E), Color(0xFFFFFFFF)),
  beige('Bej', Color(0xFFD4C4A8), Color(0xFF1E293B)),
  navy('Lacivert', Color(0xFF1E3A8A), Color(0xFFFFFFFF)),
  burgundy('Bordo', Color(0xFF7F1D1D), Color(0xFFFFFFFF)),
  champagne('Şampanya', Color(0xFFF5DEB3), Color(0xFF1E293B));

  final String label;
  final Color color;
  final Color textColor;
  const CarColor(this.label, this.color, this.textColor);
}

/// Car brand model
class CarBrand {
  final String id;
  final String name;
  final String logoUrl;
  final String country;
  final bool isPremium;
  final bool isPopular;

  const CarBrand({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.country,
    this.isPremium = false,
    this.isPopular = false,
  });

  static const List<CarBrand> allBrands = [
    // Premium Brands
    CarBrand(id: 'mercedes', name: 'Mercedes-Benz', logoUrl: 'https://www.carlogos.org/car-logos/mercedes-benz-logo.png', country: 'Almanya', isPremium: true, isPopular: true),
    CarBrand(id: 'bmw', name: 'BMW', logoUrl: 'https://www.carlogos.org/car-logos/bmw-logo.png', country: 'Almanya', isPremium: true, isPopular: true),
    CarBrand(id: 'audi', name: 'Audi', logoUrl: 'https://www.carlogos.org/car-logos/audi-logo.png', country: 'Almanya', isPremium: true, isPopular: true),
    CarBrand(id: 'porsche', name: 'Porsche', logoUrl: 'https://www.carlogos.org/car-logos/porsche-logo.png', country: 'Almanya', isPremium: true),
    CarBrand(id: 'lexus', name: 'Lexus', logoUrl: 'https://www.carlogos.org/car-logos/lexus-logo.png', country: 'Japonya', isPremium: true),
    CarBrand(id: 'jaguar', name: 'Jaguar', logoUrl: 'https://www.carlogos.org/car-logos/jaguar-logo.png', country: 'İngiltere', isPremium: true),
    CarBrand(id: 'landrover', name: 'Land Rover', logoUrl: 'https://www.carlogos.org/car-logos/land-rover-logo.png', country: 'İngiltere', isPremium: true),
    CarBrand(id: 'maserati', name: 'Maserati', logoUrl: 'https://www.carlogos.org/car-logos/maserati-logo.png', country: 'İtalya', isPremium: true),
    CarBrand(id: 'bentley', name: 'Bentley', logoUrl: 'https://www.carlogos.org/car-logos/bentley-logo.png', country: 'İngiltere', isPremium: true),
    CarBrand(id: 'rollsroyce', name: 'Rolls-Royce', logoUrl: 'https://www.carlogos.org/car-logos/rolls-royce-logo.png', country: 'İngiltere', isPremium: true),
    CarBrand(id: 'ferrari', name: 'Ferrari', logoUrl: 'https://www.carlogos.org/car-logos/ferrari-logo.png', country: 'İtalya', isPremium: true),
    CarBrand(id: 'lamborghini', name: 'Lamborghini', logoUrl: 'https://www.carlogos.org/car-logos/lamborghini-logo.png', country: 'İtalya', isPremium: true),
    CarBrand(id: 'tesla', name: 'Tesla', logoUrl: 'https://www.carlogos.org/car-logos/tesla-logo.png', country: 'ABD', isPremium: true, isPopular: true),

    // Popular Brands
    CarBrand(id: 'volkswagen', name: 'Volkswagen', logoUrl: 'https://www.carlogos.org/car-logos/volkswagen-logo.png', country: 'Almanya', isPopular: true),
    CarBrand(id: 'toyota', name: 'Toyota', logoUrl: 'https://www.carlogos.org/car-logos/toyota-logo.png', country: 'Japonya', isPopular: true),
    CarBrand(id: 'honda', name: 'Honda', logoUrl: 'https://www.carlogos.org/car-logos/honda-logo.png', country: 'Japonya', isPopular: true),
    CarBrand(id: 'ford', name: 'Ford', logoUrl: 'https://www.carlogos.org/car-logos/ford-logo.png', country: 'ABD', isPopular: true),
    CarBrand(id: 'hyundai', name: 'Hyundai', logoUrl: 'https://www.carlogos.org/car-logos/hyundai-logo.png', country: 'G. Kore', isPopular: true),
    CarBrand(id: 'kia', name: 'Kia', logoUrl: 'https://www.carlogos.org/car-logos/kia-logo.png', country: 'G. Kore', isPopular: true),
    CarBrand(id: 'nissan', name: 'Nissan', logoUrl: 'https://www.carlogos.org/car-logos/nissan-logo.png', country: 'Japonya', isPopular: true),
    CarBrand(id: 'mazda', name: 'Mazda', logoUrl: 'https://www.carlogos.org/car-logos/mazda-logo.png', country: 'Japonya'),
    CarBrand(id: 'subaru', name: 'Subaru', logoUrl: 'https://www.carlogos.org/car-logos/subaru-logo.png', country: 'Japonya'),
    CarBrand(id: 'volvo', name: 'Volvo', logoUrl: 'https://www.carlogos.org/car-logos/volvo-logo.png', country: 'İsveç'),
    CarBrand(id: 'peugeot', name: 'Peugeot', logoUrl: 'https://www.carlogos.org/car-logos/peugeot-logo.png', country: 'Fransa', isPopular: true),
    CarBrand(id: 'renault', name: 'Renault', logoUrl: 'https://www.carlogos.org/car-logos/renault-logo.png', country: 'Fransa', isPopular: true),
    CarBrand(id: 'citroen', name: 'Citroen', logoUrl: 'https://www.carlogos.org/car-logos/citroen-logo.png', country: 'Fransa'),
    CarBrand(id: 'fiat', name: 'Fiat', logoUrl: 'https://www.carlogos.org/car-logos/fiat-logo.png', country: 'İtalya', isPopular: true),
    CarBrand(id: 'seat', name: 'SEAT', logoUrl: 'https://www.carlogos.org/car-logos/seat-logo.png', country: 'İspanya'),
    CarBrand(id: 'skoda', name: 'Skoda', logoUrl: 'https://www.carlogos.org/car-logos/skoda-logo.png', country: 'Çekya', isPopular: true),
    CarBrand(id: 'opel', name: 'Opel', logoUrl: 'https://www.carlogos.org/car-logos/opel-logo.png', country: 'Almanya'),
    CarBrand(id: 'chevrolet', name: 'Chevrolet', logoUrl: 'https://www.carlogos.org/car-logos/chevrolet-logo.png', country: 'ABD'),
    CarBrand(id: 'jeep', name: 'Jeep', logoUrl: 'https://www.carlogos.org/car-logos/jeep-logo.png', country: 'ABD'),
    CarBrand(id: 'mitsubishi', name: 'Mitsubishi', logoUrl: 'https://www.carlogos.org/car-logos/mitsubishi-logo.png', country: 'Japonya'),
    CarBrand(id: 'suzuki', name: 'Suzuki', logoUrl: 'https://www.carlogos.org/car-logos/suzuki-logo.png', country: 'Japonya'),
    CarBrand(id: 'dacia', name: 'Dacia', logoUrl: 'https://www.carlogos.org/car-logos/dacia-logo.png', country: 'Romanya'),
    CarBrand(id: 'mini', name: 'Mini', logoUrl: 'https://www.carlogos.org/car-logos/mini-logo.png', country: 'İngiltere'),
    CarBrand(id: 'alfa', name: 'Alfa Romeo', logoUrl: 'https://www.carlogos.org/car-logos/alfa-romeo-logo.png', country: 'İtalya'),
  ];

  static List<CarBrand> get premiumBrands => allBrands.where((b) => b.isPremium).toList();
  static List<CarBrand> get popularBrands => allBrands.where((b) => b.isPopular).toList();
}

/// Car model (specific model of a brand)
class CarModel {
  final String id;
  final String brandId;
  final String name;
  final List<CarBodyType> bodyTypes;
  final int startYear;
  final int? endYear;
  final bool isActive;

  const CarModel({
    required this.id,
    required this.brandId,
    required this.name,
    required this.bodyTypes,
    required this.startYear,
    this.endYear,
    this.isActive = true,
  });
}

/// Car feature/equipment
class CarFeature {
  final String id;
  final String name;
  final String category;
  final IconData icon;

  const CarFeature({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
  });

  static const Map<String, List<CarFeature>> featuresByCategory = {
    'Güvenlik': [
      CarFeature(id: 'abs', name: 'ABS', category: 'Güvenlik', icon: Icons.security),
      CarFeature(id: 'esp', name: 'ESP', category: 'Güvenlik', icon: Icons.security),
      CarFeature(id: 'airbag_front', name: 'Ön Hava Yastığı', category: 'Güvenlik', icon: Icons.airline_seat_recline_extra),
      CarFeature(id: 'airbag_side', name: 'Yan Hava Yastığı', category: 'Güvenlik', icon: Icons.airline_seat_recline_extra),
      CarFeature(id: 'airbag_curtain', name: 'Perde Hava Yastığı', category: 'Güvenlik', icon: Icons.airline_seat_recline_extra),
      CarFeature(id: 'blind_spot', name: 'Kör Nokta Uyarısı', category: 'Güvenlik', icon: Icons.visibility),
      CarFeature(id: 'lane_assist', name: 'Şerit Takip Sistemi', category: 'Güvenlik', icon: Icons.swap_horiz),
      CarFeature(id: 'parking_sensor', name: 'Park Sensörü', category: 'Güvenlik', icon: Icons.sensors),
      CarFeature(id: 'rear_camera', name: 'Geri Görüş Kamerası', category: 'Güvenlik', icon: Icons.camera_rear),
      CarFeature(id: '360_camera', name: '360° Kamera', category: 'Güvenlik', icon: Icons.panorama_horizontal),
      CarFeature(id: 'collision_warning', name: 'Çarpışma Uyarı Sistemi', category: 'Güvenlik', icon: Icons.warning),
      CarFeature(id: 'adaptive_cruise', name: 'Adaptif Hız Sabitleyici', category: 'Güvenlik', icon: Icons.speed),
    ],
    'Konfor': [
      CarFeature(id: 'ac', name: 'Klima', category: 'Konfor', icon: Icons.ac_unit),
      CarFeature(id: 'climate_control', name: 'Otomatik Klima', category: 'Konfor', icon: Icons.thermostat_auto),
      CarFeature(id: 'dual_zone_climate', name: 'Çift Bölgeli Klima', category: 'Konfor', icon: Icons.thermostat),
      CarFeature(id: 'heated_seats', name: 'Isıtmalı Koltuk', category: 'Konfor', icon: Icons.event_seat),
      CarFeature(id: 'cooled_seats', name: 'Soğutmalı Koltuk', category: 'Konfor', icon: Icons.event_seat),
      CarFeature(id: 'leather_seats', name: 'Deri Koltuk', category: 'Konfor', icon: Icons.airline_seat_legroom_extra),
      CarFeature(id: 'electric_seats', name: 'Elektrikli Koltuk', category: 'Konfor', icon: Icons.electrical_services),
      CarFeature(id: 'memory_seats', name: 'Hafızalı Koltuk', category: 'Konfor', icon: Icons.save),
      CarFeature(id: 'sunroof', name: 'Cam Tavan', category: 'Konfor', icon: Icons.wb_sunny),
      CarFeature(id: 'panoramic_roof', name: 'Panoramik Tavan', category: 'Konfor', icon: Icons.panorama),
      CarFeature(id: 'keyless_entry', name: 'Anahtarsız Giriş', category: 'Konfor', icon: Icons.key_off),
      CarFeature(id: 'push_start', name: 'Tek Tuş ile Çalıştırma', category: 'Konfor', icon: Icons.power_settings_new),
      CarFeature(id: 'electric_trunk', name: 'Elektrikli Bagaj', category: 'Konfor', icon: Icons.sensor_door),
      CarFeature(id: 'remote_start', name: 'Uzaktan Çalıştırma', category: 'Konfor', icon: Icons.settings_remote),
    ],
    'Multimedya': [
      CarFeature(id: 'bluetooth', name: 'Bluetooth', category: 'Multimedya', icon: Icons.bluetooth),
      CarFeature(id: 'usb', name: 'USB Bağlantı', category: 'Multimedya', icon: Icons.usb),
      CarFeature(id: 'aux', name: 'AUX Girişi', category: 'Multimedya', icon: Icons.cable),
      CarFeature(id: 'navigation', name: 'Navigasyon', category: 'Multimedya', icon: Icons.navigation),
      CarFeature(id: 'apple_carplay', name: 'Apple CarPlay', category: 'Multimedya', icon: Icons.phone_iphone),
      CarFeature(id: 'android_auto', name: 'Android Auto', category: 'Multimedya', icon: Icons.android),
      CarFeature(id: 'touchscreen', name: 'Dokunmatik Ekran', category: 'Multimedya', icon: Icons.touch_app),
      CarFeature(id: 'premium_audio', name: 'Premium Ses Sistemi', category: 'Multimedya', icon: Icons.speaker),
      CarFeature(id: 'wireless_charging', name: 'Kablosuz Şarj', category: 'Multimedya', icon: Icons.charging_station),
      CarFeature(id: 'head_up_display', name: 'Head-Up Display', category: 'Multimedya', icon: Icons.preview),
      CarFeature(id: 'digital_cockpit', name: 'Dijital Gösterge', category: 'Multimedya', icon: Icons.speed),
    ],
    'Dış Donanım': [
      CarFeature(id: 'led_headlights', name: 'LED Farlar', category: 'Dış Donanım', icon: Icons.highlight),
      CarFeature(id: 'xenon_headlights', name: 'Xenon Farlar', category: 'Dış Donanım', icon: Icons.lightbulb),
      CarFeature(id: 'adaptive_headlights', name: 'Adaptif Farlar', category: 'Dış Donanım', icon: Icons.light_mode),
      CarFeature(id: 'fog_lights', name: 'Sis Farları', category: 'Dış Donanım', icon: Icons.foggy),
      CarFeature(id: 'alloy_wheels', name: 'Alaşım Jant', category: 'Dış Donanım', icon: Icons.radio_button_unchecked),
      CarFeature(id: 'electric_mirrors', name: 'Elektrikli Ayna', category: 'Dış Donanım', icon: Icons.flip),
      CarFeature(id: 'heated_mirrors', name: 'Isıtmalı Ayna', category: 'Dış Donanım', icon: Icons.flip),
      CarFeature(id: 'folding_mirrors', name: 'Katlanır Ayna', category: 'Dış Donanım', icon: Icons.flip_to_back),
      CarFeature(id: 'roof_rails', name: 'Tavan Rayları', category: 'Dış Donanım', icon: Icons.straighten),
      CarFeature(id: 'tow_hook', name: 'Çeki Demiri', category: 'Dış Donanım', icon: Icons.rv_hookup),
    ],
  };

  static List<CarFeature> get allFeatures =>
      featuresByCategory.values.expand((list) => list).toList();
}

/// Seller information
class CarSeller {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? imageUrl;
  final SellerType type;
  final String? companyName;
  final String? address;
  final double rating;
  final int totalListings;
  final int soldCount;
  final bool isVerified;
  final DateTime memberSince;
  final double responseRate;
  final String? responseTime;

  const CarSeller({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.imageUrl,
    required this.type,
    this.companyName,
    this.address,
    this.rating = 0,
    this.totalListings = 0,
    this.soldCount = 0,
    this.isVerified = false,
    required this.memberSince,
    this.responseRate = 0,
    this.responseTime,
  });

  String get displayName => companyName ?? name;

  String get membershipDuration {
    final years = DateTime.now().difference(memberSince).inDays ~/ 365;
    if (years > 0) return '$years yıldır üye';
    final months = DateTime.now().difference(memberSince).inDays ~/ 30;
    if (months > 0) return '$months aydır üye';
    return 'Yeni üye';
  }
}

/// Main car listing model
class CarListing {
  final String id;
  final String title;
  final String description;
  final CarBrand brand;
  final String modelName;
  final int year;
  final int mileage;
  final CarBodyType bodyType;
  final CarFuelType fuelType;
  final CarTransmission transmission;
  final CarTraction traction;
  final int engineCC;
  final int horsePower;
  final CarColor exteriorColor;
  final CarColor interiorColor;
  final CarCondition condition;
  final double price;
  final String currency;
  final bool isPriceNegotiable;
  final bool isExchangeAccepted;
  final CarListingStatus status;
  final CarSeller seller;
  final List<String> images;
  final List<String> featureIds;
  final String? damageReport;
  final String? serviceHistory;
  final int? previousOwners;
  final bool hasOriginalPaint;
  final bool hasAccidentHistory;
  final String? plateCity;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? soldAt;
  final int viewCount;
  final int favoriteCount;
  final int contactCount;
  final bool isFeatured;
  final bool isPremiumListing;
  final String? city;
  final String? district;
  final double? latitude;
  final double? longitude;
  final String? videoUrl;
  final bool hasWarranty;
  final String? warrantyDetails;

  const CarListing({
    required this.id,
    required this.title,
    required this.description,
    required this.brand,
    required this.modelName,
    required this.year,
    required this.mileage,
    required this.bodyType,
    required this.fuelType,
    required this.transmission,
    required this.traction,
    required this.engineCC,
    required this.horsePower,
    required this.exteriorColor,
    required this.interiorColor,
    required this.condition,
    required this.price,
    this.currency = 'TL',
    this.isPriceNegotiable = false,
    this.isExchangeAccepted = false,
    required this.status,
    required this.seller,
    required this.images,
    required this.featureIds,
    this.damageReport,
    this.serviceHistory,
    this.previousOwners,
    this.hasOriginalPaint = true,
    this.hasAccidentHistory = false,
    this.plateCity,
    required this.createdAt,
    this.updatedAt,
    this.soldAt,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.contactCount = 0,
    this.isFeatured = false,
    this.isPremiumListing = false,
    this.city,
    this.district,
    this.latitude,
    this.longitude,
    this.videoUrl,
    this.hasWarranty = false,
    this.warrantyDetails,
  });

  String get fullName => '${brand.name} $modelName';

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

  String get formattedMileage {
    final formatted = mileage.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted km';
  }

  String get location => district != null ? '$district, $city' : city ?? '';

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30} ay önce';
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    return '${diff.inMinutes} dakika önce';
  }

  List<CarFeature> get features {
    return featureIds
        .map((id) => CarFeature.allFeatures.firstWhere(
              (f) => f.id == id,
              orElse: () => CarFeature(
                id: id,
                name: id,
                category: 'Diğer',
                icon: Icons.check,
              ),
            ))
        .toList();
  }
}

/// Search/Filter model
class CarSearchFilter {
  final String? query;
  final List<String>? brandIds;
  final List<String>? modelNames;
  final int? minYear;
  final int? maxYear;
  final int? minPrice;
  final int? maxPrice;
  final int? minMileage;
  final int? maxMileage;
  final List<CarBodyType>? bodyTypes;
  final List<CarFuelType>? fuelTypes;
  final List<CarTransmission>? transmissions;
  final List<CarTraction>? tractions;
  final List<CarColor>? colors;
  final List<CarCondition>? conditions;
  final List<SellerType>? sellerTypes;
  final int? minEnginePower;
  final int? maxEnginePower;
  final String? city;
  final String? district;
  final bool? isPriceNegotiable;
  final bool? isExchangeAccepted;
  final bool? hasWarranty;
  final bool? hasOriginalPaint;
  final bool? noAccidentHistory;
  final List<String>? requiredFeatures;
  final CarSortOption sortBy;

  const CarSearchFilter({
    this.query,
    this.brandIds,
    this.modelNames,
    this.minYear,
    this.maxYear,
    this.minPrice,
    this.maxPrice,
    this.minMileage,
    this.maxMileage,
    this.bodyTypes,
    this.fuelTypes,
    this.transmissions,
    this.tractions,
    this.colors,
    this.conditions,
    this.sellerTypes,
    this.minEnginePower,
    this.maxEnginePower,
    this.city,
    this.district,
    this.isPriceNegotiable,
    this.isExchangeAccepted,
    this.hasWarranty,
    this.hasOriginalPaint,
    this.noAccidentHistory,
    this.requiredFeatures,
    this.sortBy = CarSortOption.newest,
  });

  CarSearchFilter copyWith({
    String? query,
    List<String>? brandIds,
    List<String>? modelNames,
    int? minYear,
    int? maxYear,
    int? minPrice,
    int? maxPrice,
    int? minMileage,
    int? maxMileage,
    List<CarBodyType>? bodyTypes,
    List<CarFuelType>? fuelTypes,
    List<CarTransmission>? transmissions,
    List<CarTraction>? tractions,
    List<CarColor>? colors,
    List<CarCondition>? conditions,
    List<SellerType>? sellerTypes,
    int? minEnginePower,
    int? maxEnginePower,
    String? city,
    String? district,
    bool? isPriceNegotiable,
    bool? isExchangeAccepted,
    bool? hasWarranty,
    bool? hasOriginalPaint,
    bool? noAccidentHistory,
    List<String>? requiredFeatures,
    CarSortOption? sortBy,
  }) {
    return CarSearchFilter(
      query: query ?? this.query,
      brandIds: brandIds ?? this.brandIds,
      modelNames: modelNames ?? this.modelNames,
      minYear: minYear ?? this.minYear,
      maxYear: maxYear ?? this.maxYear,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minMileage: minMileage ?? this.minMileage,
      maxMileage: maxMileage ?? this.maxMileage,
      bodyTypes: bodyTypes ?? this.bodyTypes,
      fuelTypes: fuelTypes ?? this.fuelTypes,
      transmissions: transmissions ?? this.transmissions,
      tractions: tractions ?? this.tractions,
      colors: colors ?? this.colors,
      conditions: conditions ?? this.conditions,
      sellerTypes: sellerTypes ?? this.sellerTypes,
      minEnginePower: minEnginePower ?? this.minEnginePower,
      maxEnginePower: maxEnginePower ?? this.maxEnginePower,
      city: city ?? this.city,
      district: district ?? this.district,
      isPriceNegotiable: isPriceNegotiable ?? this.isPriceNegotiable,
      isExchangeAccepted: isExchangeAccepted ?? this.isExchangeAccepted,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      hasOriginalPaint: hasOriginalPaint ?? this.hasOriginalPaint,
      noAccidentHistory: noAccidentHistory ?? this.noAccidentHistory,
      requiredFeatures: requiredFeatures ?? this.requiredFeatures,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (brandIds?.isNotEmpty ?? false) count++;
    if (modelNames?.isNotEmpty ?? false) count++;
    if (minYear != null || maxYear != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (minMileage != null || maxMileage != null) count++;
    if (bodyTypes?.isNotEmpty ?? false) count++;
    if (fuelTypes?.isNotEmpty ?? false) count++;
    if (transmissions?.isNotEmpty ?? false) count++;
    if (tractions?.isNotEmpty ?? false) count++;
    if (colors?.isNotEmpty ?? false) count++;
    if (conditions?.isNotEmpty ?? false) count++;
    if (sellerTypes?.isNotEmpty ?? false) count++;
    if (city != null) count++;
    if (isPriceNegotiable == true) count++;
    if (isExchangeAccepted == true) count++;
    if (hasWarranty == true) count++;
    if (hasOriginalPaint == true) count++;
    if (noAccidentHistory == true) count++;
    if (requiredFeatures?.isNotEmpty ?? false) count++;
    return count;
  }
}

/// Sort options
enum CarSortOption {
  newest('En Yeni', Icons.access_time),
  oldest('En Eski', Icons.history),
  priceLow('Fiyat (Düşük-Yüksek)', Icons.trending_down),
  priceHigh('Fiyat (Yüksek-Düşük)', Icons.trending_up),
  mileageLow('Kilometre (Düşük-Yüksek)', Icons.speed),
  mileageHigh('Kilometre (Yüksek-Düşük)', Icons.speed),
  yearNew('Model Yılı (Yeni-Eski)', Icons.calendar_today),
  yearOld('Model Yılı (Eski-Yeni)', Icons.calendar_month);

  final String label;
  final IconData icon;
  const CarSortOption(this.label, this.icon);
}

/// Theme colors for car sales module
class CarSalesColors {
  // Primary - Deep Blue (Trust, Premium)
  static const Color primary = Color(0xFF1E40AF);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);

  // Secondary - Amber (Automotive, Energy)
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryDark = Color(0xFFD97706);
  static const Color secondaryLight = Color(0xFFFBBF24);

  // Accent - Racing Red
  static const Color accent = Color(0xFFDC2626);
  static const Color accentLight = Color(0xFFEF4444);

  // Success - Green
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF1E40AF),
    Color(0xFF3B82F6),
  ];

  static const List<Color> premiumGradient = [
    Color(0xFF0F172A),
    Color(0xFF1E293B),
  ];

  static const List<Color> goldGradient = [
    Color(0xFFF59E0B),
    Color(0xFFD97706),
  ];

  static const List<Color> sportGradient = [
    Color(0xFFDC2626),
    Color(0xFFF97316),
  ];

  // ============ LIGHT MODE ============
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // ============ DARK MODE ============
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF1E293B);

  // Helper methods
  static Color background(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textTertiary(bool isDark) => isDark ? textTertiaryDark : textTertiaryLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color divider(bool isDark) => isDark ? dividerDark : dividerLight;
}

/// Demo data
class CarSalesDemoData {
  static final List<CarSeller> sellers = [
    CarSeller(
      id: 'seller_1',
      name: 'Ahmet Yıldırım',
      phone: '+90 532 111 22 33',
      email: 'ahmet@email.com',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      type: SellerType.individual,
      rating: 4.8,
      totalListings: 3,
      soldCount: 12,
      isVerified: true,
      memberSince: DateTime(2020, 5, 15),
      responseRate: 95,
      responseTime: '1 saat içinde',
    ),
    CarSeller(
      id: 'seller_2',
      name: 'Premium Auto Gallery',
      phone: '+90 212 333 44 55',
      email: 'info@premiumauto.com',
      imageUrl: 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=200',
      type: SellerType.dealer,
      companyName: 'Premium Auto Gallery',
      address: 'Maslak, Sarıyer, İstanbul',
      rating: 4.9,
      totalListings: 45,
      soldCount: 320,
      isVerified: true,
      memberSince: DateTime(2018, 3, 1),
      responseRate: 98,
      responseTime: '30 dakika içinde',
    ),
    CarSeller(
      id: 'seller_3',
      name: 'Mercedes-Benz İstanbul',
      phone: '+90 212 555 66 77',
      email: 'satis@mercedes-istanbul.com',
      imageUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200',
      type: SellerType.authorizedDealer,
      companyName: 'Mercedes-Benz İstanbul',
      address: 'Maslak, Sarıyer, İstanbul',
      rating: 5.0,
      totalListings: 85,
      soldCount: 1250,
      isVerified: true,
      memberSince: DateTime(2015, 1, 1),
      responseRate: 100,
      responseTime: '15 dakika içinde',
    ),
  ];

  static List<CarListing> get listings => [
    CarListing(
      id: 'car_1',
      title: 'Mercedes-Benz S 500 4MATIC Long',
      description: '''Türkiye'de tek, özel sipariş, full paket Mercedes S 500 4MATIC Long.

• AMG Line paket
• Burmester 4D surround ses sistemi
• Executive arka koltuk paketi
• Panoramik cam tavan
• Head-Up Display
• 360° kamera sistemi
• Masaj fonksiyonlu koltuklar
• Ambient aydınlatma (64 renk)
• MBUX Augmented Reality navigasyon
• Distronic Plus adaptif cruise control

Araç showroom kondisyonundadır. Tüm bakımları yetkili serviste yapılmıştır. Detaylı ekspertiz raporu mevcuttur.''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'mercedes'),
      modelName: 'S 500 4MATIC Long',
      year: 2024,
      mileage: 5200,
      bodyType: CarBodyType.sedan,
      fuelType: CarFuelType.petrol,
      transmission: CarTransmission.automatic,
      traction: CarTraction.awd,
      engineCC: 2999,
      horsePower: 435,
      exteriorColor: CarColor.black,
      interiorColor: CarColor.beige,
      condition: CarCondition.likeNew,
      price: 12500000,
      isPriceNegotiable: false,
      isExchangeAccepted: false,
      status: CarListingStatus.active,
      seller: sellers[2],
      images: [
        'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=800',
        'https://images.unsplash.com/photo-1617531653332-bd46c24f2068?w=800',
        'https://images.unsplash.com/photo-1618843479619-f3d0d81e4d10?w=800',
        'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?w=800',
        'https://images.unsplash.com/photo-1619405399517-d7fce0f13302?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'airbag_curtain', 'blind_spot', 'lane_assist', 'parking_sensor', 'rear_camera', '360_camera', 'collision_warning', 'adaptive_cruise', 'climate_control', 'dual_zone_climate', 'heated_seats', 'cooled_seats', 'leather_seats', 'electric_seats', 'memory_seats', 'panoramic_roof', 'keyless_entry', 'push_start', 'electric_trunk', 'bluetooth', 'navigation', 'apple_carplay', 'android_auto', 'touchscreen', 'premium_audio', 'wireless_charging', 'head_up_display', 'digital_cockpit', 'led_headlights', 'adaptive_headlights', 'alloy_wheels'],
      serviceHistory: 'Yetkili servis bakımlı',
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '34',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      viewCount: 2450,
      favoriteCount: 187,
      contactCount: 45,
      isFeatured: true,
      isPremiumListing: true,
      city: 'İstanbul',
      district: 'Maslak',
      hasWarranty: true,
      warrantyDetails: '2 yıl Mercedes-Benz garantisi',
    ),
    CarListing(
      id: 'car_2',
      title: 'BMW M4 Competition',
      description: '''BMW M4 Competition - Track ready, street legal!

• M Carbon paket
• M Drivers Package (250 km/s limiter kaldırılmış)
• Harman Kardon ses sistemi
• M Sport fren sistemi
• Akrapovic egzoz (opsiyonel)
• Karbon fiber tavan
• M Sport diferansiyel

Araç Amerika'dan özel ithal edilmiştir. Tüm vergileri ödenmiştir.''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'bmw'),
      modelName: 'M4 Competition',
      year: 2023,
      mileage: 12500,
      bodyType: CarBodyType.coupe,
      fuelType: CarFuelType.petrol,
      transmission: CarTransmission.automatic,
      traction: CarTraction.rwd,
      engineCC: 2993,
      horsePower: 510,
      exteriorColor: CarColor.blue,
      interiorColor: CarColor.black,
      condition: CarCondition.excellent,
      price: 6850000,
      isPriceNegotiable: true,
      isExchangeAccepted: false,
      status: CarListingStatus.active,
      seller: sellers[1],
      images: [
        'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=800',
        'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=800',
        'https://images.unsplash.com/photo-1617531653332-bd46c24f2068?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'blind_spot', 'lane_assist', 'parking_sensor', 'rear_camera', 'adaptive_cruise', 'climate_control', 'heated_seats', 'leather_seats', 'electric_seats', 'keyless_entry', 'push_start', 'bluetooth', 'navigation', 'apple_carplay', 'android_auto', 'touchscreen', 'premium_audio', 'head_up_display', 'digital_cockpit', 'led_headlights', 'adaptive_headlights', 'alloy_wheels'],
      serviceHistory: 'BMW yetkili servis bakımlı',
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '34',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      viewCount: 3250,
      favoriteCount: 289,
      contactCount: 67,
      isFeatured: true,
      isPremiumListing: true,
      city: 'İstanbul',
      district: 'Sarıyer',
      hasWarranty: false,
    ),
    CarListing(
      id: 'car_3',
      title: 'Porsche 911 Carrera S',
      description: '''İkonik Porsche 911 Carrera S - Sürüş tutkusu için tasarlandı.

• Sport Chrono paketi
• PASM (Porsche Active Suspension Management)
• Bose surround ses sistemi
• Sport egzoz
• 20/21 inç Carrera S jantlar

Araç garaj aracıdır, sadece hafta sonları kullanılmıştır.''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'porsche'),
      modelName: '911 Carrera S',
      year: 2022,
      mileage: 18000,
      bodyType: CarBodyType.sports,
      fuelType: CarFuelType.petrol,
      transmission: CarTransmission.automatic,
      traction: CarTraction.rwd,
      engineCC: 2981,
      horsePower: 450,
      exteriorColor: CarColor.white,
      interiorColor: CarColor.red,
      condition: CarCondition.excellent,
      price: 9750000,
      isPriceNegotiable: true,
      isExchangeAccepted: true,
      status: CarListingStatus.active,
      seller: sellers[0],
      images: [
        'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=800',
        'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=800',
        'https://images.unsplash.com/photo-1544636331-e26879cd4d9b?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'parking_sensor', 'rear_camera', 'adaptive_cruise', 'climate_control', 'heated_seats', 'leather_seats', 'electric_seats', 'keyless_entry', 'push_start', 'bluetooth', 'navigation', 'apple_carplay', 'touchscreen', 'premium_audio', 'led_headlights', 'alloy_wheels'],
      serviceHistory: 'Porsche Center bakımlı',
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '06',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      viewCount: 4100,
      favoriteCount: 356,
      contactCount: 89,
      isFeatured: true,
      isPremiumListing: true,
      city: 'Ankara',
      district: 'Çankaya',
      hasWarranty: false,
    ),
    CarListing(
      id: 'car_4',
      title: 'Tesla Model Y Long Range',
      description: '''Tesla Model Y Long Range - Geleceğin SUV'u bugün!

• Full Self-Driving Capability (FSD)
• Premium bağlantı paketi
• 21" Überturbine jantlar
• Beyaz premium iç mekan
• Tow hitch (çeki demiri)

Supercharger ağı ile Türkiye'nin her yerine seyahat imkanı.''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'tesla'),
      modelName: 'Model Y Long Range',
      year: 2024,
      mileage: 3500,
      bodyType: CarBodyType.suv,
      fuelType: CarFuelType.electric,
      transmission: CarTransmission.automatic,
      traction: CarTraction.awd,
      engineCC: 0,
      horsePower: 384,
      exteriorColor: CarColor.red,
      interiorColor: CarColor.white,
      condition: CarCondition.likeNew,
      price: 2950000,
      isPriceNegotiable: false,
      isExchangeAccepted: false,
      status: CarListingStatus.active,
      seller: sellers[1],
      images: [
        'https://images.unsplash.com/photo-1619317190897-15de2ebe7e8a?w=800',
        'https://images.unsplash.com/photo-1620891549027-942fdc95d3f5?w=800',
        'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'airbag_curtain', 'blind_spot', 'lane_assist', 'parking_sensor', 'rear_camera', '360_camera', 'collision_warning', 'adaptive_cruise', 'climate_control', 'dual_zone_climate', 'heated_seats', 'electric_seats', 'panoramic_roof', 'keyless_entry', 'push_start', 'electric_trunk', 'remote_start', 'bluetooth', 'navigation', 'touchscreen', 'premium_audio', 'wireless_charging', 'digital_cockpit', 'led_headlights', 'alloy_wheels'],
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '34',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      viewCount: 1850,
      favoriteCount: 145,
      contactCount: 34,
      isFeatured: true,
      isPremiumListing: false,
      city: 'İstanbul',
      district: 'Kadıköy',
      hasWarranty: true,
      warrantyDetails: '4 yıl Tesla garantisi',
    ),
    CarListing(
      id: 'car_5',
      title: 'Audi RS6 Avant',
      description: '''Audi RS6 Avant - Aile aracı görünümünde süper araba performansı!

• Karbon seramik frenler
• RS Design paketi
• Bang & Olufsen 3D ses sistemi
• Matrix LED farlar
• Panoramik cam tavan
• RS sport egzoz

En hızlı station wagon!''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'audi'),
      modelName: 'RS6 Avant',
      year: 2023,
      mileage: 8500,
      bodyType: CarBodyType.wagon,
      fuelType: CarFuelType.petrol,
      transmission: CarTransmission.automatic,
      traction: CarTraction.awd,
      engineCC: 3996,
      horsePower: 600,
      exteriorColor: CarColor.gray,
      interiorColor: CarColor.black,
      condition: CarCondition.excellent,
      price: 8500000,
      isPriceNegotiable: true,
      isExchangeAccepted: true,
      status: CarListingStatus.active,
      seller: sellers[1],
      images: [
        'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?w=800',
        'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'airbag_curtain', 'blind_spot', 'lane_assist', 'parking_sensor', 'rear_camera', '360_camera', 'adaptive_cruise', 'climate_control', 'dual_zone_climate', 'heated_seats', 'cooled_seats', 'leather_seats', 'electric_seats', 'memory_seats', 'panoramic_roof', 'keyless_entry', 'push_start', 'electric_trunk', 'bluetooth', 'navigation', 'apple_carplay', 'android_auto', 'touchscreen', 'premium_audio', 'head_up_display', 'digital_cockpit', 'led_headlights', 'adaptive_headlights', 'alloy_wheels'],
      serviceHistory: 'Audi yetkili servis bakımlı',
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '34',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      viewCount: 2780,
      favoriteCount: 234,
      contactCount: 56,
      isFeatured: true,
      isPremiumListing: true,
      city: 'İstanbul',
      district: 'Beşiktaş',
      hasWarranty: true,
      warrantyDetails: '1 yıl Audi garantisi',
    ),
    CarListing(
      id: 'car_6',
      title: 'Volkswagen Golf 1.5 TSI',
      description: '''Volkswagen Golf 1.5 TSI R-Line - Ekonomik ve şık!

• R-Line paket
• Dijital kokpit
• Adaptive cruise control
• Lane assist
• App-Connect (CarPlay & Android Auto)
• LED farlar

İdeal şehir içi ve uzun yol aracı.''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'volkswagen'),
      modelName: 'Golf 1.5 TSI R-Line',
      year: 2023,
      mileage: 25000,
      bodyType: CarBodyType.hatchback,
      fuelType: CarFuelType.petrol,
      transmission: CarTransmission.automatic,
      traction: CarTraction.fwd,
      engineCC: 1498,
      horsePower: 150,
      exteriorColor: CarColor.white,
      interiorColor: CarColor.black,
      condition: CarCondition.excellent,
      price: 1650000,
      isPriceNegotiable: true,
      isExchangeAccepted: true,
      status: CarListingStatus.active,
      seller: sellers[0],
      images: [
        'https://images.unsplash.com/photo-1471444928139-48c5bf5173f8?w=800',
        'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'blind_spot', 'lane_assist', 'parking_sensor', 'rear_camera', 'adaptive_cruise', 'climate_control', 'heated_seats', 'keyless_entry', 'push_start', 'bluetooth', 'navigation', 'apple_carplay', 'android_auto', 'touchscreen', 'digital_cockpit', 'led_headlights', 'alloy_wheels'],
      serviceHistory: 'Yetkili servis bakımlı',
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '35',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      viewCount: 1250,
      favoriteCount: 89,
      contactCount: 23,
      isFeatured: false,
      isPremiumListing: false,
      city: 'İzmir',
      district: 'Karşıyaka',
      hasWarranty: true,
      warrantyDetails: '6 ay garanti',
    ),
    CarListing(
      id: 'car_7',
      title: 'Toyota Corolla Hybrid',
      description: '''Toyota Corolla 1.8 Hybrid - Güvenilirlik ve yakıt tasarrufu!

• Hibrit teknolojisi (4.3L/100km)
• Toyota Safety Sense
• 8" multimedya ekran
• Kablosuz şarj
• Akıllı park sistemi

Dünyada en çok satan otomobil!''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'toyota'),
      modelName: 'Corolla 1.8 Hybrid',
      year: 2024,
      mileage: 8000,
      bodyType: CarBodyType.sedan,
      fuelType: CarFuelType.hybrid,
      transmission: CarTransmission.automatic,
      traction: CarTraction.fwd,
      engineCC: 1798,
      horsePower: 140,
      exteriorColor: CarColor.silver,
      interiorColor: CarColor.black,
      condition: CarCondition.likeNew,
      price: 1450000,
      isPriceNegotiable: false,
      isExchangeAccepted: false,
      status: CarListingStatus.active,
      seller: sellers[0],
      images: [
        'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=800',
        'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'blind_spot', 'lane_assist', 'parking_sensor', 'rear_camera', 'collision_warning', 'adaptive_cruise', 'climate_control', 'keyless_entry', 'push_start', 'bluetooth', 'navigation', 'apple_carplay', 'android_auto', 'touchscreen', 'wireless_charging', 'led_headlights', 'alloy_wheels'],
      serviceHistory: 'Toyota yetkili servis bakımlı',
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '34',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      viewCount: 980,
      favoriteCount: 67,
      contactCount: 18,
      isFeatured: false,
      isPremiumListing: false,
      city: 'İstanbul',
      district: 'Ümraniye',
      hasWarranty: true,
      warrantyDetails: '3 yıl Toyota garantisi',
    ),
    CarListing(
      id: 'car_8',
      title: 'Land Rover Range Rover Sport',
      description: '''Range Rover Sport P400 - Lüks ve arazi kabiliyeti bir arada!

• 22" jantlar
• Meridian 3D ses sistemi
• Hava süspansiyon
• Terrain Response 2
• Pixel LED farlar
• Premium deri döşeme

Her zeminde konfor ve performans.''',
      brand: CarBrand.allBrands.firstWhere((b) => b.id == 'landrover'),
      modelName: 'Range Rover Sport P400',
      year: 2023,
      mileage: 15000,
      bodyType: CarBodyType.suv,
      fuelType: CarFuelType.petrol,
      transmission: CarTransmission.automatic,
      traction: CarTraction.awd,
      engineCC: 2996,
      horsePower: 400,
      exteriorColor: CarColor.black,
      interiorColor: CarColor.beige,
      condition: CarCondition.excellent,
      price: 7250000,
      isPriceNegotiable: true,
      isExchangeAccepted: true,
      status: CarListingStatus.active,
      seller: sellers[1],
      images: [
        'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?w=800',
        'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=800',
      ],
      featureIds: ['abs', 'esp', 'airbag_front', 'airbag_side', 'airbag_curtain', 'blind_spot', 'lane_assist', 'parking_sensor', 'rear_camera', '360_camera', 'adaptive_cruise', 'climate_control', 'dual_zone_climate', 'heated_seats', 'cooled_seats', 'leather_seats', 'electric_seats', 'memory_seats', 'panoramic_roof', 'keyless_entry', 'push_start', 'electric_trunk', 'bluetooth', 'navigation', 'apple_carplay', 'android_auto', 'touchscreen', 'premium_audio', 'wireless_charging', 'head_up_display', 'digital_cockpit', 'led_headlights', 'adaptive_headlights', 'fog_lights', 'alloy_wheels', 'roof_rails'],
      serviceHistory: 'Yetkili servis bakımlı',
      previousOwners: 1,
      hasOriginalPaint: true,
      hasAccidentHistory: false,
      plateCity: '34',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      viewCount: 2100,
      favoriteCount: 178,
      contactCount: 42,
      isFeatured: true,
      isPremiumListing: true,
      city: 'İstanbul',
      district: 'Beykoz',
      hasWarranty: true,
      warrantyDetails: '2 yıl Land Rover garantisi',
    ),
  ];

  static List<CarListing> get featuredListings =>
      listings.where((l) => l.isFeatured).toList();

  static List<CarListing> get premiumListings =>
      listings.where((l) => l.isPremiumListing).toList();

  static List<CarListing> getListingsByBrand(String brandId) =>
      listings.where((l) => l.brand.id == brandId).toList();

  static List<CarListing> getListingsByBodyType(CarBodyType bodyType) =>
      listings.where((l) => l.bodyType == bodyType).toList();
}
