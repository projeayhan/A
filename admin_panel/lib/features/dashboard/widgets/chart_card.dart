import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget chart;
  final List<Widget>? actions;

  const ChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.chart,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (actions != null)
                Row(children: actions!)
              else
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 24),
          chart,
        ],
      ),
    );
  }
}
