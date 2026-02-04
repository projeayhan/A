import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/models/merchant_models.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  String _selectedPeriod = 'Bu Ay';

  @override
  Widget build(BuildContext context) {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final financeStats = merchant != null
        ? ref.watch(financeStatsProvider(FinanceQuery(
            merchantId: merchant.id,
            period: _selectedPeriod,
            merchantType: merchant.type,
          )))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  isDense: true,
                  items:
                      ['Bu Hafta', 'Bu Ay', 'Son 3 Ay', 'Bu Yil']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedPeriod = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Loading or Error State
          if (financeStats == null || financeStats.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (financeStats.hasError)
            Center(
              child: Text(
                'Veri yuklenirken hata olustu',
                style: TextStyle(color: AppColors.error),
              ),
            )
          else ...[
            // Summary Cards
            _buildSummaryCards(financeStats.value!),
            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Revenue Chart
                Expanded(
                  flex: 2,
                  child: _buildRevenueChart(context, financeStats.value!),
                ),
                const SizedBox(width: 24),
                // Payment Breakdown
                Expanded(
                  child: _buildPaymentBreakdown(context, financeStats.value!),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Transactions Table
            _buildTransactionsTable(context, financeStats.value!),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCards(FinanceStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Toplam Gelir',
            '${stats.totalRevenue.toStringAsFixed(2)} TL',
            '+${stats.completedOrders} siparis',
            Icons.trending_up,
            AppColors.success,
            true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Komisyon Kesintisi',
            '${stats.commission.toStringAsFixed(2)} TL',
            '%${stats.commissionRate.toStringAsFixed(0)}',
            Icons.account_balance,
            AppColors.warning,
            false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Net Kazanc',
            '${stats.netRevenue.toStringAsFixed(2)} TL',
            stats.totalRevenue > 0
                ? '+${((stats.netRevenue / stats.totalRevenue) * 100).toStringAsFixed(1)}%'
                : '0%',
            Icons.account_balance_wallet,
            AppColors.primary,
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String change,
    IconData icon,
    Color color,
    bool showPercentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (showPercentage)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        change.startsWith('+')
                            ? AppColors.success.withAlpha(30)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change,
                    style: TextStyle(
                      color:
                          change.startsWith('+')
                              ? AppColors.success
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Text(
                  change,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(BuildContext context, FinanceStats stats) {
    // Gunluk verileri bar chart icin hazirla
    final sortedDays = stats.dailyRevenue.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    List<BarChartGroupData> barGroups = [];
    double maxY = 1000;

    for (int i = 0; i < sortedDays.length && i < 7; i++) {
      final day = sortedDays[i];
      final revenue = stats.dailyRevenue[day] ?? 0;
      final netRevenue = stats.dailyNetRevenue[day] ?? 0;

      if (revenue > maxY) maxY = revenue;

      barGroups.add(_buildBarGroup(i, revenue, netRevenue));
    }

    // Veri yoksa bos grafik
    if (barGroups.isEmpty) {
      barGroups = List.generate(7, (i) => _buildBarGroup(i, 0, 0));
    }

    maxY = ((maxY / 1000).ceil() * 1000).toDouble();
    if (maxY < 1000) maxY = 1000;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gelir Gecmisi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget:
                          (value, meta) => Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(0)}K'
                                : value.toInt().toString(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < sortedDays.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              sortedDays[value.toInt()],
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine:
                      (value) =>
                          FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppColors.primary, label: 'Gelir'),
              const SizedBox(width: 24),
              _LegendItem(color: AppColors.success, label: 'Net Kazanc'),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double revenue, double net) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: revenue,
          color: AppColors.primary,
          width: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
        BarChartRodData(
          toY: net,
          color: AppColors.success,
          width: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildPaymentBreakdown(BuildContext context, FinanceStats stats) {
    final hasData = stats.totalRevenue > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Odeme Yontemleri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          if (!hasData)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Henuz veri yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    if (stats.cardPercentage > 0)
                      PieChartSectionData(
                        value: stats.cardPercentage,
                        color: AppColors.primary,
                        title: '${stats.cardPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 40,
                      ),
                    if (stats.cashPercentage > 0)
                      PieChartSectionData(
                        value: stats.cashPercentage,
                        color: AppColors.success,
                        title: '${stats.cashPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 40,
                      ),
                    if (stats.transferPercentage > 0)
                      PieChartSectionData(
                        value: stats.transferPercentage,
                        color: AppColors.warning,
                        title: '${stats.transferPercentage.round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 40,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _PaymentMethodItem(
              icon: Icons.credit_card,
              color: AppColors.primary,
              label: 'Kredi Karti',
              amount: '${stats.cardRevenue.toStringAsFixed(2)} TL',
            ),
            const SizedBox(height: 12),
            _PaymentMethodItem(
              icon: Icons.money,
              color: AppColors.success,
              label: 'Nakit',
              amount: '${stats.cashRevenue.toStringAsFixed(2)} TL',
            ),
            const SizedBox(height: 12),
            _PaymentMethodItem(
              icon: Icons.account_balance,
              color: AppColors.warning,
              label: 'Havale/EFT',
              amount: '${stats.transferRevenue.toStringAsFixed(2)} TL',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(BuildContext context, FinanceStats stats) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'tr');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son Islemler',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Excel Indir'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (stats.transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Henuz islem yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  children: [
                    _TableHeader('Islem'),
                    _TableHeader('Tarih'),
                    _TableHeader('Tutar'),
                    _TableHeader('Durum'),
                    _TableHeader('Islem No'),
                  ],
                ),
                ...stats.transactions.map((transaction) => _buildTransactionRow(
                  transaction.description,
                  dateFormat.format(transaction.date),
                  '${transaction.isIncome ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} TL',
                  transaction.status,
                  '#${transaction.id}',
                  transaction.isIncome,
                )),
              ],
            ),
          if (stats.transactions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('Tum Islemleri Gor'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TableRow _buildTransactionRow(
    String description,
    String date,
    String amount,
    String status,
    String transactionId,
    bool isIncome,
  ) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border.withAlpha(100)),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isIncome
                          ? AppColors.success.withAlpha(30)
                          : AppColors.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: isIncome ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Text(description),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(date, style: TextStyle(color: AppColors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isIncome ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  status == 'Iptal'
                      ? AppColors.warning.withAlpha(30)
                      : AppColors.success.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: status == 'Iptal' ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            transactionId,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PaymentMethodItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String amount;

  const _PaymentMethodItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
