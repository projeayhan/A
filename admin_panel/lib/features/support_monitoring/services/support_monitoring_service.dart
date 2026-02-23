import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';

final supportMonitoringServiceProvider = Provider<SupportMonitoringService>((ref) {
  return SupportMonitoringService(Supabase.instance.client);
});

class SupportMonitoringService {
  final SupabaseClient _client;

  SupportMonitoringService(this._client);

  Future<Map<String, dynamic>> getDashboardStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['p_start_date'] = startDate.toUtc().toIso8601String();
    if (endDate != null) params['p_end_date'] = endDate.toUtc().toIso8601String();
    final result = await _client.rpc('get_support_dashboard_stats', params: params);
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> getAgentPerformance({
    String? agentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (agentId != null) params['p_agent_id'] = agentId;
    if (startDate != null) params['p_start_date'] = startDate.toUtc().toIso8601String();
    if (endDate != null) params['p_end_date'] = endDate.toUtc().toIso8601String();
    final result = await _client.rpc('get_agent_performance_summary', params: params);
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getTickets({
    String? status,
    String? priority,
    String? serviceType,
    String? agentId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('support_tickets')
        .select('*, support_agents!support_tickets_assigned_agent_id_fkey(full_name, email)');

    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    if (priority != null && priority.isNotEmpty) query = query.eq('priority', priority);
    if (serviceType != null && serviceType.isNotEmpty) query = query.eq('service_type', serviceType);
    if (agentId != null && agentId.isNotEmpty) query = query.eq('assigned_agent_id', agentId);
    if (search != null && search.isNotEmpty) {
      final isNumeric = int.tryParse(search) != null;
      if (isNumeric) {
        query = query.or('customer_name.ilike.%$search%,subject.ilike.%$search%,ticket_number.eq.$search');
      } else {
        query = query.or('customer_name.ilike.%$search%,subject.ilike.%$search%');
      }
    }

    final result = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<int> getTicketCount({
    String? status,
    String? priority,
    String? serviceType,
    String? agentId,
    String? search,
  }) async {
    var query = _client.from('support_tickets').select('id');
    if (status != null && status.isNotEmpty) query = query.eq('status', status);
    if (priority != null && priority.isNotEmpty) query = query.eq('priority', priority);
    if (serviceType != null && serviceType.isNotEmpty) query = query.eq('service_type', serviceType);
    if (agentId != null && agentId.isNotEmpty) query = query.eq('assigned_agent_id', agentId);
    if (search != null && search.isNotEmpty) {
      final isNumeric = int.tryParse(search) != null;
      if (isNumeric) {
        query = query.or('customer_name.ilike.%$search%,subject.ilike.%$search%,ticket_number.eq.$search');
      } else {
        query = query.or('customer_name.ilike.%$search%,subject.ilike.%$search%');
      }
    }
    final result = await query;
    return (result as List).length;
  }

  Future<List<Map<String, dynamic>>> getTicketMessages(String ticketId) async {
    final result = await _client
        .from('ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAgentActions({
    String? agentId,
    String? ticketId,
    int limit = 50,
  }) async {
    var query = _client.from('agent_actions_log').select();
    if (agentId != null) query = query.eq('agent_id', agentId);
    if (ticketId != null) query = query.eq('ticket_id', ticketId);
    final result = await query.order('created_at', ascending: false).limit(limit);
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAgents() async {
    final result = await _client.from('support_agents').select().order('full_name');
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- Static Helpers ---

  static String formatDuration(int seconds) {
    if (seconds <= 0) return '-';
    if (seconds < 60) return '${seconds}sn';
    if (seconds < 3600) return '${(seconds / 60).round()}dk';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}sa ${m}dk';
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'open': return 'Acik';
      case 'assigned': return 'Atanmis';
      case 'in_progress': return 'Islemde';
      case 'waiting_customer': return 'Musteri Bekleniyor';
      case 'resolved': return 'Cozuldu';
      case 'closed': return 'Kapandi';
      default: return status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'open': return AppColors.info;
      case 'assigned': return AppColors.warning;
      case 'in_progress': return const Color(0xFF8B5CF6);
      case 'waiting_customer': return const Color(0xFFF97316);
      case 'resolved': return AppColors.success;
      case 'closed': return AppColors.textMuted;
      default: return AppColors.textMuted;
    }
  }

  static String priorityLabel(String priority) {
    switch (priority) {
      case 'low': return 'Dusuk';
      case 'normal': return 'Normal';
      case 'high': return 'Yuksek';
      case 'urgent': return 'Acil';
      default: return priority;
    }
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'low': return AppColors.textMuted;
      case 'normal': return AppColors.info;
      case 'high': return AppColors.warning;
      case 'urgent': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }

  static String serviceLabel(String type) {
    switch (type) {
      case 'food': return 'Yemek';
      case 'market': return 'Market';
      case 'store': return 'Magaza';
      case 'taxi': return 'Taksi';
      case 'rental': return 'Kiralama';
      case 'emlak': return 'Emlak';
      case 'car_sales': return 'Arac Satis';
      case 'general': return 'Genel';
      default: return type;
    }
  }

  static IconData serviceIcon(String type) {
    switch (type) {
      case 'food': return Icons.restaurant;
      case 'market': return Icons.shopping_cart;
      case 'store': return Icons.store;
      case 'taxi': return Icons.local_taxi;
      case 'rental': return Icons.car_rental;
      case 'emlak': return Icons.home_work;
      case 'car_sales': return Icons.directions_car;
      default: return Icons.help_outline;
    }
  }

  static Color serviceColor(String type) {
    switch (type) {
      case 'food': return AppColors.warning;
      case 'market': return AppColors.success;
      case 'store': return AppColors.info;
      case 'taxi': return const Color(0xFF8B5CF6);
      case 'rental': return AppColors.primary;
      case 'emlak': return const Color(0xFFEC4899);
      case 'car_sales': return const Color(0xFFF97316);
      default: return AppColors.textMuted;
    }
  }
}
