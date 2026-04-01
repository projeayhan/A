import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_engagement_model.dart';

class PropertyActivityCard extends StatelessWidget {
  final ClientPropertyActivity activity;

  const PropertyActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.border(isDark),
              child: activity.firstImage.isNotEmpty
                  ? Image.network(
                      activity.firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.home_outlined,
                        color: AppColors.textMuted(isDark),
                      ),
                    )
                  : Icon(
                      Icons.home_outlined,
                      color: AppColors.textMuted(isDark),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.city}, ${activity.district} - ${activity.formattedPrice}',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _miniStat(
                      Icons.visibility,
                      '${activity.viewCount}',
                      AppColors.info,
                      isDark,
                    ),
                    const SizedBox(width: 8),
                    if (activity.isFavorited)
                      _miniStat(
                        Icons.favorite,
                        'Favori',
                        AppColors.error,
                        isDark,
                      ),
                    const Spacer(),
                    if (activity.lastViewedAt != null)
                      Text(
                        'Son: ${DateFormat('dd.MM.yy').format(activity.lastViewedAt!)}',
                        style: TextStyle(
                          color: AppColors.textMuted(isDark),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
