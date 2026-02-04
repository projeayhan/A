import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/merchant_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Ekran açıldığında tüm bildirimleri okundu olarak işaretle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                'Bildirimler',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount yeni',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: () {
                    ref.read(notificationsProvider.notifier).markAllAsRead();
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Tumunu Okundu Isaretle'),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  ref.read(notificationsProvider.notifier).clearAll();
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Temizle'),
              ),
            ],
          ),
        ),

        // Notifications List
        Expanded(
          child: notifications.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationCard(
                      notification: notification,
                      onTap: () {
                        ref.read(notificationsProvider.notifier).markAsRead(notification.id);
                        _navigateToNotificationTarget(context, notification);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _navigateToNotificationTarget(BuildContext context, MerchantNotification notification) {
    final data = notification.data;

    switch (notification.type) {
      case 'order':
      case 'order_cancelled':
        // Sipariş bildirimi - sipariş detayına git
        final orderId = data?['order_id'] as String?;
        if (orderId != null) {
          context.push('/orders/$orderId');
        } else {
          context.go('/orders');
        }
        break;

      case 'review':
        // Yorum bildirimi - yorumlar sayfasına git
        context.go('/reviews');
        break;

      case 'payment':
        // Ödeme bildirimi - finans sayfasına git
        context.go('/finance');
        break;

      case 'stock':
        // Stok bildirimi - ürünler sayfasına git
        context.go('/products');
        break;

      case 'system':
      default:
        // Sistem bildirimi - bir şey yapma
        break;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 64,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bildirim Yok',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bildirimler burada gorunecek',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final MerchantNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead ? AppColors.surface : AppColors.primary.withAlpha(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Content
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
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread Indicator
              if (!notification.isRead) ...[
                const SizedBox(width: 12),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.receipt_long;
      case 'order_cancelled':
        return Icons.cancel;
      case 'review':
        return Icons.star;
      case 'payment':
        return Icons.account_balance_wallet;
      case 'stock':
        return Icons.inventory;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'order':
        return AppColors.primary;
      case 'order_cancelled':
        return AppColors.error;
      case 'review':
        return AppColors.warning;
      case 'payment':
        return AppColors.success;
      case 'stock':
        return AppColors.error;
      case 'system':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Simdi';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk once';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat once';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gun once';
    } else {
      return DateFormat('d MMM').format(dateTime);
    }
  }
}
