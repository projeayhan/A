import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// ==================== MODELS ====================

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

class FinanceEntry {
  final String id;
  final String type; // income, expense
  final String category;
  final String description;
  final double amount;
  final String source;
  final DateTime date;
  final String? referenceId;
  final String? subcategory;
  final double? kdvRate;
  final double? kdvAmount;
  final double? totalAmount;
  final String? currency;
  final String? merchantId;
  final String? invoiceId;
  final String? paymentStatus;
  final String? paymentMethod;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final bool taxDeductible;
  final String? notes;
  final String? createdBy;
  final List<String> tags;
  final String? recurringEntryId;
  final DateTime? updatedAt;

  FinanceEntry({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.source,
    required this.date,
    this.referenceId,
    this.subcategory,
    this.kdvRate,
    this.kdvAmount,
    this.totalAmount,
    this.currency,
    this.merchantId,
    this.invoiceId,
    this.paymentStatus,
    this.paymentMethod,
    this.dueDate,
    this.paidAt,
    this.taxDeductible = false,
    this.notes,
    this.createdBy,
    this.tags = const [],
    this.recurringEntryId,
    this.updatedAt,
  });

  factory FinanceEntry.fromJson(Map<String, dynamic> json) {
    return FinanceEntry(
      id: json['id'] as String? ?? '',
      type: json['entry_type'] as String? ?? 'income',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      source: json['source_type'] as String? ?? '',
      date: DateTime.tryParse(json['created_at'] as String? ?? json['date'] as String? ?? '') ?? DateTime.now(),
      referenceId: json['source_id'] as String?,
      subcategory: json['subcategory'] as String?,
      kdvRate: (json['kdv_rate'] as num?)?.toDouble(),
      kdvAmount: (json['kdv_amount'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      merchantId: json['merchant_id'] as String?,
      invoiceId: json['invoice_id'] as String?,
      paymentStatus: json['payment_status'] as String?,
      paymentMethod: json['payment_method'] as String?,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null,
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      taxDeductible: json['tax_deductible'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      recurringEntryId: json['recurring_entry_id'] as String?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }
}

// ==================== INCOME/EXPENSE MODELS ====================

class TimeSeriesPoint {
  final DateTime date;
  final double income;
  final double expense;

  TimeSeriesPoint({required this.date, required this.income, required this.expense});

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPoint(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      income: (json['income'] as num?)?.toDouble() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CategoryBreakdown {
  final String category;
  final double total;
  final int count;

  CategoryBreakdown({required this.category, required this.total, required this.count});

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: json['category'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class SourceBreakdown {
  final String sourceType;
  final double total;
  final int count;

  SourceBreakdown({required this.sourceType, required this.total, required this.count});

  factory SourceBreakdown.fromJson(Map<String, dynamic> json) {
    return SourceBreakdown(
      sourceType: json['source_type'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }
}

class BudgetAlert {
  final String category;
  final double target;
  final double actual;
  final double percentage;

  BudgetAlert({required this.category, required this.target, required this.actual, required this.percentage});

  factory BudgetAlert.fromJson(Map<String, dynamic> json) {
    return BudgetAlert(
      category: json['category'] as String? ?? '',
      target: (json['target'] as num?)?.toDouble() ?? 0,
      actual: (json['actual'] as num?)?.toDouble() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class IncomeExpenseSummary {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final double totalKdv;
  final int pendingCount;
  final double pendingAmount;
  final int entryCount;
  final double incomeTrend;
  final double expenseTrend;
  final List<TimeSeriesPoint> timeSeries;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<SourceBreakdown> sourceBreakdown;
  final List<BudgetAlert> budgetAlerts;

  IncomeExpenseSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.totalKdv,
    required this.pendingCount,
    required this.pendingAmount,
    required this.entryCount,
    required this.incomeTrend,
    required this.expenseTrend,
    required this.timeSeries,
    required this.categoryBreakdown,
    required this.sourceBreakdown,
    required this.budgetAlerts,
  });

  factory IncomeExpenseSummary.fromJson(Map<String, dynamic> json) {
    final currentIncome = (json['total_income'] as num?)?.toDouble() ?? 0;
    final currentExpense = (json['total_expense'] as num?)?.toDouble() ?? 0;
    final prevIncome = (json['prev_income'] as num?)?.toDouble() ?? 0;
    final prevExpense = (json['prev_expense'] as num?)?.toDouble() ?? 0;

    double calcTrend(double current, double prev) {
      if (prev == 0) return current > 0 ? 100 : 0;
      return (current - prev) / prev * 100;
    }

    return IncomeExpenseSummary(
      totalIncome: currentIncome,
      totalExpense: currentExpense,
      netBalance: (json['net_balance'] as num?)?.toDouble() ?? (currentIncome - currentExpense),
      totalKdv: (json['total_kdv'] as num?)?.toDouble() ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0,
      entryCount: json['entry_count'] as int? ?? 0,
      incomeTrend: (json['income_trend'] as num?)?.toDouble() ?? calcTrend(currentIncome, prevIncome),
      expenseTrend: (json['expense_trend'] as num?)?.toDouble() ?? calcTrend(currentExpense, prevExpense),
      timeSeries: (json['time_series'] as List?)
              ?.map((e) => TimeSeriesPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      categoryBreakdown: (json['category_breakdown'] as List?)
              ?.map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      sourceBreakdown: (json['source_breakdown'] as List?)
              ?.map((e) => SourceBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      budgetAlerts: (json['budget_alerts'] as List?)
              ?.map((e) => BudgetAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class IncomeExpenseFilterParams {
  final DateTime startDate;
  final DateTime endDate;
  final String? type;
  final String? source;
  final String? category;
  final String? paymentStatus;
  final String? searchQuery;
  final double? minAmount;
  final double? maxAmount;
  final List<String>? tags;
  final int page;
  final int pageSize;
  final String sortColumn;
  final bool sortAscending;
  final String aggregation;

  IncomeExpenseFilterParams({
    required this.startDate,
    required this.endDate,
    this.type,
    this.source,
    this.category,
    this.paymentStatus,
    this.searchQuery,
    this.minAmount,
    this.maxAmount,
    this.tags,
    this.page = 0,
    this.pageSize = 25,
    this.sortColumn = 'created_at',
    this.sortAscending = false,
    this.aggregation = 'daily',
  });

  @override
  bool operator ==(Object other) =>
      other is IncomeExpenseFilterParams &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.type == type &&
      other.source == source &&
      other.category == category &&
      other.paymentStatus == paymentStatus &&
      other.searchQuery == searchQuery &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.sortColumn == sortColumn &&
      other.sortAscending == sortAscending &&
      other.aggregation == aggregation;

  @override
  int get hashCode => Object.hash(
        startDate,
        endDate,
        type,
        source,
        category,
        paymentStatus,
        searchQuery,
        minAmount,
        maxAmount,
        page,
        pageSize,
        sortColumn,
        sortAscending,
        aggregation,
      );
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

final kdvSummaryProvider = FutureProvider.family<KdvSummary, BalanceSheetParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  final result = await supabase.rpc('get_kdv_summary', params: {
    'p_month': params.month,
    'p_year': params.year,
  });
  return KdvSummary.fromJson(result as Map<String, dynamic>);
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
  var query = supabase.from('finance_entries').select();
  if (params.type != null) {
    query = query.eq('entry_type', params.type!);
  }
  if (params.source != null) {
    query = query.eq('source_type', params.source!);
  }
  final result = await query
      .order('created_at', ascending: false)
      .range(params.page * params.pageSize, (params.page + 1) * params.pageSize - 1);
  return (result as List).map((e) => FinanceEntry.fromJson(e as Map<String, dynamic>)).toList();
});

// ==================== INCOME/EXPENSE PROVIDERS ====================

final incomeExpenseSummaryProvider =
    FutureProvider.family<IncomeExpenseSummary, IncomeExpenseFilterParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  final result = await supabase.rpc('get_income_expense_summary', params: {
    'p_start_date': params.startDate.toIso8601String(),
    'p_end_date': params.endDate.toIso8601String(),
    'p_type': params.type,
    'p_source': params.source,
    'p_category': params.category,
    'p_aggregation': params.aggregation,
  });
  return IncomeExpenseSummary.fromJson(result as Map<String, dynamic>);
});

final incomeExpenseEntriesProvider =
    FutureProvider.family<List<FinanceEntry>, IncomeExpenseFilterParams>((ref, params) async {
  final supabase = ref.watch(supabaseProvider);
  var query = supabase.from('finance_entries').select();

  query = query.gte('created_at', params.startDate.toIso8601String());
  query = query.lte('created_at', params.endDate.toIso8601String());

  if (params.type != null) {
    query = query.eq('entry_type', params.type!);
  }
  if (params.source != null) {
    query = query.eq('source_type', params.source!);
  }
  if (params.category != null) {
    query = query.eq('category', params.category!);
  }
  if (params.paymentStatus != null) {
    query = query.eq('payment_status', params.paymentStatus!);
  }
  if (params.searchQuery != null && params.searchQuery!.isNotEmpty) {
    final q = params.searchQuery!;
    query = query.or('description.ilike.%$q%,category.ilike.%$q%,notes.ilike.%$q%');
  }
  if (params.minAmount != null) {
    query = query.gte('amount', params.minAmount!);
  }
  if (params.maxAmount != null) {
    query = query.lte('amount', params.maxAmount!);
  }

  final result = await query
      .order(params.sortColumn, ascending: params.sortAscending)
      .range(params.page * params.pageSize, (params.page + 1) * params.pageSize - 1);

  return (result as List).map((e) => FinanceEntry.fromJson(e as Map<String, dynamic>)).toList();
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
      'entry_type': type,
      'category': category,
      'description': description,
      'amount': amount,
      'source_type': source,
      'source_id': referenceId,
    });
  }

  static Future<void> deleteFinanceEntry(String id) async {
    await SupabaseService.client.from('finance_entries').delete().eq('id', id);
  }

  // ==================== ENHANCED CRUD ====================

  static Future<void> createFinanceEntryFull({
    required String type,
    required String category,
    String? subcategory,
    required String description,
    required double amount,
    required double kdvRate,
    required String source,
    String? paymentMethod,
    String paymentStatus = 'pending',
    DateTime? dueDate,
    bool taxDeductible = false,
    String? notes,
    List<String>? tags,
  }) async {
    final kdvAmount = amount * kdvRate / 100;
    final totalAmount = amount + kdvAmount;
    await SupabaseService.client.from('finance_entries').insert({
      'entry_type': type,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'amount': amount,
      'kdv_rate': kdvRate,
      'kdv_amount': kdvAmount,
      'total_amount': totalAmount,
      'source_type': source,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'due_date': dueDate?.toIso8601String(),
      'tax_deductible': taxDeductible,
      'notes': notes,
      'tags': tags,
    });
  }

  static Future<void> updateFinanceEntry(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await SupabaseService.client.from('finance_entries').update(updates).eq('id', id);
  }

  static Future<void> bulkDeleteFinanceEntries(List<String> ids) async {
    await SupabaseService.client.from('finance_entries').delete().inFilter('id', ids);
  }
}
