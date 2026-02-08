import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/utils/image_utils.dart';
import '../../models/store/store_product_model.dart';

class ProductCard extends StatelessWidget {
  final StoreProduct product;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool showStoreName;
  final bool isFavorite;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onFavorite,
    this.showStoreName = true,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.15, // Wider for compact mobile look
                    child: Image.network(
                      ImageUtils.getProductThumbnail(product.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.image_outlined,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                // Discount badge
                if (product.discountPercent != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '%${product.discountPercent}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.captionSmallSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Favorite button
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      if (onFavorite != null) {
                        onFavorite!();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color:
                            isFavorite ? Colors.red : Colors.grey[400],
                        size: 16,
                      ),
                    ),
                  ),
                ),
                // Store promotion label
                if (product.promotionLabel != null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade600,
                            Colors.deepOrange.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        product.promotionLabel!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.captionSmallSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Badges row
                if (product.promotionLabel == null)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Row(
                      children: [
                        if (product.freeShipping)
                          _buildBadge(context,
                            'Ücretsiz Kargo',
                            const Color(0xFF10B981),
                          ),
                        if (product.fastDelivery) ...[
                          if (product.freeShipping) const SizedBox(width: 4),
                          _buildBadge(context,
                            'Hızlı',
                            AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(context.cardPaddingCompact),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showStoreName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          product.storeName,
                          style: TextStyle(
                            fontSize: context.captionSmallSize,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontSize: context.bodySmallSize,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Rating row
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: context.captionSize,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: context.captionSize,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          ' (${product.reviewCount})',
                          style: TextStyle(
                            fontSize: context.captionSmallSize,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (product.formattedSoldCount.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            product.formattedSoldCount,
                            style: TextStyle(
                              fontSize: context.captionSmallSize,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Price row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          product.formattedPrice,
                          style: TextStyle(
                            fontSize: context.priceSize,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (product.originalPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            product.formattedOriginalPrice,
                            style: TextStyle(
                              fontSize: context.captionSize,
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: context.captionSmallSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
