import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_responsive.dart';
import '../core/providers/address_provider.dart';
import '../core/providers/store_follow_provider.dart';
import '../core/providers/notification_provider.dart';
import '../core/providers/cart_provider.dart';
import '../core/providers/store_cart_provider.dart';

class DeliveryHeader extends ConsumerStatefulWidget {
  final Color? backgroundColor;
  final bool showCart;
  final VoidCallback? onCartTap;

  const DeliveryHeader({
    super.key,
    this.backgroundColor,
    this.showCart = true,
    this.onCartTap,
  });

  @override
  ConsumerState<DeliveryHeader> createState() => _DeliveryHeaderState();
}

class _DeliveryHeaderState extends ConsumerState<DeliveryHeader> {
  final LayerLink _addressLayerLink = LayerLink();
  final LayerLink _notificationLayerLink = LayerLink();
  OverlayEntry? _addressOverlay;
  OverlayEntry? _notificationOverlay;
  bool _showAddressDropdown = false;
  bool _showNotificationDropdown = false;

  @override
  void dispose() {
    _removeAddressOverlay();
    _removeNotificationOverlay();
    super.dispose();
  }

  void _removeAddressOverlay() {
    _addressOverlay?.remove();
    _addressOverlay = null;
  }

  void _removeNotificationOverlay() {
    _notificationOverlay?.remove();
    _notificationOverlay = null;
  }

  void _toggleAddressDropdown() {
    if (_showNotificationDropdown) {
      _removeNotificationOverlay();
      setState(() => _showNotificationDropdown = false);
    }

    if (_showAddressDropdown) {
      _removeAddressOverlay();
      setState(() => _showAddressDropdown = false);
    } else {
      _showAddressOverlay();
      setState(() => _showAddressDropdown = true);
    }
  }

  void _toggleNotificationDropdown() {
    if (_showAddressDropdown) {
      _removeAddressOverlay();
      setState(() => _showAddressDropdown = false);
    }

    if (_showNotificationDropdown) {
      _removeNotificationOverlay();
      setState(() => _showNotificationDropdown = false);
    } else {
      _showNotificationOverlay();
      setState(() => _showNotificationDropdown = true);
      // Bildirim paneli açıldığında tüm bildirimleri okunmuş olarak işaretle
      ref.read(notificationProvider.notifier).markAllAsRead();
      ref.read(storeNotificationProvider.notifier).markAllAsRead();
    }
  }

  void _showAddressOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressState = ref.read(addressProvider);
    final addresses = addressState.addresses;
    final selectedAddress = addressState.selectedAddress;

