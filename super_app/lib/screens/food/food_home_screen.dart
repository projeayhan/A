import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/address_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/restaurant_provider.dart';
import '../../core/services/restaurant_service.dart';
import '../../core/theme/app_responsive.dart';
import '../../widgets/food/food_banner_carousel.dart';
import '../../widgets/food/restaurant_card.dart';

// Search data models - veriler Supabase'den yüklenir
class SearchableFood {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final double rating;
  final String restaurantId;
  final String restaurantName;

  const SearchableFood({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.restaurantId,
    required this.restaurantName,
  });
}

class SearchableRestaurant {
  final String id;
  final String name;
  final String categories;
  final double rating;
  final String deliveryTime;
  final String imageUrl;

  const SearchableRestaurant({
    required this.id,
    required this.name,
    required this.categories,
    required this.rating,
    required this.deliveryTime,
    required this.imageUrl,
  });
}

// Food theme colors
class FoodColors {
  static const Color primary = Color(0xFFEC6D13);
  static const Color primaryDark = Color(0xFFD35400);
  static const Color backgroundLight = Color(0xFFF8F7F6);
  static const Color backgroundDark = Color(0xFF221810);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D241E);
}

class FoodHomeScreen extends ConsumerStatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  ConsumerState<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends ConsumerState<FoodHomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final LayerLink _notificationLayerLink = LayerLink();
  final LayerLink _addressLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _notificationOverlayEntry;
  OverlayEntry? _addressOverlayEntry;

  String _searchQuery = '';
  List<SearchableFood> _foodResults = [];
  List<SearchableRestaurant> _restaurantResults = [];
  Timer? _searchDebounceTimer;
  bool _isSearching = false;
  String? _selectedCategory; // null = Tümü

  // Filter states
  String _selectedSorting = 'Önerilen';
  double? _minRating;
  final bool _showFiltersPanel = false;

  // Address dropdown state
  bool _showAddressDropdown = false;

  // Notification dropdown state
  bool _showNotificationDropdown = false;

  // Cart state removed - using cartItemCountProvider instead

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    // Remove overlays directly without setState
    _overlayEntry?.remove();
    _overlayEntry = null;
    _notificationOverlayEntry?.remove();
    _notificationOverlayEntry = null;
    _addressOverlayEntry?.remove();
    _addressOverlayEntry = null;
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Advanced Filters Dialog
  void _showAdvancedFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtreler',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedSorting = 'Önerilen';
                        _minRating = null;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Temizle',
                      style: TextStyle(color: FoodColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sorting Section
                    Text(
                      'Sıralama',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ['Önerilen', 'Puana Göre', 'En Yakın', 'En Hızlı']
                              .map(
                                (option) => _buildFilterOption(
                                  option,
                                  _selectedSorting == option,
                                  isDark,
                                  () =>
                                      setState(() => _selectedSorting = option),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 24),

                    // Rating Section
                    Text(
                      'Minimum Puan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [4.5, 4.0, 3.5, 3.0]
                          .map(
                            (rating) => _buildRatingOption(
                              rating,
                              _minRating == rating,
                              isDark,
                              () => setState(() {
                                if (_minRating == rating) {
                                  _minRating = null;
                                } else {
                                  _minRating = rating;
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Apply Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: FoodColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Uygula',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(
    String label,
    bool isSelected,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? FoodColors.primary
              : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? FoodColors.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : Colors.black),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRatingOption(
    double rating,
    bool isSelected,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? FoodColors.primary
              : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? FoodColors.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 16,
              color: isSelected ? Colors.white : Colors.amber,
            ),
            const SizedBox(width: 4),
            Text(
              '$rating+',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Notification Overlay Methods
  void _showNotificationOverlay() {
    _removeNotificationOverlay();
    _removeAddressOverlay();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dropdownWidth = (screenWidth - 32).clamp(0.0, 380.0);
    // Position: align right edge of dropdown with the bell icon
    final offsetX = -(dropdownWidth - 40);

    _notificationOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeNotificationOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: dropdownWidth,
            child: CompositedTransformFollower(
              link: _notificationLayerLink,
              showWhenUnlinked: false,
              offset: Offset(offsetX, 45),
              child: Material(
                color: Colors.transparent,
                child: _buildNotificationOverlayContent(isDark),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_notificationOverlayEntry!);
    setState(() => _showNotificationDropdown = true);
  }

  void _removeNotificationOverlay() {
    _notificationOverlayEntry?.remove();
    _notificationOverlayEntry = null;
    _showNotificationDropdown = false;
  }

  IconData _getNotificationIcon(String iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'local_taxi': return Icons.local_taxi;
      case 'directions_car': return Icons.directions_car;
      case 'work': return Icons.work;
      case 'home': return Icons.home;
      case 'celebration': return Icons.celebration;
      case 'delivery_dining': return Icons.delivery_dining;
      case 'star': return Icons.star;
      default: return Icons.notifications;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Widget _buildNotificationOverlayContent(bool isDark) {
    final notifState = ref.read(notificationProvider);
    final notifications = notifState.notifications.take(5).toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bildirimler',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                if (notifState.unreadCount > 0)
                  GestureDetector(
                    onTap: () {
                      ref.read(notificationProvider.notifier).markAllAsRead();
                      _removeNotificationOverlay();
                      _showNotificationOverlay();
                    },
                    child: const Text(
                      'Tümünü Okundu İşaretle',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: FoodColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Notifications list or empty state
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Henüz bildiriminiz yok',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final notifColor = Color(notification.colorValue);

                  return InkWell(
                    onTap: () {
                      if (!notification.isRead) {
                        ref.read(notificationProvider.notifier).markAsRead(notification.id);
                      }
                      _removeNotificationOverlay();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? null
                            : FoodColors.primary.withValues(alpha: 0.05),
                        border: index < notifications.length - 1
                            ? Border(
                                bottom: BorderSide(
                                  color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: notifColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.iconName),
                              color: notifColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: notification.isRead
                                              ? FontWeight.w500
                                              : FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.grey[900],
                                        ),
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: FoodColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.body,
                                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _getTimeAgo(notification.createdAt),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          // See all button
          InkWell(
            onTap: () {
              _removeNotificationOverlay();
              context.push('/notifications');
            },
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  ),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tüm Bildirimleri Gör',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: FoodColors.primary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: FoodColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Address Overlay Methods
  void _showAddressOverlay() {
    _removeAddressOverlay();
    _removeNotificationOverlay();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _addressOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Tap outside to close
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeAddressOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown
          Positioned(
            width: MediaQuery.of(context).size.width - 32,
            child: CompositedTransformFollower(
              link: _addressLayerLink,
              showWhenUnlinked: false,
              offset: const Offset(-16, 45),
              child: Material(
                color: Colors.transparent,
                child: _buildAddressOverlayContent(isDark),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_addressOverlayEntry!);
    setState(() => _showAddressDropdown = true);
  }

  void _removeAddressOverlay() {
    _addressOverlayEntry?.remove();
    _addressOverlayEntry = null;
    if (mounted) setState(() => _showAddressDropdown = false);
  }

  Widget _buildAddressOverlayContent(bool isDark) {
    final addressState = ref.read(addressProvider);
    final addresses = addressState.addresses;
    final selectedAddress = addressState.selectedAddress;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...addresses.asMap().entries.map((entry) {
            final index = entry.key;
            final address = entry.value;
            final isSelected = selectedAddress?.id == address.id;

            return InkWell(
              onTap: () {
                ref.read(addressProvider.notifier).setDefaultAddress(address.id);
                _removeAddressOverlay();
              },
              borderRadius: BorderRadius.vertical(
                top: index == 0 ? const Radius.circular(16) : Radius.zero,
                bottom: index == addresses.length - 1
                    ? Radius.zero
                    : Radius.zero,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FoodColors.primary.withValues(alpha: 0.1)
                      : null,
                  border: index < addresses.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey[100]!,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FoodColors.primary
                            : (isDark ? Colors.grey[800] : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        address.icon,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
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
                              color: isSelected
                                  ? FoodColors.primary
                                  : (isDark ? Colors.white : Colors.grey[900]),
                            ),
                          ),
                          Text(
                            address.shortAddress,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: FoodColors.primary,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
          // Add new address button
          InkWell(
            onTap: () {
              _removeAddressOverlay();
              context.push('/settings/addresses');
            },
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[100]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FoodColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_location_alt,
                      color: FoodColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Yeni Adres Ekle',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: FoodColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
      _showOverlay();
    } else if (!_searchFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_searchFocusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query.toLowerCase();
    });

    if (query.isEmpty) {
      _searchDebounceTimer?.cancel();
      _removeOverlay();
      setState(() {
        _foodResults = [];
        _restaurantResults = [];
        _isSearching = false;
      });
      return;
    }

    // Debounce: wait 300ms before searching
    _searchDebounceTimer?.cancel();
    setState(() => _isSearching = true);
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    try {
      // Search both restaurants and menu items in parallel
      final results = await Future.wait([
        RestaurantService.searchRestaurants(query),
        RestaurantService.searchMenuItems(query),
      ]);

      if (!mounted || _searchController.text.trim() != query) return;

      final restaurants = (results[0] as List<Restaurant>)
          .map((r) => SearchableRestaurant(
                id: r.id,
                name: r.name,
                categories: r.categoryTags.join(', '),
                rating: r.rating,
                deliveryTime: r.deliveryTime,
                imageUrl: r.coverUrl ?? r.logoUrl ?? '',
              ))
          .toList();

      final foods = (results[1] as List<Map<String, dynamic>>)
          .map((f) => SearchableFood(
                id: f['id'] as String,
                name: f['name'] as String,
                description: f['description'] as String,
                price: f['price'] as double,
                imageUrl: f['imageUrl'] as String,
                rating: f['rating'] as double,
                restaurantId: f['merchantId'] as String,
                restaurantName: f['restaurantName'] as String,
              ))
          .toList();

      setState(() {
        _foodResults = foods;
        _restaurantResults = restaurants;
        _isSearching = false;
      });

      if (foods.isNotEmpty || restaurants.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            color: Colors.transparent,
            child: _buildSearchResults(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    final hasResults = _foodResults.isNotEmpty || _restaurantResults.isNotEmpty;

    if (!hasResults && _searchQuery.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"$_searchQuery" için sonuç yok',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Restaurants section
              if (_restaurantResults.isNotEmpty) ...[
                _buildSectionHeader('Restoranlar', Icons.restaurant, isDark),
                ..._restaurantResults
                    .take(3)
                    .map((r) => _buildRestaurantItem(r, isDark)),
              ],

              // Foods section
              if (_foodResults.isNotEmpty) ...[
                if (_restaurantResults.isNotEmpty)
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),
                _buildSectionHeader('Yemekler', Icons.fastfood, isDark),
                ..._foodResults.take(5).map((f) => _buildFoodItem(f, isDark)),
              ],

              // See all results
              if (_foodResults.length > 5 || _restaurantResults.length > 3)
                _buildSeeAllButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: FoodColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: FoodColors.primary),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: FoodColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              title == 'Restoranlar'
                  ? '${_restaurantResults.length}'
                  : '${_foodResults.length}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FoodColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantItem(SearchableRestaurant restaurant, bool isDark) {
    return InkWell(
      onTap: () {
        _removeOverlay();
        _searchFocusNode.unfocus();
        context.push(
          '/food/restaurant/${restaurant.id}',
          extra: {
            'name': restaurant.name,
            'imageUrl': restaurant.imageUrl,
            'rating': restaurant.rating,
            'categories': restaurant.categories,
            'deliveryTime': restaurant.deliveryTime,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: restaurant.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: FoodColors.primary.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.restaurant,
                      color: FoodColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.categories,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Rating & Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        restaurant.rating.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  restaurant.deliveryTime,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem(SearchableFood food, bool isDark) {
    return InkWell(
      onTap: () {
        _removeOverlay();
        _searchFocusNode.unfocus();
        context.push(
          '/food/item/${food.id}',
          extra: {
            'name': food.name,
            'description': food.description,
            'price': food.price,
            'imageUrl': food.imageUrl,
            'rating': food.rating,
            'restaurantName': food.restaurantName,
            'deliveryTime': '30-40 dk',
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: food.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: FoodColors.primary.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.fastfood,
                      color: FoodColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Restaurant name with icon
                  Row(
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 12,
                        color: FoodColors.primary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          food.restaurantName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: FoodColors.primary.withValues(alpha: 0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    food.description,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FoodColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₺${food.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FoodColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeeAllButton(bool isDark) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to full search results page
        _removeOverlay();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tüm sonuçları gör',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FoodColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: FoodColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final restaurantsAsync = ref.watch(restaurantsProvider);
    return Scaffold(
      backgroundColor: isDark ? FoodColors.backgroundDark : FoodColors.backgroundLight,
      body: restaurantsAsync.when(
        data: (restaurants) => _buildHomeContent(isDark, restaurants),
        loading: () => const Center(child: CircularProgressIndicator(color: FoodColors.primary)),
        error: (error, stack) => Center(child: Text('Hata: $error')),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Restaurant> restaurants) {
    var results = restaurants.map((r) => r.toCardData()).toList();

    // Category filter (from category tabs)
    if (_selectedCategory != null && _selectedCategory != 'Tümü') {
      results = results.where((r) {
        final tags = r['categoryTags'] as List<String>;
        return tags.any((tag) => tag.toLowerCase().contains(_selectedCategory!.toLowerCase()));
      }).toList();
    }

    // Rating filter
    if (_minRating != null) {
      results = results.where((r) => (r['rating'] as double) >= _minRating!).toList();
    }

    // Sorting
    switch (_selectedSorting) {
      case 'Puana Göre':
        results.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
        break;
      case 'En Yakın':
        // TODO: Sort by distance when location is available
        // For now, sort by delivery time as proxy
        results.sort((a, b) {
          final aTime = _parseDeliveryTime(a['deliveryTime'] as String);
          final bTime = _parseDeliveryTime(b['deliveryTime'] as String);
          return aTime.compareTo(bTime);
        });
        break;
      case 'En Hızlı Teslimat':
        results.sort((a, b) {
          final aTime = _parseDeliveryTime(a['deliveryTime'] as String);
          final bTime = _parseDeliveryTime(b['deliveryTime'] as String);
          return aTime.compareTo(bTime);
        });
        break;
      case 'Fiyat (Düşükten Yükseğe)':
        results.sort((a, b) {
          final aMin = (a['minOrder'] as String).replaceAll(RegExp(r'[^\d.]'), '');
          final bMin = (b['minOrder'] as String).replaceAll(RegExp(r'[^\d.]'), '');
          final aVal = double.tryParse(aMin) ?? 0;
          final bVal = double.tryParse(bMin) ?? 0;
          return aVal.compareTo(bVal);
        });
        break;
      case 'Fiyat (Yüksekten Düşüğe)':
        results.sort((a, b) {
          final aMin = (a['minOrder'] as String).replaceAll(RegExp(r'[^\d.]'), '');
          final bMin = (b['minOrder'] as String).replaceAll(RegExp(r'[^\d.]'), '');
          final aVal = double.tryParse(aMin) ?? 0;
          final bVal = double.tryParse(bMin) ?? 0;
          return bVal.compareTo(aVal);
        });
        break;
      default: // 'Önerilen'
        // Keep default order (by popularity/rating mix)
        break;
    }

    return results;
  }

  int _parseDeliveryTime(String time) {
    // Parse "20-30 dk" format
    final match = RegExp(r'(\d+)').firstMatch(time);
    return match != null ? int.parse(match.group(1)!) : 999;
  }

  Widget _buildHomeContent(bool isDark, List<Restaurant> restaurants) {
    final filteredRestaurants = _applyFilters(restaurants);
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _buildHeader(isDark)),

        // Categories
        SliverToBoxAdapter(child: _buildCategories(isDark)),

        // Promo Banners
        SliverToBoxAdapter(child: _buildPromoBanners(isDark)),

        // Filter Bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterBarDelegate(
            isDark: isDark,
            selectedSorting: _selectedSorting,
            minRating: _minRating,
            onFilterTap: _showAdvancedFilters,
            onSortingChanged: (value) =>
                setState(() => _selectedSorting = value),
            onRatingChanged: (value) => setState(() => _minRating = value),
          ),
        ),

        // Restaurants Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == null
                      ? 'Popüler Restoranlar'
                      : '$_selectedCategory Restoranları',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  '${filteredRestaurants.length} restoran',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),

        // Restaurant List - Filtered
        filteredRestaurants.isEmpty
            ? SliverToBoxAdapter(child: _buildEmptyCategory(isDark))
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final restaurant = filteredRestaurants[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < filteredRestaurants.length - 1
                            ? 16
                            : 0,
                      ),
                      child: RestaurantCard(
                        restaurantId: restaurant['id'],
                        name: restaurant['name'],
                        categories: restaurant['categories'],
                        rating: restaurant['rating'],
                        deliveryTime: restaurant['deliveryTime'],
                        minOrder: restaurant['minOrder'],
                        deliveryFee: restaurant['deliveryFee'],
                        discount: restaurant['discount'],
                        imageUrl: restaurant['imageUrl'],
                      ),
                    );
                  }, childCount: filteredRestaurants.length),
                ),
              ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    final selectedAddress = ref.watch(selectedAddressProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final cartItemCount = ref.watch(cartItemCountProvider);

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: isDark
            ? FoodColors.backgroundDark.withValues(alpha: 0.95)
            : FoodColors.backgroundLight.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? FoodColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.grey[700],
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Address - Clickable dropdown
                Expanded(
                  child: CompositedTransformTarget(
                    link: _addressLayerLink,
                    child: GestureDetector(
                      onTap: () {
                        if (_showAddressDropdown) {
                          _removeAddressOverlay();
                        } else {
                          _showAddressOverlay();
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teslimat Adresi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[500],
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                selectedAddress?.icon ?? Icons.location_on,
                                size: 16,
                                color: FoodColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  selectedAddress != null
                                      ? '${selectedAddress.title} - ${selectedAddress.shortAddress}'
                                      : 'Adres Seçin',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _showAddressDropdown ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: FoodColors.primary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Notification button
                CompositedTransformTarget(
                  link: _notificationLayerLink,
                  child: GestureDetector(
                    onTap: () {
                      if (_showNotificationDropdown) {
                        _removeNotificationOverlay();
                      } else {
                        _showNotificationOverlay();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _showNotificationDropdown
                            ? FoodColors.primary.withValues(alpha: 0.1)
                            : (isDark ? FoodColors.surfaceDark : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showNotificationDropdown
                              ? FoodColors.primary
                              : (isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[200]!),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Icon(
                            _showNotificationDropdown
                                ? Icons.notifications
                                : Icons.notifications_outlined,
                            color: FoodColors.primary,
                            size: 22,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? FoodColors.surfaceDark
                                        : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cart button
                GestureDetector(
                  onTap: () {
                    context.push('/food/cart');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? FoodColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          color: FoodColors.primary,
                          size: 22,
                        ),
                        if (cartItemCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: FoodColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                cartItemCount.toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CompositedTransformTarget(
              link: _layerLink,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? FoodColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                    ),
                  ],
                  border: _searchFocusNode.hasFocus
                      ? Border.all(color: FoodColors.primary, width: 2)
                      : null,
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Yemek veya restoran ara...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: FoodColors.primary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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

  // Kategoriler artık veritabanından yükleniyor (restaurantCategoriesProvider)

  // Tüm restoranlar - Supabase'den yüklenir
  final List<Map<String, dynamic>> _allRestaurantCards = [];

  List<Map<String, dynamic>> get _filteredRestaurants {
    var results = _allRestaurantCards.toList();

    // Kategori filtresi
    if (_selectedCategory != null && _selectedCategory != 'Tümü') {
      results = results.where((r) {
        final tags = r['categoryTags'] as List<String>;
        return tags.any(
          (tag) => tag.toLowerCase().contains(_selectedCategory!.toLowerCase()),
        );
      }).toList();
    }

    // Puan filtresi
    if (_minRating != null) {
      results = results.where((r) {
        final rating = r['rating'] as double;
        return rating >= _minRating!;
      }).toList();
    }

    // Sıralama
    switch (_selectedSorting) {
      case 'Puana Göre':
        results.sort(
          (a, b) => (b['rating'] as double).compareTo(a['rating'] as double),
        );
        break;
      case 'En Yakın':
        // Teslimat süresine göre sırala (yaklaşık mesafe)
        results.sort((a, b) {
          final aTime =
              int.tryParse((a['deliveryTime'] as String).split('-').first) ??
              30;
          final bTime =
              int.tryParse((b['deliveryTime'] as String).split('-').first) ??
              30;
          return aTime.compareTo(bTime);
        });
        break;
      case 'En Hızlı Teslimat':
        results.sort((a, b) {
          final aTime =
              int.tryParse((a['deliveryTime'] as String).split('-').first) ??
              30;
          final bTime =
              int.tryParse((b['deliveryTime'] as String).split('-').first) ??
              30;
          return aTime.compareTo(bTime);
        });
        break;
      case 'Fiyat (Düşükten Yükseğe)':
        results.sort((a, b) {
          final aPrice = (a['minOrder'] as String).replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );
          final bPrice = (b['minOrder'] as String).replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );
          return (int.tryParse(aPrice) ?? 0).compareTo(
            int.tryParse(bPrice) ?? 0,
          );
        });
        break;
      case 'Fiyat (Yüksekten Düşüğe)':
        results.sort((a, b) {
          final aPrice = (a['minOrder'] as String).replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );
          final bPrice = (b['minOrder'] as String).replaceAll(
            RegExp(r'[^0-9]'),
            '',
          );
          return (int.tryParse(bPrice) ?? 0).compareTo(
            int.tryParse(aPrice) ?? 0,
          );
        });
        break;
      default:
        // Önerilen - varsayılan sıralama
        break;
    }

    return results;
  }

  Widget _buildCategories(bool isDark) {
    final categoriesAsync = ref.watch(restaurantCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        return SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected =
                  (_selectedCategory == null && category.name == 'Tümü') ||
                  _selectedCategory == category.name;

              // "Tümü" için özel widget
              if (category.name == 'Tümü') {
                return _buildAllCategoryItem(isDark, isSelected);
              }

              return _buildCategoryItem(
                category.name,
                category.imageUrl ?? '',
                isSelected,
                isDark,
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 115,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(height: 115),
    );
  }

  Widget _buildAllCategoryItem(bool isDark, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = null;
        });
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isSelected
                    ? FoodColors.primary
                    : (isDark ? FoodColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? FoodColors.primary
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: FoodColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.restaurant_menu,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tümü',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? FoodColors.primary
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    String name,
    String imageUrl,
    bool isSelected,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = name;
        });
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? FoodColors.primary
                      : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: FoodColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: isDark ? FoodColors.surfaceDark : Colors.grey[100],
                    child: Icon(
                      Icons.restaurant,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? FoodColors.primary
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategory(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FoodColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: FoodColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bu kategoride restoran bulunamadı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir kategori seçmeyi deneyin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanners(bool isDark) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: FoodBannerCarousel(height: 160),
    );
  }
}

// Filter bar delegate for sticky header
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final String selectedSorting;
  final double? minRating;
  final VoidCallback onFilterTap;
  final Function(String) onSortingChanged;
  final Function(double?) onRatingChanged;

  _FilterBarDelegate({
    required this.isDark,
    required this.selectedSorting,
    required this.minRating,
    required this.onFilterTap,
    required this.onSortingChanged,
    required this.onRatingChanged,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final hasActiveFilters = minRating != null;

    return Container(
      color: isDark
          ? FoodColors.backgroundDark.withValues(alpha: 0.95)
          : FoodColors.backgroundLight.withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            context,
            'Filtrele',
            Icons.tune,
            hasActiveFilters,
            isDark,
            onTap: onFilterTap,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            selectedSorting,
            null,
            selectedSorting != 'Önerilen',
            isDark,
            hasDropdown: true,
            onTap: () => _showSortingDialog(context),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            context,
            minRating != null ? '$minRating+' : 'Puan',
            null,
            minRating != null,
            isDark,
            hasDropdown: true,
            onTap: () => _showRatingDialog(context),
          ),
        ],
      ),
    );
  }

  void _showSortingDialog(BuildContext context) {
    final sortingOptions = [
      'Önerilen',
      'Puana Göre',
      'En Yakın',
      'En Hızlı Teslimat',
      'Fiyat (Düşükten Yükseğe)',
      'Fiyat (Yüksekten Düşüğe)',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sıralama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            ...sortingOptions.map(
              (option) => ListTile(
                title: Text(
                  option,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: option == selectedSorting
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: option == selectedSorting
                    ? Icon(Icons.check, color: FoodColors.primary)
                    : null,
                onTap: () {
                  onSortingChanged(option);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    final ratingOptions = [null, 4.5, 4.0, 3.5, 3.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? FoodColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Minimum Puan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            ...ratingOptions.map(
              (option) => ListTile(
                leading: option != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            option.toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' ve üzeri',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : null,
                title: option == null
                    ? Text(
                        'Tümü',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: option == minRating
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      )
                    : null,
                trailing: option == minRating
                    ? Icon(Icons.check, color: FoodColors.primary)
                    : null,
                onTap: () {
                  onRatingChanged(option);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    IconData? icon,
    bool isActive,
    bool isDark, {
    bool hasDropdown = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? FoodColors.primary
              : (isDark ? FoodColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? null
              : Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: FoodColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (isDark ? Colors.grey[200] : Colors.grey[700]),
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) =>
      oldDelegate.selectedSorting != selectedSorting ||
      oldDelegate.minRating != minRating ||
      oldDelegate.isDark != isDark;
}
