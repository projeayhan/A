import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/taxi_management_providers.dart';

class AdminDriverEarningsScreen extends ConsumerStatefulWidget {
  final String driverId;
  const AdminDriverEarningsScreen({super.key, required this.driverId});

  @override
  ConsumerState<AdminDriverEarningsScreen> createState() =>
      _AdminDriverEarningsScreenState();
}

class _AdminDriverEarningsScreenState
    extends ConsumerState<AdminDriverEarningsScreen> {
  String _selectedPeriod = 'month';
  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '\u20BA',
    decimalDigits: 2,
  );

  final List<Map<String, String>> _periods = [
    {'key': 'week', 'label': 'Bu Hafta'},
    {'key': 'month', 'label': 'Bu Ay'},
    {'key': 'quarter', 'label': 'Son 3 Ay'},
    {'key': 'year', 'label': 'Bu Yıl'},
  ];

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(
      driverEarningsProvider((
        driverId: widget.driverId,
        period: _selectedPeriod,
      )),
    );
    final historyAsync = ref.watch(
      rideEarningsHistoryProvider((
        driverId: widget.driverId,
        period: _selectedPeriod,
      )),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: earningsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Hata: $e',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        data: (data) => _buildContent(data, historyAsync),
      ),
    );
  }

  Widget _buildContent(
      Map<String, dynamic> data, AsyncValue<List<Map<String, dynamic>>> historyAsync) {
    final totalFare = (data['total_fare'] as num?)?.toDouble() ?? 0;
    final totalTips = (data['total_tips'] as num?)?.toDouble() ?? 0;
    final commission = (data['commission'] as num?)?.toDouble() ?? 0;
    final commissionRate =
        (data['commission_rate'] as num?)?.toDouble() ?? 0.20;
    final netEarnings = (data['net_earnings'] as num?)?.toDouble() ?? 0;
    final rideCount = data['ride_count'] ?? 0;
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final dailyEarnings =
        Map<String, double>.from(data['daily_earnings'] ?? {});

    return SingleChildScrollView(
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
                    'Kazançlar',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sürücünün kazanç detaylarını görüntüleyin.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  // Period selector chips
                  ..._periods.map((p) {
                    final isSelected = _selectedPeriod == p['key'];
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          p['label']!,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _selectedPeriod = p['key']!;
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: AppColors.textSecondary),
                    onPressed: () {
                      ref.invalidate(driverEarningsProvider);
                      ref.invalidate(rideEarningsHistoryProvider);
                    },
                    tooltip: 'Yenile',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Summary Cards
          Row(
            children: [
              _buildStatCard(
                'Brüt Kazanç',
                _currencyFormat.format(totalFare),
                Icons.account_balance_wallet,
                AppColors.info,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Komisyon (%${(commissionRate * 100).toInt()})',
                _currencyFormat.format(commission),
                Icons.percent,
                AppColors.warning,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Net Kazanç',
                _currencyFormat.format(netEarnings),
                Icons.payments,
                AppColors.success,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Bahşişler',
                _currencyFormat.format(totalTips),
                Icons.volunteer_activism,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Sefer Sayısı',
                '$rideCount',
                Icons.local_taxi,
                AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Ortalama Puan',
                rating > 0 ? rating.toStringAsFixed(1) : '-',
                Icons.star,
                AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Commission rate display + Earnings flow
          _buildEarningsFlowSection(totalFare, commission, netEarnings, commissionRate),
          const SizedBox(height: 24),

          // Daily Earnings Chart
          if (dailyEarnings.isNotEmpty) ...[
            _buildDailyChart(dailyEarnings),
            const SizedBox(height: 24),
          ],

          // Earnings Breakdown
          _buildBreakdownSection(totalFare, commission, totalTips, netEarnings, commissionRate),
          const SizedBox(height: 24),

          // Earnings History
          _buildHistorySection(historyAsync, commissionRate),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsFlowSection(
      double gross, double commission, double net, double commissionRate) {
    final total = gross > 0 ? gross : 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Kazanç Akışı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Komisyon Oranı: %${(commissionRate * 100).toInt()}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Visual flow bar
          Row(
            children: [
              // Gross
              Expanded(
                flex: 100,
                child: Column(
                  children: [
                    Text(
                      'Brüt',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(gross),
                      style: const TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.textMuted, size: 20),
              // Commission
              Expanded(
                flex: ((commission / total) * 100).toInt().clamp(10, 100),
                child: Column(
                  children: [
                    Text(
                      'Komisyon',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '-${_currencyFormat.format(commission)}',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.textMuted, size: 20),
              // Net
              Expanded(
                flex: 100,
                child: Column(
                  children: [
                    Text(
                      'Net',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(net),
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    flex: ((net / total) * 100).toInt().clamp(1, 100),
                    child: Container(color: AppColors.success),
                  ),
                  Expanded(
                    flex: ((commission / total) * 100).toInt().clamp(1, 100),
                    child: Container(color: AppColors.error.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendItem('Net Kazanç', AppColors.success),
              const SizedBox(width: 16),
              _buildLegendItem('Komisyon', AppColors.error),
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

  Widget _buildDailyChart(Map<String, double> dailyEarnings) {
    final sortedEntries = dailyEarnings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = sortedEntries
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b) *
        1.2;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Günlük Kazanç Trendi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 100,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final date = sortedEntries[group.x.toInt()].key;
                      return BarTooltipItem(
                        '$date\n${_currencyFormat.format(rod.toY)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\u20BA${value.toInt()}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < sortedEntries.length) {
                          final date = sortedEntries[index].key;
                          // Show day/month
                          if (sortedEntries.length <= 14 ||
                              index % (sortedEntries.length ~/ 7).clamp(1, 100) == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                date.substring(5),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
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
                  horizontalInterval: maxY > 0 ? maxY / 5 : 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.surfaceLight.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: sortedEntries.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value,
                        color: AppColors.primary,
                        width: sortedEntries.length > 20 ? 8 : 16,
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

  Widget _buildBreakdownSection(double totalFare, double commission,
      double totalTips, double netEarnings, double commissionRate) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kazanç Dökümü',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildBreakdownRow(
              'Brüt Hasılat (Yolcu Ücretleri)', totalFare),
          const Divider(color: AppColors.surfaceLight),
          _buildBreakdownRow(
              'Platform Komisyonu (%${(commissionRate * 100).toInt()})',
              -commission,
              isNegative: true),
          const Divider(color: AppColors.surfaceLight),
          _buildBreakdownRow('Bahşişler', totalTips),
          const Divider(color: AppColors.surfaceLight, thickness: 2),
          _buildBreakdownRow('Net Kazanç', netEarnings, isBold: true),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount,
      {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '${isNegative ? "- " : ""}${_currencyFormat.format(amount.abs())}',
            style: TextStyle(
              color: isNegative
                  ? AppColors.error
                  : (isBold ? AppColors.success : AppColors.textPrimary),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
      AsyncValue<List<Map<String, dynamic>>> historyAsync, double commissionRate) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kazanç Geçmişi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          historyAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Hata: $e',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            data: (history) {
              if (history.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long,
                            size: 40, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'Bu dönemde kazanç geçmişi yok.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: history.take(20).map((ride) {
                  final fare =
                      (ride['fare'] as num?)?.toDouble() ?? 0;
                  final tip =
                      (ride['tip_amount'] as num?)?.toDouble() ?? 0;
                  final commissionAmount = fare * commissionRate;
                  final netAmount = fare - commissionAmount + tip;
                  final createdAt = ride['created_at'] != null
                      ? DateTime.parse(ride['created_at']).toLocal()
                      : DateTime.now();
                  final pickup =
                      ride['pickup_address'] ?? 'Bilinmiyor';
                  final dropoff =
                      ride['dropoff_address'] ?? 'Bilinmiyor';
                  final distance =
                      (ride['distance_km'] as num?)?.toDouble() ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_taxi,
                              color: AppColors.success, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$pickup \u2192 $dropoff',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('dd MMM, HH:mm', 'tr').format(createdAt)} \u2022 ${distance.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${_currencyFormat.format(netAmount)}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '-${_currencyFormat.format(commissionAmount)} komisyon',
                              style: TextStyle(
                                color: AppColors.error.withValues(alpha: 0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
