import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:super_app/core/services/log_service.dart';

enum AiStreamEventType { session, chunk, actions, searchResults, rentalResults, priceComparison, done, error }

class AiStreamEvent {
  final AiStreamEventType type;
  final String? sessionId;
  final String? text;
  final String? fullMessage;
  final int? tokensUsed;
  final List<Map<String, dynamic>>? actions;
  final List<Map<String, dynamic>>? searchResults;
  final List<Map<String, dynamic>>? rentalResults;
  final Map<String, dynamic>? priceComparison;
  final String? error;

  const AiStreamEvent._({
    required this.type,
    this.sessionId,
    this.text,
    this.fullMessage,
    this.tokensUsed,
    this.actions,
    this.searchResults,
    this.rentalResults,
    this.priceComparison,
    this.error,
  });

  factory AiStreamEvent.session(String sessionId) =>
      AiStreamEvent._(type: AiStreamEventType.session, sessionId: sessionId);
  factory AiStreamEvent.chunk(String text) =>
      AiStreamEvent._(type: AiStreamEventType.chunk, text: text);
  factory AiStreamEvent.actions(List<Map<String, dynamic>> actions) =>
      AiStreamEvent._(type: AiStreamEventType.actions, actions: actions);
  factory AiStreamEvent.searchResults(List<Map<String, dynamic>> products) =>
      AiStreamEvent._(type: AiStreamEventType.searchResults, searchResults: products);
  factory AiStreamEvent.rentalResults(List<Map<String, dynamic>> cars) =>
      AiStreamEvent._(type: AiStreamEventType.rentalResults, rentalResults: cars);
  factory AiStreamEvent.priceComparison(Map<String, dynamic> data) =>
      AiStreamEvent._(type: AiStreamEventType.priceComparison, priceComparison: data);
  factory AiStreamEvent.done(String fullMessage, int tokensUsed) =>
      AiStreamEvent._(type: AiStreamEventType.done, fullMessage: fullMessage, tokensUsed: tokensUsed);
  factory AiStreamEvent.error(String error) =>
      AiStreamEvent._(type: AiStreamEventType.error, error: error);
}

class AiChatService {
  static const String _functionName = 'ai-chat';
  static const String _appSource = 'super_app';

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
        } catch (e, st) {
          LogService.error('Error getting preferred voice', error: e, stackTrace: st, source: 'AiChatService:sendMessage');
          return null;
        }
      }
    }

    return session.accessToken;
  }

  /// Send message to AI and get response
  static Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
    Map<String, dynamic>? screenContext,
    bool generateAudio = false,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'error': 'Lütfen önce giriş yapın.',
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

      return await _invokeAiChat(message, sessionId, screenContext, accessToken: token, generateAudio: generateAudio);
    } on FunctionException catch (e) {
      LogService.error('AI Chat FunctionException: ${e.status}', error: e, source: 'AiChatService:sendMessage');

      // Handle 401 - refresh and retry with explicit new token
      if (e.status == 401) {
        try {
          final refreshed = await _client.auth.refreshSession();
          final newToken = refreshed.session?.accessToken;
          if (newToken != null) {
            return await _invokeAiChat(message, sessionId, screenContext, accessToken: newToken, generateAudio: generateAudio);
          }
        } catch (refreshError, st) {
          LogService.error('Refresh and retry failed', error: refreshError, stackTrace: st, source: 'AiChatService:sendMessage');
        }
        return {
          'success': false,
          'error': 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.',
          'needs_login': true,
        };
      }

      return {
        'success': false,
        'error': 'AI servisi hatası: ${e.details?['error'] ?? e.details?['message'] ?? e.status}',
      };
    } catch (e, st) {
      LogService.error('AI Chat Error', error: e, stackTrace: st, source: 'AiChatService:sendMessage');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _invokeAiChat(
    String message,
    String? sessionId,
    Map<String, dynamic>? screenContext, {
    required String accessToken,
    bool generateAudio = false,
  }) async {
    final body = {
      'message': message,
      'session_id': sessionId,
      'app_source': _appSource,
      'user_type': 'customer',
      if (screenContext != null) 'screen_context': screenContext,
      if (generateAudio) 'generate_audio': true,
    };

    final response = await _client.functions.invoke(
      _functionName,
      body: body,
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
    Map<String, dynamic>? screenContext,
  }) async* {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      yield AiStreamEvent.error('Lütfen önce giriş yapın.');
      return;
    }

    final token = await _getValidAccessToken();
    if (token == null) {
      yield AiStreamEvent.error('Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.');
      return;
    }

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    final url = '$supabaseUrl/functions/v1/$_functionName';

    final body = jsonEncode({
      'message': message,
      'session_id': sessionId,
      'app_source': _appSource,
      'user_type': 'customer',
      'stream': true,
      if (screenContext != null) 'screen_context': screenContext,
    });

    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'apikey': anonKey,
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
        } catch (e, st) {
          LogService.error('HTTP error response parse failed', error: e, stackTrace: st, source: 'AiChatService:streamChat');
          yield AiStreamEvent.error('HTTP ${response.statusCode}');
        }
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
    } catch (e, st) {
      LogService.error('Stream connection error', error: e, stackTrace: st, source: 'AiChatService:streamChat');
      yield AiStreamEvent.error('Bağlantı hatası: $e');
    } finally {
      client?.close();
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
      final data = jsonDecode(dataStr.trim()) as Map<String, dynamic>;

      switch (eventType) {
        case 'session':
          return AiStreamEvent.session(data['session_id'] as String);
        case 'chunk':
          return AiStreamEvent.chunk(data['text'] as String);
        case 'actions':
          return AiStreamEvent.actions(
            (data['actions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        case 'search_results':
          return AiStreamEvent.searchResults(
            (data['products'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        case 'rental_results':
          return AiStreamEvent.rentalResults(
            (data['cars'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        case 'price_comparison':
          return AiStreamEvent.priceComparison(Map<String, dynamic>.from(data as Map));
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
    } catch (e, st) {
      LogService.error('SSE parse error [$eventType]', error: e, stackTrace: st, source: 'AiChatService:_parseEvent');
      return null;
    }
  }

  /// Get chat history for a session
  static Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    try {
      final response = await _client
          .from('support_chat_messages')
          .select('id, role, content, created_at, metadata')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      LogService.error('Error getting chat history', error: e, stackTrace: st, source: 'AiChatService:getChatHistory');
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
    } catch (e, st) {
      LogService.error('Error getting user sessions', error: e, stackTrace: st, source: 'AiChatService:getUserSessions');
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
    } catch (e, st) {
      LogService.error('Error getting active session', error: e, stackTrace: st, source: 'AiChatService:getActiveSessionId');
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
    } catch (e, st) {
      LogService.error('Error closing session', error: e, stackTrace: st, source: 'AiChatService:closeSession');
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
    } catch (e, st) {
      LogService.error('Error rating session', error: e, stackTrace: st, source: 'AiChatService:rateSession');
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
    } catch (e, st) {
      LogService.error('Error escalating to human', error: e, stackTrace: st, source: 'AiChatService:escalateToHuman');
      return false;
    }
  }
}
