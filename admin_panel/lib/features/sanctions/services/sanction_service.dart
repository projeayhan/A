// NOTE: The 'sanctions' table does not yet exist in the database.
// A migration needs to be created with the following columns:
//   id (uuid, PK), user_id (uuid, FK to users), reason (text), type (text),
//   status (text), expires_at (timestamptz), lifted_at (timestamptz),
//   created_at (timestamptz), updated_at (timestamptz)
// All Supabase calls are wrapped in try-catch to prevent crashes until the table is created.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

final sanctionServiceProvider = Provider<SanctionService>((ref) {
  return SanctionService(ref.watch(supabaseProvider));
});

class SanctionService {
  final SupabaseClient _supabase;

  SanctionService(this._supabase);

  // Get active sanctions
  Future<List<Map<String, dynamic>>> getActiveSanctions() async {
    try {
      final response = await _supabase
          .from('sanctions')
          .select(
            '*, users:user_id(full_name, phone)',
          )
          .eq('status', 'active')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // sanctions table may not exist yet
      return <Map<String, dynamic>>[];
    }
  }

  // Create sanction (Ban)
  Future<void> imposeSanction({
    required String userId,
    required String reason,
    required int durationDays,
    required String type, // 'ban', 'warning', 'suspension'
  }) async {
    final expiryDate = DateTime.now().add(Duration(days: durationDays));

    try {
      await _supabase.from('sanctions').insert({
        'user_id': userId,
        'reason': reason,
        'type': type,
        'status': 'active',
        'expires_at': expiryDate.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // sanctions table may not exist yet
      throw Exception('Yaptırım oluşturma hatası (sanctions tablosu mevcut olmayabilir): $e');
    }

    // Also update user status in users table if it's a ban
    if (type == 'ban') {
      try {
        // Immediately invalidate all active sessions for the banned user
        await SupabaseService.adminClient.auth.admin.signOut(userId);
      } catch (_) {
        // Sign out may fail if user has no active sessions
      }
    }
  }

  // Lift sanction
  Future<void> liftSanction(String id, String userId) async {
    try {
      await _supabase
          .from('sanctions')
          .update({
            'status': 'lifted',
            'lifted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      // sanctions table may not exist yet
      throw Exception('Yaptırım kaldırma hatası (sanctions tablosu mevcut olmayabilir): $e');
    }
  }

  // Search user by email or phone to sanction
  Future<Map<String, dynamic>?> searchUser(String query) async {
    // Sanitize input: trim and enforce max length
    var cleanQuery = query.trim();
    if (cleanQuery.length > 100) cleanQuery = cleanQuery.substring(0, 100);

    // Strip characters that could manipulate PostgREST query syntax;
    // allow only alphanumeric, @, ., +, -, _
    cleanQuery = cleanQuery.replaceAll(RegExp(r'[^a-zA-Z0-9@.+\-_]'), '');

    if (cleanQuery.isEmpty) return null;

    try {
      // Search by email using safe parameterised API call
      final emailResult = await _supabase
          .from('users')
          .select('id, full_name, email, phone')
          .eq('email', cleanQuery)
          .maybeSingle();
      if (emailResult != null) return emailResult;

      // Fall back to searching by phone
      final phoneResult = await _supabase
          .from('users')
          .select('id, full_name, email, phone')
          .eq('phone', cleanQuery)
          .maybeSingle();
      return phoneResult;
    } catch (e) {
      // users table query failed
      return null;
    }
  }
}
