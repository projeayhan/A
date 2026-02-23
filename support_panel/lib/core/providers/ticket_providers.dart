import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/ticket_service.dart';
import '../models/support_models.dart';

// Ticket stats provider (auto-refresh every 30 seconds)
final ticketStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final service = ref.watch(ticketServiceProvider);
  final stats = await service.getTicketStats();

  // Auto-refresh every 30 seconds
  final timer = Timer(const Duration(seconds: 30), () {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return stats;
});

// Open ticket count for badge
final openTicketCountProvider = Provider<int>((ref) {
  final stats = ref.watch(ticketStatsProvider);
  return stats.when(
    data: (data) => data['open'] ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// Realtime ticket subscription
final ticketRealtimeProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final controller = StreamController<List<Map<String, dynamic>>>();

  // Initial fetch
  supabase
      .from('support_tickets')
      .select('*, support_agents!assigned_agent_id(full_name)')
      .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
      .order('created_at', ascending: false)
      .limit(100)
      .then((data) {
    controller.add(List<Map<String, dynamic>>.from(data));
  });

  // Realtime subscription
  final channel = supabase.channel('support_tickets_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'support_tickets',
        callback: (payload) {
          // Re-fetch on any change
          supabase
              .from('support_tickets')
              .select('*, support_agents!assigned_agent_id(full_name)')
              .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
              .order('created_at', ascending: false)
              .limit(100)
              .then((data) {
            if (!controller.isClosed) {
              controller.add(List<Map<String, dynamic>>.from(data));
            }
          });
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

// Ticket messages realtime subscription
final ticketMessagesProvider = StreamProvider.autoDispose.family<List<TicketMessage>, String>((ref, ticketId) {
  final supabase = ref.watch(supabaseProvider);
  final controller = StreamController<List<TicketMessage>>();

  // Initial fetch
  supabase
      .from('ticket_messages')
      .select()
      .eq('ticket_id', ticketId)
      .order('created_at', ascending: true)
      .then((data) {
    controller.add((data as List).map((m) => TicketMessage.fromJson(m)).toList());
  });

  // Realtime subscription
  final channel = supabase.channel('ticket_messages_$ticketId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'ticket_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'ticket_id',
          value: ticketId,
        ),
        callback: (payload) {
          // Re-fetch all messages
          supabase
              .from('ticket_messages')
              .select()
              .eq('ticket_id', ticketId)
              .order('created_at', ascending: true)
              .then((data) {
            if (!controller.isClosed) {
              controller.add((data as List).map((m) => TicketMessage.fromJson(m)).toList());
            }
          });
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});
