import 'package:supabase_flutter/supabase_flutter.dart';
import 'log_service.dart';
import 'supabase_service.dart';

/// Security service for brute force protection
class SecurityService {
  static const String appSource = 'taxi_app';
  static SupabaseClient get _client => SupabaseService.client;

  /// Check if login is blocked for this phone
  static Future<Map<String, dynamic>> checkLoginBlocked(String identifier) async {
    try {
      final response = await _client.rpc('check_login_blocked', params: {
        'p_email': identifier,
        'p_app_source': appSource,
      });
      return Map<String, dynamic>.from(response ?? {'is_blocked': false});
    } catch (e, st) {
      LogService.error('checkLoginBlocked error', error: e, stackTrace: st, source: 'SecurityService:checkLoginBlocked');
      return {'is_blocked': false};
    }
  }

  /// Track a failed login attempt
  static Future<Map<String, dynamic>> trackFailedLogin({
    required String identifier,
    String? errorMessage,
  }) async {
    try {
      final response = await _client.rpc('track_failed_login', params: {
        'p_email': identifier,
        'p_error_message': errorMessage,
        'p_app_source': appSource,
      });
      return Map<String, dynamic>.from(response ?? {});
    } catch (e, st) {
      LogService.error('trackFailedLogin error', error: e, stackTrace: st, source: 'SecurityService:trackFailedLogin');
      return {};
    }
  }

  /// Clear login blocks after successful login
  static Future<void> clearLoginBlocks(String identifier) async {
    try {
      await _client.rpc('clear_login_blocks', params: {
        'p_email': identifier,
        'p_app_source': appSource,
      });
    } catch (e, st) {
      LogService.error('clearLoginBlocks error', error: e, stackTrace: st, source: 'SecurityService:clearLoginBlocks');
    }
  }
}
