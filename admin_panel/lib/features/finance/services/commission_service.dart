import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== MODELS ====================

class CommissionRate {
  final String id;
  final String sector;
  final double rate;
  final double? minAmount;
  final double? maxAmount;
  final bool isActive;
  final DateTime updatedAt;

  CommissionRate({
    required this.id,
    required this.sector,
    required this.rate,
    this.minAmount,
    this.maxAmount,
    required this.isActive,
    required this.updatedAt,
  });

  factory CommissionRate.fromJson(Map<String, dynamic> json) {
    return CommissionRate(
      id: json['id'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      minAmount: (json['min_amount'] as num?)?.toDouble(),
      maxAmount: (json['max_amount'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class MerchantCommissionOverride {
  final String id;
  final String merchantId;
  final String merchantName;
  final String sector;
  final double rate;
  final String? reason;
  final DateTime createdAt;

  MerchantCommissionOverride({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.sector,
    required this.rate,
    this.reason,
    required this.createdAt,
  });

  factory MerchantCommissionOverride.fromJson(Map<String, dynamic> json) {
    return MerchantCommissionOverride(
      id: json['id'] as String? ?? '',
      merchantId: json['merchant_id'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? json['merchants']?['name'] as String? ?? '',
      sector: json['sector'] as String? ?? '',
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ==================== PROVIDERS ====================

final commissionRatesProvider = FutureProvider<List<CommissionRate>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final result = await supabase
        .from('commission_rates')
        .select()
        .order('sector');
    return (result as List).map((e) => CommissionRate.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

final merchantOverridesProvider = FutureProvider<List<MerchantCommissionOverride>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final result = await supabase
        .from('merchant_commission_overrides')
        .select('*, merchants(name)')
        .order('created_at', ascending: false);
    return (result as List)
        .map((e) => MerchantCommissionOverride.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ==================== SERVICE ====================

class CommissionService {
  static Future<void> updateCommissionRate({
    required String id,
    required double rate,
    double? minAmount,
    double? maxAmount,
  }) async {
    await SupabaseService.client.from('commission_rates').update({
      'rate': rate,
      if (minAmount != null) 'min_amount': minAmount,
      if (maxAmount != null) 'max_amount': maxAmount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> createMerchantOverride({
    required String merchantId,
    required String sector,
    required double rate,
    String? reason,
  }) async {
    await SupabaseService.client.from('merchant_commission_overrides').insert({
      'merchant_id': merchantId,
      'sector': sector,
      'rate': rate,
      'reason': reason,
    });
  }

  static Future<void> deleteMerchantOverride(String id) async {
    await SupabaseService.client.from('merchant_commission_overrides').delete().eq('id', id);
  }
}
