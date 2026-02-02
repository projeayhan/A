import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/car_sales_admin_service.dart';

class CarSalesDashboardScreen extends ConsumerStatefulWidget {
  const CarSalesDashboardScreen({super.key});

  @override
  ConsumerState<CarSalesDashboardScreen> createState() => _CarSalesDashboardScreenState();
}

class _CarSalesDashboardScreenState extends ConsumerState<CarSalesDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(carSalesStatsProvider);
    final pendingAsync = ref.watch(pendingCarListingsProvider);

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
                      'Araç Satış Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İlanları, markaları ve satıcıları yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(carSalesStatsProvider);
                        ref.invalidate(pendingCarListingsProvider);
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
              error: (e, _) => _buildStatsRow(CarSalesStats.empty()),
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

  Widget _buildStatsRow(CarSalesStats stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(
            'Toplam İlan',
            stats.totalListings.toString(),
            Icons.directions_car,
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
            'Satıldı',
            stats.soldListings.toString(),
            Icons.sell,
            AppColors.info,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Satıcılar',
            stats.totalDealers.toString(),
            Icons.store,
            AppColors.primary,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Bekleyen Başvuru',
            stats.pendingApplications.toString(),
            Icons.person_add,
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRowLoading() {
    return Row(
      children: List.generate(6, (_) => Expanded(child: _buildStatCardLoading())),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 180,
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
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
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

  Widget _buildPendingListingsCard(AsyncValue<List<CarListing>> pendingAsync) {
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

  Widget _buildListingItem(CarListing listing) {
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
                      errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, color: AppColors.textMuted),
                    )
                  : const Icon(Icons.directions_car, color: AppColors.textMuted),
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
                  '${listing.brandName} ${listing.modelName} · ${listing.year}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                Text(
                  '${_formatNumber(listing.mileage)} km · ${_formatFuelType(listing.fuelType)} · ${_formatTransmission(listing.transmission)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                '${listing.city ?? ''} / ${listing.district ?? ''}',
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
            'Marka Ekle',
            Icons.add_circle,
            AppColors.primary,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            'Özellik Ekle',
            Icons.add_box,
            AppColors.info,
            () {},
          ),
          const SizedBox(height: 8),
          _buildQuickActionButton(
            'Fiyat Ayarla',
            Icons.attach_money,
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
    final recentListingsAsync = ref.watch(recentCarListingsProvider);

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
            'Son Eklenen İlanlar',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: recentListingsAsync.when(
              data: (listings) => listings.isEmpty
                  ? const Center(
                      child: Text('Henüz ilan yok', style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      itemCount: listings.length,
                      itemBuilder: (context, index) {
                        final listing = listings[index];
                        return _buildActivityItem(
                          '${listing.brandName} ${listing.modelName}',
                          _formatPrice(listing.price),
                          _getStatusIcon(listing.status),
                          _getStatusColor(listing.status),
                          _formatTimeAgo(listing.createdAt),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Center(child: Text('Hata', style: TextStyle(color: AppColors.error))),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active': return Icons.check_circle;
      case 'pending': return Icons.pending;
      case 'sold': return Icons.sell;
      case 'rejected': return Icons.cancel;
      default: return Icons.directions_car;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return AppColors.success;
      case 'pending': return AppColors.warning;
      case 'sold': return AppColors.info;
      case 'rejected': return AppColors.error;
      default: return AppColors.textMuted;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dk önce';
    } else {
      return 'Az önce';
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

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatFuelType(String type) {
    switch (type) {
      case 'petrol': return 'Benzin';
      case 'diesel': return 'Dizel';
      case 'electric': return 'Elektrik';
      case 'hybrid': return 'Hibrit';
      case 'lpg': return 'LPG';
      default: return type;
    }
  }

  String _formatTransmission(String type) {
    switch (type) {
      case 'automatic': return 'Otomatik';
      case 'manual': return 'Manuel';
      default: return type;
    }
  }

  void _approveListing(CarListing listing) async {
    final service = ref.read(carSalesAdminServiceProvider);
    try {
      await service.updateListingStatus(listing.id, 'active');
      ref.invalidate(pendingCarListingsProvider);
      ref.invalidate(carSalesStatsProvider);
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

  void _rejectListing(CarListing listing) async {
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
      final service = ref.read(carSalesAdminServiceProvider);
      try {
        await service.updateListingStatus(listing.id, 'rejected');
        ref.invalidate(pendingCarListingsProvider);
        ref.invalidate(carSalesStatsProvider);
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
