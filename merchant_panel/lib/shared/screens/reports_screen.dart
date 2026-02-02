import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/report_export_service.dart';

// Selected tab state provider
final selectedReportTabProvider = StateProvider<int>((ref) => 0);

// Date range provider
final reportDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, 1),
    end: now,
  );
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final selectedTab = ref.watch(selectedReportTabProvider);
    final dateRange = ref.watch(reportDateRangeProvider);

    // Provider'a tarih araligi parametresi gonder
    final reportsStats = merchant != null
        ? ref.watch(reportsStatsProvider(ReportsParams(
            merchantId: merchant.id,
            startDate: dateRange.start,
            endDate: dateRange.end,
          )))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Date Filter
          _buildHeader(context, ref, dateRange),
          const SizedBox(height: 24),

          // Report Type Tabs
          _buildReportTabs(context, ref, selectedTab),
          const SizedBox(height: 24),

          // Loading or Error State
          if (reportsStats == null || reportsStats.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (reportsStats.hasError)
            _buildErrorState(context, ref, reportsStats.error)
          else
            _buildTabContent(context, ref, selectedTab, reportsStats.value!),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, DateTimeRange dateRange) {
    final dateFormat = DateFormat('dd MMM yyyy', 'tr');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raporlar',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'İşletme performansınızı analiz edin',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        Row(
          children: [
            // Date Range Picker
            InkWell(
              onTap: () => _selectDateRange(context, ref, dateRange),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Refresh Button
            IconButton(
              onPressed: () {
                final merchant = ref.read(currentMerchantProvider).valueOrNull;
                final dateRange = ref.read(reportDateRangeProvider);
                if (merchant != null) {
                  ref.invalidate(reportsStatsProvider(ReportsParams(
                    merchantId: merchant.id,
                    startDate: dateRange.start,
                    endDate: dateRange.end,
                  )));
                }
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Yenile',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 12),
            // Export Button
            PopupMenuButton<String>(
              onSelected: (value) => _handleExport(context, ref, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pdf', child: Text('PDF olarak indir')),
                const PopupMenuItem(value: 'excel', child: Text('Excel olarak indir')),
                const PopupMenuItem(value: 'csv', child: Text('CSV olarak indir')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.download, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Dışa Aktar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref, DateTimeRange currentRange) async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: currentRange,
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      ref.read(reportDateRangeProvider.notifier).state = result;
    }
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref, String format) async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    final dateRange = ref.read(reportDateRangeProvider);

    if (merchant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Merchant bilgisi bulunamadı'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final reportsStats = ref.read(reportsStatsProvider(ReportsParams(
      merchantId: merchant.id,
      startDate: dateRange.start,
      endDate: dateRange.end,
    )));

    if (reportsStats.valueOrNull == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rapor verileri yüklenemedi'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final stats = reportsStats.value!;

    // Yukleniyor mesaji goster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${format.toUpperCase()} formatında rapor hazırlanıyor...'),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 1),
      ),
    );

    bool success = false;

    switch (format) {
      case 'pdf':
        success = await reportExportService.exportPdf(
          context: context,
          stats: stats,
          dateRange: dateRange,
          merchantName: merchant.businessName,
        );
        break;
      case 'excel':
        success = await reportExportService.exportExcel(
          context: context,
          stats: stats,
          dateRange: dateRange,
          merchantName: merchant.businessName,
        );
        break;
      case 'csv':
        success = await reportExportService.exportCsv(
          context: context,
          stats: stats,
          dateRange: dateRange,
          merchantName: merchant.businessName,
        );
        break;
    }

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} raporu başarıyla oluşturuldu'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} raporu oluşturulurken hata oluştu'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildReportTabs(BuildContext context, WidgetRef ref, int selectedTab) {
    final tabs = ['Genel Bakış', 'Satış Raporu', 'Ürün Analizi', 'Müşteri Analizi'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = index == selectedTab;

          return InkWell(
            onTap: () => ref.read(selectedReportTabProvider.notifier).state = index,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object? error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Veri yüklenirken hata oluştu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final merchant = ref.read(currentMerchantProvider).valueOrNull;
                final dateRange = ref.read(reportDateRangeProvider);
                if (merchant != null) {
                  ref.invalidate(reportsStatsProvider(ReportsParams(
                    merchantId: merchant.id,
                    startDate: dateRange.start,
                    endDate: dateRange.end,
                  )));
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, WidgetRef ref, int selectedTab, ReportsStats stats) {
    switch (selectedTab) {
      case 0:
        return _buildOverviewTab(context, stats);
      case 1:
        return _buildSalesReportTab(context, stats);
      case 2:
        return _buildProductAnalysisTab(context, stats);
      case 3:
        return _buildCustomerAnalysisTab(context, stats);
      default:
        return _buildOverviewTab(context, stats);
    }
  }

  // ===== GENEL BAKIŞ TAB =====
  Widget _buildOverviewTab(BuildContext context, ReportsStats stats) {
    return Column(
      children: [
        // Key Metrics
        _buildKeyMetrics(context, stats),
        const SizedBox(height: 24),

        // Charts Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildSalesTrendChart(context, stats),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTopProductsCard(context, stats),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Second Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildOrdersByHourChart(context, stats),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildCustomerStatsCard(context, stats),
            ),
          ],
        ),
      ],
    );
  }

  // ===== SATIŞ RAPORU TAB =====
  Widget _buildSalesReportTab(BuildContext context, ReportsStats stats) {
    // Degisim yuzdeleri
    final revenueChangeStr = stats.orderChangePercent >= 0
        ? '+${stats.orderChangePercent.toStringAsFixed(1)}%'
        : '${stats.orderChangePercent.toStringAsFixed(1)}%';

    return Column(
      children: [
        // Revenue Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildRevenueCard(
                context,
                'Toplam Gelir',
                '${NumberFormat('#,###', 'tr').format(stats.totalRevenue)} TL',
                Icons.account_balance_wallet,
                AppColors.success,
                revenueChangeStr,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRevenueCard(
                context,
                'Ortalama Sipariş',
                '${stats.averageOrderValue.toStringAsFixed(2)} TL',
                Icons.shopping_cart,
                AppColors.primary,
                revenueChangeStr,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRevenueCard(
                context,
                'Toplam Sipariş',
                stats.totalOrders.toString(),
                Icons.receipt_long,
                AppColors.info,
                revenueChangeStr,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRevenueCard(
                context,
                'İptal Edilen',
                '${stats.cancelledOrders} (${stats.cancellationRate.toStringAsFixed(1)}%)',
                Icons.cancel_outlined,
                AppColors.warning,
                stats.cancellationRate < 5 ? 'İyi' : 'Dikkat',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sales Chart
        _buildDetailedSalesChart(context, stats),
        const SizedBox(height: 24),

        // Daily Sales Table
        _buildDailySalesTable(context, stats),
      ],
    );
  }

  Widget _buildRevenueCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    final isPositive = change.startsWith('+') && !change.contains('-');

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.success : AppColors.error).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: isPositive ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      change,
                      style: TextStyle(
                        color: isPositive ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDetailedSalesChart(BuildContext context, ReportsStats stats) {
    final thisMonth = stats.weeklyOrderCounts;
    final lastMonth = stats.prevPeriodWeeklyOrderCounts;

    double maxY = 50;
    for (var v in thisMonth) {
      if (v > maxY) maxY = v.toDouble();
    }
    for (var v in lastMonth) {
      if (v > maxY) maxY = v.toDouble();
    }
    maxY = ((maxY / 50).ceil() * 50).toDouble();
    if (maxY < 50) maxY = 50;

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
              Text('Haftalık Satış Karşılaştırması', style: Theme.of(context).textTheme.titleLarge),
              Row(
                children: [
                  _LegendDot(color: AppColors.primary, label: 'Bu Ay'),
                  const SizedBox(width: 16),
                  _LegendDot(color: AppColors.textMuted, label: 'Geçen Ay'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()} sipariş',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final weeks = ['1. Hafta', '2. Hafta', '3. Hafta', '4. Hafta'];
                        if (value.toInt() < weeks.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(weeks[value.toInt()], style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(4, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: thisMonth[i].toDouble(),
                        color: AppColors.primary,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                      BarChartRodData(
                        toY: lastMonth[i].toDouble(),
                        color: AppColors.textMuted.withAlpha(100),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySalesTable(BuildContext context, ReportsStats stats) {
    final dateFormat = DateFormat('dd MMM yyyy', 'tr');

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
          Text('Günlük Satış Özeti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (stats.dailyStats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Seçilen tarih aralığında sipariş bulunamadı', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  children: [
                    _tableHeader('Tarih'),
                    _tableHeader('Sipariş'),
                    _tableHeader('Gelir'),
                    _tableHeader('Ort. Sepet'),
                  ],
                ),
                ...stats.dailyStats.map((daily) {
                  final date = DateTime.parse(daily.date);
                  return TableRow(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(50)))),
                    children: [
                      _tableCell(dateFormat.format(date)),
                      _tableCell(daily.orders.toString()),
                      _tableCell('${NumberFormat('#,###', 'tr').format(daily.revenue)} TL'),
                      _tableCell('${daily.averageOrderValue.toStringAsFixed(2)} TL'),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
    );
  }

  Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text),
    );
  }

  // ===== ÜRÜN ANALİZİ TAB =====
  Widget _buildProductAnalysisTab(BuildContext context, ReportsStats stats) {
    return Column(
      children: [
        // Product Performance Cards
        Row(
          children: [
            Expanded(
              child: _buildProductPerformanceCard(
                context,
                'En Çok Satan',
                stats.bestSellingProduct,
                '${stats.bestSellingQuantity} adet satıldı',
                Icons.emoji_events,
                AppColors.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildProductPerformanceCard(
                context,
                'Toplam Ürün Çeşidi',
                stats.topProducts.length.toString(),
                'Aktif menüde',
                Icons.restaurant_menu,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildProductPerformanceCard(
                context,
                'Ortalama Ürün Puanı',
                stats.averageRating.toStringAsFixed(1),
                'Müşteri değerlendirmesi',
                Icons.star,
                AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Product Charts
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildProductSalesChart(context, stats),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildProductRankingList(context, stats),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductPerformanceCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(subtitle, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSalesChart(BuildContext context, ReportsStats stats) {
    if (stats.topProducts.isEmpty) {
      return _buildEmptyState(context, 'Henüz ürün satışı yok');
    }

    final maxRevenue = stats.topProducts.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);

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
          Text('Ürün Bazlı Gelir Dağılımı', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRevenue * 1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final product = stats.topProducts[groupIndex];
                      return BarTooltipItem(
                        '${product.name}\n${product.revenue.toStringAsFixed(0)} TL',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()} TL',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < stats.topProducts.length) {
                          final name = stats.topProducts[value.toInt()].name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              name.length > 10 ? '${name.substring(0, 10)}...' : name,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: stats.topProducts.asMap().entries.map((entry) {
                  final colors = [AppColors.primary, AppColors.success, AppColors.info, AppColors.warning, AppColors.restaurant];
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.revenue,
                        color: colors[entry.key % colors.length],
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRankingList(BuildContext context, ReportsStats stats) {
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
          Text('Ürün Sıralaması', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (stats.topProducts.isEmpty)
            _buildEmptyStateSmall(context, 'Veri yok')
          else
            ...stats.topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final medalColors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index < 3 ? medalColors[index].withAlpha(30) : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: index < 3
                            ? Icon(Icons.emoji_events, size: 18, color: medalColors[index])
                            : Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${product.quantity} adet', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('${product.revenue.toStringAsFixed(0)} TL', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===== MÜŞTERİ ANALİZİ TAB =====
  Widget _buildCustomerAnalysisTab(BuildContext context, ReportsStats stats) {
    return Column(
      children: [
        // Customer Metrics
        Row(
          children: [
            Expanded(child: _buildCustomerMetricCard(context, 'Toplam Müşteri', stats.totalCustomers.toString(), Icons.people, AppColors.primary)),
            const SizedBox(width: 16),
            Expanded(child: _buildCustomerMetricCard(context, 'Yeni Müşteri', '${(stats.totalCustomers * 0.15).round()}', Icons.person_add, AppColors.success)),
            const SizedBox(width: 16),
            Expanded(child: _buildCustomerMetricCard(context, 'Tekrar Eden', '%${stats.repeatCustomerRate.toStringAsFixed(0)}', Icons.repeat, AppColors.info)),
            const SizedBox(width: 16),
            Expanded(child: _buildCustomerMetricCard(context, 'Ort. Sipariş', stats.avgOrdersPerCustomer.toStringAsFixed(1), Icons.shopping_bag, AppColors.warning)),
          ],
        ),
        const SizedBox(height: 24),

        // Customer Charts
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildCustomerSegmentChart(context, stats)),
            const SizedBox(width: 24),
            Expanded(child: _buildCustomerSatisfactionCard(context, stats)),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCustomerSegmentChart(BuildContext context, ReportsStats stats) {
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
          Text('Müşteri Segmentasyonu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: stats.repeatCustomerRate,
                    title: 'Sadık\n%${stats.repeatCustomerRate.toStringAsFixed(0)}',
                    color: AppColors.success,
                    radius: 80,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: 100 - stats.repeatCustomerRate,
                    title: 'Yeni\n%${(100 - stats.repeatCustomerRate).toStringAsFixed(0)}',
                    color: AppColors.primary,
                    radius: 80,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.success, label: 'Tekrar Eden Müşteri'),
              const SizedBox(width: 24),
              _LegendDot(color: AppColors.primary, label: 'Yeni Müşteri'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSatisfactionCard(BuildContext context, ReportsStats stats) {
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
          Text('Müşteri Memnuniyeti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: stats.averageRating / 5,
                        strokeWidth: 12,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          stats.averageRating >= 4 ? AppColors.success : (stats.averageRating >= 3 ? AppColors.warning : AppColors.error),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          stats.averageRating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (i) {
                            if (i < stats.averageRating.floor()) {
                              return const Icon(Icons.star, size: 16, color: AppColors.warning);
                            } else if (i < stats.averageRating) {
                              return const Icon(Icons.star_half, size: 16, color: AppColors.warning);
                            }
                            return Icon(Icons.star_border, size: 16, color: Colors.grey[400]);
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  stats.averageRating >= 4 ? 'Mükemmel!' : (stats.averageRating >= 3 ? 'İyi' : 'Geliştirilebilir'),
                  style: TextStyle(
                    color: stats.averageRating >= 4 ? AppColors.success : (stats.averageRating >= 3 ? AppColors.warning : AppColors.error),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSatisfactionItem('Kurye Hizmeti', 4.2, AppColors.info),
          const SizedBox(height: 12),
          _buildSatisfactionItem('Servis Kalitesi', 4.0, AppColors.success),
          const SizedBox(height: 12),
          _buildSatisfactionItem('Yemek Lezzeti', 3.8, AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildSatisfactionItem(String label, double rating, Color color) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(color: AppColors.textSecondary))),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rating / 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ===== ORTAK WIDGETLAR =====
  Widget _buildKeyMetrics(BuildContext context, ReportsStats stats) {
    final orderChange = stats.orderChangePercent;
    final orderChangeStr = orderChange >= 0 ? '+${orderChange.toStringAsFixed(0)}%' : '${orderChange.toStringAsFixed(0)}%';

    return Row(
      children: [
        Expanded(child: _buildMetricCard(context, 'Toplam Sipariş', stats.totalOrders.toString(), orderChangeStr, Icons.receipt_long, AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(context, 'Toplam Gelir', '${NumberFormat('#,###', 'tr').format(stats.totalRevenue)} TL', orderChangeStr, Icons.attach_money, AppColors.success)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(context, 'En Çok Satan', stats.bestSellingProduct, '${stats.bestSellingQuantity} adet', Icons.local_fire_department, AppColors.restaurant)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(context, 'İptal Oranı', '%${stats.cancellationRate.toStringAsFixed(1)}', '${stats.cancelledOrders} sipariş', Icons.cancel_outlined, AppColors.warning)),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, String change, IconData icon, Color color) {
    final isPositive = change.startsWith('+') || change.startsWith('-0');

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
                decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive ? AppColors.success.withAlpha(30) : AppColors.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(change, style: TextStyle(color: isPositive ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSalesTrendChart(BuildContext context, ReportsStats stats) {
    final thisMonth = stats.weeklyOrderCounts;
    final lastMonth = stats.prevPeriodWeeklyOrderCounts;

    double maxY = 50;
    for (var v in thisMonth) { if (v > maxY) maxY = v.toDouble(); }
    for (var v in lastMonth) { if (v > maxY) maxY = v.toDouble(); }
    maxY = ((maxY / 50).ceil() * 50).toDouble();
    if (maxY < 50) maxY = 50;

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
              Text('Satış Trendi', style: Theme.of(context).textTheme.titleLarge),
              Row(children: [_LegendDot(color: AppColors.primary, label: 'Bu Ay'), const SizedBox(width: 16), _LegendDot(color: AppColors.textMuted, label: 'Geçen Ay')]),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 5, getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) { final weeks = ['1. Hafta', '2. Hafta', '3. Hafta', '4. Hafta']; if (value.toInt() < weeks.length) { return Padding(padding: const EdgeInsets.only(top: 8), child: Text(weeks[value.toInt()], style: const TextStyle(color: AppColors.textMuted, fontSize: 11))); } return const SizedBox(); })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(spots: List.generate(4, (i) => FlSpot(i.toDouble(), thisMonth[i].toDouble())), isCurved: true, color: AppColors.primary, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: AppColors.primary, strokeWidth: 2, strokeColor: Colors.white)), belowBarData: BarAreaData(show: true, color: AppColors.primary.withAlpha(30))),
                  LineChartBarData(spots: List.generate(4, (i) => FlSpot(i.toDouble(), lastMonth[i].toDouble())), isCurved: true, color: AppColors.textMuted, barWidth: 2, dotData: const FlDotData(show: false), dashArray: [5, 5]),
                ],
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(BuildContext context, ReportsStats stats) {
    final products = stats.topProducts;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('En Çok Satanlar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (products.isEmpty)
            _buildEmptyStateSmall(context, 'Henüz veri yok')
          else
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: index < 3 ? [AppColors.warning, AppColors.textSecondary, AppColors.store][index].withAlpha(30) : AppColors.background, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: index < 3 ? [AppColors.warning, AppColors.textSecondary, AppColors.store][index] : AppColors.textMuted))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis), Text('${product.quantity} adet', style: TextStyle(color: AppColors.textMuted, fontSize: 12))])),
                    Text('${product.revenue.toStringAsFixed(0)} TL', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOrdersByHourChart(BuildContext context, ReportsStats stats) {
    final hourlyData = stats.hourlyDistribution;
    final peakHour = stats.peakHour;

    double maxY = 10;
    for (var v in hourlyData) { if (v > maxY) maxY = v.toDouble(); }
    maxY = ((maxY / 10).ceil() * 10).toDouble();
    if (maxY < 10) maxY = 10;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saatlik Sipariş Dağılımı', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) { final hours = ['10', '12', '14', '16', '18', '20', '22']; if (value.toInt() < hours.length) { return Text(hours[value.toInt()], style: const TextStyle(color: AppColors.textMuted, fontSize: 11)); } return const SizedBox(); })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(hourlyData.length > 7 ? 7 : hourlyData.length, (i) => _buildSingleBar(i, hourlyData.length > i ? hourlyData[i].toDouble() : 0, maxY * 0.8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.info_outline, size: 16, color: AppColors.textMuted), const SizedBox(width: 8), Text('En yoğun saat: ${peakHour.toString().padLeft(2, '0')}:00', style: TextStyle(color: AppColors.textMuted, fontSize: 13))]),
        ],
      ),
    );
  }

  BarChartGroupData _buildSingleBar(int x, double value, double threshold) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: value, color: value > threshold ? AppColors.success : AppColors.primary, width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))]);
  }

  Widget _buildCustomerStatsCard(BuildContext context, ReportsStats stats) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Müşteri İstatistikleri', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          _CustomerStatItem(icon: Icons.people, color: AppColors.primary, label: 'Toplam Müşteri', value: stats.totalCustomers.toString()),
          const SizedBox(height: 16),
          _CustomerStatItem(icon: Icons.person_add, color: AppColors.success, label: 'Yeni Müşteri (Bu Ay)', value: '${(stats.totalCustomers * 0.15).round()}'),
          const SizedBox(height: 16),
          _CustomerStatItem(icon: Icons.repeat, color: AppColors.info, label: 'Tekrar Eden Müşteri', value: '%${stats.repeatCustomerRate.toStringAsFixed(0)}'),
          const SizedBox(height: 16),
          _CustomerStatItem(icon: Icons.star, color: AppColors.warning, label: 'Ortalama Değerlendirme', value: stats.averageRating.toStringAsFixed(1)),
          const SizedBox(height: 16),
          _CustomerStatItem(icon: Icons.shopping_bag, color: AppColors.restaurant, label: 'Ort. Sipariş/Müşteri', value: stats.avgOrdersPerCustomer.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildEmptyStateSmall(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))]);
  }
}

class _CustomerStatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _CustomerStatItem({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(color: AppColors.textSecondary))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }
}
