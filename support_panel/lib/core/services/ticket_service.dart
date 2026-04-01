import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:support_panel/core/services/log_service.dart';
import 'supabase_service.dart';
import 'support_auth_service.dart';
import '../utils/sla_calculator.dart';

final ticketServiceProvider = Provider<TicketService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return TicketService(supabase, ref);
});

class TicketService {
  final SupabaseClient _supabase;
  final Ref _ref;

  TicketService(this._supabase, this._ref);

  Future<Map<String, dynamic>> fetchTickets({
    int page = 0,
    int pageSize = 50,
    String? statusFilter,
    String? priorityFilter,
    String? serviceTypeFilter,
    String? assignedAgentFilter,
    String? searchQuery,
    String sortColumn = 'created_at',
    bool sortAscending = false,
  }) async {
    final agent = _ref.read(currentAgentProvider).value;
    // Only supervisors and managers can see all tickets; L1/L2 agents see only their own.
    final bool canViewAll = agent != null && (agent.isSupervisor || agent.isManager);

    // Data query
    var query = _supabase
        .from('support_tickets')
        .select('*, assigned_agent:support_agents!assigned_agent_id(full_name)');

    // Agent isolation: restrict non-supervisor/manager agents to their assigned tickets.
    if (!canViewAll && agent != null) {
      query = query.eq('assigned_agent_id', agent.id);
    }

    if (statusFilter != null && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }
    if (priorityFilter != null && priorityFilter != 'all') {
      query = query.eq('priority', priorityFilter);
    }
    if (serviceTypeFilter != null && serviceTypeFilter != 'all') {
      query = query.eq('service_type', serviceTypeFilter);
    }
    if (assignedAgentFilter != null && assignedAgentFilter != 'all') {
      if (assignedAgentFilter == 'unassigned') {
        query = query.isFilter('assigned_agent_id', null);
      } else {
        query = query.eq('assigned_agent_id', assignedAgentFilter);
      }
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('subject.ilike.%$searchQuery%,customer_name.ilike.%$searchQuery%,customer_phone.ilike.%$searchQuery%');
    }

    final data = await query
        .order(sortColumn, ascending: sortAscending)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    // Count query (separate)
    var countQuery = _supabase.from('support_tickets').select('id');

    // Agent isolation applied to count query as well.
    if (!canViewAll && agent != null) {
      countQuery = countQuery.eq('assigned_agent_id', agent.id);
    }

    if (statusFilter != null && statusFilter != 'all') {
      countQuery = countQuery.eq('status', statusFilter);
    }
    if (priorityFilter != null && priorityFilter != 'all') {
      countQuery = countQuery.eq('priority', priorityFilter);
    }
    if (serviceTypeFilter != null && serviceTypeFilter != 'all') {
      countQuery = countQuery.eq('service_type', serviceTypeFilter);
    }
    if (assignedAgentFilter != null && assignedAgentFilter != 'all') {
      if (assignedAgentFilter == 'unassigned') {
        countQuery = countQuery.isFilter('assigned_agent_id', null);
      } else {
        countQuery = countQuery.eq('assigned_agent_id', assignedAgentFilter);
      }
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      countQuery = countQuery.or('subject.ilike.%$searchQuery%,customer_name.ilike.%$searchQuery%,customer_phone.ilike.%$searchQuery%');
    }
    final countResponse = await countQuery.count();

    return {
      'data': data,
      'count': countResponse.count,
    };
  }

