import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakDashboardScreen extends ConsumerStatefulWidget {
  const EmlakDashboardScreen({super.key});

  @override
  ConsumerState<EmlakDashboardScreen> createState() => _EmlakDashboardScreenState();
}

class _EmlakDashboardScreenState extends ConsumerState<EmlakDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(emlakStatsProvider);
    final pendingAsync = ref.watch(pendingListingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
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
                      'Emlak Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İlanları, şehirleri ve ilçeleri yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(emlakStatsProvider);
                        ref.invalidate(pendingListingsProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            statsAsync.when(
              data: (stats) => _buildStatsRow(stats),
              loading: () => _buildStatsRowLoading(),
              error: (e, _) => _buildStatsRow(EmlakStats.empty()),
            ),

            const SizedBox(height: 24),

            // Main Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Pending Listings
                  Expanded(
                    flex: 2,
                    child: _buildPendingListingsCard(pendingAsync),
                  ),
                  const SizedBox(width: 24),
                  // Right Column - Quick Stats
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildQuickActionsCard(),
                        const SizedBox(height: 16),
                        Expanded(child: _buildRecentActivityCard()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(EmlakStats stats) {
    return Row(
      children: [
        _buildStatCard(
          'Toplam İlan',
          stats.totalListings.toString(),
          Icons.home_work,
          AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Onay Bekleyen',
          stats.pendingListings.toString(),
          Icons.pending_actions,
          AppColors.warning,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Aktif İlan',
          stats.activeListings.toString(),
          Icons.check_circle,
          AppColors.success,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Şehir',
          stats.totalCities.toString(),
          Icons.location_city,
          AppColors.info,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'İlçe',
          stats.totalDistricts.toString(),
          Icons.map,
          AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildStatsRowLoading() {
    return Row(
      children: List.generate(5, (_) => Expanded(child: _buildStatCardLoading())),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardLoading() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildPendingListingsCard(AsyncValue<List<EmlakListing>> pendingAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Onay Bekleyen İlanlar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: pendingAsync.when(
              data: (listings) => listings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                          SizedBox(height: 12),
                          Text('Onay bekleyen ilan yok', style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: listings.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.surfaceLight),
                      itemBuilder: (context, index) {
                        final listing = listings[index];
                        return _buildListingItem(listing);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingItem(EmlakListing listing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Image
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: listing.images.isNotEmpty
                  ? Image.network(
                      listing.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.home, color: AppColors.textMuted),
                    )
                  : const Icon(Icons.home, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${listing.city ?? ''} / ${listing.district ?? ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          // Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(listing.price),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                listing.listingType == 'sale' ? 'Satılık' : 'Kiralık',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Actions
          Row(
            children: [
              IconButton(
                onPressed: () => _approveListing(listing),
                icon: const Icon(Icons.check, color: AppColors.success),
                tooltip: 'Onayla',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.success.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _rejectListing(listing),
                icon: const Icon(Icons.close, color: AppColors.error),
                tooltip: 'Reddet',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hızlı İşlemler',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickActionButton(
            'Şehir Ekle',
            Icons.add_location,
            AppColors.primary,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            'İlçe Ekle',
            Icons.add_location_alt,
            AppColors.info,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            'Emlak Türü Ekle',
            Icons.add_home,
            AppColors.success,
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final recentActivityAsync = ref.watch(emlakRecentActivityProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son Aktivite',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: recentActivityAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
              data: (activities) => activities.isEmpty
                  ? const Center(child: Text('Aktivite yok', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _buildActivityItem(
                          activity.title,
                          activity.subtitle,
                          _getActivityIcon(activity.activityType),
                          _getActivityColor(activity.activityType),
                          _formatTimeAgo(activity.createdAt),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'new_listing':
        return Icons.add;
      case 'approved':
        return Icons.check;
      case 'rejected':
        return Icons.close;
      case 'city_added':
        return Icons.location_city;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String activityType) {
    switch (activityType) {
      case 'new_listing':
        return AppColors.success;
      case 'approved':
        return AppColors.info;
      case 'rejected':
        return AppColors.error;
      case 'city_added':
        return AppColors.primary;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon, Color color, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M ₺';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K ₺';
    }
    return '${price.toStringAsFixed(0)} ₺';
  }

  void _approveListing(EmlakListing listing) async {
    final service = ref.read(emlakAdminServiceProvider);
    try {
      await service.updateListingStatus(listing.id, 'active');
      ref.invalidate(pendingListingsProvider);
      ref.invalidate(emlakStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İlan onaylandı'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _rejectListing(EmlakListing listing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlanı Reddet'),
        content: Text('"${listing.title}" ilanını reddetmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(emlakAdminServiceProvider);
      try {
        await service.updateListingStatus(listing.id, 'rejected');
        ref.invalidate(pendingListingsProvider);
        ref.invalidate(emlakStatsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('İlan reddedildi'), backgroundColor: AppColors.warning),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
