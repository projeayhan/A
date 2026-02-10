import 'package:flutter/material.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/store_colors.dart';

class StoreSearchBar extends StatelessWidget {
  final VoidCallback? onTap;
  final String hintText;

  const StoreSearchBar({
    super.key,
    this.onTap,
    this.hintText = 'Mağaza veya ürün ara...',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: Colors.grey[500],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hintText,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: context.bodySize,
                ),
              ),
            ),
            Container(
              height: 32,
              width: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.camera_alt_outlined,
                color: StoreColors.primary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
