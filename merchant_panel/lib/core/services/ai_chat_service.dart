import 'package:supabase_flutter/supabase_flutter.dart';

/// AI Chat Service for Merchant Panel
class AiChatService {
  static const String appSource = 'merchant_panel';
  static SupabaseClient get _client => Supabase.instance.client;

  /// Send a message to AI assistant
  static Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return {'success': false, 'error': 'Kullanıcı oturumu bulunamadı'};
      }

      final response = await _client.functions.invoke(
        'ai-chat',
        body: {
          'message': message,
          'session_id': sessionId,
          'user_id': userId,
          'app_source': appSource,
        },
      );

      if (response.status == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        return {'success': false, 'error': 'AI servisi yanıt vermedi'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get chat history for a session
  static Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    try {
      final response = await _client
          .from('support_chat_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get all sessions for current user
  static Future<List<Map<String, dynamic>>> getUserSessions() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('support_chat_sessions')
          .select()
          .eq('user_id', userId)
          .eq('app_source', appSource)
          .order('updated_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get active session ID if exists
  static Future<String?> getActiveSessionId() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('support_chat_sessions')
          .select('id')
          .eq('user_id', userId)
          .eq('app_source', appSource)
          .eq('status', 'active')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['id'];
    } catch (e) {
      return null;
    }
  }

  /// Close a chat session
  static Future<bool> closeSession(String sessionId) async {
    try {
      await _client
          .from('support_chat_sessions')
          .update({'status': 'closed'})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rate a chat session
  static Future<bool> rateSession(String sessionId, int rating) async {
    try {
      await _client
          .from('support_chat_sessions')
          .update({'user_rating': rating})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Escalate to human support
  static Future<bool> escalateToHuman(String sessionId, String reason) async {
    try {
      await _client
          .from('support_chat_sessions')
          .update({
            'status': 'escalated',
            'escalated_at': DateTime.now().toIso8601String(),
            'escalation_reason': reason,
          })
          .eq('id', sessionId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
