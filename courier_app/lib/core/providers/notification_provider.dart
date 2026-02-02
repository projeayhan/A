import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Bildirimler provider'ı - realtime dinleme ile
final notificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    yield [];
    return;
  }

  // İlk yükleme
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final response = await supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  yield await fetchNotifications();

  // Realtime dinleme
  await for (final _ in supabase
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)) {
    yield await fetchNotifications();
  }
});

// Okunmamış bildirim sayısı
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.when(
    data: (notifications) => notifications.where((n) => n['is_read'] != true).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Bildirim servisi
class NotificationService {
  static final _supabase = Supabase.instance.client;

  // Bildirimi okundu olarak işaretle
  static Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // Tüm bildirimleri okundu olarak işaretle
  static Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // Bildirimi sil
  static Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }
}