  Future<Map<String, dynamic>?> getTicketById(String ticketId) async {
    return await _supabase
        .from('support_tickets')
        .select('*, assigned_agent:support_agents!assigned_agent_id(full_name)')
        .eq('id', ticketId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getTicketMessages(String ticketId) async {
    return await _supabase
        .from('ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
  }

  Future<void> createTicket({
    required String serviceType,
    required String subject,
    String? description,
    String? customerUserId,
    String? customerName,
    String? customerPhone,
    String priority = 'normal',
    String? category,
    String? relatedOrderId,
    String? relatedRideId,
    String? relatedBookingId,
    String? relatedListingId,
    String? relatedMerchantId,
  }) async {
    final slaDueAt = SlaCalculator.calculateSlaDue(priority);

    await _supabase.from('support_tickets').insert({
      'service_type': serviceType,
      'subject': subject,
      'description': description,
      'customer_user_id': customerUserId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'priority': priority,
      'category': category,
      'sla_due_at': slaDueAt.toIso8601String(),
      'related_order_id': relatedOrderId,
      'related_ride_id': relatedRideId,
      'related_booking_id': relatedBookingId,
      'related_listing_id': relatedListingId,
      'related_merchant_id': relatedMerchantId,
    });
  }

  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    final updates = <String, dynamic>{
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (newStatus == 'resolved') {
      updates['resolved_at'] = DateTime.now().toIso8601String();
    } else if (newStatus == 'closed') {
      updates['closed_at'] = DateTime.now().toIso8601String();
    }

    await _supabase.from('support_tickets').update(updates).eq('id', ticketId);
  }

  Future<void> assignTicket(String ticketId, String agentId) async {
    await _supabase.from('support_tickets').update({
      'assigned_agent_id': agentId,
      'status': 'assigned',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }

  Future<void> updateTicketPriority(String ticketId, String newPriority) async {
    final slaDueAt = SlaCalculator.calculateSlaDue(newPriority);
    await _supabase.from('support_tickets').update({
      'priority': newPriority,
      'sla_due_at': slaDueAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }

  Future<void> sendMessage({
    required String ticketId,
    required String message,
    String senderType = 'agent',
    String messageType = 'text',
    String? whisperTargetId,
  }) async {
    final agent = _ref.read(currentAgentProvider).value;

    await _supabase.from('ticket_messages').insert({
      'ticket_id': ticketId,
      'sender_type': senderType,
      'sender_id': agent?.id,
      'sender_name': agent?.fullName,
      'message': message,
      'message_type': messageType,
      'whisper_target_id': whisperTargetId,
    });

    // Update first_response_at if this is the first agent response
    try {
      final ticket = await _supabase
          .from('support_tickets')
          .select('first_response_at')
          .eq('id', ticketId)
          .single();

      if (ticket['first_response_at'] == null && senderType == 'agent') {
        await _supabase.from('support_tickets').update({
          'first_response_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', ticketId);
      }
    } catch (e, st) {
      LogService.error('Error updating first_response_at', error: e, stackTrace: st, source: 'TicketService:sendMessage');
    }
  }

  Future<Map<String, int>> getTicketStats() async {
    try {
      final agent = _ref.read(currentAgentProvider).value;

      final allOpen = await _supabase
          .from('support_tickets')
          .select('id')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          .count();

      int myCount = 0;
      if (agent != null) {
        final myTickets = await _supabase
            .from('support_tickets')
            .select('id')
            .eq('assigned_agent_id', agent.id)
            .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
            .count();
        myCount = myTickets.count;
      }

      final slaBreached = await _supabase
          .from('support_tickets')
          .select('id')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          .lte('sla_due_at', DateTime.now().toIso8601String())
          .count();

      final unassigned = await _supabase
          .from('support_tickets')
          .select('id')
          .isFilter('assigned_agent_id', null)
          .inFilter('status', ['open'])
          .count();

      return {
        'open': allOpen.count,
        'my_tickets': myCount,
        'sla_breached': slaBreached.count,
        'unassigned': unassigned.count,
      };
    } catch (e, st) {
      LogService.error('Error fetching ticket stats', error: e, stackTrace: st, source: 'TicketService:getTicketStats');
      return {'open': 0, 'my_tickets': 0, 'sla_breached': 0, 'unassigned': 0};
    }
  }
}
