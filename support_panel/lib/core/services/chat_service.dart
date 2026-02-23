import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'support_auth_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return ChatService(supabase, ref);
});

class ChatService {
  final SupabaseClient _supabase;
  final Ref _ref;

  ChatService(this._supabase, this._ref);

  /// Get all active chats (tickets with recent messages, assigned to current agent or unassigned)
  Future<List<Map<String, dynamic>>> getActiveChats() async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return [];

    try {
      final response = await _supabase
          .from('support_tickets')
          .select('*, support_agents!assigned_agent_id(full_name)')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          .order('updated_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error fetching active chats: $e');
      return [];
    }
  }

  /// Get unread message count for a ticket
  Future<int> getUnreadCount(String ticketId) async {
    try {
      final response = await _supabase
          .from('ticket_messages')
          .select('id')
          .eq('ticket_id', ticketId)
          .eq('is_read', false)
          .neq('sender_type', 'agent');
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String ticketId) async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return;

    try {
      await _supabase
          .from('ticket_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('ticket_id', ticketId)
          .eq('is_read', false)
          .neq('sender_type', 'agent');
    } catch (e) {
      if (kDebugMode) print('Error marking messages as read: $e');
    }
  }

  /// Send a whisper message (agent-to-agent, invisible to customer)
  Future<void> sendWhisper({
    required String ticketId,
    required String message,
    String? targetAgentId,
  }) async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return;

    await _supabase.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_type': 'whisper',
      'sender_id': agent.id,
      'sender_name': agent.fullName,
      'message': message,
      'message_type': 'whisper',
      'whisper_target_id': targetAgentId,
    });
  }

  /// Update collision lock (heartbeat)
  Future<void> updateCollisionLock(String ticketId) async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return;

    try {
      await _supabase.from('ticket_collision_locks').upsert({
        'ticket_id': ticketId,
        'agent_id': agent.id,
        'agent_name': agent.fullName,
        'locked_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) print('Error updating collision lock: $e');
    }
  }

  /// Release collision lock
  Future<void> releaseCollisionLock(String ticketId) async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return;

    try {
      await _supabase
          .from('ticket_collision_locks')
          .delete()
          .eq('ticket_id', ticketId)
          .eq('agent_id', agent.id);
    } catch (_) {}
  }

  /// Check if another agent has the ticket locked
  Future<Map<String, dynamic>?> checkCollisionLock(String ticketId) async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return null;

    try {
      final response = await _supabase
          .from('ticket_collision_locks')
          .select()
          .eq('ticket_id', ticketId)
          .neq('agent_id', agent.id)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Get canned responses
  Future<List<Map<String, dynamic>>> getCannedResponses({String? category, String? serviceType}) async {
    var query = _supabase
        .from('canned_responses')
        .select()
        .eq('is_active', true);

    if (category != null) {
      query = query.eq('category', category);
    }
    if (serviceType != null) {
      query = query.eq('service_type', serviceType);
    }

    return await query.order('usage_count', ascending: false);
  }

  /// Increment canned response usage count
  Future<void> incrementCannedResponseUsage(String id) async {
    try {
      await _supabase.rpc('increment_canned_response_usage', params: {'response_id': id});
    } catch (_) {
      // Fallback: manual increment
      try {
        final current = await _supabase.from('canned_responses').select('usage_count').eq('id', id).single();
        await _supabase.from('canned_responses').update({
          'usage_count': (current['usage_count'] as int? ?? 0) + 1,
        }).eq('id', id);
      } catch (_) {}
    }
  }
}
