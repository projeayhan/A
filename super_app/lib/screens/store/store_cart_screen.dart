import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/store_cart_provider.dart';
import '../../core/providers/address_provider.dart';

class StoreColors {
  static const primary = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF4F46E5);
  static const accent = Color(0xFF8B5CF6);
  static const backgroundDark = Color(0xFF0F172A);
}

class StoreCartScreen extends ConsumerStatefulWidget {
  const StoreCartScreen({super.key});

  @override
  ConsumerState<StoreCartScreen> createState() => _StoreCartScreenState();
}

class _StoreCartScreenState extends ConsumerState<StoreCartScreen> {
  int _selectedPaymentMethod = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartState = ref.watch(storeCartProvider);

    return Scaffold(
      backgroundColor: isDark
          ? StoreColors.backgroundDark
          : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(isDark, cartState),
          Expanded(
            child: cartState.isEmpty
                ? _buildEmptyCart(isDark)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDeliveryBanner(isDark),
                        const SizedBox(height: 16),
                        _buildDeliveryAddress(isDark),
                        const SizedBox(height: 24),
                        ...cartState.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildCartItem(item, isDark),
                          );
                        }),
                        const SizedBox(height: 24),
                        _buildPaymentSection(isDark),
                        const SizedBox(height: 24),
                        _buildOrderSummary(isDark, cartState),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, StoreCartState cartState) {
    final cartNotifier = ref.read(storeCartProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? StoreColors.backgroundDark.withValues(alpha: 0.95)
            : const Color(0xFFF8F9FA).withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
          ),
          Text(
            'Sepetim (${cartState.itemCount})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          GestureDetector(
            onTap: cartState.isNotEmpty
                ? () {
                    cartNotifier.clearCart();
                  }
                : null,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: cartState.isNotEmpty
                      ? Colors.red[500]
                      : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'Temizle',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cartState.isNotEmpty
                        ? Colors.red[500]
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Sepetiniz Boş',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Harika ürünler keşfetmeye başlayın',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: StoreColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Alışverişe Başla',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? StoreColors.primary.withValues(alpha: 0.1)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? StoreColors.primary.withValues(alpha: 0.3)
              : const Color(0xFFC7D2FE),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? StoreColors.primary.withValues(alpha: 0.3)
                  : const Color(0xFFC7D2FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              color: isDark ? StoreColors.primary : StoreColors.primaryDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tahmini Teslimat: 2-3 İş Günü',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[100] : Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Siparişiniz kargoya verildiğinde bildirim alacaksınız.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddress(bool isDark) {
    final selectedAddress = ref.watch(selectedAddressProvider);

    String addressTitle = selectedAddress?.title ?? 'Adres Seç';
    String addressLine1 =
        selectedAddress?.fullAddress ?? 'Teslimat adresi seçin';
    String addressLine2 = selectedAddress?.shortAddress ?? '';
    String addressType = selectedAddress?.type ?? 'other';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? StoreColors.primary.withValues(alpha: 0.2)
                  : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on,
              color: isDark ? StoreColors.primary : StoreColors.primaryDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Teslimat Adresi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF166534).withValues(alpha: 0.3)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        addressType == 'home'
                            ? 'Ev'
                            : (addressType == 'work' ? 'İş' : addressTitle),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  addressLine1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  addressLine2,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showAddressSelector(isDark),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_outlined,
                size: 20,
                color: isDark ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddressSelector(bool isDark) {
    final addresses = ref.read(addressProvider).addresses;
    final selectedAddress = ref.read(selectedAddressProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Teslimat Adresi Seç',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/settings/addresses');
                    },
                    child: const Text(
                      'Yeni Ekle',
                      style: TextStyle(color: StoreColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final address = addresses[index];
                final isSelected = selectedAddress?.id == address.id;

                return InkWell(
                  onTap: () {
                    ref
                        .read(addressProvider.notifier)
                        .setDefaultAddress(address.id);
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? StoreColors.primary.withValues(alpha: 0.1)
                          : (isDark ? Colors.grey[800] : Colors.grey[50]),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: StoreColors.primary, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: StoreColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            address.type == 'home'
                                ? Icons.home
                                : (address.type == 'work'
                                      ? Icons.work
                                      : Icons.location_on),
                            color: StoreColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                address.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey[900],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                address.fullAddress,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: StoreColors.primary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(StoreCartItem item, bool isDark) {
    final cartNotifier = ref.read(storeCartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              height: 96,
              color: isDark ? Colors.grey[700] : Colors.grey[100],
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.shopping_bag,
                    size: 32,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey[900],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.storeName,
                            style: TextStyle(
                              fontSize: 12,
                              color: StoreColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => cartNotifier.removeItem(item.id),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₺${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    _buildQuantityStepper(item, isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStepper(StoreCartItem item, bool isDark) {
    final cartNotifier = ref.read(storeCartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => cartNotifier.decrementQuantity(item.id),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.remove,
                size: 16,
                color: isDark ? Colors.grey[200] : Colors.grey[600],
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                item.quantity.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => cartNotifier.incrementQuantity(item.id),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: StoreColors.primary,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: StoreColors.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ödeme Yöntemi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Tümünü Gör',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: StoreColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          index: 0,
          icon: Icons.credit_card,
          title: 'Kredi Kartı',
          subtitle: 'Mastercard •••• 4242',
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          index: 1,
          icon: Icons.payments_outlined,
          title: 'Kapıda Ödeme',
          subtitle: 'Nakit veya Kart',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final isSelected = _selectedPaymentMethod == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? StoreColors.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[100]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: StoreColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? StoreColors.primary.withValues(alpha: 0.2)
                          : const Color(0xFFEEF2FF))
                    : (isDark ? Colors.grey[700] : Colors.grey[50]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? StoreColors.primary
                    : (isDark ? Colors.grey[400] : Colors.grey[500]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? StoreColors.primary : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: StoreColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(bool isDark, StoreCartState cartState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!.withValues(alpha: 0.5)
              : Colors.grey[100]!,
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
          _buildSummaryRow(
            'Ara Toplam',
            '₺${cartState.subtotal.toStringAsFixed(2)}',
            isDark,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Kargo Ücreti',
            '₺${cartState.deliveryFee.toStringAsFixed(2)}',
            isDark,
          ),
          const SizedBox(height: 12),
          if (cartState.subtotal >= 500)
            _buildSummaryRow(
              'Ücretsiz Kargo',
              '-₺${cartState.deliveryFee.toStringAsFixed(2)}',
              isDark,
              isDiscount: true,
            ),
          Container(
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
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toplam Ödenecek Tutar',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₺${(cartState.subtotal >= 500 ? cartState.subtotal : cartState.total).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              context.push('/store/checkout');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [StoreColors.primary, StoreColors.accent],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: StoreColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Siparişi Tamamla',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    bool isDark, {
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDiscount
                ? Colors.green
                : (isDark ? Colors.grey[400] : Colors.grey[500]),
            fontWeight: isDiscount ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDiscount
                ? Colors.green
                : (isDark ? Colors.white : Colors.grey[900]),
          ),
        ),
      ],
    );
  }
}
