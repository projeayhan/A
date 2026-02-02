import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Finance stats provider
final financeStatsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) {
    return {
      'totalRevenue': 0.0,
      'monthlyRevenue': 0.0,
      'pendingPayments': 0.0,
      'completedBookings': 0,
      'averageBookingValue': 0.0,
      'monthlyData': <Map<String, dynamic>>[],
    };
  }

  // Get all completed bookings
  final bookingsResponse = await client
      .from('rental_bookings')
      .select('total_amount, created_at, status, payment_status')
      .eq('company_id', companyId);

  double totalRevenue = 0;
  double monthlyRevenue = 0;
  double pendingPayments = 0;
  int completedBookings = 0;

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  // Monthly data for chart (last 6 months)
  final monthlyData = <String, double>{};
  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final key = DateFormat('yyyy-MM').format(month);
    monthlyData[key] = 0;
  }

  for (final booking in bookingsResponse) {
    final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse(booking['created_at'] ?? '');
    final status = booking['status'] as String?;
    final paymentStatus = booking['payment_status'] as String?;

    if (status == 'completed') {
      totalRevenue += amount;
      completedBookings++;

      if (createdAt != null && createdAt.isAfter(startOfMonth)) {
        monthlyRevenue += amount;
      }

      // Add to monthly chart data
      if (createdAt != null) {
        final key = DateFormat('yyyy-MM').format(createdAt);
        if (monthlyData.containsKey(key)) {
          monthlyData[key] = (monthlyData[key] ?? 0) + amount;
        }
      }
    }

    if (paymentStatus == 'pending' && status != 'cancelled') {
      pendingPayments += amount;
    }
  }

  final averageBookingValue =
      completedBookings > 0 ? totalRevenue / completedBookings : 0.0;

  return {
    'totalRevenue': totalRevenue,
    'monthlyRevenue': monthlyRevenue,
    'pendingPayments': pendingPayments,
    'completedBookings': completedBookings,
    'averageBookingValue': averageBookingValue,
    'monthlyData': monthlyData.entries
        .map((e) => {'month': e.key, 'amount': e.value})
        .toList(),
  };
});

// Recent transactions provider
final recentTransactionsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_bookings')
      .select('''
        id, booking_number, customer_name, total_amount,
        payment_status, status, created_at,
        rental_cars(brand, model)
      ''')
      .eq('company_id', companyId)
      .inFilter('status', ['completed', 'active', 'confirmed'])
      .order('created_at', ascending: false)
      .limit(10);

  return List<Map<String, dynamic>>.from(response);
});

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(financeStatsProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeStatsProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Finans',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Stats cards
              statsAsync.when(
                data: (stats) => Column(
                  children: [
                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Toplam Gelir',
                            value: formatter.format(stats['totalRevenue']),
                            icon: Icons.account_balance_wallet,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Bu Ay',
                            value: formatter.format(stats['monthlyRevenue']),
                            icon: Icons.calendar_month,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Bekleyen Ödemeler',
                            value: formatter.format(stats['pendingPayments']),
                            icon: Icons.pending_actions,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Ortalama Rezervasyon',
                            value: formatter.format(stats['averageBookingValue']),
                            icon: Icons.analytics,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Chart
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aylık Gelir',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 250,
                              child: _buildRevenueChart(
                                stats['monthlyData'] as List<Map<String, dynamic>>,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
              const SizedBox(height: 24),

              // Recent transactions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Son İşlemler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      transactionsAsync.when(
                        data: (transactions) {
                          if (transactions.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'Henüz işlem yok',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              final car = tx['rental_cars'] as Map<String, dynamic>?;
                              final createdAt = DateTime.tryParse(tx['created_at'] ?? '');

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long,
                                    color: AppColors.success,
                                  ),
                                ),
                                title: Text(
                                  tx['customer_name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  car != null
                                      ? '${car['brand']} ${car['model']} • ${tx['booking_number'] ?? ''}'
                                      : tx['booking_number'] ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatter.format(tx['total_amount'] ?? 0),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                    if (createdAt != null)
                                      Text(
                                        DateFormat('dd MMM').format(createdAt),
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Hata: $e')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<Map<String, dynamic>> monthlyData) {
    if (monthlyData.isEmpty) {
      return const Center(
        child: Text(
          'Veri yok',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final maxValue = monthlyData
        .map((e) => (e['amount'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue > 0 ? maxValue * 1.2 : 10000,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
              return BarTooltipItem(
                formatter.format(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  '${(value / 1000).toStringAsFixed(0)}K',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= monthlyData.length) return const SizedBox();
                final month = monthlyData[value.toInt()]['month'] as String;
                final parts = month.split('-');
                final monthNames = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
                  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
                final monthIndex = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthIndex > 0 && monthIndex <= 12 ? monthNames[monthIndex] : '',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 0 ? maxValue / 4 : 2500,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.surfaceLight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: monthlyData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: (entry.value['amount'] as num).toDouble(),
                color: AppColors.primary,
                width: 24,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
