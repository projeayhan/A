import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Finance stats provider - gerçek veriler
final financeStatsProvider = FutureProvider.family<FinanceStats, int>((ref, days) async {
  final supabase = ref.watch(supabaseProvider);
  final result = await supabase.rpc('get_finance_stats', params: {'p_days': days});
  return FinanceStats.fromJson(result as Map<String, dynamic>);
});

// Recent transactions provider
final recentTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final result = await supabase.rpc('get_recent_transactions', params: {'p_limit': 10});
  if (result == null) return [];
  return (result as List).map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
});

class FinanceStats {
  final double totalRevenue;
  final double prevTotalRevenue;
  final double commissionRevenue;
  final double prevCommissionRevenue;
  final double partnerPayments;
  final double prevPartnerPayments;
  final double pendingPayments;
  final double foodRevenue;
  final double storeRevenue;
  final double taxiRevenue;
  final double rentalRevenue;
  final List<MonthlyRevenue> monthlyRevenue;
  final List<DailyRevenue> dailyRevenue;

  FinanceStats({
    required this.totalRevenue,
    required this.prevTotalRevenue,
    required this.commissionRevenue,
    required this.prevCommissionRevenue,
    required this.partnerPayments,
    required this.prevPartnerPayments,
    required this.pendingPayments,
    required this.foodRevenue,
    required this.storeRevenue,
    required this.taxiRevenue,
    required this.rentalRevenue,
    required this.monthlyRevenue,
    required this.dailyRevenue,
  });

  factory FinanceStats.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final distribution = json['revenue_distribution'] as Map<String, dynamic>? ?? {};
    final monthly = json['monthly_revenue'] as List? ?? [];
    final daily = json['daily_revenue'] as List? ?? [];

