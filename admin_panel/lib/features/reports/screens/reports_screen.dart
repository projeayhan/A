import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../dashboard/widgets/stat_card.dart';
import '../../dashboard/widgets/chart_card.dart';

// ─── Date Range ───────────────────────────────────────────────────────────────

enum ReportDateRange {
  last7Days,
  last30Days,
  last90Days,
  custom,
}

class DateRangeParams {
  final DateTime start;
  final DateTime end;
  final String label;

  const DateRangeParams({
    required this.start,
    required this.end,
    required this.label,
  });

  factory DateRangeParams.fromEnum(ReportDateRange range,
      {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    switch (range) {
      case ReportDateRange.last7Days:
        return DateRangeParams(
          start: now.subtract(const Duration(days: 6)),
          end: now,
          label: 'Son 7 Gün',
        );
      case ReportDateRange.last30Days:
        return DateRangeParams(
          start: now.subtract(const Duration(days: 29)),
          end: now,
          label: 'Son 30 Gün',
        );
      case ReportDateRange.last90Days:
        return DateRangeParams(
          start: now.subtract(const Duration(days: 89)),
          end: now,
          label: 'Son 90 Gün',
        );
      case ReportDateRange.custom:
        return DateRangeParams(
          start: customStart ?? now.subtract(const Duration(days: 29)),
          end: customEnd ?? now,
          label: 'Özel Aralık',
        );
    }
  }
}

// ─── State Notifiers ──────────────────────────────────────────────────────────

class ReportsDateRangeNotifier extends StateNotifier<DateRangeParams> {
  ReportsDateRangeNotifier()
      : super(DateRangeParams.fromEnum(ReportDateRange.last30Days));

  void setRange(ReportDateRange range) {
    state = DateRangeParams.fromEnum(range);
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = DateRangeParams(
      start: start,
      end: end,
      label: 'Özel Aralık',
    );
  }
}

final reportsDateRangeProvider =
    StateNotifierProvider<ReportsDateRangeNotifier, DateRangeParams>(
  (ref) => ReportsDateRangeNotifier(),
);

// ─── Data Models ─────────────────────────────────────────────────────────────

class RevenueByService {
  final String service;
  final String label;
  final double revenue;
  final int orderCount;
  final double avgOrderValue;
  final Color color;

  const RevenueByService({
    required this.service,
    required this.label,
    required this.revenue,
    required this.orderCount,
    required this.avgOrderValue,
    required this.color,
  });
}

class DailyRevenuePoint {
  final DateTime date;
  final double revenue;

  const DailyRevenuePoint({required this.date, required this.revenue});
}

class TopMerchantRevenue {
  final String name;
  final String serviceType;
  final double revenue;
  final int orderCount;

  const TopMerchantRevenue({
    required this.name,
    required this.serviceType,
    required this.revenue,
    required this.orderCount,
  });
}

class RevenueReportData {
  final double totalRevenue;
  final List<RevenueByService> byService;
  final List<DailyRevenuePoint> dailyRevenue;
  final List<TopMerchantRevenue> topMerchants;

  const RevenueReportData({
    required this.totalRevenue,
    required this.byService,
    required this.dailyRevenue,
    required this.topMerchants,
  });
}

class DailyUserPoint {
  final DateTime date;
  final int newUsers;

  const DailyUserPoint({required this.date, required this.newUsers});
}

class UserGrowthData {
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final List<DailyUserPoint> dailyNewUsers;

  const UserGrowthData({
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.dailyNewUsers,
  });
}

class OrderStatsData {
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int pendingOrders;
  final double avgOrderValue;
  final Map<String, int> byService;
  final Map<String, int> byStatus;
  final List<List<int>> hourlyHeatmap; // [dayOfWeek][hour] counts

  const OrderStatsData({
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.pendingOrders,
    required this.avgOrderValue,
    required this.byService,
    required this.byStatus,
    required this.hourlyHeatmap,
  });
}

class PlatformSummaryData {
  final int totalMerchants;
  final int totalUsers;
  final int totalOrders;
  final double totalRevenue;
  final List<RevenueByService> serviceComparison;

