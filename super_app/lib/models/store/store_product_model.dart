class StoreProduct {
  final String id;
  final String storeId;
  final String storeName;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final double? originalPrice;
  final double rating;
  final int reviewCount;
  final int soldCount;
  final bool isFavorite;
  final bool freeShipping;
  final bool fastDelivery;
  final List<String> images;
  final Map<String, List<String>>? variants;
  final int stock;
  final String category;
  final int categorySortOrder;
  final String? promotionLabel; // Mağaza tarafından belirlenen promosyon etiketi

  const StoreProduct({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    this.originalPrice,
    required this.rating,
    required this.reviewCount,
    this.soldCount = 0,
    this.isFavorite = false,
    this.freeShipping = false,
    this.fastDelivery = false,
    this.images = const [],
    this.variants,
    this.stock = 100,
    this.category = 'Diğer',
    this.categorySortOrder = 999,
    this.promotionLabel,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json, {String? storeName, String? categoryName, int categorySortOrder = 999}) {
    // products tablosu merchant_id kullanıyor, store_products tablosu store_id kullanıyor
    final storeId = json['merchant_id'] as String? ?? json['store_id'] as String? ?? '';

    return StoreProduct(
      id: json['id'] as String,
      storeId: storeId,
      storeName: storeName ?? json['store_name'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      originalPrice: json['original_price'] != null ? (json['original_price'] as num).toDouble() : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      soldCount: json['sold_count'] as int? ?? 0,
      isFavorite: false,
      freeShipping: json['free_shipping'] as bool? ?? false,
      fastDelivery: json['fast_delivery'] as bool? ?? false,
      images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
      variants: null,
      stock: json['stock'] as int? ?? 100,
      category: categoryName ?? json['category'] as String? ?? 'Diğer',
      categorySortOrder: categorySortOrder,
      promotionLabel: json['promotion_label'] as String?,
    );
  }

  int? get discountPercent {
    if (originalPrice != null && originalPrice! > price) {
      return ((1 - price / originalPrice!) * 100).round();
    }
    return null;
  }

  String get formattedPrice => '₺${price.toStringAsFixed(2)}';
  String get formattedOriginalPrice =>
      originalPrice != null ? '₺${originalPrice!.toStringAsFixed(2)}' : '';

  String get formattedSoldCount {
    if (soldCount >= 10000) {
      return '${(soldCount / 1000).toStringAsFixed(0)}K+ satış';
    } else if (soldCount >= 1000) {
      return '${(soldCount / 1000).toStringAsFixed(1)}K satış';
    } else if (soldCount > 0) {
      return '$soldCount satış';
    }
    return '';
  }

  // Veriler Supabase'den yüklenir
  static List<StoreProduct> get mockProducts => [];

  static List<StoreProduct> get flashDeals => [];

  static List<StoreProduct> get bestSellers => [];

  static List<StoreProduct> get recommended => [];
}
