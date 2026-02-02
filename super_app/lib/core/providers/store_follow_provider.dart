import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/store/store_model.dart';

// Takip Edilen Mağaza Modeli
class FollowedStore {
  final String id;
  final String name;
  final String logoUrl;
  final DateTime followedAt;
  final bool notificationsEnabled;

  const FollowedStore({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.followedAt,
    this.notificationsEnabled = true,
  });

  FollowedStore copyWith({
    String? id,
    String? name,
    String? logoUrl,
    DateTime? followedAt,
    bool? notificationsEnabled,
  }) {
    return FollowedStore(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      followedAt: followedAt ?? this.followedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}

// Mağaza Takip State
class StoreFollowState {
  final List<FollowedStore> followedStores;
  final bool isLoading;

  const StoreFollowState({
    this.followedStores = const [],
    this.isLoading = false,
  });

  bool isFollowing(String storeId) {
    return followedStores.any((s) => s.id == storeId);
  }

  FollowedStore? getFollowedStore(String storeId) {
    try {
      return followedStores.firstWhere((s) => s.id == storeId);
    } catch (_) {
      return null;
    }
  }

  StoreFollowState copyWith({
    List<FollowedStore>? followedStores,
    bool? isLoading,
  }) {
    return StoreFollowState(
      followedStores: followedStores ?? this.followedStores,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Mağaza Takip Notifier
class StoreFollowNotifier extends StateNotifier<StoreFollowState> {
  final Ref ref;

  StoreFollowNotifier(this.ref) : super(const StoreFollowState()) {
    _loadFollowedStores();
  }

  void _loadFollowedStores() {
    // Mock data - gerçek uygulamada API'den veya local storage'dan çekilecek
    // Şimdilik boş başlıyoruz
  }

  void followStore(Store store) {
    if (state.isFollowing(store.id)) return;

    final followedStore = FollowedStore(
      id: store.id,
      name: store.name,
      logoUrl: store.logoUrl,
      followedAt: DateTime.now(),
      notificationsEnabled: true,
    );

    state = state.copyWith(
      followedStores: [...state.followedStores, followedStore],
    );

    // Bildirim provider'ına mağaza takip bildirimi ekle
    ref.read(storeNotificationProvider.notifier).addNotification(
      StoreNotification(
        id: 'follow_${store.id}_${DateTime.now().millisecondsSinceEpoch}',
        storeId: store.id,
        storeName: store.name,
        storeLogoUrl: store.logoUrl,
        type: StoreNotificationType.follow,
        title: '${store.name} takip ediliyor',
        message: 'Artık ${store.name} mağazasının indirim ve yeni ürün bildirimlerini alacaksınız.',
        createdAt: DateTime.now(),
      ),
    );
  }

  void unfollowStore(String storeId) {
    state = state.copyWith(
      followedStores: state.followedStores.where((s) => s.id != storeId).toList(),
    );
  }

  void toggleNotifications(String storeId) {
    final updatedList = state.followedStores.map((s) {
      if (s.id == storeId) {
        return s.copyWith(notificationsEnabled: !s.notificationsEnabled);
      }
      return s;
    }).toList();

    state = state.copyWith(followedStores: updatedList);
  }
}

// Store Follow Provider
final storeFollowProvider = StateNotifierProvider<StoreFollowNotifier, StoreFollowState>((ref) {
  return StoreFollowNotifier(ref);
});

// Convenience provider - belirli bir mağazanın takip durumu
final isFollowingProvider = Provider.family<bool, String>((ref, storeId) {
  return ref.watch(storeFollowProvider).isFollowing(storeId);
});

// ============================================
// MAĞAZA BİLDİRİM SİSTEMİ
// ============================================

enum StoreNotificationType {
  follow,        // Mağaza takip edildiğinde
  discount,      // Mağaza indirim yaptığında
  newProduct,    // Yeni ürün eklendiğinde
  campaign,      // Kampanya başladığında
  priceDown,     // Fiyat düştüğünde
}

class StoreNotification {
  final String id;
  final String storeId;
  final String storeName;
  final String storeLogoUrl;
  final StoreNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? productId;
  final String? productName;
  final String? productImageUrl;
  final double? discountPercentage;
  final double? oldPrice;
  final double? newPrice;

  const StoreNotification({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.storeLogoUrl,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.productId,
    this.productName,
    this.productImageUrl,
    this.discountPercentage,
    this.oldPrice,
    this.newPrice,
  });

  IconData get icon {
    switch (type) {
      case StoreNotificationType.follow:
        return Icons.store_rounded;
      case StoreNotificationType.discount:
        return Icons.local_offer_rounded;
      case StoreNotificationType.newProduct:
        return Icons.new_releases_rounded;
      case StoreNotificationType.campaign:
        return Icons.campaign_rounded;
      case StoreNotificationType.priceDown:
        return Icons.trending_down_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case StoreNotificationType.follow:
        return Colors.blue;
      case StoreNotificationType.discount:
        return Colors.red;
      case StoreNotificationType.newProduct:
        return Colors.green;
      case StoreNotificationType.campaign:
        return Colors.orange;
      case StoreNotificationType.priceDown:
        return Colors.purple;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${(difference.inDays / 7).floor()} hafta önce';
    }
  }

  StoreNotification copyWith({
    String? id,
    String? storeId,
    String? storeName,
    String? storeLogoUrl,
    StoreNotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? productId,
    String? productName,
    String? productImageUrl,
    double? discountPercentage,
    double? oldPrice,
    double? newPrice,
  }) {
    return StoreNotification(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeLogoUrl: storeLogoUrl ?? this.storeLogoUrl,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      oldPrice: oldPrice ?? this.oldPrice,
      newPrice: newPrice ?? this.newPrice,
    );
  }
}

// Mağaza Bildirim State
class StoreNotificationState {
  final List<StoreNotification> notifications;
  final bool isLoading;

  const StoreNotificationState({
    this.notifications = const [],
    this.isLoading = false,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  List<StoreNotification> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();

  StoreNotificationState copyWith({
    List<StoreNotification>? notifications,
    bool? isLoading,
  }) {
    return StoreNotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Mağaza Bildirim Notifier
class StoreNotificationNotifier extends StateNotifier<StoreNotificationState> {
  StoreNotificationNotifier() : super(const StoreNotificationState()) {
    _loadNotifications();
  }

  void _loadNotifications() {
    // Veriler Supabase'den yüklenir - başlangıçta boş
    state = state.copyWith(notifications: []);
  }

  void addNotification(StoreNotification notification) {
    state = state.copyWith(
      notifications: [notification, ...state.notifications],
    );
  }

  void markAsRead(String notificationId) {
    final updatedList = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    state = state.copyWith(notifications: updatedList);
  }

  void markAllAsRead() {
    final updatedList = state.notifications.map((n) {
      return n.copyWith(isRead: true);
    }).toList();

    state = state.copyWith(notifications: updatedList);
  }

  void deleteNotification(String notificationId) {
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.id != notificationId).toList(),
    );
  }

  void clearAll() {
    state = state.copyWith(notifications: []);
  }

  // Simülasyon: Mağaza indirim bildirimi gönder
  void simulateDiscountNotification(String storeId, String storeName, String storeLogoUrl, double discountPercentage) {
    addNotification(
      StoreNotification(
        id: 'discount_${storeId}_${DateTime.now().millisecondsSinceEpoch}',
        storeId: storeId,
        storeName: storeName,
        storeLogoUrl: storeLogoUrl,
        type: StoreNotificationType.discount,
        title: '$storeName\'da İndirim!',
        message: 'Tüm ürünlerde %${discountPercentage.toInt()} indirim başladı.',
        createdAt: DateTime.now(),
        discountPercentage: discountPercentage,
      ),
    );
  }

  // Simülasyon: Yeni ürün bildirimi gönder
  void simulateNewProductNotification(String storeId, String storeName, String storeLogoUrl, String productName) {
    addNotification(
      StoreNotification(
        id: 'newproduct_${storeId}_${DateTime.now().millisecondsSinceEpoch}',
        storeId: storeId,
        storeName: storeName,
        storeLogoUrl: storeLogoUrl,
        type: StoreNotificationType.newProduct,
        title: 'Yeni Ürün: $productName',
        message: '$storeName mağazasına yeni ürün eklendi.',
        createdAt: DateTime.now(),
        productName: productName,
      ),
    );
  }
}

// Store Notification Provider
final storeNotificationProvider = StateNotifierProvider<StoreNotificationNotifier, StoreNotificationState>((ref) {
  return StoreNotificationNotifier();
});

// Convenience providers
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(storeNotificationProvider).unreadCount;
});

final allNotificationsProvider = Provider<List<StoreNotification>>((ref) {
  return ref.watch(storeNotificationProvider).notifications;
});
