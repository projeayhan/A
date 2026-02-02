import 'package:flutter/material.dart';

/// Surus durumu enum
enum RideStatus {
  pending,
  accepted,
  arrived,
  inProgress,
  completed,
  cancelledByUser,
  cancelledByDriver,
  noDriverFound,
}

extension RideStatusExtension on RideStatus {
  String get value {
    switch (this) {
      case RideStatus.pending:
        return 'pending';
      case RideStatus.accepted:
        return 'accepted';
      case RideStatus.arrived:
        return 'arrived';
      case RideStatus.inProgress:
        return 'in_progress';
      case RideStatus.completed:
        return 'completed';
      case RideStatus.cancelledByUser:
        return 'cancelled_by_user';
      case RideStatus.cancelledByDriver:
        return 'cancelled_by_driver';
      case RideStatus.noDriverFound:
        return 'no_driver_found';
    }
  }

  String get displayName {
    switch (this) {
      case RideStatus.pending:
        return 'Surucu Araniyor';
      case RideStatus.accepted:
        return 'Kabul Edildi';
      case RideStatus.arrived:
        return 'Musteride';
      case RideStatus.inProgress:
        return 'Yolculukta';
      case RideStatus.completed:
        return 'Tamamlandi';
      case RideStatus.cancelledByUser:
        return 'Musteri Iptal';
      case RideStatus.cancelledByDriver:
        return 'Surucu Iptal';
      case RideStatus.noDriverFound:
        return 'Surucu Bulunamadi';
    }
  }

  Color get color {
    switch (this) {
      case RideStatus.pending:
        return Colors.orange;
      case RideStatus.accepted:
        return Colors.blue;
      case RideStatus.arrived:
        return Colors.purple;
      case RideStatus.inProgress:
        return Colors.green;
      case RideStatus.completed:
        return Colors.teal;
      case RideStatus.cancelledByUser:
      case RideStatus.cancelledByDriver:
      case RideStatus.noDriverFound:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case RideStatus.pending:
        return Icons.hourglass_empty;
      case RideStatus.accepted:
        return Icons.check_circle;
      case RideStatus.arrived:
        return Icons.place;
      case RideStatus.inProgress:
        return Icons.local_taxi;
      case RideStatus.completed:
        return Icons.done_all;
      case RideStatus.cancelledByUser:
      case RideStatus.cancelledByDriver:
      case RideStatus.noDriverFound:
        return Icons.cancel;
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
      case 'cancelled_by_user':
        return RideStatus.cancelledByUser;
      case 'cancelled_by_driver':
        return RideStatus.cancelledByDriver;
      case 'no_driver_found':
        return RideStatus.noDriverFound;
      default:
        return RideStatus.pending;
    }
  }
}

