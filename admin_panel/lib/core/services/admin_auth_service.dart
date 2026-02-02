import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

// Admin user model
class AdminUser {
  final String id;
  final String? userId;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String roleId;
  final String roleName;
  final String roleDisplayName;
  final Map<String, dynamic> permissions;
  final String status;
  final bool twoFactorEnabled;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  AdminUser({
    required this.id,
    this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.roleId,
    required this.roleName,
    required this.roleDisplayName,
    required this.permissions,
    required this.status,
    required this.twoFactorEnabled,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final role = json['admin_roles'] as Map<String, dynamic>?;
    return AdminUser(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      roleId: json['role_id'] as String? ?? '',
      roleName: role?['name'] as String? ?? '',
      roleDisplayName: role?['display_name'] as String? ?? '',
      permissions: role?['permissions'] as Map<String, dynamic>? ?? {},
      status: json['status'] as String? ?? 'active',
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool hasPermission(String module, String action) {
    if (roleName == 'super_admin') return true;
    final modulePermissions = permissions[module] as List<dynamic>?;
    return modulePermissions?.contains(action) ?? false;
  }

  bool get isSuperAdmin => roleName == 'super_admin';
  bool get isActive => status == 'active';
}

// Auth result
class AdminAuthResult {
  final bool isSuccess;
  final String? error;
  final AdminUser? admin;

  AdminAuthResult._({
    required this.isSuccess,
    this.error,
    this.admin,
  });

  factory AdminAuthResult.success(AdminUser admin) {
    return AdminAuthResult._(isSuccess: true, admin: admin);
  }

  factory AdminAuthResult.error(String message) {
    return AdminAuthResult._(isSuccess: false, error: message);
  }
}

// Admin auth service provider
final adminAuthServiceProvider = Provider<AdminAuthService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AdminAuthService(supabase);
});

// Current admin user provider
final currentAdminProvider = StateNotifierProvider<AdminNotifier, AsyncValue<AdminUser?>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AdminNotifier(supabase);
});

class AdminNotifier extends StateNotifier<AsyncValue<AdminUser?>> {
  final SupabaseClient _supabase;

  AdminNotifier(this._supabase) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await loadAdmin(user.id);
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> loadAdmin(String userId) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase
          .from('admin_users')
          .select('*, admin_roles(*)')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        state = AsyncValue.data(AdminUser.fromJson(response));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

class AdminAuthService {
  final SupabaseClient _supabase;

  AdminAuthService(this._supabase);

  // Admin login
  Future<AdminAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // First authenticate with Supabase Auth
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return AdminAuthResult.error('Giriş başarısız oldu');
      }

      // Check if user is an admin
      final adminResponse = await _supabase
          .from('admin_users')
          .select('*, admin_roles(*)')
          .eq('user_id', authResponse.user!.id)
          .maybeSingle();

      if (adminResponse == null) {
        await _supabase.auth.signOut();
        return AdminAuthResult.error('Bu hesap yönetici paneline erişim yetkisine sahip değil');
      }

      final admin = AdminUser.fromJson(adminResponse);

      if (!admin.isActive) {
        await _supabase.auth.signOut();
        return AdminAuthResult.error('Hesabınız askıya alınmış');
      }

      // Update last login
      await _supabase.from('admin_users').update({
        'last_login_at': DateTime.now().toIso8601String(),
      }).eq('id', admin.id);

      // Note: Login is logged by AdminLogService in login_screen.dart

      return AdminAuthResult.success(admin);
    } on AuthException catch (e) {
      return AdminAuthResult.error(_getErrorMessage(e.message));
    } catch (e) {
      return AdminAuthResult.error('Beklenmeyen bir hata oluştu: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get admin by user id
  Future<AdminUser?> getAdmin(String userId) async {
    try {
      final response = await _supabase
          .from('admin_users')
          .select('*, admin_roles(*)')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return AdminUser.fromJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _getErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı';
    }
    if (message.contains('Email not confirmed')) {
      return 'E-posta adresinizi doğrulamanız gerekiyor';
    }
    if (message.contains('rate limit')) {
      return 'Çok fazla deneme yaptınız. Lütfen biraz bekleyin.';
    }
    return message;
  }
}
