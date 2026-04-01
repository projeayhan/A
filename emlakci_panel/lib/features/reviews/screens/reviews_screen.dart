import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/review_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/review_card.dart';
import '../widgets/rating_breakdown.dart';
import 'package:emlakci_panel/core/services/log_service.dart';

/// Reviews Screen - Displays realtor reviews with rating overview and list.
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviewsAsync = ref.watch(reviewsProvider);
    final statsAsync = ref.watch(reviewStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating Overview Card
          statsAsync.when(
            data: (stats) => _buildRatingOverview(context, stats, isDark),
            loading: () => _buildOverviewSkeleton(isDark),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFFCA5A5).withValues(alpha: 0.3)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Text(
                'Istatistikler yuklenirken hata: $e',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFDC2626),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Reviews list section title
          Text(
            'Degerlendirmeler',
            style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Reviews list
          reviewsAsync.when(
            data: (reviews) {
              if (reviews.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: EmptyState(
                    message:
                        'Henuz degerlendirme yapilmamis.\nMusterileriniz sizi degerlendirdiginde burada gorunecek.',
                    icon: Icons.rate_review_outlined,
                  ),
                );
              }

              return Column(
                children: reviews.map((review) {
                  return ReviewCard(
                    review: review,
                    onRespond: review.hasResponse
                        ? null
                        : (response) async {
                            try {
                              final service = ref.read(reviewServiceProvider);
                              await service.respondToReview(
                                  review.id, response);
                              // Refresh reviews after responding
                              ref.invalidate(reviewsProvider);
                              ref.invalidate(reviewStatsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        const Text('Yanitiniz basariyla gonderildi'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e, st) {
                              LogService.error('Failed to send review reply', error: e, stackTrace: st, source: 'ReviewsScreen:replyToReview');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Yanit gonderilemedi: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 16),
                    Text(
                      'Degerlendirmeler yuklenirken hata: $e',
                      style: TextStyle(color: AppColors.textSecondary(isDark)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(reviewsProvider),
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RATING OVERVIEW ====================

  Widget _buildRatingOverview(
      BuildContext context, Map<String, dynamic> stats, bool isDark) {
    final averageRating = (stats['averageRating'] as num?)?.toDouble() ?? 0.0;
    final totalReviews = (stats['totalReviews'] as int?) ?? 0;
    final ratingDistribution =
        (stats['ratingDistribution'] as Map<dynamic, dynamic>?) ?? {};
    final avgCommunication =
        (stats['avgCommunication'] as num?)?.toDouble() ?? 0.0;
    final avgProfessionalism =
        (stats['avgProfessionalism'] as num?)?.toDouble() ?? 0.0;
    final avgKnowledge =
        (stats['avgKnowledge'] as num?)?.toDouble() ?? 0.0;

    // Convert distribution keys to int
    final Map<int, int> distribution = {};
    for (final entry in ratingDistribution.entries) {
      final key = entry.key is int ? entry.key as int : int.tryParse('${entry.key}') ?? 0;
      final value = entry.value is int ? entry.value as int : int.tryParse('${entry.value}') ?? 0;
      distribution[key] = value;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Icons.star_rounded,
                  color: const Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 8),
              Text(
                'Degerlendirme Ozeti',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rating breakdown (big number + bars)
          RatingBreakdown(
            distribution: distribution,
            average: averageRating,
            total: totalReviews,
          ),

          // Sub-ratings
          if (avgCommunication > 0 ||
              avgProfessionalism > 0 ||
              avgKnowledge > 0) ...[
            const SizedBox(height: 20),
            Divider(color: AppColors.border(isDark)),
            const SizedBox(height: 16),
            Text(
              'Kategori Bazli Puanlar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                final items = [
                  if (avgCommunication > 0)
                    _buildSubRatingItem(
                        'Iletisim', avgCommunication, Icons.chat_bubble_outline, isDark),
                  if (avgProfessionalism > 0)
                    _buildSubRatingItem('Profesyonellik', avgProfessionalism,
                        Icons.workspace_premium_outlined, isDark),
                  if (avgKnowledge > 0)
                    _buildSubRatingItem(
                        'Bilgi', avgKnowledge, Icons.school_outlined, isDark),
                ];

                if (isWide) {
                  return Row(
                    children: items
                        .map((item) => Expanded(child: item))
                        .toList(),
                  );
                }

                return Column(children: items);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubRatingItem(
      String label, double value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.star,
                          size: 14, color: const Color(0xFFF59E0B)),
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

  // ==================== SKELETON LOADING ====================

  Widget _buildOverviewSkeleton(bool isDark) {
    final shimmerColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 180,
                height: 20,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Big number placeholder
              Container(
                width: 100,
                height: 80,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 24),
              // Bars placeholder
              Expanded(
                child: Column(
                  children: List.generate(
                    5,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
