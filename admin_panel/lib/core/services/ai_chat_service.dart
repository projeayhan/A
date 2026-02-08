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

/// AI Chat Service for Admin Panel - uses admin-ai-chat edge function
class AiChatService {
  static const String appSource = 'admin_panel';
  static SupabaseClient get _client => Supabase.instance.client;

  /// Get a valid (non-expired) access token, refreshing if needed
  static Future<String?> _getValidAccessToken() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

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

  /// Send a message to admin AI assistant
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
          'error': 'Kullanici oturumu bulunamadi',
          'needs_login': true,
        };
      }

      final token = await _getValidAccessToken();
      if (token == null) {
        return {
          'success': false,
          'error': 'Oturum sureniz dolmus. Lutfen tekrar giris yapin.',
          'needs_login': true,
        };
      }

      return await _invokeAdminAiChat(message, sessionId, accessToken: token, generateAudio: generateAudio);
    } on FunctionException catch (e) {
      if (e.status == 401) {
        try {
          final refreshed = await _client.auth.refreshSession();
          final newToken = refreshed.session?.accessToken;
          if (newToken != null) {
            return await _invokeAdminAiChat(message, sessionId, accessToken: newToken, generateAudio: generateAudio);
          }
        } catch (_) {}
        return {
          'success': false,
          'error': 'Oturum sureniz dolmus. Lutfen tekrar giris yapin.',
          'needs_login': true,
        };
      }
      return {
        'success': false,
        'error': 'AI servisi hatasi: ${e.details?['message'] ?? e.status}',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _invokeAdminAiChat(
    String message,
    String? sessionId, {
    required String accessToken,
    bool generateAudio = false,
  }) async {
    final response = await _client.functions.invoke(
      'admin-ai-chat',
      body: {
        'message': message,
        'session_id': sessionId,
        if (generateAudio) 'generate_audio': true,
      },
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.status != 200) {
      final errorMsg = response.data?['error'] ?? 'AI servisi hatasi (${response.status})';
      throw Exception(errorMsg);
    }

    return Map<String, dynamic>.from(response.data);
  }

  /// Send message with SSE streaming
  static Stream<AiStreamEvent> sendMessageStream({
    required String message,
    String? sessionId,
  }) async* {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      yield AiStreamEvent.error('Kullanici oturumu bulunamadi.');
      return;
    }

    final token = await _getValidAccessToken();
    if (token == null) {
      yield AiStreamEvent.error('Oturum sureniz dolmus. Lutfen tekrar giris yapin.');
      return;
    }

    final url = '${SupabaseService.supabaseUrl}/functions/v1/admin-ai-chat';

    final body = jsonEncode({
      'message': message,
      'session_id': sessionId,
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

      if (buffer.trim().isNotEmpty) {
        final event = _parseSseChunk(buffer.trim());
        if (event != null) yield event;
      }

      client.close();
    } catch (e) {
      client?.close();
      yield AiStreamEvent.error('Baglanti hatasi: $e');
    }
  }

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
          .from('admin_ai_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

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
          .from('admin_ai_sessions')
          .select('id')
          .eq('admin_user_id', userId)
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
          .from('admin_ai_sessions')
          .update({'status': 'closed', 'closed_at': DateTime.now().toIso8601String()})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get session actions (audit log)
  static Future<List<Map<String, dynamic>>> getSessionActions(String sessionId) async {
    try {
      final response = await _client
          .from('admin_ai_actions')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
