import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/chat_service.dart';
import '../models/support_models.dart';

/// Active chats provider (realtime)
final activeChatsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final chatService = ref.watch(chatServiceProvider);
  final controller = StreamController<List<Map<String, dynamic>>>();

  // Initial fetch
  chatService.getActiveChats().then((chats) {
    if (!controller.isClosed) controller.add(chats);
  });

  // Realtime subscription for new/updated tickets
  final channel = supabase.channel('active_chats_realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'support_tickets',
        callback: (_) {
          chatService.getActiveChats().then((chats) {
            if (!controller.isClosed) controller.add(chats);
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

/// Active chat count for badge
final activeChatCountProvider = Provider<int>((ref) {
  final chats = ref.watch(activeChatsProvider);
  return chats.when(
    data: (data) => data.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Live messages for a specific ticket (realtime)
final liveChatMessagesProvider = StreamProvider.autoDispose.family<List<TicketMessage>, String>((ref, ticketId) {
  final supabase = ref.watch(supabaseProvider);
  final controller = StreamController<List<TicketMessage>>();

  // Initial fetch
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

  // Realtime subscription
  final channel = supabase.channel('live_chat_$ticketId')
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

/// Canned responses provider
final cannedResponsesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getCannedResponses();
});

/// Selected chat ticket ID
final selectedChatTicketProvider = StateProvider<String?>((ref) => null);
