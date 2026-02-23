import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';

/// Singleton service for CRM (Realtor Clients) operations
class ClientService {
  static final ClientService _instance = ClientService._internal();
  factory ClientService() => _instance;
  ClientService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String get _realtorId => _client.auth.currentUser!.id;

  // ==================== SORGULAMA ====================

  /// Fetch realtor's clients with optional status filter and search
  Future<List<RealtorClient>> getClients({
    String? status,
    String? search,
  }) async {
    var query = _client
        .from('realtor_clients')
        .select()
        .eq('realtor_id', _realtorId);

    if (status != null && status.isNotEmpty) {
      query = query.eq('status', status);
    }

    if (search != null && search.isNotEmpty) {
      query = query.or(
        'name.ilike.%$search%,phone.ilike.%$search%,email.ilike.%$search%',
      );
    }

    final response =
        await query.order('created_at', ascending: false);

    return (response as List)
        .map((json) => RealtorClient.fromJson(json))
        .toList();
  }

  /// Fetch a single client by ID
  Future<RealtorClient?> getClient(String id) async {
    final response = await _client
        .from('realtor_clients')
        .select()
        .eq('id', id)
        .eq('realtor_id', _realtorId)
        .maybeSingle();

    if (response == null) return null;
    return RealtorClient.fromJson(response);
  }

  // ==================== EKLEME / GUNCELLEME / SILME ====================

  /// Insert a new client with realtor_id set to current user
  Future<RealtorClient> addClient(Map<String, dynamic> data) async {
    data['realtor_id'] = _realtorId;

    final response = await _client
        .from('realtor_clients')
        .insert(data)
        .select()
        .single();

    return RealtorClient.fromJson(response);
  }

  /// Update an existing client
  Future<RealtorClient> updateClient(
      String id, Map<String, dynamic> data) async {
    final response = await _client
        .from('realtor_clients')
        .update(data)
        .eq('id', id)
        .eq('realtor_id', _realtorId)
        .select()
        .single();

    return RealtorClient.fromJson(response);
  }

  /// Delete a client
  Future<void> deleteClient(String id) async {
    await _client
        .from('realtor_clients')
        .delete()
        .eq('id', id)
        .eq('realtor_id', _realtorId);
  }

  // ==================== ISTATISTIKLER ====================

  /// Get total count of realtor's clients
  Future<int> getClientCount() async {
    final response = await _client
        .from('realtor_clients')
        .select('id')
        .eq('realtor_id', _realtorId);

    return (response as List).length;
  }

  /// Get clients where next_followup_at is today or in the past
  Future<List<RealtorClient>> getUpcomingFollowups() async {
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final response = await _client
        .from('realtor_clients')
        .select()
        .eq('realtor_id', _realtorId)
        .not('next_followup_at', 'is', null)
        .lte('next_followup_at', endOfToday.toIso8601String())
        .order('next_followup_at', ascending: true);

    return (response as List)
        .map((json) => RealtorClient.fromJson(json))
        .toList();
  }

  // ==================== ANALİTİK RPC'LER ====================

  /// CRM KPI özeti
  Future<Map<String, dynamic>> getCrmKpis() async {
    final response = await _client.rpc('get_crm_kpis', params: {
      'p_realtor_user_id': _realtorId,
    });
    if (response is List && response.isNotEmpty) {
      return response[0] as Map<String, dynamic>;
    }
    return {};
  }

  /// Müşteri engagement verileri
  Future<List<Map<String, dynamic>>> getClientEngagement() async {
    final response = await _client.rpc('get_client_engagement', params: {
      'p_realtor_user_id': _realtorId,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// En çok ilgi gören ilanlar
  Future<List<Map<String, dynamic>>> getPropertiesClientInterest(
      {int limit = 10}) async {
    final response =
        await _client.rpc('get_properties_client_interest', params: {
      'p_realtor_user_id': _realtorId,
      'p_limit': limit,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Belirli müşterinin ilan aktivitesi
  Future<List<Map<String, dynamic>>> getClientPropertyActivity(
      String clientId) async {
    final response =
        await _client.rpc('get_client_property_activity', params: {
      'p_realtor_user_id': _realtorId,
      'p_client_id': clientId,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Son müşteri aktivite akışı
  Future<List<Map<String, dynamic>>> getClientActivityFeed(
      {int limit = 20}) async {
    final response = await _client.rpc('get_client_activity_feed', params: {
      'p_realtor_user_id': _realtorId,
      'p_limit': limit,
    });
    return (response as List).cast<Map<String, dynamic>>();
  }
}
