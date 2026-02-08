import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/taxi_service.dart';
import '../services/security_service.dart';

// Auth durumu
enum AuthStatus { initial, loading, authenticated, unauthenticated, pendingApproval, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final Map<String, dynamic>? driverProfile;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.driverProfile,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    Map<String, dynamic>? driverProfile,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      driverProfile: driverProfile ?? this.driverProfile,
      errorMessage: errorMessage,
    );
  }

  bool get isApproved => driverProfile?['status'] == 'approved';
  bool get isPending => driverProfile?['status'] == 'pending';
  String get driverName => driverProfile?['full_name'] ?? 'Sürücü';
  String get driverEmail => user?.email ?? '';
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  void _init() async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      await _loadDriverProfile(user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    // Auth değişikliklerini dinle
    SupabaseService.authStateChanges.listen((authState) async {
      if (authState.session != null) {
        await _loadDriverProfile(authState.session!.user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  // Kullanıcının rolünü kontrol et
  Future<Map<String, dynamic>> _checkUserRole(String userId) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_user_role',
        params: {'check_user_id': userId},
      );
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return {'role': 'none', 'message': 'Rol bulunamadı'};
    } catch (e) {
      debugPrint('_checkUserRole error: $e');
      return {'role': 'none', 'message': 'Rol kontrolü başarısız'};
    }
  }

  Future<void> _loadDriverProfile(User user) async {
    final profile = await TaxiService.getDriverProfile();

    if (profile == null) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        user: user,
      );
    } else if (profile['status'] == 'pending') {
      state = AuthState(
        status: AuthStatus.pendingApproval,
        user: user,
        driverProfile: profile,
      );
    } else if (profile['status'] == 'approved') {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        driverProfile: profile,
      );
    } else {
      state = AuthState(
        status: AuthStatus.error,
        user: user,
        driverProfile: profile,
        errorMessage: 'Hesabınız askıya alınmış',
      );
    }
  }

  // Giriş yap (brute force korumalı)
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // Brute force kontrolü
      final blockStatus = await SecurityService.checkLoginBlocked(email);
      if (blockStatus['is_blocked'] == true) {
        final blockedUntil = blockStatus['blocked_until'];
        String message = 'Çok fazla başarısız deneme. Hesabınız geçici olarak engellendi.';
        if (blockedUntil != null) {
          final until = DateTime.tryParse(blockedUntil.toString());
          if (until != null) {
            final minutes = until.difference(DateTime.now()).inMinutes;
            if (minutes > 0) {
              message = 'Hesabınız $minutes dakika süreyle engellendi.';
            }
          }
        }
        state = state.copyWith(status: AuthStatus.error, errorMessage: message);
        return false;
      }

      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Kullanıcının rollerini kontrol et
        final roleCheck = await _checkUserRole(response.user!.id);
        final roles = List<String>.from(roleCheck['roles'] ?? []);

        // Kullanıcının rolleri var ama taxi_driver veya admin değilse engelle
        if (roles.isNotEmpty && !roles.contains('taxi_driver') && !roles.contains('admin')) {
          await SupabaseService.signOut();
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Bu hesapla taksi uygulamasına giriş yapamazsınız.',
          );
          return false;
        }

        await SecurityService.clearLoginBlocks(email);
        await _loadDriverProfile(response.user!);
        return state.status == AuthStatus.authenticated || state.status == AuthStatus.pendingApproval;
      }

      await SecurityService.trackFailedLogin(identifier: email, errorMessage: 'Giriş başarısız');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Giriş başarısız',
      );
      return false;
    } on AuthException catch (e) {
      await SecurityService.trackFailedLogin(identifier: email, errorMessage: _getErrorMessage(e.message));
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e.message),
      );
      return false;
    } catch (e) {
      await SecurityService.trackFailedLogin(identifier: email, errorMessage: 'Bir hata oluştu');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Bir hata oluştu',
      );
      return false;
    }
  }

  // Kayıt ol
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String tcNo,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehiclePlate,
    required String vehicleColor,
    required int vehicleYear,
    required String vehicleType,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone},
      );

      if (response.user != null) {
        final driverProfile = await TaxiService.createDriverProfile(
          fullName: fullName,
          phone: phone,
          tcNo: tcNo,
          vehicleBrand: vehicleBrand,
          vehicleModel: vehicleModel,
          vehiclePlate: vehiclePlate,
          vehicleColor: vehicleColor,
          vehicleYear: vehicleYear,
          vehicleType: vehicleType,
        );

        if (driverProfile != null) {
          await _loadDriverProfile(response.user!);
          return true;
        }
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Kayıt başarısız',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Bir hata oluştu: $e',
      );
      return false;
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    await SupabaseService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // Profili yenile
  Future<void> refreshProfile() async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      await _loadDriverProfile(user);
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  String _getErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı';
    }
    if (message.contains('User already registered')) {
      return 'Bu e-posta zaten kayıtlı';
    }
    if (message.contains('Password should be at least')) {
      return 'Şifre en az 6 karakter olmalı';
    }
    return message;
  }
}

// Providers
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
