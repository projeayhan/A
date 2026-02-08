class Store {
  final String id;
  final String name;
  final String logoUrl;
  final String coverUrl;
  final String categoryId;
  final double rating;
  final int reviewCount;
  final int followerCount;
  final int productCount;
  final bool isVerified;
  final bool isFavorite;
  final String deliveryTime;
  final double minOrderAmount;
  final List<String> tags;
  final String? discountBadge;
  final DateTime? memberSince;

  const Store({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.coverUrl,
    required this.categoryId,
    required this.rating,
    required this.reviewCount,
    this.followerCount = 0,
    this.productCount = 0,
    this.isVerified = false,
    this.isFavorite = false,
    this.deliveryTime = '1-3 gün',
    this.minOrderAmount = 0,
    this.tags = const [],
    this.discountBadge,
    this.memberSince,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String? ?? '',
      coverUrl: json['cover_url'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      followerCount: json['follower_count'] as int? ?? 0,
      productCount: json['product_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isFavorite: false,
      deliveryTime: json['delivery_time'] as String? ?? '1-3 gün',
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      discountBadge: json['discount_badge'] as String?,
      memberSince: json['member_since'] != null ? DateTime.parse(json['member_since'] as String) : null,
    );
  }

  // merchants tablosundan Store oluştur
  factory Store.fromMerchant(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      name: json['business_name'] as String? ?? '',
      logoUrl: json['logo_url'] as String? ?? '',
      coverUrl: json['cover_url'] as String? ?? '',
      categoryId: '', // merchants tablosunda category_id yok, category_tags var
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['total_reviews'] as int? ?? 0,
      followerCount: 0,
      productCount: _extractProductCount(json),
      isVerified: json['is_approved'] as bool? ?? false,
      isFavorite: false,
      deliveryTime: json['delivery_time'] as String? ?? '1-3 gün',
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      tags: (json['category_tags'] as List<dynamic>?)?.cast<String>() ?? [],
      discountBadge: json['discount_badge'] as String?,
      memberSince: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  static int _extractProductCount(Map<String, dynamic> json) {
    final products = json['products'];
    if (products is List && products.isNotEmpty) {
      return (products[0]['count'] as int?) ?? 0;
    }
    return 0;
  }

  String get formattedFollowers {
    if (followerCount >= 1000000) {
      return '${(followerCount / 1000000).toStringAsFixed(1)}M';
    } else if (followerCount >= 1000) {
      return '${(followerCount / 1000).toStringAsFixed(1)}K';
    }
    return followerCount.toString();
  }

  String get formattedRating => rating.toStringAsFixed(1);

  // Veriler Supabase'den yüklenir
  static List<Store> get mockStores => [];

  static List<Store> get featuredStores => [];

  static List<Store> get flashDealStores => [];
}
