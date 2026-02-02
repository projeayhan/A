import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationState = ref.watch(notificationProvider);
    final notifications = notificationState.notifications;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: isDark ? Colors.white : Colors.grey[800]),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Bildirimler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
        actions: [
          if (notificationState.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllAsRead();
              },
              child: const Text(
                'Tümünü Oku',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: notificationState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: () => ref.read(notificationProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationCard(context, ref, notification, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Bildirim Yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz bildiriminiz bulunmuyor',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
    bool isDark,
  ) {
    final timeAgo = _getTimeAgo(notification.createdAt);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(notificationProvider.notifier).deleteNotification(notification.id);
      },
      child: GestureDetector(
        onTap: () {
          if (!notification.isRead) {
            ref.read(notificationProvider.notifier).markAsRead(notification.id);
          }
          _handleNotificationTap(context, notification);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: !notification.isRead
                ? Border.all(color: Color(notification.colorValue).withValues(alpha: 0.5), width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İkon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(notification.colorValue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getIcon(notification.iconName),
                  color: Color(notification.colorValue),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              // İçerik
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
                              fontSize: 15,
                              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(notification.colorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String iconName) {
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

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
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
}
