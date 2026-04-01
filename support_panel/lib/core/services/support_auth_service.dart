import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:support_panel/core/services/log_service.dart';
import '../models/support_models.dart';
import 'supabase_service.dart';

// Auth result
class SupportAuthResult {
  final bool isSuccess;
  final String? error;
  final SupportAgent? agent;

  SupportAuthResult._({required this.isSuccess, this.error, this.agent});

  factory SupportAuthResult.success(SupportAgent agent) {
    return SupportAuthResult._(isSuccess: true, agent: agent);
  }

  factory SupportAuthResult.error(String message) {
    return SupportAuthResult._(isSuccess: false, error: message);
  }
}

// Auth service provider
final supportAuthServiceProvider = Provider<SupportAuthService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SupportAuthService(supabase);
});

// Current agent provider
final currentAgentProvider = StateNotifierProvider<AgentNotifier, AsyncValue<SupportAgent?>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return AgentNotifier(supabase);
});

class AgentNotifier extends StateNotifier<AsyncValue<SupportAgent?>> {
  final SupabaseClient _supabase;

  AgentNotifier(this._supabase) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      await loadAgent(user.id);
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> loadAgent(String userId) async {
    state = const AsyncValue.loading();
    try {
      final response = await _supabase
          .from('support_agents')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final agent = SupportAgent.fromJson(response);
        // Set status to online on login
        await _supabase.from('support_agents').update({
          'status': 'online',
          'last_active_at': DateTime.now().toIso8601String(),
        }).eq('id', agent.id);
        state = AsyncValue.data(SupportAgent.fromJson({...response, 'status': 'online'}));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      LogService.error('Failed to load agent', error: e, stackTrace: st, source: 'CurrentAgentNotifier:loadAgent');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateStatus(String newStatus) async {
    final agent = state.value;
    if (agent == null) return;
    try {
      await _supabase.from('support_agents').update({
        'status': newStatus,
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', agent.id);
      state = AsyncValue.data(SupportAgent.fromJson({
        'id': agent.id,
        'user_id': agent.userId,
        'full_name': agent.fullName,
        'email': agent.email,
        'phone': agent.phone,
        'avatar_url': agent.avatarUrl,
        'permission_level': agent.permissionLevel,
        'status': newStatus,
        'max_concurrent_chats': agent.maxConcurrentChats,
        'active_chat_count': agent.activeChatCount,
        'specializations': agent.specializations,
        'shift_start': agent.shiftStart?.toIso8601String(),
        'shift_end': agent.shiftEnd?.toIso8601String(),
        'created_at': agent.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
      }));
    } catch (e, st) {
      LogService.error('Error syncing agent cache', error: e, stackTrace: st, source: 'CurrentAgentNotifier:loadAgent');
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

class SupportAuthService {
  final SupabaseClient _supabase;

  SupportAuthService(this._supabase);

  Future<SupportAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return SupportAuthResult.error('Giriş başarısız oldu');
      }

      final agentResponse = await _supabase
          .from('support_agents')
          .select()
          .eq('user_id', authResponse.user!.id)
          .maybeSingle();

      if (agentResponse == null) {
        await _supabase.auth.signOut();
        return SupportAuthResult.error('Bu hesap destek paneline erişim yetkisine sahip değil');
      }

      final agent = SupportAgent.fromJson(agentResponse);
      return SupportAuthResult.success(agent);
    } on AuthException catch (e) {
      return SupportAuthResult.error(_getErrorMessage(e.message));
    } catch (e, st) {
      LogService.error('Login failed', error: e, stackTrace: st, source: 'SupportAuthService:signIn');
      return SupportAuthResult.error('Beklenmeyen bir hata oluştu: $e');
    }
  }

  Future<void> signOut() async {
    // Set status to offline before signing out
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase
            .from('support_agents')
            .update({'status': 'offline', 'last_active_at': DateTime.now().toIso8601String()})
            .eq('user_id', user.id);
      } catch (e, st) {
        LogService.error('Error setting agent offline', error: e, stackTrace: st, source: 'SupportAuthService:signOut');
      }
    }
    await _supabase.auth.signOut();
  }

  String _getErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı';
    }
    if (message.contains('Email not confirmed')) {
      return 'E-posta adresinizi doğrulamanız gerekiyor';
    }
    if (message.contains('rate limit')) {
      return 'Çok fazla deneme yaptınız. Lütfen biraz bekleyin.';
    }
    return message;
  }
}
