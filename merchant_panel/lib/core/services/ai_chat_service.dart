import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum AiStreamEventType { session, chunk, actions, done, error }

class AiStreamEvent {
  final AiStreamEventType type;
  final String? sessionId;
  final String? text;
  final String? fullMessage;
  final int? tokensUsed;
  final List<Map<String, dynamic>>? actions;
  final String? error;

  const AiStreamEvent._({
    required this.type,
    this.sessionId,
    this.text,
    this.fullMessage,
    this.tokensUsed,
    this.actions,
    this.error,
  });

  factory AiStreamEvent.session(String sessionId) =>
      AiStreamEvent._(type: AiStreamEventType.session, sessionId: sessionId);
  factory AiStreamEvent.chunk(String text) =>
      AiStreamEvent._(type: AiStreamEventType.chunk, text: text);
  factory AiStreamEvent.actions(List<Map<String, dynamic>> actions) =>
      AiStreamEvent._(type: AiStreamEventType.actions, actions: actions);
  factory AiStreamEvent.done(String fullMessage, int tokensUsed) =>
      AiStreamEvent._(type: AiStreamEventType.done, fullMessage: fullMessage, tokensUsed: tokensUsed);
  factory AiStreamEvent.error(String error) =>
      AiStreamEvent._(type: AiStreamEventType.error, error: error);
}

/// AI Chat Service for Merchant Panel
class AiChatService {
  static const String appSource = 'merchant_panel';
  static SupabaseClient get _client => Supabase.instance.client;

  /// Get a valid (non-expired) access token, refreshing if needed
  static Future<String?> _getValidAccessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    // Check if token will expire within 30 seconds
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (DateTime.now().isAfter(expiryTime.subtract(const Duration(seconds: 30)))) {
        try {
          final refreshed = await _client.auth.refreshSession();
          return refreshed.session?.accessToken;
        } catch (_) {
          return null;
        }
      }
    }

    return session.accessToken;
  }

  /// Send a message to AI assistant
  static Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
    bool generateAudio = false,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'error': 'Kullanıcı oturumu bulunamadı',
          'needs_login': true,
        };
      }

      // Get a valid (non-expired) access token
      final token = await _getValidAccessToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.',
          'needs_login': true,
        };
      }

      return await _invokeAiChat(message, sessionId, accessToken: token, generateAudio: generateAudio);
    } on FunctionException catch (e) {
      print('AI Chat FunctionException: ${e.status} - ${e.details}');

      // Handle 401 - refresh and retry with explicit new token
      if (e.status == 401) {
        try {
          final refreshed = await _client.auth.refreshSession();
          final newToken = refreshed.session?.accessToken;
          if (newToken != null) {
            return await _invokeAiChat(message, sessionId, accessToken: newToken, generateAudio: generateAudio);
          }
        } catch (refreshError) {
          print('Refresh and retry failed: $refreshError');
        }
        return {
          'success': false,
          'error': 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.',
          'needs_login': true,
        };
      }

      return {
        'success': false,
        'error': 'AI servisi hatası: ${e.details?['message'] ?? e.status}',
      };
    } catch (e) {
      print('AI Chat Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _invokeAiChat(
    String message,
    String? sessionId, {
    required String accessToken,
    bool generateAudio = false,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'message': message,
        'session_id': sessionId,
        'user_id': userId,
        'app_source': appSource,
        if (generateAudio) 'generate_audio': true,
      },
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.status != 200) {
      final errorMsg = response.data?['error'] ?? 'AI servisi hatası (${response.status})';
      throw Exception(errorMsg);
    }

    return Map<String, dynamic>.from(response.data);
  }

  /// Send message with SSE streaming - returns progressive chunks
  static Stream<AiStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
  }) async* {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      yield AiStreamEvent.error('Kullanıcı oturumu bulunamadı.');
      return;
    }

    final token = await _getValidAccessToken();
    if (token == null) {
      yield AiStreamEvent.error('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
      return;
    }

    final url = '${SupabaseService.supabaseUrl}/functions/v1/ai-chat';

    final body = jsonEncode({
      'message': message,
      'session_id': sessionId,
      'user_id': currentUser.id,
      'app_source': appSource,
      'stream': true,
    });

    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'apikey': SupabaseService.supabaseAnonKey,
    });
    request.body = body;

    http.Client? client;
    try {
      client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        try {
          final json = jsonDecode(responseBody);
          yield AiStreamEvent.error(json['error'] ?? 'HTTP ${response.statusCode}');
        } catch (_) {
          yield AiStreamEvent.error('HTTP ${response.statusCode}');
        }
        client.close();
        return;
      }

      // Parse SSE stream with buffering for TCP packet splitting
      String buffer = '';

      await for (final bytes in response.stream) {
        buffer += utf8.decode(bytes);

        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final chunk = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          final event = _parseSseChunk(chunk);
          if (event != null) yield event;
        }
      }

      // Process remaining buffer
      if (buffer.trim().isNotEmpty) {
        final event = _parseSseChunk(buffer.trim());
        if (event != null) yield event;
      }

      client.close();
    } catch (e) {
      client?.close();
      yield AiStreamEvent.error('Bağlantı hatası: $e');
    }
  }

  /// Parse a single SSE chunk into an AiStreamEvent
  static AiStreamEvent? _parseSseChunk(String chunk) {
    String? eventType;
    String? dataStr;

    for (final line in chunk.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        dataStr = line.substring(6);
      }
    }

    if (dataStr == null) return null;

    try {
      final data = jsonDecode(dataStr) as Map<String, dynamic>;

      switch (eventType) {
        case 'session':
          return AiStreamEvent.session(data['session_id'] as String);
        case 'chunk':
          return AiStreamEvent.chunk(data['text'] as String);
        case 'actions':
          return AiStreamEvent.actions(
            (data['actions'] as List).cast<Map<String, dynamic>>(),
          );
        case 'done':
          return AiStreamEvent.done(
            data['message'] as String,
            data['tokens_used'] as int? ?? 0,
          );
        case 'error':
          return AiStreamEvent.error(data['error'] as String? ?? 'Bilinmeyen hata');
        default:
          return null;
      }
    } catch (_) {
      return null;
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
