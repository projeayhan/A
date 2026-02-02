import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'admin_auth_service.dart';

/// Log severity levels
enum LogSeverity {
  info,
  warning,
  error,
  critical,
}

/// Action types for logging
enum LogActionType {
  login,
  logout,
  create,
  update,
  delete,
  view,
  export,
  approve,
  reject,
  ban,
  unban,
}

/// Service for logging admin actions
class AdminLogService {
  final SupabaseClient _supabase;
  final Ref _ref;

  AdminLogService(this._supabase, this._ref);

  /// Log an admin action
  Future<void> log({
    required LogActionType actionType,
    required String action,
    String? targetTable,
    String? targetId,
    String? targetName,
    String? description,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    LogSeverity severity = LogSeverity.info,
  }) async {
    try {
      final admin = _ref.read(currentAdminProvider).value;

      await _supabase.from('admin_logs').insert({
        'admin_user_id': admin?.id,
        'admin_email': admin?.email,
        'admin_name': admin?.fullName,
        'action': action,
        'action_type': actionType.name,
        'target_table': targetTable,
        'target_id': targetId,
        'target_name': targetName,
        'description': description,
        'old_data': oldData,
        'new_data': newData,
        'severity': severity.name,
      });
    } catch (e) {
      // Silently fail - we don't want logging to break the app
      if (kDebugMode) print('Failed to log admin action: $e');
    }
  }

  /// Log a login attempt
  Future<void> logLogin({
    required String email,
    required bool success,
    String? adminUserId,
    String? adminName,
    String? errorMessage,
  }) async {
    try {
      await _supabase.from('admin_logs').insert({
        'admin_user_id': adminUserId,
        'admin_email': email,
        'admin_name': adminName,
        'action': success ? 'Giriş Yapıldı' : 'Giriş Başarısız',
        'action_type': 'login',
        'description': success
            ? '${adminName ?? email} başarıyla giriş yaptı'
            : '$email giriş denemesi başarısız: $errorMessage',
        'severity': success ? 'info' : 'warning',
      });
    } catch (e) {
      if (kDebugMode) print('Failed to log login: $e');
    }
  }

  /// Log a logout
  Future<void> logLogout() async {
    try {
      final admin = _ref.read(currentAdminProvider).value;

      await _supabase.from('admin_logs').insert({
        'admin_user_id': admin?.id,
        'admin_email': admin?.email,
        'admin_name': admin?.fullName,
        'action': 'Çıkış Yapıldı',
        'action_type': 'logout',
        'description': '${admin?.fullName ?? admin?.email} çıkış yaptı',
        'severity': 'info',
      });
    } catch (e) {
      if (kDebugMode) print('Failed to log logout: $e');
    }
  }

  /// Log user approval/rejection
  Future<void> logUserApproval({
    required String userType, // 'courier', 'taxi_driver', 'merchant'
    required String userId,
    required String userName,
    required bool approved,
    String? reason,
  }) async {
    await log(
      actionType: approved ? LogActionType.approve : LogActionType.reject,
      action: approved ? 'Onaylandı' : 'Reddedildi',
      targetTable: userType == 'courier' ? 'couriers'
          : userType == 'taxi_driver' ? 'taxi_drivers'
          : 'merchants',
      targetId: userId,
      targetName: userName,
      description: '$userName ${approved ? 'onaylandı' : 'reddedildi'}${reason != null ? ': $reason' : ''}',
      severity: LogSeverity.warning,
    );
  }

  /// Log user ban/unban
  Future<void> logUserBan({
    required String userType,
    required String userId,
    required String userName,
    required bool banned,
    String? reason,
  }) async {
    await log(
      actionType: banned ? LogActionType.ban : LogActionType.unban,
      action: banned ? 'Banlandı' : 'Ban Kaldırıldı',
      targetTable: userType,
      targetId: userId,
      targetName: userName,
      description: '$userName ${banned ? 'banlandı' : 'ban kaldırıldı'}${reason != null ? ': $reason' : ''}',
      severity: banned ? LogSeverity.critical : LogSeverity.warning,
    );
  }

  /// Log pricing change
  Future<void> logPricingChange({
    required String pricingType, // 'taxi', 'delivery', 'commission'
    required String description,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    await log(
      actionType: LogActionType.update,
      action: 'Fiyat Güncelleme',
      targetTable: pricingType == 'taxi' ? 'taxi_pricing'
          : pricingType == 'delivery' ? 'delivery_pricing'
          : 'platform_commissions',
      description: description,
      oldData: oldData,
      newData: newData,
      severity: LogSeverity.warning,
    );
  }

  /// Log order cancellation
  Future<void> logOrderCancellation({
    required String orderId,
    required String orderNumber,
    required String reason,
  }) async {
    await log(
      actionType: LogActionType.update,
      action: 'Sipariş İptali',
      targetTable: 'orders',
      targetId: orderId,
      targetName: orderNumber,
      description: 'Sipariş #$orderNumber iptal edildi: $reason',
      severity: LogSeverity.warning,
    );
  }

  /// Log data export
  Future<void> logExport({
    required String exportType,
    required String description,
  }) async {
    await log(
      actionType: LogActionType.export,
      action: 'Veri Dışa Aktarma',
      description: description,
      severity: LogSeverity.info,
    );
  }
}

/// Provider for AdminLogService
final adminLogServiceProvider = Provider<AdminLogService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AdminLogService(supabase, ref);
});
