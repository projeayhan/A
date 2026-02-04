import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/utils/app_dialogs.dart';
import 'food_home_screen.dart';
import '../../core/providers/address_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/restaurant_service.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  int _selectedPaymentMethod = 0; // 0: Credit Card, 1: Cash
  bool _isPlacingOrder = false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _loadingSuggestions = false;
  String? _lastRestaurantId;

  double get _discount => 0.0;

  @override
  void initState() {
    super.initState();
    // Load suggestions after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSuggestions();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload suggestions if merchant changed
    final cartState = ref.read(cartProvider);
    final currentMerchantId = cartState.items.isNotEmpty
        ? cartState.items.first.merchantId
        : null;
    if (currentMerchantId != _lastRestaurantId) {
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    final cartState = ref.read(cartProvider);
    if (cartState.items.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    // Get merchant ID from first cart item
    final merchantId = cartState.items.first.merchantId;
    if (merchantId == null) return;

    // Skip if same merchant and we already have suggestions
    if (merchantId == _lastRestaurantId && _suggestions.isNotEmpty) return;

    setState(() {
      _loadingSuggestions = true;
      _lastRestaurantId = merchantId;
    });

    try {
      // Get cart item IDs to exclude
      final cartItemIds = cartState.items.map((item) => item.id).toSet();

      // Fetch menu items from the same restaurant
      debugPrint('Loading suggestions for merchant: $merchantId');
      final menuItems = await RestaurantService.getMenuItems(merchantId);
      debugPrint('Found ${menuItems.length} menu items');

      // Filter: exclude items already in cart, prioritize add-ons/sides/drinks
      final suggestions = <Map<String, dynamic>>[];
      final addOnCategories = ['İçecekler', 'Tatlılar', 'Yan Ürünler', 'Soslar', 'Ekstralar'];

      for (final item in menuItems) {
        if (cartItemIds.contains(item.id)) continue;
        if (suggestions.length >= 6) break;

        final categoryName = item.category ?? '';
        final isAddOn = addOnCategories.any((c) => categoryName.toLowerCase().contains(c.toLowerCase()));

        // Prioritize add-ons, but also include other items
        if (isAddOn || suggestions.length < 4) {
          suggestions.add({
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'imageUrl': item.imageUrl ?? '',
            'description': item.description ?? '',
          });
        }
      }

      debugPrint('Filtered to ${suggestions.length} suggestions');
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _loadingSuggestions = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
      if (mounted) {
        setState(() => _loadingSuggestions = false);
      }
    }
  }

  void _clearCart() {
    ref.read(cartProvider.notifier).clearCart();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartState = ref.watch(cartProvider);
    final cartItems = cartState.items;

    return Scaffold(
      backgroundColor: isDark ? FoodColors.backgroundDark : const Color(0xFFF8F9FA),
      body: Column(
        children: [
          // Header
          _buildHeader(isDark, cartItems),

          // Content
          Expanded(
            child: cartItems.isEmpty
                ? _buildEmptyCart(isDark)
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(context.pagePaddingH, 24, context.pagePaddingH, 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Delivery Info Banner
                        _buildDeliveryBanner(isDark, cartState),

                        const SizedBox(height: 16),

                        // Delivery Address
                        _buildDeliveryAddress(isDark),

                        const SizedBox(height: 24),

                        // Cart Items
                        ...cartItems.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildCartItemWidget(entry.value, isDark),
                          );
                        }),

                        const SizedBox(height: 16),

                        // Suggestions
                        _buildSuggestions(isDark),

                        const SizedBox(height: 24),

                        // Payment Method
                        _buildPaymentSection(isDark),

                        const SizedBox(height: 24),

                        // Order Summary
                        _buildOrderSummary(isDark, cartState),
                      ],
                    ),
                  ),
          ),

          // Bottom Navigation
          _buildBottomNav(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, List<CartItem> cartItems) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? FoodColors.backgroundDark.withValues(alpha: 0.95)
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
            'Sepetim (${cartItems.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          GestureDetector(
            onTap: cartItems.isNotEmpty ? _clearCart : null,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: cartItems.isNotEmpty ? Colors.red[500] : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'Temizle',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cartItems.isNotEmpty ? Colors.red[500] : Colors.grey[400],
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
            'Lezzetli yemekler keşfetmeye başlayın',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodColors.primary,
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

  Widget _buildDeliveryAddress(bool isDark) {
    final selectedAddress = ref.watch(selectedAddressProvider);

    String addressTitle = selectedAddress?.title ?? 'Adres Seç';
    String addressLine1 = selectedAddress?.fullAddress ?? 'Teslimat adresi seçin';
    String addressLine2 = selectedAddress?.shortAddress ?? '';
    String addressType = selectedAddress?.type ?? 'other';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF7C2D12).withValues(alpha: 0.2)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on,
              color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF166534).withValues(alpha: 0.3)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        addressType == 'home' ? 'Ev' : (addressType == 'work' ? 'İş' : addressTitle),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
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
                    child: const Text('Yeni Ekle', style: TextStyle(color: FoodColors.primary)),
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
                    ref.read(addressProvider.notifier).setDefaultAddress(address.id);
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? FoodColors.primary.withValues(alpha: 0.1)
                          : (isDark ? Colors.grey[800] : Colors.grey[50]),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: FoodColors.primary, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: FoodColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            address.type == 'home'
                                ? Icons.home
                                : (address.type == 'work' ? Icons.work : Icons.location_on),
                            color: FoodColors.primary,
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
                                  color: isDark ? Colors.white : Colors.grey[900],
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
                          const Icon(Icons.check_circle, color: FoodColors.primary),
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

  Widget _buildDeliveryBanner(bool isDark, CartState cartState) {
    final merchantName = cartState.merchantName ?? 'Restoran';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7C2D12).withValues(alpha: 0.1)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
              : const Color(0xFFFFEDD5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
                  : const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.moped,
              color: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tahmini Teslimat: 25-35 dk',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[100] : Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Siparişiniz $merchantName\'dan hazırlanacaktır.',
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

  Widget _buildCartItemWidget(CartItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              height: 96,
              color: isDark ? Colors.grey[700] : Colors.grey[100],
              child: item.imageUrl.isNotEmpty
                  ? Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.fastfood,
                          size: 32,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        );
                      },
                    )
                  : Icon(
                      Icons.fastfood,
                      size: 32,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[900],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(cartProvider.notifier).removeItem(item.id),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.extra != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF7C2D12).withValues(alpha: 0.2)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.extra!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: FoodColors.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.price.toStringAsFixed(2)} TL',
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

  Widget _buildQuantityStepper(CartItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(cartProvider.notifier).decrementQuantity(item.id),
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
            onTap: () => ref.read(cartProvider.notifier).incrementQuantity(item.id),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: FoodColors.primary,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: FoodColors.primary.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSuggestionToCart(Map<String, dynamic> suggestion) {
    final cartState = ref.read(cartProvider);

    // Get merchant info from existing cart items
    final merchantId = cartState.items.isNotEmpty ? cartState.items.first.merchantId : null;
    final merchantName = cartState.items.isNotEmpty ? cartState.items.first.merchantName : null;

    final cartItem = CartItem(
      id: suggestion['id'] as String,
      name: suggestion['name'] as String,
      description: suggestion['description'] as String?,
      price: suggestion['price'] as double,
      quantity: 1,
      imageUrl: suggestion['imageUrl'] as String? ?? '',
      merchantId: merchantId,
      merchantName: merchantName,
      type: 'food',
    );

    ref.read(cartProvider.notifier).addItem(cartItem);

    // Remove from suggestions list after adding
    setState(() {
      _suggestions.removeWhere((s) => s['id'] == suggestion['id']);
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${suggestion['name']} sepete eklendi'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSuggestions(bool isDark) {
    // Don't show section if loading or no suggestions
    if (_loadingSuggestions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bunları da eklemek ister misin?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bunları da eklemek ister misin?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[200] : Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final suggestion = _suggestions[index];
              return Container(
                width: 128,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]!.withValues(alpha: 0.5) : Colors.grey[100]!,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 64,
                        color: isDark ? Colors.grey[700] : Colors.grey[100],
                        child: Image.network(
                          suggestion['imageUrl'] ?? '',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.fastfood,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      suggestion['name'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey[900],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${((suggestion['price'] as double?) ?? 0).toInt()} TL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _addSuggestionToCart(suggestion),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: FoodColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
                  color: FoodColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Credit Card Option
        _buildPaymentOption(
          index: 0,
          icon: Icons.credit_card,
          title: 'Kredi Kartı',
          subtitle: 'Mastercard •••• 4242',
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Cash Option
        _buildPaymentOption(
          index: 1,
          icon: Icons.payments_outlined,
          title: 'Kapıda Ödeme',
          subtitle: 'Nakit veya Kart',
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Add New Payment Method
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                style: BorderStyle.solid,
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
                ? FoodColors.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[100]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: FoodColors.primary.withValues(alpha: 0.1),
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
                        ? const Color(0xFF7C2D12).withValues(alpha: 0.2)
                        : const Color(0xFFFFF7ED))
                    : (isDark ? Colors.grey[700] : Colors.grey[50]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? FoodColors.primary
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
                  color: isSelected ? FoodColors.primary : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: FoodColors.primary,
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

  Widget _buildOrderSummary(bool isDark, CartState cartState) {
    final subtotal = cartState.subtotal;
    final deliveryFee = cartState.deliveryFee;
    final total = subtotal + deliveryFee - _discount;

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
          _buildSummaryRow('Ara Toplam', '${subtotal.toStringAsFixed(2)} TL', isDark),
          const SizedBox(height: 12),
          _buildSummaryRow('Teslimat Ücreti', '${deliveryFee.toStringAsFixed(2)} TL', isDark),
          if (_discount > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              'İndirim',
              '-${_discount.toStringAsFixed(2)} TL',
              isDark,
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 12),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${total.toStringAsFixed(2)} TL',
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

          // Confirm Button
          GestureDetector(
            onTap: () => _placeOrder(cartState, total),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FoodColors.primary, Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: FoodColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isPlacingOrder
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Siparişi Onayla',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.check_circle,
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

  Future<void> _placeOrder(CartState cartState, double total) async {
    if (_isPlacingOrder) return;

    final selectedAddress = ref.read(selectedAddressProvider);
    if (selectedAddress == null) {
      await AppDialogs.showWarning(context, 'Lütfen teslimat adresi seçin');
      return;
    }

    if (cartState.merchantId == null) {
      await AppDialogs.showWarning(context, 'Sepet bilgisi eksik');
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      // Convert cart items to order items format
      final orderItems = cartState.items.map((item) => {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.totalPrice,
        'image_url': item.imageUrl,
      }).toList();

      // Create order in Supabase
      final orderId = await RestaurantService.createOrder(
        merchantId: cartState.merchantId!,
        items: orderItems,
        subtotal: cartState.subtotal,
        deliveryFee: cartState.deliveryFee,
        totalAmount: total,
        deliveryAddress: selectedAddress.fullAddress,
        deliveryLatitude: selectedAddress.latitude,
        deliveryLongitude: selectedAddress.longitude,
        paymentMethod: 'cash', // TODO: ödeme yöntemi seçimi eklenecek
      );

      if (orderId != null) {
        // Clear cart after successful order
        ref.read(cartProvider.notifier).clearCart();

        // Navigate to success screen
        if (mounted) {
          context.go(
            '/food/order-success/$orderId',
            extra: {'totalAmount': total},
          );
        }
      } else {
        throw Exception('Sipariş oluşturulamadı');
      }
    } catch (e) {
      if (mounted) {
        await AppDialogs.showError(context, 'Sipariş hatası: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  Widget _buildSummaryRow(String label, String value, bool isDark, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDiscount ? FoodColors.primary : (isDark ? Colors.grey[400] : Colors.grey[500]),
            fontWeight: isDiscount ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDiscount ? FoodColors.primary : (isDark ? Colors.white : Colors.grey[900]),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A202C).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: context.bottomNavPadding,
        top: 8,
        left: context.pagePaddingH,
        right: context.pagePaddingH,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'Ana Sayfa', false, isDark, '/'),
          _buildNavItem(Icons.favorite, 'Favoriler', false, isDark, '/favorites'),
          _buildNavItem(Icons.receipt_long, 'Siparişlerim', false, isDark, '/orders'),
          _buildNavItem(Icons.person, 'Profil', false, isDark, '/profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, bool isDark, String route) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.go(route),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? FoodColors.primary
                  : (isDark ? Colors.grey[500] : Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? FoodColors.primary
                    : (isDark ? Colors.grey[500] : Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
