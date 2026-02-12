import 'package:flutter/material.dart';

/// Konum modeli
class TaxiLocation {
  final String? id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? type; // 'home', 'work', 'recent', 'search'
  final IconData? icon;

  const TaxiLocation({
    this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.type,
    this.icon,
  });

  factory TaxiLocation.fromJson(Map<String, dynamic> json) {
    return TaxiLocation(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'type': type,
  };

  TaxiLocation copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? type,
    IconData? icon,
  }) {
    return TaxiLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      icon: icon ?? this.icon,
    );
  }
}

/// Araç tipi modeli
class VehicleType {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final IconData icon;
  final double baseFare;
  final double perKmRate;
  final double perMinuteRate;
  final double minimumFare;
  final int capacity;
  final Color color;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  const VehicleType({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.baseFare,
    required this.perKmRate,
    required this.perMinuteRate,
    required this.minimumFare,
    required this.capacity,
    required this.color,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: _getIconFromName(
        json['name'] as String? ?? json['icon_name'] as String?,
      ),
      baseFare:
          (json['default_base_fare'] as num?)?.toDouble() ??
          (json['base_fare'] as num?)?.toDouble() ??
          10.0,
      perKmRate:
          (json['default_per_km'] as num?)?.toDouble() ??
          (json['per_km_rate'] as num?)?.toDouble() ??
          5.0,
      perMinuteRate:
          (json['default_per_minute'] as num?)?.toDouble() ??
          (json['per_minute_rate'] as num?)?.toDouble() ??
          0.5,
      minimumFare:
          (json['default_minimum_fare'] as num?)?.toDouble() ??
          (json['minimum_fare'] as num?)?.toDouble() ??
          35.0,
      capacity: json['capacity'] as int? ?? 4,
      color: _getColorFromName(json['name'] as String?),
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static IconData _getIconFromName(String? name) {
    switch (name?.toLowerCase()) {
      case 'economy':
        return Icons.directions_car_rounded;
      case 'standard':
        return Icons.directions_car;
      case 'comfort':
        return Icons.directions_car_filled_rounded;
      case 'xl':
      case 'suv':
        return Icons.airport_shuttle_rounded;
      case 'vip':
      case 'premium':
      case 'luxury':
        return Icons.local_taxi_rounded;
      case 'kulis':
        return Icons.star_rounded;
      default:
        return Icons.directions_car;
    }
  }

  static Color _getColorFromName(String? name) {
    switch (name?.toLowerCase()) {
      case 'economy':
        return Colors.blue;
      case 'standard':
        return Colors.teal;
      case 'comfort':
        return Colors.green;
      case 'xl':
        return Colors.orange;
      case 'vip':
      case 'premium':
        return Colors.purple;
      case 'kulis':
        return const Color(0xFFFFD700); // Gold
      default:
        return Colors.blue;
    }
  }

  double calculateFare(
    double distanceKm,
    int durationMinutes, {
    double surge = 1.0,
  }) {
    final calculatedFare =
        (baseFare +
            (distanceKm * perKmRate) +
            (durationMinutes * perMinuteRate)) *
        surge;
    // Minimum ücretin altına düşmemeli
    final fare = calculatedFare < minimumFare ? minimumFare : calculatedFare;
    return (fare * 100).round() / 100;
  }
}

/// Sürücü modeli
class TaxiDriver {
  final String id;
  final String fullName;
  final String? phone;
  final double rating;
  final int totalRatings;
  final int totalRides;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePlate;
  final int? vehicleYear;
  final String? avatarUrl;

  const TaxiDriver({
    required this.id,
    required this.fullName,
    this.phone,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.totalRides = 0,
    this.currentLatitude,
    this.currentLongitude,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePlate,
    this.vehicleYear,
    this.avatarUrl,
  });

  bool get isNewDriver => totalRatings < 5;

  factory TaxiDriver.fromJson(Map<String, dynamic> json) {
    return TaxiDriver(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Sürücü',
      phone: json['phone'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      totalRides: json['total_rides'] as int? ?? 0,
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleYear: json['vehicle_year'] as int?,
      avatarUrl: json['profile_photo_url'] as String? ?? json['avatar_url'] as String?,
    );
  }

  String get vehicleInfo {
    final parts = <String>[];
    if (vehicleBrand != null) parts.add(vehicleBrand!);
    if (vehicleModel != null) parts.add(vehicleModel!);
    if (vehicleColor != null) parts.add(vehicleColor!);
    return parts.join(' ');
  }
}

/// Sürüş durumu enum
enum RideStatus {
  pending, // Beklemede - sürücü aranıyor
  accepted, // Kabul edildi - sürücü yolda
  arrived, // Varış noktasında - sürücü müşteriyi bekliyor
  inProgress, // Yolculuk başladı
  completed, // Tamamlandı
  cancelled, // İptal edildi
}

extension RideStatusExtension on RideStatus {
  String get displayName {
    switch (this) {
      case RideStatus.pending:
        return 'Sürücü Aranıyor';
      case RideStatus.accepted:
        return 'Sürücü Yolda';
      case RideStatus.arrived:
        return 'Sürücü Bekliyor';
      case RideStatus.inProgress:
        return 'Yolculuk Devam Ediyor';
      case RideStatus.completed:
        return 'Tamamlandı';
      case RideStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  Color get color {
    switch (this) {
      case RideStatus.pending:
        return Colors.orange;
      case RideStatus.accepted:
        return Colors.blue;
      case RideStatus.arrived:
        return Colors.green;
      case RideStatus.inProgress:
        return Colors.purple;
      case RideStatus.completed:
        return Colors.teal;
      case RideStatus.cancelled:
        return Colors.red;
    }
  }

  static RideStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return RideStatus.pending;
      case 'accepted':
      case 'driver_assigned':
        return RideStatus.accepted;
      case 'arrived':
        return RideStatus.arrived;
      case 'in_progress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled':
      case 'cancelled_by_user':
      case 'cancelled_by_driver':
        return RideStatus.cancelled;
      default:
        return RideStatus.pending;
    }
  }
}

/// Sürüş modeli
class TaxiRide {
  final String id;
  final String? rideNumber;
  final String userId;
  final String? driverId;
  final TaxiDriver? driver;
  final TaxiLocation pickup;
  final TaxiLocation dropoff;
  final RideStatus status;
  final double fare;
  final double distanceKm;
  final int durationMinutes;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final int? rating;
  final String? ratingComment;
  final double? tipAmount;
  final String? vehicleTypeId;

  const TaxiRide({
    required this.id,
    this.rideNumber,
    required this.userId,
    this.driverId,
    this.driver,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.fare,
    required this.distanceKm,
    required this.durationMinutes,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.rating,
    this.ratingComment,
    this.tipAmount,
    this.vehicleTypeId,
  });

  factory TaxiRide.fromJson(Map<String, dynamic> json) {
    final driverData = json['driver'] as Map<String, dynamic>?;

    return TaxiRide(
      id: json['id'] as String,
      rideNumber: json['ride_number'] as String?,
      userId: json['user_id'] as String,
      driverId: json['driver_id'] as String?,
      driver: driverData != null ? TaxiDriver.fromJson(driverData) : null,
      pickup: TaxiLocation(
        name: json['pickup_address'] as String? ?? '',
        address: json['pickup_address'] as String? ?? '',
        latitude: (json['pickup_lat'] as num?)?.toDouble() ?? 0,
        longitude: (json['pickup_lng'] as num?)?.toDouble() ?? 0,
      ),
      dropoff: TaxiLocation(
        name: json['dropoff_address'] as String? ?? '',
        address: json['dropoff_address'] as String? ?? '',
        latitude: (json['dropoff_lat'] as num?)?.toDouble() ?? 0,
        longitude: (json['dropoff_lng'] as num?)?.toDouble() ?? 0,
      ),
      status: RideStatusExtension.fromString(json['status'] as String?),
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      rating: json['rating'] as int?,
      ratingComment: json['rating_comment'] as String?,
      tipAmount: (json['tip_amount'] as num?)?.toDouble(),
      vehicleTypeId: json['vehicle_type_id'] as String?,
    );
  }

  /// copyWith metodu - sürücü bilgisini güncellemek için
  TaxiRide copyWith({
    String? id,
    String? rideNumber,
    String? userId,
    String? driverId,
    TaxiDriver? driver,
    TaxiLocation? pickup,
    TaxiLocation? dropoff,
    RideStatus? status,
    double? fare,
    double? distanceKm,
    int? durationMinutes,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    int? rating,
    String? ratingComment,
    double? tipAmount,
    String? vehicleTypeId,
  }) {
    return TaxiRide(
      id: id ?? this.id,
      rideNumber: rideNumber ?? this.rideNumber,
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      driver: driver ?? this.driver,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      tipAmount: tipAmount ?? this.tipAmount,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
    );
  }
}
