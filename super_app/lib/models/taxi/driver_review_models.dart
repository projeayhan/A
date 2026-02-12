import 'package:flutter/material.dart';

/// Feedback tag model
class TaxiFeedbackTag {
  final String id;
  final String tagKey;
  final String tagText;
  final String category;
  final String? iconName;
  final int sortOrder;

  const TaxiFeedbackTag({
    required this.id,
    required this.tagKey,
    required this.tagText,
    required this.category,
    this.iconName,
    this.sortOrder = 0,
  });

  factory TaxiFeedbackTag.fromJson(Map<String, dynamic> json) {
    return TaxiFeedbackTag(
      id: json['id'] as String,
      tagKey: json['tag_key'] as String,
      tagText: json['tag_text_tr'] as String? ?? json['tag_key'] as String,
      category: json['category'] as String,
      iconName: json['icon_name'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  bool get isPositive => category == 'positive';
  bool get isNegative => category == 'negative';
}

/// Driver review detail model
class DriverReview {
  final String id;
  final String rideId;
  final String driverId;
  final String customerId;
  final String? customerName;
  final int rating;
  final String? comment;
  final List<String> feedbackTags;
  final String? driverReply;
  final DateTime? driverRepliedAt;
  final double? tipAmount;
  final DateTime createdAt;
  final DateTime? rideCompletedAt;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? fare;

  const DriverReview({
    required this.id,
    required this.rideId,
    required this.driverId,
    required this.customerId,
    this.customerName,
    required this.rating,
    this.comment,
    this.feedbackTags = const [],
    this.driverReply,
    this.driverRepliedAt,
    this.tipAmount,
    required this.createdAt,
    this.rideCompletedAt,
    this.pickupAddress,
    this.dropoffAddress,
    this.fare,
  });

  factory DriverReview.fromJson(Map<String, dynamic> json) {
    final rideData = json['ride'] as Map<String, dynamic>?;

    return DriverReview(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      driverId: json['driver_id'] as String,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String?,
      rating: rideData?['rating'] as int? ?? 0,
      comment: rideData?['rating_comment'] as String?,
      feedbackTags: (json['feedback_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      driverReply: json['driver_reply'] as String?,
      driverRepliedAt: json['driver_replied_at'] != null
          ? DateTime.parse(json['driver_replied_at'] as String)
          : null,
      tipAmount: (rideData?['tip_amount'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      rideCompletedAt: rideData?['completed_at'] != null
          ? DateTime.parse(rideData!['completed_at'] as String)
          : null,
      pickupAddress: rideData?['pickup_address'] as String?,
      dropoffAddress: rideData?['dropoff_address'] as String?,
      fare: (rideData?['fare'] as num?)?.toDouble(),
    );
  }

  factory DriverReview.fromMap(Map<String, dynamic> map) => DriverReview.fromJson(map);

  bool get hasReply => driverReply != null && driverReply!.isNotEmpty;
  bool get hasTip => tipAmount != null && tipAmount! > 0;
  DateTime? get replyDate => driverRepliedAt;

  String get formattedDate {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    return '$day.$month.$year';
  }

  Color get ratingColor {
    switch (rating) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.amber;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get ratingText {
    switch (rating) {
      case 5:
        return 'Mükemmel';
      case 4:
        return 'Çok İyi';
      case 3:
        return 'İyi';
      case 2:
        return 'Orta';
      case 1:
        return 'Kötü';
      default:
        return '';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 30) {
      return '${diff.inDays ~/ 30} ay önce';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} gün önce';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} saat önce';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}

/// Driver rating statistics model
class DriverRatingStats {
  final String driverId;
  final double overallRating;
  final int totalRatings;
  final int totalRides;
  final int rating5Count;
  final int rating4Count;
  final int rating3Count;
  final int rating2Count;
  final int rating1Count;
  final double rating30Days;
  final int totalRatings30Days;

  const DriverRatingStats({
    required this.driverId,
    required this.overallRating,
    required this.totalRatings,
    required this.totalRides,
    this.rating5Count = 0,
    this.rating4Count = 0,
    this.rating3Count = 0,
    this.rating2Count = 0,
    this.rating1Count = 0,
    this.rating30Days = 0.0,
    this.totalRatings30Days = 0,
  });

  factory DriverRatingStats.fromJson(Map<String, dynamic> json) {
    return DriverRatingStats(
      driverId: json['id'] as String,
      overallRating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      totalRides: json['total_rides'] as int? ?? 0,
      rating5Count: json['rating_count_5'] as int? ?? 0,
      rating4Count: json['rating_count_4'] as int? ?? 0,
      rating3Count: json['rating_count_3'] as int? ?? 0,
      rating2Count: json['rating_count_2'] as int? ?? 0,
      rating1Count: json['rating_count_1'] as int? ?? 0,
      rating30Days: (json['rating_30d'] as num?)?.toDouble() ?? 0.0,
      totalRatings30Days: json['total_ratings_30d'] as int? ?? 0,
    );
  }

  factory DriverRatingStats.fromMap(Map<String, dynamic> map) => DriverRatingStats.fromJson(map);

  int getCountForRating(int rating) {
    switch (rating) {
      case 5:
        return rating5Count;
      case 4:
        return rating4Count;
      case 3:
        return rating3Count;
      case 2:
        return rating2Count;
      case 1:
        return rating1Count;
      default:
        return 0;
    }
  }

  double getPercentageForRating(int rating) {
    if (totalRatings == 0) return 0;
    return getCountForRating(rating) / totalRatings;
  }

  bool get isTrendingUp => rating30Days > overallRating;
  bool get isTrendingDown => rating30Days < overallRating;

  double get trendDifference => rating30Days - overallRating;

  String get trendText {
    final diff = trendDifference.abs();
    if (diff < 0.1) return 'Stabil';
    if (isTrendingUp) return '+${diff.toStringAsFixed(1)}';
    return '-${diff.toStringAsFixed(1)}';
  }
}
