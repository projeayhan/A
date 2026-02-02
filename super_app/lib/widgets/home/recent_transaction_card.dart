import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RecentTransactionCard extends StatelessWidget {
  final String title;
  final String date;
  final String amount;
  final IconData icon;
  final VoidCallback? onTap;

  const RecentTransactionCard({
    super.key,
    required this.title,
    required this.date,
    required this.amount,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.grey[700]!.withValues(alpha: 0.5)
                : Colors.grey[100]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$date • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: amount,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[300] : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[700]!.withValues(alpha: 0.5)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
