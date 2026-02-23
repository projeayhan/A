import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isAuthenticated => currentSession != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // Auth Methods
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  // Phone OTP - Twilio Verify üzerinden SMS gönder
  static Future<void> sendPhoneOtp({required String phone}) async {
    final response = await client.functions.invoke(
      'phone-verify',
      body: {'action': 'send', 'phone': phone},
    );
    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(data?['error'] ?? 'SMS gönderilemedi');
    }
  }

  // Phone OTP - Kodu doğrula ve oturum aç
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
    final refreshToken = data['refresh_token'] as String;
    await client.auth.setSession(refreshToken);
    return {
      'is_new_user': data['is_new_user'] ?? false,
      'user_id': data['user']?['id'],
    };
  }

  // Phone OTP - Sadece kodu doğrula (kullanıcı oluşturmaz, session açmaz)
  static Future<bool> verifyPhoneOnly({
    required String phone,
    required String code,
  }) async {
    final response = await client.functions.invoke(
      'phone-verify',
      body: {'action': 'verify_only', 'phone': phone, 'code': code},
    );
    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(data?['error'] ?? 'Doğrulama başarısız');
    }
    return true;
  }

}