    return FinanceStats(
      totalRevenue: (summary['total_revenue'] as num?)?.toDouble() ?? 0,
      prevTotalRevenue: (summary['prev_total_revenue'] as num?)?.toDouble() ?? 0,
      commissionRevenue: (summary['commission_revenue'] as num?)?.toDouble() ?? 0,
      prevCommissionRevenue: (summary['prev_commission_revenue'] as num?)?.toDouble() ?? 0,
      partnerPayments: (summary['partner_payments'] as num?)?.toDouble() ?? 0,
      prevPartnerPayments: (summary['prev_partner_payments'] as num?)?.toDouble() ?? 0,
      pendingPayments: (summary['pending_payments'] as num?)?.toDouble() ?? 0,
      foodRevenue: (distribution['food_revenue'] as num?)?.toDouble() ?? 0,
      storeRevenue: (distribution['store_revenue'] as num?)?.toDouble() ?? 0,
      taxiRevenue: (distribution['taxi_revenue'] as num?)?.toDouble() ?? 0,
      rentalRevenue: (distribution['rental_revenue'] as num?)?.toDouble() ?? 0,
      monthlyRevenue: monthly.map((e) => MonthlyRevenue.fromJson(e as Map<String, dynamic>)).toList(),
      dailyRevenue: daily.map((e) => DailyRevenue.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  double get totalRevenueTrend {
    if (prevTotalRevenue == 0) return 0;
    return ((totalRevenue - prevTotalRevenue) / prevTotalRevenue) * 100;
  }

  double get commissionTrend {
    if (prevCommissionRevenue == 0) return 0;
    return ((commissionRevenue - prevCommissionRevenue) / prevCommissionRevenue) * 100;
  }

  double get partnerPaymentsTrend {
    if (prevPartnerPayments == 0) return 0;
    return ((partnerPayments - prevPartnerPayments) / prevPartnerPayments) * 100;
  }
}

class MonthlyRevenue {
  final int monthNum;
  final String monthName;
  final double revenue;
  final double commission;

  MonthlyRevenue({
    required this.monthNum,
    required this.monthName,
    required this.revenue,
    required this.commission,
  });

  factory MonthlyRevenue.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenue(
      monthNum: json['month_num'] as int? ?? 0,
      monthName: json['month_name'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DailyRevenue {
  final int dayNum;
  final String dayName;
  final double revenue;

  DailyRevenue({
    required this.dayNum,
    required this.dayName,
    required this.revenue,
  });

  factory DailyRevenue.fromJson(Map<String, dynamic> json) {
    return DailyRevenue(
      dayNum: json['day_num'] as int? ?? 0,
      dayName: json['day_name'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Transaction {
  final String id;
  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final String source;

  Transaction({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.source,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['transaction_id'] as String? ?? '',
      type: json['type'] as String? ?? 'income',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      source: json['source'] as String? ?? '',
    );
  }
}

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  int _selectedDays = 30;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(financeStatsProvider(_selectedDays));
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finans',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gelir, gider ve finansal raporlar',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildDateRangeButton(),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Rapor İndir'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Stats Cards
            statsAsync.when(
              data: (stats) => _buildStatsCards(stats),
              loading: () => _buildStatsCardsLoading(),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),

            const SizedBox(height: 32),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Revenue Chart
                Expanded(
                  flex: 2,
                  child: statsAsync.when(
                    data: (stats) => _buildChartCard(
                      'Gelir Grafiği',
                      'Aylık gelir trendi',
                      _buildRevenueChart(stats),
                    ),
                    loading: () => _buildChartCardLoading(),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                  ),
                ),
                const SizedBox(width: 24),
                // Revenue Distribution
                Expanded(
                  child: statsAsync.when(
                    data: (stats) => _buildChartCard(
                      'Gelir Dağılımı',
                      'Kaynağa göre',
                      _buildPieChart(stats),
                    ),
                    loading: () => _buildChartCardLoading(),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Transactions Table
            transactionsAsync.when(
              data: (transactions) => _buildTransactionsCard(transactions),
              loading: () => _buildTransactionsCardLoading(),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeButton() {
    return PopupMenuButton<int>(
      onSelected: (days) {
        setState(() => _selectedDays = days);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 7, child: Text('Son 7 Gün')),
        const PopupMenuItem(value: 30, child: Text('Bu Ay')),
        const PopupMenuItem(value: 90, child: Text('Son 3 Ay')),
        const PopupMenuItem(value: 365, child: Text('Bu Yıl')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              _selectedDays == 7 ? 'Son 7 Gün' :
              _selectedDays == 30 ? 'Bu Ay' :
              _selectedDays == 90 ? 'Son 3 Ay' : 'Bu Yıl',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(FinanceStats stats) {
    return Row(
      children: [
        _buildFinanceCard(
          'Toplam Gelir',
          _currencyFormat.format(stats.totalRevenue),
          stats.totalRevenueTrend,
          Icons.trending_up,
          AppColors.success,
        ),
        const SizedBox(width: 24),
        _buildFinanceCard(
          'Komisyon Geliri',
          _currencyFormat.format(stats.commissionRevenue),
          stats.commissionTrend,
          Icons.account_balance,
          AppColors.primary,
        ),
        const SizedBox(width: 24),
        _buildFinanceCard(
          'Partner Ödemeleri',
          _currencyFormat.format(stats.partnerPayments),
          stats.partnerPaymentsTrend,
          Icons.payments,
          AppColors.warning,
        ),
        const SizedBox(width: 24),
        _buildFinanceCard(
          'Bekleyen Ödeme',
          _currencyFormat.format(stats.pendingPayments),
          0, // Bekleyen ödeme için trend yok
          Icons.pending_actions,
          AppColors.info,
        ),
      ],
    );
  }

  Widget _buildStatsCardsLoading() {
    return Row(
      children: List.generate(4, (_) => Expanded(
        child: Container(
          height: 140,
          margin: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      )),
    );
  }

  Widget _buildFinanceCard(
    String title,
    String value,
    double trend,
    IconData icon,
    Color color,
  ) {
    final trendUp = trend >= 0;
    final hasTrend = trend != 0;

    return Expanded(
      child: Container(
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (hasTrend)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: trendUp
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trendUp ? Icons.trending_up : Icons.trending_down,
                          color: trendUp ? AppColors.success : AppColors.error,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trendUp ? '+' : ''}${trend.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: trendUp ? AppColors.success : AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, String subtitle, Widget chart) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 24),
          chart,
        ],
      ),
    );
  }

  Widget _buildChartCardLoading() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildRevenueChart(FinanceStats stats) {
    if (stats.monthlyRevenue.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Text(
            'Henüz veri yok',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final maxRevenue = stats.monthlyRevenue.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    final chartMax = (maxRevenue * 1.2).ceilToDouble();

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMax > 0 ? chartMax : 1000,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final month = stats.monthlyRevenue[groupIndex];
                return BarTooltipItem(
                  '${rodIndex == 0 ? 'Gelir' : 'Komisyon'}\n${_currencyFormat.format(rod.toY)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  '${(value / 1000).toInt()}K',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < stats.monthlyRevenue.length) {
                    return Text(
                      stats.monthlyRevenue[value.toInt()].monthName,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMax > 0 ? chartMax / 5 : 200,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: stats.monthlyRevenue.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.revenue,
                  color: AppColors.primary,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                BarChartRodData(
                  toY: entry.value.commission,
                  color: AppColors.success,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPieChart(FinanceStats stats) {
    final total = stats.foodRevenue + stats.storeRevenue + stats.taxiRevenue + stats.rentalRevenue;

    if (total == 0) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Text(
            'Henüz veri yok',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final foodPercent = (stats.foodRevenue / total * 100).round();
    final storePercent = (stats.storeRevenue / total * 100).round();
    final taxiPercent = (stats.taxiRevenue / total * 100).round();
    final rentalPercent = (stats.rentalRevenue / total * 100).round();

    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  if (stats.foodRevenue > 0)
                    PieChartSectionData(
                      value: stats.foodRevenue,
                      title: '$foodPercent%',
                      color: AppColors.primary,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  if (stats.storeRevenue > 0)
                    PieChartSectionData(
                      value: stats.storeRevenue,
                      title: '$storePercent%',
                      color: AppColors.success,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  if (stats.taxiRevenue > 0)
                    PieChartSectionData(
                      value: stats.taxiRevenue,
                      title: '$taxiPercent%',
                      color: AppColors.warning,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  if (stats.rentalRevenue > 0)
                    PieChartSectionData(
                      value: stats.rentalRevenue,
                      title: '$rentalPercent%',
                      color: AppColors.info,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Yemek', AppColors.primary, _currencyFormat.format(stats.foodRevenue)),
              _buildLegendItem('Market', AppColors.success, _currencyFormat.format(stats.storeRevenue)),
              _buildLegendItem('Taksi', AppColors.warning, _currencyFormat.format(stats.taxiRevenue)),
              _buildLegendItem('Kiralama', AppColors.info, _currencyFormat.format(stats.rentalRevenue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text('$label: $value', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildTransactionsCard(List<Transaction> transactions) {
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
                    'Son İşlemler',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Son komisyon işlemleri',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(child: Text('İŞLEM ID', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('AÇIKLAMA', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('TARİH', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('TUTAR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Henüz işlem yok', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...transactions.map((t) => _buildTransactionRow(t)),
        ],
      ),
    );
  }

  Widget _buildTransactionsCardLoading() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildTransactionRow(Transaction transaction) {
    final isIncome = transaction.type == 'income';
    final dateFormat = DateFormat('dd MMM yyyy', 'tr');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              transaction.id,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isIncome ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncome ? AppColors.success : AppColors.error,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(transaction.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      Text(
                        transaction.source.toUpperCase(),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(dateFormat.format(transaction.date), style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              '${isIncome ? '+' : '-'}${_currencyFormat.format(transaction.amount)}',
              style: TextStyle(
                color: isIncome ? AppColors.success : AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