  const PlatformSummaryData({
    required this.totalMerchants,
    required this.totalUsers,
    required this.totalOrders,
    required this.totalRevenue,
    required this.serviceComparison,
  });
}

// ─── Providers ────────────────────────────────────────────────────────────────

final revenueReportProvider =
    FutureProvider.family<RevenueReportData, DateRangeParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseProvider);
    final fmt = DateFormat('yyyy-MM-dd');
    final startStr = fmt.format(params.start);
    final endStr = fmt.format(params.end);

    // Query orders grouped by service type for revenue
    final ordersRes = await supabase
        .from('orders')
        .select('total_amount, status, created_at, merchant_id, merchants(type, business_name)')
        .gte('created_at', '${startStr}T00:00:00')
        .lte('created_at', '${endStr}T23:59:59')
        .eq('status', 'delivered');

    final orders = ordersRes as List<dynamic>;

    // Aggregate by service
    final Map<String, double> revenueMap = {};
    final Map<String, int> countMap = {};
    final Map<String, double> merchantRevenue = {};
    final Map<String, int> merchantCount = {};
    final Map<String, String> merchantService = {};

    for (final o in orders) {
      final merchantData = o['merchants'] as Map<String, dynamic>?;
      final rawType = (merchantData?['type'] as String?) ?? 'other';
      final type = rawType == 'restaurant' ? 'food' : rawType;
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      revenueMap[type] = (revenueMap[type] ?? 0) + amount;
      countMap[type] = (countMap[type] ?? 0) + 1;

      // Merchant aggregation
      final merchantName = merchantData?['business_name'] as String? ?? 'Bilinmeyen';
      final key = '${merchantName}_$type';
      merchantRevenue[key] = (merchantRevenue[key] ?? 0) + amount;
      merchantCount[key] = (merchantCount[key] ?? 0) + 1;
      merchantService[key] = type;
    }

    // Build service data
    final serviceColors = {
      'food': AppColors.chartColors[0],
      'store': AppColors.chartColors[1],
      'taxi': AppColors.chartColors[2],
      'rental': AppColors.chartColors[3],
      'emlak': AppColors.chartColors[4],
      'car_sales': AppColors.chartColors[5],
      'jobs': AppColors.chartColors[6],
    };

    final serviceLabels = {
      'food': 'Yemek',
      'store': 'Market',
      'taxi': 'Taksi',
      'rental': 'Araç Kiralama',
      'emlak': 'Emlak',
      'car_sales': 'Araç Satış',
      'jobs': 'İş İlanları',
    };

    final allServices = serviceColors.keys.toList();
    final byService = allServices.map((s) {
      final rev = revenueMap[s] ?? 0;
      final cnt = countMap[s] ?? 0;
      return RevenueByService(
        service: s,
        label: serviceLabels[s] ?? s,
        revenue: rev,
        orderCount: cnt,
        avgOrderValue: cnt > 0 ? rev / cnt : 0,
        color: serviceColors[s] ?? AppColors.primary,
      );
    }).toList();

    final totalRevenue = byService.fold<double>(0, (s, e) => s + e.revenue);

    // Build daily revenue - iterate each day in range
    final dayCount = params.end.difference(params.start).inDays + 1;
    final dailyMap = <String, double>{};

    for (final o in orders) {
      final createdAt = DateTime.tryParse(o['created_at'] as String? ?? '');
      if (createdAt == null) continue;
      final dayKey = fmt.format(createdAt);
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      dailyMap[dayKey] = (dailyMap[dayKey] ?? 0) + amount;
    }

    final dailyRevenue = List.generate(dayCount, (i) {
      final date = params.start.add(Duration(days: i));
      final key = fmt.format(date);
      return DailyRevenuePoint(date: date, revenue: dailyMap[key] ?? 0);
    });

    // Top 10 merchants
    final merchantEntries = merchantRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10 = merchantEntries.take(10).map((e) {
      final parts = e.key.split('_');
      final name = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('_') : e.key;
      return TopMerchantRevenue(
        name: name,
        serviceType: serviceLabels[merchantService[e.key]] ?? (merchantService[e.key] ?? ''),
        revenue: e.value,
        orderCount: merchantCount[e.key] ?? 0,
      );
    }).toList();

    return RevenueReportData(
      totalRevenue: totalRevenue,
      byService: byService,
      dailyRevenue: dailyRevenue,
      topMerchants: top10,
    );
  },
);

final userGrowthProvider =
    FutureProvider.family<UserGrowthData, DateRangeParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseProvider);
    final fmt = DateFormat('yyyy-MM-dd');

    // Total users
    final totalRes = await supabase
        .from('users')
        .select('id, created_at')
        .order('created_at', ascending: true);

    final allUsers = totalRes as List<dynamic>;
    final totalUsers = allUsers.length;
    final activeUsers = totalUsers; // all registered users considered active
    final inactiveUsers = 0;

    // New users in range
    final rangeUsers = allUsers
        .where((u) {
          final created = DateTime.tryParse(u['created_at'] as String? ?? '');
          if (created == null) return false;
          return !created.isBefore(params.start) &&
              !created.isAfter(params.end.add(const Duration(days: 1)));
        })
        .toList();

    // Group by day
    final dayCount = params.end.difference(params.start).inDays + 1;
    final dailyMap = <String, int>{};
    for (final u in rangeUsers) {
      final created = DateTime.tryParse(u['created_at'] as String? ?? '');
      if (created == null) continue;
      final key = fmt.format(created);
      dailyMap[key] = (dailyMap[key] ?? 0) + 1;
    }

    final dailyNewUsers = List.generate(dayCount, (i) {
      final date = params.start.add(Duration(days: i));
      return DailyUserPoint(date: date, newUsers: dailyMap[fmt.format(date)] ?? 0);
    });

    return UserGrowthData(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      inactiveUsers: inactiveUsers,
      dailyNewUsers: dailyNewUsers,
    );
  },
);

final orderStatsProvider =
    FutureProvider.family<OrderStatsData, DateRangeParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseProvider);
    final fmt = DateFormat('yyyy-MM-dd');
    final startStr = fmt.format(params.start);
    final endStr = fmt.format(params.end);

    final ordersRes = await supabase
        .from('orders')
        .select('total_amount, status, created_at, merchants(type)')
        .gte('created_at', '${startStr}T00:00:00')
        .lte('created_at', '${endStr}T23:59:59');

    final orders = ordersRes as List<dynamic>;
    final total = orders.length;

    int completed = 0, cancelled = 0, pending = 0;
    double totalAmount = 0;
    final Map<String, int> byService = {};
    final Map<String, int> byStatus = {};
    // heatmap: [dayOfWeek 0=Mon..6=Sun][hour 0..23]
    final heatmap = List.generate(7, (_) => List.filled(24, 0));

    for (final o in orders) {
      final status = (o['status'] as String?) ?? '';
      final merchantData = o['merchants'] as Map<String, dynamic>?;
      final rawType = (merchantData?['type'] as String?) ?? 'other';
      final type = rawType == 'restaurant' ? 'food' : rawType;
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      final createdAt = DateTime.tryParse(o['created_at'] as String? ?? '');

      if (status == 'delivered') {
        completed++;
        totalAmount += amount;
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        pending++;
      }

      byService[type] = (byService[type] ?? 0) + 1;
      byStatus[status] = (byStatus[status] ?? 0) + 1;

      if (createdAt != null) {
        final dow = createdAt.weekday - 1; // 0=Mon
        final hour = createdAt.hour;
        heatmap[dow][hour]++;
      }
    }

    return OrderStatsData(
      totalOrders: total,
      completedOrders: completed,
      cancelledOrders: cancelled,
      pendingOrders: pending,
      avgOrderValue: completed > 0 ? totalAmount / completed : 0,
      byService: byService,
      byStatus: byStatus,
      hourlyHeatmap: heatmap,
    );
  },
);

