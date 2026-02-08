import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      'previousMonthRevenue': 0.0,
      'pendingPayments': 0.0,
      'totalBookings': 0,
      'completedBookings': 0,
      'averageBookingValue': 0.0,
      'monthlyData': <Map<String, dynamic>>[],
      'revenueByCategory': <String, double>{},
      'paymentMethods': <String, Map<String, dynamic>>{},
      'topEarningCars': <Map<String, dynamic>>[],
    };
  }

  // Get all bookings with car data for category breakdown
  final bookingsResponse = await client
      .from('rental_bookings')
      .select(
          'total_amount, created_at, status, payment_status, payment_method, car_id, rental_cars(brand, model, plate, category)')
      .eq('company_id', companyId);

  double totalRevenue = 0;
  double monthlyRevenue = 0;
  double previousMonthRevenue = 0;
  double pendingPayments = 0;
  int completedBookings = 0;
  int totalBookings = bookingsResponse.length;

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startOfPrevMonth = DateTime(now.year, now.month - 1, 1);

  // Monthly data for chart (last 6 months)
  final monthlyData = <String, double>{};
  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final key = DateFormat('yyyy-MM').format(month);
    monthlyData[key] = 0;
  }

  // Revenue by category
  final revenueByCategory = <String, double>{};

  // Payment method breakdown
  final paymentMethods = <String, Map<String, dynamic>>{
    'cash': {'count': 0, 'amount': 0.0},
    'credit_card': {'count': 0, 'amount': 0.0},
    'bank_transfer': {'count': 0, 'amount': 0.0},
  };

  // Top earning cars: carId -> {brand, model, plate, revenue, bookingCount}
  final carEarnings = <String, Map<String, dynamic>>{};

  for (final booking in bookingsResponse) {
    final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse(booking['created_at'] ?? '');
    final status = booking['status'] as String?;
    final paymentStatus = booking['payment_status'] as String?;
    final paymentMethod = booking['payment_method'] as String?;
    final car = booking['rental_cars'] as Map<String, dynamic>?;
    final carId = booking['car_id'] as String?;
    final category = car?['category'] as String?;

    if (status == 'completed') {
      totalRevenue += amount;
      completedBookings++;

      if (createdAt != null && createdAt.isAfter(startOfMonth)) {
        monthlyRevenue += amount;
      }

      if (createdAt != null &&
          createdAt.isAfter(startOfPrevMonth) &&
          createdAt.isBefore(startOfMonth)) {
        previousMonthRevenue += amount;
      }

      // Add to monthly chart data
      if (createdAt != null) {
        final key = DateFormat('yyyy-MM').format(createdAt);
        if (monthlyData.containsKey(key)) {
          monthlyData[key] = (monthlyData[key] ?? 0) + amount;
        }
      }

      // Revenue by category
      if (category != null && category.isNotEmpty) {
        revenueByCategory[category] =
            (revenueByCategory[category] ?? 0) + amount;
      }

      // Top earning cars
      if (carId != null && car != null) {
        if (!carEarnings.containsKey(carId)) {
          carEarnings[carId] = {
            'brand': car['brand'] ?? '',
            'model': car['model'] ?? '',
            'plate': car['plate'] ?? '',
            'revenue': 0.0,
            'bookingCount': 0,
          };
        }
        carEarnings[carId]!['revenue'] =
            (carEarnings[carId]!['revenue'] as double) + amount;
        carEarnings[carId]!['bookingCount'] =
            (carEarnings[carId]!['bookingCount'] as int) + 1;
      }
    }

    // Payment method breakdown (for non-cancelled bookings)
    if (status != 'cancelled' && paymentMethod != null) {
      final methodKey = paymentMethods.containsKey(paymentMethod)
          ? paymentMethod
          : 'cash';
      paymentMethods[methodKey]!['count'] =
          (paymentMethods[methodKey]!['count'] as int) + 1;
      paymentMethods[methodKey]!['amount'] =
          (paymentMethods[methodKey]!['amount'] as double) + amount;
    }

    if (paymentStatus == 'pending' && status != 'cancelled') {
      pendingPayments += amount;
    }
  }

  final averageBookingValue =
      completedBookings > 0 ? totalRevenue / completedBookings : 0.0;

  // Sort top earning cars by revenue descending, take top 5
  final sortedCars = carEarnings.values.toList()
    ..sort(
        (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
  final topEarningCars = sortedCars.take(5).toList();

  return {
    'totalRevenue': totalRevenue,
    'monthlyRevenue': monthlyRevenue,
    'previousMonthRevenue': previousMonthRevenue,
    'pendingPayments': pendingPayments,
    'totalBookings': totalBookings,
    'completedBookings': completedBookings,
    'averageBookingValue': averageBookingValue,
    'monthlyData': monthlyData.entries
        .map((e) => {'month': e.key, 'amount': e.value})
        .toList(),
    'revenueByCategory': revenueByCategory,
    'paymentMethods': paymentMethods,
    'topEarningCars': topEarningCars,
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
        payment_status, payment_method, status, created_at,
        rental_cars(brand, model, plate)
      ''')
      .eq('company_id', companyId)
      .inFilter('status', ['completed', 'active', 'confirmed'])
      .order('created_at', ascending: false)
      .limit(15);

  return List<Map<String, dynamic>>.from(response);
});

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(financeStatsProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA');

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
                data: (stats) => _FinanceContent(
                  stats: stats,
                  formatter: formatter,
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
              const SizedBox(height: 24),

              // Recent transactions
              _TransactionsSection(
                transactionsAsync: transactionsAsync,
                formatter: formatter,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Finance content with stats ----------

class _FinanceContent extends StatelessWidget {
  final Map<String, dynamic> stats;
  final NumberFormat formatter;

  const _FinanceContent({
    required this.stats,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyRevenue = (stats['monthlyRevenue'] as num).toDouble();
    final previousMonthRevenue =
        (stats['previousMonthRevenue'] as num).toDouble();

    // Calculate % change
    double percentChange = 0;
    if (previousMonthRevenue > 0) {
      percentChange =
          ((monthlyRevenue - previousMonthRevenue) / previousMonthRevenue) *
              100;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row 1
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
              child: _StatCardWithChange(
                title: 'Bu Ay',
                value: formatter.format(monthlyRevenue),
                icon: Icons.calendar_month,
                color: AppColors.primary,
                percentChange: percentChange,
                hasPreviousData: previousMonthRevenue > 0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Bekleyen Odemeler',
                value: formatter.format(stats['pendingPayments']),
                icon: Icons.pending_actions,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Stats row 2
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Tamamlanan',
                value: '${stats['completedBookings']}',
                subtitle: '/ ${stats['totalBookings']} rezervasyon',
                icon: Icons.check_circle_outline,
                color: AppColors.statusCompleted,
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
            const SizedBox(width: 16),
            Expanded(
              child: _StatCard(
                title: 'Gecen Ay',
                value: formatter.format(previousMonthRevenue),
                icon: Icons.history,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Monthly revenue chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aylik Gelir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: _RevenueChart(
                    monthlyData:
                        stats['monthlyData'] as List<Map<String, dynamic>>,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Revenue by category & Payment methods row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _RevenueByCategoryCard(
                revenueByCategory:
                    Map<String, double>.from(stats['revenueByCategory'] ?? {}),
                formatter: formatter,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _PaymentMethodsCard(
                paymentMethods: Map<String, Map<String, dynamic>>.from(
                    stats['paymentMethods'] ?? {}),
                formatter: formatter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Top earning cars
        _TopEarningCarsCard(
          topCars: List<Map<String, dynamic>>.from(
              stats['topEarningCars'] ?? []),
          formatter: formatter,
        ),
      ],
    );
  }
}

// ---------- Stat cards ----------

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
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
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
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
}

class _StatCardWithChange extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double percentChange;
  final bool hasPreviousData;

  const _StatCardWithChange({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.percentChange,
    required this.hasPreviousData,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = percentChange >= 0;
    final changeColor = isPositive ? AppColors.success : AppColors.error;
    final changeIcon =
        isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

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
                if (hasPreviousData)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(changeIcon, color: changeColor, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '%${percentChange.abs().toStringAsFixed(1)}',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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

// ---------- Revenue chart ----------

class _RevenueChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthlyData;

  const _RevenueChart({required this.monthlyData});

  @override
  Widget build(BuildContext context) {
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
              final fmt =
                  NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA');
              return BarTooltipItem(
                fmt.format(rod.toY),
                const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
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
                if (value.toInt() >= monthlyData.length) {
                  return const SizedBox();
                }
                final month =
                    monthlyData[value.toInt()]['month'] as String;
                final parts = month.split('-');
                const monthNames = [
                  '',
                  'Oca',
                  'Sub',
                  'Mar',
                  'Nis',
                  'May',
                  'Haz',
                  'Tem',
                  'Agu',
                  'Eyl',
                  'Eki',
                  'Kas',
                  'Ara'
                ];
                final monthIndex =
                    int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthIndex > 0 && monthIndex <= 12
                        ? monthNames[monthIndex]
                        : '',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 0 ? maxValue / 4 : 2500,
          getDrawingHorizontalLine: (value) => const FlLine(
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ---------- Revenue by category ----------

class _RevenueByCategoryCard extends StatelessWidget {
  final Map<String, double> revenueByCategory;
  final NumberFormat formatter;

  const _RevenueByCategoryCard({
    required this.revenueByCategory,
    required this.formatter,
  });

  static const _categoryLabels = {
    'economy': 'Ekonomi',
    'compact': 'Kompakt',
    'midsize': 'Orta',
    'fullsize': 'Buyuk',
    'suv': 'SUV',
    'luxury': 'Luks',
    'van': 'Van',
  };

  static const _categoryColors = {
    'economy': AppColors.success,
    'compact': AppColors.info,
    'midsize': AppColors.secondary,
    'fullsize': AppColors.warning,
    'suv': AppColors.primary,
    'luxury': Color(0xFFAB47BC),
    'van': Color(0xFF78909C),
  };

  @override
  Widget build(BuildContext context) {
    final sorted = revenueByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxRevenue =
        sorted.isNotEmpty ? sorted.first.value : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.category, color: AppColors.textSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Kategoriye Gore Gelir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Veri yok',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ...sorted.map((entry) {
                final label =
                    _categoryLabels[entry.key] ?? entry.key;
                final color =
                    _categoryColors[entry.key] ?? AppColors.textSecondary;
                final ratio =
                    maxRevenue > 0 ? entry.value / maxRevenue : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            formatter.format(entry.value),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ---------- Payment methods ----------

class _PaymentMethodsCard extends StatelessWidget {
  final Map<String, Map<String, dynamic>> paymentMethods;
  final NumberFormat formatter;

  const _PaymentMethodsCard({
    required this.paymentMethods,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final methods = [
      {
        'key': 'cash',
        'label': 'Nakit',
        'icon': Icons.money,
        'color': AppColors.success,
      },
      {
        'key': 'credit_card',
        'label': 'Kredi Karti',
        'icon': Icons.credit_card,
        'color': AppColors.info,
      },
      {
        'key': 'bank_transfer',
        'label': 'Havale/EFT',
        'icon': Icons.account_balance,
        'color': AppColors.secondary,
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment, color: AppColors.textSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Odeme Yontemleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...methods.map((method) {
              final key = method['key'] as String;
              final data = paymentMethods[key] ??
                  {'count': 0, 'amount': 0.0};
              final count = data['count'] as int;
              final amount = (data['amount'] as num).toDouble();
              final color = method['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          method['icon'] as IconData,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              method['label'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count islem',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatter.format(amount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------- Top earning cars ----------

class _TopEarningCarsCard extends StatelessWidget {
  final List<Map<String, dynamic>> topCars;
  final NumberFormat formatter;

  const _TopEarningCarsCard({
    required this.topCars,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events,
                    color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Text(
                  'En Cok Kazandiran Araclar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (topCars.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Veri yok',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ...topCars.asMap().entries.map((entry) {
                final index = entry.key;
                final car = entry.value;
                final brand = car['brand'] as String? ?? '';
                final model = car['model'] as String? ?? '';
                final plate = car['plate'] as String? ?? '';
                final revenue = (car['revenue'] as num).toDouble();
                final bookingCount = car['bookingCount'] as int? ?? 0;

                final rankColors = [
                  const Color(0xFFFFD700), // gold
                  const Color(0xFFC0C0C0), // silver
                  const Color(0xFFCD7F32), // bronze
                  AppColors.textSecondary,
                  AppColors.textSecondary,
                ];
                final rankColor = rankColors[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFFFFD700).withValues(alpha: 0.06)
                          : AppColors.surfaceLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: index == 0
                          ? Border.all(
                              color: const Color(0xFFFFD700)
                                  .withValues(alpha: 0.25))
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Rank
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: rankColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Car info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$brand $model',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                plate,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Stats
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatter.format(revenue),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$bookingCount kiralama',
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
              }),
          ],
        ),
      ),
    );
  }
}

// ---------- Transactions section ----------

class _TransactionsSection extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> transactionsAsync;
  final NumberFormat formatter;

  const _TransactionsSection({
    required this.transactionsAsync,
    required this.formatter,
  });

  Color _paymentStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'partial':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  String _paymentStatusLabel(String? status) {
    switch (status) {
      case 'paid':
        return 'Odendi';
      case 'pending':
        return 'Bekliyor';
      case 'partial':
        return 'Kismi';
      default:
        return status ?? '-';
    }
  }

  IconData _paymentMethodIcon(String? method) {
    switch (method) {
      case 'credit_card':
        return Icons.credit_card;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cash':
      default:
        return Icons.money;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long,
                    color: AppColors.textSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Son Islemler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Henuz islem yok',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final car =
                        tx['rental_cars'] as Map<String, dynamic>?;
                    final createdAt =
                        DateTime.tryParse(tx['created_at'] ?? '');
                    final paymentStatus =
                        tx['payment_status'] as String?;
                    final paymentMethod =
                        tx['payment_method'] as String?;
                    final statusColor =
                        _paymentStatusColor(paymentStatus);
                    final bookingId = tx['id'] as String?;

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: bookingId != null
                          ? () => context.push('/bookings/$bookingId')
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        child: Row(
                          children: [
                            // Payment method icon with status color
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _paymentMethodIcon(paymentMethod),
                                color: statusColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Customer & car info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx['customer_name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (car != null) ...[
                                        Text(
                                          '${car['brand']} ${car['model']}',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: AppColors.textMuted,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        tx['booking_number'] ?? '',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Payment status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _paymentStatusLabel(paymentStatus),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Amount & date
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatter.format(
                                      tx['total_amount'] ?? 0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                                if (createdAt != null)
                                  Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(createdAt),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),
          ],
        ),
      ),
    );
  }
}
