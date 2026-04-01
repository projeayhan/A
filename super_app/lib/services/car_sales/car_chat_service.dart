import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:super_app/core/services/log_service.dart';

/// Araç Satış Mesajlaşma Servisi (SuperCyp)
class CarChatService {
  static final CarChatService _instance = CarChatService._internal();
  static CarChatService get instance => _instance;
  factory CarChatService() => _instance;
  CarChatService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  /// Konuşma oluştur veya mevcut olanı getir
  Future<Map<String, dynamic>?> getOrCreateConversation({
    required String listingId,
    String? sellerId, // Opsiyonel - veritabanından alınacak
  }) async {
    LogService.debug('getOrCreateConversation başladı - listingId: $listingId', source: 'CarChatService:getOrCreateConversation');

    if (_userId == null) {
      return null;
    }

    try {
      LogService.debug('İlan bilgisi alınıyor...', source: 'CarChatService:getOrCreateConversation');
      // İlanı veritabanından al ve gerçek satıcı ID'sini öğren
      final listing = await _client
          .from('car_listings')
          .select('user_id')
          .eq('id', listingId)
          .single();

      final realSellerId = listing['user_id'] as String;

      // Kendi ilanına mesaj göndermeye çalışıyorsa engelle
      if (_userId == realSellerId) {
        throw Exception('Kendi ilanınıza mesaj gönderemezsiniz');
      }

      // Mevcut konuşma var mı kontrol et
      // Mevcut konuşma var mı kontrol et
      final existing = await _client
          .from('car_conversations')
          .select('''
            *,
            car_listings:listing_id (
              id, title, brand_name, model_name, year, price, images, city
            )
          ''')
          .eq('listing_id', listingId)
          .eq('buyer_id', _userId!)
          .eq('seller_id', realSellerId)
          .maybeSingle();

      if (existing != null) {
        return existing;
      }

      // Yeni konuşma oluştur
      final response = await _client
          .from('car_conversations')
          .insert({
            'listing_id': listingId,
            'buyer_id': _userId,
            'seller_id': realSellerId,
          })
          .select('''
            *,
            car_listings:listing_id (
              id, title, brand_name, model_name, year, price, images, city
            )
          ''')
          .single();

      return response;
    } catch (e, st) {
      LogService.error('Konuşma oluşturulamadı', error: e, stackTrace: st, source: 'CarChatService:getOrCreateConversation');
      rethrow; // Hatayı UI'a ilet
    }
  }

  /// Mesajları getir
  Future<List<Map<String, dynamic>>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('car_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).cast<Map<String, dynamic>>().reversed.toList();
    } catch (e, st) {
      LogService.error('Mesajlar alınamadı', error: e, stackTrace: st, source: 'CarChatService:getMessages');
      return [];
    }
  }

  /// Mesaj gönder
  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('car_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': _userId,
            'content': content,
            'message_type': messageType,
            'media_url': mediaUrl,
          })
          .select()
          .single();

      return response;
    } catch (e, st) {
      LogService.error('Mesaj gönderilemedi', error: e, stackTrace: st, source: 'CarChatService:sendMessage');
      return null;
    }
  }

  /// Mesajları okundu olarak işaretle
  Future<void> markMessagesAsRead(String conversationId) async {
    if (_userId == null) return;

    try {
      // Konuşmayı al
      final conversation = await _client
          .from('car_conversations')
          .select('buyer_id, seller_id')
          .eq('id', conversationId)
          .single();

      final isBuyer = conversation['buyer_id'] == _userId;

      // Mesajları okundu olarak işaretle
      await _client
          .from('car_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', _userId!)
          .eq('is_read', false);

      // Unread count'u sıfırla
      final updateField = isBuyer ? 'buyer_unread_count' : 'seller_unread_count';
      await _client
          .from('car_conversations')
          .update({updateField: 0})
          .eq('id', conversationId);
    } catch (e, st) {
      LogService.error('Mesajlar okundu olarak işaretlenemedi', error: e, stackTrace: st, source: 'CarChatService:markMessagesAsRead');
    }
  }

  /// Konuşmaları getir
  Future<List<Map<String, dynamic>>> getConversations() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('car_conversations')
          .select('''
            *,
            car_listings:listing_id (
              id, title, brand_name, model_name, year, price, images, city
            )
          ''')
          .or('buyer_id.eq.$_userId,seller_id.eq.$_userId')
          .eq('status', 'active')
          .order('last_message_at', ascending: false, nullsFirst: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e, st) {
      LogService.error('Konuşmalar alınamadı', error: e, stackTrace: st, source: 'CarChatService:getConversations');
      return [];
    }
  }

  /// Toplam okunmamış mesaj sayısı
  Future<int> getTotalUnreadCount() async {
    if (_userId == null) return 0;

    try {
      final response = await _client
          .from('car_conversations')
          .select('buyer_id, seller_id, buyer_unread_count, seller_unread_count')
          .or('buyer_id.eq.$_userId,seller_id.eq.$_userId')
          .eq('status', 'active');

      int total = 0;
      for (var conv in response) {
        if (conv['buyer_id'] == _userId) {
          total += (conv['buyer_unread_count'] as int? ?? 0);
        } else {
          total += (conv['seller_unread_count'] as int? ?? 0);
        }
      }
      return total;
    } catch (e, st) {
      LogService.error('Okunmamış mesaj sayısı alınamadı', error: e, stackTrace: st, source: 'CarChatService:getTotalUnreadCount');
      return 0;
    }
  }

  /// Mesajları dinle (realtime)
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    return _client
        .channel('car_messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'car_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onMessage(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Mesaj dinlemeyi durdur
  Future<void> unsubscribeFromMessages(RealtimeChannel channel) async {
    await channel.unsubscribe();
  }
}
