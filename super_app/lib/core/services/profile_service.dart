import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class UserProfile {
  final String id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? avatarUrl;
  final String membershipType;
  final int totalOrders;
  final int totalFavorites;
  final double averageRating;
  final int loyaltyPoints;
  final DateTime? createdAt;
  final DateTime? dateOfBirth;
  final String? gender;

  UserProfile({
    required this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarUrl,
    this.membershipType = 'standard',
    this.totalOrders = 0,
    this.totalFavorites = 0,
    this.averageRating = 0,
    this.loyaltyPoints = 0,
    this.createdAt,
    this.dateOfBirth,
    this.gender,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      membershipType: json['membership_type'] as String? ?? 'standard',
      totalOrders: json['total_orders'] as int? ?? 0,
      totalFavorites: json['total_favorites'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      loyaltyPoints: json['loyalty_points'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
    );
  }
}

class UserAddress {
  final String id;
  final String userId;
  final String type;
  final String name;
  final String? icon;
  final double latitude;
  final double longitude;
  final String address;
  final String? addressDetails;
  final String? contactName;
  final String? contactPhone;
  final bool isDefault;
  final int sortOrder;

  UserAddress({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    this.icon,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.addressDetails,
    this.contactName,
    this.contactPhone,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      addressDetails: json['address_details'] as String?,
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class UserPaymentMethod {
  final String id;
  final String userId;
  final String type;
  final String? provider;
  final String? cardLastFour;
  final String? cardBrand;
  final String? cardHolderName;
  final int? expiryMonth;
  final int? expiryYear;
  final bool isDefault;
  final bool isVerified;

  UserPaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    this.provider,
    this.cardLastFour,
    this.cardBrand,
    this.cardHolderName,
    this.expiryMonth,
    this.expiryYear,
    this.isDefault = false,
    this.isVerified = false,
  });

  String get displayName {
    if (cardBrand != null && cardLastFour != null) {
      return '$cardBrand **** $cardLastFour';
    }
    return type;
  }

  String get expiryDate {
    if (expiryMonth != null && expiryYear != null) {
      return '${expiryMonth.toString().padLeft(2, '0')}/${expiryYear.toString().substring(2)}';
    }
    return '';
  }

  factory UserPaymentMethod.fromJson(Map<String, dynamic> json) {
    return UserPaymentMethod(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      provider: json['provider'] as String?,
      cardLastFour: json['card_last_four'] as String?,
      cardBrand: json['card_brand'] as String?,
      cardHolderName: json['card_holder_name'] as String?,
      expiryMonth: json['expiry_month'] as int?,
      expiryYear: json['expiry_year'] as int?,
      isDefault: json['is_default'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

class UserCoupon {
  final String id;
  final String userId;
  final String code;
  final String title;
  final String? description;
  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscount;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool isUsed;
  final DateTime? usedAt;

  UserCoupon({
    required this.id,
    required this.userId,
    required this.code,
    required this.title,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount = 0,
    this.maxDiscount,
    required this.validFrom,
    required this.validUntil,
    this.isUsed = false,
    this.usedAt,
  });

  bool get isValid => !isUsed && DateTime.now().isBefore(validUntil);

  String get discountText {
    if (discountType == 'percentage') {
      return '%${discountValue.toInt()} indirim';
    }
    return '${discountValue.toStringAsFixed(0)} TL indirim';
  }

  int get daysRemaining {
    return validUntil.difference(DateTime.now()).inDays;
  }

  factory UserCoupon.fromJson(Map<String, dynamic> json) {
    return UserCoupon(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      maxDiscount: json['max_discount'] != null
          ? (json['max_discount'] as num).toDouble()
          : null,
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      isUsed: json['is_used'] as bool? ?? false,
      usedAt: json['used_at'] != null
          ? DateTime.parse(json['used_at'] as String)
          : null,
    );
  }
}

class UserOrder {
  final String id;
  final String userId;
  final String orderNumber;
  final String orderType;
  final String? storeId;
  final String status;
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double total;
  final String? paymentMethod;
  final String paymentStatus;
  final List<dynamic> items;
  final String? notes;
  final DateTime createdAt;

  UserOrder({
    required this.id,
    required this.userId,
    required this.orderNumber,
    required this.orderType,
    this.storeId,
    required this.status,
    required this.subtotal,
    this.discount = 0,
    this.shippingFee = 0,
    required this.total,
    this.paymentMethod,
    this.paymentStatus = 'pending',
    required this.items,
    this.notes,
    required this.createdAt,
  });

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Beklemede';
      case 'confirmed':
        return 'Onaylandı';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'shipped':
        return 'Kargoda';
      case 'delivered':
        return 'Teslim Edildi';
      case 'cancelled':
        return 'İptal Edildi';
      case 'refunded':
        return 'İade Edildi';
      default:
        return status;
    }
  }

  factory UserOrder.fromJson(Map<String, dynamic> json) {
    return UserOrder(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orderNumber: json['order_number'] as String,
      orderType: json['order_type'] as String,
      storeId: json['store_id'] as String?,
      status: json['status'] as String,
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      shippingFee: (json['shipping_fee'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      items: json['items'] as List<dynamic>? ?? [],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ProfileService {
  static SupabaseClient get _client => SupabaseService.client;

  // Kullanıcı profili getir
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching user profile: $e');
      return null;
    }
  }

  // Mevcut kullanıcının profilini getir
  static Future<UserProfile?> getCurrentUserProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    return getUserProfile(user.id);
  }

  // Kullanıcı adreslerini getir
  static Future<List<UserAddress>> getUserAddresses(String userId) async {
    try {
      final response = await _client
          .from('saved_locations')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('sort_order');

      return (response as List)
          .map((json) => UserAddress.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching addresses: $e');
      return [];
    }
  }

  // Kullanıcı ödeme yöntemlerini getir
  static Future<List<UserPaymentMethod>> getUserPaymentMethods(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('is_default', ascending: false);

      return (response as List)
          .map((json) => UserPaymentMethod.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching payment methods: $e');
      return [];
    }
  }

  // Kullanıcı kuponlarını getir
  static Future<List<UserCoupon>> getUserCoupons(String userId) async {
    try {
      final response = await _client
          .from('user_coupons')
          .select()
          .eq('user_id', userId)
          .eq('is_used', false)
          .gte('valid_until', DateTime.now().toIso8601String())
          .order('valid_until');

      return (response as List)
          .map((json) => UserCoupon.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching coupons: $e');
      return [];
    }
  }

  // Kullanıcı siparişlerini getir
  static Future<List<UserOrder>> getUserOrders(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => UserOrder.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching orders: $e');
      return [];
    }
  }

  // Profil istatistiklerini getir
  static Future<Map<String, dynamic>> getProfileStats(String userId) async {
    try {
      // Sipariş sayısı
      final ordersResponse = await _client
          .from('orders')
          .select('id')
          .eq('user_id', userId);
      final orderCount = (ordersResponse as List).length;

      // Adres sayısı
      final addressesResponse = await _client
          .from('saved_locations')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true);
      final addressCount = (addressesResponse as List).length;

      // Kart sayısı
      final cardsResponse = await _client
          .from('payment_methods')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true);
      final cardCount = (cardsResponse as List).length;

      // Kupon sayısı
      final couponsResponse = await _client
          .from('user_coupons')
          .select('id')
          .eq('user_id', userId)
          .eq('is_used', false)
          .gte('valid_until', DateTime.now().toIso8601String());
      final couponCount = (couponsResponse as List).length;

      return {
        'orderCount': orderCount,
        'addressCount': addressCount,
        'cardCount': cardCount,
        'couponCount': couponCount,
      };
    } catch (e) {
      if (kDebugMode) print('Error fetching profile stats: $e');
      return {
        'orderCount': 0,
        'addressCount': 0,
        'cardCount': 0,
        'couponCount': 0,
      };
    }
  }

  // Profil güncelle
  static Future<bool> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _client.from('users').update(updates).eq('id', userId);

      return true;
    } catch (e) {
      if (kDebugMode) print('Error updating profile: $e');
      return false;
    }
  }
}
