import 'package:flutter/material.dart';
import 'quantity_stepper.dart';

/// Generic cart item model for both food and store items
class CartItemData {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int quantity;
  final String imageUrl;
  final String? extra;
  final IconData fallbackIcon;

  const CartItemData({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.extra,
    this.fallbackIcon = Icons.shopping_bag,
  });
}

/// Reusable cart item tile widget.
/// Used in both food and store cart screens.
class CartItemTile extends StatelessWidget {
  final CartItemData item;
  final VoidCallback onRemove;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final Color primaryColor;
  final bool isDark;
  final double imageSize;
  final double padding;
  final double bodyFontSize;
  final double captionFontSize;
  final double priceFontSize;
  final double iconSmallSize;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
    required this.primaryColor,
    this.isDark = false,
    this.imageSize = 60,
    this.padding = 12,
    this.bodyFontSize = 14,
    this.captionFontSize = 12,
    this.priceFontSize = 14,
    this.iconSmallSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[700]!.withValues(alpha: 0.5) : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildImage(),
          const SizedBox(width: 10),
          Expanded(child: _buildDetails()),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: imageSize,
        height: imageSize,
        color: isDark ? Colors.grey[700] : Colors.grey[100],
        child: item.imageUrl.isNotEmpty
            ? Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    item.fallbackIcon,
                    size: 24,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  );
                },
              )
            : Icon(
                item.fallbackIcon,
                size: 24,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: bodyFontSize,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: iconSmallSize,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        if (item.description != null) ...[
          const SizedBox(height: 2),
          Text(
            item.description!,
            style: TextStyle(
              fontSize: captionFontSize,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (item.extra != null) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isDark
                  ? primaryColor.withValues(alpha: 0.2)
                  : primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.extra!,
              style: TextStyle(
                fontSize: captionFontSize - 2,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${item.price.toStringAsFixed(2)} TL',
              style: TextStyle(
                fontSize: priceFontSize,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            QuantityStepper(
              quantity: item.quantity,
              onDecrement: onDecrement,
              onIncrement: onIncrement,
              primaryColor: primaryColor,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }
}
