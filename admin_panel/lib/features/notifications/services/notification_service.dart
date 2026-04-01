import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseProvider));
});

class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  // ── History ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    final response = await _supabase
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  // ── User search (for specific-user targeting) ──────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await _supabase
        .from('users')
        .select('id, full_name, email, phone')
        .or('full_name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
        .limit(15);
    return List<Map<String, dynamic>>.from(response);
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> sendNotification({
    required String title,
    required String body,
    required String targetType, // 'all' | 'users' | 'couriers' | 'merchants' | 'specific_user' | segment key
    String? targetId,           // user id when targetType == 'specific_user'
    String notificationType = 'info', // 'info' | 'warning' | 'promo' | 'system'
    DateTime? scheduledAt,      // null = send immediately
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Persist in DB
    await _supabase.from('notifications').insert({
      'user_id': targetId,
      'title': title,
      'body': body,
      'type': notificationType,
      'data': {
        'target_type': targetType,
      },
      'is_read': false,
      'created_at': now,
    });

    // 2. If scheduled for the future, skip edge function call now
    if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) return;

    // 3. Invoke edge function for immediate delivery
    try {
      await _supabase.functions.invoke('send-push-notification', body: {
        'title': title,
        'body': body,
        'target_type': targetType,
        'target_id': targetId,
        'notification_type': notificationType,
      });
    } catch (e) {
      // Edge function failure doesn't roll back the DB record – rethrow so
      // the UI can inform the admin, but history entry is already saved.
      rethrow;
    }
  }
}
