import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class Restaurant {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final double rating;
  final int reviewCount;
  final String deliveryTime;
  final double minOrderAmount;
  final double deliveryFee;
  final List<String> tags;
  final List<String> categoryTags;
  final String? discountBadge;
  final bool isActive;
  final bool isOpen;

  Restaurant({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.rating = 0,
    this.reviewCount = 0,
    this.deliveryTime = '30-45 dk',
    this.minOrderAmount = 0,
    this.deliveryFee = 0,
    this.tags = const [],
    this.categoryTags = const [],
    this.discountBadge,
    this.isActive = true,
    this.isOpen = true,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      deliveryTime: json['delivery_time'] as String? ?? '30-45 dk',
      minOrderAmount: double.tryParse(json['min_order_amount']?.toString() ?? '0') ?? 0,
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      categoryTags: (json['category_tags'] as List<dynamic>?)?.cast<String>() ?? [],
      discountBadge: json['discount_badge'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isOpen: json['is_open'] as bool? ?? true,
    );
  }

  // merchants tablosundan gelen veriyi parse et
  factory Restaurant.fromMerchantJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['business_name'] as String,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      deliveryTime: json['delivery_time'] as String? ?? '30-45 dk',
      minOrderAmount: double.tryParse(json['min_order_amount']?.toString() ?? '0') ?? 0,
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      categoryTags: (json['category_tags'] as List<dynamic>?)?.cast<String>() ?? [],
      discountBadge: json['discount_badge'] as String?,
      isActive: json['is_approved'] as bool? ?? true,
      isOpen: json['is_open'] as bool? ?? true,
    );
  }

  // FoodHomeScreen için uygun formata dönüştür
  Map<String, dynamic> toCardData() {
    return {
      'id': id,
      'name': name,
      'categories': categoryTags.join(', '),
      'rating': rating,
      'deliveryTime': deliveryTime,
      'minOrder': minOrderAmount > 0 ? '₺${minOrderAmount.toStringAsFixed(0)} min' : 'Min yok',
      'deliveryFee': deliveryFee > 0 ? '₺${deliveryFee.toStringAsFixed(2)}' : 'Ücretsiz',
      'discount': discountBadge,
      'imageUrl': coverUrl ?? logoUrl ?? '',
      'categoryTags': categoryTags,
    };
  }
}

class RestaurantCategory {
  final String id;
  final String name;
  final String? imageUrl;
  final String? icon;
  final int sortOrder;

  RestaurantCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.icon,
    this.sortOrder = 0,
  });

  factory RestaurantCategory.fromJson(Map<String, dynamic> json) {
    return RestaurantCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class MenuItem {
  final String id;
  final String merchantId;
  final String? category;
  final String name;
  final String? description;
  final double price;
  final double? discountedPrice;
  final String? imageUrl;
  final bool isAvailable;
  final bool isPopular;
  final int sortOrder;
  final int categorySortOrder;
  final bool hasOptionGroups; // Whether this item has required option groups

  MenuItem({
    required this.id,
    required this.merchantId,
    this.category,
    required this.name,
    this.description,
    required this.price,
    this.discountedPrice,
    this.imageUrl,
    this.isAvailable = true,
    this.isPopular = false,
    this.sortOrder = 0,
    this.categorySortOrder = 0,
    this.hasOptionGroups = false,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json, {String? categoryName, int? categorySortOrder, bool hasOptionGroups = false}) {
    return MenuItem(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String,
      category: categoryName ?? json['category'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      discountedPrice: json['discounted_price'] != null
          ? double.tryParse(json['discounted_price'].toString())
          : null,
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      isPopular: json['is_popular'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      categorySortOrder: categorySortOrder ?? json['category_sort_order'] as int? ?? 0,
      hasOptionGroups: hasOptionGroups,
    );
  }

  Map<String, dynamic> toOrderItem(int quantity) {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'total': price * quantity,
      'image_url': imageUrl,
    };
  }
}

class RestaurantService {
  static SupabaseClient get _client => SupabaseService.client;

  // Tüm restoranları getir (müşteri konumuna göre teslimat bölgesi filtreli)
  static Future<List<Restaurant>> getRestaurants({
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      // Müşteri konumu varsa, teslimat bölgesi içindeki restoranları getir
      if (customerLat != null && customerLon != null) {
        final deliveryRangeResponse = await _client
            .rpc('get_restaurants_in_delivery_range', params: {
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
            });

        final deliverableIds = (deliveryRangeResponse as List)
            .map((json) => json['merchant_id'] as String)
            .toList();

        if (deliverableIds.isEmpty) return [];

        final response = await _client
            .from('merchants')
            .select()
            .inFilter('id', deliverableIds)
            .eq('type', 'restaurant')
            .eq('is_approved', true)
            .eq('is_open', true)
            .order('rating', ascending: false);

        return (response as List)
            .map((json) => Restaurant.fromMerchantJson(json))
            .toList();
      }

      // Konum yoksa tüm restoranları getir
      final response = await _client
          .from('merchants')
          .select()
          .eq('type', 'restaurant')
          .eq('is_approved', true)
          .eq('is_open', true)
          .order('rating', ascending: false);

      return (response as List)
          .map((json) => Restaurant.fromMerchantJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching restaurants: $e');
      return [];
    }
  }

  // Restoran kategorilerini getir
  static Future<List<RestaurantCategory>> getCategories() async {
    try {
      final response = await _client
          .from('restaurant_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => RestaurantCategory.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching restaurant categories: $e');
      return [];
    }
  }

  // Kategoriye göre restoranları getir (menü kategorilerine göre filtreler)
  // Örn: "Kahvaltı" kategorisine tıklandığında, menüsünde Kahvaltı olan restoranlar listelenir
  static Future<List<Restaurant>> getRestaurantsByCategory(
    String categoryName, {
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      if (categoryName == 'Tümü' || categoryName.isEmpty) {
        return getRestaurants(customerLat: customerLat, customerLon: customerLon);
      }

      // Menü kategorisine göre restoran ID'lerini bul
      final categoryResponse = await _client
          .rpc('get_restaurants_by_menu_category', params: {
            'p_category_name': categoryName,
            'p_customer_lat': customerLat,
            'p_customer_lon': customerLon,
          });

      final merchantIds = (categoryResponse as List)
          .map((json) => json['merchant_id'] as String)
          .toList();

      if (merchantIds.isEmpty) return [];

      // Bu restoran ID'lerine göre detayları getir
      final response = await _client
          .from('merchants')
          .select()
          .inFilter('id', merchantIds)
          .order('rating', ascending: false);

      return (response as List)
          .map((json) => Restaurant.fromMerchantJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching restaurants by category: $e');
      return [];
    }
  }

  // Tek restoran getir
  static Future<Restaurant?> getRestaurantById(String id) async {
    try {
      final response = await _client
          .from('merchants')
          .select()
          .eq('id', id)
          .eq('type', 'restaurant')
          .single();

      return Restaurant.fromMerchantJson(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching restaurant: $e');
      return null;
    }
  }

  // Restoran menüsünü getir (merchant_id kullanarak)
  static Future<List<MenuItem>> getMenuItems(String merchantId) async {
    try {
      final response = await _client
          .from('menu_items')
          .select('*, menu_categories!category_id(name, sort_order), menu_item_option_groups(option_group_id)')
          .eq('merchant_id', merchantId)
          .eq('is_available', true)
          .order('sort_order');

      return (response as List).map((json) {
        final categoryData = json['menu_categories'];
        final categoryName = categoryData?['name'] as String?;
        final categorySortOrder = categoryData?['sort_order'] as int? ?? 999;

        // Check if item has option groups
        final optionGroupLinks = json['menu_item_option_groups'] as List?;
        final hasOptionGroups = optionGroupLinks != null && optionGroupLinks.isNotEmpty;

        return MenuItem.fromJson(
          json,
          categoryName: categoryName,
          categorySortOrder: categorySortOrder,
          hasOptionGroups: hasOptionGroups,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching menu items: $e');
      return [];
    }
  }

  // Restoran ara (müşteri konumuna göre teslimat bölgesi filtreli)
  static Future<List<Restaurant>> searchRestaurants(
    String query, {
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      // Müşteri konumu varsa, teslimat bölgesi içindeki restoranları getir
      if (customerLat != null && customerLon != null) {
        final deliveryRangeResponse = await _client
            .rpc('get_restaurants_in_delivery_range', params: {
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
            });

        final deliverableIds = (deliveryRangeResponse as List)
            .map((json) => json['merchant_id'] as String)
            .toList();

        if (deliverableIds.isEmpty) return [];

        final response = await _client
            .from('merchants')
            .select()
            .inFilter('id', deliverableIds)
            .eq('type', 'restaurant')
            .eq('is_approved', true)
            .or('business_name.ilike.%$query%,description.ilike.%$query%')
            .order('rating', ascending: false)
            .limit(20);

        return (response as List)
            .map((json) => Restaurant.fromMerchantJson(json))
            .toList();
      }

      final response = await _client
          .from('merchants')
          .select()
          .eq('type', 'restaurant')
          .eq('is_approved', true)
          .or('business_name.ilike.%$query%,description.ilike.%$query%')
          .order('rating', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => Restaurant.fromMerchantJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error searching restaurants: $e');
      return [];
    }
  }

  // Popüler restoranları getir (müşteri konumuna göre teslimat bölgesi filtreli)
  static Future<List<Restaurant>> getPopularRestaurants({
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      // Müşteri konumu varsa, teslimat bölgesi içindeki restoranları getir
      if (customerLat != null && customerLon != null) {
        final deliveryRangeResponse = await _client
            .rpc('get_restaurants_in_delivery_range', params: {
              'p_customer_lat': customerLat,
              'p_customer_lon': customerLon,
            });

        final deliverableIds = (deliveryRangeResponse as List)
            .map((json) => json['merchant_id'] as String)
            .toList();

        if (deliverableIds.isEmpty) return [];

        final response = await _client
            .from('merchants')
            .select()
            .inFilter('id', deliverableIds)
            .eq('type', 'restaurant')
            .eq('is_approved', true)
            .eq('is_open', true)
            .gte('rating', 4.0)
            .order('review_count', ascending: false)
            .limit(10);

        return (response as List)
            .map((json) => Restaurant.fromMerchantJson(json))
            .toList();
      }

      final response = await _client
          .from('merchants')
          .select()
          .eq('type', 'restaurant')
          .eq('is_approved', true)
          .eq('is_open', true)
          .gte('rating', 4.0)
          .order('review_count', ascending: false)
          .limit(10);

      return (response as List)
          .map((json) => Restaurant.fromMerchantJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching popular restaurants: $e');
      return [];
    }
  }

  // Sipariş oluştur
  static Future<String?> createOrder({
    required String merchantId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double deliveryFee,
    required double totalAmount,
    required String deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? customerName,
    String? customerPhone,
    String? deliveryInstructions,
    String? paymentMethod,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // Merchant tipini al ve ilgili komisyon oranını çek
      double? commissionRate;
      try {
        // Merchant tipini al
        final merchantData = await _client
            .from('merchants')
            .select('type')
            .eq('id', merchantId)
            .maybeSingle();

        if (merchantData != null) {
          final merchantType = merchantData['type'] as String? ?? 'restaurant';

          // Platform komisyon oranını al
          final commissionData = await _client
              .from('platform_commissions')
              .select('platform_commission_rate')
              .eq('service_type', merchantType)
              .eq('is_active', true)
              .maybeSingle();

          if (commissionData != null) {
            commissionRate = double.tryParse(
              commissionData['platform_commission_rate']?.toString() ?? ''
            );
          }
        }
      } catch (e) {
        if (kDebugMode) print('Error fetching commission rate: $e');
      }

      final response = await _client.from('orders').insert({
        'order_number': orderNumber,
        'user_id': userId,
        'merchant_id': merchantId,
        'items': items,
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'total_amount': totalAmount,
        'delivery_address': deliveryAddress,
        'delivery_latitude': deliveryLatitude,
        'delivery_longitude': deliveryLongitude,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'delivery_instructions': deliveryInstructions,
        'payment_method': paymentMethod ?? 'cash',
        'status': 'pending',
        'payment_status': 'pending',
        'commission_rate': commissionRate,
      }).select('id').single();

      return response['id'] as String;
    } catch (e) {
      if (kDebugMode) print('Error creating order: $e');
      return null;
    }
  }

  // Kullanıcının siparişlerini getir
  static Future<List<Map<String, dynamic>>> getUserOrders() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('orders')
          .select('*, merchants!inner(business_name, logo_url)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching user orders: $e');
      return [];
    }
  }

  /// Merchant çalışma saatlerini kontrol et
  static Future<({bool isOpen, String? message, String? openTime, String? closeTime})> checkMerchantWorkingHours(String merchantId) async {
    try {
      // Mevcut gün (0 = Pazartesi, 6 = Pazar)
      final now = DateTime.now();
      int dayOfWeek = now.weekday - 1; // Dart'ta 1 = Pazartesi, biz 0 = Pazartesi istiyoruz

      // Çalışma saatlerini al
      final response = await _client
          .from('merchant_working_hours')
          .select()
          .eq('merchant_id', merchantId)
          .eq('day_of_week', dayOfWeek)
          .maybeSingle();

      if (response == null) {
        return (isOpen: false, message: 'Bugün için çalışma saati tanımlı değil', openTime: null, closeTime: null);
      }

      final isOpen = response['is_open'] as bool? ?? false;
      final openTimeStr = response['open_time'] as String?;
      final closeTimeStr = response['close_time'] as String?;

      if (!isOpen) {
        return (isOpen: false, message: 'Restoran bugün kapalı', openTime: openTimeStr, closeTime: closeTimeStr);
      }

      if (openTimeStr == null || closeTimeStr == null) {
        return (isOpen: false, message: 'Çalışma saatleri tanımlı değil', openTime: null, closeTime: null);
      }

      // Saat kontrolü
      final nowTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final openTime = openTimeStr.substring(0, 5); // "HH:mm" formatına çevir
      final closeTime = closeTimeStr.substring(0, 5);

      if (nowTime.compareTo(openTime) < 0) {
        return (isOpen: false, message: 'Restoran henüz açılmadı. Açılış: $openTime', openTime: openTime, closeTime: closeTime);
      }

      if (nowTime.compareTo(closeTime) > 0) {
        return (isOpen: false, message: 'Restoran kapandı. Kapanış: $closeTime', openTime: openTime, closeTime: closeTime);
      }

      return (isOpen: true, message: null, openTime: openTime, closeTime: closeTime);
    } catch (e) {
      if (kDebugMode) print('Error checking working hours: $e');
      // Hata durumunda siparişe izin ver, server-side kontrol yapacak
      return (isOpen: true, message: null, openTime: null, closeTime: null);
    }
  }
}
