import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/car_models.dart';
import '../../providers/dealer_provider.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/loading_skeleton.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsAsync = ref.watch(dashboardStatsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Banner
          _buildWelcomeBanner(context, isDark),
          const SizedBox(height: 24),

          // Stats Grid
          statsAsync.when(
            data: (stats) => _buildStatsGrid(context, stats),
            loading: () => _buildSkeletonStatsGrid(),
            error: (_, __) => _buildSkeletonStatsGrid(),
          ),
          const SizedBox(height: 32),

          // Quick Actions
          _buildQuickActions(context, isDark),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: CarSalesColors.primaryGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CarSalesColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hos Geldiniz!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Arac satis panelinizden ilanlarinizi yonetin, performansinizi takip edin.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Map<String, dynamic> stats) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 800 ? 4 : 2;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          title: 'Aktif Ilanlar',
          value: '${stats['active_listings'] ?? 0}',
          icon: Icons.check_circle_outline,
          color: CarSalesColors.success,
        ),
        StatCard(
          title: 'Bekleyen Ilanlar',
          value: '${stats['pending_listings'] ?? 0}',
          icon: Icons.hourglass_empty,
          color: CarSalesColors.secondary,
        ),
        StatCard(
          title: 'Toplam Goruntuleme',
          value: '${stats['total_views'] ?? 0}',
          icon: Icons.visibility_outlined,
          color: CarSalesColors.primary,
        ),
        StatCard(
          title: 'Satilan Araclar',
          value: '${stats['sold_listings'] ?? 0}',
          icon: Icons.sell_outlined,
          color: CarSalesColors.accent,
        ),
      ],
    );
  }

  Widget _buildSkeletonStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: const [
        SkeletonStatCard(),
        SkeletonStatCard(),
        SkeletonStatCard(),
        SkeletonStatCard(),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hizli Islemler',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: CarSalesColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionButton(
              icon: Icons.add_circle_outline,
              label: 'Yeni Ilan',
              color: CarSalesColors.primary,
              onTap: () => context.push('/listings/add'),
            ),
            _QuickActionButton(
              icon: Icons.star_outline,
              label: 'Degerlendirmeler',
              color: CarSalesColors.secondary,
              onTap: () => context.go('/reviews'),
            ),
            _QuickActionButton(
              icon: Icons.message_outlined,
              label: 'Mesajlar',
              color: CarSalesColors.success,
              onTap: () => context.go('/messages'),
            ),
            _QuickActionButton(
              icon: Icons.bar_chart_outlined,
              label: 'Performans',
              color: CarSalesColors.accent,
              onTap: () => context.go('/performance'),
            ),
          ],
        ),
      ],
    );
  }

}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: CarSalesColors.textPrimary(isDark),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
