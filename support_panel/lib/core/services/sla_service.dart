import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:support_panel/core/services/log_service.dart';
import 'supabase_service.dart';
import 'ticket_service.dart';
import '../utils/sla_calculator.dart';

final slaServiceProvider = Provider<SlaService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SlaService(supabase, ref);
});

class SlaService {
  final SupabaseClient _supabase;
  final Ref _ref;

  SlaService(this._supabase, this._ref);

  /// Check all open tickets for SLA breaches and return breached ones
  Future<List<Map<String, dynamic>>> getBreachedTickets() async {
    try {
      return await _supabase
          .from('support_tickets')
          .select('id, subject, priority, sla_due_at, customer_name, assigned_agent_id, status')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          .lte('sla_due_at', DateTime.now().toIso8601String())
          .order('sla_due_at');
    } catch (e, st) {
      LogService.error('Error fetching breached tickets', error: e, stackTrace: st, source: 'SlaService:getBreachedTickets');
      return [];
    }
  }

  /// Check tickets approaching SLA breach (within 30 minutes)
  Future<List<Map<String, dynamic>>> getAtRiskTickets() async {
    try {
      final now = DateTime.now();
      final threshold = now.add(const Duration(minutes: 30));

      return await _supabase
          .from('support_tickets')
          .select('id, subject, priority, sla_due_at, customer_name, assigned_agent_id')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          .gt('sla_due_at', now.toIso8601String())
          .lte('sla_due_at', threshold.toIso8601String())
          .order('sla_due_at');
    } catch (e, st) {
      LogService.error('Error fetching at-risk tickets', error: e, stackTrace: st, source: 'SlaService:getAtRiskTickets');
      return [];
    }
  }

  /// Get SLA statistics for dashboard
  Future<Map<String, dynamic>> getSlaStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final results = await Future.wait([
        // Currently breached
        _supabase
            .from('support_tickets')
            .select('id', const FetchOptions(count: CountOption.exact, head: true))
            .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
            .lte('sla_due_at', now.toIso8601String()),
        // Resolved within SLA today
        _supabase
            .from('support_tickets')
            .select('id, sla_due_at, resolved_at')
            .eq('status', 'resolved')
            .gte('resolved_at', todayStart.toIso8601String()),
      ]);

      final breachedCount = results[0].count ?? 0;

      // Calculate SLA compliance rate for today
      final resolvedToday = results[1] as List;
      int withinSla = 0;
      for (final t in resolvedToday) {
        final slaDue = DateTime.tryParse(t['sla_due_at'] ?? '');
        final resolvedAt = DateTime.tryParse(t['resolved_at'] ?? '');
        if (slaDue != null && resolvedAt != null && resolvedAt.isBefore(slaDue)) {
          withinSla++;
        }
      }

      final complianceRate = resolvedToday.isNotEmpty
          ? (withinSla / resolvedToday.length * 100).round()
          : 100;

      return {
        'breached': breachedCount,
        'resolved_today': resolvedToday.length,
        'within_sla': withinSla,
        'compliance_rate': complianceRate,
      };
    } catch (e, st) {
      LogService.error('Error fetching SLA stats', error: e, stackTrace: st, source: 'SlaService:getSlaStats');
      return {'breached': 0, 'resolved_today': 0, 'within_sla': 0, 'compliance_rate': 100};
    }
  }

  /// Recalculate SLA due date when priority changes
  Future<void> recalculateSla(String ticketId, String newPriority) async {
    final slaDueAt = SlaCalculator.calculateSlaDue(newPriority);
    await _supabase.from('support_tickets').update({
      'sla_due_at': slaDueAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }

  /// Get average response and resolution times
  Future<Map<String, dynamic>> getResponseMetrics({int days = 7}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days));

      final tickets = await _supabase
          .from('support_tickets')
          .select('created_at, first_response_at, resolved_at')
          .gte('created_at', since.toIso8601String())
          .not('resolved_at', 'is', null);

      if (tickets.isEmpty) {
        return {'avg_response_minutes': 0, 'avg_resolution_minutes': 0};
      }

      int totalResponseMinutes = 0;
      int responseCount = 0;
      int totalResolutionMinutes = 0;
      int resolutionCount = 0;

      for (final t in tickets) {
        final created = DateTime.tryParse(t['created_at'] ?? '');
        final firstResponse = DateTime.tryParse(t['first_response_at'] ?? '');
        final resolved = DateTime.tryParse(t['resolved_at'] ?? '');

        if (created != null && firstResponse != null) {
          totalResponseMinutes += firstResponse.difference(created).inMinutes;
          responseCount++;
        }
        if (created != null && resolved != null) {
          totalResolutionMinutes += resolved.difference(created).inMinutes;
          resolutionCount++;
        }
      }

      return {
        'avg_response_minutes': responseCount > 0 ? (totalResponseMinutes / responseCount).round() : 0,
        'avg_resolution_minutes': resolutionCount > 0 ? (totalResolutionMinutes / resolutionCount).round() : 0,
      };
    } catch (e, st) {
      LogService.error('Error fetching response metrics', error: e, stackTrace: st, source: 'SlaService:getResponseMetrics');
      return {'avg_response_minutes': 0, 'avg_resolution_minutes': 0};
    }
  }
}
