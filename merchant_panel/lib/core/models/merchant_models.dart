import 'package:flutter/material.dart';

// Merchant Types
enum MerchantType {
  restaurant,
  store,
}

extension MerchantTypeExtension on MerchantType {
  String get displayName {
    switch (this) {
      case MerchantType.restaurant:
        return 'Restoran';
      case MerchantType.store:
        return 'Magaza';
    }
  }

  IconData get icon {
    switch (this) {
      case MerchantType.restaurant:
        return Icons.restaurant;
      case MerchantType.store:
        return Icons.store;
    }
  }
}

// Order Status
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  delivering,
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Bekliyor';
      case OrderStatus.confirmed:
        return 'Onaylandi';
      case OrderStatus.preparing:
        return 'Hazirlaniyor';
      case OrderStatus.ready:
        return 'Hazir';
      case OrderStatus.pickedUp:
        return 'Alindi';
      case OrderStatus.delivering:
        return 'Yolda';
      case OrderStatus.delivered:
        return 'Teslim Edildi';
      case OrderStatus.cancelled:
        return 'Iptal';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF3B82F6);
      case OrderStatus.preparing:
        return const Color(0xFF8B5CF6);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.pickedUp:
        return const Color(0xFF06B6D4);
      case OrderStatus.delivering:
        return const Color(0xFF6366F1);
      case OrderStatus.delivered:
        return const Color(0xFF22C55E);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.soup_kitchen;
      case OrderStatus.ready:
        return Icons.done_all;
      case OrderStatus.pickedUp:
        return Icons.delivery_dining;
      case OrderStatus.delivering:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String get value {
    return toString().split('.').last;
  }

  // Database'deki snake_case değeri döndürür
  String get dbValue {
    switch (this) {
      case OrderStatus.pickedUp:
        return 'picked_up';
      default:
        return value;
    }
  }

  static OrderStatus fromString(String status) {
    // snake_case'i destekle (veritabanı değerleri)
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'picked_up':
      case 'pickedUp':
        return OrderStatus.pickedUp;
      case 'delivering':
        return OrderStatus.delivering;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

// Merchant Model
class Merchant {
  final String id;
  final String userId;
  final MerchantType type;
  final String? businessId;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? phone;
  final String? email;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int totalOrders;
  final int totalReviews;
  final bool isOpen;
  final bool isApproved;
  final double commissionRate;
  final double minOrderAmount;
  final double deliveryFee;
  final String deliveryTime;
  final List<String> categoryTags;
  final DateTime createdAt;

  Merchant({
    required this.id,
    required this.userId,
    required this.type,
    this.businessId,
    required this.businessName,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.phone,
    this.email,
    this.address,
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalReviews = 0,
    this.isOpen = true,
    this.isApproved = false,
    this.commissionRate = 15.0,
    this.minOrderAmount = 0,
    this.deliveryFee = 0,
    this.deliveryTime = '30-45 dk',
    this.categoryTags = const [],
    required this.createdAt,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'],
      userId: json['user_id'] ?? '',
      type: json['type'] == 'restaurant' ? MerchantType.restaurant : MerchantType.store,
      businessId: json['business_id'],
      businessName: json['business_name'] ?? '',
      description: json['description'],
      logoUrl: json['logo_url'],
      coverUrl: json['cover_url'],
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      totalOrders: json['total_orders'] ?? 0,
      totalReviews: json['review_count'] ?? json['total_reviews'] ?? 0,
      isOpen: json['is_open'] ?? true,
      isApproved: json['is_approved'] ?? false,
      commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '15') ?? 15,
      minOrderAmount: double.tryParse(json['min_order_amount']?.toString() ?? '0') ?? 0,
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0,
      deliveryTime: json['delivery_time'] ?? '30-45 dk',
      categoryTags: (json['category_tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'type': type.value,
    'business_id': businessId,
    'business_name': businessName,
    'description': description,
    'logo_url': logoUrl,
    'cover_url': coverUrl,
    'phone': phone,
    'email': email,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'rating': rating,
    'total_orders': totalOrders,
    'review_count': totalReviews,
    'is_open': isOpen,
    'is_approved': isApproved,
    'commission_rate': commissionRate,
    'min_order_amount': minOrderAmount,
    'delivery_fee': deliveryFee,
    'delivery_time': deliveryTime,
    'category_tags': categoryTags,
  };

  bool get isOnline => isOpen;

  Merchant copyWith({
    String? id,
    String? userId,
    MerchantType? type,
    String? businessId,
    String? businessName,
    String? description,
    String? logoUrl,
    String? coverUrl,
    String? phone,
    String? email,
    String? address,
    double? latitude,
    double? longitude,
    double? rating,
    int? totalOrders,
    int? totalReviews,
    bool? isOpen,
    bool? isOnline,
    bool? isApproved,
    double? commissionRate,
    double? minOrderAmount,
    double? deliveryFee,
    String? deliveryTime,
    List<String>? categoryTags,
    DateTime? createdAt,
  }) {
    return Merchant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      totalReviews: totalReviews ?? this.totalReviews,
      isOpen: isOnline ?? isOpen ?? this.isOpen,
      isApproved: isApproved ?? this.isApproved,
      commissionRate: commissionRate ?? this.commissionRate,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      categoryTags: categoryTags ?? this.categoryTags,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

extension MerchantTypeValue on MerchantType {
  String get value {
    return toString().split('.').last;
  }
}

// Order Model
class Order {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAvatar;
  final String merchantId;
  final String? courierId;
  final String? courierName;
  final String? deliveryStatus; // 'pending', 'searching', 'assigned', 'picked_up', 'delivering', 'delivered'
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final double total;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? deliveryInstructions;
  final String paymentMethod;
  final String paymentStatus;
  final OrderStatus status;
  final DateTime? estimatedDelivery;
  final DateTime? confirmedAt;
  final DateTime? preparedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerAvatar,
    required this.merchantId,
    this.courierId,
    this.courierName,
    this.deliveryStatus,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.discount,
    required this.total,
    required this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryInstructions,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    this.estimatedDelivery,
    this.confirmedAt,
    this.preparedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      customerId: json['user_id'] ?? json['customer_id'],
      customerName: json['users']?['full_name'] ?? json['customer_name'] ?? 'Musteri',
      customerPhone: json['users']?['phone'] ?? json['customer_phone'],
      customerAvatar: json['users']?['avatar_url'],
      merchantId: json['merchant_id'] ?? json['restaurant_id'] ?? json['store_id'],
      courierId: json['courier_id'],
      courierName: json['courier']?['full_name'],
      deliveryStatus: json['delivery_status'],
      items: (json['items'] as List?)?.map((e) => OrderItem.fromJson(e)).toList() ?? [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0).toDouble(),
      serviceFee: (json['service_fee'] ?? 0).toDouble(),
      discount: (json['discount_amount'] ?? 0).toDouble(),
      total: (json['total_amount'] ?? json['total'] ?? 0).toDouble(),
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryLat: json['delivery_latitude']?.toDouble(),
      deliveryLng: json['delivery_longitude']?.toDouble(),
      deliveryInstructions: json['delivery_instructions'],
      paymentMethod: json['payment_method'] ?? 'card',
      paymentStatus: json['payment_status'] ?? 'pending',
      status: OrderStatusExtension.fromString(json['status'] ?? 'pending'),
      estimatedDelivery: json['estimated_delivery_time'] != null
          ? DateTime.parse(json['estimated_delivery_time'])
          : null,
      confirmedAt: json['confirmed_at'] != null ? DateTime.parse(json['confirmed_at']) : null,
      preparedAt: json['prepared_at'] != null ? DateTime.parse(json['prepared_at']) : null,
      pickedUpAt: json['picked_up_at'] != null ? DateTime.parse(json['picked_up_at']) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      cancellationReason: json['cancellation_reason'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  // Kurye atandı mı kontrol et (assigned, picked_up, delivering durumlarında true)
  bool get hasCourierAssigned => courierId != null &&
      (deliveryStatus == 'assigned' ||
       deliveryStatus == 'picked_up' ||
       deliveryStatus == 'delivering');

  Duration get waitingTime => DateTime.now().difference(createdAt);

  String get waitingTimeText {
    final minutes = waitingTime.inMinutes;
    if (minutes < 1) return 'Simdi';
    if (minutes < 60) return '$minutes dk';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}s ${remainingMinutes}dk';
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerAvatar,
    String? merchantId,
    String? courierId,
    String? courierName,
    String? deliveryStatus,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? serviceFee,
    double? discount,
    double? total,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryInstructions,
    String? paymentMethod,
    String? paymentStatus,
    OrderStatus? status,
    DateTime? estimatedDelivery,
    DateTime? confirmedAt,
    DateTime? preparedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? createdAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      merchantId: merchantId ?? this.merchantId,
      courierId: courierId ?? this.courierId,
      courierName: courierName ?? this.courierName,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      serviceFee: serviceFee ?? this.serviceFee,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      status: status ?? this.status,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      preparedAt: preparedAt ?? this.preparedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Order Item Model
class OrderItem {
  final String id;
  final String name;
  final String? imageUrl;
  final int quantity;
  final double price;
  final double total;
  final String? notes;
  final List<String>? options;

  OrderItem({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.price,
    required this.total,
    this.notes,
    this.options,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? json['item_id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
      total: (json['total'] ?? (json['price'] ?? 0) * (json['quantity'] ?? 1)).toDouble(),
      notes: json['notes'],
      options: (json['options'] as List?)?.cast<String>(),
    );
  }
}

// Menu Category Model
class MenuCategory {
  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final int itemCount;

  MenuCategory({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    this.imageUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.itemCount = 0,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      itemCount: json['item_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'restaurant_id': restaurantId,
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'sort_order': sortOrder,
    'is_active': isActive,
  };
}

// Menu Item Model
class MenuItem {
  final String id;
  final String merchantId;
  final String? category;
  final String name;
  final String? description;
  final double price;
  final double? discountedPrice;
  final String? imageUrl;
  final int sortOrder;
  final bool isAvailable;
  final bool isPopular;
  final List<MenuItemOption>? options;
  final DateTime? createdAt;

  MenuItem({
    required this.id,
    required this.merchantId,
    this.category,
    required this.name,
    this.description,
    required this.price,
    this.discountedPrice,
    this.imageUrl,
    this.sortOrder = 0,
    this.isAvailable = true,
    this.isPopular = false,
    this.options,
    this.createdAt,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      merchantId: json['merchant_id'] ?? json['restaurant_id'] ?? '',
      category: json['category'] ?? json['category_id'],
      name: json['name'] ?? '',
      description: json['description'],
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      discountedPrice: json['discounted_price'] != null
          ? double.tryParse(json['discounted_price'].toString())
          : null,
      imageUrl: json['image_url'],
      sortOrder: json['sort_order'] ?? 0,
      isAvailable: json['is_available'] ?? true,
      isPopular: json['is_popular'] ?? false,
      options: json['options'] != null
          ? (json['options'] as List).map((e) => MenuItemOption.fromJson(e)).toList()
          : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'merchant_id': merchantId,
    'category': category,
    'name': name,
    'description': description,
    'price': price,
    'discounted_price': discountedPrice,
    'image_url': imageUrl,
    'sort_order': sortOrder,
    'is_available': isAvailable,
    'is_popular': isPopular,
  };

  double get effectivePrice => discountedPrice ?? price;
  bool get hasDiscount => discountedPrice != null && discountedPrice! < price;
  double get discountPercent => hasDiscount ? ((price - discountedPrice!) / price * 100) : 0;

  // Backwards compatibility
  String get restaurantId => merchantId;
  String get categoryId => category ?? '';
  int get preparationTime => 15;

  MenuItem copyWith({
    String? id,
    String? merchantId,
    String? restaurantId,
    String? category,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    double? discountedPrice,
    String? imageUrl,
    int? sortOrder,
    int? preparationTime,
    bool? isAvailable,
    bool? isPopular,
    List<MenuItemOption>? options,
    DateTime? createdAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      merchantId: merchantId ?? restaurantId ?? this.merchantId,
      category: category ?? categoryId ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isAvailable: isAvailable ?? this.isAvailable,
      isPopular: isPopular ?? this.isPopular,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Menu Item Option
class MenuItemOption {
  final String name;
  final List<MenuItemOptionValue> values;
  final bool isRequired;
  final bool isMultiple;

  MenuItemOption({
    required this.name,
    required this.values,
    this.isRequired = false,
    this.isMultiple = false,
  });

  factory MenuItemOption.fromJson(Map<String, dynamic> json) {
    return MenuItemOption(
      name: json['name'],
      values: (json['values'] as List).map((e) => MenuItemOptionValue.fromJson(e)).toList(),
      isRequired: json['is_required'] ?? false,
      isMultiple: json['is_multiple'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'values': values.map((e) => e.toJson()).toList(),
    'is_required': isRequired,
    'is_multiple': isMultiple,
  };
}

class MenuItemOptionValue {
  final String name;
  final double price;

  MenuItemOptionValue({required this.name, this.price = 0});

  factory MenuItemOptionValue.fromJson(Map<String, dynamic> json) {
    return MenuItemOptionValue(
      name: json['name'],
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
  };
}

// Unit types for store products
enum UnitType {
  adet,
  kg,
  gram,
  litre,
  ml,
}

extension UnitTypeExtension on UnitType {
  String get displayName {
    switch (this) {
      case UnitType.adet:
        return 'Adet';
      case UnitType.kg:
        return 'Kilogram (kg)';
      case UnitType.gram:
        return 'Gram (g)';
      case UnitType.litre:
        return 'Litre (L)';
      case UnitType.ml:
        return 'Mililitre (ml)';
    }
  }

  String get shortName {
    switch (this) {
      case UnitType.adet:
        return 'adet';
      case UnitType.kg:
        return 'kg';
      case UnitType.gram:
        return 'g';
      case UnitType.litre:
        return 'L';
      case UnitType.ml:
        return 'ml';
    }
  }

  String get value => toString().split('.').last;

  static UnitType fromString(String? value) {
    if (value == null) return UnitType.adet;
    return UnitType.values.firstWhere(
      (e) => e.value == value || e.shortName == value,
      orElse: () => UnitType.adet,
    );
  }
}

// Store Product Model
class StoreProduct {
  final String id;
  final String storeId;
  final String? categoryId;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final String? imageUrl;
  final List<String>? images;
  final int stock;
  final int soldCount;
  final double rating;
  final int reviewCount;
  final bool isAvailable;
  final bool isFeatured;
  final String? sku;
  final String? barcode;
  final double? weight;
  final UnitType unitType;
  final int lowStockThreshold;
  final String? brand;
  final List<ProductVariant>? variants;
  final DateTime createdAt;

  StoreProduct({
    required this.id,
    required this.storeId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    this.images,
    this.stock = 0,
    this.soldCount = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.isAvailable = true,
    this.isFeatured = false,
    this.sku,
    this.barcode,
    this.weight,
    this.unitType = UnitType.adet,
    this.lowStockThreshold = 5,
    this.brand,
    this.variants,
    required this.createdAt,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      id: json['id'],
      storeId: json['merchant_id'] ?? json['store_id'],
      categoryId: json['category_id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      originalPrice: json['original_price']?.toDouble(),
      imageUrl: json['image_url'],
      images: (json['images'] as List?)?.cast<String>(),
      stock: json['stock'] ?? 0,
      soldCount: json['sold_count'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      isAvailable: json['is_available'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      sku: json['sku'],
      barcode: json['barcode'],
      weight: json['weight']?.toDouble(),
      unitType: UnitTypeExtension.fromString(json['weight_unit']),
      lowStockThreshold: json['low_stock_threshold'] ?? 5,
      brand: json['brand'],
      variants: json['variants'] != null
          ? (json['variants'] as List).map((e) => ProductVariant.fromJson(e)).toList()
          : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant_id': storeId,
    if (categoryId != null && categoryId!.isNotEmpty) 'category_id': categoryId,
    'name': name,
    'description': description,
    'price': price,
    'original_price': originalPrice,
    'image_url': imageUrl,
    'images': images,
    'stock': stock,
    'sold_count': soldCount,
    'rating': rating,
    'review_count': reviewCount,
    'is_available': isAvailable,
    'is_featured': isFeatured,
    'sku': sku,
    'barcode': barcode,
    'weight': weight,
    'weight_unit': unitType.value,
    'low_stock_threshold': lowStockThreshold,
    'brand': brand,
    'variants': variants?.map((e) => e.toJson()).toList(),
  };

  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  double get discountPercent => hasDiscount ? ((originalPrice! - price) / originalPrice! * 100) : 0;
  bool get isLowStock => stock > 0 && stock <= lowStockThreshold;
  bool get isOutOfStock => stock <= 0;

  int get stockQuantity => stock;

  StoreProduct copyWith({
    String? id,
    String? storeId,
    String? categoryId,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? imageUrl,
    List<String>? images,
    int? stock,
    int? stockQuantity,
    int? soldCount,
    double? rating,
    int? reviewCount,
    bool? isAvailable,
    bool? isFeatured,
    String? sku,
    String? barcode,
    double? weight,
    UnitType? unitType,
    int? lowStockThreshold,
    String? brand,
    List<ProductVariant>? variants,
    DateTime? createdAt,
  }) {
    return StoreProduct(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      stock: stockQuantity ?? stock ?? this.stock,
      soldCount: soldCount ?? this.soldCount,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      weight: weight ?? this.weight,
      unitType: unitType ?? this.unitType,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      brand: brand ?? this.brand,
      variants: variants ?? this.variants,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ProductVariant {
  final String name;
  final String value;
  final double? priceModifier;
  final int? stock;

  ProductVariant({
    required this.name,
    required this.value,
    this.priceModifier,
    this.stock,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      name: json['name'],
      value: json['value'],
      priceModifier: json['price_modifier']?.toDouble(),
      stock: json['stock'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'price_modifier': priceModifier,
    'stock': stock,
  };
}

// Review Model
class Review {
  final String id;
  final String orderId;
  final String customerId;
  final String customerName;
  final String? customerAvatar;
  final int rating;
  final String? comment;
  final String? reply;
  final DateTime? repliedAt;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    this.customerAvatar,
    required this.rating,
    this.comment,
    this.reply,
    this.repliedAt,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      orderId: json['order_id'],
      customerId: json['customer_id'] ?? json['user_id'],
      customerName: json['users']?['full_name'] ?? json['customer_name'] ?? 'Musteri',
      customerAvatar: json['users']?['avatar_url'],
      rating: json['rating'] ?? 5,
      comment: json['comment'],
      reply: json['reply'],
      repliedAt: json['replied_at'] != null ? DateTime.parse(json['replied_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String? get merchantReply => reply;

  Review copyWith({
    String? id,
    String? orderId,
    String? customerId,
    String? customerName,
    String? customerAvatar,
    int? rating,
    String? comment,
    String? reply,
    String? merchantReply,
    DateTime? repliedAt,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      reply: merchantReply ?? reply ?? this.reply,
      repliedAt: repliedAt ?? this.repliedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Dashboard Stats Model
class DashboardStats {
  final double todayRevenue;
  final double yesterdayRevenue;
  final int todayOrders;
  final int yesterdayOrders;
  final int pendingOrders;
  final int preparingOrders;
  final double averageRating;
  final int totalReviews;
  final double averagePreparationTime;
  final double completionRate;

  DashboardStats({
    this.todayRevenue = 0,
    this.yesterdayRevenue = 0,
    this.todayOrders = 0,
    this.yesterdayOrders = 0,
    this.pendingOrders = 0,
    this.preparingOrders = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.averagePreparationTime = 0,
    this.completionRate = 0,
  });

  double get revenueChange {
    if (yesterdayRevenue == 0) return todayRevenue > 0 ? 100 : 0;
    return ((todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100);
  }

  double get ordersChange {
    if (yesterdayOrders == 0) return todayOrders > 0 ? 100 : 0;
    return ((todayOrders - yesterdayOrders) / yesterdayOrders * 100);
  }
}
