import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_model.dart';
import '../../../shared/widgets/status_badge.dart';

class ClientCard extends StatelessWidget {
  final RealtorClient client;
  final VoidCallback? onTap;

  const ClientCard({
    super.key,
    required this.client,
    this.onTap,
  });

  Color _getStatusColor(ClientStatus status) {
    switch (status) {
      case ClientStatus.potential:
        return AppColors.warning;
      case ClientStatus.active:
        return AppColors.success;
      case ClientStatus.closed:
        return AppColors.info;
      case ClientStatus.lost:
        return AppColors.error;
    }
  }

  String _getLookingForLabel(String? lookingFor) {
    switch (lookingFor) {
      case 'sale':
        return 'Satilik';
      case 'rent':
        return 'Kiralik';
      default:
        return lookingFor ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  client.name.isNotEmpty
                      ? client.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            client.name,
                            style: TextStyle(
                              color: AppColors.textPrimary(isDark),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: client.status.label,
                          color: _getStatusColor(client.status),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Phone
                    if (client.phone != null && client.phone!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: AppColors.textMuted(isDark),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              client.phone!,
                              style: TextStyle(
                                color: AppColors.textSecondary(isDark),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Looking for + Budget
                    Row(
                      children: [
                        if (client.lookingFor != null &&
                            client.lookingFor!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: client.lookingFor == 'sale'
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getLookingForLabel(client.lookingFor),
                              style: TextStyle(
                                color: client.lookingFor == 'sale'
                                    ? AppColors.success
                                    : AppColors.info,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (client.budgetMin != null ||
                            client.budgetMax != null)
                          Expanded(
                            child: Text(
                              client.formattedBudget,
                              style: TextStyle(
                                color: AppColors.textMuted(isDark),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),

                    // Follow-up due indicator
                    if (client.isFollowupDue)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notification_important_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Takip zamani geldi',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted(isDark),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
