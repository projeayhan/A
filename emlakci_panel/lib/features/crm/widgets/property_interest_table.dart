import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_engagement_model.dart';
import '../../../providers/client_provider.dart';
import '../../../shared/widgets/chart_card.dart';

class PropertyInterestTable extends ConsumerWidget {
  const PropertyInterestTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final interestAsync = ref.watch(propertiesClientInterestProvider);

    return ChartCard(
      title: 'En Cok Ilgi Goren Ilanlar',
      subtitle: 'Musterilerinizin en cok baktigi ilanlar',
      child: interestAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 100,
          child: Center(
            child: Text('Veri yuklenemedi',
                style: TextStyle(color: AppColors.textMuted(isDark))),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'Henuz ilan etkilesimi yok',
                  style: TextStyle(color: AppColors.textMuted(isDark)),
                ),
              ),
            );
          }

          final top5 = items.take(5).toList();
          return Column(
            children: top5
                .map((item) => _buildPropertyRow(context, item, isDark))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildPropertyRow(
      BuildContext context, PropertyClientInterest item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: AppColors.border(isDark),
              child: item.firstImage.isNotEmpty
                  ? Image.network(
                      item.firstImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.home_outlined,
                        color: AppColors.textMuted(isDark),
                        size: 20,
                      ),
                    )
                  : Icon(
                      Icons.home_outlined,
                      color: AppColors.textMuted(isDark),
                      size: 20,
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
                  item.title,
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
                  '${item.city}, ${item.district} - ${item.formattedPrice}',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Stats
          const SizedBox(width: 8),
          _statChip(Icons.visibility, item.clientViewCount.toString(),
              AppColors.info, isDark),
          const SizedBox(width: 6),
          _statChip(Icons.favorite, item.clientFavoriteCount.toString(),
              AppColors.error, isDark),
          const SizedBox(width: 6),
          _statChip(Icons.people, item.uniqueClientViewers.toString(),
              AppColors.primary, isDark),
        ],
      ),
    );
  }

  Widget _statChip(
      IconData icon, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
