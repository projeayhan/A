import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveSupportService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Subscribe to ticket messages (realtime)
  static ({StreamSubscription<List<Map<String, dynamic>>> subscription, RealtimeChannel channel}) subscribeToMessages({
    required String ticketId,
    required void Function(List<Map<String, dynamic>> messages) onMessages,
  }) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    // Initial fetch
    _fetchMessages(ticketId).then((msgs) {
      if (!controller.isClosed) controller.add(msgs);
    });

    // Realtime subscription
    final channel = _client.channel('live_support_$ticketId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'ticket_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'ticket_id',
          value: ticketId,
        ),
        callback: (_) {
          _fetchMessages(ticketId).then((msgs) {
            if (!controller.isClosed) controller.add(msgs);
          });
        },
      )
      .subscribe();

    final sub = controller.stream.listen(onMessages);

    return (subscription: sub, channel: channel);
  }

  /// Subscribe to ticket status changes
  static RealtimeChannel subscribeToTicketStatus({
    required String ticketId,
    required void Function(String newStatus) onStatusChange,
  }) {
    return _client.channel('ticket_status_$ticketId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'support_tickets',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: ticketId,
        ),
        callback: (payload) {
          final newStatus = payload.newRecord['status'] as String?;
          if (newStatus != null) onStatusChange(newStatus);
        },
      )
      .subscribe();
  }

  /// Send a customer message
  static Future<void> sendMessage({
    required String ticketId,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    String senderName = 'Musteri';
    try {
      final userData = await _client
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      if (userData != null && userData['full_name'] != null) {
        senderName = userData['full_name'] as String;
      }
    } catch (_) {}

    await _client.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_type': 'customer',
      'sender_id': user.id,
      'sender_name': senderName,
      'message': message,
      'message_type': 'text',
    });
  }

  /// Fetch all messages for a ticket
  static Future<List<Map<String, dynamic>>> _fetchMessages(String ticketId) async {
    final response = await _client
        .from('ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Check for existing open live support ticket
  static Future<Map<String, dynamic>?> getExistingTicket() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('support_tickets')
        .select('id, ticket_number, status')
        .eq('customer_user_id', userId)
        .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
        .order('created_at', ascending: false)
        .limit(1);

    final list = List<Map<String, dynamic>>.from(response);
    if (list.isEmpty) return null;

    // Check metadata for is_live_chat
    final ticket = list.first;
    final fullTicket = await _client
        .from('support_tickets')
        .select('id, ticket_number, status, metadata')
        .eq('id', ticket['id'])
        .single();

    final metadata = fullTicket['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['is_live_chat'] == true) {
      return fullTicket;
    }
    return null;
  }
}
