import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection configuration.
///
/// Values are loaded from the .env file at runtime via flutter_dotenv.
/// Create a .env file in the project root with:
///   SUPABASE_URL=https://your-project.supabase.co
///   SUPABASE_ANON_KEY=your-anon-key
String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

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
