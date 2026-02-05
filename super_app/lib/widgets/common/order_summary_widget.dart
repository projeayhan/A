import 'package:flutter/material.dart';

/// Summary line item model for order summary
class SummaryLineItem {
  final String label;
  final double amount;
  final bool isDiscount;
  final bool isFreeShipping;

  const SummaryLineItem({
    required this.label,
    required this.amount,
    this.isDiscount = false,
    this.isFreeShipping = false,
  });
}

/// Reusable order summary widget for cart and checkout screens.
/// Displays price breakdown with subtotal, fees, discounts and total.
class OrderSummaryWidget extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final String buttonText;
  final VoidCallback? onConfirm;
  final bool isLoading;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final bool isDark;
  final List<SummaryLineItem>? additionalItems;
  final Widget? customButton;
  final bool showFreeShippingNote;
  final double freeShippingThreshold;
  final String currencySuffix;
  final String currencyPrefix;

  const OrderSummaryWidget({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.primaryColor,
    this.discount = 0,
    this.buttonText = 'Siparişi Onayla',
    this.onConfirm,
    this.isLoading = false,
    this.gradientColors,
    this.isDark = false,
    this.additionalItems,
    this.customButton,
    this.showFreeShippingNote = false,
    this.freeShippingThreshold = 500,
    this.currencySuffix = ' TL',
    this.currencyPrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.grey[700]!.withValues(alpha: 0.5) : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Ara Toplam', _formatCurrency(subtotal)),
          const SizedBox(height: 12),
          _buildDeliveryRow(),
          if (discount > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              'İndirim',
              '-${_formatCurrency(discount)}',
              isDiscount: true,
            ),
          ],
          if (additionalItems != null)
            ...additionalItems!.map((item) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildSummaryRow(
                    item.label,
                    item.isDiscount
                        ? '-${_formatCurrency(item.amount)}'
                        : _formatCurrency(item.amount),
                    isDiscount: item.isDiscount,
                  ),
                )),
          const SizedBox(height: 12),
          _buildDashedDivider(),
          const SizedBox(height: 8),
          _buildTotalRow(),
          const SizedBox(height: 16),
          customButton ?? _buildConfirmButton(),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '$currencyPrefix${amount.toStringAsFixed(2)}$currencySuffix';
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDiscount
                ? Colors.green
                : (isDark ? Colors.grey[200] : Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryRow() {
    final isFree = showFreeShippingNote && subtotal >= freeShippingThreshold;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'Teslimat Ücreti',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (isFree) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ÜCRETSİZ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
        Text(
          isFree ? _formatCurrency(0) : _formatCurrency(deliveryFee),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isFree ? Colors.green : (isDark ? Colors.grey[200] : Colors.grey[800]),
            decoration: isFree ? TextDecoration.lineThrough : null,
            decorationColor: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(
          30,
          (index) => Expanded(
            child: Container(
              height: 1,
              color: index % 2 == 0
                  ? (isDark ? Colors.grey[700] : Colors.grey[200])
                  : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toplam Ödenecek Tutar',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatCurrency(total),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    final colors = gradientColors ?? [primaryColor, primaryColor.withValues(alpha: 0.8)];

    return GestureDetector(
      onTap: isLoading ? null : onConfirm,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
      ),
    );
  }
}
