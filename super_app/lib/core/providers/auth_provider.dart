import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/security_service.dart';

// Auth State
enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription? _authSubscription;

  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    // Check initial auth state
    final user = SupabaseService.currentUser;
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    // Listen to auth changes - store subscription for cleanup
    _authSubscription = SupabaseService.authStateChanges.listen((authState) async {
      if (authState.session != null) {
        final user = authState.session!.user;

        // OAuth ile giriş yapıldıysa rol kontrolü yap
        if (authState.event == AuthChangeEvent.signedIn) {
          final roleCheck = await _checkUserRole(user.id);
          final roles = List<String>.from(roleCheck['roles'] ?? []);

          // Kullanıcının rolleri var ama customer veya admin değilse engelle
          if (roles.isNotEmpty && !roles.contains('customer') && !roles.contains('admin')) {
            await SupabaseService.signOut();
            state = AuthState(
              status: AuthStatus.error,
              errorMessage: 'Bu hesapla müşteri uygulamasına giriş yapamazsınız.',
            );
            return;
          }

          // Profil bilgilerini senkronize et
          await _syncUserProfile(user);
        }

        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // OAuth ile giriş yapan kullanıcının profil bilgilerini veritabanına kaydet
  Future<void> _syncUserProfile(User user) async {
    try {
      final metadata = user.userMetadata;
      final email = user.email;

      // Google'dan gelen bilgiler
      final fullName = metadata?['full_name'] ?? metadata?['name'] ?? '';
      final avatarUrl = metadata?['avatar_url'] ?? metadata?['picture'];

      // İsmi parçala
      final nameParts = fullName.toString().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Veritabanında kullanıcı var mı kontrol et
      final existing = await SupabaseService.client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existing == null) {
        // Yeni kullanıcı oluştur
        await SupabaseService.client.from('users').insert({
          'id': user.id,
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'avatar_url': avatarUrl,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Mevcut kullanıcıyı güncelle (boş alanları doldur)
        final updates = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (email != null) updates['email'] = email;
        if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

        // İsim alanları boşsa metadata'dan doldur
        final existingProfile = await SupabaseService.client
            .from('users')
            .select('first_name, last_name')
            .eq('id', user.id)
            .single();

        final existingFirst = existingProfile['first_name'] as String? ?? '';
        final existingLast = existingProfile['last_name'] as String? ?? '';

        if (existingFirst.isEmpty && firstName.isNotEmpty) {
          updates['first_name'] = firstName;
        }
        if (existingLast.isEmpty && lastName.isNotEmpty) {
          updates['last_name'] = lastName;
        }

        await SupabaseService.client
            .from('users')
            .update(updates)
            .eq('id', user.id);
      }
    } catch (e) {
      // Hata olursa sessizce devam et, giriş engellenmemeli
      print('Profile sync error: $e');
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
    } catch (e) {
      debugPrint('_checkUserRole error: $e');
      return {'role': 'none', 'message': 'Rol kontrolü başarısız'};
    }
  }

  // Email/Password Sign In with brute force protection
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // Check if login is blocked (brute force protection)
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
        state = AuthState(status: AuthStatus.error, errorMessage: message);
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

        // Kullanıcının rolleri var ama customer veya admin değilse engelle
        if (roles.isNotEmpty && !roles.contains('customer') && !roles.contains('admin')) {
          await SupabaseService.signOut();
          state = AuthState(
            status: AuthStatus.error,
            errorMessage: 'Bu hesapla müşteri uygulamasına giriş yapamazsınız.',
          );
          return false;
        }

        // Clear any previous failed login attempts on success
        await SecurityService.clearLoginBlocks(email);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        return true;
      }

      // Track failed login
      await SecurityService.trackFailedLogin(email: email, errorMessage: 'Giriş başarısız');
      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Giriş başarısız',
      );
      return false;
    } catch (e) {
      // Track failed login
      await SecurityService.trackFailedLogin(email: email, errorMessage: _getErrorMessage(e));
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  // Email/Password Sign Up
  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone},
      );

      if (response.user != null) {
        // After signup, always require email verification
        // (signOut + resend is handled in SupabaseService.signUp)
        state = const AuthState(status: AuthStatus.unauthenticated);
        return true;
      }

      state = const AuthState(
        status: AuthStatus.error,
        errorMessage: 'Kayıt başarısız',
      );
      return false;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  // Google Sign In
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final success = await SupabaseService.signInWithGoogle();
      if (!success) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Google ile giriş başarısız',
        );
      } else {
        // OAuth tarayıcıyı açtı, kullanıcı geri dönene kadar loading'den çık
        // Auth state listener callback'i aldığında authenticated yapacak
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      return success;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  // Apple Sign In
  Future<bool> signInWithApple() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final success = await SupabaseService.signInWithApple();
      if (!success) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Apple ile giriş başarısız',
        );
      } else {
        // OAuth tarayıcıyı açtı, kullanıcı geri dönene kadar loading'den çık
        // Auth state listener callback'i aldığında authenticated yapacak
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
      return success;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  // Reset Password
  Future<bool> resetPassword(String email) async {
    try {
      await SupabaseService.resetPassword(email);
      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _getErrorMessage(e),
      );
      return false;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await SupabaseService.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // Clear Error
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = AuthState(
        status: state.user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: state.user,
      );
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'E-posta veya şifre hatalı';
        case 'Email not confirmed':
          return 'E-posta adresinizi onaylayın';
        case 'User already registered':
          return 'Bu e-posta zaten kayıtlı';
        default:
          return error.message;
      }
    }
    return 'Bir hata oluştu';
  }
}

// Providers
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
