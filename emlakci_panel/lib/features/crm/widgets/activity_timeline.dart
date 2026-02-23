import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_engagement_model.dart';

class ActivityTimeline extends StatelessWidget {
  final List<ClientPropertyActivity> activities;

  const ActivityTimeline({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Henuz aktivite yok',
            style: TextStyle(color: AppColors.textMuted(isDark)),
          ),
        ),
      );
    }

    // Build a chronological list of events from activities
    final events = <_TimelineEvent>[];
    for (final a in activities) {
      if (a.firstViewedAt != null) {
        events.add(_TimelineEvent(
          type: 'view',
          title: a.title,
          subtitle:
              '${a.viewCount} kez goruntuledi',
          date: a.lastViewedAt ?? a.firstViewedAt!,
          propertyId: a.propertyId,
        ));
      }
      if (a.isFavorited && a.favoritedAt != null) {
        events.add(_TimelineEvent(
          type: 'favorite',
          title: a.title,
          subtitle: 'Favorilere ekledi',
          date: a.favoritedAt!,
          propertyId: a.propertyId,
        ));
      }
    }
    events.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: List.generate(events.length, (i) {
        final event = events[i];
        final isLast = i == events.length - 1;
        return _buildTimelineItem(event, isLast, isDark);
      }),
    );
  }

  Widget _buildTimelineItem(
      _TimelineEvent event, bool isLast, bool isDark) {
    final color = event.type == 'favorite' ? AppColors.error : AppColors.info;
    final icon = event.type == 'favorite'
        ? Icons.favorite
        : Icons.visibility_outlined;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border(isDark),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
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
                    event.subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary(isDark),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(event.date),
                    style: TextStyle(
                      color: AppColors.textMuted(isDark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEvent {
  final String type;
  final String title;
  final String subtitle;
  final DateTime date;
  final String propertyId;

  const _TimelineEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.propertyId,
  });
}
