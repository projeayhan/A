import 'package:flutter/material.dart';
import '../../models/store/store_category_model.dart';

class StoreCategoryChip extends StatelessWidget {
  final StoreCategory category;
  final VoidCallback? onTap;

  const StoreCategoryChip({
    super.key,
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: category.color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                category.icon,
                color: category.color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
