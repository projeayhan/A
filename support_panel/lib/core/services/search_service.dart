import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:support_panel/core/services/log_service.dart';
import 'supabase_service.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return SearchService(supabase);
});

class SearchResult {
  final String type; // customer, ticket, order, merchant, ride
  final String id;
  final String title;
  final String? subtitle;
  final String? route;

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.route,
  });
}

class SearchService {
  final SupabaseClient _supabase;

  SearchService(this._supabase);

  Future<List<SearchResult>> globalSearch(String query) async {
    if (query.length < 2) return [];

    final results = <SearchResult>[];

    try {
      final futures = await Future.wait([
        _searchCustomers(query),
        _searchTickets(query),
        _searchOrders(query),
        _searchMerchants(query),
      ]);

      for (final list in futures) {
        results.addAll(list);
      }
    } catch (e, st) {
      LogService.error('Global search error', error: e, stackTrace: st, source: 'SearchService:search');
    }

    return results;
  }

  Future<List<SearchResult>> _searchCustomers(String query) async {
    try {
      final data = await _supabase
          .from('users')
          .select('id, first_name, last_name, phone, email')
          .or('first_name.ilike.%$query%,last_name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
          .limit(5);

      return (data as List).map((u) => SearchResult(
        type: 'customer',
        id: u['id'],
        title: '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim(),
        subtitle: u['phone'] ?? u['email'],
        route: '/customers/${u['id']}',
      )).toList();
    } catch (e, st) {
      LogService.error('Error searching customers', error: e, stackTrace: st, source: 'SearchService:_searchCustomers');
      return [];
    }
  }

  Future<List<SearchResult>> _searchTickets(String query) async {
    try {
      final data = await _supabase
          .from('support_tickets')
          .select('id, ticket_number, subject, status')
          .or('subject.ilike.%$query%,customer_name.ilike.%$query%')
          .limit(5);

      return (data as List).map((t) => SearchResult(
        type: 'ticket',
        id: t['id'],
        title: '#${t['ticket_number']} - ${t['subject']}',
        subtitle: t['status'],
        route: '/tickets/${t['id']}',
      )).toList();
    } catch (e, st) {
      LogService.error('Error searching tickets', error: e, stackTrace: st, source: 'SearchService:_searchTickets');
      return [];
    }
  }

  Future<List<SearchResult>> _searchOrders(String query) async {
    try {
      final data = await _supabase
          .from('orders')
          .select('id, order_number, customer_name, status')
          .or('order_number.ilike.%$query%,customer_name.ilike.%$query%')
          .limit(5);

      return (data as List).map((o) => SearchResult(
        type: 'order',
        id: o['id'],
        title: '#${o['order_number']} - ${o['customer_name'] ?? 'Müşteri'}',
        subtitle: o['status'],
      )).toList();
    } catch (e, st) {
      LogService.error('Error searching orders', error: e, stackTrace: st, source: 'SearchService:_searchOrders');
      return [];
    }
  }

  Future<List<SearchResult>> _searchMerchants(String query) async {
    try {
      final data = await _supabase
          .from('merchants')
          .select('id, business_name, business_type, status')
          .or('business_name.ilike.%$query%')
          .limit(5);

      return (data as List).map((m) => SearchResult(
        type: 'merchant',
        id: m['id'],
        title: m['business_name'] ?? '',
        subtitle: m['business_type'],
        route: '/businesses?id=${m['id']}',
      )).toList();
    } catch (e, st) {
      LogService.error('Error searching merchants', error: e, stackTrace: st, source: 'SearchService:_searchMerchants');
      return [];
    }
  }
}
