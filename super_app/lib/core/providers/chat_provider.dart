import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/emlak/chat_service.dart';
import '../../services/emlak/appointment_service.dart';

// ============================================
// SERVİS PROVIDERs
// ============================================

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService();
});

// ============================================
// KONUŞMALAR PROVIDER
// ============================================

class ConversationsState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;
  // Memoized unread count - her seferinde hesaplamak yerine state ile birlikte güncellenir
  final int _cachedUnreadCount;

  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
    int cachedUnreadCount = 0,
  }) : _cachedUnreadCount = cachedUnreadCount;

  ConversationsState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    final newConversations = conversations ?? this.conversations;
    // Sadece conversations değiştiğinde unread count'u yeniden hesapla
    final newUnreadCount = conversations != null
        ? _calculateUnreadCount(newConversations)
        : _cachedUnreadCount;

    return ConversationsState(
      conversations: newConversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      cachedUnreadCount: newUnreadCount,
    );
  }

  // Memoized getter - artık her çağrıda hesaplama yapmıyor
  int get totalUnreadCount => _cachedUnreadCount;

  // Private hesaplama metodu - sadece conversations değiştiğinde çağrılır
  static int _calculateUnreadCount(List<Conversation> convs) {
    return convs.fold(
      0,
      (sum, conv) => sum + conv.buyerUnreadCount + conv.sellerUnreadCount,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ChatService _service;
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _messagesChannel;

  // Debounce timer - art arda gelen güncellemeleri birleştirmek için
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  ConversationsNotifier(this._service) : super(const ConversationsState()) {
    loadConversations();
    _subscribeToRealtimeUpdates();
  }

  // Debounced load - 500ms içinde birden fazla çağrı gelirse sadece son çağrıyı çalıştır
  void _debouncedLoadConversations() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      loadConversations();
    });
  }

  void _subscribeToRealtimeUpdates() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Konuşmalar tablosundaki değişiklikleri dinle
    _conversationsChannel = client
        .channel('super_app_conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            // Debounce ile yükle - art arda gelen eventleri birleştir
            _debouncedLoadConversations();
          },
        )
        .subscribe();

    // Mesajlar tablosundaki değişiklikleri dinle (yeni mesaj geldiğinde liste güncellenmeli)
    _messagesChannel = client
        .channel('super_app_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Debounce ile yükle - art arda gelen eventleri birleştir
            _debouncedLoadConversations();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _conversationsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
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

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final service = ref.watch(chatServiceProvider);
  return ConversationsNotifier(service);
});

// ============================================
// MESAJLAR PROVIDER
// ============================================

class MessagesState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  MessagesState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final ChatService _service;
  final String conversationId;
  RealtimeChannel? _channel;

  MessagesNotifier(this._service, this.conversationId) : super(const MessagesState()) {
    loadMessages();
    _subscribeToNewMessages();
  }

  void _subscribeToNewMessages() {
    _channel = _service.subscribeToNewMessages(conversationId, (message) {
      // Yeni mesajı ekle (duplicate kontrolü ile)
      if (!state.messages.any((m) => m.id == message.id)) {
        state = state.copyWith(
          messages: [...state.messages, message],
        );
      }
    });
  }

  @override
  void dispose() {
    if (_channel != null) {
      _service.unsubscribe(_channel!);
    }
    super.dispose();
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await _service.getMessages(conversationId);
      // Mesajları tersine çevir (en eski en üstte)
      state = state.copyWith(
        messages: messages.reversed.toList(),
        isLoading: false,
      );

      // Mesajları okundu olarak işaretle
      await _service.markMessagesAsRead(conversationId);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    state = state.copyWith(isSending: true, error: null);

    try {
      final message = await _service.sendMessage(
        conversationId: conversationId,
        content: content.trim(),
      );

      if (message != null) {
        state = state.copyWith(
          messages: [...state.messages, message],
          isSending: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString(),
      );
    }
  }

  void addMessage(ChatMessage message) {
    // Yeni mesajı ekle (realtime için)
    if (!state.messages.any((m) => m.id == message.id)) {
      state = state.copyWith(
        messages: [...state.messages, message],
      );
    }
  }

  Future<void> refresh() async {
    await loadMessages();
  }
}

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
        (ref, conversationId) {
  final service = ref.watch(chatServiceProvider);
  return MessagesNotifier(service, conversationId);
});