final platformSummaryProvider =
    FutureProvider.family<PlatformSummaryData, DateRangeParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseProvider);
    final fmt = DateFormat('yyyy-MM-dd');
    final startStr = fmt.format(params.start);
    final endStr = fmt.format(params.end);

    final merchantRes = await supabase.from('merchants').select('id').count();
    final userRes = await supabase.from('users').select('id').count();
    final ordersRes = await supabase
        .from('orders')
        .select('total_amount, status, merchants(type)')
        .gte('created_at', '${startStr}T00:00:00')
        .lte('created_at', '${endStr}T23:59:59');

    final merchantCount = merchantRes.count;
    final userCount = userRes.count;
    final orders = ordersRes as List<dynamic>;

    final serviceLabels = {
      'food': 'Yemek',
      'store': 'Market',
      'taxi': 'Taksi',
      'rental': 'Araç Kiralama',
      'emlak': 'Emlak',
      'car_sales': 'Araç Satış',
      'jobs': 'İş İlanları',
    };

    final serviceColors = {
      'food': AppColors.chartColors[0],
      'store': AppColors.chartColors[1],
      'taxi': AppColors.chartColors[2],
      'rental': AppColors.chartColors[3],
      'emlak': AppColors.chartColors[4],
      'car_sales': AppColors.chartColors[5],
      'jobs': AppColors.chartColors[6],
    };

    int totalOrders = 0;
    double totalRevenue = 0;
    final Map<String, double> revenueMap = {};
    final Map<String, int> countMap = {};

    for (final o in orders) {
      final merchantData = o['merchants'] as Map<String, dynamic>?;
      final rawType = (merchantData?['type'] as String?) ?? 'other';
      final type = rawType == 'restaurant' ? 'food' : rawType;
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      final status = (o['status'] as String?) ?? '';
      totalOrders++;
      revenueMap[type] = (revenueMap[type] ?? 0) + amount;
      countMap[type] = (countMap[type] ?? 0) + 1;
      if (status == 'delivered') totalRevenue += amount;
    }

    final serviceComparison = serviceLabels.keys.map((s) {
      final rev = revenueMap[s] ?? 0;
      final cnt = countMap[s] ?? 0;
      return RevenueByService(
        service: s,
        label: serviceLabels[s]!,
        revenue: rev,
        orderCount: cnt,
        avgOrderValue: cnt > 0 ? rev / cnt : 0,
        color: serviceColors[s] ?? AppColors.primary,
      );
    }).toList();

    return PlatformSummaryData(
      totalMerchants: merchantCount,
      totalUsers: userCount,
      totalOrders: totalOrders,
      totalRevenue: totalRevenue,
      serviceComparison: serviceComparison,
    );
  },
);

