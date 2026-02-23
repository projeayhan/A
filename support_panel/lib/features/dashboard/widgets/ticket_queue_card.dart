import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/metrics_service.dart';
import '../../../shared/widgets/status_badge.dart';

class TicketQueueCard extends ConsumerWidget {
  const TicketQueueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(metricsServiceProvider).getQueueByServiceType(),
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.queue, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text('Atanmamis Kuyruk', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              if (queue.isEmpty)
                Text('Kuyrukta ticket yok', style: TextStyle(color: textMuted, fontSize: 13))
              else
                ...queue.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      StatusBadge.serviceType(item['service_type'] ?? ''),
                      const Spacer(),
                      Text(
                        '${item['total'] ?? 0}',
                        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if ((item['urgent'] ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item['urgent']} acil',
                            style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
            ],
          ),
        );
      },
    );
  }
}
