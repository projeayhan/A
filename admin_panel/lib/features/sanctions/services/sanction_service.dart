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
          ) // Assumes a 'users' table relation
          .eq('status', 'active')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
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

    await _supabase.from('sanctions').insert({
      'user_id': userId,
      'reason': reason,
      'type': type,
      'status': 'active',
      'expires_at': expiryDate.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    // Also update user status in users table if it's a ban
    if (type == 'ban') {
      await _supabase
          .from('users')
          .update({'is_banned': true})
          .eq('id', userId);
    }
  }

  // Lift sanction
  Future<void> liftSanction(String id, String userId) async {
    await _supabase
        .from('sanctions')
        .update({
          'status': 'lifted',
          'lifted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);

    // Check if user has other active bans, if not, unban
    final otherBans = await _supabase
        .from('sanctions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .neq('id', id);

    if (otherBans.isEmpty) {
      await _supabase
          .from('users')
          .update({'is_banned': false})
          .eq('id', userId);
    }
  }

  // Search user by email or phone to sanction
  Future<Map<String, dynamic>?> searchUser(String query) async {
    final response = await _supabase
        .from('users')
        .select('id, full_name, email, phone')
        .or('email.eq.$query,phone.eq.$query')
        .maybeSingle();
    return response;
  }
}
