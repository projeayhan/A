import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service to handle real-time review reply notifications
class ReviewNotificationService {
  static final ReviewNotificationService _instance = ReviewNotificationService._internal();
  factory ReviewNotificationService() => _instance;
  ReviewNotificationService._internal();

  RealtimeChannel? _reviewChannel;
  StreamController<ReviewReplyUpdate>? _replyController;
  final Set<String> _seenReplies = {};

  /// Stream of review reply updates
  Stream<ReviewReplyUpdate> get replyUpdates {
    _ensureController();
    return _replyController!.stream;
  }

  void _ensureController() {
    if (_replyController == null || _replyController!.isClosed) {
      _replyController = StreamController<ReviewReplyUpdate>.broadcast();
    }
  }

  /// Initialize the notification service for a user
  void initialize() {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // Clean up existing subscription
    _reviewChannel?.unsubscribe();

    // Subscribe to review updates for this user (merchant replies)
    _reviewChannel = SupabaseService.client
        .channel('user_review_replies_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;

            final oldReply = oldRecord['merchant_reply'] as String?;
            final newReply = newRecord['merchant_reply'] as String?;
            final reviewId = newRecord['id'] as String? ?? '';

            // Check if merchant just replied (was null, now has value)
            if (oldReply == null && newReply != null && !_seenReplies.contains(reviewId)) {
              _seenReplies.add(reviewId);

              final update = ReviewReplyUpdate(
                reviewId: reviewId,
                merchantName: newRecord['merchant_name'] as String? ?? 'Restoran',
                merchantReply: newReply,
                orderId: newRecord['order_id'] as String?,
                orderNumber: newRecord['order_number'] as String?,
                timestamp: DateTime.now(),
              );

              // Play notification sound using system haptic/sound
              _playNotificationSound();

              _ensureController();
              _replyController?.add(update);
            }
          },
        )
        .subscribe();
  }

  /// Play notification sound using system feedback
  Future<void> _playNotificationSound() async {
    try {
      // Use haptic feedback as notification
      await HapticFeedback.mediumImpact();
      // Also trigger a vibration pattern if available
      await HapticFeedback.vibrate();
    } catch (e) {
      debugPrint('Could not play notification feedback: $e');
    }
  }

  /// Dispose of the service
  void dispose() {
    _reviewChannel?.unsubscribe();
    _reviewChannel = null;
    _replyController?.close();
    _replyController = null;
    _seenReplies.clear();
  }
}

/// Represents a review reply update from merchant
class ReviewReplyUpdate {
  final String reviewId;
  final String merchantName;
  final String merchantReply;
  final String? orderId;
  final String? orderNumber;
  final DateTime timestamp;

  ReviewReplyUpdate({
    required this.reviewId,
    required this.merchantName,
    required this.merchantReply,
    this.orderId,
    this.orderNumber,
    required this.timestamp,
  });

  /// Get notification title
  String get notificationTitle => '$merchantName Yanıt Verdi';

  /// Get notification body
  String get notificationBody => merchantReply.length > 100
      ? '${merchantReply.substring(0, 100)}...'
      : merchantReply;

  /// Get icon for notification
  IconData get icon => Icons.reply;

  /// Get color for notification
  Color get color => const Color(0xFF22C55E);
}

/// Global instance
final reviewNotificationService = ReviewNotificationService();
