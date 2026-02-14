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
