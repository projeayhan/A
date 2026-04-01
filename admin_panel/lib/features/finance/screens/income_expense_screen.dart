import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';
import '../services/accounting_service.dart';
import '../../dashboard/widgets/chart_card.dart';
import '../../invoices/screens/web_download_helper.dart'
    if (dart.library.io) '../../invoices/screens/io_download_helper.dart';

class IncomeExpenseScreen extends ConsumerStatefulWidget {
  const IncomeExpenseScreen({super.key});

  @override
  ConsumerState<IncomeExpenseScreen> createState() =>
      _IncomeExpenseScreenState();
}

class _IncomeExpenseScreenState extends ConsumerState<IncomeExpenseScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '\u20BA',
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');

  // State
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String? _filterType;
  String? _filterSource;
  String? _filterCategory;
  String? _filterPaymentStatus;
  String _searchQuery = '';
  String _aggregation = 'daily';
  int _currentPage = 0;
  int _pageSize = 25;
  String _sortColumn = 'created_at';
  bool _sortAscending = false;
  late TextEditingController _searchController;
  Timer? _searchDebounce;

  // Chart toggle
  String _distributionMode = 'expense'; // expense | income

  IncomeExpenseFilterParams get _filterParams => IncomeExpenseFilterParams(
    startDate: _startDate,
    endDate: _endDate,
    type: _filterType,
    source: _filterSource,
    category: _filterCategory,
    paymentStatus: _filterPaymentStatus,
    searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
    page: _currentPage,
    pageSize: _pageSize,
    sortColumn: _sortColumn,
    sortAscending: _sortAscending,
    aggregation: _aggregation,
  );

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(incomeExpenseSummaryProvider(_filterParams));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),

            // KPI Cards
            summaryAsync.when(
              data: (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKpiCards(summary),
                  const SizedBox(height: 24),
                  _buildChartsRow(summary),
                ],
              ),
              loading: () => Column(
                children: [
                  _buildLoadingCards(5),
                  const SizedBox(height: 24),
                  _buildLoadingRow(),
                ],
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Text(
                    'Hata: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Filters + Table
            _buildFiltersSection(),
            const SizedBox(height: 16),
            _buildDataTable(),
          ],
        ),
      ),
    );
  }

  // --- HEADER ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gelir / Gider',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tum finansal hareketler',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showAddEntryDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Manuel Giris'),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              onSelected: (format) => _exportData(format),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'excel', child: Text('Excel (.xlsx)')),
                PopupMenuItem(value: 'pdf', child: Text('PDF')),
                PopupMenuItem(value: 'csv', child: Text('CSV')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.download,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Disa Aktar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- KPI CARDS ---

  Widget _buildKpiCards(IncomeExpenseSummary summary) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildKpiCard(
          title: 'Toplam Gelir',
          value: _currencyFormat.format(summary.totalIncome),
          icon: Icons.trending_up,
          color: AppColors.success,
          trend: summary.incomeTrend,
        ),
        _buildKpiCard(
          title: 'Toplam Gider',
          value: _currencyFormat.format(summary.totalExpense),
          icon: Icons.trending_down,
          color: AppColors.error,
          trend: summary.expenseTrend,
        ),
        _buildKpiCard(
          title: 'Net Bakiye',
          value: _currencyFormat.format(summary.netBalance),
          icon: Icons.account_balance_wallet,
          color: summary.netBalance >= 0 ? AppColors.success : AppColors.error,
        ),
        _buildKpiCard(
          title: 'KDV Toplam',
          value: _currencyFormat.format(summary.totalKdv),
          icon: Icons.receipt_long,
          color: AppColors.warning,
        ),
        _buildKpiCard(
          title: 'Bekleyen Odemeler',
          value: _currencyFormat.format(summary.pendingAmount),
          icon: Icons.pending_actions,
          color: AppColors.info,
          subtitle: '${summary.pendingCount} adet',
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double? trend,
    String? subtitle,
  }) {
    final hasTrend = trend != null && trend != 0;
    final trendUp = (trend ?? 0) >= 0;

    return SizedBox(
      width: 240,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                            color: trendUp
                                ? AppColors.success
                                : AppColors.error,
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- CHARTS ROW ---

  Widget _buildChartsRow(IncomeExpenseSummary summary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar Chart — Income vs Expense Trend
        Expanded(flex: 2, child: _buildBarChart(summary)),
        const SizedBox(width: 24),
        // Pie Chart — Distribution
        Expanded(flex: 1, child: _buildPieChart(summary)),
      ],
    );
  }

  Widget _buildBarChart(IncomeExpenseSummary summary) {
    final ts = summary.timeSeries;
    final maxVal = ts.isNotEmpty
        ? ts
              .map((p) => p.income > p.expense ? p.income : p.expense)
              .reduce((a, b) => a > b ? a : b)
        : 0.0;
    final chartMax = maxVal > 0 ? (maxVal * 1.2).ceilToDouble() : 1000.0;

    return ChartCard(
      title: 'Gelir vs Gider Trendi',
      subtitle:
          '${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate)}',
      actions: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'daily', label: Text('Gunluk')),
            ButtonSegment(value: 'weekly', label: Text('Haftalik')),
            ButtonSegment(value: 'monthly', label: Text('Aylik')),
          ],
          selected: {_aggregation},
          onSelectionChanged: (val) => setState(() => _aggregation = val.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 12)),
          ),
        ),
      ],
      chart: ts.isEmpty
          ? const SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  'Henuz veri yok',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartMax,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final label = rodIndex == 0 ? 'Gelir' : 'Gider';
                            return BarTooltipItem(
                              '$label\n${_currencyFormat.format(rod.toY)}',
                              const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 55,
                            getTitlesWidget: (v, _) => Text(
                              v >= 1000000
                                  ? '${(v / 1000000).toStringAsFixed(1)}M'
                                  : '${(v / 1000).toInt()}K',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              if (idx < 0 || idx >= ts.length) {
                                return const Text('');
                              }
                              final d = ts[idx].date;
                              String label;
                              switch (_aggregation) {
                                case 'weekly':
                                  label = 'Hft ${d.day}/${d.month}';
                                  break;
                                case 'monthly':
                                  label = DateFormat('MMM', 'tr').format(d);
                                  break;
                                default:
                                  label = '${d.day}/${d.month}';
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              );
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
                        horizontalInterval: chartMax / 5,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: AppColors.surfaceLight.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: ts.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.income,
                              color: AppColors.success,
                              width: 12,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            BarChartRodData(
                              toY: e.value.expense,
                              color: AppColors.error,
                              width: 12,
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
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legendDot(AppColors.success, 'Gelir'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.error, 'Gider'),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildPieChart(IncomeExpenseSummary summary) {
    final isExpenseMode = _distributionMode == 'expense';
    final data = isExpenseMode
        ? summary.categoryBreakdown
              .map((e) => _PieSlice(e.category, e.total))
              .toList()
        : summary.sourceBreakdown
              .map((e) => _PieSlice(e.sourceType, e.total))
              .toList();
    final total = data.fold<double>(0, (s, e) => s + e.value);

    return ChartCard(
      title: 'Dagilim',
      subtitle: isExpenseMode ? 'Gider kategorileri' : 'Gelir kaynaklari',
      actions: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'expense', label: Text('Gider')),
            ButtonSegment(value: 'income', label: Text('Gelir')),
          ],
          selected: {_distributionMode},
          onSelectionChanged: (val) =>
              setState(() => _distributionMode = val.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 12)),
          ),
        ),
      ],
      chart: data.isEmpty || total == 0
          ? const SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  'Henuz veri yok',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: data.asMap().entries.map((e) {
                        final color = AppColors
                            .chartColors[e.key % AppColors.chartColors.length];
                        final pct = (e.value.value / total * 100).round();
                        return PieChartSectionData(
                          value: e.value.value,
                          title: '$pct%',
                          color: color,
                          radius: 45,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: data.asMap().entries.map((e) {
                    final color = AppColors
                        .chartColors[e.key % AppColors.chartColors.length];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${e.value.label} (${_currencyFormat.format(e.value.value)})',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  // --- FILTERS SECTION ---

  static const _sourceMap = {
    'food': ('Yemek', Icons.restaurant),
    'market': ('Market', Icons.shopping_cart),
    'store': ('Magaza', Icons.store),
    'taxi': ('Taksi', Icons.local_taxi),
    'rental': ('Kiralama', Icons.car_rental),
    'car_sales': ('Arac Satis', Icons.directions_car),
    'real_estate': ('Emlak', Icons.home),
    'jobs': ('Is Ilanlari', Icons.work),
    'promotion': ('Öne Çıkarma', Icons.star),
    'manual': ('Manuel', Icons.edit),
  };

  static const _presetLabels = [
    'Bugun',
    'Bu Hafta',
    'Bu Ay',
    'Son 3 Ay',
    'Bu Yil',
  ];

  int get _activeFilterCount {
    int count = 0;
    if (_filterType != null) count++;
    if (_filterSource != null) count++;
    if (_filterCategory != null) count++;
    if (_filterPaymentStatus != null) count++;
    if (_searchQuery.isNotEmpty) count++;
    return count;
  }

  void _applyPreset(int index) {
    final now = DateTime.now();
    setState(() {
      switch (index) {
        case 0: // Bugun
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
        case 1: // Bu Hafta
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _startDate = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
          );
          _endDate = now;
        case 2: // Bu Ay
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
        case 3: // Son 3 Ay
          _startDate = DateTime(now.year, now.month - 2, 1);
          _endDate = now;
        case 4: // Bu Yil
          _startDate = DateTime(now.year, 1, 1);
          _endDate = now;
      }
      _currentPage = 0;
    });
  }

  void _clearAllFilters() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
      _filterType = null;
      _filterSource = null;
      _filterCategory = null;
      _filterPaymentStatus = null;
      _searchQuery = '';
      _searchController.clear();
      _currentPage = 0;
    });
  }

  Widget _buildFiltersSection() {
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
          // Row 1 -- Tarih
          Row(
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                      _currentPage = 0;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _dateFormat.format(_startDate),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  ' -- ',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _endDate = picked;
                      _currentPage = 0;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _dateFormat.format(_endDate),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: List.generate(_presetLabels.length, (i) {
                    return ActionChip(
                      label: Text(
                        _presetLabels[i],
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _applyPreset(i),
                      visualDensity: VisualDensity.compact,
                    );
                  }),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2 -- Tip + Kaynak
          Row(
            children: [
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Tumu')),
                  ButtonSegment(value: 'income', label: Text('Gelir')),
                  ButtonSegment(value: 'expense', label: Text('Gider')),
                ],
                selected: {_filterType},
                onSelectionChanged: (val) => setState(() {
                  _filterType = val.first;
                  _currentPage = 0;
                }),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _sourceMap.entries.map((e) {
                    final isSelected = _filterSource == e.key;
                    return FilterChip(
                      label: Text(
                        e.value.$1,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: isSelected,
                      onSelected: (sel) => setState(() {
                        _filterSource = sel ? e.key : null;
                        _currentPage = 0;
                      }),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3 -- Detay
          Row(
            children: [
              SizedBox(
                width: 200,
                child: TextFormField(
                  initialValue: _filterCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _filterCategory = v.isNotEmpty ? v : null;
                      _currentPage = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _filterPaymentStatus,
                  decoration: const InputDecoration(
                    labelText: 'Odeme Durumu',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tumu')),
                    DropdownMenuItem(value: 'pending', child: Text('Bekleyen')),
                    DropdownMenuItem(value: 'paid', child: Text('Odenmis')),
                    DropdownMenuItem(value: 'overdue', child: Text('Geciken')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Iptal')),
                  ],
                  onChanged: (v) => setState(() {
                    _filterPaymentStatus = v;
                    _currentPage = 0;
                  }),
                  isExpanded: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Aciklama, kategori veya not ara...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 500),
                      () {
                        if (mounted) {
                          setState(() {
                            _searchQuery = val;
                            _currentPage = 0;
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 4 -- Aktif filtre sayisi + temizle
          Row(
            children: [
              if (_activeFilterCount > 0) ...[
                Badge(
                  label: Text('$_activeFilterCount'),
                  child: const Icon(
                    Icons.filter_list,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_activeFilterCount filtre aktif',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Filtreleri Temizle'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DATA TABLE ---

  Widget _buildDataTable() {
    final entriesAsync = ref.watch(incomeExpenseEntriesProvider(_filterParams));
    final summaryAsync = ref.watch(incomeExpenseSummaryProvider(_filterParams));

    return entriesAsync.when(
      data: (entries) {
        final entryCount =
            summaryAsync.valueOrNull?.entryCount ?? entries.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: (entries.length.clamp(1, _pageSize) * 56.0 + 56)
                        .clamp(200, 800),
                    child: entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.receipt_long,
                                  size: 48,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Kayit bulunamadi',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_activeFilterCount > 0)
                                  TextButton(
                                    onPressed: _clearAllFilters,
                                    child: const Text('Filtreleri Temizle'),
                                  ),
                              ],
                            ),
                          )
                        : DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 16,
                            minWidth: 1400,
                            sortColumnIndex: _getSortColumnIndex(),
                            sortAscending: _sortAscending,
                            headingRowColor: WidgetStateProperty.all(
                              AppColors.surfaceLight.withValues(alpha: 0.3),
                            ),
                            headingTextStyle: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            dataTextStyle: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            columns: [
                              DataColumn2(
                                label: const Text('TARIH'),
                                fixedWidth: 110,
                                onSort: (_, asc) => _onSort('created_at', asc),
                              ),
                              DataColumn2(
                                label: const Text('TIP'),
                                fixedWidth: 80,
                                onSort: (_, asc) => _onSort('entry_type', asc),
                              ),
                              DataColumn2(
                                label: const Text('KATEGORI'),
                                fixedWidth: 140,
                                onSort: (_, asc) => _onSort('category', asc),
                              ),
                              const DataColumn2(
                                label: Text('ACIKLAMA'),
                                size: ColumnSize.L,
                              ),
                              DataColumn2(
                                label: const Text('KAYNAK'),
                                fixedWidth: 110,
                                onSort: (_, asc) => _onSort('source_type', asc),
                              ),
                              const DataColumn2(
                                label: Text('ODEME DURUMU'),
                                fixedWidth: 120,
                              ),
                              DataColumn2(
                                label: const Text('KDV'),
                                fixedWidth: 80,
                                numeric: true,
                                onSort: (_, asc) => _onSort('kdv_amount', asc),
                              ),
                              DataColumn2(
                                label: const Text('TUTAR'),
                                fixedWidth: 120,
                                numeric: true,
                                onSort: (_, asc) => _onSort('amount', asc),
                              ),
                              const DataColumn2(
                                label: Text(''),
                                fixedWidth: 50,
                              ),
                            ],
                            rows: entries.map((entry) {
                              final isIncome = entry.type == 'income';
                              final rowColor = isIncome
                                  ? AppColors.success.withValues(alpha: 0.03)
                                  : AppColors.error.withValues(alpha: 0.03);

                              return DataRow2(
                                color: WidgetStateProperty.all(rowColor),
                                onTap: () => _showEntryDetailDialog(entry),
                                cells: [
                                  DataCell(
                                    Text(
                                      DateFormat(
                                        'dd.MM.yyyy',
                                        'tr',
                                      ).format(entry.date),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(_buildTypeBadge(isIncome)),
                                  DataCell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.category,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (entry.subcategory != null &&
                                            entry.subcategory!.isNotEmpty)
                                          Text(
                                            entry.subcategory!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      entry.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  DataCell(_buildSourceLabel(entry.source)),
                                  DataCell(
                                    _buildPaymentStatusBadge(
                                      entry.paymentStatus,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      entry.kdvAmount != null
                                          ? _currencyFormat.format(
                                              entry.kdvAmount,
                                            )
                                          : '-',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${isIncome ? '+' : '-'}${_currencyFormat.format(entry.amount)}',
                                      style: TextStyle(
                                        color: isIncome
                                            ? AppColors.success
                                            : AppColors.error,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
                                      onSelected: (action) =>
                                          _handleEntryAction(action, entry),
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Duzenle'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Sil'),
                                        ),
                                        if (entry.paymentStatus == 'pending')
                                          const PopupMenuItem(
                                            value: 'mark_paid',
                                            child: Text('Odendi Isaretle'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                  ),

                  // Pagination
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Sayfa boyutu: ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _pageSize,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                            DropdownMenuItem(value: 100, child: Text('100')),
                          ],
                          onChanged: (v) => setState(() {
                            _pageSize = v!;
                            _currentPage = 0;
                          }),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          iconSize: 20,
                        ),
                        Text(
                          'Sayfa ${_currentPage + 1}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          onPressed: entries.length == _pageSize
                              ? () => setState(() => _currentPage++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          iconSize: 20,
                        ),
                        const Spacer(),
                        Text(
                          'Toplam $entryCount kayit',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Text(
            'Hata: $e',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  int _getSortColumnIndex() {
    const colMap = {
      'created_at': 0,
      'entry_type': 1,
      'category': 2,
      'source_type': 4,
      'kdv_amount': 6,
      'amount': 7,
    };
    return colMap[_sortColumn] ?? 0;
  }

  void _onSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _currentPage = 0;
    });
  }

  Widget _buildTypeBadge(bool isIncome) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isIncome ? AppColors.success : AppColors.error).withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isIncome ? 'Gelir' : 'Gider',
        style: TextStyle(
          color: isIncome ? AppColors.success : AppColors.error,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSourceLabel(String source) {
    final info = _sourceMap[source];
    if (info == null) return Text(source, style: const TextStyle(fontSize: 12));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(info.$2, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            info.$1,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusBadge(String? status) {
    Color color;
    String label;
    switch (status) {
      case 'paid':
        color = AppColors.success;
        label = 'Odenmis';
      case 'overdue':
        color = AppColors.error;
        label = 'Geciken';
      case 'cancelled':
        color = AppColors.textMuted;
        label = 'Iptal';
      case 'pending':
      default:
        color = AppColors.warning;
        label = 'Bekleyen';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- TABLE ACTIONS ---

  void _handleEntryAction(String action, FinanceEntry entry) async {
    switch (action) {
      case 'edit':
        _showAddEntryDialog(editEntry: entry);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Kayit Sil',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: const Text(
              'Bu kaydi silmek istediginizden emin misiniz?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await AccountingService.deleteFinanceEntry(entry.id);
          ref.invalidate(incomeExpenseSummaryProvider);
          ref.invalidate(incomeExpenseEntriesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kayit silindi'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      case 'mark_paid':
        await AccountingService.updateFinanceEntry(entry.id, {
          'payment_status': 'paid',
          'paid_at': DateTime.now().toIso8601String(),
        });
        ref.invalidate(incomeExpenseSummaryProvider);
        ref.invalidate(incomeExpenseEntriesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Odendi olarak isaretlendi'),
              backgroundColor: AppColors.success,
            ),
          );
        }
    }
  }

  // --- ENTRY DETAIL DIALOG ---

  void _showEntryDetailDialog(FinanceEntry entry) {
    final isIncome = entry.type == 'income';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            _buildTypeBadge(isIncome),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.description,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Tarih', _dateFormat.format(entry.date)),
                _detailRow(
                  'Kategori',
                  '${entry.category}${entry.subcategory != null ? ' / ${entry.subcategory}' : ''}',
                ),
                _detailRow(
                  'Kaynak',
                  _sourceMap[entry.source]?.$1 ?? entry.source,
                ),
                _detailRow('Tutar', _currencyFormat.format(entry.amount)),
                if (entry.kdvRate != null)
                  _detailRow(
                    'KDV Orani',
                    '%${entry.kdvRate!.toStringAsFixed(0)}',
                  ),
                if (entry.kdvAmount != null)
                  _detailRow(
                    'KDV Tutari',
                    _currencyFormat.format(entry.kdvAmount),
                  ),
                if (entry.totalAmount != null)
                  _detailRow(
                    'Toplam',
                    _currencyFormat.format(entry.totalAmount),
                  ),
                _detailRow(
                  'Odeme Durumu',
                  _paymentStatusLabel(entry.paymentStatus),
                ),
                if (entry.paymentMethod != null)
                  _detailRow('Odeme Yontemi', entry.paymentMethod!),
                if (entry.paidAt != null)
                  _detailRow(
                    'Odenme Tarihi',
                    _dateFormat.format(entry.paidAt!),
                  ),
                if (entry.notes != null && entry.notes!.isNotEmpty)
                  _detailRow('Notlar', entry.notes!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: ctx,
                builder: (c2) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text(
                    'Kaydi Sil',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  content: const Text(
                    'Bu kaydi silmek istediginizden emin misiniz?',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c2, false),
                      child: const Text('Iptal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(c2, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: const Text('Sil'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await AccountingService.deleteFinanceEntry(entry.id);
                ref.invalidate(incomeExpenseSummaryProvider);
                ref.invalidate(incomeExpenseEntriesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kayit silindi'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Sil',
              style: TextStyle(color: AppColors.error),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showAddEntryDialog(editEntry: entry);
            },
            child: const Text('Duzenle'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String _paymentStatusLabel(String? status) {
    switch (status) {
      case 'paid':
        return 'Odenmis';
      case 'overdue':
        return 'Geciken';
      case 'cancelled':
        return 'Iptal';
      case 'pending':
        return 'Bekleyen';
      default:
        return status ?? 'Bekleyen';
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- ADD / EDIT ENTRY DIALOG ---

  Future<void> _showAddEntryDialog({FinanceEntry? editEntry}) async {
    final formKey = GlobalKey<FormState>();
    final isEdit = editEntry != null;
    final typeCtrl = ValueNotifier<String>(editEntry?.type ?? 'income');
    final categoryCtrl = TextEditingController(
      text: editEntry?.category ?? '',
    );
    final descCtrl = TextEditingController(
      text: editEntry?.description ?? '',
    );
    final amountCtrl = TextEditingController(
      text: isEdit ? editEntry.amount.toStringAsFixed(2) : '',
    );
    final rawKdv = editEntry?.kdvRate ?? 0;
    final kdvRateCtrl = ValueNotifier<double>(
      rawKdv > 0 && rawKdv < 1 ? rawKdv * 100 : rawKdv,
    );
    final sourceCtrl = ValueNotifier<String>(editEntry?.source ?? 'manual');
    final paymentMethodCtrl = ValueNotifier<String?>(
      editEntry?.paymentMethod ?? 'cash',
    );
    final paymentStatusCtrl = ValueNotifier<String>(
      editEntry?.paymentStatus ?? 'pending',
    );
    final notesCtrl = TextEditingController(text: editEntry?.notes ?? '');
    final isSaving = ValueNotifier<bool>(false);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isEdit ? 'Kaydi Duzenle' : 'Manuel Giris',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 550,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type selector
                  ValueListenableBuilder<String>(
                    valueListenable: typeCtrl,
                    builder: (_, val, _) => SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'income', label: Text('Gelir')),
                        ButtonSegment(value: 'expense', label: Text('Gider')),
                      ],
                      selected: {val},
                      onSelectionChanged: (s) => typeCtrl.value = s.first,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  TextFormField(
                    controller: categoryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Kategori gerekli' : null,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Aciklama',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Aciklama bos olamaz' : null,
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tutar',
                      prefixIcon: Icon(Icons.currency_lira),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final a = double.tryParse(v ?? '');
                      if (a == null || a <= 0) return 'Gecerli bir tutar girin';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // KDV Rate
                  ValueListenableBuilder<double>(
                    valueListenable: kdvRateCtrl,
                    builder: (_, val, _) => DropdownButtonFormField<double>(
                      initialValue: val,
                      decoration: const InputDecoration(
                        labelText: 'KDV Orani',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('%0')),
                        DropdownMenuItem(value: 1, child: Text('%1')),
                        DropdownMenuItem(value: 10, child: Text('%10')),
                        DropdownMenuItem(value: 20, child: Text('%20')),
                      ],
                      onChanged: (v) => kdvRateCtrl.value = v ?? 0,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // KDV Preview
                  _buildKdvPreview(amountCtrl, kdvRateCtrl),
                  const SizedBox(height: 12),

                  // Source
                  ValueListenableBuilder<String>(
                    valueListenable: sourceCtrl,
                    builder: (_, val, _) => DropdownButtonFormField<String>(
                      initialValue: val,
                      decoration: const InputDecoration(
                        labelText: 'Kaynak',
                        border: OutlineInputBorder(),
                      ),
                      items: _sourceMap.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value.$1),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => sourceCtrl.value = v ?? 'manual',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment method
                  ValueListenableBuilder<String?>(
                    valueListenable: paymentMethodCtrl,
                    builder: (_, val, _) => DropdownButtonFormField<String>(
                      initialValue: val,
                      decoration: const InputDecoration(
                        labelText: 'Odeme Yontemi',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Nakit')),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Banka Transferi'),
                        ),
                        DropdownMenuItem(
                          value: 'credit_card',
                          child: Text('Kredi Karti'),
                        ),
                        DropdownMenuItem(
                          value: 'eft',
                          child: Text('Havale/EFT'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Diger')),
                      ],
                      onChanged: (v) => paymentMethodCtrl.value = v,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment status
                  ValueListenableBuilder<String>(
                    valueListenable: paymentStatusCtrl,
                    builder: (_, val, _) => DropdownButtonFormField<String>(
                      initialValue: val,
                      decoration: const InputDecoration(
                        labelText: 'Odeme Durumu',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Bekleyen'),
                        ),
                        DropdownMenuItem(
                          value: 'paid',
                          child: Text('Odenmis'),
                        ),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Text('Geciken'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('Iptal'),
                        ),
                      ],
                      onChanged: (v) =>
                          paymentStatusCtrl.value = v ?? 'pending',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notlar',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isSaving,
            builder: (_, saving, _) => ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      isSaving.value = true;
                      try {
                        final amount = double.parse(amountCtrl.text);
                        final kdvRate = kdvRateCtrl.value;
                        final kdvAmount = amount * kdvRate / 100;
                        final totalAmount = amount + kdvAmount;

                        if (isEdit) {
                          await AccountingService.updateFinanceEntry(
                            editEntry.id,
                            {
                              'entry_type': typeCtrl.value,
                              'category': categoryCtrl.text,
                              'description': descCtrl.text,
                              'amount': amount,
                              'kdv_rate': kdvRate,
                              'kdv_amount': kdvAmount,
                              'total_amount': totalAmount,
                              'source_type': sourceCtrl.value,
                              'payment_method': paymentMethodCtrl.value,
                              'payment_status': paymentStatusCtrl.value,
                              'notes': notesCtrl.text.isNotEmpty
                                  ? notesCtrl.text
                                  : null,
                            },
                          );
                        } else {
                          await AccountingService.createFinanceEntryFull(
                            type: typeCtrl.value,
                            category: categoryCtrl.text,
                            description: descCtrl.text,
                            amount: amount,
                            kdvRate: kdvRateCtrl.value,
                            source: sourceCtrl.value,
                            paymentMethod: paymentMethodCtrl.value,
                            paymentStatus: paymentStatusCtrl.value,
                            notes: notesCtrl.text.isNotEmpty
                                ? notesCtrl.text
                                : null,
                          );
                        }
                        ref.invalidate(incomeExpenseSummaryProvider);
                        ref.invalidate(incomeExpenseEntriesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? 'Kayit guncellendi'
                                    : 'Kayit eklendi',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        isSaving.value = false;
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Guncelle' : 'Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  // --- KDV PREVIEW ---

  Widget _buildKdvPreview(
    TextEditingController amountCtrl,
    ValueNotifier<double> kdvRateCtrl,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: kdvRateCtrl,
      builder: (_, rate, _) => ListenableBuilder(
        listenable: amountCtrl,
        builder: (_, _) {
          final amount = double.tryParse(amountCtrl.text) ?? 0;
          final kdv = amount * rate / 100;
          final total = amount + kdv;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'KDV: ${_currencyFormat.format(kdv)} | Toplam: ${_currencyFormat.format(total)}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- EXPORT ---

  Future<void> _exportData(String format) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${format.toUpperCase()} hazirlaniyor...'),
          backgroundColor: AppColors.info,
        ),
      );
      final supabase = ref.read(supabaseProvider);
      var query = supabase.from('finance_entries').select();

      // Apply all active filters
      query = query
          .gte('created_at', _startDate.toIso8601String())
          .lte('created_at', _endDate.toIso8601String());
      if (_filterType != null) query = query.eq('entry_type', _filterType!);
      if (_filterSource != null) {
        query = query.eq('source_type', _filterSource!);
      }
      if (_filterCategory != null) {
        query = query.eq('category', _filterCategory!);
      }
      if (_filterPaymentStatus != null) {
        query = query.eq('payment_status', _filterPaymentStatus!);
      }
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'description.ilike.%$_searchQuery%,category.ilike.%$_searchQuery%,notes.ilike.%$_searchQuery%',
        );
      }

      final result = await query
          .order(_sortColumn, ascending: _sortAscending)
          .limit(10000);
      final data = (result as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (format == 'excel') {
        final bytes = await InvoiceService.exportFinanceToExcel(data);
        downloadFile(
          Uint8List.fromList(bytes),
          'gelir_gider_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );
      } else if (format == 'csv') {
        final csvBuffer = StringBuffer();
        csvBuffer.write('\uFEFF'); // BOM for Excel Turkish compatibility
        // Filter summary
        final filters = <String>[];
        filters.add(
          'Tarih: ${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate)}',
        );
        if (_filterType != null) {
          filters.add('Tip: ${_filterType == 'income' ? 'Gelir' : 'Gider'}');
        }
        if (_filterSource != null) {
          filters.add(
            'Kaynak: ${_sourceMap[_filterSource]?.$1 ?? _filterSource}',
          );
        }
        if (_filterCategory != null) filters.add('Kategori: $_filterCategory');
        if (_filterPaymentStatus != null) {
          filters.add(
            'Odeme Durumu: ${_paymentStatusLabel(_filterPaymentStatus)}',
          );
        }
        csvBuffer.writeln('"# Filtreler: ${filters.join(" | ")}"');

        // Header
        csvBuffer.writeln(
          '"Tarih","Tip","Kategori","Alt Kategori","Aciklama","Kaynak","Odeme Durumu","Odeme Yontemi","KDV Orani","KDV Tutari","Tutar","Toplam","Notlar"',
        );

        double totalIncome = 0;
        double totalExpense = 0;
        for (final row in data) {
          final amount = (row['amount'] as num?)?.toDouble() ?? 0;
          final isIncome = row['entry_type'] == 'income';
          if (isIncome) {
            totalIncome += amount;
          } else {
            totalExpense += amount;
          }
          String esc(dynamic v) =>
              '"${(v?.toString() ?? '').replaceAll('"', '""')}"';
          final date = row['created_at'] != null
              ? DateFormat(
                  'dd.MM.yyyy',
                ).format(DateTime.parse(row['created_at']))
              : '';
          csvBuffer.writeln(
            '${esc(date)},${esc(isIncome ? 'Gelir' : 'Gider')},${esc(row['category'])},${esc(row['subcategory'])},${esc(row['description'])},${esc(_sourceMap[row['source_type']]?.$1 ?? row['source_type'])},${esc(_paymentStatusLabel(row['payment_status']))},${esc(row['payment_method'])},${esc(row['kdv_rate'] != null ? '%${row['kdv_rate']}' : '')},${esc(row['kdv_amount'])},${esc(amount)},${esc(row['total_amount'])},${esc(row['notes'])}',
          );
        }
        // Summary rows
        csvBuffer.writeln(
          ',,,,,,,,,,"Toplam Gelir","${totalIncome.toStringAsFixed(2)}",,',
        );
        csvBuffer.writeln(
          ',,,,,,,,,,"Toplam Gider","${totalExpense.toStringAsFixed(2)}",,',
        );
        csvBuffer.writeln(
          ',,,,,,,,,,"Net Bakiye","${(totalIncome - totalExpense).toStringAsFixed(2)}",,',
        );

        final csvStr = csvBuffer.toString();
        final bytes = Uint8List.fromList(utf8.encode(csvStr));
        final now = DateTime.now();
        downloadFile(
          bytes,
          'gelir_gider_${DateFormat('yyyyMMdd').format(now)}.csv',
        );
      } else if (format == 'pdf') {
        await _exportPdf(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${format.toUpperCase()} indirildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // --- PDF EXPORT ---

  Future<void> _exportPdf(List<Map<String, dynamic>> data) async {
    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final font = pw.Font.ttf(fontData);
    final company = await InvoiceService.getCompanyInfo();
    final now = DateTime.now();

    // Calculate totals
    double totalIncome = 0, totalExpense = 0, totalKdv = 0;
    int pendingCount = 0;
    for (final row in data) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final kdv = (row['kdv_amount'] as num?)?.toDouble() ?? 0;
      if (row['entry_type'] == 'income') {
        totalIncome += amount;
      } else {
        totalExpense += amount;
      }
      totalKdv += kdv;
      if (row['payment_status'] == 'pending') pendingCount++;
    }

    // Category breakdown
    final categoryTotals = <String, double>{};
    for (final row in data) {
      final cat = row['category'] as String? ?? 'Diger';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amount;
    }
    final grandTotal = totalIncome + totalExpense;

    final pdf = pw.Document();

    // Styles
    final headerStyle = pw.TextStyle(
      font: font,
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
    );
    final subHeaderStyle = pw.TextStyle(
      font: font,
      fontSize: 14,
      color: PdfColors.grey700,
    );
    final labelStyle = pw.TextStyle(
      font: font,
      fontSize: 10,
      color: PdfColors.grey600,
    );
    final valueStyle = pw.TextStyle(
      font: font,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final smallStyle = pw.TextStyle(font: font, fontSize: 9);
    final tableHeaderStyle = pw.TextStyle(
      font: font,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final tableCellStyle = pw.TextStyle(font: font, fontSize: 8);

    // Filter description
    final filters = <String>[];
    filters.add(
      'Tarih: ${_dateFormat.format(_startDate)} - ${_dateFormat.format(_endDate)}',
    );
    if (_filterType != null) {
      filters.add('Tip: ${_filterType == 'income' ? 'Gelir' : 'Gider'}');
    }
    if (_filterSource != null) {
      filters.add('Kaynak: ${_sourceMap[_filterSource]?.$1 ?? _filterSource}');
    }
    if (_filterCategory != null) filters.add('Kategori: $_filterCategory');
    if (_filterPaymentStatus != null) {
      filters.add('Durum: ${_paymentStatusLabel(_filterPaymentStatus)}');
    }

    // Limit detail rows to 500
    final detailRows = data.take(500).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(company['name'] ?? 'Sirket', style: headerStyle),
                    pw.SizedBox(height: 4),
                    pw.Text('Gelir / Gider Raporu', style: subHeaderStyle),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Olusturma: ${DateFormat('dd.MM.yyyy HH:mm').format(now)}',
                      style: labelStyle,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(filters.join(' | '), style: labelStyle),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Bu rapor otomatik olusturulmustur',
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
            pw.Text(
              'Sayfa ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
        build: (context) => [
          // Summary KPI Table
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfKpiItem(
                  'Toplam Gelir',
                  _currencyFormat.format(totalIncome),
                  labelStyle,
                  valueStyle,
                ),
                _pdfKpiItem(
                  'Toplam Gider',
                  _currencyFormat.format(totalExpense),
                  labelStyle,
                  valueStyle,
                ),
                _pdfKpiItem(
                  'Net Bakiye',
                  _currencyFormat.format(totalIncome - totalExpense),
                  labelStyle,
                  valueStyle,
                ),
                _pdfKpiItem(
                  'KDV Toplam',
                  _currencyFormat.format(totalKdv),
                  labelStyle,
                  valueStyle,
                ),
                _pdfKpiItem(
                  'Bekleyen',
                  '$pendingCount adet',
                  labelStyle,
                  valueStyle,
                ),
                _pdfKpiItem(
                  'Kayit Sayisi',
                  '${data.length}',
                  labelStyle,
                  valueStyle,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Category Breakdown
          if (categoryTotals.isNotEmpty) ...[
            pw.Text(
              'Kategori Dagilimi',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headerStyle: tableHeaderStyle,
              cellStyle: smallStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
              },
              headers: ['Kategori', 'Tutar', 'Oran'],
              data: categoryTotals.entries.map((e) {
                final pct = grandTotal > 0 ? (e.value / grandTotal * 100) : 0;
                return [
                  e.key,
                  _currencyFormat.format(e.value),
                  '%${pct.toStringAsFixed(1)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // Detail Table
          pw.Text(
            'Detay Listesi${data.length > 500 ? ' (ilk 500 kayit)' : ''}',
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: tableHeaderStyle,
            cellStyle: tableCellStyle,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Tarih
              1: const pw.FlexColumnWidth(0.8), // Tip
              2: const pw.FlexColumnWidth(1.5), // Kategori
              3: const pw.FlexColumnWidth(3), // Aciklama
              4: const pw.FlexColumnWidth(1.2), // Kaynak
              5: const pw.FlexColumnWidth(1.2), // Tutar
            },
            headers: [
              'Tarih',
              'Tip',
              'Kategori',
              'Aciklama',
              'Kaynak',
              'Tutar',
            ],
            data: detailRows.map((row) {
              final isIncome = row['entry_type'] == 'income';
              final date = row['created_at'] != null
                  ? DateFormat(
                      'dd.MM.yyyy',
                    ).format(DateTime.parse(row['created_at']))
                  : '';
              final amount = (row['amount'] as num?)?.toDouble() ?? 0;
              return [
                date,
                isIncome ? 'Gelir' : 'Gider',
                row['category'] ?? '',
                (row['description'] as String? ?? '').length > 60
                    ? '${(row['description'] as String).substring(0, 60)}...'
                    : row['description'] ?? '',
                _sourceMap[row['source_type']]?.$1 ??
                    (row['source_type'] ?? ''),
                '${isIncome ? '+' : '-'}${_currencyFormat.format(amount)}',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    downloadFile(
      Uint8List.fromList(pdfBytes),
      'gelir_gider_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf',
    );
  }

  pw.Widget _pdfKpiItem(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Column(
      children: [
        pw.Text(label, style: labelStyle),
        pw.SizedBox(height: 4),
        pw.Text(value, style: valueStyle),
      ],
    );
  }

  // --- HELPERS ---

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLoadingCards(int count) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(
        count,
        (_) => SizedBox(
          width: 240,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            height: 400,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _PieSlice {
  final String label;
  final double value;
  const _PieSlice(this.label, this.value);
}