    _addressOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _removeAddressOverlay();
                setState(() => _showAddressDropdown = false);
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown
          Positioned(
            width: context.dropdownMaxWidth,
            child: CompositedTransformFollower(
              link: _addressLayerLink,
              showWhenUnlinked: false,
              offset: Offset(0, context.isMobile ? 48 : 54),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: isDark ? AppColors.surfaceDark : Colors.white,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Text(
                              'Teslimat Adresi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                _removeAddressOverlay();
                                setState(() => _showAddressDropdown = false);
                                context.push('/settings/addresses');
                              },
                              child: const Text(
                                'Düzenle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Address List
                      ...addresses.map((address) {
                        final isSelected = selectedAddress?.id == address.id;
                        IconData icon;
                        Color iconColor;

                        switch (address.type) {
                          case 'home':
                            icon = Icons.home_outlined;
                            iconColor = const Color(0xFF3B82F6);
                            break;
                          case 'work':
                            icon = Icons.work_outline;
                            iconColor = const Color(0xFF8B5CF6);
                            break;
                          default:
                            icon = Icons.location_on_outlined;
                            iconColor = const Color(0xFF10B981);
                        }

                        return InkWell(
                          onTap: () {
                            ref.read(addressProvider.notifier).setDefaultAddress(address.id);
                            _removeAddressOverlay();
                            setState(() => _showAddressDropdown = false);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: iconColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        address.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                                        ),
                                      ),
                                      Text(
                                        address.shortAddress,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 1),
                      // Add New Address
                      InkWell(
                        onTap: () {
                          _removeAddressOverlay();
                          setState(() => _showAddressDropdown = false);
                          context.push('/settings/addresses');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Yeni Adres Ekle',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_addressOverlay!);
  }

  void _showNotificationOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationState = ref.read(notificationProvider);
    final notifications = notificationState.notifications;
    final storeNotifications = ref.read(storeNotificationProvider).notifications;

    _notificationOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _removeNotificationOverlay();
                setState(() => _showNotificationDropdown = false);
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown
          Positioned(
            left: context.pagePaddingH,
            right: context.pagePaddingH,
            top: MediaQuery.of(context).padding.top + (context.isMobile ? 62 : 68),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: isDark ? AppColors.surfaceDark : Colors.white,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              'Bildirimler',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                ref.read(notificationProvider.notifier).markAllAsRead();
                                ref.read(storeNotificationProvider.notifier).markAllAsRead();
                              },
                              child: const Text(
                                'Tümünü Okundu İşaretle',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Notifications List
                      Flexible(
                        child: (notifications.isEmpty && storeNotifications.isEmpty)
                            ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.notifications_off_outlined,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Bildirim yok',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                shrinkWrap: true,
                                padding: const EdgeInsets.all(8),
                                children: [
                                  // Mağaza Bildirimleri
                                  if (storeNotifications.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.store_rounded, size: 16, color: Colors.grey[500]),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Mağaza Bildirimleri',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...storeNotifications.map((notification) =>
                                      _buildStoreNotificationItem(notification, isDark)),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                  ],
                                  // Genel Bildirimler
                                  if (notifications.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.notifications_rounded, size: 16, color: Colors.grey[500]),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Genel Bildirimler',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...notifications.map((notification) =>
                                      _buildNotificationItem(notification, isDark)),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

    Overlay.of(context).insert(_notificationOverlay!);
  }

  Widget _buildStoreNotificationItem(StoreNotification notification, bool isDark) {
    return GestureDetector(
      onTap: () {
        ref.read(storeNotificationProvider.notifier).markAsRead(notification.id);
        _removeNotificationOverlay();
        setState(() => _showNotificationDropdown = false);
        // Mağaza sayfasına yönlendir
        // context.push('/store/${notification.storeId}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : notification.iconColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Logo veya Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: notification.iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: notification.storeLogoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: notification.storeLogoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          notification.icon,
                          color: notification.iconColor,
                          size: 18,
                        ),
                      )
                    : Icon(
                        notification.icon,
                        color: notification.iconColor,
                        size: 18,
                      ),
              ),
            ),
            const SizedBox(width: 10),
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
                            fontSize: 13,
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: notification.iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: notification.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notification.storeName,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: notification.iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        notification.timeAgo,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification, bool isDark) {
    final iconColor = Color(notification.colorValue);
    final icon = _getNotificationIcon(notification.iconName);
    final timeAgo = _getTimeAgo(notification.createdAt);

    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          ref.read(notificationProvider.notifier).markAsRead(notification.id);
        }
        _removeNotificationOverlay();
        setState(() => _showNotificationDropdown = false);
        _handleNotificationTap(notification);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.transparent
              : iconColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
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
                            fontSize: 13,
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
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

  IconData _getNotificationIcon(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'local_taxi':
        return Icons.local_taxi;
      case 'directions_car':
        return Icons.directions_car;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'celebration':
        return Icons.celebration;
      case 'delivery_dining':
        return Icons.delivery_dining;
      case 'star':
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Az önce';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dakika önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    final data = notification.data;
    if (data == null) return;

    switch (notification.type) {
      case 'order_update':
      case 'store_order':
        final orderId = data['order_id'] as String?;
        if (orderId != null) {
          context.push('/food/order-tracking/$orderId');
        }
        break;
      case 'taxi_ride':
        final rideId = data['ride_id'] as String?;
        if (rideId != null) {
          context.push('/taxi');
        }
        break;
      case 'job_application':
      case 'job_application_status':
        final jobId = data['job_id'] as String?;
        if (jobId != null) {
          context.push('/jobs/detail/$jobId');
        }
        break;
      case 'car_message':
      case 'car_favorite':
        final listingId = data['listing_id'] as String?;
        if (listingId != null) {
          context.push('/car-sales/detail/$listingId');
        }
        break;
      case 'property_message':
      case 'property_favorite':
      case 'property_appointment':
        final propertyId = data['property_id'] as String?;
        if (propertyId != null) {
          context.push('/emlak/property/$propertyId');
        }
        break;
      case 'rental_reservation':
        context.push('/rental');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedAddress = ref.watch(selectedAddressProvider);
    final notificationState = ref.watch(notificationProvider);
    final storeNotificationState = ref.watch(storeNotificationProvider);
    final foodCartCount = ref.watch(cartItemCountProvider);
    final storeCartCount = ref.watch(storeCartItemCountProvider);
    final cartCount = foodCartCount + storeCartCount;
    final generalUnreadCount = notificationState.unreadCount;
    final storeUnreadCount = storeNotificationState.unreadCount;
    final unreadCount = generalUnreadCount + storeUnreadCount;

    IconData addressIcon;
    switch (selectedAddress?.type ?? 'other') {
      case 'home':
        addressIcon = Icons.home;
        break;
      case 'work':
        addressIcon = Icons.work;
        break;
      default:
        addressIcon = Icons.location_on;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.pagePaddingH, vertical: context.isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? (isDark ? AppColors.surfaceDark : Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Address Selection
            Expanded(
              child: CompositedTransformTarget(
                link: _addressLayerLink,
                child: GestureDetector(
                  onTap: _toggleAddressDropdown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showAddressDropdown
                            ? AppColors.primary
                            : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC6D13).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(addressIcon, color: const Color(0xFFEC6D13), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Teslimat Adresi',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      selectedAddress != null
                                          ? '${selectedAddress.title} - ${selectedAddress.shortAddress}'
                                          : 'Adres Seçin',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: _showAddressDropdown ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 18,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Notification Button
            CompositedTransformTarget(
              link: _notificationLayerLink,
              child: GestureDetector(
                onTap: _toggleNotificationDropdown,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _showNotificationDropdown
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showNotificationDropdown
                          ? AppColors.primary
                          : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications_outlined,
                          color: _showNotificationDropdown
                              ? AppColors.primary
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          size: 22,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 9 ? '9+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Cart Button (optional)
            if (widget.showCart) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onCartTap ?? () => context.push(foodCartCount > 0 ? '/food/cart' : '/store/cart'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: Color(0xFFEC6D13),
                          size: 22,
                        ),
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEC6D13),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                cartCount > 9 ? '9+' : cartCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
