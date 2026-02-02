import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../services/job_listings_admin_service.dart';

class JobListingsDashboardScreen extends ConsumerWidget {
  const JobListingsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(jobDashboardStatsProvider);

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
                      'İş İlanları Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kategoriler, yetenekler, yan haklar ve ilanları yönetin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.invalidate(jobDashboardStatsProvider);
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yenile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Stats Cards
            statsAsync.when(
              data: (stats) => _buildStatsGrid(context, stats),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(
                child: Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
              ),
            ),

            const SizedBox(height: 32),

            // Quick Actions
            const Text(
              'Hızlı İşlemler',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActionsGrid(context),

            const SizedBox(height: 32),

            // Management Sections
            const Text(
              'Yönetim Panelleri',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildManagementGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, JobDashboardStats stats) {
    return GridView.count(
      crossAxisCount: 5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(
          icon: Icons.work_rounded,
          title: 'Toplam İlan',
          value: '${stats.totalListings}',
          subtitle: '${stats.activeListings} aktif',
          color: AppColors.primary,
        ),
        _buildStatCard(
          icon: Icons.hourglass_empty_rounded,
          title: 'Onay Bekleyen',
          value: '${stats.pendingListings}',
          subtitle: 'İlan',
          color: AppColors.warning,
          highlight: stats.pendingListings > 0,
        ),
        _buildStatCard(
          icon: Icons.business_rounded,
          title: 'Şirketler',
          value: '${stats.totalCompanies}',
          subtitle: '${stats.pendingCompanies} bekleyen',
          color: AppColors.info,
        ),
        _buildStatCard(
          icon: Icons.category_rounded,
          title: 'Kategoriler',
          value: '${stats.totalCategories}',
          subtitle: 'Tanımlı',
          color: AppColors.success,
        ),
        _buildStatCard(
          icon: Icons.description_rounded,
          title: 'Başvurular',
          value: '${stats.totalApplications}',
          subtitle: 'Toplam',
          color: Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
            : Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
      ),
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
                child: Icon(icon, color: color, size: 22),
              ),
              if (highlight)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Dikkat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: highlight ? color : AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.pending_actions_rounded,
            title: 'Bekleyen İlanlar',
            subtitle: 'Onay bekleyen ilanları incele',
            color: AppColors.warning,
            onTap: () => context.go(AppRoutes.jobListingsList),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.business_center_rounded,
            title: 'Şirket Başvuruları',
            subtitle: 'Yeni şirket başvurularını onayla',
            color: AppColors.info,
            onTap: () => context.go(AppRoutes.jobCompanies),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.add_circle_outline_rounded,
            title: 'Kategori Ekle',
            subtitle: 'Yeni iş kategorisi tanımla',
            color: AppColors.success,
            onTap: () => context.go(AppRoutes.jobCategories),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.settings_rounded,
            title: 'Ayarlar',
            subtitle: 'Sistem ayarlarını düzenle',
            color: AppColors.primary,
            onTap: () => context.go(AppRoutes.jobSettings),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: [
        _buildManagementCard(
          context,
          icon: Icons.category_rounded,
          title: 'Kategoriler',
          description: 'İş kategorilerini yönet',
          route: AppRoutes.jobCategories,
        ),
        _buildManagementCard(
          context,
          icon: Icons.psychology_rounded,
          title: 'Yetenekler',
          description: 'Yetenek havuzunu yönet',
          route: AppRoutes.jobSkills,
        ),
        _buildManagementCard(
          context,
          icon: Icons.card_giftcard_rounded,
          title: 'Yan Haklar',
          description: 'Yan hakları yönet',
          route: AppRoutes.jobBenefits,
        ),
        _buildManagementCard(
          context,
          icon: Icons.work_rounded,
          title: 'İlanlar',
          description: 'Tüm ilanları yönet',
          route: AppRoutes.jobListingsList,
        ),
        _buildManagementCard(
          context,
          icon: Icons.business_rounded,
          title: 'Şirketler',
          description: 'Şirket profillerini yönet',
          route: AppRoutes.jobCompanies,
        ),
        _buildManagementCard(
          context,
          icon: Icons.monetization_on_rounded,
          title: 'Fiyatlandırma',
          description: 'Promosyon fiyatlarını düzenle',
          route: AppRoutes.jobPricing,
        ),
      ],
    );
  }

  Widget _buildManagementCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
