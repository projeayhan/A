import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Stats provider
final dashboardStatsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) {
    return {
      'totalCars': 0,
      'activeCars': 0,
      'totalBookings': 0,
      'pendingBookings': 0,
      'activeBookings': 0,
      'totalRevenue': 0.0,
      'monthlyRevenue': 0.0,
    };
  }

  // Get car stats
  final carsResponse = await client
      .from('rental_cars')
      .select('status')
      .eq('company_id', companyId);

  final totalCars = carsResponse.length;
  final activeCars = carsResponse.where((c) => c['status'] == 'available').length;

  // Get booking stats
  final bookingsResponse = await client
      .from('rental_bookings')
      .select('status, total_amount, created_at')
      .eq('company_id', companyId);

  final totalBookings = bookingsResponse.length;
  final pendingBookings =
      bookingsResponse.where((b) => b['status'] == 'pending').length;
  final activeBookings =
      bookingsResponse.where((b) => b['status'] == 'active').length;

  // Calculate revenue
  double totalRevenue = 0;
  double monthlyRevenue = 0;
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);

  for (final booking in bookingsResponse) {
    if (booking['status'] == 'completed') {
      final amount = (booking['total_amount'] as num?)?.toDouble() ?? 0;
      totalRevenue += amount;

      final createdAt = DateTime.tryParse(booking['created_at'] ?? '');
      if (createdAt != null && createdAt.isAfter(startOfMonth)) {
        monthlyRevenue += amount;
      }
    }
  }

  return {
    'totalCars': totalCars,
    'activeCars': activeCars,
    'totalBookings': totalBookings,
    'pendingBookings': pendingBookings,
    'activeBookings': activeBookings,
    'totalRevenue': totalRevenue,
    'monthlyRevenue': monthlyRevenue,
  };
});

// Recent bookings provider
final recentBookingsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_bookings')
      .select('''
        *,
        rental_cars(brand, model, image_url)
      ''')
      .eq('company_id', companyId)
      .order('created_at', ascending: false)
      .limit(5);

  return List<Map<String, dynamic>>.from(response);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final bookingsAsync = ref.watch(recentBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentBookingsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now()),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/cars'),
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Araç Ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats cards
              statsAsync.when(
                data: (stats) => _buildStatsGrid(stats),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Text('Hata: $e'),
                ),
              ),
              const SizedBox(height: 24),

              // Charts row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Revenue chart
                  Expanded(
                    flex: 2,
                    child: _buildRevenueChart(),
                  ),
                  const SizedBox(width: 24),
                  // Booking status chart
                  Expanded(
                    child: statsAsync.when(
                      data: (stats) => _buildBookingStatusChart(stats),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent bookings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Son Rezervasyonlar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/bookings'),
                            child: const Text('Tümünü Gör'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      bookingsAsync.when(
                        data: (bookings) => _buildRecentBookings(bookings),
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => Center(
                          child: Text('Hata: $e'),
                        ),
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

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          title: 'Toplam Araç',
          value: '${stats['totalCars']}',
          subtitle: '${stats['activeCars']} müsait',
          icon: Icons.directions_car,
          color: AppColors.primary,
        ),
        _StatCard(
          title: 'Toplam Rezervasyon',
          value: '${stats['totalBookings']}',
          subtitle: '${stats['pendingBookings']} beklemede',
          icon: Icons.book_online,
          color: AppColors.info,
        ),
        _StatCard(
          title: 'Aktif Kiralama',
          value: '${stats['activeBookings']}',
          subtitle: 'Şu an kirada',
          icon: Icons.car_rental,
          color: AppColors.success,
        ),
        _StatCard(
          title: 'Bu Ay Gelir',
          value: formatter.format(stats['monthlyRevenue']),
          subtitle: 'Toplam: ${formatter.format(stats['totalRevenue'])}',
          icon: Icons.account_balance_wallet,
          color: AppColors.secondary,
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gelir Grafiği',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 10000,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.surfaceLight,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) => Text(
                          '${(value / 1000).toInt()}K',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz'];
                          if (value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                months[value.toInt()],
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
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
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 15000),
                        FlSpot(1, 22000),
                        FlSpot(2, 18000),
                        FlSpot(3, 28000),
                        FlSpot(4, 35000),
                        FlSpot(5, 32000),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingStatusChart(Map<String, dynamic> stats) {
    final pending = stats['pendingBookings'] as int;
    final active = stats['activeBookings'] as int;
    final total = stats['totalBookings'] as int;
    final completed = total - pending - active;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rezervasyon Durumu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: total > 0
                  ? PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          PieChartSectionData(
                            value: pending.toDouble(),
                            color: AppColors.warning,
                            title: '$pending',
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          PieChartSectionData(
                            value: active.toDouble(),
                            color: AppColors.success,
                            title: '$active',
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          PieChartSectionData(
                            value: completed.toDouble(),
                            color: AppColors.info,
                            title: '$completed',
                            radius: 50,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Henüz veri yok',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Beklemede', AppColors.warning),
                _buildLegendItem('Aktif', AppColors.success),
                _buildLegendItem('Tamamlandı', AppColors.info),
              ],
            ),
          ],
        ),
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBookings(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Henüz rezervasyon yok',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final car = booking['rental_cars'] as Map<String, dynamic>?;
        final createdAt = DateTime.tryParse(booking['created_at'] ?? '');

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: car?['image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      car!['image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.directions_car,
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.directions_car,
                    color: AppColors.textMuted,
                  ),
          ),
          title: Text(
            car != null ? '${car['brand']} ${car['model']}' : 'Araç',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            booking['customer_name'] ?? '',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatusBadge(booking['status'] ?? ''),
              if (createdAt != null)
                Text(
                  DateFormat('dd MMM HH:mm').format(createdAt),
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
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Beklemede';
        break;
      case 'confirmed':
        color = AppColors.info;
        label = 'Onaylandı';
        break;
      case 'active':
        color = AppColors.success;
        label = 'Aktif';
        break;
      case 'completed':
        color = AppColors.secondary;
        label = 'Tamamlandı';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'İptal';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
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
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            const Spacer(),
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
