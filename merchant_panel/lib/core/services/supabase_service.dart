import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase client provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Alias for supabaseClientProvider
final supabaseClientProvider = supabaseProvider;

// Auth state stream - listens to auth changes reactively
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange;
});

// Current user - reactive based on auth state
final currentUserProvider = Provider<User?>((ref) {
  // Watch auth state to trigger updates on auth changes
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session?.user,
  ) ?? Supabase.instance.client.auth.currentUser;
});

// Current session - reactive based on auth state
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session,
  ) ?? Supabase.instance.client.auth.currentSession;
});

// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

class SupabaseService {
  static const String supabaseUrl = 'https://mzgtvdgwxrlhgjboolys.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
}
