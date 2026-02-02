import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';

// Mevcut kullanıcı ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  return SupabaseService.currentUser?.id;
});

// Kullanıcı profili provider
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return await ProfileService.getUserProfile(userId);
});

// Kullanıcı adresleri provider
final userAddressesProvider = FutureProvider<List<UserAddress>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return await ProfileService.getUserAddresses(userId);
});

// Kullanıcı ödeme yöntemleri provider
final userPaymentMethodsProvider = FutureProvider<List<UserPaymentMethod>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return await ProfileService.getUserPaymentMethods(userId);
});

// Kullanıcı kuponları provider
final userCouponsProvider = FutureProvider<List<UserCoupon>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return await ProfileService.getUserCoupons(userId);
});

// Kullanıcı siparişleri provider
final userOrdersProvider = FutureProvider<List<UserOrder>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return await ProfileService.getUserOrders(userId);
});

// Profil istatistikleri provider
final profileStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return {
      'orderCount': 0,
      'addressCount': 0,
      'cardCount': 0,
      'couponCount': 0,
    };
  }
  return await ProfileService.getProfileStats(userId);
});

// Adres sayısı provider
final addressCountProvider = Provider<int>((ref) {
  final addresses = ref.watch(userAddressesProvider);
  return addresses.valueOrNull?.length ?? 0;
});

// Kart sayısı provider
final cardCountProvider = Provider<int>((ref) {
  final cards = ref.watch(userPaymentMethodsProvider);
  return cards.valueOrNull?.length ?? 0;
});

// Kupon sayısı provider
final couponCountProvider = Provider<int>((ref) {
  final coupons = ref.watch(userCouponsProvider);
  return coupons.valueOrNull?.length ?? 0;
});

// Sipariş sayısı provider
final orderCountProvider = Provider<int>((ref) {
  final orders = ref.watch(userOrdersProvider);
  return orders.valueOrNull?.length ?? 0;
});
