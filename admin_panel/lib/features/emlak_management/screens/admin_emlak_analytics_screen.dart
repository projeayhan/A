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
  ConsumerState<AdminEmlakAnalyticsScreen> createState() => _AdminEmlakAnalyticsScreenState();
}

class _AdminEmlakAnalyticsScreenState extends ConsumerState<AdminEmlakAnalyticsScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);
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
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildDateRangeButton(),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(realtorAnalyticsProvider(params)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Stats Cards
            analyticsAsync.when(
              data: (data) => _buildStatsCards(data),
              loading: () => _buildStatsCardsLoading(),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),

            const SizedBox(height: 32),

            // Bar Chart - Top Properties by Views
            analyticsAsync.when(
              data: (data) => _buildTopPropertiesChart(data),
              loading: () => _buildChartCardLoading(),
              error: (e, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Properties Table
            analyticsAsync.when(
              data: (data) => _buildPropertiesTable(data),
              loading: () => _buildChartCardLoading(),
              error: (e, _) => const SizedBox.shrink(),
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
        const PopupMenuItem(value: 365, child: Text('Bu Yil')),
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
              _selectedDays == 7 ? 'Son 7 Gun' :
              _selectedDays == 30 ? 'Bu Ay' :
              _selectedDays == 90 ? 'Son 3 Ay' : 'Bu Yil',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> data) {
    return Row(
      children: [
        _buildStatCard(
          'Toplam Ilan',
          '${data['total_properties'] ?? 0}',
          Icons.home_work,
          AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Aktif Ilan',
          '${data['active_count'] ?? 0}',
          Icons.check_circle,
          AppColors.success,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Satilan',
          '${data['sold_count'] ?? 0}',
          Icons.sell,
          AppColors.info,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Kiralanan',
          '${data['rented_count'] ?? 0}',
          Icons.key,
          AppColors.warning,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Toplam Goruntulenme',
          '${data['total_views'] ?? 0}',
          Icons.visibility,
          AppColors.primaryLight,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Toplam Favori',
          '${data['total_favorites'] ?? 0}',
          Icons.favorite,
          AppColors.error,
        ),
      ],
    );
  }

  Widget _buildStatsCardsLoading() {
    return Row(
      children: List.generate(6, (_) => Expanded(
        child: Container(
          height: 100,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      )),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPropertiesChart(Map<String, dynamic> data) {
    final topProperties = List<Map<String, dynamic>>.from(data['top_properties'] ?? []);

    if (topProperties.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: const Center(
          child: Text('Henuz veri yok', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    final maxViews = topProperties.isNotEmpty
        ? topProperties.map((p) => (p['view_count'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final chartMax = maxViews > 0 ? (maxViews * 1.2).ceilToDouble() : 10.0;

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
                    'En Cok Goruntulenen Ilanlar',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Goruntulenme sayisina gore ilk 10',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
                      return BarTooltipItem(
                        '${prop['title'] ?? ''}\n${rod.toY.toInt()} goruntulenme',
                        const TextStyle(color: Colors.white, fontSize: 12),
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
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < topProperties.length) {
                          final title = (topProperties[value.toInt()]['title'] ?? '') as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              title.length > 12 ? '${title.substring(0, 12)}...' : title,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
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
                  horizontalInterval: chartMax > 0 ? chartMax / 5 : 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.surfaceLight.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: topProperties.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value['view_count'] as num?)?.toDouble() ?? 0,
                        color: AppColors.primary,
                        width: 20,
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
          Row(
            children: [
              _buildBarLegendItem('Goruntulenme', AppColors.primary),
            ],
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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

  Widget _buildPropertiesTable(Map<String, dynamic> data) {
    final properties = List<Map<String, dynamic>>.from(data['properties'] ?? []);

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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ilan Detaylari',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tum ilanlarin performans detaylari',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('BASLIK', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('SEHIR', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('FIYAT', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('DURUM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('GORUNTULENME', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                Expanded(child: Text('FAVORI', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (properties.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Henuz ilan yok', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ...properties.map((p) => _buildPropertyRow(p)),
        ],
      ),
    );
  }

  Widget _buildPropertyRow(Map<String, dynamic> property) {
    final status = property['status'] as String? ?? '';

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
        statusText = 'Satildi';
        break;
      case 'rented':
        statusColor = AppColors.primaryLight;
        statusText = 'Kiralandi';
        break;
      default:
        statusColor = AppColors.textMuted;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              property['title'] ?? '-',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              property['city'] ?? '-',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              _currencyFormat.format((property['price'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.visibility, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${property['view_count'] ?? 0}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.favorite, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(
                  '${property['favorite_count'] ?? 0}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