/// Konum modeli
class RideLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String? name;

  const RideLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.name,
  });

  factory RideLocation.fromJson(Map<String, dynamic> json, String prefix) {
    return RideLocation(
      latitude: (json['${prefix}_lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['${prefix}_lng'] as num?)?.toDouble() ?? 0,
      address: json['${prefix}_address'] as String? ?? '',
      name: json['${prefix}_name'] as String?,
    );
  }

  String get displayName => name ?? address;
}

/// Surus modeli
class Ride {
  final String id;
  final String? rideNumber;
  final String userId;
  final String? driverId;
  final RideLocation pickup;
  final RideLocation dropoff;
  final RideStatus status;
  final double fare;
  final double distanceKm;
  final int durationMinutes;
  final String? customerName;
  final String? customerPhone;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final int? rating;
  final String? ratingComment;

  const Ride({
    required this.id,
    this.rideNumber,
    required this.userId,
    this.driverId,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.fare,
    required this.distanceKm,
    required this.durationMinutes,
    this.customerName,
    this.customerPhone,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.pickedUpAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.rating,
    this.ratingComment,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as String,
      rideNumber: json['ride_number'] as String?,
      userId: json['user_id'] as String,
      driverId: json['driver_id'] as String?,
      pickup: RideLocation.fromJson(json, 'pickup'),
      dropoff: RideLocation.fromJson(json, 'dropoff'),
      status: RideStatusExtension.fromString(json['status'] as String?),
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'] as String)
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
    );
  }

  bool get isActive => [
        RideStatus.accepted,
        RideStatus.arrived,
        RideStatus.inProgress,
      ].contains(status);

  bool get isCancelled => [
        RideStatus.cancelledByUser,
        RideStatus.cancelledByDriver,
        RideStatus.noDriverFound,
      ].contains(status);

  String get formattedFare => '${fare.toStringAsFixed(2)} TL';

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  String get formattedDuration {
    if (durationMinutes < 60) {
      return '$durationMinutes dk';
    }
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return '${hours}s ${minutes}dk';
  }

  /// Bir sonraki aksiyonun ne olduğunu belirle
  String? get nextActionLabel {
    switch (status) {
      case RideStatus.accepted:
        return 'Vardim';
      case RideStatus.arrived:
        return 'Yolculugu Baslat';
      case RideStatus.inProgress:
        return 'Yolculugu Tamamla';
      default:
        return null;
    }
  }

  RideStatus? get nextStatus {
    switch (status) {
      case RideStatus.accepted:
        return RideStatus.arrived;
      case RideStatus.arrived:
        return RideStatus.inProgress;
      case RideStatus.inProgress:
        return RideStatus.completed;
      default:
        return null;
    }
  }
}

/// Surucu modeli
class Driver {
  final String id;
  final String userId;
  final String fullName;
  final String? phone;
  final String? email;
  final String? profilePhotoUrl;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? vehicleColor;
  final int? vehicleYear;
  final String status;
  final bool isOnline;
  final bool isVerified;
  final double rating;
  final int totalRatings;
  final int totalRides;
  final double totalEarnings;
  final double? currentLatitude;
  final double? currentLongitude;
  final DateTime? lastOnlineAt;
  final DateTime createdAt;

  const Driver({
    required this.id,
    required this.userId,
    required this.fullName,
    this.phone,
    this.email,
    this.profilePhotoUrl,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleColor,
    this.vehicleYear,
    required this.status,
    required this.isOnline,
    required this.isVerified,
    required this.rating,
    required this.totalRatings,
    required this.totalRides,
    required this.totalEarnings,
    this.currentLatitude,
    this.currentLongitude,
    this.lastOnlineAt,
    required this.createdAt,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? 'Surucu',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      vehicleYear: json['vehicle_year'] as int?,
      status: json['status'] as String? ?? 'pending',
      isOnline: json['is_online'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      totalRides: json['total_rides'] as int? ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      currentLatitude: (json['current_latitude'] as num?)?.toDouble(),
      currentLongitude: (json['current_longitude'] as num?)?.toDouble(),
      lastOnlineAt: json['last_online_at'] != null
          ? DateTime.parse(json['last_online_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get vehicleInfo {
    final parts = <String>[];
    if (vehicleBrand != null) parts.add(vehicleBrand!);
    if (vehicleModel != null) parts.add(vehicleModel!);
    return parts.join(' ');
  }

  String get vehicleFullInfo {
    final parts = <String>[];
    if (vehicleColor != null) parts.add(vehicleColor!);
    if (vehicleBrand != null) parts.add(vehicleBrand!);
    if (vehicleModel != null) parts.add(vehicleModel!);
    if (vehicleYear != null) parts.add('($vehicleYear)');
    return parts.join(' ');
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
}

/// Kazanc ozeti modeli
class EarningsSummary {
  final double today;
  final double week;
  final double month;
  final double total;
  final int todayRides;
  final int weekRides;
  final int monthRides;
  final int totalRides;
  final double rating;

  const EarningsSummary({
    required this.today,
    required this.week,
    required this.month,
    required this.total,
    required this.todayRides,
    required this.weekRides,
    required this.monthRides,
    required this.totalRides,
    required this.rating,
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      today: (json['today'] as num?)?.toDouble() ?? 0.0,
      week: (json['week'] as num?)?.toDouble() ?? 0.0,
      month: (json['month'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      todayRides: json['today_rides'] as int? ?? 0,
      weekRides: json['week_rides'] as int? ?? 0,
      monthRides: json['month_rides'] as int? ?? 0,
      totalRides: json['total_rides'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
    );
  }

  static EarningsSummary empty() {
    return const EarningsSummary(
      today: 0,
      week: 0,
      month: 0,
      total: 0,
      todayRides: 0,
      weekRides: 0,
      monthRides: 0,
      totalRides: 0,
      rating: 5.0,
    );
  }
}
