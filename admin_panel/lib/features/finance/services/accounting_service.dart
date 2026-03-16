import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== MODELS ====================

class BalanceSheetData {
  final double totalAssets;
  final double totalLiabilities;
  final double equity;
  final List<BalanceSheetItem> assets;
  final List<BalanceSheetItem> liabilities;

  BalanceSheetData({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.equity,
    required this.assets,
    required this.liabilities,
  });

  factory BalanceSheetData.fromJson(Map<String, dynamic> json) {
    return BalanceSheetData(
      totalAssets: (json['total_assets'] as num?)?.toDouble() ?? 0,
      totalLiabilities: (json['total_liabilities'] as num?)?.toDouble() ?? 0,
      equity: (json['equity'] as num?)?.toDouble() ?? 0,
      assets: (json['assets'] as List?)
              ?.map((e) => BalanceSheetItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      liabilities: (json['liabilities'] as List?)
              ?.map((e) => BalanceSheetItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BalanceSheetItem {
  final String category;
  final double amount;
  final double? prevAmount;

  BalanceSheetItem({
    required this.category,
    required this.amount,
    this.prevAmount,
  });

  factory BalanceSheetItem.fromJson(Map<String, dynamic> json) {
    return BalanceSheetItem(
      category: json['category'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      prevAmount: (json['prev_amount'] as num?)?.toDouble(),
    );
  }
}

class ProfitLossData {
  final double totalRevenue;
  final double totalExpenses;
  final double netProfit;
  final List<SectorRevenue> sectorRevenues;
  final List<ExpenseCategory> expenseCategories;
  final List<MonthlyProfit> monthlyProfits;

  ProfitLossData({
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.sectorRevenues,
    required this.expenseCategories,
    required this.monthlyProfits,
  });

  factory ProfitLossData.fromJson(Map<String, dynamic> json) {
    return ProfitLossData(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0,
      sectorRevenues: (json['sector_revenues'] as List?)
              ?.map((e) => SectorRevenue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      expenseCategories: (json['expense_categories'] as List?)
              ?.map(
                  (e) => ExpenseCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      monthlyProfits: (json['monthly_profits'] as List?)
              ?.map((e) => MonthlyProfit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SectorRevenue {
  final String sector;
  final double revenue;
  final double commission;

  SectorRevenue({
    required this.sector,
    required this.revenue,
    required this.commission,
  });

  factory SectorRevenue.fromJson(Map<String, dynamic> json) {
    return SectorRevenue(
      sector: json['sector'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ExpenseCategory {
  final String category;
  final double amount;

  ExpenseCategory({required this.category, required this.amount});

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      category: json['category'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MonthlyProfit {
  final String month;
  final double revenue;
  final double expenses;
  final double profit;

  MonthlyProfit({
    required this.month,
    required this.revenue,
    required this.expenses,
    required this.profit,
  });

  factory MonthlyProfit.fromJson(Map<String, dynamic> json) {
    return MonthlyProfit(
      month: json['month'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      expenses: (json['expenses'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class KdvSummary {
  final double totalKdvCollected;
  final double totalKdvPaid;
  final double netKdv;
  final List<SectorKdv> sectorKdv;

  KdvSummary({
    required this.totalKdvCollected,
    required this.totalKdvPaid,
    required this.netKdv,
    required this.sectorKdv,
  });

  factory KdvSummary.fromJson(Map<String, dynamic> json) {
    return KdvSummary(
      totalKdvCollected: (json['total_kdv_collected'] as num?)?.toDouble() ?? 0,
      totalKdvPaid: (json['total_kdv_paid'] as num?)?.toDouble() ?? 0,
      netKdv: (json['net_kdv'] as num?)?.toDouble() ?? 0,
      sectorKdv: (json['sector_kdv'] as List?)
              ?.map((e) => SectorKdv.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SectorKdv {
  final String sector;
  final double kdvCollected;
  final double kdvPaid;
  final double kdvRate;

  SectorKdv({
    required this.sector,
    required this.kdvCollected,
    required this.kdvPaid,
    required this.kdvRate,
  });

  factory SectorKdv.fromJson(Map<String, dynamic> json) {
    return SectorKdv(
      sector: json['sector'] as String? ?? '',
      kdvCollected: (json['kdv_collected'] as num?)?.toDouble() ?? 0,
      kdvPaid: (json['kdv_paid'] as num?)?.toDouble() ?? 0,
      kdvRate: (json['kdv_rate'] as num?)?.toDouble() ?? 0.20,
    );
  }
}

class AgingReport {
  final double current;
  final double days30;
  final double days60;
  final double days90;
  final double days90Plus;
  final List<AgingItem> items;

  AgingReport({
    required this.current,
    required this.days30,
    required this.days60,
    required this.days90,
    required this.days90Plus,
    required this.items,
  });

  factory AgingReport.fromJson(Map<String, dynamic> json) {
    return AgingReport(
      current: (json['current'] as num?)?.toDouble() ?? 0,
      days30: (json['days_30'] as num?)?.toDouble() ?? 0,
      days60: (json['days_60'] as num?)?.toDouble() ?? 0,
      days90: (json['days_90'] as num?)?.toDouble() ?? 0,
      days90Plus: (json['days_90_plus'] as num?)?.toDouble() ?? 0,
      items: (json['items'] as List?)
              ?.map((e) => AgingItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  double get total => current + days30 + days60 + days90 + days90Plus;
}

class AgingItem {
  final String id;
  final String entityName;
  final double amount;
  final String status;
  final DateTime dueDate;
  final int daysOverdue;

  AgingItem({
    required this.id,
    required this.entityName,
    required this.amount,
    required this.status,
    required this.dueDate,
    required this.daysOverdue,
  });

  factory AgingItem.fromJson(Map<String, dynamic> json) {
    return AgingItem(
      id: json['id'] as String? ?? '',
      entityName: json['entity_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ?? DateTime.now(),
      daysOverdue: json['days_overdue'] as int? ?? 0,
    );
  }
}

class FinanceEntry {
  final String id;
  final String type; // income, expense
  final String category;
  final String description;
  final double amount;
  final String source;
  final DateTime date;
  final String? referenceId;

  FinanceEntry({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.source,
    required this.date,
    this.referenceId,
  });

  factory FinanceEntry.fromJson(Map<String, dynamic> json) {
    return FinanceEntry(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'income',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      source: json['source'] as String? ?? '',
      date: DateTime.tryParse(json['created_at'] as String? ?? json['date'] as String? ?? '') ?? DateTime.now(),
      referenceId: json['reference_id'] as String?,
    );
  }
}

// ==================== PROVIDERS ====================

class BalanceSheetParams {
  final int month;
  final int year;
  BalanceSheetParams(this.month, this.year);

  @override
  bool operator ==(Object other) =>
      other is BalanceSheetParams && other.month == month && other.year == year;

  @override
  int get hashCode => Object.hash(month, year);
}

final balanceSheetProvider = FutureProvider.family<BalanceSheetData, BalanceSheetParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final result = await supabase.rpc('get_balance_sheet', params: {
      'p_month': params.month,
      'p_year': params.year,
    });
    return BalanceSheetData.fromJson(result as Map<String, dynamic>);
  } catch (_) {
    return BalanceSheetData(
      totalAssets: 0,
      totalLiabilities: 0,
      equity: 0,
      assets: [],
      liabilities: [],
    );
  }
});

final profitLossProvider = FutureProvider.family<ProfitLossData, BalanceSheetParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final result = await supabase.rpc('get_profit_loss', params: {
      'p_month': params.month,
      'p_year': params.year,
    });
    return ProfitLossData.fromJson(result as Map<String, dynamic>);
  } catch (_) {
    return ProfitLossData(
      totalRevenue: 0,
      totalExpenses: 0,
      netProfit: 0,
      sectorRevenues: [],
      expenseCategories: [],
      monthlyProfits: [],
    );
  }
});

final kdvSummaryProvider = FutureProvider.family<KdvSummary, BalanceSheetParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final result = await supabase.rpc('get_kdv_summary', params: {
      'p_month': params.month,
      'p_year': params.year,
    });
    return KdvSummary.fromJson(result as Map<String, dynamic>);
  } catch (_) {
    return KdvSummary(
      totalKdvCollected: 0,
      totalKdvPaid: 0,
      netKdv: 0,
      sectorKdv: [],
    );
  }
});

final agingReportProvider = FutureProvider<AgingReport>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final result = await supabase.rpc('get_aging_report');
    return AgingReport.fromJson(result as Map<String, dynamic>);
  } catch (_) {
    return AgingReport(
      current: 0,
      days30: 0,
      days60: 0,
      days90: 0,
      days90Plus: 0,
      items: [],
    );
  }
});

class FinanceEntryParams {
  final String? type;
  final String? source;
  final int page;
  final int pageSize;

  FinanceEntryParams({this.type, this.source, this.page = 0, this.pageSize = 20});

  @override
  bool operator ==(Object other) =>
      other is FinanceEntryParams &&
      other.type == type &&
      other.source == source &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(type, source, page, pageSize);
}

final financeEntriesProvider =
    FutureProvider.family<List<FinanceEntry>, FinanceEntryParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    var query = supabase.from('finance_entries').select();
    if (params.type != null) {
      query = query.eq('type', params.type!);
    }
    if (params.source != null) {
      query = query.eq('source', params.source!);
    }
    final result = await query
        .order('created_at', ascending: false)
        .range(params.page * params.pageSize, (params.page + 1) * params.pageSize - 1);
    return (result as List).map((e) => FinanceEntry.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

// ==================== SERVICE ====================

class AccountingService {
  static Future<void> createFinanceEntry({
    required String type,
    required String category,
    required String description,
    required double amount,
    required String source,
    String? referenceId,
  }) async {
    await SupabaseService.client.from('finance_entries').insert({
      'type': type,
      'category': category,
      'description': description,
      'amount': amount,
      'source': source,
      'reference_id': referenceId,
    });
  }

  static Future<void> deleteFinanceEntry(String id) async {
    await SupabaseService.client.from('finance_entries').delete().eq('id', id);
  }

  static Future<void> markPaymentPaid(String invoiceId) async {
    await SupabaseService.client
        .from('invoices')
        .update({'status': 'paid', 'paid_at': DateTime.now().toIso8601String()})
        .eq('id', invoiceId);
  }

  static Future<void> markPaymentsPaidBulk(List<String> invoiceIds) async {
    await SupabaseService.client
        .from('invoices')
        .update({'status': 'paid', 'paid_at': DateTime.now().toIso8601String()})
        .inFilter('id', invoiceIds);
  }
}

