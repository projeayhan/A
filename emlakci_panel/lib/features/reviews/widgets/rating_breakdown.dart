import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Rating breakdown widget showing 5-star distribution.
/// Displays a large average rating on the left with horizontal bar chart on the right.
class RatingBreakdown extends StatelessWidget {
  final Map<int, int> distribution;
  final double average;
  final int total;

  const RatingBreakdown({
    super.key,
    required this.distribution,
    required this.average,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side - big average number
        SizedBox(
          width: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    index < average.round() ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                    size: 16,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$total degerlendirme',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right side - bar chart
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = 5 - index;
              final count = distribution[star] ?? 0;
              final fraction = total > 0 ? count / total : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$star',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(isDark),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.star,
                      size: 14,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.borderDark
                              : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getBarColor(star),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Color _getBarColor(int star) {
    switch (star) {
      case 5:
        return const Color(0xFF10B981);
      case 4:
        return const Color(0xFF34D399);
      case 3:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFFF97316);
      case 1:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}
