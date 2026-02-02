import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const String supabaseUrl = 'https://mzgtvdgwxrlhgjboolys.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
}
