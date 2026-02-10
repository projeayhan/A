import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FoodCategoryItem extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  const FoodCategoryItem({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFFEC6D13).withValues(alpha: 0.2)
                  : const Color(0xFFFED7AA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFEC6D13).withValues(alpha: 0.3)
                    : const Color(0xFFFDBA74),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.restaurant,
                  color: isDark ? Colors.orange[300] : Colors.orange[600],
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
