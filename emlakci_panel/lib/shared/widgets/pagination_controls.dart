import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous button
        _buildNavButton(
          context,
          icon: Icons.chevron_left,
          onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        // Page number buttons
        ..._buildPageButtons(isDark),
        const SizedBox(width: 8),
        // Next button
        _buildNavButton(
          context,
          icon: Icons.chevron_right,
          onTap: currentPage < totalPages - 1
              ? () => onPageChanged(currentPage + 1)
              : null,
          isDark: isDark,
        ),
      ],
    );
  }

  List<Widget> _buildPageButtons(bool isDark) {
    final pages = <int>[];

    // Calculate visible page range (max 5 pages)
    int start = currentPage - 2;
    int end = currentPage + 2;

    if (start < 0) {
      end += (0 - start);
      start = 0;
    }
    if (end >= totalPages) {
      start -= (end - totalPages + 1);
      end = totalPages - 1;
    }
    start = start.clamp(0, totalPages - 1);
    end = end.clamp(0, totalPages - 1);

    for (int i = start; i <= end; i++) {
      pages.add(i);
    }

    return pages.map((page) {
      final isActive = page == currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: isActive ? null : () => onPageChanged(page),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? null
                  : Border.all(color: AppColors.border(isDark)),
            ),
            child: Text(
              '${page + 1}',
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : AppColors.textPrimary(isDark),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border(isDark)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDisabled
              ? AppColors.textMuted(isDark).withValues(alpha: 0.4)
              : AppColors.textPrimary(isDark),
        ),
      ),
    );
  }
}
