import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';

/// Araç Satış Mesajlaşma Servisi
class ChatService {
  static final ChatService _instance = ChatService._internal();
  static ChatService get instance => _instance;
  factory ChatService() => _instance;
  ChatService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== CONVERSATIONS ====================

  /// Tüm konuşmaları getir
  Future<List<CarConversation>> getConversations() async {
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

      final conversations = (response as List)
          .map((json) => CarConversation.fromJson(json))
          .toList();

      // Her konuşma için karşı tarafın bilgisini al
      for (var i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        final otherUserId = conv.buyerId == _userId ? conv.sellerId : conv.buyerId;

        // Önce car_dealers'dan dene (satıcı bilgisi)
        final dealerProfile = await _client
            .from('car_dealers')
            .select('id, owner_name, logo_url, phone')
            .eq('user_id', otherUserId)
            .maybeSingle();

        UserProfile? profile;
        if (dealerProfile != null) {
          profile = UserProfile(
            id: otherUserId,
            fullName: dealerProfile['owner_name'] as String?,
            avatarUrl: dealerProfile['logo_url'] as String?,
            phone: dealerProfile['phone'] as String?,
          );
        } else {
          // user_profiles'dan dene
          final userProfile = await _client
              .from('user_profiles')
              .select('id, full_name, avatar_url')
              .eq('id', otherUserId)
              .maybeSingle();

          if (userProfile != null) {
            profile = UserProfile.fromJson(userProfile);
          }
        }

        // Profili konuşmaya ekle
        if (profile != null) {
          if (conv.buyerId == _userId) {
            conversations[i] = CarConversation(
              id: conv.id,
              listingId: conv.listingId,
              buyerId: conv.buyerId,
              sellerId: conv.sellerId,
              lastMessage: conv.lastMessage,
              lastMessageAt: conv.lastMessageAt,
              lastMessageSenderId: conv.lastMessageSenderId,
              buyerUnreadCount: conv.buyerUnreadCount,
              sellerUnreadCount: conv.sellerUnreadCount,
              status: conv.status,
              createdAt: conv.createdAt,
              updatedAt: conv.updatedAt,
              listing: conv.listing,
              sellerProfile: profile,
            );
          } else {
            conversations[i] = CarConversation(
              id: conv.id,
              listingId: conv.listingId,
              buyerId: conv.buyerId,
              sellerId: conv.sellerId,
              lastMessage: conv.lastMessage,
              lastMessageAt: conv.lastMessageAt,
              lastMessageSenderId: conv.lastMessageSenderId,
              buyerUnreadCount: conv.buyerUnreadCount,
              sellerUnreadCount: conv.sellerUnreadCount,
              status: conv.status,
              createdAt: conv.createdAt,
              updatedAt: conv.updatedAt,
              listing: conv.listing,
              buyerProfile: profile,
            );
          }
        }
      }

      return conversations;
    } catch (e) {
      debugPrint('Konuşmalar alınamadı: $e');
      return [];
    }
  }

  /// Tek bir konuşmayı getir
  Future<CarConversation?> getConversation(String conversationId) async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('car_conversations')
          .select('''
            *,
            car_listings:listing_id (
              id, title, brand_name, model_name, year, price, images, city
            )
          ''')
          .eq('id', conversationId)
          .single();

      return CarConversation.fromJson(response);
    } catch (e) {
      debugPrint('Konuşma alınamadı: $e');
      return null;
    }
  }

  /// Konuşma oluştur veya mevcut olanı getir
  Future<CarConversation?> getOrCreateConversation({
    required String listingId,
    required String sellerId,
  }) async {
    if (_userId == null) return null;

    // Kendi ilanına mesaj göndermeye çalışıyorsa engelle
    if (_userId == sellerId) {
      throw Exception('Kendi ilanınıza mesaj gönderemezsiniz');
    }

    try {
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
          .eq('seller_id', sellerId)
          .maybeSingle();

      if (existing != null) {
        return CarConversation.fromJson(existing);
      }

      // Yeni konuşma oluştur
      final response = await _client
          .from('car_conversations')
          .insert({
            'listing_id': listingId,
            'buyer_id': _userId,
            'seller_id': sellerId,
          })
          .select('''
            *,
            car_listings:listing_id (
              id, title, brand_name, model_name, year, price, images, city
            )
          ''')
          .single();

      return CarConversation.fromJson(response);
    } catch (e) {
      debugPrint('Konuşma oluşturulamadı: $e');
      return null;
    }
  }

  // ==================== MESSAGES ====================

  /// Mesajları getir
  Future<List<ChatMessage>> getMessages(
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

      return (response as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('Mesajlar alınamadı: $e');
      return [];
    }
  }

  /// Mesaj gönder
  Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String content,
    MessageType messageType = MessageType.text,
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
            'message_type': messageType.name,
            'media_url': mediaUrl,
          })
          .select()
          .single();

      return ChatMessage.fromJson(response);
    } catch (e) {
      debugPrint('Mesaj gönderilemedi: $e');
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
    } catch (e) {
      debugPrint('Mesajlar okundu olarak işaretlenemedi: $e');
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
    } catch (e) {
      debugPrint('Okunmamış mesaj sayısı alınamadı: $e');
      return 0;
    }
  }

  // ==================== REALTIME ====================

  /// Konuşmaları dinle (realtime)
  RealtimeChannel subscribeToConversations(void Function() onUpdate) {
    return _client
        .channel('car_conversations_$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'car_conversations',
          callback: (payload) {
            final record = payload.newRecord;
            // Sadece bu kullanıcının konuşmalarını dinle
            if (record['buyer_id'] == _userId || record['seller_id'] == _userId) {
              onUpdate();
            }
          },
        )
        .subscribe();
  }

  /// Mesajları dinle (realtime)
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(ChatMessage) onMessage,
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
            final message = ChatMessage.fromJson(payload.newRecord);
            onMessage(message);
          },
        )
        .subscribe();
  }

  /// Realtime kanalını kapat
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await channel.unsubscribe();
  }

  // ==================== CONVERSATION ACTIONS ====================

  /// Konuşmayı arşivle
  Future<bool> archiveConversation(String conversationId) async {
    try {
      await _client
          .from('car_conversations')
          .update({'status': 'archived'})
          .eq('id', conversationId);
      return true;
    } catch (e) {
      debugPrint('Konuşma arşivlenemedi: $e');
      return false;
    }
  }

  /// Konuşmayı sil (soft delete - archive)
  Future<bool> deleteConversation(String conversationId) async {
    return archiveConversation(conversationId);
  }
}
