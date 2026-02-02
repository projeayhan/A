import 'package:flutter/material.dart';
import '../../screens/food/food_home_screen.dart';

class RatingSection extends StatelessWidget {
  final double rating;
  final String totalRatings;
  final bool isDark;

  const RatingSection({
    super.key,
    required this.rating,
    required this.totalRatings,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews & Ratings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: FoodColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rating Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? FoodColors.surfaceDark : const Color(0xFFFCFAF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
              ),
            ),
            child: Row(
              children: [
                // Rating Number
                Container(
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        rating.toString(),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          if (index < rating.floor()) {
                            return const Icon(
                              Icons.star,
                              size: 14,
                              color: FoodColors.primary,
                            );
                          } else if (index < rating) {
                            return const Icon(
                              Icons.star_half,
                              size: 14,
                              color: FoodColors.primary,
                            );
                          }
                          return Icon(
                            Icons.star_border,
                            size: 14,
                            color: isDark ? Colors.grey[600] : Colors.grey[300],
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalRatings ratings',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Rating Bars
                Expanded(
                  child: Column(
                    children: [
                      _buildRatingBar(5, 0.85, isDark),
                      const SizedBox(height: 4),
                      _buildRatingBar(4, 0.10, isDark),
                      const SizedBox(height: 4),
                      _buildRatingBar(3, 0.05, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, double percentage, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 12,
          child: Text(
            stars.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[200],
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: FoodColors.primary.withValues(alpha: 0.4 + (percentage * 0.6)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
