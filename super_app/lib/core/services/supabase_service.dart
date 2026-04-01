import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  // Auth Methods
  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isLoggedIn => currentUser != null;

  // Email/Password Sign Up
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );

    // signUp() already sends confirmation email, just sign out the auto-session
    if (response.user != null && response.session != null) {
      await client.auth.signOut();
    }

    return response;
  }

  // Email/Password Sign In
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Google Sign In
  static Future<bool> signInWithGoogle() async {
    // Web'de null kullanılırsa mevcut URL'e redirect yapılır
    // Mobil'de deep link kullanılır
    final redirectUrl = kIsWeb ? null : 'io.supabase.superapp://login-callback/';

    final response = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
    );
    return response;
  }

  // Apple Sign In
  static Future<bool> signInWithApple() async {
    final redirectUrl = kIsWeb ? null : 'io.supabase.superapp://login-callback/';

    final response = await client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: redirectUrl,
    );
    return response;
  }

  // Phone OTP - Send code via Twilio Verify (edge function)
  static Future<void> sendPhoneOtp({required String phone}) async {
    try {
      final response = await client.functions.invoke(
        'phone-verify',
        body: {'action': 'send', 'phone': phone},
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] ?? 'SMS gönderilemedi');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('SMS gönderilirken hata oluştu: $e');
    }
  }

  // Phone OTP - Verify code via Twilio Verify (edge function)
  static Future<Map<String, dynamic>> verifyPhoneOtp({
    required String phone,
    required String code,
  }) async {
    final response = await client.functions.invoke(
      'phone-verify',
      body: {'action': 'verify', 'phone': phone, 'code': code},
    );

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(data?['error'] ?? 'Doğrulama başarısız');
    }

    // Set session from edge function tokens
    final refreshToken = data['refresh_token'] as String?;
    if (refreshToken == null) {
      throw Exception('Oturum token\'ı alınamadı');
    }
    await client.auth.setSession(refreshToken);

    return {
      'is_new_user': data['is_new_user'] ?? false,
      'user_id': data['user']?['id'],
    };
  }

  // Update user profile (name etc. after OTP registration)
  static Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
  }) async {
    await client.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': '$firstName $lastName',
          'first_name': firstName,
          'last_name': lastName,
        },
      ),
    );
  }

  // Password Reset
  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // Sign Out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Listen to Auth State Changes
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Session'ı yenile (token süresi dolmuşsa)
  static Future<bool> refreshSession() async {
    try {
      final session = currentSession;
      if (session == null) return false;

      // Token'ın süresini kontrol et
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final now = DateTime.now();

        // Eğer token 5 dakika içinde dolacaksa veya dolmuşsa, yenile
        if (expiryDate.difference(now).inMinutes < 5) {
          final response = await client.auth.refreshSession();
          return response.session != null;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Geçerli bir session olup olmadığını kontrol et
  static Future<bool> ensureValidSession() async {
    if (currentUser == null) return false;
    return await refreshSession();
  }

  // Kullanıcının OAuth ile mi kayıt olduğunu kontrol et (şifresi yok)
  static bool get isOAuthUser {
    final user = currentUser;
    if (user == null) return false;

    // identities listesinde sadece OAuth provider varsa
    final identities = user.identities ?? [];
    if (identities.isEmpty) return false;

    // Email provider yoksa OAuth kullanıcısıdır
    return !identities.any((i) => i.provider == 'email');
  }

  // Kullanıcının onaylanmış e-postası var mı
  static String? get userEmail => currentUser?.email;
  static bool get hasConfirmedEmail => currentUser?.emailConfirmedAt != null;

  // E-posta güncelleme (doğrulama maili gönderir)
  static Future<void> updateEmail(String newEmail) async {
    await client.auth.updateUser(UserAttributes(email: newEmail));
  }

  // OAuth kullanıcısı için şifre belirleme
  static Future<void> setPassword(String newPassword) async {
    await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Mevcut şifreyi değiştirme (şifreyle giriş yapanlar için)
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    if (user?.email == null) throw Exception('Kullanıcı bulunamadı');

    // Önce mevcut şifreyle doğrula
    await client.auth.signInWithPassword(
      email: user!.email!,
      password: currentPassword,
    );

    // Sonra yeni şifreyi ayarla
    await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
