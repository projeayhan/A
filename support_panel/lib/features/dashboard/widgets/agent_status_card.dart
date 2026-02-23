import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/metrics_service.dart';

class AgentStatusCard extends ConsumerWidget {
  const AgentStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(metricsServiceProvider).getOnlineAgents(),
      builder: (context, snapshot) {
        final agents = snapshot.data ?? [];
        final online = agents.where((a) => a['status'] == 'online').length;
        final busy = agents.where((a) => a['status'] == 'busy').length;
        final onBreak = agents.where((a) => a['status'] == 'break').length;

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
                  Icon(Icons.people_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Takim Durumu', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatusRow('Cevrimici', online, AppColors.success, textMuted),
              const SizedBox(height: 10),
              _buildStatusRow('Mesgul', busy, AppColors.warning, textMuted),
              const SizedBox(height: 10),
              _buildStatusRow('Mola', onBreak, AppColors.info, textMuted),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (agents.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: agents.map((a) {
                    final statusColor = a['status'] == 'online' ? AppColors.success
                        : a['status'] == 'busy' ? AppColors.warning
                        : AppColors.info;
                    return Tooltip(
                      message: '${a['full_name']} - ${_statusLabel(a['status'])}',
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: statusColor.withValues(alpha: 0.15),
                        child: Text(
                          (a['full_name'] as String? ?? '?')[0].toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                Text('Cevrimici agent yok', style: TextStyle(color: textMuted, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(String label, int count, Color color, Color textMuted) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: textMuted, fontSize: 13)),
        const Spacer(),
        Text('$count', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'online': return 'Cevrimici';
      case 'busy': return 'Mesgul';
      case 'break': return 'Mola';
      default: return status ?? '';
    }
  }
}
