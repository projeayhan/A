import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/merchant_models.dart';
import '../../core/providers/merchant_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(currentMerchantProvider);
    final pendingOrders = ref.watch(pendingOrdersProvider);
    final activeOrdersCount = ref.watch(activeOrdersCountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(context, merchant.valueOrNull),
          const SizedBox(height: 24),

          // Verification Warning
          if (merchant.valueOrNull?.isApproved == false) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha:0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hesabiniz Onay Bekliyor',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Isletmenizin onaylanmasi icin lutfen dogrulama belgelerini yukleyin.',
                          style: TextStyle(
                            color: AppColors.error.withValues(alpha:0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Belgeleri Yukle'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Quick Stats
          _buildQuickStats(
            context,
            ref,
            activeOrdersCount,
            pendingOrders.length,
          ),
          const SizedBox(height: 24),

          // Main Content Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column - Charts & Stats
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildRevenueChart(context, ref),
                    const SizedBox(height: 24),
                    _buildOrdersChart(context, ref),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right Column - Pending Orders & Activity
              Expanded(
                child: Column(
                  children: [
                    _buildPendingOrdersCard(context, pendingOrders),
                    const SizedBox(height: 24),
                    _buildRecentActivityCard(context, ref),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, Merchant? merchant) {
    final now = DateTime.now();
    String greeting;
    if (now.hour < 12) {
      greeting = 'Gunaydin';
    } else if (now.hour < 18) {
      greeting = 'Iyi Gunler';
    } else {
      greeting = 'Iyi Aksamlar';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                merchant?.businessName ?? 'Isletmenize hosgeldiniz',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
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
                DateFormat('d MMMM yyyy, EEEE', 'tr').format(DateTime.now()),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    WidgetRef ref,
    int activeOrders,
    int pendingOrders,
  ) {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final isRestaurant = merchant?.type == MerchantType.restaurant;
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];

    // Bugünün siparişlerini hesapla
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayOrders =
        orders.where((o) => o.createdAt.isAfter(todayStart)).toList();
    final todayRevenue = todayOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold(0.0, (sum, o) => sum + o.total);

    final reviews = ref.watch(reviewsProvider).valueOrNull ?? [];

    // Okunmamış mesaj sayısı
    final unreadMessages = merchant != null
        ? ref.watch(unreadMessagesCountProvider(merchant.id)).valueOrNull ?? 0
        : 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Bugunun Geliri',
            value: '${todayRevenue.toStringAsFixed(2)} TL',
            change: todayOrders.isNotEmpty ? '+${todayOrders.length}' : null,
            isPositive: true,
            icon: Icons.trending_up,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Bugunun Siparisleri',
            value: todayOrders.length.toString(),
            subtitle: 'Toplam ${orders.length} siparis',
            icon: Icons.receipt_long,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Aktif Siparisler',
            value: activeOrders.toString(),
            subtitle: '$pendingOrders bekliyor',
            icon: Icons.local_shipping,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Musteri Mesajlari',
            value: unreadMessages.toString(),
            subtitle: unreadMessages > 0 ? 'Okunmamis mesaj' : 'Mesaj yok',
            icon: Icons.chat_bubble,
            color: unreadMessages > 0 ? AppColors.error : AppColors.info,
            isHighlighted: unreadMessages > 0,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            title: 'Ortalama Puan',
            value: merchant?.rating.toStringAsFixed(1) ?? '0.0',
            subtitle: '${reviews.length} degerlendirme',
            icon: Icons.star,
            color: isRestaurant ? AppColors.restaurant : AppColors.store,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final dashboardStats = merchant != null
        ? ref.watch(dashboardStatsProvider(merchant.id))
        : null;

    // Supabase'den gelen haftalik gelir verileri
    final weeklyRevenue = dashboardStats?.valueOrNull?.weeklyRevenue ?? [];

    // Grafik icin spot'lari olustur
    List<FlSpot> spots = [];
    double maxY = 1000; // Minimum maxY

    if (weeklyRevenue.isNotEmpty) {
      for (int i = 0; i < weeklyRevenue.length && i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), weeklyRevenue[i]));
        if (weeklyRevenue[i] > maxY) {
          maxY = weeklyRevenue[i];
        }
      }
    } else {
      // Veri yoksa bos grafik
      spots = List.generate(7, (i) => FlSpot(i.toDouble(), 0));
    }

    // maxY'yi yuvarla
    maxY = ((maxY / 1000).ceil() * 1000).toDouble();
    if (maxY < 1000) maxY = 1000;

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
              Text(
                'Gelir Grafigi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Bu Hafta',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine:
                      (value) =>
                          FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget:
                          (value, meta) => Text(
                            value >= 1000
                                ? '${(value / 1000).toStringAsFixed(1)}K'
                                : value.toInt().toString(),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = [
                          'Pzt',
                          'Sal',
                          'Car',
                          'Per',
                          'Cum',
                          'Cmt',
                          'Paz',
                        ];
                        if (value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
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
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withAlpha(30),
                    ),
                  ),
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

  Widget _buildOrdersChart(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).valueOrNull ?? [];

    final delivered =
        orders.where((o) => o.status == OrderStatus.delivered).length;
    final preparing =
        orders
            .where(
              (o) =>
                  o.status == OrderStatus.preparing ||
                  o.status == OrderStatus.confirmed ||
                  o.status == OrderStatus.pending,
            )
            .length;
    final onTheWay =
        orders
            .where(
              (o) =>
                  o.status == OrderStatus.delivering ||
                  o.status == OrderStatus.pickedUp ||
                  o.status == OrderStatus.ready,
            )
            .length;
    final cancelled =
        orders.where((o) => o.status == OrderStatus.cancelled).length;

    final total = orders.length;
    final deliveredPct = total > 0 ? (delivered / total * 100).round() : 0;
    final preparingPct = total > 0 ? (preparing / total * 100).round() : 0;
    final onTheWayPct = total > 0 ? (onTheWay / total * 100).round() : 0;
    final cancelledPct = total > 0 ? (cancelled / total * 100).round() : 0;

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
          Text(
            'Siparis Dagilimi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          if (total == 0)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Henuz siparis yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: [
                          if (delivered > 0)
                            PieChartSectionData(
                              value: delivered.toDouble(),
                              color: AppColors.success,
                              title: '$deliveredPct%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              radius: 45,
                            ),
                          if (preparing > 0)
                            PieChartSectionData(
                              value: preparing.toDouble(),
                              color: AppColors.warning,
                              title: '$preparingPct%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              radius: 45,
                            ),
                          if (onTheWay > 0)
                            PieChartSectionData(
                              value: onTheWay.toDouble(),
                              color: AppColors.info,
                              title: '$onTheWayPct%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              radius: 45,
                            ),
                          if (cancelled > 0)
                            PieChartSectionData(
                              value: cancelled.toDouble(),
                              color: AppColors.error,
                              title: '$cancelledPct%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              radius: 45,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendItem(
                      color: AppColors.success,
                      label: 'Teslim Edildi',
                      value: '$delivered',
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: AppColors.warning,
                      label: 'Hazirlaniyor',
                      value: '$preparing',
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: AppColors.info,
                      label: 'Yolda',
                      value: '$onTheWay',
                    ),
                    const SizedBox(height: 12),
                    _LegendItem(
                      color: AppColors.error,
                      label: 'Iptal',
                      value: '$cancelled',
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersCard(BuildContext context, List<Order> orders) {
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
              Text(
                'Bekleyen Siparisler',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (orders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    orders.length.toString(),
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tum siparisler tamamlandi!',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.take(5).length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final order = orders[index];
                return _PendingOrderItem(order: order);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final isRestaurant = merchant?.type == MerchantType.restaurant;
    final dashboardStats = merchant != null
        ? ref.watch(dashboardStatsProvider(merchant.id))
        : null;

    final activities = dashboardStats?.valueOrNull?.recentActivities ?? [];

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
          Text(
            'Son Aktiviteler',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 40,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Henuz aktivite yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...activities.take(6).map((activity) {
              final type = activity['type'] as String;
              final data = activity['data'] as Map<String, dynamic>;
              final createdAt = DateTime.parse(activity['created_at']);
              final timeAgo = _getTimeAgo(createdAt);

              if (type == 'review') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityItem(
                    icon: Icons.star,
                    iconColor: AppColors.warning,
                    title: 'Yeni Yorum',
                    subtitle: '${data['customer_name'] ?? 'Anonim'} - ${data['overall_rating']?.toInt() ?? 0} yildiz',
                    time: timeAgo,
                  ),
                );
              } else {
                // Order
                final status = data['status'] as String? ?? '';
                IconData icon;
                Color iconColor;
                String title;

                switch (status) {
                  case 'delivered':
                    icon = Icons.check_circle;
                    iconColor = AppColors.success;
                    title = 'Teslim Edildi';
                    break;
                  case 'cancelled':
                    icon = Icons.cancel;
                    iconColor = AppColors.error;
                    title = 'Iptal Edildi';
                    break;
                  case 'pending':
                    icon = Icons.receipt;
                    iconColor = AppColors.primary;
                    title = 'Yeni Siparis';
                    break;
                  case 'confirmed':
                    icon = Icons.thumb_up;
                    iconColor = AppColors.info;
                    title = 'Onaylandi';
                    break;
                  case 'preparing':
                    // Restoran için mutfak ikonu, mağaza için paket ikonu
                    icon = isRestaurant ? Icons.restaurant : Icons.inventory_2;
                    iconColor = AppColors.warning;
                    title = 'Hazirlaniyor';
                    break;
                  case 'ready':
                    icon = Icons.done_all;
                    iconColor = AppColors.success;
                    title = 'Hazir';
                    break;
                  default:
                    icon = Icons.receipt_long;
                    iconColor = AppColors.textSecondary;
                    title = 'Siparis';
                }

                final orderNumber = data['order_number'] ?? '';
                final total = (data['total_amount'] ?? data['total'] ?? 0) as num;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityItem(
                    icon: icon,
                    iconColor: iconColor,
                    title: title,
                    subtitle: '#$orderNumber - ${total.toStringAsFixed(0)} TL',
                    time: timeAgo,
                  ),
                );
              }
            }),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Simdi';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk once';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat once';
    } else {
      return '${difference.inDays} gun once';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? change;
  final String? subtitle;
  final bool isPositive;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  const _StatCard({
    required this.title,
    required this.value,
    this.change,
    this.subtitle,
    this.isPositive = true,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? color : AppColors.border,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
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
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isPositive
                            ? AppColors.success.withAlpha(30)
                            : AppColors.error.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    change!,
                    style: TextStyle(
                      color: isPositive ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? title,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PendingOrderItem extends StatelessWidget {
  final Order order;

  const _PendingOrderItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.schedule, color: AppColors.warning),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${order.orderNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${order.itemCount} urun - ${order.total.toStringAsFixed(0)} TL',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Text(
          order.waitingTimeText,
          style: TextStyle(
            color:
                order.waitingTime.inMinutes > 5
                    ? AppColors.error
                    : AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        Text(time, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}
