import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/store_cart_provider.dart';
import '../../core/providers/address_provider.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/store_colors.dart';
import '../../widgets/common/common_widgets.dart';
import '../../core/services/delivery_service.dart';

class StoreCartScreen extends ConsumerStatefulWidget {
  const StoreCartScreen({super.key});

  @override
  ConsumerState<StoreCartScreen> createState() => _StoreCartScreenState();
}

class _StoreCartScreenState extends ConsumerState<StoreCartScreen> {
  int _selectedPaymentMethod = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDeliveryFee();
    });
  }

  void _calculateDeliveryFee() {
    final selectedAddress = ref.read(selectedAddressProvider);
    final cartState = ref.read(storeCartProvider);
    if (selectedAddress == null || cartState.items.isEmpty) return;
    if (selectedAddress.latitude == null || selectedAddress.longitude == null) return;

    // Use first store's ID for estimation
    final firstStoreId = cartState.items.first.storeId;
    ref.read(storeCartProvider.notifier).calculateDeliveryFee(
      storeId: firstStoreId,
      customerLat: selectedAddress.latitude!,
      customerLon: selectedAddress.longitude!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartState = ref.watch(storeCartProvider);

    return Scaffold(
      backgroundColor: isDark
          ? StoreColors.backgroundDark
          : StoreColors.backgroundLight,
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
            : StoreColors.backgroundLight.withValues(alpha: 0.95),
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
              fontSize: context.heading2Size,
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
                    fontSize: context.bodySize,
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
              fontSize: context.heading1Size,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Harika ürünler keşfetmeye başlayın',
            style: TextStyle(
              fontSize: context.bodySize,
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
            child: Text(
              'Alışverişe Başla',
              style: TextStyle(
                fontSize: context.heading2Size,
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
    final cartState = ref.watch(storeCartProvider);
    final hasEstimate = cartState.estimatedDeliveryMin != null;
    final estimateText = hasEstimate
        ? '~${cartState.estimatedDeliveryMin} dk'
        : '2-3 İş Günü';
    final distanceText = cartState.deliveryDistanceKm != null
        ? '${cartState.deliveryDistanceKm!.toStringAsFixed(1)} km'
        : null;

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
                  'Tahmini Teslimat: $estimateText',
                  style: TextStyle(
                    fontSize: context.bodySize,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[100] : Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  distanceText != null
                      ? '$distanceText • Siparişiniz hazırlandığında bildirim alacaksınız.'
                      : 'Siparişiniz kargoya verildiğinde bildirim alacaksınız.',
                  style: TextStyle(
                    fontSize: context.captionSize,
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
                        fontSize: context.captionSize,
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
                          fontSize: context.captionSmallSize,
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
                    fontSize: context.bodySize,
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
                    fontSize: context.captionSize,
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
                      fontSize: context.heading2Size,
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
                    Future.microtask(() => _calculateDeliveryFee());
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
                                  fontSize: context.bodySize,
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
                                  fontSize: context.bodySmallSize,
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
              child: CachedNetworkImage(
                imageUrl: item.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, error, stackTrace) {
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
                              fontSize: context.bodySize,
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
                              fontSize: context.captionSize,
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
                        fontSize: context.heading2Size,
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

    return QuantityStepper(
      quantity: item.quantity,
      onDecrement: () => cartNotifier.decrementQuantity(item.id),
      onIncrement: () => cartNotifier.incrementQuantity(item.id),
      primaryColor: StoreColors.primary,
      isDark: isDark,
    );
  }

  Widget _buildPaymentSection(bool isDark) {
    return PaymentMethodSelector(
      selectedIndex: _selectedPaymentMethod,
      onChanged: (index) => setState(() => _selectedPaymentMethod = index),
      primaryColor: StoreColors.primary,
      isDark: isDark,
      onViewAll: () {},
      showAddNew: false,
    );
  }

  Widget _buildOrderSummary(bool isDark, StoreCartState cartState) {
    final isFreeShipping = cartState.subtotal >= 500;
    final total = isFreeShipping ? cartState.subtotal : cartState.total;

    return OrderSummaryWidget(
      subtotal: cartState.subtotal,
      deliveryFee: cartState.deliveryFee,
      total: total,
      primaryColor: StoreColors.primary,
      gradientColors: const [StoreColors.primary, StoreColors.accent],
      isDark: isDark,
      showFreeShippingNote: true,
      freeShippingThreshold: 500,
      buttonText: 'Siparişi Tamamla',
      onConfirm: () => context.push('/store/checkout'),
      customButton: _buildCheckoutButton(),
      currencyPrefix: '₺',
      currencySuffix: '',
    );
  }

  Widget _buildCheckoutButton() {
    return GestureDetector(
      onTap: () => context.push('/store/checkout'),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Siparişi Tamamla',
              style: TextStyle(
                fontSize: context.heading2Size,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
