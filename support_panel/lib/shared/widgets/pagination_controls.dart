import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int>? onPageChanged;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.pageSize,
    this.onPrevious,
    this.onNext,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalCount == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final from = currentPage * pageSize + 1;
    final to = ((currentPage + 1) * pageSize).clamp(0, totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$totalCount kayıttan $from-$to arası gösteriliyor',
            style: TextStyle(color: mutedColor, fontSize: 13),
          ),
          Row(
            children: [
              _buildPageButton(context, icon: Icons.chevron_left, onTap: currentPage > 0 ? onPrevious : null, surfaceColor: surfaceColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _buildPageButton(context, icon: Icons.chevron_right, onTap: currentPage < totalPages - 1 ? onNext : null, surfaceColor: surfaceColor, borderColor: borderColor, textColor: textColor, mutedColor: mutedColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton(BuildContext context, {required IconData icon, VoidCallback? onTap, required Color surfaceColor, required Color borderColor, required Color textColor, required Color mutedColor}) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 20, color: isDisabled ? mutedColor.withValues(alpha: 0.4) : textColor),
      ),
    );
  }
}
