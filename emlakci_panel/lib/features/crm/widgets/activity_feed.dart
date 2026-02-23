import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_engagement_model.dart';
import '../../../providers/client_provider.dart';
import '../../../shared/widgets/chart_card.dart';

class ActivityFeed extends ConsumerWidget {
  final void Function(String clientId)? onClientTap;

  const ActivityFeed({super.key, this.onClientTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feedAsync = ref.watch(clientActivityFeedProvider);

    return ChartCard(
      title: 'Son Musteri Aktiviteleri',
      child: feedAsync.when(
        loading: () => const SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 80,
          child: Center(
            child: Text('Veri yuklenemedi',
                style: TextStyle(color: AppColors.textMuted(isDark))),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return SizedBox(
              height: 80,
              child: Center(
                child: Text(
                  'Henuz aktivite yok',
                  style: TextStyle(color: AppColors.textMuted(isDark)),
                ),
              ),
            );
          }

          final display = items.take(10).toList();
          return Column(
            children:
                display.map((item) => _buildFeedItem(item, isDark)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildFeedItem(ActivityFeedItem item, bool isDark) {
    final icon = _getIcon(item.activityType);
    final color = _getColor(item.activityType);
    final timeStr = _formatTime(item.activityAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: item.clientId != null && onClientTap != null
            ? () => onClientTap!(item.clientId!)
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.textSecondary(isDark),
                    fontSize: 13,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: item.clientName ?? 'Bilinmeyen',
                      style: TextStyle(
                        color: AppColors.textPrimary(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(text: ' ${item.actionText} '),
                    if (item.propertyTitle != null)
                      TextSpan(
                        text: item.propertyTitle!,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: TextStyle(
                color: AppColors.textMuted(isDark),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'view':
        return Icons.visibility_outlined;
      case 'favorite':
        return Icons.favorite_outlined;
      case 'appointment':
        return Icons.calendar_today_outlined;
      default:
        return Icons.circle;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'view':
        return AppColors.info;
      case 'favorite':
        return AppColors.error;
      case 'appointment':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    if (diff.inDays < 7) return '${diff.inDays}g';
    return DateFormat('dd.MM').format(dt);
  }
}
