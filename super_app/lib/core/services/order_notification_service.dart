import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service to handle real-time order status notifications
class OrderNotificationService {
  static final OrderNotificationService _instance =
      OrderNotificationService._internal();
  factory OrderNotificationService() => _instance;
  OrderNotificationService._internal();

  RealtimeChannel? _orderChannel;
  StreamController<OrderStatusUpdate>? _statusController;

  /// Stream of order status updates
  Stream<OrderStatusUpdate> get statusUpdates {
    _ensureController();
    return _statusController!.stream;
  }

  void _ensureController() {
    if (_statusController == null || _statusController!.isClosed) {
      _statusController = StreamController<OrderStatusUpdate>.broadcast();
    }
  }

  /// Initialize the notification service for a user
  void initialize() {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // Clean up existing subscription
    _orderChannel?.unsubscribe();

    // Subscribe to order updates for this user
    _orderChannel = SupabaseService.client
        .channel('user_order_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.oldRecord != null) {
              final oldStatus = payload.oldRecord['status'] as String?;
              final newStatus = payload.newRecord['status'] as String?;

              if (oldStatus != newStatus && newStatus != null) {
                final update = OrderStatusUpdate(
                  orderId: payload.newRecord['id'] as String,
                  orderNumber:
                      payload.newRecord['order_number'] as String? ?? '',
                  oldStatus: oldStatus ?? 'unknown',
                  newStatus: newStatus,
                  storeName: payload.newRecord['store_name'] as String?,
                  timestamp: DateTime.now(),
                );

                _ensureController();
                _statusController?.add(update);
              }
            }
          },
        )
        .subscribe();
  }

  /// Dispose of the service
  void dispose() {
    _orderChannel?.unsubscribe();
    _orderChannel = null;
    _statusController?.close();
    _statusController = null;
  }
}

/// Represents an order status update
class OrderStatusUpdate {
  final String orderId;
  final String orderNumber;
  final String oldStatus;
  final String newStatus;
  final String? storeName;
  final DateTime timestamp;

  OrderStatusUpdate({
    required this.orderId,
    required this.orderNumber,
    required this.oldStatus,
    required this.newStatus,
    this.storeName,
    required this.timestamp,
  });

  /// Get notification title based on status
  String get notificationTitle {
    switch (newStatus) {
      case 'confirmed':
        return 'Sipariş Onaylandı';
      case 'preparing':
        return 'Sipariş Hazırlanıyor';
      case 'ready':
        return 'Sipariş Hazır';
      case 'delivering':
        return 'Kurye Yola Çıktı';
      case 'delivered':
        return 'Sipariş Teslim Edildi';
      case 'cancelled':
        return 'Sipariş İptal Edildi';
      default:
        return 'Sipariş Durumu Güncellendi';
    }
  }

  /// Get notification body based on status
  String get notificationBody {
    final store = storeName ?? 'Restoran';
    switch (newStatus) {
      case 'confirmed':
        return '$store siparişinizi onayladı ve hazırlamaya başlayacak.';
      case 'preparing':
        return '$store siparişinizi hazırlıyor. Biraz bekleyin!';
      case 'ready':
        return 'Siparişiniz hazır! Kurye kısa sürede yola çıkacak.';
      case 'delivering':
        return 'Kurye siparişinizi aldı ve size doğru geliyor!';
      case 'delivered':
        return 'Siparişiniz teslim edildi. Afiyet olsun!';
      case 'cancelled':
        return 'Siparişiniz iptal edildi. Detaylar için destek ile iletişime geçin.';
      default:
        return 'Sipariş #$orderNumber durumu güncellendi.';
    }
  }

  /// Get icon for this status
  IconData get statusIcon {
    switch (newStatus) {
      case 'confirmed':
        return Icons.check_circle;
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.check_box;
      case 'delivering':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  /// Get color for this status
  Color get statusColor {
    switch (newStatus) {
      case 'confirmed':
        return const Color(0xFF3B82F6);
      case 'preparing':
        return const Color(0xFF8B5CF6);
      case 'ready':
        return const Color(0xFF10B981);
      case 'delivering':
        return const Color(0xFF06B6D4);
      case 'delivered':
        return const Color(0xFF22C55E);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }
}

/// Global instance
final orderNotificationService = OrderNotificationService();
