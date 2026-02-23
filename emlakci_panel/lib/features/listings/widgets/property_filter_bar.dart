import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Reusable filter bar for property listings.
///
/// Provides status filtering via ChoiceChips, a search text field,
/// and a grid/list toggle button.
class PropertyFilterBar extends StatelessWidget {
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool isGridView;
  final VoidCallback onToggleView;

  const PropertyFilterBar({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.isGridView,
    required this.onToggleView,
  });

  static const _statusFilters = <String?, String>{
    null: 'Tümü',
    'active': 'Aktif',
    'pending': 'Bekleyen',
    'sold': 'Satıldı',
    'rented': 'Kiralandı',
  };

  Color _chipColor(String? statusKey) {
    switch (statusKey) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'sold':
        return AppColors.error;
      case 'rented':
        return AppColors.info;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.card(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status ChoiceChips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.entries.map((entry) {
                final isSelected = selectedStatus == entry.key;
                final color = _chipColor(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) => onStatusChanged(entry.key),
                    selectedColor: color.withValues(alpha: 0.15),
                    backgroundColor: isDark
                        ? AppColors.surfaceDark
                        : const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSelected ? color : AppColors.textSecondary(isDark),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : AppColors.border(isDark),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Search + toggle row
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Ilan ara...',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted(isDark),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: AppColors.textMuted(isDark),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.surfaceDark
                        : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Grid / List toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: onToggleView,
                  icon: Icon(
                    isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: AppColors.textSecondary(isDark),
                    size: 22,
                  ),
                  tooltip: isGridView ? 'Liste Gorunumu' : 'Izgara Gorunumu',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
