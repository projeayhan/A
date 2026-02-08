import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

// Bildirim modeli
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  // Bildirim türüne göre ikon
  String get iconName {
    switch (type) {
      case 'order_update':
        return 'restaurant';
      case 'store_order':
        return 'shopping_bag';
      case 'taxi_ride':
        return 'local_taxi';
      case 'rental_reservation':
      case 'rental_review_reply':
      case 'rental_review_received':
        return 'directions_car';
      case 'job_application':
      case 'job_application_status':
        return 'work';
      case 'car_message':
      case 'car_favorite':
        return 'directions_car';
      case 'property_message':
      case 'property_favorite':
      case 'property_appointment':
        return 'home';
      case 'welcome':
        return 'celebration';
      case 'courier_order':
        return 'delivery_dining';
      case 'taxi_rating':
        return 'star';
      default:
        return 'notifications';
    }
  }

  // Bildirim türüne göre renk (hex)
  int get colorValue {
    switch (type) {
      case 'order_update':
        return 0xFFFF6B35; // Turuncu
      case 'store_order':
        return 0xFF10B981; // Yeşil
      case 'taxi_ride':
        return 0xFFFFC107; // Sarı
      case 'rental_reservation':
      case 'rental_review_reply':
      case 'rental_review_received':
        return 0xFF3B82F6; // Mavi
      case 'job_application':
      case 'job_application_status':
        return 0xFF8B5CF6; // Mor
      case 'car_message':
      case 'car_favorite':
        return 0xFF06B6D4; // Cyan
      case 'property_message':
      case 'property_favorite':
      case 'property_appointment':
        return 0xFFEC4899; // Pembe
      case 'welcome':
        return 0xFF22C55E; // Yeşil
      default:
        return 0xFF6B7280; // Gri
    }
  }
}

// Bildirim state
class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    int? unreadCount,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// Bildirim notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSubscription;

  NotificationNotifier() : super(const NotificationState(isLoading: true)) {
    _init();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = SupabaseService.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedIn) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _init();
        });
      } else if (authState.event == AuthChangeEvent.signedOut) {
        _channel?.unsubscribe();
        state = const NotificationState();
      }
    });
  }

  Future<void> _init() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      state = const NotificationState(isLoading: false);
      return;
    }

    await _loadNotifications();
    _subscribeToRealtime(userId);
  }

  Future<void> _loadNotifications() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();

      final unreadCount = notifications.where((n) => !n.isRead).length;

      state = NotificationState(
        notifications: notifications,
        isLoading: false,
        unreadCount: unreadCount,
      );
    } catch (e) {
      if (kDebugMode) print('Error loading notifications: $e');
      state = const NotificationState(isLoading: false);
    }
  }

  void _subscribeToRealtime(String userId) {
    _channel?.unsubscribe();

    _channel = SupabaseService.client
        .channel('user_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newNotification = AppNotification.fromJson(payload.newRecord);
            state = state.copyWith(
              notifications: [newNotification, ...state.notifications],
              unreadCount: state.unreadCount + 1,
            );
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      if (kDebugMode) print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      final updatedNotifications = state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
    } catch (e) {
      if (kDebugMode) print('Error marking all as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      final notification = state.notifications.firstWhere((n) => n.id == notificationId);
      final updatedNotifications = state.notifications
          .where((n) => n.id != notificationId)
          .toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: notification.isRead ? state.unreadCount : state.unreadCount - 1,
      );
    } catch (e) {
      if (kDebugMode) print('Error deleting notification: $e');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadNotifications();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _authSubscription?.cancel();
    super.dispose();
  }
}

// Providers
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});
