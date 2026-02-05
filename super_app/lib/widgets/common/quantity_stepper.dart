import 'package:flutter/material.dart';

/// Reusable quantity stepper widget for cart items.
/// Used in both food and store cart screens.
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final Color primaryColor;
  final bool isDark;
  final double buttonSize;
  final double fontSize;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    required this.primaryColor,
    this.isDark = false,
    this.buttonSize = 28,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            icon: Icons.remove,
            onTap: onDecrement,
            isIncrement: false,
          ),
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                quantity.toString(),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ),
          ),
          _buildButton(
            icon: Icons.add,
            onTap: onIncrement,
            isIncrement: true,
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isIncrement,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: isIncrement ? primaryColor : (isDark ? Colors.grey[600] : Colors.white),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: isIncrement
                  ? primaryColor.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: isIncrement ? Colors.white : (isDark ? Colors.grey[200] : Colors.grey[600]),
        ),
      ),
    );
  }
}
