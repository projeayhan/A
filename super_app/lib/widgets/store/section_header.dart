import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: AppColors.primary,
              size: context.iconMedium,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: context.heading2Size,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (actionText != null)
            GestureDetector(
              onTap: onActionTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionText!,
                    style: TextStyle(
                      fontSize: context.bodySmallSize,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.primary,
                    size: context.captionSize,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
