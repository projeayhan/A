import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/property_provider.dart';
import '../../../providers/realtor_provider.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/welcome_card.dart';
import '../widgets/quick_actions_card.dart';
import '../widgets/today_appointments_card.dart';
import '../widgets/views_chart.dart';

/// Dashboard screen extracted from the monolith RealtorPanelScreen.
/// Shows a summary of listings, appointments, views, and quick actions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardStats = ref.watch(realtorDashboardStatsProvider);
    final userProperties = ref.watch(userPropertiesProvider);
    final stats = dashboardStats.valueOrNull ?? {};
    final isStatsLoading = dashboardStats.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Welcome hero card
          const WelcomeCard(),
          const SizedBox(height: 24),

          // 2. Stats grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 1200
                  ? 3
                  : (constraints.maxWidth > 600 ? 3 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth > 600 ? 2.2 : 2.5,
                children: [
                  StatCard(
                    title: 'Aktif Ilanlar',
                    value: '${userProperties.activeProperties.length}',
                    icon: Icons.home_work_rounded,
                    color: AppColors.success,
                    isLoading: userProperties.isLoading,
                    onTap: () => context.go('/listings'),
                  ),
                  StatCard(
                    title: 'Bugunku Randevu',
                    value: '${stats['today_appointments'] ?? 0}',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.info,
                    isLoading: isStatsLoading,
                    onTap: () => context.go('/appointments'),
                  ),
                  StatCard(
                    title: 'Toplam Goruntuleme',
                    value: '${stats['total_views'] ?? 0}',
                    icon: Icons.visibility_rounded,
                    color: const Color(0xFF8B5CF6),
                    isLoading: isStatsLoading,
                    onTap: () => context.go('/analytics'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // 3. Quick actions + views chart (side-by-side on wide screens)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 2, child: QuickActionsCard()),
                    const SizedBox(width: 24),
                    const Expanded(flex: 3, child: ViewsChart()),
                  ],
                );
              }
              return const Column(
                children: [
                  QuickActionsCard(),
                  SizedBox(height: 24),
                  ViewsChart(),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // 4. Today's appointments
          const TodayAppointmentsCard(),
        ],
      ),
    );
  }
}
