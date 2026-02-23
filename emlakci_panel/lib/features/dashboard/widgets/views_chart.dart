import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/realtor_provider.dart';
import '../../../shared/widgets/chart_card.dart';

/// Line chart showing property views trend over the last 7 days
class ViewsChart extends ConsumerWidget {
  const ViewsChart({super.key});

  static const _dayLabels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perfStats = ref.watch(propertyPerformanceStatsProvider(7));

    return ChartCard(
      title: 'Goruntuleme Trendi',
      child: SizedBox(
        height: 200,
        child: perfStats.when(
          loading: () => _buildShimmer(isDark),
          error: (_, _) => _buildPlaceholder(isDark),
          data: (data) {
            final dailyTotals = _extractDailyTotals(data);
            if (dailyTotals.every((v) => v == 0)) {
              return _buildPlaceholder(isDark);
            }
            return _buildChart(dailyTotals, isDark);
          },
        ),
      ),
    );
  }

  /// Extract last-7-day total views by summing each property's dailyViews array
  List<double> _extractDailyTotals(Map<String, dynamic> data) {
    final properties = data['properties'] as List<dynamic>? ?? [];
    final totals = List<double>.filled(7, 0);

    for (final prop in properties) {
      final dailyViews = prop['dailyViews'] as List<dynamic>? ?? [];
      for (int i = 0; i < dailyViews.length && i < 7; i++) {
        totals[i] += (dailyViews[i] as num).toDouble();
      }
    }

    return totals;
  }

  Widget _buildChart(List<double> values, bool isDark) {
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final ceilMax = maxY < 5 ? 5.0 : (maxY * 1.2).ceilToDouble();

    // Map values to day-of-week adjusted labels
    final now = DateTime.now();
    final labels = List<String>.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      // Monday = 1 in Dart
      return _dayLabels[(day.weekday - 1) % 7];
    });

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: ceilMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceilMax / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark
                ? AppColors.borderDark.withValues(alpha: 0.5)
                : AppColors.borderLight.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: ceilMax / 4,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[idx],
                    style: TextStyle(
                      color: AppColors.textMuted(isDark),
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toInt()} goruntuleme',
                TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              values.length,
              (i) => FlSpot(i.toDouble(), values[i]),
            ),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: AppColors.primary,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(bool isDark) {
    final shimmerColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: shimmerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: shimmerColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 40,
            color: AppColors.textMuted(isDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Henuz veri yok',
            style: TextStyle(
              color: AppColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
