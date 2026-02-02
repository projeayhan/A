import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseProvider));
});

class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  // Get notification history
  Future<List<Map<String, dynamic>>> getNotificationHistory() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // If table doesn't exist or error, return empty list for now
      return [];
    }
  }

  // Send notification
  Future<void> sendNotification({
    required String title,
    required String body,
    required String targetType, // 'all', 'users', 'couriers', 'merchants'
    String? targetId,
  }) async {
    // 1. Insert into database for history
    await _supabase.from('notifications').insert({
      'title': title,
      'body': body,
      'target_type': targetType,
      'target_id': targetId,
      'status': 'sent',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Call Edge Function to actually send FCM/OneSignal (Mock for now)
    // await _supabase.functions.invoke('send-push-notification', body: { ... });
  }
}
