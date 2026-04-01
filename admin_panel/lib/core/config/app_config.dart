import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase connection configuration.
///
/// Values are loaded from the .env file at runtime via flutter_dotenv.
/// Create a .env file in the project root with:
///   SUPABASE_URL=https://your-project.supabase.co
///   SUPABASE_ANON_KEY=your-anon-key
///   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
class AppConfig {
  AppConfig._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseServiceRoleKey =>
      dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
}
