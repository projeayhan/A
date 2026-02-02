import 'package:flutter/material.dart';
import '../../models/taxi/driver_review_models.dart';

class DriverRatingStatsWidget extends StatelessWidget {
  final DriverRatingStats stats;
  final bool showTrend;
  final bool compact;

  const DriverRatingStatsWidget({
    super.key,
    required this.stats,
    this.showTrend = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (compact) {
      return _buildCompactView(theme, colorScheme);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.3),
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Main rating display
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big rating number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          stats.overallRating.toStringAsFixed(1),
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < stats.overallRating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 20,
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stats.totalRatings} değerlendirme',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Trend indicator
              if (showTrend && stats.totalRatings30Days > 0)
                _buildTrendIndicator(theme, colorScheme),
            ],
          ),

          const SizedBox(height: 24),

          // Rating distribution bars
          ...List.generate(5, (index) {
            final rating = 5 - index;
            return _buildRatingBar(theme, colorScheme, rating);
          }),
        ],
      ),
    );
  }

  Widget _buildCompactView(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        Text(
          stats.overallRating.toStringAsFixed(1),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${stats.totalRatings})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendIndicator(ThemeData theme, ColorScheme colorScheme) {
    final isUp = stats.isTrendingUp;
    final isDown = stats.isTrendingDown;
    final color = isUp ? Colors.green : (isDown ? Colors.red : colorScheme.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUp ? Icons.trending_up_rounded :
                (isDown ? Icons.trending_down_rounded : Icons.trending_flat_rounded),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                stats.trendText,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Son 30 gün',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(ThemeData theme, ColorScheme colorScheme, int rating) {
    final count = stats.getCountForRating(rating);
    final percentage = stats.getPercentageForRating(rating);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Star label
          SizedBox(
            width: 20,
            child: Text(
              '$rating',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 8),

          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(_getRatingColor(rating)),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Count
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 5:
        return Colors.green;
      case 4:
        return Colors.lightGreen;
      case 3:
        return Colors.amber;
      case 2:
        return Colors.orange;
      case 1:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
