// Realtor Review Model
// DB Table: realtor_reviews

class RealtorReview {
  final String id;
  final String realtorId;
  final String userId;
  final String? propertyId;
  final int rating;
  final String? title;
  final String? comment;
  final int? communicationRating;
  final int? professionalismRating;
  final int? knowledgeRating;
  final bool isVerified;
  final bool isVisible;
  final String? realtorResponse;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Nested reviewer profile data (from user_profiles join)
  final String? reviewerName;
  final String? reviewerAvatarUrl;

  const RealtorReview({
    required this.id,
    required this.realtorId,
    required this.userId,
    this.propertyId,
    required this.rating,
    this.title,
    this.comment,
    this.communicationRating,
    this.professionalismRating,
    this.knowledgeRating,
    this.isVerified = false,
    this.isVisible = true,
    this.realtorResponse,
    this.respondedAt,
    required this.createdAt,
    this.updatedAt,
    this.reviewerName,
    this.reviewerAvatarUrl,
  });

  factory RealtorReview.fromJson(Map<String, dynamic> json) {
    // Extract nested reviewer profile if present (support multiple join keys)
    final profile = json['users'] as Map<String, dynamic>? ??
        json['user_profiles'] as Map<String, dynamic>? ??
        json['reviewer'] as Map<String, dynamic>?;

    return RealtorReview(
      id: json['id'] as String,
      realtorId: json['realtor_id'] as String,
      userId: json['user_id'] as String,
      propertyId: json['property_id'] as String?,
      rating: json['rating'] as int,
      title: json['title'] as String?,
      comment: json['comment'] as String?,
      communicationRating: json['communication_rating'] as int?,
      professionalismRating: json['professionalism_rating'] as int?,
      knowledgeRating: json['knowledge_rating'] as int?,
      isVerified: json['is_verified'] as bool? ?? false,
      isVisible: json['is_visible'] as bool? ?? true,
      realtorResponse: json['realtor_response'] as String?,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      reviewerName: profile?['full_name'] as String? ??
          profile?['name'] as String?,
      reviewerAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  RealtorReview copyWith({
    String? id,
    String? realtorId,
    String? userId,
    String? propertyId,
    int? rating,
    String? title,
    String? comment,
    int? communicationRating,
    int? professionalismRating,
    int? knowledgeRating,
    bool? isVerified,
    bool? isVisible,
    String? realtorResponse,
    DateTime? respondedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reviewerName,
    String? reviewerAvatarUrl,
  }) {
    return RealtorReview(
      id: id ?? this.id,
      realtorId: realtorId ?? this.realtorId,
      userId: userId ?? this.userId,
      propertyId: propertyId ?? this.propertyId,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      communicationRating: communicationRating ?? this.communicationRating,
      professionalismRating:
          professionalismRating ?? this.professionalismRating,
      knowledgeRating: knowledgeRating ?? this.knowledgeRating,
      isVerified: isVerified ?? this.isVerified,
      isVisible: isVisible ?? this.isVisible,
      realtorResponse: realtorResponse ?? this.realtorResponse,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerAvatarUrl: reviewerAvatarUrl ?? this.reviewerAvatarUrl,
    );
  }

  /// Average of sub-ratings (communication, professionalism, knowledge)
  double? get averageSubRating {
    final ratings = <int>[];
    if (communicationRating != null) ratings.add(communicationRating!);
    if (professionalismRating != null) ratings.add(professionalismRating!);
    if (knowledgeRating != null) ratings.add(knowledgeRating!);
    if (ratings.isEmpty) return null;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  /// Whether the realtor has responded to this review
  bool get hasResponse =>
      realtorResponse != null && realtorResponse!.isNotEmpty;

  /// Display name for the reviewer
  String get displayName => reviewerName ?? 'Anonim Kullanıcı';
}
