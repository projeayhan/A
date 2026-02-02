import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase URL ve Key
const String supabaseUrl = 'https://mzgtvdgwxrlhgjboolys.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY';

/// Initialize Supabase
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

/// Auth state changes stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Company ID provider - gets the company ID for the logged in user
final companyIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);

  // Check if user has a rental company
  final response = await client
      .from('rental_companies')
      .select('id')
      .eq('owner_user_id', user.id)
      .maybeSingle();

  return response?['id'] as String?;
});
