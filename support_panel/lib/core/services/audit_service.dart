import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:support_panel/core/services/log_service.dart';
import 'supabase_service.dart';
import 'support_auth_service.dart';

final auditServiceProvider = Provider<AuditService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AuditService(supabase, ref);
});

class AuditService {
  final SupabaseClient _supabase;
  final Ref _ref;

  AuditService(this._supabase, this._ref);

  Future<void> log({
    required String actionType,
    required String actionDescription,
    String? targetType,
    String? targetId,
    String? targetName,
    String? ticketId,
    String? businessId,
    String? businessType,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    try {
      final agent = _ref.read(currentAgentProvider).value;
      if (agent == null) return;

      await _supabase.from('agent_actions_log').insert({
        'agent_id': agent.id,
        'agent_name': agent.fullName,
        'action_type': actionType,
        'action_description': actionDescription,
        'target_type': targetType,
        'target_id': targetId,
        'target_name': targetName,
        'ticket_id': ticketId,
        'business_id': businessId,
        'business_type': businessType,
        'old_data': oldData,
        'new_data': newData,
      });
    } catch (e, st) {
      LogService.error('Failed to log agent action', error: e, stackTrace: st, source: 'AuditService:logAction');
    }
  }

  Future<void> logLogin({required String email, required bool success, String? agentName, String? agentId}) async {
    final id = agentId ?? _ref.read(currentAgentProvider).value?.id;
    if (id == null) return; // Agent not loaded yet, skip logging
    try {
      await _supabase.from('agent_actions_log').insert({
        'agent_id': id,
        'agent_name': agentName ?? email,
        'action_type': 'login',
        'action_description': success
            ? '${agentName ?? email} başarıyla giriş yaptı'
            : '$email giriş denemesi başarısız',
      });
    } catch (e, st) {
      LogService.error('Failed to log login', error: e, stackTrace: st, source: 'AuditService:logLogin');
    }
  }

  Future<void> logTicketAction({
    required String action,
    required String ticketId,
    String? ticketSubject,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    await log(
      actionType: 'ticket_$action',
      actionDescription: 'Ticket ${action == 'create' ? 'oluşturuldu' : action == 'update' ? 'güncellendi' : action == 'assign' ? 'atandı' : action}',
      targetType: 'ticket',
      targetId: ticketId,
      targetName: ticketSubject,
      ticketId: ticketId,
      oldData: oldData,
      newData: newData,
    );
  }

  Future<void> logBusinessAction({
    required String action,
    required String businessId,
    required String businessType,
    String? businessName,
    String? ticketId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    await log(
      actionType: 'business_$action',
      actionDescription: 'İşletme proxy: $action',
      targetType: businessType,
      targetId: businessId,
      targetName: businessName,
      ticketId: ticketId,
      businessId: businessId,
      businessType: businessType,
      oldData: oldData,
      newData: newData,
    );
  }
}
