import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/courier_service.dart';

// Earnings provider
final earningsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await CourierService.getEarningsSummary();
});

// Earnings history provider
final earningsHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await CourierService.getEarningsHistory();
});
