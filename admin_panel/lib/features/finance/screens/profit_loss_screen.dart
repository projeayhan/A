import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/accounting_service.dart';

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final plAsync = ref.watch(profitLossProvider(BalanceSheetParams(_selectedMonth, _selectedYear)));

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
                    Text('Kar / Zarar', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Sektör bazlı gelir-gider ve net kar analizi', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
                Row(children: [
                  _buildMonthYearSelector(),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf, size: 18), label: const Text('PDF')),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 18), label: const Text('Excel')),
                ]),
              ],
            ),
            const SizedBox(height: 32),

            plAsync.when(
              data: (pl) => _buildContent(pl),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return Row(children: [
      DropdownButton<int>(
        value: _selectedMonth,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary),
        items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat.MMMM('tr').format(DateTime(2024, i + 1))))),
        onChanged: (v) => setState(() => _selectedMonth = v!),
      ),
      const SizedBox(width: 8),
      DropdownButton<int>(
        value: _selectedYear,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary),
        items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - i, child: Text('${DateTime.now().year - i}'))),
        onChanged: (v) => setState(() => _selectedYear = v!),
      ),
    ]);
  }

  Widget _buildContent(ProfitLossData pl) {
    return Column(
      children: [
        // Summary Cards
        Row(children: [
          _buildCard('Toplam Gelir', pl.totalRevenue, Icons.trending_up, AppColors.success),
          const SizedBox(width: 16),
          _buildCard('Toplam Gider', pl.totalExpenses, Icons.trending_down, AppColors.error),
          const SizedBox(width: 16),
          _buildCard('Net Kar', pl.netProfit, Icons.savings, pl.netProfit >= 0 ? AppColors.success : AppColors.error),
        ]),
        const SizedBox(height: 32),

        // Sector Revenues & Expense Categories
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSectorRevenueTable(pl)),
            const SizedBox(width: 24),
            Expanded(child: _buildExpenseCategoryTable(pl)),
          ],
        ),
        const SizedBox(height: 32),

        // Trend Chart
        _buildTrendChart(pl),
      ],
    );
  }

  Widget _buildCard(String title, double value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            Text(_currencyFormat.format(value), style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorRevenueTable(ProfitLossData pl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sektör Bazlı Gelir', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (pl.sectorRevenues.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            DataTable(
              columns: const [
                DataColumn(label: Text('SEKTÖR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('GELİR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('KOMİSYON', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
              ],
              rows: pl.sectorRevenues.map((s) => DataRow(cells: [
                DataCell(Text(_sectorLabel(s.sector), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                DataCell(Text(_currencyFormat.format(s.revenue), style: const TextStyle(color: AppColors.success, fontSize: 13))),
                DataCell(Text(_currencyFormat.format(s.commission), style: const TextStyle(color: AppColors.primary, fontSize: 13))),
              ])).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoryTable(ProfitLossData pl) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori Bazlı Gider', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (pl.expenseCategories.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Veri yok', style: TextStyle(color: AppColors.textMuted))))
          else
            DataTable(
              columns: const [
                DataColumn(label: Text('KATEGORİ', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('TUTAR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
              ],
              rows: pl.expenseCategories.map((e) => DataRow(cells: [
                DataCell(Text(e.category, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                DataCell(Text(_currencyFormat.format(e.amount), style: const TextStyle(color: AppColors.error, fontSize: 13))),
              ])).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(ProfitLossData pl) {
    if (pl.monthlyProfits.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
        child: const SizedBox(height: 300, child: Center(child: Text('Trend verisi yok', style: TextStyle(color: AppColors.textMuted)))),
      );
    }

    final maxVal = pl.monthlyProfits.fold(0.0, (m, e) {
      final v = [e.revenue, e.expenses, e.profit.abs()].reduce((a, b) => a > b ? a : b);
      return v > m ? v : m;
    });
    final chartMax = maxVal > 0 ? (maxVal * 1.2).ceilToDouble() : 1000.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kar/Zarar Trendi', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: LineChart(LineChartData(
              maxY: chartMax,
              minY: -chartMax * 0.3,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 55, getTitlesWidget: (v, _) => Text('${(v / 1000).toStringAsFixed(0)}K', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => v.toInt() < pl.monthlyProfits.length ? Text(pl.monthlyProfits[v.toInt()].month, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)) : const Text(''))),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.surfaceLight.withValues(alpha: 0.5), strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(spots: pl.monthlyProfits.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList(), color: AppColors.success, dotData: const FlDotData(show: false), barWidth: 2),
                LineChartBarData(spots: pl.monthlyProfits.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expenses)).toList(), color: AppColors.error, dotData: const FlDotData(show: false), barWidth: 2),
                LineChartBarData(spots: pl.monthlyProfits.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.profit)).toList(), color: AppColors.primary, dotData: const FlDotData(show: false), barWidth: 3),
              ],
            )),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _legendDot(AppColors.success, 'Gelir'),
            const SizedBox(width: 16),
            _legendDot(AppColors.error, 'Gider'),
            const SizedBox(width: 16),
            _legendDot(AppColors.primary, 'Net Kar'),
          ]),
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

  String _sectorLabel(String s) {
    switch (s) {
      case 'food': return 'Yemek';
      case 'store': return 'Market/Mağaza';
      case 'taxi': return 'Taksi';
      case 'rental': return 'Kiralama';
      default: return s;
    }
  }
}
