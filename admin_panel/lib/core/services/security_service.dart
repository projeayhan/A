import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Security monitoring service
class SecurityService {
  final SupabaseClient _supabase;

  SecurityService(this._supabase);

  /// Get security dashboard stats
  Future<Map<String, dynamic>> getSecurityStats({int hours = 24}) async {
    final response = await _supabase.rpc('get_security_stats', params: {
      'p_hours': hours,
    });
    return Map<String, dynamic>.from(response ?? {});
  }

  /// Get recent security events
  Future<List<Map<String, dynamic>>> getSecurityEvents({
    int limit = 100,
    String? eventType,
    String? severity,
    bool? unresolvedOnly,
  }) async {
    var query = _supabase.from('security_events').select('*');

    if (eventType != null && eventType.isNotEmpty) {
      query = query.eq('event_type', eventType);
    }
    if (severity != null && severity.isNotEmpty) {
      query = query.eq('severity', severity);
    }
    if (unresolvedOnly == true) {
      query = query.eq('resolved', false);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get failed login attempts
  Future<List<Map<String, dynamic>>> getFailedLogins({
    int limit = 100,
    bool? blockedOnly,
  }) async {
    var query = _supabase.from('failed_login_attempts').select('*');

    if (blockedOnly == true) {
      query = query.eq('is_blocked', true);
    }

    final response = await query
        .order('last_attempt_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get system errors
  Future<List<Map<String, dynamic>>> getSystemErrors({
    int limit = 100,
    String? errorType,
    String? severity,
    bool? unresolvedOnly,
  }) async {
    var query = _supabase.from('system_errors').select('*');

    if (errorType != null && errorType.isNotEmpty) {
      query = query.eq('error_type', errorType);
    }
    if (severity != null && severity.isNotEmpty) {
      query = query.eq('severity', severity);
    }
    if (unresolvedOnly == true) {
      query = query.eq('resolved', false);
    }

    final response = await query
        .order('last_occurred_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Resolve a security event
  Future<void> resolveSecurityEvent(String eventId, String notes) async {
    await _supabase.from('security_events').update({
      'resolved': true,
      'resolved_at': DateTime.now().toIso8601String(),
      'resolution_notes': notes,
    }).eq('id', eventId);
  }

  /// Resolve a system error
  Future<void> resolveSystemError(String errorId) async {
    await _supabase.from('system_errors').update({
      'resolved': true,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', errorId);
  }

  /// Unblock an IP/email
  Future<void> unblockLogin(String attemptId) async {
    await _supabase.from('failed_login_attempts').update({
      'is_blocked': false,
      'blocked_until': null,
    }).eq('id', attemptId);
  }

  /// Log a security event from Flutter
  Future<void> logSecurityEvent({
    required String eventType,
    required String severity,
    required String description,
    String? userId,
    String? email,
    Map<String, dynamic>? metadata,
  }) async {
    await _supabase.rpc('log_security_event', params: {
      'p_event_type': eventType,
      'p_severity': severity,
      'p_description': description,
      'p_user_id': userId,
      'p_email': email,
      'p_metadata': metadata ?? {},
    });
  }

  /// Log a system error from Flutter
  Future<void> logSystemError({
    required String errorType,
    required String errorMessage,
    String? errorCode,
    String? stackTrace,
    String? endpoint,
    String? userId,
    String severity = 'error',
  }) async {
    await _supabase.rpc('log_system_error', params: {
      'p_error_type': errorType,
      'p_error_message': errorMessage,
      'p_error_code': errorCode,
      'p_stack_trace': stackTrace,
      'p_service': 'flutter',
      'p_endpoint': endpoint,
      'p_user_id': userId,
      'p_severity': severity,
    });
  }

  /// Check if login is blocked
  Future<Map<String, dynamic>> checkLoginBlocked(String email) async {
    final response = await _supabase.rpc('check_login_blocked', params: {
      'p_email': email,
    });
    return Map<String, dynamic>.from(response ?? {'is_blocked': false});
  }

  /// Track failed login
  Future<Map<String, dynamic>> trackFailedLogin({
    required String email,
    String? errorMessage,
  }) async {
    final response = await _supabase.rpc('track_failed_login', params: {
      'p_email': email,
      'p_error_message': errorMessage,
    });
    return Map<String, dynamic>.from(response ?? {});
  }

  /// Clear login blocks after successful login
  Future<void> clearLoginBlocks(String email) async {
    await _supabase.rpc('clear_login_blocks', params: {
      'p_email': email,
    });
  }
}

/// Provider for SecurityService
final securityServiceProvider = Provider<SecurityService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SecurityService(supabase);
});

/// Provider for security stats
final securityStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(securityServiceProvider);
  return service.getSecurityStats();
});
