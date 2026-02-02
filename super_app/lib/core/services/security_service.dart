import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Security service for brute force protection
class SecurityService {
  static const String appSource = 'super_app';
  static SupabaseClient get _client => SupabaseService.client;

  /// Check if login is blocked for this email
  static Future<Map<String, dynamic>> checkLoginBlocked(String email) async {
    try {
      final response = await _client.rpc('check_login_blocked', params: {
        'p_email': email,
        'p_app_source': appSource,
      });
      return Map<String, dynamic>.from(response ?? {'is_blocked': false});
    } catch (e) {
      return {'is_blocked': false};
    }
  }

  /// Track a failed login attempt
  static Future<Map<String, dynamic>> trackFailedLogin({
    required String email,
    String? errorMessage,
  }) async {
    try {
      final response = await _client.rpc('track_failed_login', params: {
        'p_email': email,
        'p_error_message': errorMessage,
        'p_app_source': appSource,
      });
      return Map<String, dynamic>.from(response ?? {});
    } catch (e) {
      return {};
    }
  }

  /// Clear login blocks after successful login
  static Future<void> clearLoginBlocks(String email) async {
    try {
      await _client.rpc('clear_login_blocks', params: {
        'p_email': email,
        'p_app_source': appSource,
      });
    } catch (e) {
      // Silently fail
    }
  }

  /// Log a security event
  static Future<void> logSecurityEvent({
    required String eventType,
    required String severity,
    required String description,
    String? userId,
    String? email,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.rpc('log_security_event', params: {
        'p_event_type': eventType,
        'p_severity': severity,
        'p_description': description,
        'p_user_id': userId,
        'p_email': email,
        'p_metadata': {...?metadata, 'app_source': appSource},
      });
    } catch (e) {
      // Silently fail
    }
  }
}