// ============================================
// TOPLAM OKUNMAMIŞ MESAJ SAYISI
// ============================================

final totalUnreadMessagesProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(chatServiceProvider);
  return service.getTotalUnreadCount();
});

// ============================================
// KONUŞMA DETAY PROVIDER
// ============================================

final conversationDetailProvider =
    FutureProvider.family<Conversation?, String>((ref, conversationId) async {
  final service = ref.watch(chatServiceProvider);
  return service.getConversation(conversationId);
});

// ============================================
// YENİ KONUŞMA OLUŞTUR/BUL PROVIDER
// ============================================

final getOrCreateConversationProvider = FutureProvider.family<Conversation,
    ({String propertyId, String sellerId})>((ref, params) async {
  final service = ref.watch(chatServiceProvider);
  return service.getOrCreateConversation(
    propertyId: params.propertyId,
    sellerId: params.sellerId,
  );
});

// ============================================
// RANDEVU PROVIDERs
// ============================================

class AppointmentsState {
  final List<Appointment> sentAppointments;
  final List<Appointment> receivedAppointments;
  final bool isLoading;
  final String? error;

  const AppointmentsState({
    this.sentAppointments = const [],
    this.receivedAppointments = const [],
    this.isLoading = false,
    this.error,
  });

  AppointmentsState copyWith({
    List<Appointment>? sentAppointments,
    List<Appointment>? receivedAppointments,
    bool? isLoading,
    String? error,
  }) {
    return AppointmentsState(
      sentAppointments: sentAppointments ?? this.sentAppointments,
      receivedAppointments: receivedAppointments ?? this.receivedAppointments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int get pendingReceivedCount =>
      receivedAppointments.where((a) => a.status == AppointmentStatus.pending).length;
}

class AppointmentsNotifier extends StateNotifier<AppointmentsState> {
  final AppointmentService _service;
  RealtimeChannel? _appointmentsChannel;

  AppointmentsNotifier(this._service) : super(const AppointmentsState()) {
    loadAppointments();
    _subscribeToRealtimeUpdates();
  }

  void _subscribeToRealtimeUpdates() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Randevular tablosundaki değişiklikleri dinle
    // Kullanıcının gönderdiği veya aldığı randevulardaki güncellemeleri yakala
    _appointmentsChannel = client
        .channel('super_app_appointments_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'appointments',
          callback: (payload) {
            // Randevu durumu güncellendiğinde listeyi yenile
            loadAppointments();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _appointmentsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> loadAppointments() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sent = await _service.getSentAppointments();
      final received = await _service.getReceivedAppointments();

      state = state.copyWith(
        sentAppointments: sent,
        receivedAppointments: received,
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
    await loadAppointments();
  }

  Future<bool> confirmAppointment(String appointmentId, {String? note}) async {
    final success = await _service.confirmAppointment(appointmentId, responseNote: note);
    if (success) {
      await loadAppointments();
    }
    return success;
  }

  Future<bool> cancelAppointment(String appointmentId, {String? reason}) async {
    final success = await _service.cancelAppointment(appointmentId, reason: reason);
    if (success) {
      await loadAppointments();
    }
    return success;
  }

  Future<bool> completeAppointment(String appointmentId) async {
    final success = await _service.completeAppointment(appointmentId);
    if (success) {
      await loadAppointments();
    }
    return success;
  }
}

final appointmentsProvider =
    StateNotifierProvider<AppointmentsNotifier, AppointmentsState>((ref) {
  final service = ref.watch(appointmentServiceProvider);
  return AppointmentsNotifier(service);
});

// ============================================
// BEKLEYEN RANDEVU SAYISI
// ============================================

final pendingAppointmentsCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(appointmentServiceProvider);
  return service.getPendingAppointmentsCount();
});

// ============================================
// MÜSAIT SAATLER PROVIDER
// ============================================

final availableTimeSlotsProvider =
    FutureProvider.family<List<String>, ({String propertyId, DateTime date})>(
        (ref, params) async {
  final service = ref.watch(appointmentServiceProvider);
  return service.getAvailableTimeSlots(params.propertyId, params.date);
});
