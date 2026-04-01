import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/courier_service.dart';
import '../services/log_service.dart';
import '../services/security_service.dart';
import '../services/push_notification_service.dart';

// Auth durumu
enum AuthStatus { initial, loading, authenticated, unauthenticated, pendingApproval, needsRegistration, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final Map<String, dynamic>? courierProfile;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.courierProfile,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    Map<String, dynamic>? courierProfile,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      courierProfile: courierProfile ?? this.courierProfile,
      errorMessage: errorMessage,
    );
  }

  bool get isApproved => courierProfile?['status'] == 'approved';
  bool get isPending => courierProfile?['status'] == 'pending';
  String get courierName => courierProfile?['full_name'] ?? 'Kurye';
  String get courierEmail => user?.email ?? '';
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
        await _loadCourierProfile(user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }

      // Auth değişikliklerini dinle
      _authSub = SupabaseService.authStateChanges.listen((authState) async {
        // Explicit auth işlemi sırasında (loading) listener'ın müdahale etmesini engelle
        if (state.status == AuthStatus.loading) return;
        if (authState.session != null) {
          await _loadCourierProfile(authState.session!.user);
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      });
    } catch (e, st) {
      LogService.error('_init error', error: e, stackTrace: st, source: 'AuthProvider:_init');
      state = const AuthState(status: AuthStatus.unauthenticated);
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

  Future<void> _loadCourierProfile(User user) async {
    final profile = await CourierService.getCourierProfile();

    if (profile == null) {
      // Oturum açık ama kurye profili yok → kayıt gerekli
      state = AuthState(
        status: AuthStatus.needsRegistration,
        user: user,
      );
    } else if (profile['status'] == 'pending') {
      // Onay bekliyor
      state = AuthState(
        status: AuthStatus.pendingApproval,
        user: user,
        courierProfile: profile,
      );
      // FCM token kaydet (push bildirim için)
      pushNotificationService.saveTokenIfNeeded();
    } else if (profile['status'] == 'approved') {
      // Onaylı kurye
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        courierProfile: profile,
      );
      // FCM token kaydet
      pushNotificationService.saveTokenIfNeeded();
    } else {
      // Reddedilmiş veya askıya alınmış
      state = AuthState(
        status: AuthStatus.error,
        user: user,
        courierProfile: profile,
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

        // Kullanıcının rolleri var ama courier veya admin değilse engelle
        if (roles.isNotEmpty && !roles.contains('courier') && !roles.contains('admin')) {
          await SupabaseService.signOut();
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: 'Bu hesapla kurye uygulamasına giriş yapamazsınız.',
          );
          return false;
        }

        await SecurityService.clearLoginBlocks(email);
        await _loadCourierProfile(response.user!);
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

  // Phone OTP - SMS gönder (kayıt sırasında telefon doğrulama için)
  Future<bool> sendOtp({required String phone}) async {
    try {
      await SupabaseService.sendPhoneOtp(phone: phone);
      return true;
    } catch (e, st) {
      LogService.error('sendOtp error', error: e, stackTrace: st, source: 'AuthProvider:sendOtp');
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // Phone OTP - Sadece doğrula (session açmaz, kullanıcı oluşturmaz)
  Future<bool> verifyPhoneOnly({required String phone, required String code}) async {
    try {
      await SupabaseService.verifyPhoneOnly(phone: phone, code: code);
      return true;
    } catch (e, st) {
      LogService.error('verifyPhoneOnly error', error: e, stackTrace: st, source: 'AuthProvider:verifyPhoneOnly');
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // E-posta ile kayıt ol: hesap oluştur + giriş yap + kurye profili oluştur
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String tcNo,
    required String vehicleType,
    required String vehiclePlate,
    String? bankName,
    String? bankIban,
    String workMode = 'platform',
    String? merchantId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      User? user;

      // 1. E-posta + şifre ile hesap oluştur
      try {
        final response = await SupabaseService.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'phone': phone,
            'is_courier': 'true',
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

            // Zaten kurye profili var mı kontrol et
            final existingProfile = await CourierService.getCourierProfile();
            if (existingProfile != null) {
              await _loadCourierProfile(user!);
              return true;
            }
            // Profil yok, devam et oluşturacağız
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

      if (user == null) {
        state = state.copyWith(status: AuthStatus.error, errorMessage: 'Kayıt başarısız');
        return false;
      }

      // 2. E-postayı onayla & telefonu kaydet
      try { await SupabaseService.client.rpc('auto_confirm_email', params: {'p_user_id': user.id}); } catch (e, st) { LogService.error('auto_confirm_email error', error: e, stackTrace: st, source: 'AuthProvider:register'); }
      try { await SupabaseService.client.rpc('set_user_phone', params: {'p_user_id': user.id, 'p_phone': phone}); } catch (e, st) { LogService.error('set_user_phone error', error: e, stackTrace: st, source: 'AuthProvider:register'); }

      // 3. Henüz giriş yapmamışsak (yeni kayıt), giriş yap
      if (SupabaseService.currentUser == null) {
        try { await SupabaseService.signOut(); } catch (e, st) { LogService.error('signOut error', error: e, stackTrace: st, source: 'AuthProvider:register'); }
        await SupabaseService.signIn(email: email, password: password);
      }

      // 4. Kurye profilini oluştur
      final success = await CourierService.createCourierProfile(
        fullName: fullName,
        phone: phone,
        tcNo: tcNo,
        vehicleType: vehicleType,
        vehiclePlate: vehiclePlate,
        bankName: bankName,
        bankIban: bankIban,
        workMode: workMode,
        merchantId: merchantId,
      );

      if (success) {
        final currentUser = SupabaseService.currentUser;
        if (currentUser != null) {
          await _loadCourierProfile(currentUser);
        }
        return true;
      }

      state = state.copyWith(status: AuthStatus.error, errorMessage: 'Profil oluşturulamadı');
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e.message),
      );
      return false;
    } catch (e, st) {
      LogService.error('registerWithEmail error', error: e, stackTrace: st, source: 'AuthProvider:registerWithEmail');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Bir hata oluştu: $e',
      );
      return false;
    }
  }

  // Mevcut kullanıcıya kurye profili oluştur (needsRegistration durumu için)
  Future<bool> completeRegistration({
    required String fullName,
    required String phone,
    required String tcNo,
    required String vehicleType,
    required String vehiclePlate,
    String? bankName,
    String? bankIban,
    String workMode = 'platform',
    String? merchantId,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // Telefonu kaydet
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        try { await SupabaseService.client.rpc('set_user_phone', params: {'p_user_id': userId, 'p_phone': phone}); } catch (e, st) { LogService.error('set_user_phone error', error: e, stackTrace: st, source: 'AuthProvider:completeRegistration'); }
      }

      final success = await CourierService.createCourierProfile(
        fullName: fullName,
        phone: phone,
        tcNo: tcNo,
        vehicleType: vehicleType,
        vehiclePlate: vehiclePlate,
        bankName: bankName,
        bankIban: bankIban,
        workMode: workMode,
        merchantId: merchantId,
      );
      if (success) {
        final user = SupabaseService.currentUser;
        if (user != null) {
          await _loadCourierProfile(user);
        }
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

  // Çıkış yap
  Future<void> signOut() async {
    await pushNotificationService.deleteToken();
    CourierService.invalidateProfileCache();
    await SupabaseService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // Profili yenile
  Future<void> refreshProfile() async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      await _loadCourierProfile(user);
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
