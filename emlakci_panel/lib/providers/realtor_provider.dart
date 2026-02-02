import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/realtor_service.dart';
import '../services/chat_service.dart';

// ============================================
// REALTOR SERVICE PROVIDER
// ============================================

final realtorServiceProvider = Provider<RealtorService>((ref) {
  return RealtorService();
});

// ============================================
// EMLAKÇI DURUMU PROVIDER
// ============================================

final isRealtorProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.isRealtor();
});

// ============================================
// EMLAKÇI PROFİLİ PROVIDER
// ============================================

final realtorProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getRealtorProfile();
});

// ============================================
// BAŞVURU DURUMU PROVIDER
// ============================================

final applicationStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getApplicationStatus();
});

// ============================================
// DASHBOARD İSTATİSTİKLERİ PROVIDER
// ============================================

final realtorDashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getDashboardStats();
});

// ============================================
// İLAN BAZLI PERFORMANS İSTATİSTİKLERİ PROVIDER
// ============================================

/// Performans istatistikleri için family provider
/// [days] parametresi ile dönem seçilebilir (7, 30, 90)
final propertyPerformanceStatsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getPropertyPerformanceStats(days: days);
});

// ============================================
// PROMOSYON PROVIDERLARI
// ============================================

/// Aktif promosyonlar provider
final activePromotionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getActivePromotions();
});

/// Promosyon geçmişi provider
final promotionHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getPromotionHistory();
});

/// Promosyon fiyatları provider
final promotionPricesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getPromotionPrices();
});

// ============================================
// RANDEVULAR PROVIDER
// ============================================

class RealtorAppointmentsState {
  final List<Map<String, dynamic>> appointments;
  final List<Map<String, dynamic>> todayAppointments;
  final bool isLoading;
  final String? error;

  const RealtorAppointmentsState({
    this.appointments = const [],
    this.todayAppointments = const [],
    this.isLoading = false,
    this.error,
  });

  RealtorAppointmentsState copyWith({
    List<Map<String, dynamic>>? appointments,
    List<Map<String, dynamic>>? todayAppointments,
    bool? isLoading,
    String? error,
  }) {
    return RealtorAppointmentsState(
      appointments: appointments ?? this.appointments,
      todayAppointments: todayAppointments ?? this.todayAppointments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RealtorAppointmentsNotifier extends StateNotifier<RealtorAppointmentsState> {
  final RealtorService _service;
  RealtimeChannel? _appointmentsChannel;

  RealtorAppointmentsNotifier(this._service) : super(const RealtorAppointmentsState()) {
    loadAppointments();
    _subscribeToRealtimeUpdates();
  }

  void _subscribeToRealtimeUpdates() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Randevular tablosundaki değişiklikleri dinle
    _appointmentsChannel = client
        .channel('realtor_appointments_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          callback: (payload) {
            // Randevu eklendiğinde/güncellendiğinde listeyi yenile
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
      final appointments = await _service.getAppointments();
      final todayAppointments = await _service.getTodayAppointments();

      state = state.copyWith(
        appointments: appointments,
        todayAppointments: todayAppointments,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addAppointment({
    required String title,
    required DateTime scheduledAt,
    String? description,
    String? appointmentType,
    int durationMinutes = 60,
    String? clientId,
    String? propertyId,
    String? location,
  }) async {
    try {
      await _service.addAppointment(
        title: title,
        scheduledAt: scheduledAt,
        description: description,
        appointmentType: appointmentType,
        durationMinutes: durationMinutes,
        clientId: clientId,
        propertyId: propertyId,
        location: location,
      );
      await loadAppointments();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> cancelAppointment(String appointmentId, String? reason) async {
    try {
      await _service.cancelAppointment(appointmentId, reason);
      await loadAppointments();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> completeAppointment(String appointmentId, String? outcome) async {
    try {
      await _service.completeAppointment(appointmentId, outcome);
      await loadAppointments();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final realtorAppointmentsProvider =
    StateNotifierProvider<RealtorAppointmentsNotifier, RealtorAppointmentsState>((ref) {
  final service = ref.watch(realtorServiceProvider);
  return RealtorAppointmentsNotifier(service);
});

// ============================================
// SON AKTİVİTELER PROVIDER
// ============================================

final realtorActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getRecentActivity();
});

// ============================================
// ONAYLI EMLAKÇILAR PROVIDER (Public)
// ============================================

final approvedRealtorsProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, city) async {
  final service = ref.watch(realtorServiceProvider);
  return service.getApprovedRealtors(city: city);
});

// ============================================
// CHAT SERVICE PROVIDER
// ============================================

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// ============================================
// MESAJLAŞMA PROVIDERLARI
// ============================================

class ChatState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;
  final int totalUnreadCount;

  const ChatState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
    this.totalUnreadCount = 0,
  });

  ChatState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
    int? totalUnreadCount,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _service;
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _messagesChannel;

  ChatNotifier(this._service) : super(const ChatState()) {
    loadConversations();
    _subscribeToRealtimeUpdates();
  }

  void _subscribeToRealtimeUpdates() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Konuşmalar tablosundaki değişiklikleri dinle
    _conversationsChannel = client
        .channel('realtor_conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            // Konuşma güncellendiğinde listeyi yenile
            loadConversations();
          },
        )
        .subscribe();

    // Mesajlar tablosundaki değişiklikleri dinle
    _messagesChannel = client
        .channel('realtor_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Yeni mesaj geldiğinde listeyi yenile
            loadConversations();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _conversationsChannel?.unsubscribe();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: state.conversations.isEmpty, error: null);

    try {
      final conversations = await _service.getConversations();
      final unreadCount = await _service.getTotalUnreadCount();

      state = state.copyWith(
        conversations: conversations,
        totalUnreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadConversations();
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _service.markMessagesAsRead(conversationId);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final service = ref.watch(chatServiceProvider);
  return ChatNotifier(service);
});

/// Okunmamış mesaj sayısı
final unreadMessagesCountProvider = Provider<int>((ref) {
  return ref.watch(chatProvider).totalUnreadCount;
});

/// Konuşma mesajları provider (family)
final conversationMessagesProvider = FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) async {
  final service = ref.watch(chatServiceProvider);
  return service.getMessages(conversationId);
});

/// Konuşma detayı provider
final conversationDetailProvider = FutureProvider.family<Conversation?, String>((ref, conversationId) async {
  final service = ref.watch(chatServiceProvider);
  return service.getConversation(conversationId);
});
