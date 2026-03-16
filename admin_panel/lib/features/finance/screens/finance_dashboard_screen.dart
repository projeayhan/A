import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import 'finance_screen.dart';

class FinanceDashboardScreen extends ConsumerStatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  ConsumerState<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends ConsumerState<FinanceDashboardScreen> {
  int _selectedDays = 30;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(financeStatsProvider(_selectedDays));

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
                    Text('Finans Dashboard', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Genel finansal özet ve hızlı erişim', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
                _buildDateRangeButton(),
              ],
            ),
            const SizedBox(height: 32),

            // 5 Summary Cards
            statsAsync.when(
              data: (stats) => _buildSummaryCards(stats),
              loading: () => _buildLoadingCards(5),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),

            const SizedBox(height: 32),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Monthly Bar Chart
                Expanded(
                  flex: 2,
                  child: statsAsync.when(
                    data: (stats) => _buildBarChartCard(stats),
                    loading: () => _buildLoadingCard(350),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                  ),
                ),
                const SizedBox(width: 24),
                // Pie Chart
                Expanded(
                  child: statsAsync.when(
                    data: (stats) => _buildPieChartCard(stats),
                    loading: () => _buildLoadingCard(350),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Quick Actions
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeButton() {
    return PopupMenuButton<int>(
      onSelected: (days) => setState(() => _selectedDays = days),
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
              _selectedDays == 7 ? 'Son 7 Gün' : _selectedDays == 30 ? 'Bu Ay' : _selectedDays == 90 ? 'Son 3 Ay' : 'Bu Yıl',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(FinanceStats stats) {
    return Row(
      children: [
        _buildCard('Toplam Gelir', stats.totalRevenue, stats.totalRevenueTrend, Icons.trending_up, AppColors.success),
        const SizedBox(width: 16),
        _buildCard('Komisyon', stats.commissionRevenue, stats.commissionTrend, Icons.account_balance, AppColors.primary),
        const SizedBox(width: 16),
        _buildCard('Net Kar', stats.netRevenue, 0, Icons.savings, AppColors.info),
        const SizedBox(width: 16),
        _buildCard('Bekleyen', stats.pendingPayments, 0, Icons.pending_actions, AppColors.warning),
        const SizedBox(width: 16),
        _buildCard('KDV', stats.totalRevenue * 0.18, 0, Icons.receipt_long, AppColors.error),
      ],
    );
  }

  Widget _buildCard(String title, double value, double trend, IconData icon, Color color) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (trend != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (trend >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                      style: TextStyle(color: trend >= 0 ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_currencyFormat.format(value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(FinanceStats stats) {
    final maxRevenue = stats.monthlyRevenue.isNotEmpty
        ? stats.monthlyRevenue.map((e) => e.revenue).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final chartMax = maxRevenue > 0 ? (maxRevenue * 1.2).ceilToDouble() : 1000.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aylık Gelir', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Gelir ve komisyon trendi', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (stats.monthlyRevenue.isEmpty)
            const SizedBox(height: 300, child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMax,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => Text('${(v / 1000).toInt()}K', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => v.toInt() < stats.monthlyRevenue.length ? Text(stats.monthlyRevenue[v.toInt()].monthName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)) : const Text(''))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: chartMax / 5, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.surfaceLight.withValues(alpha: 0.5), strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  barGroups: stats.monthlyRevenue.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(toY: e.value.revenue, color: AppColors.primary, width: 14, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                    BarChartRodData(toY: e.value.commission, color: AppColors.success, width: 14, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4))),
                  ])).toList(),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            _legendDot(AppColors.primary, 'Gelir'),
            const SizedBox(width: 16),
            _legendDot(AppColors.success, 'Komisyon'),
          ]),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(FinanceStats stats) {
    final total = stats.foodRevenue + stats.storeRevenue + stats.taxiRevenue + stats.rentalRevenue;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sektör Dağılımı', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Gelir kaynağına göre', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          if (total == 0)
            const SizedBox(height: 250, child: Center(child: Text('Henüz veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            SizedBox(
              height: 250,
              child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 45,
                sections: [
                  if (stats.foodRevenue > 0) PieChartSectionData(value: stats.foodRevenue, title: '${(stats.foodRevenue / total * 100).round()}%', color: AppColors.primary, radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (stats.storeRevenue > 0) PieChartSectionData(value: stats.storeRevenue, title: '${(stats.storeRevenue / total * 100).round()}%', color: AppColors.success, radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (stats.taxiRevenue > 0) PieChartSectionData(value: stats.taxiRevenue, title: '${(stats.taxiRevenue / total * 100).round()}%', color: AppColors.warning, radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (stats.rentalRevenue > 0) PieChartSectionData(value: stats.rentalRevenue, title: '${(stats.rentalRevenue / total * 100).round()}%', color: AppColors.info, radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              )),
            ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 8, children: [
            _legendDot(AppColors.primary, 'Yemek'),
            _legendDot(AppColors.success, 'Market'),
            _legendDot(AppColors.warning, 'Taksi'),
            _legendDot(AppColors.info, 'Kiralama'),
          ]),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('Faturalar', Icons.receipt_long, AppRoutes.financeInvoices),
      _QuickAction('Toplu Fatura', Icons.playlist_add_check, AppRoutes.financeBatchInvoice),
      _QuickAction('Gelir/Gider', Icons.swap_horiz, AppRoutes.financeIncomeExpense),
      _QuickAction('Vergi Raporu', Icons.calculate, AppRoutes.financeTax),
      _QuickAction('Bilanço', Icons.account_balance, AppRoutes.financeBalanceSheet),
      _QuickAction('Kar/Zarar', Icons.show_chart, AppRoutes.financeProfitLoss),
      _QuickAction('Komisyon', Icons.percent, AppRoutes.financeCommission),
      _QuickAction('Ödeme Takip', Icons.payment, AppRoutes.financePaymentTracking),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hızlı Erişim', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: actions.map((a) => InkWell(
              onTap: () => context.go(a.route),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 140,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Column(
                  children: [
                    Icon(a.icon, color: AppColors.primary, size: 28),
                    const SizedBox(height: 8),
                    Text(a.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]);
  }

  Widget _buildLoadingCards(int count) {
    return Row(children: List.generate(count, (i) => Expanded(
      child: Container(
        height: 120,
        margin: EdgeInsets.only(right: i < count - 1 ? 16 : 0),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator()),
      ),
    )));
  }

  Widget _buildLoadingCard(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String route;
  const _QuickAction(this.label, this.icon, this.route);
}
