/// CRM KPI özet verileri
class CrmKpis {
  final int totalClients;
  final int activeClients;
  final int linkedClients;
  final int dueFollowups;
  final int totalClientViews;
  final int totalClientFavorites;
  final String? mostEngagedClientName;
  final String? mostEngagedClientId;

  const CrmKpis({
    this.totalClients = 0,
    this.activeClients = 0,
    this.linkedClients = 0,
    this.dueFollowups = 0,
    this.totalClientViews = 0,
    this.totalClientFavorites = 0,
    this.mostEngagedClientName,
    this.mostEngagedClientId,
  });

  factory CrmKpis.fromJson(Map<String, dynamic> json) {
    return CrmKpis(
      totalClients: (json['total_clients'] as num?)?.toInt() ?? 0,
      activeClients: (json['active_clients'] as num?)?.toInt() ?? 0,
      linkedClients: (json['linked_clients'] as num?)?.toInt() ?? 0,
      dueFollowups: (json['due_followups'] as num?)?.toInt() ?? 0,
      totalClientViews: (json['total_client_views'] as num?)?.toInt() ?? 0,
      totalClientFavorites:
          (json['total_client_favorites'] as num?)?.toInt() ?? 0,
      mostEngagedClientName: json['most_engaged_client_name'] as String?,
      mostEngagedClientId: json['most_engaged_client_id'] as String?,
    );
  }
}

/// Müşteri başına engagement verileri
class ClientEngagement {
  final String clientId;
  final String clientName;
  final String clientStatus;
  final String? clientUserId;
  final int viewCount;
  final int favoriteCount;
  final DateTime? lastViewAt;
  final DateTime? lastFavoriteAt;
  final DateTime? lastActivityAt;
  final int appointmentCount;
  final double engagementScore;

  const ClientEngagement({
    required this.clientId,
    required this.clientName,
    required this.clientStatus,
    this.clientUserId,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.lastViewAt,
    this.lastFavoriteAt,
    this.lastActivityAt,
    this.appointmentCount = 0,
    this.engagementScore = 0,
  });

  factory ClientEngagement.fromJson(Map<String, dynamic> json) {
    return ClientEngagement(
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String,
      clientStatus: json['client_status'] as String? ?? 'potential',
      clientUserId: json['client_user_id'] as String?,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (json['favorite_count'] as num?)?.toInt() ?? 0,
      lastViewAt: json['last_view_at'] != null
          ? DateTime.parse(json['last_view_at'] as String)
          : null,
      lastFavoriteAt: json['last_favorite_at'] != null
          ? DateTime.parse(json['last_favorite_at'] as String)
          : null,
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.parse(json['last_activity_at'] as String)
          : null,
      appointmentCount: (json['appointment_count'] as num?)?.toInt() ?? 0,
      engagementScore: (json['engagement_score'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get isLinked => clientUserId != null;
}

/// İlan başına müşteri ilgisi
class PropertyClientInterest {
  final String propertyId;
  final String title;
  final String city;
  final String district;
  final double price;
  final List<String> images;
  final int clientViewCount;
  final int clientFavoriteCount;
  final int uniqueClientViewers;
  final int uniqueClientFavoriters;

  const PropertyClientInterest({
    required this.propertyId,
    required this.title,
    required this.city,
    required this.district,
    required this.price,
    this.images = const [],
    this.clientViewCount = 0,
    this.clientFavoriteCount = 0,
    this.uniqueClientViewers = 0,
    this.uniqueClientFavoriters = 0,
  });

  factory PropertyClientInterest.fromJson(Map<String, dynamic> json) {
    return PropertyClientInterest(
      propertyId: json['property_id'] as String,
      title: json['title'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      clientViewCount: (json['client_view_count'] as num?)?.toInt() ?? 0,
      clientFavoriteCount:
          (json['client_favorite_count'] as num?)?.toInt() ?? 0,
      uniqueClientViewers:
          (json['unique_client_viewers'] as num?)?.toInt() ?? 0,
      uniqueClientFavoriters:
          (json['unique_client_favoriters'] as num?)?.toInt() ?? 0,
    );
  }

  String get firstImage => images.isNotEmpty ? images.first : '';

  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M TL';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K TL';
    }
    return '${price.toStringAsFixed(0)} TL';
  }
}

/// Müşterinin belirli ilan aktivitesi
class ClientPropertyActivity {
  final String propertyId;
  final String title;
  final String city;
  final String district;
  final double price;
  final List<String> images;
  final int viewCount;
  final DateTime? firstViewedAt;
  final DateTime? lastViewedAt;
  final bool isFavorited;
  final DateTime? favoritedAt;

  const ClientPropertyActivity({
    required this.propertyId,
    required this.title,
    required this.city,
    required this.district,
    required this.price,
    this.images = const [],
    this.viewCount = 0,
    this.firstViewedAt,
    this.lastViewedAt,
    this.isFavorited = false,
    this.favoritedAt,
  });

  factory ClientPropertyActivity.fromJson(Map<String, dynamic> json) {
    return ClientPropertyActivity(
      propertyId: json['property_id'] as String,
      title: json['title'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      firstViewedAt: json['first_viewed_at'] != null
          ? DateTime.parse(json['first_viewed_at'] as String)
          : null,
      lastViewedAt: json['last_viewed_at'] != null
          ? DateTime.parse(json['last_viewed_at'] as String)
          : null,
      isFavorited: json['is_favorited'] as bool? ?? false,
      favoritedAt: json['favorited_at'] != null
          ? DateTime.parse(json['favorited_at'] as String)
          : null,
    );
  }

  String get firstImage => images.isNotEmpty ? images.first : '';

  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M TL';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K TL';
    }
    return '${price.toStringAsFixed(0)} TL';
  }
}

/// Aktivite feed öğesi
class ActivityFeedItem {
  final String activityType; // 'view', 'favorite', 'appointment'
  final String? clientId;
  final String? clientName;
  final String? propertyId;
  final String? propertyTitle;
  final DateTime activityAt;

  const ActivityFeedItem({
    required this.activityType,
    this.clientId,
    this.clientName,
    this.propertyId,
    this.propertyTitle,
    required this.activityAt,
  });

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    return ActivityFeedItem(
      activityType: json['activity_type'] as String? ?? 'view',
      clientId: json['client_id'] as String?,
      clientName: json['client_name'] as String?,
      propertyId: json['property_id'] as String?,
      propertyTitle: json['property_title'] as String?,
      activityAt: DateTime.parse(json['activity_at'] as String),
    );
  }

  String get actionText {
    switch (activityType) {
      case 'view':
        return 'goruntuledi';
      case 'favorite':
        return 'favorilere ekledi';
      case 'appointment':
        return 'randevu';
      default:
        return activityType;
    }
  }
}
