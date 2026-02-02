import 'package:supabase_flutter/supabase_flutter.dart';

/// Mesaj modeli
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String messageType;
  final String? mediaUrl;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
    };
  }

  /// Mesajın gönderen tarafından mı olduğunu kontrol et
  bool isMine(String currentUserId) => senderId == currentUserId;
}

/// Konuşma modeli
class Conversation {
  final String id;
  final String? propertyId;
  final String buyerId;
  final String sellerId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int buyerUnreadCount;
  final int sellerUnreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // İlişkili veriler
  final Map<String, dynamic>? property;
  final Map<String, dynamic>? buyerProfile;
  final Map<String, dynamic>? sellerProfile;

  const Conversation({
    required this.id,
    this.propertyId,
    required this.buyerId,
    required this.sellerId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.buyerUnreadCount = 0,
    this.sellerUnreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.property,
    this.buyerProfile,
    this.sellerProfile,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      propertyId: json['property_id'] as String?,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      buyerUnreadCount: json['buyer_unread_count'] as int? ?? 0,
      sellerUnreadCount: json['seller_unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      property: json['properties'] as Map<String, dynamic>?,
      buyerProfile: json['buyer_profile'] as Map<String, dynamic>?,
      sellerProfile: json['seller_profile'] as Map<String, dynamic>?,
    );
  }

  /// Karşı tarafın ID'sini al
  String getOtherUserId(String currentUserId) {
    return currentUserId == buyerId ? sellerId : buyerId;
  }

  /// Okunmamış mesaj sayısını al
  int getUnreadCount(String currentUserId) {
    return currentUserId == buyerId ? buyerUnreadCount : sellerUnreadCount;
  }

  /// Karşı tarafın profil bilgisini al
  Map<String, dynamic>? getOtherUserProfile(String currentUserId) {
    return currentUserId == buyerId ? sellerProfile : buyerProfile;
  }

  /// İlan başlığını al
  String? get propertyTitle => property?['title'] as String?;

  /// İlan resmini al
  String? get propertyImage {
    final images = property?['images'] as List<dynamic>?;
    return images?.isNotEmpty == true ? images!.first as String : null;
  }
}

/// Emlak mesajlaşma servisi
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== KONUŞMALAR ====================

  /// Kullanıcının tüm konuşmalarını getir
  Future<List<Conversation>> getConversations() async {
    if (_userId == null) return [];

    final response = await _client
        .from('conversations')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .or('buyer_id.eq.$_userId,seller_id.eq.$_userId')
        .order('last_message_at', ascending: false);

    return (response as List).map((json) => Conversation.fromJson(json)).toList();
  }

  /// Konuşma detayını getir
  Future<Conversation?> getConversation(String conversationId) async {
    if (_userId == null) return null;

    final response = await _client
        .from('conversations')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .eq('id', conversationId)
        .or('buyer_id.eq.$_userId,seller_id.eq.$_userId')
        .maybeSingle();

    if (response == null) return null;
    return Conversation.fromJson(response);
  }

  /// Property ve satıcı için mevcut konuşmayı bul veya yeni oluştur
  Future<Conversation> getOrCreateConversation({
    required String propertyId,
    required String sellerId,
  }) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    // Mevcut konuşmayı ara
    final existing = await _client
        .from('conversations')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .eq('property_id', propertyId)
        .eq('buyer_id', _userId!)
        .eq('seller_id', sellerId)
        .maybeSingle();

    if (existing != null) {
      return Conversation.fromJson(existing);
    }

    // Yeni konuşma oluştur
    final newConversation = await _client
        .from('conversations')
        .insert({
          'property_id': propertyId,
          'buyer_id': _userId,
          'seller_id': sellerId,
        })
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .single();

    return Conversation.fromJson(newConversation);
  }

  /// Toplam okunmamış mesaj sayısını getir
  Future<int> getTotalUnreadCount() async {
    if (_userId == null) return 0;

    final response = await _client
        .from('conversations')
        .select('buyer_id, buyer_unread_count, seller_unread_count')
        .or('buyer_id.eq.$_userId,seller_id.eq.$_userId');

    int total = 0;
    for (final conv in response as List) {
      if (conv['buyer_id'] == _userId) {
        total += (conv['buyer_unread_count'] as int? ?? 0);
      } else {
        total += (conv['seller_unread_count'] as int? ?? 0);
      }
    }
    return total;
  }

  // ==================== MESAJLAR ====================

  /// Konuşmadaki mesajları getir
  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    if (_userId == null) return [];

    final response = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => ChatMessage.fromJson(json)).toList();
  }

  /// Mesaj gönder
  Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final response = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': _userId,
          'content': content,
          'message_type': messageType,
          'media_url': mediaUrl,
        })
        .select()
        .single();

    return ChatMessage.fromJson(response);
  }

  /// Mesajları okundu olarak işaretle
  Future<void> markMessagesAsRead(String conversationId) async {
    if (_userId == null) return;

    // Önce konuşmayı al
    final conv = await _client
        .from('conversations')
        .select('buyer_id, seller_id')
        .eq('id', conversationId)
        .single();

    final isBuyer = conv['buyer_id'] == _userId;

    // Okunmamış mesajları güncelle
    await _client
        .from('messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('conversation_id', conversationId)
        .neq('sender_id', _userId!)
        .eq('is_read', false);

    // Konuşmadaki okunmamış sayısını sıfırla
    await _client
        .from('conversations')
        .update({
          if (isBuyer) 'buyer_unread_count': 0 else 'seller_unread_count': 0,
        })
        .eq('id', conversationId);
  }

  // ==================== REALTIME ====================

  /// Konuşma listesini dinle
  Stream<List<Conversation>> streamConversations() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('last_message_at', ascending: false)
        .map((list) {
          // Sadece kullanıcının konuşmalarını filtrele
          return list
              .where((json) => json['buyer_id'] == _userId || json['seller_id'] == _userId)
              .map((json) => Conversation.fromJson(json))
              .toList();
        });
  }

  /// Mesajları dinle
  Stream<List<ChatMessage>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((list) => list.map((json) => ChatMessage.fromJson(json)).toList());
  }

  /// Yeni mesaj geldiğinde bildirim al
  RealtimeChannel subscribeToNewMessages(String conversationId, void Function(ChatMessage) onMessage) {
    return _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
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

  /// Kanaldan ayrıl
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }

  // ==================== YARDIMCI METODLAR ====================

  /// Kullanıcı profil bilgisini getir
  Future<Map<String, dynamic>?> getUserProfile(String oderId) async {
    final response = await _client
        .from('user_profiles')
        .select()
        .eq('id', oderId)
        .maybeSingle();

    return response;
  }

  /// Kullanıcı adını getir
  Future<String> getUserName(String oderId) async {
    final profile = await getUserProfile(oderId);
    return profile?['full_name'] as String? ?? 'Kullanıcı';
  }
}
