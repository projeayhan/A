import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Job mesaj modeli
class JobChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String messageType;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const JobChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = 'text',
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory JobChatMessage.fromJson(Map<String, dynamic> json) {
    return JobChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool isMine(String currentUserId) => senderId == currentUserId;
}

/// Job konuşma modeli
class JobConversation {
  final String id;
  final String jobListingId;
  final String applicantId;
  final String posterId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int applicantUnreadCount;
  final int posterUnreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // İlişkili veriler
  final Map<String, dynamic>? jobListing;

  const JobConversation({
    required this.id,
    required this.jobListingId,
    required this.applicantId,
    required this.posterId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.applicantUnreadCount = 0,
    this.posterUnreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.jobListing,
  });

  factory JobConversation.fromJson(Map<String, dynamic> json) {
    return JobConversation(
      id: json['id'] as String,
      jobListingId: json['job_listing_id'] as String,
      applicantId: json['applicant_id'] as String,
      posterId: json['poster_id'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      applicantUnreadCount: json['applicant_unread_count'] as int? ?? 0,
      posterUnreadCount: json['poster_unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      jobListing: json['job_listing'] as Map<String, dynamic>?,
    );
  }

  String getOtherUserId(String currentUserId) {
    return currentUserId == applicantId ? posterId : applicantId;
  }

  int getUnreadCount(String currentUserId) {
    return currentUserId == applicantId
        ? applicantUnreadCount
        : posterUnreadCount;
  }

  String? get jobTitle => jobListing?['title'] as String?;
  String? get companyName {
    final company = jobListing?['company'] as Map<String, dynamic>?;
    return company?['name'] as String?;
  }
}

/// İş ilanı mesajlaşma servisi
class JobChatService {
  static final JobChatService _instance = JobChatService._internal();
  factory JobChatService() => _instance;
  JobChatService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== KONUŞMALAR ====================

  /// Kullanıcının tüm iş konuşmalarını getir
  Future<List<JobConversation>> getConversations() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('job_conversations')
          .select('''
            *,
            job_listing:job_listing_id (id, title, company:company_id(name))
          ''')
          .or('applicant_id.eq.$_userId,poster_id.eq.$_userId')
          .order('last_message_at', ascending: false);

      return (response as List)
          .map((json) => JobConversation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobChatService.getConversations error: $e');
      return [];
    }
  }

  /// Konuşma bul veya oluştur
  /// [jobListingId] - ilan ID'si
  /// posterId'yi otomatik olarak ilanın user_id'sinden alır
  Future<JobConversation> getOrCreateConversation({
    required String jobListingId,
  }) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    try {
      // İlanın user_id'sini al (poster'ın auth user_id'si)
      final listing = await _client
          .from('job_listings')
          .select('user_id')
          .eq('id', jobListingId)
          .single();
      final posterId = listing['user_id'] as String;

      // Mevcut konuşmayı ara
      final existing = await _client
          .from('job_conversations')
          .select('''
            *,
            job_listing:job_listing_id (id, title, company:company_id(name))
          ''')
          .eq('job_listing_id', jobListingId)
          .eq('applicant_id', _userId!)
          .eq('poster_id', posterId)
          .maybeSingle();

      if (existing != null) {
        return JobConversation.fromJson(existing);
      }

      // Yeni konuşma oluştur
      final newConv = await _client
          .from('job_conversations')
          .insert({
            'job_listing_id': jobListingId,
            'applicant_id': _userId,
            'poster_id': posterId,
          })
          .select('''
            *,
            job_listing:job_listing_id (id, title, company:company_id(name))
          ''')
          .single();

      return JobConversation.fromJson(newConv);
    } catch (e) {
      debugPrint('JobChatService.getOrCreateConversation error: $e');
      rethrow;
    }
  }

  /// Toplam okunmamış mesaj sayısı
  Future<int> getTotalUnreadCount() async {
    if (_userId == null) return 0;

    try {
      final response = await _client
          .from('job_conversations')
          .select('applicant_id, applicant_unread_count, poster_unread_count')
          .or('applicant_id.eq.$_userId,poster_id.eq.$_userId');

      int total = 0;
      for (final conv in response as List) {
        if (conv['applicant_id'] == _userId) {
          total += (conv['applicant_unread_count'] as int? ?? 0);
        } else {
          total += (conv['poster_unread_count'] as int? ?? 0);
        }
      }
      return total;
    } catch (e) {
      debugPrint('JobChatService.getTotalUnreadCount error: $e');
      return 0;
    }
  }

  // ==================== MESAJLAR ====================

  /// Konuşmadaki mesajları getir
  Future<List<JobChatMessage>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('job_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => JobChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('JobChatService.getMessages error: $e');
      return [];
    }
  }

  /// Mesaj gönder
  Future<JobChatMessage?> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('job_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': _userId,
            'content': content,
          })
          .select()
          .single();

      return JobChatMessage.fromJson(response);
    } catch (e) {
      debugPrint('JobChatService.sendMessage error: $e');
      return null;
    }
  }

  /// Mesajları okundu olarak işaretle
  Future<void> markMessagesAsRead(String conversationId) async {
    if (_userId == null) return;

    try {
      // Konuşmayı al
      final conv = await _client
          .from('job_conversations')
          .select('applicant_id, poster_id')
          .eq('id', conversationId)
          .single();

      final isApplicant = conv['applicant_id'] == _userId;

      // Okunmamış mesajları güncelle
      await _client
          .from('job_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', _userId!)
          .eq('is_read', false);

      // Okunmamış sayısını sıfırla
      await _client
          .from('job_conversations')
          .update({
            if (isApplicant)
              'applicant_unread_count': 0
            else
              'poster_unread_count': 0,
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('JobChatService.markMessagesAsRead error: $e');
    }
  }

  // ==================== REALTIME ====================

  /// Yeni mesaj geldiğinde bildirim al
  RealtimeChannel subscribeToNewMessages(
    String conversationId,
    void Function(JobChatMessage) onMessage,
  ) {
    return _client
        .channel('job_messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'job_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final message = JobChatMessage.fromJson(payload.newRecord);
            onMessage(message);
          },
        )
        .subscribe();
  }

  /// Kanaldan ayrıl
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
