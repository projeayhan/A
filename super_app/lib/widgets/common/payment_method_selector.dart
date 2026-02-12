import 'package:flutter/material.dart';

/// Payment method option model
class PaymentOption {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  /// Backend value: 'card', 'cash', 'wallet', 'credit_card_on_delivery'
  final String paymentMethodKey;

  const PaymentOption({
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.paymentMethodKey,
  });
}

/// Common payment options
class PaymentOptions {
  static const creditCard = PaymentOption(
    index: 0,
    icon: Icons.credit_card,
    title: 'Kredi Kartı',
    subtitle: 'Kapıda Kredi Kartı',
    paymentMethodKey: 'credit_card_on_delivery',
  );

  static const cashOnDelivery = PaymentOption(
    index: 1,
    icon: Icons.payments_outlined,
    title: 'Nakit',
    subtitle: 'Kapıda Nakit Ödeme',
    paymentMethodKey: 'cash',
  );

  static List<PaymentOption> get defaultOptions => [creditCard, cashOnDelivery];

  // Store options with sequential indexes for proper selection
  static List<PaymentOption> get storeOptions => [
    const PaymentOption(
      index: 0,
      icon: Icons.credit_card,
      title: 'Kredi/Banka Kartı',
      subtitle: 'Kapıda Kredi Kartı',
      paymentMethodKey: 'credit_card_on_delivery',
    ),
    const PaymentOption(
      index: 1,
      icon: Icons.payments_outlined,
      title: 'Kapıda Ödeme',
      subtitle: 'Nakit Ödeme',
      paymentMethodKey: 'cash',
    ),
  ];

  /// Resolves the paymentMethodKey for a given index from a list of options.
  static String resolvePaymentMethod(List<PaymentOption> options, int selectedIndex) {
    final match = options.where((o) => o.index == selectedIndex);
    if (match.isNotEmpty) return match.first.paymentMethodKey;
    return options.first.paymentMethodKey;
  }
}

/// Reusable payment method selector widget.
/// Used in cart and checkout screens for both food and store modules.
class PaymentMethodSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<PaymentOption> options;
  final Color primaryColor;
  final bool isDark;
  final String title;
  final VoidCallback? onViewAll;
  final VoidCallback? onAddNew;
  final bool showAddNew;

  const PaymentMethodSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.primaryColor,
    this.options = const [],
    this.isDark = false,
    this.title = 'Ödeme Yöntemi',
    this.onViewAll,
    this.onAddNew,
    this.showAddNew = true,
  });

  @override
  Widget build(BuildContext context) {
    final paymentOptions = options.isEmpty ? PaymentOptions.defaultOptions : options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...paymentOptions.map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PaymentOptionTile(
                option: option,
                isSelected: selectedIndex == option.index,
                onTap: () => onChanged(option.index),
                primaryColor: primaryColor,
                isDark: isDark,
              ),
            )),
        if (showAddNew) _buildAddNewButton(),
      ],
    );
  }

  Widget _buildAddNewButton() {
    return GestureDetector(
      onTap: onAddNew,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 16,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Yeni Ödeme Yöntemi Ekle',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final PaymentOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final bool isDark;

  const _PaymentOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? Colors.grey[700]! : Colors.grey[100]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(child: _buildContent()),
            _buildRadio(),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? primaryColor.withValues(alpha: 0.2)
                : primaryColor.withValues(alpha: 0.1))
            : (isDark ? Colors.grey[700] : Colors.grey[50]),
        shape: BoxShape.circle,
      ),
      child: Icon(
        option.icon,
        color: isSelected ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey[500]),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
        Text(
          option.subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildRadio() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? primaryColor : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
