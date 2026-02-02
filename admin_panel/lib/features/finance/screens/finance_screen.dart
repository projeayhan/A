import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Row(
              children: [
                _buildFinanceCard(
                  'Toplam Gelir',
                  '₺847,250',
                  '+12.5%',
                  Icons.trending_up,
                  AppColors.success,
                  true,
                ),
                const SizedBox(width: 24),
                _buildFinanceCard(
                  'Komisyon Geliri',
                  '₺127,087',
                  '+8.2%',
                  Icons.account_balance,
                  AppColors.primary,
                  true,
                ),
                const SizedBox(width: 24),
                _buildFinanceCard(
                  'Partner Ödemeleri',
                  '₺456,890',
                  '+15.3%',
                  Icons.payments,
                  AppColors.warning,
                  true,
                ),
                const SizedBox(width: 24),
                _buildFinanceCard(
                  'Bekleyen Ödeme',
                  '₺23,450',
                  '-5.1%',
                  Icons.pending_actions,
                  AppColors.info,
                  false,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Revenue Chart
                Expanded(
                  flex: 2,
                  child: _buildChartCard(
                    'Gelir Grafiği',
                    'Aylık gelir trendi',
                    _buildRevenueChart(),
                  ),
                ),
                const SizedBox(width: 24),
                // Revenue Distribution
                Expanded(
                  child: _buildChartCard(
                    'Gelir Dağılımı',
                    'Kaynağa göre',
                    _buildPieChart(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Transactions Table
            _buildTransactionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Text('Bu Ay', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildFinanceCard(
    String title,
    String value,
    String trend,
    IconData icon,
    Color color,
    bool trendUp,
  ) {
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
                        trend,
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

  Widget _buildRevenueChart() {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 150000,
          barTouchData: BarTouchData(enabled: true),
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
                  final months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz'];
                  if (value.toInt() < months.length) {
                    return Text(
                      months[value.toInt()],
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
            horizontalInterval: 30000,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            _makeBarGroup(0, 85000, 12000),
            _makeBarGroup(1, 95000, 15000),
            _makeBarGroup(2, 78000, 11000),
            _makeBarGroup(3, 110000, 18000),
            _makeBarGroup(4, 125000, 20000),
            _makeBarGroup(5, 140000, 22000),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: AppColors.primary,
          width: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
        BarChartRodData(
          toY: y2,
          color: AppColors.success,
          width: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
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
                  PieChartSectionData(
                    value: 45,
                    title: '45%',
                    color: AppColors.primary,
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: 30,
                    title: '30%',
                    color: AppColors.success,
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: 15,
                    title: '15%',
                    color: AppColors.warning,
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: 10,
                    title: '10%',
                    color: AppColors.info,
                    radius: 50,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Yemek', AppColors.primary),
              _buildLegendItem('Market', AppColors.success),
              _buildLegendItem('Taksi', AppColors.warning),
              _buildLegendItem('Diğer', AppColors.info),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildTransactionsCard() {
    final transactions = [
      {'id': 'TRX-001', 'type': 'income', 'desc': 'Sipariş Komisyonu', 'amount': '₺125.50', 'date': '10 Oca 2026'},
      {'id': 'TRX-002', 'type': 'expense', 'desc': 'Partner Ödemesi', 'amount': '₺850.00', 'date': '10 Oca 2026'},
      {'id': 'TRX-003', 'type': 'income', 'desc': 'Sipariş Komisyonu', 'amount': '₺98.75', 'date': '09 Oca 2026'},
      {'id': 'TRX-004', 'type': 'income', 'desc': 'Premium Üyelik', 'amount': '₺299.00', 'date': '09 Oca 2026'},
      {'id': 'TRX-005', 'type': 'expense', 'desc': 'İade', 'amount': '₺45.00', 'date': '08 Oca 2026'},
    ];

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
                    'Son 5 finansal işlem',
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
          ...transactions.map((t) => _buildTransactionRow(t)),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(Map<String, String> transaction) {
    final isIncome = transaction['type'] == 'income';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              transaction['id']!,
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
                Text(transaction['desc']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: Text(transaction['date']!, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              '${isIncome ? '+' : '-'}${transaction['amount']}',
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
