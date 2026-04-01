import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/log_service.dart';
import '../services/supabase_service.dart';
import '../services/taxi_service.dart';
import '../services/security_service.dart';

// Auth durumu
enum AuthStatus { initial, loading, authenticated, unauthenticated, pendingApproval, needsRegistration, error }

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
  StreamSubscription? _authSub;

  @override
  AuthState build() {
    ref.onDispose(() => _authSub?.cancel());
    _init();
    return const AuthState();
  }

  void _init() async {
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        await _loadDriverProfile(user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }

      // Auth değişikliklerini dinle
      _authSub = SupabaseService.authStateChanges.listen((authState) async {
        // Explicit auth işlemi sırasında (loading) listener'ın müdahale etmesini engelle
        if (state.status == AuthStatus.loading) return;
        if (authState.session != null) {
          await _loadDriverProfile(authState.session!.user);
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      });
    } catch (e, st) {
      LogService.error('_init error', error: e, stackTrace: st, source: 'AuthProvider:_init');
      state = AuthState(status: AuthStatus.error, errorMessage: 'Başlatma hatası');
    }
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
    } catch (e, st) {
      LogService.error('_checkUserRole error', error: e, stackTrace: st, source: 'AuthProvider:_checkUserRole');
      return {'role': 'none', 'message': 'Rol kontrolü başarısız'};
    }
  }

  Future<void> _loadDriverProfile(User user) async {
    final profile = await TaxiService.getDriverProfile();

    if (profile == null) {
      // Oturum açık ama sürücü profili yok → kayıt gerekli
      state = AuthState(
        status: AuthStatus.needsRegistration,
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
        return state.status == AuthStatus.authenticated
            || state.status == AuthStatus.pendingApproval
            || state.status == AuthStatus.needsRegistration;
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
    } catch (e, st) {
      LogService.error('signIn error', error: e, stackTrace: st, source: 'AuthProvider:signIn');
      await SecurityService.trackFailedLogin(identifier: email, errorMessage: 'Bir hata oluştu');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Bir hata oluştu',
      );
      return false;
    }
  }

  // Phone OTP - SMS gönder
  Future<bool> sendOtp({required String phone}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await SupabaseService.sendPhoneOtp(phone: phone);
      state = const AuthState(status: AuthStatus.unauthenticated);
      return true;
    } catch (e, st) {
      LogService.error('sendOtp error', error: e, stackTrace: st, source: 'AuthProvider:sendOtp');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // Phone OTP - Doğrula ve oturum aç
  Future<Map<String, dynamic>> verifyOtp({required String phone, required String code}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final result = await SupabaseService.verifyPhoneOtp(phone: phone, code: code);
      final user = SupabaseService.currentUser;
      if (user != null) {
        // OTP akışında rol kontrolü yapma - kullanıcı şoför olarak kayıt olmak istiyor olabilir.
        // _loadDriverProfile zaten doğru yönlendirmeyi yapar:
        // profil yoksa → needsRegistration, pending → pendingApproval, approved → authenticated
        await _loadDriverProfile(user);
      }
      return {
        'success': true,
        'is_new_user': result['is_new_user'] ?? false,
      };
    } catch (e, st) {
      LogService.error('verifyOtp error', error: e, stackTrace: st, source: 'AuthProvider:verifyOtp');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return {'success': false};
    }
  }

  // OTP kayıt sonrası profil oluştur
  Future<bool> completeRegistration({
    required String fullName,
    required String phone,
    required String tcNo,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehiclePlate,
    required String vehicleColor,
    required int vehicleYear,
    required List<String> vehicleTypes,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final profile = await TaxiService.createDriverProfile(
        fullName: fullName,
        phone: phone,
        tcNo: tcNo,
        vehicleBrand: vehicleBrand,
        vehicleModel: vehicleModel,
        vehiclePlate: vehiclePlate,
        vehicleColor: vehicleColor,
        vehicleYear: vehicleYear,
        vehicleTypes: vehicleTypes,
        email: SupabaseService.currentUser?.email,
      );
      if (profile != null) {
        state = AuthState(
          status: AuthStatus.pendingApproval,
          user: SupabaseService.currentUser,
          driverProfile: profile,
        );
        return true;
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Profil oluşturulamadı');
      return false;
    } catch (e, st) {
      LogService.error('completeRegistration error', error: e, stackTrace: st, source: 'AuthProvider:completeRegistration');
      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Bir hata oluştu: $e');
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
    required List<String> vehicleTypes,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      User? user;

      // Kayıt - trigger sürücü profilini otomatik oluşturur
      try {
        final response = await SupabaseService.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'phone': phone,
            'is_taxi_driver': 'true',
            'tc_no': tcNo,
            'vehicle_brand': vehicleBrand,
            'vehicle_model': vehicleModel,
            'vehicle_plate': vehiclePlate,
            'vehicle_color': vehicleColor,
            'vehicle_year': vehicleYear.toString(),
            'vehicle_types': vehicleTypes.join(','),
          },
        );
        user = response.user;
      } on AuthException catch (e) {
        if (e.message.contains('User already registered')) {
          // Kullanıcı zaten var (başka uygulamadan kayıtlı olabilir)
          try {
            final signInResponse = await SupabaseService.signIn(
              email: email,
              password: password,
            );
            user = signInResponse.user;
            final existingUser = user!;

            // Telefonu auth.users'a yaz (OTP login için)
            try { await SupabaseService.client.rpc('set_user_phone', params: {'p_user_id': existingUser.id, 'p_phone': phone}); } catch (e, st) { LogService.error('set_user_phone error', error: e, stackTrace: st, source: 'AuthProvider:registerDriver'); }

            // Zaten sürücü profili var mı kontrol et
            final existingProfile = await TaxiService.getDriverProfile();
            if (existingProfile != null) {
              await _loadDriverProfile(existingUser);
              return true;
            }
          } on AuthException {
            state = state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Bu e-posta başka bir uygulamamızda kayıtlı. Lütfen o uygulamada kullandığınız şifre ile deneyin veya farklı bir e-posta kullanın.',
            );
            return false;
          }
        } else {
          rethrow;
        }
      }

      if (user != null) {
        // Auto-confirm email (no email verification for taxi drivers)
        try { await SupabaseService.client.rpc('auto_confirm_email', params: {'p_user_id': user.id}); } catch (e, st) { LogService.error('auto_confirm_email error', error: e, stackTrace: st, source: 'AuthProvider:registerDriver'); }
        // Telefonu auth.users'a yaz (OTP login için)
        try { await SupabaseService.client.rpc('set_user_phone', params: {'p_user_id': user.id, 'p_phone': phone}); } catch (e, st) { LogService.error('set_user_phone error', error: e, stackTrace: st, source: 'AuthProvider:registerDriver'); }
        try { await SupabaseService.signOut(); } catch (e, st) { LogService.error('signOut error', error: e, stackTrace: st, source: 'AuthProvider:registerDriver'); }
        state = const AuthState(status: AuthStatus.unauthenticated);
        return true;
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
    } catch (e, st) {
      LogService.error('signUp error', error: e, stackTrace: st, source: 'AuthProvider:signUp');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Bir hata oluştu: $e',
      );
      return false;
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    TaxiService.invalidateProfileCache();
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
    if (message.contains('Email not confirmed')) {
      return 'E-posta adresinizi doğrulayınız. Lütfen e-postanızı kontrol edin.';
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
