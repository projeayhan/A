import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/job_chat_service.dart';

// ============================================
// SERVİS PROVIDER
// ============================================

final jobChatServiceProvider = Provider<JobChatService>((ref) {
  return JobChatService();
});

// ============================================
// KONUŞMALAR PROVIDER
// ============================================

class JobConversationsState {
  final List<JobConversation> conversations;
  final bool isLoading;
  final String? error;

  const JobConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  JobConversationsState copyWith({
    List<JobConversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return JobConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class JobConversationsNotifier extends StateNotifier<JobConversationsState> {
  final JobChatService _service;

  JobConversationsNotifier(this._service) : super(const JobConversationsState()) {
    loadConversations();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conversations = await _service.getConversations();
      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadConversations();
  }
}

final jobConversationsProvider =
    StateNotifierProvider<JobConversationsNotifier, JobConversationsState>((ref) {
  final service = ref.watch(jobChatServiceProvider);
  return JobConversationsNotifier(service);
});

// ============================================
// MESAJLAR PROVIDER
// ============================================

class JobMessagesState {
  final List<JobChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const JobMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  JobMessagesState copyWith({
    List<JobChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return JobMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class JobMessagesNotifier extends StateNotifier<JobMessagesState> {
  final JobChatService _service;
  final String conversationId;
  RealtimeChannel? _channel;

  JobMessagesNotifier(this._service, this.conversationId) : super(const JobMessagesState()) {
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _service.getMessages(conversationId);
      state = state.copyWith(
        messages: messages.reversed.toList(), // chronological order
        isLoading: false,
      );
      // Mesajları okundu olarak işaretle
      _service.markMessagesAsRead(conversationId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribeToMessages() {
    _channel = _service.subscribeToNewMessages(
      conversationId,
      (message) {
        // Duplicat kontrolü
        if (state.messages.any((m) => m.id == message.id)) return;
        state = state.copyWith(
          messages: [...state.messages, message],
        );
        // Okundu olarak işaretle (açık ekranda olduğumuz için)
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null && message.senderId != userId) {
          _service.markMessagesAsRead(conversationId);
        }
      },
    );
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    state = state.copyWith(isSending: true);

    final message = await _service.sendMessage(
      conversationId: conversationId,
      content: content.trim(),
    );

    if (message != null) {
      // Realtime subscription ile gelecek, ama duplicate kontrolü var
      if (!state.messages.any((m) => m.id == message.id)) {
        state = state.copyWith(
          messages: [...state.messages, message],
          isSending: false,
        );
      } else {
        state = state.copyWith(isSending: false);
      }
    } else {
      state = state.copyWith(isSending: false, error: 'Mesaj gönderilemedi');
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      _service.unsubscribe(_channel!);
    }
    super.dispose();
  }
}

final jobMessagesProvider =
    StateNotifierProvider.autoDispose.family<JobMessagesNotifier, JobMessagesState, String>(
  (ref, conversationId) {
    final service = ref.watch(jobChatServiceProvider);
    return JobMessagesNotifier(service, conversationId);
  },
);

// ============================================
// OKUNMAMIŞ MESAJ SAYISI PROVIDER
// ============================================

final jobUnreadCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(jobChatServiceProvider);
  return service.getTotalUnreadCount();
});
