import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state stream
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange;
});

// Current user
final currentUserProvider = Provider<User?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.currentUser;
});

// Current session
final currentSessionProvider = Provider<Session?>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.currentSession;
});

class SupabaseService {
  static String get supabaseUrl => AppConfig.supabaseUrl;
  static String get supabaseAnonKey => AppConfig.supabaseAnonKey;

  static SupabaseClient get client => Supabase.instance.client;

  static SupabaseClient get adminClient => SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabaseServiceRoleKey,
  );

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
}
