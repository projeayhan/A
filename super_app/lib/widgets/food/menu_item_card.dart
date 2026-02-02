import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/image_utils.dart';
import '../../screens/food/food_home_screen.dart';
import 'add_to_cart_animation.dart';

class MenuItemCard extends StatefulWidget {
  final String itemId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String? badge;
  final bool isDark;
  final VoidCallback onAdd;
  final String restaurantName;
  final String deliveryTime;
  final double rating;
  final GlobalKey? cartIconKey;
  final bool hasOptionGroups; // Whether item has option groups that need selection

  const MenuItemCard({
    super.key,
    required this.itemId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.badge,
    required this.isDark,
    required this.onAdd,
    required this.restaurantName,
    required this.deliveryTime,
    this.rating = 4.5,
    this.cartIconKey,
    this.hasOptionGroups = false,
  });

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  final GlobalKey _addButtonKey = GlobalKey();

  void _handleAddToCart() {
    // If item has option groups, navigate to detail screen instead of adding directly
    if (widget.hasOptionGroups) {
      context.push(
        '/food/item/${widget.itemId}',
        extra: {
          'name': widget.name,
          'description': widget.description,
          'price': widget.price,
          'imageUrl': widget.imageUrl,
          'rating': widget.rating,
          'restaurantName': widget.restaurantName,
          'deliveryTime': widget.deliveryTime,
        },
      );
      return;
    }

    // Trigger flying animation if cart key is provided
    if (widget.cartIconKey != null) {
      CartAnimationHelper.animateToCart(
        context: context,
        startKey: _addButtonKey,
        endKey: widget.cartIconKey!,
        imageUrl: widget.imageUrl,
        onComplete: () {
          widget.onAdd();
        },
      );
    } else {
      widget.onAdd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push(
          '/food/item/${widget.itemId}',
          extra: {
            'name': widget.name,
            'description': widget.description,
            'price': widget.price,
            'imageUrl': widget.imageUrl,
            'rating': widget.rating,
            'restaurantName': widget.restaurantName,
            'deliveryTime': widget.deliveryTime,
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isDark ? Colors.grey[400] : Colors.grey[500],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${widget.price.toStringAsFixed(2)} TL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      if (widget.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? FoodColors.primary.withValues(alpha: 0.3)
                                : const Color(0xFFFED7AA),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.badge!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: FoodColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Image with Add Button
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ImageUtils.getProductThumbnail(widget.imageUrl),
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 112,
                          height: 112,
                          color: widget.isDark ? Colors.grey[800] : Colors.grey[100],
                          child: Icon(
                            Icons.fastfood,
                            size: 32,
                            color: widget.isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      key: _addButtonKey,
                      onTap: _handleAddToCart,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: widget.isDark ? FoodColors.surfaceDark : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: FoodColors.primary,
                        ),
                      ),
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
