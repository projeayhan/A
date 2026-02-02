import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/unified_favorites_provider.dart';
import '../../core/utils/image_utils.dart';
import '../../core/theme/app_responsive.dart';

class RestaurantCard extends ConsumerWidget {
  final String restaurantId;
  final String name;
  final String categories;
  final double rating;
  final String deliveryTime;
  final String minOrder;
  final String deliveryFee;
  final String? discount;
  final String imageUrl;
  final double? minOrderAmount;

  const RestaurantCard({
    super.key,
    required this.restaurantId,
    required this.name,
    required this.categories,
    required this.rating,
    required this.deliveryTime,
    required this.minOrder,
    required this.deliveryFee,
    this.discount,
    required this.imageUrl,
    this.minOrderAmount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFavorite = ref.watch(isFoodFavoriteProvider(restaurantId));

    return GestureDetector(
      onTap: () {
        context.push(
          '/food/restaurant/$restaurantId',
          extra: {
            'name': name,
            'imageUrl': imageUrl,
            'rating': rating,
            'categories': categories,
            'deliveryTime': deliveryTime,
          },
        );
      },
      child: Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D241E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                SizedBox(
                  height: context.cardImageHeight(140),
                  width: double.infinity,
                  child: Image.network(
                    ImageUtils.getProductDetail(imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(
                          Icons.restaurant,
                          size: 48,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),

                // Delivery Time Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D241E) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 14,
                          color: Color(0xFFEC6D13),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          deliveryTime,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEC6D13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Min Order Badge
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D241E) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      'Min. $minOrder',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),

                // Favorite Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      final restaurant = FavoriteRestaurant(
                        id: restaurantId,
                        name: name,
                        imageUrl: imageUrl,
                        category: categories,
                        rating: rating,
                        deliveryTime: deliveryTime,
                        minOrder: minOrderAmount ?? 100,
                        addedAt: DateTime.now(),
                      );
                      ref.read(foodFavoriteProvider.notifier).toggleRestaurant(restaurant);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFavorite
                                ? '$name favorilerden kaldırıldı'
                                : '$name favorilere eklendi',
                          ),
                          backgroundColor: isFavorite ? Colors.red : const Color(0xFFEC6D13),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D241E) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? const Color(0xFFEC4899) : Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info Section
          Padding(
            padding: EdgeInsets.all(context.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and Rating Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF166534).withValues(alpha: 0.3)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rating.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.star,
                            size: 12,
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Categories
                Text(
                  categories,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),

                // Delivery Info
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        deliveryFee,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                      ),
                      if (discount != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          discount!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFEC6D13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
