import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

// ==================== SERVICE PROVIDER ====================

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// ==================== CONVERSATIONS STATE ====================

class ConversationsState {
  final List<CarConversation> conversations;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  ConversationsState copyWith({
    List<CarConversation>? conversations,
    bool? isLoading,
    String? error,
    int? unreadCount,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ChatService _chatService;
  RealtimeChannel? _channel;
  Timer? _debounceTimer;

  ConversationsNotifier(this._chatService) : super(const ConversationsState()) {
    _init();
  }

  void _init() {
    loadConversations();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _channel = _chatService.subscribeToConversations(() {
      // Debounce to prevent excessive reloads
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        loadConversations();
      });
    });
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final conversations = await _chatService.getConversations();
      final unreadCount = await _chatService.getTotalUnreadCount();

      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
        unreadCount: unreadCount,
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return ConversationsNotifier(chatService);
});

// ==================== MESSAGES STATE ====================

class MessagesState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final CarConversation? conversation;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.conversation,
  });

  MessagesState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    CarConversation? conversation,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      conversation: conversation ?? this.conversation,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final ChatService _chatService;
  final String conversationId;
  RealtimeChannel? _channel;

  MessagesNotifier(this._chatService, this.conversationId)
      : super(const MessagesState()) {
    _init();
  }

  void _init() {
    loadMessages();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _channel = _chatService.subscribeToMessages(conversationId, (message) {
      // Mesaj zaten listede yoksa ekle
      if (!state.messages.any((m) => m.id == message.id)) {
        state = state.copyWith(
          messages: [...state.messages, message],
        );
      }
    });
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final conversation = await _chatService.getConversation(conversationId);
      final messages = await _chatService.getMessages(conversationId);

      // Mesajları okundu olarak işaretle
      await _chatService.markMessagesAsRead(conversationId);

      state = state.copyWith(
        messages: messages,
        conversation: conversation,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> sendMessage(String content) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await _chatService.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
      );

      if (message != null) {
        // Mesaj realtime ile gelebilir ama garantilemek için ekle
        if (!state.messages.any((m) => m.id == message.id)) {
          state = state.copyWith(
            messages: [...state.messages, message],
            isSending: false,
          );
        } else {
          state = state.copyWith(isSending: false);
        }
        return true;
      }

      state = state.copyWith(isSending: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> markAsRead() async {
    await _chatService.markMessagesAsRead(conversationId);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier,
    MessagesState, String>((ref, conversationId) {
  final chatService = ref.watch(chatServiceProvider);
  return MessagesNotifier(chatService, conversationId);
});

// ==================== UNREAD COUNT PROVIDER ====================

final unreadCountProvider = FutureProvider<int>((ref) async {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getTotalUnreadCount();
});

// ==================== CREATE CONVERSATION ====================

final createConversationProvider =
    FutureProvider.family<CarConversation?, CreateConversationParams>(
        (ref, params) async {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getOrCreateConversation(
    listingId: params.listingId,
    sellerId: params.sellerId,
  );
});

class CreateConversationParams {
  final String listingId;
  final String sellerId;

  CreateConversationParams({
    required this.listingId,
    required this.sellerId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateConversationParams &&
          runtimeType == other.runtimeType &&
          listingId == other.listingId &&
          sellerId == other.sellerId;

  @override
  int get hashCode => listingId.hashCode ^ sellerId.hashCode;
}
