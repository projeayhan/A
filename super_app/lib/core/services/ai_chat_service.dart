import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatService {
  static const String _functionName = 'ai-chat';
  static const String _appSource = 'super_app';

  static SupabaseClient get _client => Supabase.instance.client;

  /// Send message to AI and get response
  static Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: {
          'message': message,
          'session_id': sessionId,
          'app_source': _appSource,
          'user_type': 'customer',
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'AI servisi hatası (${response.status})';
        throw Exception(errorMsg);
      }

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      print('AI Chat Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get chat history for a session
  static Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    try {
      final response = await _client
          .from('support_chat_messages')
          .select('id, role, content, created_at')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get user's chat sessions
  static Future<List<Map<String, dynamic>>> getUserSessions() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('support_chat_sessions')
          .select('id, status, subject, created_at, updated_at')
          .eq('user_id', userId)
          .eq('app_source', _appSource)
          .order('updated_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get active session or null
  static Future<String?> getActiveSessionId() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('support_chat_sessions')
          .select('id')
          .eq('user_id', userId)
          .eq('app_source', _appSource)
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
          .update({
            'status': 'closed',
            'closed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rate the chat session
  static Future<bool> rateSession(String sessionId, int rating) async {
    try {
      await _client
          .from('support_chat_sessions')
          .update({'satisfaction_rating': rating})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Escalate to human agent
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
