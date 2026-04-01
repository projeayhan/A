import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/car_models.dart';
import '../../providers/dealer_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_skeleton.dart';

class ListingsScreen extends ConsumerWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            decoration: BoxDecoration(
              color: CarSalesColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: CarSalesColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: CarSalesColors.textSecondary(isDark),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Aktif'),
                Tab(text: 'Bekleyen'),
                Tab(text: 'Satildi'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          Expanded(
            child: TabBarView(
              children: [
                _ListingTabContent(status: CarListingStatus.active),
                _ListingTabContent(status: CarListingStatus.pending),
                _ListingTabContent(status: CarListingStatus.sold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingTabContent extends ConsumerWidget {
  final CarListingStatus status;

  const _ListingTabContent({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listingsAsync = ref.watch(listingsByStatusProvider(status));

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return EmptyState(
            icon: Icons.directions_car_outlined,
            message: 'Henuz ilan yok',
            description: status == CarListingStatus.active
                ? 'Ilk ilaninizi olusturarak baslayabilirsiniz.'
                : null,
            actionLabel: status == CarListingStatus.active ? 'Ilan Ekle' : null,
            onAction: status == CarListingStatus.active
                ? () => context.push('/listings/add')
                : null,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(listingsByStatusProvider(status));
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return _ListingCard(listing: listing, isDark: isDark);
            },
          ),
        );
      },
      loading: () => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 5,
        itemBuilder: (_, _) => const SkeletonCard(),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: CarSalesColors.textTertiary(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              'Ilanlar yuklenirken hata olustu',
              style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(listingsByStatusProvider(status)),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final CarListing listing;
  final bool isDark;

  const _ListingCard({required this.listing, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/listings/${listing.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: listing.images.isNotEmpty
                  ? Image.network(
                      listing.images.first,
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                    )
                  : _buildImagePlaceholder(),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: CarSalesColors.textPrimary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (listing.isPremium) ...[
                        const SizedBox(width: 6),
                        _buildBadge('Premium', CarSalesColors.primaryGradient),
                      ] else if (listing.isFeatured) ...[
                        const SizedBox(width: 6),
                        _buildBadge('One Cikan', CarSalesColors.goldGradient),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Specs
                  Row(
                    children: [
                      _buildSpecChip(listing.formattedMileage),
                      const SizedBox(width: 8),
                      _buildSpecChip(listing.fuelType.label),
                      const SizedBox(width: 8),
                      _buildSpecChip(listing.transmission.label),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price + Mini stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        listing.formattedPrice,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: CarSalesColors.primary,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: CarSalesColors.textTertiary(isDark),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${listing.viewCount}',
                            style: TextStyle(
                              color: CarSalesColors.textTertiary(isDark),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.favorite_outline,
                            size: 14,
                            color: CarSalesColors.textTertiary(isDark),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${listing.favoriteCount}',
                            style: TextStyle(
                              color: CarSalesColors.textTertiary(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 100,
      height: 80,
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.directions_car,
        color: CarSalesColors.textTertiary(isDark),
        size: 32,
      ),
    );
  }

  Widget _buildBadge(String label, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSpecChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: CarSalesColors.textSecondary(isDark),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
