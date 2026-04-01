import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/cache_helper.dart';
import 'package:super_app/core/services/log_service.dart';

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
  static final _cache = CacheManager();

  // Tüm restoranları getir (müşteri konumuna göre teslimat bölgesi filtreli)
  static Future<List<Restaurant>> getRestaurants({
    double? customerLat,
    double? customerLon,
  }) async {
    final cacheKey = customerLat != null && customerLon != null
        ? 'restaurants_${customerLat.toStringAsFixed(3)}_${customerLon.toStringAsFixed(3)}'
        : 'restaurants_all';

    return _cache.getOrFetch<List<Restaurant>>(
      cacheKey,
      ttl: const Duration(minutes: 2),
      fetcher: () async {
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
        } catch (e, st) {
          LogService.error('Error fetching restaurants', error: e, stackTrace: st, source: 'RestaurantService:getRestaurants');
          return [];
        }
      },
    );
  }

  // Restoran kategorilerini getir
  static Future<List<RestaurantCategory>> getCategories() async {
    return _cache.getOrFetch<List<RestaurantCategory>>(
      'restaurant_categories',
      ttl: const Duration(hours: 24),
      fetcher: () async {
        try {
          final response = await _client
              .from('restaurant_categories')
              .select()
              .eq('is_active', true)
              .order('sort_order');

          return (response as List)
              .map((json) => RestaurantCategory.fromJson(json))
              .toList();
        } catch (e, st) {
          LogService.error('Error fetching restaurant categories', error: e, stackTrace: st, source: 'RestaurantService:getCategories');
          return [];
        }
      },
    );
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
    } catch (e, st) {
      LogService.error('Error fetching restaurants by category', error: e, stackTrace: st, source: 'RestaurantService:getRestaurantsByCategory');
      return [];
    }
  }

  // Tek restoran getir
  static Future<Restaurant?> getRestaurantById(String id) async {
    return _cache.getOrFetch<Restaurant?>(
      'restaurant_$id',
      ttl: const Duration(minutes: 5),
      fetcher: () async {
        try {
          final response = await _client
              .from('merchants')
              .select()
              .eq('id', id)
              .eq('type', 'restaurant')
              .single();

          return Restaurant.fromMerchantJson(response);
        } catch (e, st) {
          LogService.error('Error fetching restaurant', error: e, stackTrace: st, source: 'RestaurantService:getRestaurantById');
          return null;
        }
      },
    );
  }

  // Restoran menüsünü getir (merchant_id kullanarak)
  static Future<List<MenuItem>> getMenuItems(String merchantId) async {
    return _cache.getOrFetch<List<MenuItem>>(
      'menu_items_$merchantId',
      ttl: const Duration(minutes: 5),
      fetcher: () async {
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
        } catch (e, st) {
          LogService.error('Error fetching menu items', error: e, stackTrace: st, source: 'RestaurantService:getMenuItems');
          return [];
        }
      },
    );
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
            .ilike('business_name', '%$query%')
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
          .ilike('business_name', '%$query%')
          .order('rating', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => Restaurant.fromMerchantJson(json))
          .toList();
    } catch (e, st) {
      LogService.error('Error searching restaurants', error: e, stackTrace: st, source: 'RestaurantService:searchRestaurants');
      return [];
    }
  }

  // Yemek ara (menu_items tablosunda)
  static Future<List<Map<String, dynamic>>> searchMenuItems(String query) async {
    try {
      final response = await _client
          .from('menu_items')
          .select('id, name, description, price, image_url, merchant_id, merchants!inner(business_name, rating)')
          .eq('is_available', true)
          .ilike('name', '%$query%')
          .order('name')
          .limit(10);

      return (response as List).map((json) {
        final merchant = json['merchants'] as Map<String, dynamic>?;
        return {
          'id': json['id'] as String,
          'name': json['name'] as String,
          'description': json['description'] as String? ?? '',
          'price': double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
          'imageUrl': json['image_url'] as String? ?? '',
          'rating': (merchant?['rating'] as num?)?.toDouble() ?? 4.5,
          'merchantId': json['merchant_id'] as String,
          'restaurantName': merchant?['business_name'] as String? ?? '',
        };
      }).toList();
    } catch (e, st) {
      LogService.error('Error searching menu items', error: e, stackTrace: st, source: 'RestaurantService:searchMenuItems');
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
    } catch (e, st) {
      LogService.error('Error fetching popular restaurants', error: e, stackTrace: st, source: 'RestaurantService:getPopularRestaurants');
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
      String? storeName;
      try {
        // Merchant tipini ve adını al
        final merchantData = await _client
            .from('merchants')
            .select('type, business_name')
            .eq('id', merchantId)
            .maybeSingle();

        if (merchantData != null) {
          storeName = merchantData['business_name'] as String?;
          final merchantType = merchantData['type'] as String? ?? 'restaurant';

          // Önce merchant-specific override kontrol et
          final overrideData = await _client
              .from('merchant_commission_overrides')
              .select('custom_rate')
              .eq('merchant_id', merchantId)
              .maybeSingle();

          if (overrideData != null) {
            commissionRate = double.tryParse(
              overrideData['custom_rate']?.toString() ?? ''
            );
          } else {
            // Sektör bazlı varsayılan komisyon oranını al
            const sectorMap = {
              'restaurant': 'food',
              'store': 'store',
              'market': 'market',
              'taxi': 'taxi',
            };
            final sector = sectorMap[merchantType] ?? 'food';
            final sectorData = await _client
                .from('commission_rates')
                .select('default_rate')
                .eq('sector', sector)
                .eq('is_active', true)
                .maybeSingle();

            if (sectorData != null) {
              commissionRate = double.tryParse(
                sectorData['default_rate']?.toString() ?? ''
              );
            } else {
              commissionRate = 10.0; // Fallback
            }
          }
        }
      } catch (e, st) {
        LogService.error('Error fetching commission rate', error: e, stackTrace: st, source: 'RestaurantService:createOrder');
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
        'status': paymentMethod == 'online' ? 'awaiting_payment' : 'pending',
        'payment_status': paymentMethod == 'online' ? 'awaiting' : 'pending',
        'commission_rate': commissionRate,
        'store_name': storeName,
      }).select('id').single();

      return response['id'] as String;
    } catch (e, st) {
      LogService.error('Error creating order', error: e, stackTrace: st, source: 'RestaurantService:createOrder');
      throw Exception('Sipariş oluşturulamadı: $e');
    }
  }

  /// Online ödeme onaylandıktan sonra sipariş ödeme durumunu güncelle.
  static Future<void> updateOrderPaymentStatus(String orderId, String status) async {
    try {
      final update = <String, dynamic>{'payment_status': status};
      // Ödeme onaylandıysa siparişi merchant'a göster
      if (status == 'paid') {
        update['status'] = 'pending';
      }
      await _client.from('orders').update(update).eq('id', orderId);
    } catch (e, st) {
      LogService.error('Error updating order payment status', error: e, stackTrace: st, source: 'RestaurantService:updateOrderPaymentStatus');
    }
  }

  /// Online ödeme başarısız olduğunda bekleyen siparişi iptal et.
  static Future<void> cancelOrder(String orderId) async {
    try {
      await _client.from('orders').update({
        'status': 'cancelled',
        'payment_status': 'failed',
      }).eq('id', orderId);
    } catch (e, st) {
      LogService.error('Error cancelling order', error: e, stackTrace: st, source: 'RestaurantService:cancelOrder');
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
    } catch (e, st) {
      LogService.error('Error fetching user orders', error: e, stackTrace: st, source: 'RestaurantService:getUserOrders');
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
    } catch (e, st) {
      LogService.error('Error checking working hours', error: e, stackTrace: st, source: 'RestaurantService:isRestaurantOpen');
      return (isOpen: false, message: 'Çalışma saatleri alınamadı', openTime: null, closeTime: null);
    }
  }

  // Tüm aktif menü kategorilerini getir (filtre seçenekleri için)
  static Future<List<String>> getAvailableMenuCategories() async {
    return _cache.getOrFetch<List<String>>(
      'available_menu_categories',
      ttl: const Duration(hours: 24),
      fetcher: () async {
        try {
          final response = await _client
              .from('menu_categories')
              .select('name')
              .eq('is_active', true)
              .order('name');

          final categories = (response as List)
              .map((json) => json['name'] as String)
              .toSet() // Tekrarları kaldır
              .toList();

          // Kategorileri düzenli sırala
          categories.sort((a, b) => a.compareTo(b));

          return categories;
        } catch (e, st) {
          LogService.error('Error fetching menu categories', error: e, stackTrace: st, source: 'RestaurantService:getMenuCategories');
          return [];
        }
      },
    );
  }

  /// Realtime invalidation: merchants tablosu değiştiğinde çağır
  static void invalidateRestaurants() {
    _cache.invalidatePrefix('restaurant_');
    _cache.invalidate('popular_restaurants');
  }

  /// Realtime invalidation: menu_items tablosu değiştiğinde çağır
  static void invalidateMenuItems([String? merchantId]) {
    if (merchantId != null) {
      _cache.invalidate('menu_items_$merchantId');
    } else {
      _cache.invalidatePrefix('menu_items_');
    }
  }

  // Menü kategorisine göre restoran ID'lerini getir
  static Future<List<String>> getRestaurantIdsByMenuCategory(
    String categoryName, {
    double? customerLat,
    double? customerLon,
  }) async {
    try {
      // Önce kategori adına göre merchant_id'leri bul
      final categoryResponse = await _client
          .from('menu_categories')
          .select('merchant_id')
          .ilike('name', '%$categoryName%')
          .eq('is_active', true);

      final merchantIds = (categoryResponse as List)
          .map((json) => json['merchant_id'] as String)
          .toSet()
          .toList();

      if (merchantIds.isEmpty) return [];

      // Bu merchant'ların restoran ID'lerini bul
      final restaurantResponse = await _client
          .from('merchants')
          .select('id')
          .inFilter('id', merchantIds)
          .eq('type', 'restaurant')
          .eq('is_approved', true);

      return (restaurantResponse as List)
          .map((json) => json['id'] as String)
          .toList();
    } catch (e, st) {
      LogService.error('Error fetching restaurants by menu category', error: e, stackTrace: st, source: 'RestaurantService:getRestaurantsByMenuCategory');
      return [];
    }
  }

  /// Sepetteki ürünlerle birlikte en çok satın alınan ürünleri getirir
  static Future<List<MenuItem>> getFrequentlyBoughtTogether(
    String merchantId,
    List<String> cartItemIds, {
    int limit = 6,
  }) async {
    final cacheKey = 'fbt_${merchantId}_${cartItemIds.join(',')}';
    return _cache.getOrFetch<List<MenuItem>>(
      cacheKey,
      ttl: const Duration(minutes: 10),
      fetcher: () async {
        try {
          final response = await _client.rpc(
            'get_frequently_bought_together',
            params: {
              'p_merchant_id': merchantId,
              'p_cart_item_ids': cartItemIds,
              'p_limit': limit,
            },
          );

          if (response == null) return [];

          return (response as List).map((json) {
            final map = json as Map<String, dynamic>;
            return MenuItem(
              id: map['id'] as String,
              merchantId: merchantId,
              name: map['name'] as String,
              description: map['description'] as String?,
              price: double.tryParse(map['price']?.toString() ?? '0') ?? 0,
              discountedPrice: map['discounted_price'] != null
                  ? double.tryParse(map['discounted_price'].toString())
                  : null,
              imageUrl: map['image_url'] as String?,
              category: map['category'] as String?,
            );
          }).toList();
        } catch (e, st) {
          LogService.error('Error fetching frequently bought together', error: e, stackTrace: st, source: 'RestaurantService:getFrequentlyBoughtTogether');
          return [];
        }
      },
    );
  }
}
