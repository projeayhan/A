import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart';
import '../widgets/recent_orders_card.dart';
import '../widgets/top_merchants_card.dart';

// Dashboard stats provider - TEK SORGU ile tüm istatistikleri alır
// Önceki: 8+ ayrı sorgu, for döngüleriyle hesaplama
// Şimdi: 1 RPC çağrısı, SQL tarafında SUM/AVG/COUNT
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final supabase = ref.watch(supabaseProvider);

  // Tek bir RPC çağrısı ile tüm istatistikleri al
  final result = await supabase.rpc('get_dashboard_stats');

  final data = result as Map<String, dynamic>;

  return DashboardStats(
    totalUsers: (data['couriers_count'] as int) + (data['taxi_drivers_count'] as int),
    totalMerchants: data['merchants_count'] as int,
    totalPartners: data['partners_count'] as int,
    totalOrders: data['orders_count'] as int,
    totalRevenue: (data['total_revenue'] as num).toDouble(),
    todayOrders: data['today_orders_count'] as int,
    activeDeliveries: data['active_deliveries_count'] as int,
    averageRating: (data['avg_merchant_rating'] as num).toDouble(),
    // Car sales stats
    carDealersCount: data['car_dealers_count'] as int,
    carListingsCount: data['car_listings_count'] as int,
    activeCarListingsCount: data['active_car_listings_count'] as int,
    pendingCarListingsCount: data['pending_car_listings_count'] as int,
    // Individual sellers (Super App users - NOT businesses)
    individualSellersCount: data['individual_sellers_count'] as int,
    // Total businesses (all types combined - excluding individuals)
    totalBusinessesCount: data['total_businesses_count'] as int,
    // Real estate (emlak) stats
    propertiesCount: data['properties_count'] as int,
    activePropertiesCount: data['active_properties_count'] as int,
    pendingPropertiesCount: data['pending_properties_count'] as int,
  );
});

class DashboardStats {
  final int totalUsers;
  final int totalMerchants;
  final int totalPartners;
  final int totalOrders;
  final double totalRevenue;
  final int todayOrders;
  final int activeDeliveries;
  final double averageRating;
  // Car sales stats
  final int carDealersCount;
  final int carListingsCount;
  final int activeCarListingsCount;
  final int pendingCarListingsCount;
  // Individual sellers (Super App - bireysel kullanıcılar)
  final int individualSellersCount;
  // Total businesses (tüm işletmeler - bireysel hariç)
  final int totalBusinessesCount;
  // Real estate (emlak) stats
  final int propertiesCount;
  final int activePropertiesCount;
  final int pendingPropertiesCount;

  DashboardStats({
    required this.totalUsers,
    required this.totalMerchants,
    required this.totalPartners,
    required this.totalOrders,
    required this.totalRevenue,
    required this.todayOrders,
    required this.activeDeliveries,
    required this.averageRating,
    required this.carDealersCount,
    required this.carListingsCount,
    required this.activeCarListingsCount,
    required this.pendingCarListingsCount,
    required this.individualSellersCount,
    required this.totalBusinessesCount,
    required this.propertiesCount,
    required this.activePropertiesCount,
    required this.pendingPropertiesCount,
  });
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoş geldiniz! İşte bugünün özeti.',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildDateRangeButton(),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Rapor İndir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Stats Cards
            statsAsync.when(
              data: (stats) => _buildStatsGrid(stats),
              loading: () => _buildStatsGridLoading(),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),

