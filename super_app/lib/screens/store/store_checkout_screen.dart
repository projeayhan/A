import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/store_cart_provider.dart';
import '../../core/providers/address_provider.dart';
import '../../core/services/store_service.dart';
import '../../core/utils/app_dialogs.dart';

class StoreColors {
  static const primary = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF4F46E5);
  static const accent = Color(0xFF8B5CF6);
  static const backgroundDark = Color(0xFF0F172A);
}

class StoreCheckoutScreen extends ConsumerStatefulWidget {
  const StoreCheckoutScreen({super.key});

  @override
  ConsumerState<StoreCheckoutScreen> createState() =>
      _StoreCheckoutScreenState();
}

class _StoreCheckoutScreenState extends ConsumerState<StoreCheckoutScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isProcessing = false;
  bool _orderComplete = false;
  String? _orderId;

  late AnimationController _progressController;
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  final List<String> _steps = [
    'Sipariş Özeti',
    'Adres Onayı',
    'Ödeme',
    'Sipariş Onayı',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _processOrder();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _processOrder() async {
    setState(() => _isProcessing = true);

    final cartState = ref.read(storeCartProvider);
    final selectedAddress = ref.read(selectedAddressProvider);

    if (selectedAddress == null) {
      setState(() => _isProcessing = false);
      if (mounted) {
        AppDialogs.showWarning(context, 'Lütfen bir adres seçin');
      }
      return;
    }

    try {
      // Her mağaza için ayrı sipariş oluştur
      final itemsByStore = cartState.itemsByStore;
      String? lastOrderId;
      bool hasError = false;
      String? errorMessage;

      for (final entry in itemsByStore.entries) {
        final storeId = entry.key;
        final storeItems = entry.value;

        // Sipariş items listesi oluştur
        final items = storeItems.map((item) => {
          'product_id': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.totalPrice,
          'image_url': item.imageUrl,
        }).toList();

        // Mağaza için ara toplam hesapla
        final storeSubtotal = storeItems.fold<double>(
          0, (sum, item) => sum + item.totalPrice);
        final deliveryFee = cartState.subtotal >= 500 ? 0.0 : cartState.deliveryFee;
        final storeTotal = storeSubtotal + (itemsByStore.length == 1 ? deliveryFee : 0);

        // Siparişi veritabanına kaydet
        try {
          final result = await StoreService.createOrder(
            merchantId: storeId,
            items: items,
            subtotal: storeSubtotal,
            deliveryFee: itemsByStore.length == 1 ? deliveryFee : 0,
            totalAmount: storeTotal,
            deliveryAddress: selectedAddress.fullAddress,
            deliveryLatitude: selectedAddress.latitude,
            deliveryLongitude: selectedAddress.longitude,
            paymentMethod: 'card',
          );

          if (result != null) {
            lastOrderId = result['order_number'] as String?;
          } else {
            hasError = true;
            errorMessage = 'Sipariş oluşturulamadı';
          }
        } catch (e) {
          hasError = true;
          errorMessage = e.toString();
        }
      }

      // Sipariş oluşturulamadıysa hata göster
      if (hasError || lastOrderId == null) {
        setState(() => _isProcessing = false);
        if (mounted) {
          AppDialogs.showError(
            context,
            errorMessage ?? 'Sipariş oluşturulamadı. Lütfen tekrar deneyin.',
          );
        }
        return;
      }

      _orderId = lastOrderId;

      setState(() {
        _isProcessing = false;
        _orderComplete = true;
      });

      _checkController.forward();
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        AppDialogs.showError(context, 'Sipariş oluşturulurken hata: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_orderComplete) {
      return _buildOrderCompleteScreen(isDark);
    }

    if (_isProcessing) {
      return _buildProcessingScreen(isDark);
    }

    return Scaffold(
      backgroundColor: isDark
          ? StoreColors.backgroundDark
          : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(isDark),
          _buildStepIndicator(isDark),
          Expanded(child: _buildStepContent(isDark)),
          _buildBottomBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? StoreColors.backgroundDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _previousStep,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : Colors.grey[700],
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sipariş Tamamla',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                Text(
                  'Adım ${_currentStep + 1}/${_steps.length}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: StoreColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 14, color: StoreColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Güvenli',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: StoreColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: List.generate(_steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Çizgi
            final stepIndex = index ~/ 2;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: stepIndex < _currentStep
                      ? StoreColors.primary
                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          } else {
            // Adım dairesi
            final stepIndex = index ~/ 2;
            final isActive = stepIndex == _currentStep;
            final isCompleted = stepIndex < _currentStep;

            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 36 : 28,
                  height: isActive ? 36 : 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? StoreColors.primary
                        : (isActive
                              ? StoreColors.primary
                              : (isDark ? Colors.grey[800] : Colors.grey[200])),
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: StoreColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${stepIndex + 1}',
                            style: TextStyle(
                              fontSize: isActive ? 14 : 12,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[stepIndex],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? StoreColors.primary
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildOrderSummaryStep(isDark);
      case 1:
        return _buildAddressStep(isDark);
      case 2:
        return _buildPaymentStep(isDark);
      case 3:
        return _buildConfirmationStep(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildOrderSummaryStep(bool isDark) {
    final cartState = ref.watch(storeCartProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sepetinizdeki Ürünler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          ...cartState.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₺${item.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      Text(
                        '${item.quantity} adet',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              children: [
                _buildPriceRow(
                  'Ara Toplam',
                  '₺${cartState.subtotal.toStringAsFixed(2)}',
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildPriceRow(
                  'Kargo',
                  '₺${cartState.deliveryFee.toStringAsFixed(2)}',
                  isDark,
                ),
                if (cartState.subtotal >= 500) ...[
                  const SizedBox(height: 8),
                  _buildPriceRow(
                    'Kargo İndirimi',
                    '-₺${cartState.deliveryFee.toStringAsFixed(2)}',
                    isDark,
                    isGreen: true,
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                _buildPriceRow(
                  'Toplam',
                  '₺${(cartState.subtotal >= 500 ? cartState.subtotal : cartState.total).toStringAsFixed(2)}',
                  isDark,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep(bool isDark) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final addresses = ref.watch(addressProvider).addresses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teslimat Adresi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Siparişinizin teslim edileceği adresi seçin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ...addresses.map((address) {
            final isSelected = selectedAddress?.id == address.id;
            return GestureDetector(
              onTap: () {
                ref.read(addressProvider.notifier).setDefaultAddress(address.id);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? StoreColors.primary
                        : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? StoreColors.primary.withValues(alpha: 0.1)
                            : (isDark ? Colors.grey[700] : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        address.type == 'home'
                            ? Icons.home
                            : (address.type == 'work'
                                  ? Icons.work
                                  : Icons.location_on),
                        color: isSelected
                            ? StoreColors.primary
                            : Colors.grey[500],
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
                                address.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey[900],
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: StoreColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Seçili',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                    Radio<bool>(
                      value: true,
                      groupValue: isSelected,
                      onChanged: (_) {
                        ref
                            .read(addressProvider.notifier)
                            .setDefaultAddress(address.id);
                      },
                      activeColor: StoreColors.primary,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/addresses'),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Adres Ekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: StoreColors.primary,
              side: const BorderSide(color: StoreColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ödeme Yöntemi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Güvenli ödeme yönteminizi seçin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          _buildPaymentOption(
            icon: Icons.credit_card,
            title: 'Kredi/Banka Kartı',
            subtitle: '**** **** **** 4242',
            isSelected: true,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildPaymentOption(
            icon: Icons.account_balance_wallet,
            title: 'Dijital Cüzdan',
            subtitle: 'Apple Pay, Google Pay',
            isSelected: false,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildPaymentOption(
            icon: Icons.payments_outlined,
            title: 'Kapıda Ödeme',
            subtitle: 'Nakit veya Kart',
            isSelected: false,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.amber[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '3D Secure ile Güvenli Ödeme',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ödemeniz SSL ile şifrelenerek korunmaktadır.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? StoreColors.primary
              : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? StoreColors.primary.withValues(alpha: 0.1)
                  : (isDark ? Colors.grey[700] : Colors.grey[100]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isSelected ? StoreColors.primary : Colors.grey[500],
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Radio<bool>(
            value: true,
            groupValue: isSelected,
            onChanged: (_) {},
            activeColor: StoreColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep(bool isDark) {
    final cartState = ref.watch(storeCartProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sipariş Özeti',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen siparişinizi kontrol edin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          // Teslimat Bilgileri
          _buildConfirmationSection(
            icon: Icons.location_on,
            title: 'Teslimat Adresi',
            content: selectedAddress?.fullAddress ?? 'Adres seçilmedi',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildConfirmationSection(
            icon: Icons.credit_card,
            title: 'Ödeme Yöntemi',
            content: 'Kredi Kartı (**** 4242)',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildConfirmationSection(
            icon: Icons.local_shipping,
            title: 'Tahmini Teslimat',
            content: '2-3 İş Günü',
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ürünler (${cartState.itemCount})',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    Text(
                      '₺${cartState.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kargo',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    Text(
                      cartState.subtotal >= 500
                          ? 'Ücretsiz'
                          : '₺${cartState.deliveryFee.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: cartState.subtotal >= 500
                            ? Colors.green
                            : (isDark ? Colors.white : Colors.grey[900]),
                        fontWeight: cartState.subtotal >= 500
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                    ),
                    Text(
                      '₺${(cartState.subtotal >= 500 ? cartState.subtotal : cartState.total).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: StoreColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Siparişi onayladığınızda ödeme işlemi başlayacaktır.',
                    style: TextStyle(fontSize: 13, color: Colors.green[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationSection({
    required IconData icon,
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
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
            child: Icon(icon, color: StoreColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value,
    bool isDark, {
    bool isBold = false,
    bool isGreen = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isGreen
                ? Colors.green
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isGreen
                ? Colors.green
                : (isDark ? Colors.white : Colors.grey[900]),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final cartState = ref.watch(storeCartProvider);
    final total = cartState.subtotal >= 500
        ? cartState.subtotal
        : cartState.total;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Toplam',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  '₺${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _nextStep,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [StoreColors.primary, StoreColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: StoreColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _currentStep == _steps.length - 1
                        ? 'Siparişi Onayla'
                        : 'Devam Et',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark
          ? StoreColors.backgroundDark
          : const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation(StoreColors.primary),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Siparişiniz İşleniyor...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lütfen bekleyin, ödemeniz onaylanıyor',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            _buildProcessingStep(
              'Sipariş bilgileri kontrol ediliyor...',
              true,
              isDark,
            ),
            _buildProcessingStep(
              'Ödeme işlemi gerçekleştiriliyor...',
              true,
              isDark,
            ),
            _buildProcessingStep('Sipariş oluşturuluyor...', false, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingStep(String text, bool completed, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        children: [
          completed
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(StoreColors.primary),
                  ),
                ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCompleteScreen(bool isDark) {
    final cartState = ref.read(storeCartProvider);

    return Scaffold(
      backgroundColor: isDark
          ? StoreColors.backgroundDark
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _checkAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Siparişiniz Alındı!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sipariş numaranız:',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: StoreColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _orderId ?? '',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: StoreColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping,
                            color: Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tahmini Teslimat: 2-3 İş Günü',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Siparişiniz hazırlandığında ve kargoya verildiğinde\nsize bildirim göndereceğiz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(storeCartProvider.notifier).clearCart();
                      context.go('/');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StoreColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Ana Sayfaya Dön',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(storeCartProvider.notifier).clearCart();
                      context.go('/market');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: StoreColors.primary,
                      side: const BorderSide(color: StoreColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Alışverişe Devam Et',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