// ─── Main Screen ──────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _touchedPieIndex = -1;
  int _touchedOrderPieIndex = -1;

  final _currencyFmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
  final _numberFmt = NumberFormat('#,##0', 'tr_TR');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '₺${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '₺${(value / 1000).toStringAsFixed(1)}B';
    }
    return _currencyFmt.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(reportsDateRangeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(dateRange),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RevenueTab(
                  formatCurrency: _formatCurrency,
                  currencyFmt: _currencyFmt,
                  numberFmt: _numberFmt,
                  touchedPieIndex: _touchedPieIndex,
                  onPieTouched: (i) => setState(() => _touchedPieIndex = i),
                ),
                _UserGrowthTab(
                  formatNumber: _numberFmt.format,
                ),
                _OrderStatsTab(
                  formatCurrency: _formatCurrency,
                  numberFmt: _numberFmt,
                  touchedPieIndex: _touchedOrderPieIndex,
                  onPieTouched: (i) => setState(() => _touchedOrderPieIndex = i),
                ),
                _PlatformSummaryTab(
                  formatCurrency: _formatCurrency,
                  numberFmt: _numberFmt,
                ),
                _FinanceReportTab(
                  formatCurrency: _formatCurrency,
                  currencyFmt: _currencyFmt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(DateRangeParams dateRange) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Raporlar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Platform verilerini analiz edin ve raporları indirin.',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          _buildDateRangeSelector(dateRange),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(DateRangeParams current) {
    return Row(
      children: [
        _DateChip(
          label: 'Son 7 Gün',
          selected: current.label == 'Son 7 Gün',
          onTap: () => ref
              .read(reportsDateRangeProvider.notifier)
              .setRange(ReportDateRange.last7Days),
        ),
        const SizedBox(width: 8),
        _DateChip(
          label: 'Son 30 Gün',
          selected: current.label == 'Son 30 Gün',
          onTap: () => ref
              .read(reportsDateRangeProvider.notifier)
              .setRange(ReportDateRange.last30Days),
        ),
        const SizedBox(width: 8),
        _DateChip(
          label: 'Son 90 Gün',
          selected: current.label == 'Son 90 Gün',
          onTap: () => ref
              .read(reportsDateRangeProvider.notifier)
              .setRange(ReportDateRange.last90Days),
        ),
        const SizedBox(width: 8),
        _DateChip(
          label: 'Özel Aralık',
          selected: current.label == 'Özel Aralık',
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: now,
              initialDateRange: DateTimeRange(
                start: current.start,
                end: current.end,
              ),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) {
              ref
                  .read(reportsDateRangeProvider.notifier)
                  .setCustomRange(picked.start, picked.end);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: const [
          Tab(text: 'Gelir Raporu'),
          Tab(text: 'Kullanıcı Büyümesi'),
          Tab(text: 'Sipariş İstatistikleri'),
          Tab(text: 'Platform Özeti'),
          Tab(text: 'Finans Raporu'),
        ],
      ),
    );
  }
}

// ─── Date Chip ────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ─── Tab 1: Gelir Raporu ──────────────────────────────────────────────────────

class _RevenueTab extends ConsumerWidget {
  final String Function(double) formatCurrency;
  final NumberFormat currencyFmt;
  final NumberFormat numberFmt;
  final int touchedPieIndex;
  final ValueChanged<int> onPieTouched;

  const _RevenueTab({
    required this.formatCurrency,
    required this.currencyFmt,
    required this.numberFmt,
    required this.touchedPieIndex,
    required this.onPieTouched,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportsDateRangeProvider);
    final dataAsync = ref.watch(revenueReportProvider(dateRange));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: dataAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => _ErrorCard(message: e.toString()),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Revenue Stat Card
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Toplam Gelir',
                    value: formatCurrency(data.totalRevenue),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.success,
                    subtitle: dateRange.label,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Toplam Sipariş',
                    value: numberFmt.format(
                        data.byService.fold<int>(0, (s, e) => s + e.orderCount)),
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.primary,
                    subtitle: 'Tamamlanan',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Ortalama Sipariş',
                    value: () {
                      final totalOrders = data.byService
                          .fold<int>(0, (s, e) => s + e.orderCount);
                      return totalOrders > 0
                          ? formatCurrency(data.totalRevenue / totalOrders)
                          : '₺0';
                    }(),
                    icon: Icons.trending_up_outlined,
                    color: AppColors.warning,
                    subtitle: 'Sipariş başına',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'En Yüksek Gelir',
                    value: () {
                      final sorted = [...data.byService]
                        ..sort((a, b) => b.revenue.compareTo(a.revenue));
                      return sorted.isNotEmpty ? sorted.first.label : '-';
                    }(),
                    icon: Icons.emoji_events_outlined,
                    color: AppColors.info,
                    subtitle: 'Hizmet kategorisi',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bar Chart - Revenue by Service
                Expanded(
                  flex: 3,
                  child: ChartCard(
                    title: 'Hizmete Göre Gelir',
                    subtitle: 'Kategori bazında gelir dağılımı',
                    actions: [
                      TextButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Excel'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                    chart: SizedBox(
                      height: 280,
                      child: _buildRevenueBarChart(data.byService),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Legend
                Expanded(
                  child: _buildServiceLegendCard(data.byService),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Daily Revenue Line Chart
            ChartCard(
              title: 'Günlük Gelir',
              subtitle: '${dateRange.label} - Günlük gelir trendi',
              chart: SizedBox(
                height: 240,
                child: _buildDailyRevenueLineChart(data.dailyRevenue),
              ),
            ),

            const SizedBox(height: 24),

            // Top Merchants Table
            _buildTopMerchantsCard(data.topMerchants, context),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueBarChart(List<RevenueByService> services) {
    final nonEmpty = services.where((s) => s.revenue > 0).toList();
    if (nonEmpty.isEmpty) {
      return const Center(
        child: Text('Bu dönemde gelir verisi bulunamadı.',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final maxRevenue = nonEmpty.map((s) => s.revenue).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxRevenue * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final service = nonEmpty[groupIndex];
              return BarTooltipItem(
                '${service.label}\n₺${(rod.toY / 1000).toStringAsFixed(1)}B',
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= nonEmpty.length) return const SizedBox();
                final parts = nonEmpty[idx].label.split(' ');
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    parts.first,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, _) => Text(
                '₺${(value / 1000).toStringAsFixed(0)}B',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.surfaceLight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: nonEmpty.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.revenue,
                color: entry.value.color,
                width: 32,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxRevenue * 1.2,
                  color: AppColors.surfaceLight.withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServiceLegendCard(List<RevenueByService> services) {
    final total = services.fold<double>(0, (s, e) => s + e.revenue);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gelir Dağılımı',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...services
              .where((s) => s.revenue > 0)
              .map((s) {
                final pct = total > 0 ? (s.revenue / total * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? s.revenue / total : 0,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation<Color>(s.color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildDailyRevenueLineChart(List<DailyRevenuePoint> days) {
    if (days.isEmpty) {
      return const Center(
        child: Text('Veri bulunamadı.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final maxY = days.map((d) => d.revenue).fold<double>(0, (a, b) => a > b ? a : b);
    final spots = days.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.revenue))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.surfaceLight,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (days.length / 5).ceilToDouble(),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('d MMM', 'tr').format(days[idx].date),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, _) => Text(
                '₺${(value / 1000).toStringAsFixed(0)}B',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (days.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.2,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            getTooltipItems: (spots) => spots.map((spot) {
              final idx = spot.x.toInt();
              final day = idx < days.length ? days[idx] : null;
              return LineTooltipItem(
                '${day != null ? DateFormat('d MMM', 'tr').format(day.date) : ''}\n₺${(spot.y / 1000).toStringAsFixed(1)}B',
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMerchantsCard(List<TopMerchantRevenue> merchants, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'En Yüksek Gelirli İşletmeler',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gelire göre sıralanmış ilk 10 işletme',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: null,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Excel\'e Aktar'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (merchants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Bu dönemde veri bulunamadı.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    AppColors.surfaceLight.withValues(alpha: 0.5)),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return AppColors.surfaceLight.withValues(alpha: 0.3);
                  }
                  return null;
                }),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('İşletme Adı')),
                  DataColumn(label: Text('Hizmet')),
                  DataColumn(label: Text('Gelir'), numeric: true),
                  DataColumn(label: Text('Sipariş'), numeric: true),
                  DataColumn(label: Text('Ort. Sipariş'), numeric: true),
                ],
                rows: merchants.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  return DataRow(cells: [
                    DataCell(Text(
                      '${i + 1}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    )),
                    DataCell(Text(m.name,
                        style: const TextStyle(color: AppColors.textPrimary))),
                    DataCell(Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m.serviceType,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    )),
                    DataCell(Text(
                      currencyFmt.format(m.revenue),
                      style: const TextStyle(
                          color: AppColors.success, fontWeight: FontWeight.w600),
                    )),
                    DataCell(Text('${m.orderCount}',
                        style: const TextStyle(color: AppColors.textPrimary))),
                    DataCell(Text(
                      m.orderCount > 0
                          ? currencyFmt.format(m.revenue / m.orderCount)
                          : '-',
                      style: const TextStyle(color: AppColors.textSecondary),
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

}

// ─── Tab 2: Kullanıcı Büyümesi ────────────────────────────────────────────────

class _UserGrowthTab extends ConsumerWidget {
  final String Function(num) formatNumber;

  const _UserGrowthTab({required this.formatNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportsDateRangeProvider);
    final dataAsync = ref.watch(userGrowthProvider(dateRange));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: dataAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => _ErrorCard(message: e.toString()),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Toplam Kullanıcı',
                    value: formatNumber(data.totalUsers),
                    icon: Icons.people_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Aktif Kullanıcı',
                    value: formatNumber(data.activeUsers),
                    icon: Icons.person_outline,
                    color: AppColors.success,
                    trend: data.totalUsers > 0
                        ? '${(data.activeUsers / data.totalUsers * 100).toStringAsFixed(1)}%'
                        : null,
                    trendUp: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Pasif Kullanıcı',
                    value: formatNumber(data.inactiveUsers),
                    icon: Icons.person_off_outlined,
                    color: AppColors.textMuted,
                    trend: data.totalUsers > 0
                        ? '${(data.inactiveUsers / data.totalUsers * 100).toStringAsFixed(1)}%'
                        : null,
                    trendUp: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Dönemdeki Yeni Kayıt',
                    value: formatNumber(
                        data.dailyNewUsers.fold<int>(0, (s, e) => s + e.newUsers)),
                    icon: Icons.person_add_outlined,
                    color: AppColors.info,
                    subtitle: dateRange.label,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Charts
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line Chart
                Expanded(
                  flex: 3,
                  child: ChartCard(
                    title: 'Günlük Yeni Kullanıcılar',
                    subtitle: 'Seçili dönemde kayıt olan kullanıcılar',
                    chart: SizedBox(
                      height: 280,
                      child: _buildNewUsersLineChart(data.dailyNewUsers),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Pie Chart
                Expanded(
                  child: ChartCard(
                    title: 'Aktif / Pasif',
                    subtitle: 'Kullanıcı durumu',
                    chart: SizedBox(
                      height: 280,
                      child: _buildUserStatusPie(data),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewUsersLineChart(List<DailyUserPoint> days) {
    if (days.isEmpty) {
      return const Center(
          child: Text('Veri bulunamadı.',
              style: TextStyle(color: AppColors.textMuted)));
    }

    final maxY = days
        .map((d) => d.newUsers.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    final spots = days.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.newUsers.toDouble()))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.surfaceLight,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (days.length / 5).ceilToDouble(),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('d MMM', 'tr').format(days[idx].date),
                    style:
                        const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (days.length - 1).toDouble(),
        minY: 0,
        maxY: maxY * 1.2 + 1,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            getTooltipItems: (spots) => spots.map((spot) {
              final idx = spot.x.toInt();
              final day = idx < days.length ? days[idx] : null;
              return LineTooltipItem(
                '${day != null ? DateFormat('d MMM', 'tr').format(day.date) : ''}\n${spot.y.toInt()} kullanıcı',
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.info,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.info.withValues(alpha: 0.3),
                  AppColors.info.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatusPie(UserGrowthData data) {
    if (data.totalUsers == 0) {
      return const Center(
          child: Text('Veri bulunamadı.',
              style: TextStyle(color: AppColors.textMuted)));
    }

    final sections = [
      PieChartSectionData(
        value: data.activeUsers.toDouble(),
        title: '${(data.activeUsers / data.totalUsers * 100).toStringAsFixed(1)}%',
        color: AppColors.success,
        radius: 80,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: data.inactiveUsers.toDouble(),
        title: '${(data.inactiveUsers / data.totalUsers * 100).toStringAsFixed(1)}%',
        color: AppColors.surfaceLight,
        radius: 80,
        titleStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.success, label: 'Aktif'),
            const SizedBox(width: 16),
            _LegendDot(color: AppColors.surfaceLight, label: 'Pasif'),
          ],
        ),
      ],
    );
  }
}

// ─── Tab 3: Sipariş İstatistikleri ───────────────────────────────────────────

class _OrderStatsTab extends ConsumerWidget {
  final String Function(double) formatCurrency;
  final NumberFormat numberFmt;
  final int touchedPieIndex;
  final ValueChanged<int> onPieTouched;

  const _OrderStatsTab({
    required this.formatCurrency,
    required this.numberFmt,
    required this.touchedPieIndex,
    required this.onPieTouched,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportsDateRangeProvider);
    final dataAsync = ref.watch(orderStatsProvider(dateRange));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: dataAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => _ErrorCard(message: e.toString()),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Toplam Sipariş',
                    value: numberFmt.format(data.totalOrders),
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.primary,
                    subtitle: dateRange.label,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Tamamlanan',
                    value: numberFmt.format(data.completedOrders),
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    trend: data.totalOrders > 0
                        ? '${(data.completedOrders / data.totalOrders * 100).toStringAsFixed(1)}%'
                        : null,
                    trendUp: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'İptal Edilen',
                    value: numberFmt.format(data.cancelledOrders),
                    icon: Icons.cancel_outlined,
                    color: AppColors.error,
                    trend: data.totalOrders > 0
                        ? '${(data.cancelledOrders / data.totalOrders * 100).toStringAsFixed(1)}%'
                        : null,
                    trendUp: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Ortalama Sipariş Değeri',
                    value: formatCurrency(data.avgOrderValue),
                    icon: Icons.paid_outlined,
                    color: AppColors.warning,
                    subtitle: 'Tamamlanan sipariş',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Orders by Status - Bar Chart
                Expanded(
                  flex: 2,
                  child: ChartCard(
                    title: 'Duruma Göre Siparişler',
                    subtitle: 'Sipariş durumu dağılımı',
                    actions: [
                      TextButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Excel'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary),
                      ),
                    ],
                    chart: SizedBox(
                      height: 240,
                      child: _buildStatusBarChart(data.byStatus),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Orders by Service - Pie Chart
                Expanded(
                  child: ChartCard(
                    title: 'Hizmete Göre Siparişler',
                    subtitle: 'Kategori dağılımı',
                    chart: SizedBox(
                      height: 240,
                      child: _buildServicePieChart(data.byService),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Heatmap
            _buildHeatmapCard(data.hourlyHeatmap),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBarChart(Map<String, int> byStatus) {
    final statusLabels = {
      'delivered': 'Tamamlandı',
      'cancelled': 'İptal',
      'pending': 'Bekliyor',
      'ready': 'Hazır',
      'pickedUp': 'Yolda',
    };
    final statusColors = {
      'delivered': AppColors.success,
      'cancelled': AppColors.error,
      'pending': AppColors.warning,
      'ready': AppColors.info,
      'pickedUp': AppColors.primary,
    };

    final entries = byStatus.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Center(
          child: Text('Veri bulunamadı.',
              style: TextStyle(color: AppColors.textMuted)));
    }

    final maxY = entries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = entries[groupIndex];
              return BarTooltipItem(
                '${statusLabels[entry.key] ?? entry.key}\n${rod.toY.toInt()} sipariş',
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    statusLabels[entries[idx].key] ?? entries[idx].key,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.surfaceLight, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) {
          final color =
              statusColors[entry.value.key] ?? AppColors.chartColors[entry.key % AppColors.chartColors.length];
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: color,
                width: 36,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServicePieChart(Map<String, int> byService) {
    final serviceLabels = {
      'food': 'Yemek',
      'store': 'Market',
      'taxi': 'Taksi',
      'rental': 'Kiralama',
      'emlak': 'Emlak',
      'car_sales': 'Araç Satış',
      'jobs': 'İş İlanı',
    };

    final entries = byService.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Center(
          child: Text('Veri bulunamadı.',
              style: TextStyle(color: AppColors.textMuted)));
    }

    final total = entries.fold<int>(0, (s, e) => s + e.value);

    final sections = entries.asMap().entries.map((e) {
      final color = AppColors.chartColors[e.key % AppColors.chartColors.length];
      final pct = total > 0 ? e.value.value / total * 100 : 0.0;
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        title: '${pct.toStringAsFixed(0)}%',
        color: color,
        radius: 70,
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: entries.asMap().entries.map((e) {
            final color =
                AppColors.chartColors[e.key % AppColors.chartColors.length];
            return _LegendDot(
              color: color,
              label: serviceLabels[e.value.key] ?? e.value.key,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHeatmapCard(List<List<int>> heatmap) {
    final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final maxVal = heatmap.expand((d) => d).fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sipariş Yoğunluğu Haritası',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gün ve saate göre sipariş yoğunluğu',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          // Hour headers
          Row(
            children: [
              const SizedBox(width: 40),
              ...List.generate(24, (h) {
                if (h % 3 != 0) return const Expanded(child: SizedBox());
                return Expanded(
                  child: Text(
                    '$h',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          ...List.generate(7, (day) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      days[day],
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ),
                  ...List.generate(24, (hour) {
                    final count = heatmap[day][hour];
                    final intensity =
                        maxVal > 0 ? count / maxVal : 0.0;
                    return Expanded(
                      child: Tooltip(
                        message: '${days[day]} $hour:00 — $count sipariş',
                        child: Container(
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: intensity == 0
                                ? AppColors.surfaceLight.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.1 + intensity * 0.9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Az',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(width: 6),
              ...List.generate(5, (i) {
                final intensity = (i + 1) / 5;
                return Container(
                  width: 20,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1 + intensity * 0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 6),
              const Text('Çok',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab 4: Platform Özeti ────────────────────────────────────────────────────

class _PlatformSummaryTab extends ConsumerWidget {
  final String Function(double) formatCurrency;
  final NumberFormat numberFmt;

  const _PlatformSummaryTab({
    required this.formatCurrency,
    required this.numberFmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportsDateRangeProvider);
    final dataAsync = ref.watch(platformSummaryProvider(dateRange));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: dataAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        error: (e, _) => _ErrorCard(message: e.toString()),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Toplam İşletme',
                    value: numberFmt.format(data.totalMerchants),
                    icon: Icons.store_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Toplam Kullanıcı',
                    value: numberFmt.format(data.totalUsers),
                    icon: Icons.people_rounded,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Dönem Sipariş',
                    value: numberFmt.format(data.totalOrders),
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.warning,
                    subtitle: dateRange.label,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Dönem Gelir',
                    value: formatCurrency(data.totalRevenue),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.success,
                    subtitle: dateRange.label,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Service Comparison Table
            _buildServiceComparisonCard(data.serviceComparison, context),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceComparisonCard(
      List<RevenueByService> services, BuildContext context) {
    final totalRevenue = services.fold<double>(0, (s, e) => s + e.revenue);
    final totalOrders = services.fold<int>(0, (s, e) => s + e.orderCount);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hizmet Bazında Karşılaştırma',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tüm hizmetlerin gelir ve sipariş performansı',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                  AppColors.surfaceLight.withValues(alpha: 0.5)),
              columns: const [
                DataColumn(label: Text('Hizmet')),
                DataColumn(label: Text('Sipariş Sayısı'), numeric: true),
                DataColumn(label: Text('Gelir'), numeric: true),
                DataColumn(label: Text('Ort. Sipariş'), numeric: true),
                DataColumn(label: Text('Sipariş Payı'), numeric: true),
                DataColumn(label: Text('Gelir Payı'), numeric: true),
              ],
              rows: services.map((s) {
                final orderShare =
                    totalOrders > 0 ? s.orderCount / totalOrders * 100 : 0.0;
                final revenueShare =
                    totalRevenue > 0 ? s.revenue / totalRevenue * 100 : 0.0;

                return DataRow(cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(s.label,
                          style:
                              const TextStyle(color: AppColors.textPrimary)),
                    ],
                  )),
                  DataCell(Text(
                    numberFmt.format(s.orderCount),
                    style: const TextStyle(color: AppColors.textPrimary),
                  )),
                  DataCell(Text(
                    formatCurrency(s.revenue),
                    style: TextStyle(
                      color: s.revenue > 0
                          ? AppColors.success
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  )),
                  DataCell(Text(
                    s.orderCount > 0
                        ? formatCurrency(s.avgOrderValue)
                        : '-',
                    style: const TextStyle(color: AppColors.textSecondary),
                  )),
                  DataCell(_PercentBar(
                    value: orderShare,
                    color: s.color,
                  )),
                  DataCell(_PercentBar(
                    value: revenueShare,
                    color: s.color,
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Small Widgets ─────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _PercentBar extends StatelessWidget {
  final double value;
  final Color color;

  const _PercentBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${value.toStringAsFixed(1)}%',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 80),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Veri yüklenirken hata oluştu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Finance Report Data ──────────────────────────────────────────────────────

class FinanceReportData {
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final double totalKdv;
  final List<SourceRevenue> bySource;
  final List<CategoryRevenue> byCategory;

  const FinanceReportData({
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.totalKdv,
    required this.bySource,
    required this.byCategory,
  });
}

class SourceRevenue {
  final String source;
  final String label;
  final double income;
  final double expense;
  final int count;
  final Color color;

  const SourceRevenue({
    required this.source,
    required this.label,
    required this.income,
    required this.expense,
    required this.count,
    required this.color,
  });
}

class CategoryRevenue {
  final String category;
  final double total;
  final int count;

  const CategoryRevenue({required this.category, required this.total, required this.count});
}

final financeReportProvider =
    FutureProvider.family<FinanceReportData, DateRangeParams>(
  (ref, params) async {
    final supabase = ref.watch(supabaseProvider);
    final fmt = DateFormat('yyyy-MM-dd');
    final startStr = '${fmt.format(params.start)}T00:00:00';
    final endStr = '${fmt.format(params.end)}T23:59:59';

    final result = await supabase
        .from('finance_entries')
        .select()
        .gte('created_at', startStr)
        .lte('created_at', endStr)
        .order('created_at', ascending: false);

    final entries = result as List<dynamic>;

    double totalIncome = 0, totalExpense = 0, totalKdv = 0;
    final Map<String, double> sourceIncome = {};
    final Map<String, double> sourceExpense = {};
    final Map<String, int> sourceCount = {};
    final Map<String, double> categoryTotals = {};
    final Map<String, int> categoryCounts = {};

    for (final e in entries) {
      final amount = (e['amount'] as num?)?.toDouble() ?? 0;
      final kdv = (e['kdv_amount'] as num?)?.toDouble() ?? 0;
      final type = e['entry_type'] as String? ?? 'income';
      final source = e['source_type'] as String? ?? 'manual';
      final category = e['category'] as String? ?? 'Diğer';

      if (type == 'income') {
        totalIncome += amount;
        sourceIncome[source] = (sourceIncome[source] ?? 0) + amount;
      } else {
        totalExpense += amount;
        sourceExpense[source] = (sourceExpense[source] ?? 0) + amount;
      }
      totalKdv += kdv;
      sourceCount[source] = (sourceCount[source] ?? 0) + 1;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    const sourceLabels = {
      'food': 'Yemek',
      'store': 'Mağaza',
      'market': 'Market',
      'taxi': 'Taksi',
      'rental': 'Kiralama',
      'car_sales': 'Araç Satış',
      'real_estate': 'Emlak',
      'jobs': 'İş İlanları',
      'promotion': 'Öne Çıkarma',
      'manual': 'Manuel',
    };

    final sourceColors = {
      'food': AppColors.chartColors[0],
      'store': AppColors.chartColors[1],
      'taxi': AppColors.chartColors[2],
      'rental': AppColors.chartColors[3],
      'promotion': const Color(0xFFAB47BC),
      'car_sales': AppColors.chartColors[5],
      'real_estate': AppColors.chartColors[4],
      'jobs': AppColors.chartColors[6],
      'manual': AppColors.textMuted,
      'market': AppColors.chartColors[1],
    };

    final allSources = {...sourceIncome.keys, ...sourceExpense.keys};
    final bySource = allSources.map((s) => SourceRevenue(
      source: s,
      label: sourceLabels[s] ?? s,
      income: sourceIncome[s] ?? 0,
      expense: sourceExpense[s] ?? 0,
      count: sourceCount[s] ?? 0,
      color: sourceColors[s] ?? AppColors.primary,
    )).toList()
      ..sort((a, b) => (b.income + b.expense).compareTo(a.income + a.expense));

    final byCategory = categoryTotals.entries.map((e) => CategoryRevenue(
      category: e.key,
      total: e.value,
      count: categoryCounts[e.key] ?? 0,
    )).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return FinanceReportData(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netBalance: totalIncome - totalExpense,
      totalKdv: totalKdv,
      bySource: bySource,
      byCategory: byCategory,
    );
  },
);

// ─── Tab 5: Finans Raporu ────────────────────────────────────────────────────

class _FinanceReportTab extends ConsumerWidget {
  final String Function(double) formatCurrency;
  final NumberFormat currencyFmt;

  const _FinanceReportTab({
    required this.formatCurrency,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(reportsDateRangeProvider);
    final reportAsync = ref.watch(financeReportProvider(dateRange));

    return reportAsync.when(
      data: (data) => _buildContent(data),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
    );
  }

  Widget _buildContent(FinanceReportData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          Row(
            children: [
              _kpiCard('Toplam Gelir', data.totalIncome, AppColors.success, Icons.trending_up),
              const SizedBox(width: 16),
              _kpiCard('Toplam Gider', data.totalExpense, AppColors.error, Icons.trending_down),
              const SizedBox(width: 16),
              _kpiCard('Net Bakiye', data.netBalance, data.netBalance >= 0 ? AppColors.success : AppColors.error, Icons.account_balance_wallet),
              const SizedBox(width: 16),
              _kpiCard('KDV Toplam', data.totalKdv, AppColors.warning, Icons.receipt_long),
            ],
          ),
          const SizedBox(height: 24),

          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildSourceBarChart(data)),
              const SizedBox(width: 24),
              Expanded(child: _buildIncomePieChart(data)),
            ],
          ),
          const SizedBox(height: 24),

          // Source detail table
          _buildSourceTable(data),
          const SizedBox(height: 24),

          // Category breakdown table
          _buildCategoryTable(data),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(currencyFmt.format(value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBarChart(FinanceReportData data) {
    final incomeSources = data.bySource.where((s) => s.income > 0).toList();
    if (incomeSources.isEmpty) {
      return Container(
        height: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
        child: const Center(child: Text('Henüz gelir verisi yok', style: TextStyle(color: AppColors.textMuted))),
      );
    }
    final maxVal = incomeSources.map((s) => s.income).reduce((a, b) => a > b ? a : b);
    final chartMax = (maxVal * 1.2).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kaynak Bazlı Gelir', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Gelir kaynağına göre kırılım', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final src = incomeSources[groupIndex];
                      return BarTooltipItem('${src.label}\n${currencyFmt.format(src.income)}', const TextStyle(color: Colors.white, fontSize: 12));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 55, getTitlesWidget: (v, _) => Text(v >= 1000 ? '${(v / 1000).toInt()}K' : '${v.toInt()}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => v.toInt() < incomeSources.length ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(incomeSources[v.toInt()].label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))) : const Text(''))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: chartMax / 5, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.surfaceLight.withValues(alpha: 0.5), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: incomeSources.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(toY: e.value.income, color: e.value.color, width: 20, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                ])).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomePieChart(FinanceReportData data) {
    final incomeSources = data.bySource.where((s) => s.income > 0).toList();
    final total = incomeSources.fold<double>(0, (s, e) => s + e.income);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gelir Dağılımı', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Kaynağa göre yüzde', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (total == 0)
            const SizedBox(height: 250, child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            SizedBox(
              height: 250,
              child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 45,
                sections: incomeSources.map((s) {
                  final pct = (s.income / total * 100).round();
                  return PieChartSectionData(value: s.income, title: '$pct%', color: s.color, radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
                }).toList(),
              )),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: incomeSources.map((s) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text('${s.label} (${currencyFmt.format(s.income)})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTable(FinanceReportData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kaynak Bazlı Detay', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.5),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha: 0.3)),
                children: const [
                  _TableHeader('KAYNAK'),
                  _TableHeader('GELİR'),
                  _TableHeader('GİDER'),
                  _TableHeader('NET'),
                  _TableHeader('İŞLEM'),
                ],
              ),
              ...data.bySource.map((s) {
                final net = s.income - s.expense;
                return TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)))),
                  children: [
                    _tableCell(Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 8),
                      Text(s.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                    ])),
                    _tableCell(Text(currencyFmt.format(s.income), style: const TextStyle(color: AppColors.success, fontSize: 13))),
                    _tableCell(Text(s.expense > 0 ? currencyFmt.format(s.expense) : '-', style: const TextStyle(color: AppColors.error, fontSize: 13))),
                    _tableCell(Text(currencyFmt.format(net), style: TextStyle(color: net >= 0 ? AppColors.success : AppColors.error, fontSize: 13, fontWeight: FontWeight.w600))),
                    _tableCell(Text('${s.count}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                  ],
                );
              }),
              TableRow(
                decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha: 0.2)),
                children: [
                  _tableCell(const Text('TOPLAM', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold))),
                  _tableCell(Text(currencyFmt.format(data.totalIncome), style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.bold))),
                  _tableCell(Text(currencyFmt.format(data.totalExpense), style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold))),
                  _tableCell(Text(currencyFmt.format(data.netBalance), style: TextStyle(color: data.netBalance >= 0 ? AppColors.success : AppColors.error, fontSize: 13, fontWeight: FontWeight.bold))),
                  _tableCell(Text('${data.bySource.fold<int>(0, (s, e) => s + e.count)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTable(FinanceReportData data) {
    final grandTotal = data.byCategory.fold<double>(0, (s, e) => s + e.total);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori Bazlı Kırılım', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha: 0.3)),
                children: const [
                  _TableHeader('KATEGORİ'),
                  _TableHeader('TUTAR'),
                  _TableHeader('ORAN'),
                  _TableHeader('İŞLEM'),
                ],
              ),
              ...data.byCategory.map((c) {
                final pct = grandTotal > 0 ? (c.total / grandTotal * 100) : 0;
                return TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)))),
                  children: [
                    _tableCell(Text(c.category, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                    _tableCell(Text(currencyFmt.format(c.total), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
                    _tableCell(Text('%${pct.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                    _tableCell(Text('${c.count}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: child,
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
