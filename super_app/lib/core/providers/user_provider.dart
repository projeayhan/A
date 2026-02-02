import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/profile_service.dart';
export '../services/profile_service.dart' show UserProfile;

class UserProfileNotifier extends StateNotifier<UserProfile?> {
  StreamSubscription<AuthState>? _authSubscription;

  UserProfileNotifier() : super(null) {
    _init();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription = SupabaseService.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedIn) {
        // Kullanıcı giriş yaptı, profili yükle
        Future.delayed(const Duration(milliseconds: 500), () {
          _init();
        });
      } else if (authState.event == AuthChangeEvent.signedOut) {
        // Kullanıcı çıkış yaptı, state'i temizle
        state = null;
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      state = null;
      return;
    }

    final profile = await ProfileService.getUserProfile(user.id);
    state = profile;
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return false;

    // Note: ProfileService.updateProfile currently only updates name/phone/avatar via helper
    // We might need to extend ProfileService if we want to update everything,
    // OR we can keep the direct update logic here if ProfileService is limited.
    // Looking at ProfileService (Step 499), it updates first_name, last_name, phone, avatar_url.
    // It DOES NOT update email, date_of_birth, gender.

    // So for now, to support the full Personal Info screen features, I will keep the direct update logic
    // BUT I must make sure it returns the correct UserProfile object compatible with the service.

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      // email update usually requires auth flow, but if we are updating public.users table email column:
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (dateOfBirth != null) {
        updates['date_of_birth'] = dateOfBirth.toIso8601String().split('T')[0];
      }
      if (gender != null) updates['gender'] = gender;

      final response = await SupabaseService.client
          .from('users')
          .update(updates)
          .eq('id', user.id)
          .select()
          .single();

      state = UserProfile.fromJson(response);
      return true;
    } catch (e) {
      if (kDebugMode) print('Error updating profile: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await _init();
  }
}

// Rename to avoid conflict with profile_provider.dart if imported together,
// OR keep it and force aliasing.
// Let's keep it as userProfileProvider since personal_info_screen uses it.
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) {
      return UserProfileNotifier();
    });
