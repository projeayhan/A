import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_engagement_model.dart';
import '../../../providers/client_provider.dart';
import '../../../shared/widgets/chart_card.dart';

class EngagementTable extends ConsumerWidget {
  final void Function(String clientId)? onClientTap;

  const EngagementTable({super.key, this.onClientTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engagementAsync = ref.watch(clientEngagementProvider);

    return ChartCard(
      title: 'En Ilgili Musteriler',
      subtitle: 'Engagement skoruna gore siralama',
      child: engagementAsync.when(
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
                  'Henuz musteri verisi yok',
                  style: TextStyle(color: AppColors.textMuted(isDark)),
                ),
              ),
            );
          }

          final top5 = items.take(5).toList();
          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('Musteri',
                          style: TextStyle(
                              color: AppColors.textMuted(isDark),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                    _headerCell('Goruntulenme', isDark),
                    _headerCell('Favori', isDark),
                    _headerCell('Skor', isDark),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...top5.map((item) => _buildRow(context, item, isDark)),
            ],
          );
        },
      ),
    );
  }

  Widget _headerCell(String label, bool isDark) {
    return SizedBox(
      width: 80,
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textMuted(isDark),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRow(
      BuildContext context, ClientEngagement item, bool isDark) {
    return InkWell(
      onTap: onClientTap != null ? () => onClientTap!(item.clientId) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      item.clientName.isNotEmpty
                          ? item.clientName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.clientName,
                          style: TextStyle(
                            color: AppColors.textPrimary(isDark),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!item.isLinked)
                          Row(
                            children: [
                              Icon(Icons.link_off,
                                  size: 10,
                                  color: AppColors.textMuted(isDark)),
                              const SizedBox(width: 2),
                              Text(
                                'Hesap bagli degil',
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
            ),
            _valueCell(item.viewCount.toString(), isDark,
                icon: Icons.visibility, iconColor: AppColors.info),
            _valueCell(item.favoriteCount.toString(), isDark,
                icon: Icons.favorite, iconColor: AppColors.error),
            _scoreCell(item.engagementScore, isDark),
          ],
        ),
      ),
    );
  }

  Widget _valueCell(String value, bool isDark,
      {IconData? icon, Color? iconColor}) {
    return SizedBox(
      width: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor ?? AppColors.textMuted(isDark)),
            const SizedBox(width: 3),
          ],
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCell(double score, bool isDark) {
    final color = score > 20
        ? AppColors.success
        : score > 5
            ? AppColors.warning
            : AppColors.textMuted(isDark);

    return SizedBox(
      width: 80,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
