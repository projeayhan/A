import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/customer_360_model.dart';

final customerServiceProvider = Provider<CustomerService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return CustomerService(supabase);
});

class CustomerService {
  final SupabaseClient _supabase;

  CustomerService(this._supabase);

  Future<List<Map<String, dynamic>>> searchCustomers({
    required String query,
    int limit = 20,
  }) async {
    if (query.isEmpty) return [];

    try {
      // Search by name, phone, or email
      final results = await _supabase
          .from('users')
          .select('id, first_name, last_name, email, phone, avatar_url, membership_type, created_at, total_orders')
          .or('first_name.ilike.%$query%,last_name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
          .limit(limit);

      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      if (kDebugMode) print('Error searching customers: $e');
      return [];
    }
  }

  Future<Customer360?> getCustomer360(String userId) async {
    try {
      final result = await _supabase.rpc('get_customer_360', params: {'p_user_id': userId});

      if (result is Map<String, dynamic>) {
        if (result.containsKey('error')) return null;
        return Customer360.fromJson(result);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching customer 360: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      return await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }
}
