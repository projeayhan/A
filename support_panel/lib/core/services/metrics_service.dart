import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'support_auth_service.dart';

final metricsServiceProvider = Provider<MetricsService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return MetricsService(supabase, ref);
});

class MetricsService {
  final SupabaseClient _supabase;
  final Ref _ref;

  MetricsService(this._supabase, this._ref);

  /// Get dashboard stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return {};

    try {
      final open = await _supabase
          .from('support_tickets')
          .select('id')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer']);
      final myTickets = agent.id.isNotEmpty
          ? await _supabase
              .from('support_tickets')
              .select('id')
              .eq('assigned_agent_id', agent.id)
              .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          : <Map<String, dynamic>>[];
      final pending = await _supabase
          .from('support_tickets')
          .select('id')
          .eq('status', 'pending');
      final resolvedToday = await _supabase
          .from('support_tickets')
          .select('id')
          .eq('status', 'resolved')
          .gte('resolved_at', DateTime.now().toIso8601String().substring(0, 10));
      final slaBreached = await _supabase
          .from('support_tickets')
          .select('id')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer'])
          .lte('sla_due_at', DateTime.now().toIso8601String());
      final unassigned = await _supabase
          .from('support_tickets')
          .select('id')
          .isFilter('assigned_agent_id', null)
          .eq('status', 'open');

      return {
        'open': (open as List).length,
        'my_tickets': (myTickets as List).length,
        'pending': (pending as List).length,
        'resolved_today': (resolvedToday as List).length,
        'sla_breached': (slaBreached as List).length,
        'unassigned': (unassigned as List).length,
      };
    } catch (e) {
      if (kDebugMode) print('Error fetching dashboard stats: $e');
      return {};
    }
  }

  /// Get ticket distribution by service type
  Future<List<Map<String, dynamic>>> getTicketsByServiceType() async {
    try {
      final response = await _supabase
          .from('support_tickets')
          .select('service_type')
          .inFilter('status', ['open', 'assigned', 'pending', 'waiting_customer']);

      final Map<String, int> counts = {};
      for (final row in response) {
        final type = row['service_type'] as String;
        counts[type] = (counts[type] ?? 0) + 1;
      }

      return counts.entries
          .map((e) => {'service_type': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      if (kDebugMode) print('Error fetching ticket distribution: $e');
      return [];
    }
  }

  /// Get online agents
  Future<List<Map<String, dynamic>>> getOnlineAgents() async {
    try {
      return await _supabase
          .from('support_agents')
          .select()
          .neq('status', 'offline')
          .order('status');
    } catch (e) {
      if (kDebugMode) print('Error fetching online agents: $e');
      return [];
    }
  }

  /// Get recent activity (latest ticket updates)
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) async {
    try {
      return await _supabase
          .from('agent_actions_log')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
    } catch (e) {
      if (kDebugMode) print('Error fetching recent activity: $e');
      return [];
    }
  }

  /// Get agent's own metrics for today
  Future<Map<String, dynamic>?> getTodayMetrics() async {
    final agent = _ref.read(currentAgentProvider).value;
    if (agent == null) return null;

    try {
      return await _supabase
          .from('agent_metrics')
          .select()
          .eq('agent_id', agent.id)
          .eq('date', DateTime.now().toIso8601String().substring(0, 10))
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Get weekly ticket trend (last 7 days: created vs resolved per day)
  Future<List<Map<String, dynamic>>> getWeeklyTrend() async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 6));
      final startDate = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);

      final created = await _supabase
          .from('support_tickets')
          .select('created_at')
          .gte('created_at', startDate.toIso8601String());

      final resolved = await _supabase
          .from('support_tickets')
          .select('resolved_at')
          .gte('resolved_at', startDate.toIso8601String())
          .not('resolved_at', 'is', null);

      final List<Map<String, dynamic>> trend = [];
      for (int i = 0; i < 7; i++) {
        final day = startDate.add(Duration(days: i));
        final dayStr = day.toIso8601String().substring(0, 10);

        final createdCount = (created as List).where((r) {
          final d = r['created_at'] as String?;
          return d != null && d.startsWith(dayStr);
        }).length;

        final resolvedCount = (resolved as List).where((r) {
          final d = r['resolved_at'] as String?;
          return d != null && d.startsWith(dayStr);
        }).length;

        trend.add({
          'date': dayStr,
          'day_label': _dayLabel(day.weekday),
          'created': createdCount,
          'resolved': resolvedCount,
        });
      }

      return trend;
    } catch (e) {
      if (kDebugMode) print('Error fetching weekly trend: $e');
      return [];
    }
  }

  String _dayLabel(int weekday) {
    const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return labels[weekday - 1];
  }

  /// Get tickets in queue grouped by service type
  Future<List<Map<String, dynamic>>> getQueueByServiceType() async {
    try {
      final response = await _supabase
          .from('support_tickets')
          .select('service_type, priority')
          .isFilter('assigned_agent_id', null)
          .eq('status', 'open');

      final Map<String, Map<String, int>> grouped = {};
      for (final row in response) {
        final type = row['service_type'] as String;
        final priority = row['priority'] as String;
        grouped.putIfAbsent(type, () => {'total': 0, 'urgent': 0, 'high': 0});
        grouped[type]!['total'] = (grouped[type]!['total'] ?? 0) + 1;
        if (priority == 'urgent') grouped[type]!['urgent'] = (grouped[type]!['urgent'] ?? 0) + 1;
        if (priority == 'high') grouped[type]!['high'] = (grouped[type]!['high'] ?? 0) + 1;
      }

      return grouped.entries
          .map((e) => {'service_type': e.key, ...e.value})
          .toList()
        ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    } catch (e) {
      if (kDebugMode) print('Error fetching queue: $e');
      return [];
    }
  }
}
