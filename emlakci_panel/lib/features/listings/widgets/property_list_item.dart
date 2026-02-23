import 'package:flutter/material.dart';
import '../../../models/emlak_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_badge.dart';

/// Property card for list view display.
class PropertyListItem extends StatelessWidget {
  final Property property;
  final VoidCallback? onTap;

  const PropertyListItem({
    super.key,
    required this.property,
    this.onTap,
  });

  Color _statusColor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.active:
        return AppColors.success;
      case PropertyStatus.pending:
        return AppColors.warning;
      case PropertyStatus.sold:
        return AppColors.error;
      case PropertyStatus.rented:
        return AppColors.info;
      case PropertyStatus.reserved:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Property image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: property.images.isNotEmpty
                    ? Image.network(
                        property.images.first,
                        width: 120,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholder(isDark),
                      )
                    : _buildPlaceholder(isDark),
              ),
              const SizedBox(width: 14),

              // Property details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      property.title,
                      style: TextStyle(
                        color: AppColors.textPrimary(isDark),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Location
                    Text(
                      property.location.shortAddress,
                      style: TextStyle(
                        color: AppColors.textMuted(isDark),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Price + Status badge
                    Row(
                      children: [
                        Text(
                          property.formattedPrice,
                          style: const TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        StatusBadge(
                          label: property.status.label,
                          color: _statusColor(property.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Feature chips row
                    Row(
                      children: [
                        _buildFeatureChip(
                          Icons.bed_outlined,
                          '${property.rooms}',
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureChip(
                          Icons.bathtub_outlined,
                          '${property.bathrooms}',
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFeatureChip(
                          Icons.square_foot,
                          '${property.squareMeters} m\u00B2',
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: AppColors.textMuted(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      width: 120,
      height: 90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.home,
        color: AppColors.textMuted(isDark),
        size: 32,
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted(isDark)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(isDark),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
