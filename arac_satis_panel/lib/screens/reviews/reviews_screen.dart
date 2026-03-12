import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/car_models.dart';
import '../../providers/dealer_provider.dart';
import '../../shared/widgets/empty_state.dart';

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(dealerProfileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating Overview
          profileAsync.when(
            data: (profile) {
              if (profile == null) {
                return const SizedBox.shrink();
              }
              return _buildRatingOverview(isDark, profile);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),

          // Reviews List (placeholder)
          const EmptyState(
            icon: Icons.star_outline,
            message: 'Degerlendirmeler burada gorunecek',
            description:
                'Musterilerinizden gelen degerlendirmeler burada listelenecektir.',
          ),
        ],
      ),
    );
  }

  Widget _buildRatingOverview(bool isDark, CarDealer profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Column(
        children: [
          // Large star display
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CarSalesColors.secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star,
              color: CarSalesColors.secondary,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),

          // Average rating
          Text(
            profile.averageRating > 0
                ? profile.averageRating.toStringAsFixed(1)
                : '-',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: CarSalesColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),

          // Stars row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final rating = profile.averageRating;
              IconData icon;
              if (index < rating.floor()) {
                icon = Icons.star;
              } else if (index < rating.ceil() && rating % 1 != 0) {
                icon = Icons.star_half;
              } else {
                icon = Icons.star_outline;
              }
              return Icon(
                icon,
                color: CarSalesColors.secondary,
                size: 28,
              );
            }),
          ),
          const SizedBox(height: 8),

          // Total reviews
          Text(
            '${profile.totalReviews} degerlendirme',
            style: TextStyle(
              color: CarSalesColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