            const SizedBox(height: 24),

            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Revenue Chart
                Expanded(
                  flex: 2,
                  child: ChartCard(
                    title: 'Gelir Grafiği',
                    subtitle: 'Son 7 gün',
                    chart: _buildRevenueChart(),
                  ),
                ),
                const SizedBox(width: 24),
                // Orders by Category
                Expanded(
                  child: ChartCard(
                    title: 'Sipariş Dağılımı',
                    subtitle: 'Kategoriye göre',
                    chart: _buildPieChart(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bottom Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recent Orders
                const Expanded(
                  flex: 2,
                  child: RecentOrdersCard(),
                ),
                const SizedBox(width: 24),
                // Top Merchants
                const Expanded(
                  child: TopMerchantsCard(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Text(
            'Son 7 Gün',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GENEL ÖZET
        _buildSectionHeader('Genel Özet', Icons.dashboard_rounded, AppColors.primary),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Toplam Kullanıcı',
              value: _formatNumber(stats.totalUsers),
              icon: Icons.people_rounded,
              color: AppColors.info,
              subtitle: 'Kurye + Taksi Şoförü',
            ),
            StatCard(
              title: 'Toplam İşletme',
              value: _formatNumber(stats.totalBusinessesCount),
              icon: Icons.business_rounded,
              color: AppColors.success,
              subtitle: 'Restoran + Galeri + Emlakçı',
            ),
            StatCard(
              title: 'Bireysel Satıcı',
              value: _formatNumber(stats.individualSellersCount),
              icon: Icons.person_rounded,
              color: Colors.orange,
              subtitle: 'Super App Kullanıcıları',
            ),
            StatCard(
              title: 'Toplam Gelir',
              value: '${_formatNumber(stats.totalRevenue.toInt())} ₺',
              icon: Icons.monetization_on_rounded,
              color: AppColors.primary,
              subtitle: 'Tüm işlemlerden',
            ),
          ],
        ),

        const SizedBox(height: 32),

        // YEMEK SİPARİŞİ
        _buildSectionHeader('Yemek Sipariş', Icons.restaurant_rounded, Colors.deepOrange),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Restoran',
              value: _formatNumber(stats.totalMerchants),
              icon: Icons.storefront_rounded,
              color: Colors.deepOrange,
            ),
            StatCard(
              title: 'Aktif Partner',
              value: _formatNumber(stats.totalPartners),
              icon: Icons.delivery_dining_rounded,
              color: AppColors.warning,
            ),
            StatCard(
              title: 'Bugünkü Sipariş',
              value: _formatNumber(stats.todayOrders),
              icon: Icons.receipt_long_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Aktif Teslimat',
              value: _formatNumber(stats.activeDeliveries),
              icon: Icons.local_shipping_rounded,
              color: AppColors.info,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // ARAÇ SATIŞ
        _buildSectionHeader('Araç Satış', Icons.directions_car_rounded, Colors.teal),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Galeri',
              value: _formatNumber(stats.carDealersCount),
              icon: Icons.garage_rounded,
              color: Colors.purple,
              subtitle: 'Onaylı işletme',
            ),
            StatCard(
              title: 'Toplam İlan',
              value: _formatNumber(stats.carListingsCount),
              icon: Icons.directions_car_rounded,
              color: Colors.teal,
            ),
            StatCard(
              title: 'Aktif İlan',
              value: _formatNumber(stats.activeCarListingsCount),
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Onay Bekleyen',
              value: _formatNumber(stats.pendingCarListingsCount),
              icon: Icons.pending_rounded,
              color: AppColors.warning,
            ),
          ],
        ),

        const SizedBox(height: 32),

        // EMLAK
        _buildSectionHeader('Emlak', Icons.home_rounded, Colors.indigo),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Toplam İlan',
              value: _formatNumber(stats.propertiesCount),
              icon: Icons.home_rounded,
              color: Colors.indigo,
            ),
            StatCard(
              title: 'Aktif İlan',
              value: _formatNumber(stats.activePropertiesCount),
              icon: Icons.home_work_rounded,
              color: AppColors.success,
            ),
            StatCard(
              title: 'Onay Bekleyen',
              value: _formatNumber(stats.pendingPropertiesCount),
              icon: Icons.pending_actions_rounded,
              color: AppColors.warning,
            ),
            StatCard(
              title: 'Ort. Puan',
              value: stats.averageRating.toStringAsFixed(1),
              icon: Icons.star_rounded,
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGridLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Genel Özet Loading
        _buildSectionHeaderLoading(),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => const StatCardLoading()),
        ),
        const SizedBox(height: 32),
        // Yemek Sipariş Loading
        _buildSectionHeaderLoading(),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => const StatCardLoading()),
        ),
        const SizedBox(height: 32),
        // Araç Satış Loading
        _buildSectionHeaderLoading(),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => const StatCardLoading()),
        ),
        const SizedBox(height: 32),
        // Emlak Loading
        _buildSectionHeaderLoading(),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => const StatCardLoading()),
        ),
      ],
    );
  }

  Widget _buildSectionHeaderLoading() {
    return Container(
      width: 150,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20000,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
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
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                  if (value.toInt() < days.length) {
                    return Text(
                      days[value.toInt()],
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 45000),
                FlSpot(1, 52000),
                FlSpot(2, 48000),
                FlSpot(3, 61000),
                FlSpot(4, 55000),
                FlSpot(5, 72000),
                FlSpot(6, 68000),
              ],
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          minY: 0,
          maxY: 80000,
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: [
            PieChartSectionData(
              value: 40,
              title: '40%',
              color: AppColors.primary,
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            PieChartSectionData(
              value: 30,
              title: '30%',
              color: AppColors.success,
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            PieChartSectionData(
              value: 20,
              title: '20%',
              color: AppColors.warning,
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            PieChartSectionData(
              value: 10,
              title: '10%',
              color: AppColors.info,
              radius: 50,
              titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
