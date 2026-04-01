import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/emlak_management_providers.dart';

class AdminEmlakAnalyticsScreen extends ConsumerStatefulWidget {
  final String realtorId;
  const AdminEmlakAnalyticsScreen({super.key, required this.realtorId});

  @override
  ConsumerState<AdminEmlakAnalyticsScreen> createState() =>
      _AdminEmlakAnalyticsScreenState();
}

class _AdminEmlakAnalyticsScreenState
    extends ConsumerState<AdminEmlakAnalyticsScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '\u20BA',
    decimalDigits: 0,
  );
  int _selectedDays = 30;

  @override
  Widget build(BuildContext context) {
    final params = (realtorId: widget.realtorId, days: _selectedDays);
    final analyticsAsync = ref.watch(realtorAnalyticsProvider(params));

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
                      'Emlak Analitik',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlakci performans ve ilan istatistikleri',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildDateRangeButton(),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(realtorAnalyticsProvider(params)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Stats Cards with trend indicators
            analyticsAsync.when(
              data: (data) => _buildStatsCards(data),
              loading: () => _buildStatsCardsLoading(),
              error: (_, _) => Center(
                child: Text(
                  'Veri yüklenemedi',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Two-column layout: Status Breakdown + Price Distribution
            analyticsAsync.when(
              data: (data) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildStatusBreakdownChart(data)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildPriceDistributionChart(data)),
                ],
              ),
              loading: () => Row(
                children: [
                  Expanded(child: _buildChartCardLoading()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildChartCardLoading()),
                ],
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Top Properties by Views
            analyticsAsync.when(
              data: (data) => _buildTopPropertiesChart(data),
              loading: () => _buildChartCardLoading(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Listing Age Analysis
            analyticsAsync.when(
              data: (data) => _buildListingAgeAnalysis(data),
              loading: () => _buildChartCardLoading(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Properties Performance Table
            analyticsAsync.when(
              data: (data) => _buildPropertiesTable(data),
              loading: () => _buildChartCardLoading(),
              error: (_, _) => const SizedBox.shrink(),
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
        const PopupMenuItem(value: 7, child: Text('Son 7 Gun')),
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
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedDays == 7
                  ? 'Son 7 Gun'
                  : _selectedDays == 30
                      ? 'Bu Ay'
                      : _selectedDays == 90
                          ? 'Son 3 Ay'
                          : 'Bu Yıl',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> data) {
    final totalProperties = data['total_properties'] ?? 0;
    final activeCount = data['active_count'] ?? 0;
    final soldCount = data['sold_count'] ?? 0;
    final rentedCount = data['rented_count'] ?? 0;
    final totalViews = data['total_views'] ?? 0;
    final totalFavorites = data['total_favorites'] ?? 0;

    // Calculate average views per property
    final avgViews = totalProperties > 0
        ? (totalViews / totalProperties).toStringAsFixed(1)
        : '0';

    return Column(
      children: [
        Row(
          children: [
            _buildStatCard(
              'Toplam İlan',
              '$totalProperties',
              Icons.home_work,
              AppColors.primary,
              subtitle: 'Tüm ilanlar',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Aktif İlan',
              '$activeCount',
              Icons.check_circle,
              AppColors.success,
              subtitle: totalProperties > 0
                  ? '${((activeCount / totalProperties) * 100).toStringAsFixed(0)}% oran'
                  : null,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Satılan',
              '$soldCount',
              Icons.sell,
              AppColors.info,
              trendIcon: soldCount > 0
                  ? Icons.trending_up
                  : Icons.trending_flat,
              trendColor:
                  soldCount > 0 ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Kiralanan',
              '$rentedCount',
              Icons.key,
              AppColors.warning,
              trendIcon: rentedCount > 0
                  ? Icons.trending_up
                  : Icons.trending_flat,
              trendColor: rentedCount > 0
                  ? AppColors.success
                  : AppColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              'Toplam Görüntülenme',
              '$totalViews',
              Icons.visibility,
              AppColors.primaryLight,
              subtitle: 'Ort: $avgViews/ilan',
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Toplam Favori',
              '$totalFavorites',
              Icons.favorite,
              AppColors.error,
              subtitle: totalViews > 0
                  ? '${((totalFavorites / totalViews) * 100).toStringAsFixed(1)}% donusum'
                  : null,
            ),
            const SizedBox(width: 16),
            // Conversion rate card
            _buildStatCard(
              'Başarı Oranı',
              totalProperties > 0
                  ? '${(((soldCount + rentedCount) / totalProperties) * 100).toStringAsFixed(1)}%'
                  : '0%',
              Icons.analytics,
              AppColors.success,
              subtitle: '${soldCount + rentedCount} tamamlanan',
              trendIcon: (soldCount + rentedCount) > 0
                  ? Icons.trending_up
                  : Icons.trending_flat,
              trendColor: (soldCount + rentedCount) > 0
                  ? AppColors.success
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 16),
            // Average price
            _buildStatCard(
              'Ortalama Fiyat',
              _calculateAveragePrice(data),
              Icons.attach_money,
              AppColors.primary,
              subtitle: 'Aktif ilanlar',
            ),
          ],
        ),
      ],
    );
  }

  String _calculateAveragePrice(Map<String, dynamic> data) {
    final properties =
        List<Map<String, dynamic>>.from(data['properties'] ?? []);
    final activePrices = properties
        .where((p) => p['status'] == 'active' && p['price'] != null)
        .map((p) => (p['price'] as num).toDouble())
        .toList();
    if (activePrices.isEmpty) return '-';
    final avg = activePrices.reduce((a, b) => a + b) / activePrices.length;
    return _currencyFormat.format(avg);
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    IconData? trendIcon,
    Color? trendColor,
  }) {
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (trendIcon != null)
                  Icon(
                    trendIcon,
                    color: trendColor ?? AppColors.textMuted,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBreakdownChart(Map<String, dynamic> data) {
    final activeCount = (data['active_count'] as int?) ?? 0;
    final soldCount = (data['sold_count'] as int?) ?? 0;
    final rentedCount = (data['rented_count'] as int?) ?? 0;
    final properties =
        List<Map<String, dynamic>>.from(data['properties'] ?? []);
    final pendingCount =
        properties.where((p) => p['status'] == 'pending').length;

    final total = activeCount + soldCount + rentedCount + pendingCount;

    if (total == 0) {
      return _buildEmptyChartCard('Durum Dağılımı', 'Henüz ilan yok');
    }

    final sections = <PieChartSectionData>[
      if (activeCount > 0)
        PieChartSectionData(
          value: activeCount.toDouble(),
          title: '$activeCount',
          color: AppColors.success,
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (pendingCount > 0)
        PieChartSectionData(
          value: pendingCount.toDouble(),
          title: '$pendingCount',
          color: AppColors.warning,
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (soldCount > 0)
        PieChartSectionData(
          value: soldCount.toDouble(),
          title: '$soldCount',
          color: AppColors.info,
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (rentedCount > 0)
        PieChartSectionData(
          value: rentedCount.toDouble(),
          title: '$rentedCount',
          color: AppColors.primaryLight,
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
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
          const Text(
            'Durum Dağılımı',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toplam $total ilan',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (activeCount > 0)
                _buildPieLegend('Aktif', AppColors.success, activeCount),
              if (pendingCount > 0)
                _buildPieLegend(
                  'Beklemede',
                  AppColors.warning,
                  pendingCount,
                ),
              if (soldCount > 0)
                _buildPieLegend('Satıldı', AppColors.info, soldCount),
              if (rentedCount > 0)
                _buildPieLegend(
                  'Kiralandı',
                  AppColors.primaryLight,
                  rentedCount,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceDistributionChart(Map<String, dynamic> data) {
    final properties =
        List<Map<String, dynamic>>.from(data['properties'] ?? []);
    final activePrices = properties
        .where((p) => p['status'] == 'active' && p['price'] != null)
        .map((p) => (p['price'] as num).toDouble())
        .toList()
      ..sort();

    if (activePrices.isEmpty) {
      return _buildEmptyChartCard(
        'Fiyat Dağılımı',
        'Aktif ilan yok',
      );
    }

    // Create price buckets
    final ranges = <String, int>{};
    for (final price in activePrices) {
      String bucket;
      if (price < 500000) {
        bucket = '0 - 500K';
      } else if (price < 1000000) {
        bucket = '500K - 1M';
      } else if (price < 2000000) {
        bucket = '1M - 2M';
      } else if (price < 5000000) {
        bucket = '2M - 5M';
      } else {
        bucket = '5M+';
      }
      ranges[bucket] = (ranges[bucket] ?? 0) + 1;
    }

    final bucketOrder = ['0 - 500K', '500K - 1M', '1M - 2M', '2M - 5M', '5M+'];
    final orderedEntries = bucketOrder
        .where((b) => ranges.containsKey(b))
        .map((b) => MapEntry(b, ranges[b]!))
        .toList();

    final maxCount = orderedEntries.isNotEmpty
        ? orderedEntries
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
        : 0;
    final chartMax =
        maxCount > 0 ? (maxCount * 1.3).ceilToDouble() : 5.0;

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
            'Fiyat Dağılımı',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${activePrices.length} aktif ilan',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMax,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final entry = orderedEntries[groupIndex];
                      return BarTooltipItem(
                        '${entry.key}\n${rod.toY.toInt()} ilan',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
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
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < orderedEntries.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              orderedEntries[value.toInt()].key,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
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
                  horizontalInterval: chartMax > 0 ? chartMax / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color:
                        AppColors.surfaceLight.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: orderedEntries.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: AppColors.chartColors[
                            entry.key % AppColors.chartColors.length],
                        width: 28,
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
          const SizedBox(height: 16),
          // Min / Max / Avg
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPriceStat(
                'Min',
                _currencyFormat.format(activePrices.first),
              ),
              _buildPriceStat(
                'Ortalama',
                _currencyFormat.format(
                  activePrices.reduce((a, b) => a + b) /
                      activePrices.length,
                ),
              ),
              _buildPriceStat(
                'Max',
                _currencyFormat.format(activePrices.last),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildListingAgeAnalysis(Map<String, dynamic> data) {
    final properties =
        List<Map<String, dynamic>>.from(data['properties'] ?? []);
    final now = DateTime.now();

    final activeProperties = properties.where((p) {
      final status = p['status'] as String? ?? '';
      return status == 'active' && p['created_at'] != null;
    }).toList();

    if (activeProperties.isEmpty) {
      return _buildEmptyChartCard(
        'İlan Yaşı Analizi',
        'Aktif ilan yok',
      );
    }

    // Calculate days on market for each active property
    final daysOnMarket = activeProperties.map((p) {
      final createdAt = DateTime.parse(p['created_at']);
      return now.difference(createdAt).inDays;
    }).toList();

    final avgDays =
        daysOnMarket.reduce((a, b) => a + b) / daysOnMarket.length;
    final maxDays = daysOnMarket.reduce((a, b) => a > b ? a : b);
    final minDays = daysOnMarket.reduce((a, b) => a < b ? a : b);

    // Age buckets
    final ageBuckets = <String, int>{
      '0-7 gun': 0,
      '8-30 gun': 0,
      '31-90 gun': 0,
      '90+ gun': 0,
    };
    for (final days in daysOnMarket) {
      if (days <= 7) {
        ageBuckets['0-7 gun'] = ageBuckets['0-7 gun']! + 1;
      } else if (days <= 30) {
        ageBuckets['8-30 gun'] = ageBuckets['8-30 gun']! + 1;
      } else if (days <= 90) {
        ageBuckets['31-90 gun'] = ageBuckets['31-90 gun']! + 1;
      } else {
        ageBuckets['90+ gun'] = ageBuckets['90+ gun']! + 1;
      }
    }

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
            'İlan Yaşı Analizi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aktif ilanların piyasada kalma süresi',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          // Summary stats
          Row(
            children: [
              _buildAgeStatCard(
                'Ortalama',
                '${avgDays.toStringAsFixed(0)} gun',
                Icons.timer,
                AppColors.primary,
              ),
              const SizedBox(width: 16),
              _buildAgeStatCard(
                'En Kisa',
                '$minDays gun',
                Icons.flash_on,
                AppColors.success,
              ),
              const SizedBox(width: 16),
              _buildAgeStatCard(
                'En Uzun',
                '$maxDays gun',
                Icons.hourglass_bottom,
                AppColors.warning,
              ),
              const SizedBox(width: 16),
              _buildAgeStatCard(
                'Toplam Aktif',
                '${activeProperties.length}',
                Icons.home,
                AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Age distribution bars
          ...ageBuckets.entries.map((entry) {
            final percentage = activeProperties.isNotEmpty
                ? (entry.value / activeProperties.length * 100)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            percentage > 0 ? percentage / 100.0 : 0.02,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getAgeBucketColor(entry.key),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${entry.value} (${percentage.toStringAsFixed(0)}%)',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
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

  Color _getAgeBucketColor(String bucket) {
    if (bucket.contains('0-7')) return AppColors.success;
    if (bucket.contains('8-30')) return AppColors.info;
    if (bucket.contains('31-90')) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildAgeStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPropertiesChart(Map<String, dynamic> data) {
    final topProperties =
        List<Map<String, dynamic>>.from(data['top_properties'] ?? []);

    if (topProperties.isEmpty) {
      return _buildEmptyChartCard(
        'En Çok Görüntülenen İlanlar',
        'Henüz veri yok',
      );
    }

    final maxViews = topProperties.isNotEmpty
        ? topProperties
            .map(
                (p) => (p['view_count'] as num?)?.toDouble() ?? 0)
            .reduce((a, b) => a > b ? a : b)
        : 0.0;
    final chartMax =
        maxViews > 0 ? (maxViews * 1.2).ceilToDouble() : 10.0;

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
                    'En Çok Görüntülenen İlanlar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Görüntülenme ve favori sayısına göre ilk 10',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildBarLegendItem('Görüntülenme', AppColors.primary),
                  const SizedBox(width: 16),
                  _buildBarLegendItem('Favori', AppColors.error),
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
                maxY: chartMax,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final prop = topProperties[groupIndex];
                      final label =
                          rodIndex == 0 ? 'Görüntülenme' : 'Favori';
                      return BarTooltipItem(
                        '${prop['title'] ?? ''}\n${rod.toY.toInt()} $label',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < topProperties.length) {
                          final title =
                              (topProperties[value.toInt()]['title'] ??
                                  '') as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              title.length > 12
                                  ? '${title.substring(0, 12)}...'
                                  : title,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
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
                  horizontalInterval:
                      chartMax > 0 ? chartMax / 5 : 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.surfaceLight
                        .withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups:
                    topProperties.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value['view_count'] as num?)
                                ?.toDouble() ??
                            0,
                        color: AppColors.primary,
                        width: 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: (entry.value['favorite_count'] as num?)
                                ?.toDouble() ??
                            0,
                        color: AppColors.error,
                        width: 14,
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
        ],
      ),
    );
  }

  Widget _buildBarLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPropertiesTable(Map<String, dynamic> data) {
    final properties =
        List<Map<String, dynamic>>.from(data['properties'] ?? []);
    final now = DateTime.now();

    // Sort by views descending
    final sorted = List<Map<String, dynamic>>.from(properties)
      ..sort((a, b) => ((b['view_count'] as num?) ?? 0)
          .compareTo((a['view_count'] as num?) ?? 0));

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
            'İlan Performans Tablosu',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tüm ilanların detaylı performans bilgileri',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'BASLIK',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'ŞEHİR',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'FIYAT',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'DURUM',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'GORUNTULENME',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'FAVORI',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'GUN',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Henüz ilan yok',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...sorted.map((p) => _buildPropertyRow(p, now)),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(
    Map<String, dynamic> property,
    DateTime now,
  ) {
    final status = property['status'] as String? ?? '';
    final daysListed = property['created_at'] != null
        ? now.difference(DateTime.parse(property['created_at'])).inDays
        : 0;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        statusText = 'Aktif';
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Beklemede';
        break;
      case 'sold':
        statusColor = AppColors.info;
        statusText = 'Satıldı';
        break;
      case 'rented':
        statusColor = AppColors.primaryLight;
        statusText = 'Kiralandı';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.surfaceLight.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              property['title'] ?? '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              property['city'] ?? '-',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _currencyFormat.format(
                (property['price'] as num?)?.toDouble() ?? 0,
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.visibility,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${property['view_count'] ?? 0}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.favorite,
                  size: 14,
                  color: AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '${property['favorite_count'] ?? 0}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '$daysListed gun',
              style: TextStyle(
                color: daysListed > 90
                    ? AppColors.error
                    : daysListed > 30
                        ? AppColors.warning
                        : AppColors.textSecondary,
                fontSize: 14,
                fontWeight:
                    daysListed > 90 ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartCard(String title, String message) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
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
          Expanded(
            child: Center(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCardsLoading() {
    return Column(
      children: [
        Row(
          children: List.generate(
            4,
            (_) => Expanded(
              child: Container(
                height: 120,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(
            4,
            (_) => Expanded(
              child: Container(
                height: 120,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ),
      ],
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
}
