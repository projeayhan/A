import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_model.dart';
import '../models/client_engagement_model.dart';
import '../services/client_service.dart';
import 'package:emlakci_panel/core/services/log_service.dart';

// ============================================
// CLIENT SERVICE PROVIDER
// ============================================

final clientServiceProvider = Provider<ClientService>((ref) {
  return ClientService();
});

// ============================================
// CLIENTS STATE
// ============================================

class ClientsState {
  final List<RealtorClient> clients;
  final bool isLoading;
  final String? error;
  final String? selectedStatus;

  const ClientsState({
    this.clients = const [],
    this.isLoading = false,
    this.error,
    this.selectedStatus,
  });

  /// Clients filtered by selected status (if any)
  List<RealtorClient> get filteredClients {
    if (selectedStatus == null || selectedStatus!.isEmpty) return clients;
    return clients
        .where((c) => c.status.name == selectedStatus)
        .toList();
  }

  /// Count by status
  int countByStatus(ClientStatus status) {
    return clients.where((c) => c.status == status).length;
  }

  ClientsState copyWith({
    List<RealtorClient>? clients,
    bool? isLoading,
    String? error,
    String? selectedStatus,
    bool clearStatus = false,
  }) {
    return ClientsState(
      clients: clients ?? this.clients,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
    );
  }
}

// ============================================
// CLIENTS NOTIFIER
// ============================================

class ClientsNotifier extends StateNotifier<ClientsState> {
  final ClientService _service;

  ClientsNotifier(this._service) : super(const ClientsState()) {
    loadClients();
  }

  Future<void> loadClients() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final clients = await _service.getClients(
        status: state.selectedStatus,
      );
      state = state.copyWith(clients: clients, isLoading: false);
    } catch (e, st) {
      LogService.error('Failed to load clients', error: e, stackTrace: st, source: 'ClientsNotifier:loadClients');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addClient(Map<String, dynamic> data) async {
    try {
      await _service.addClient(data);
      await loadClients();
    } catch (e, st) {
      LogService.error('Failed to add client', error: e, stackTrace: st, source: 'ClientsNotifier:addClient');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    try {
      await _service.updateClient(id, data);
      await loadClients();
    } catch (e, st) {
      LogService.error('Failed to update client', error: e, stackTrace: st, source: 'ClientsNotifier:updateClient');
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      await _service.deleteClient(id);
      await loadClients();
    } catch (e, st) {
      LogService.error('Failed to delete client', error: e, stackTrace: st, source: 'ClientsNotifier:deleteClient');
      state = state.copyWith(error: e.toString());
    }
  }

  void setStatusFilter(String? status) {
    if (status == null || status.isEmpty) {
      state = state.copyWith(clearStatus: true);
    } else {
      state = state.copyWith(selectedStatus: status);
    }
    loadClients();
  }
}

// ============================================
// CLIENTS PROVIDER
// ============================================

final clientsProvider =
    StateNotifierProvider<ClientsNotifier, ClientsState>((ref) {
  final service = ref.watch(clientServiceProvider);
  return ClientsNotifier(service);
});

// ============================================
// UPCOMING FOLLOWUPS PROVIDER
// ============================================

final upcomingFollowupsProvider =
    FutureProvider<List<RealtorClient>>((ref) async {
  final service = ref.watch(clientServiceProvider);
  return service.getUpcomingFollowups();
});

// ============================================
// CLIENT COUNT PROVIDER
// ============================================

final clientCountProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(clientServiceProvider);
  return service.getClientCount();
});

// ============================================
// CRM ANALİTİK PROVIDER'LAR
// ============================================

/// CRM KPI özeti
final crmKpisProvider = FutureProvider<CrmKpis>((ref) async {
  final service = ref.watch(clientServiceProvider);
  final data = await service.getCrmKpis();
  if (data.isEmpty) return const CrmKpis();
  return CrmKpis.fromJson(data);
});

/// Müşteri engagement listesi (skor sıralı)
final clientEngagementProvider =
    FutureProvider<List<ClientEngagement>>((ref) async {
  final service = ref.watch(clientServiceProvider);
  final data = await service.getClientEngagement();
  return data.map((e) => ClientEngagement.fromJson(e)).toList();
});

/// En çok müşteri ilgisi gören ilanlar
final propertiesClientInterestProvider =
    FutureProvider<List<PropertyClientInterest>>((ref) async {
  final service = ref.watch(clientServiceProvider);
  final data = await service.getPropertiesClientInterest();
  return data.map((e) => PropertyClientInterest.fromJson(e)).toList();
});

/// Son müşteri aktivite akışı
final clientActivityFeedProvider =
    FutureProvider<List<ActivityFeedItem>>((ref) async {
  final service = ref.watch(clientServiceProvider);
  final data = await service.getClientActivityFeed();
  return data.map((e) => ActivityFeedItem.fromJson(e)).toList();
});

/// Belirli müşterinin ilan aktivitesi (family)
final clientPropertyActivityProvider = FutureProvider.family<
    List<ClientPropertyActivity>, String>((ref, clientId) async {
  final service = ref.watch(clientServiceProvider);
  final data = await service.getClientPropertyActivity(clientId);
  return data.map((e) => ClientPropertyActivity.fromJson(e)).toList();
});
