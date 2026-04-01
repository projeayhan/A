import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/home_providers.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final workMode = ref.watch(workModeProvider);
    final pendingOrders = ref.watch(pendingOrdersProvider);
    final activeOrders = ref.watch(activeOrdersProvider);
    final courierRequests = ref.watch(courierRequestsProvider);
    final assignedOrders = ref.watch(assignedOrdersProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(courierDataProvider.notifier).refreshOrders();
              },
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: _buildHeader(context, ref, authState, isOnline),
                  ),

                  // Online/Offline Card
                  SliverToBoxAdapter(
                    child: _buildOnlineCard(context, ref, isOnline),
                  ),

                  // Work Mode Card (only when online)
                  if (isOnline)
                    SliverToBoxAdapter(
                      child: _buildWorkModeCard(context, ref, workMode),
                    ),

                  // Assigned Orders Section (Restoran tarafından atanan siparişler)
                  assignedOrders.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }
                      return SliverToBoxAdapter(
                        child: _buildAssignedOrdersSection(
                          context,
                          ref,
                          orders,
                        ),
                      );
                    },
                    loading: () =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (_, _) =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),

                  // Active Orders Section
                  activeOrders.when(
                    data: (orders) {
                      if (orders.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }
                      return SliverToBoxAdapter(
                        child: _buildActiveOrdersSection(context, ref, orders),
                      );
                    },
                    loading: () =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (_, _) =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),

                  // Available Orders Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bekleyen Siparişler',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            onPressed: () {
                              ref.invalidate(pendingOrdersProvider);
                            },
                            icon: const Icon(
                              Icons.refresh,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pending Orders List
                  pendingOrders.when(
                    data: (orders) {
                      if (!isOnline) {
                        return SliverToBoxAdapter(
                          child: _buildOfflineMessage(context),
                        );
                      }
                      if (orders.isEmpty) {
                        return SliverToBoxAdapter(
                          child: _buildEmptyOrders(context),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildOrderCard(context, ref, orders[index]),
                            childCount: orders.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => SliverToBoxAdapter(
                      child: Center(child: Text('Hata: $error')),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ),
        // Courier Request Overlay - Sadece platform modunda veya 'her ikisi' modunda göster
        // Restoran modunda kuryeye direkt atama yapılır, onay gerekmez
        if (workMode != WorkMode.restaurant)
          courierRequests.when(
            data: (requests) {
              if (requests.isEmpty || !isOnline) return const SizedBox.shrink();
              return _CourierRequestOverlay(
                request: requests.first,
                onAccept: () async {
                  final orderData = await CourierService.acceptCourierRequest(
                    requests.first['id'],
                  );
                  if (orderData != null) {
                    ref.read(courierDataProvider.notifier).refreshOrders();
                    ref.read(courierDataProvider.notifier).refreshRequests();
                    if (context.mounted) {
                      // Sipariş detaylarını extra olarak gönder
                      final result = await context.push(
                        '/orders/${requests.first['order_id']}',
                        extra: orderData,
                      );
                      if (result == true) {
                        ref.read(courierDataProvider.notifier).refreshOrders();
                      }
                    }
                  }
                },
                onReject: () async {
                  await CourierService.rejectCourierRequest(
                    requests.first['id'],
                  );
                  ref.read(courierDataProvider.notifier).refreshRequests();
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    bool isOnline,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          // Name & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba, ${authState.courierName.split(' ').first}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.online : AppColors.offline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Notification with badge
          _buildNotificationButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      children: [
        IconButton(
          onPressed: () => _showNotificationsSheet(context, ref),
          icon: const Icon(Icons.notifications_outlined),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    final notifications = ref.read(notificationsProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bildirimler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        NotificationService.markAllAsRead();
                        ref.invalidate(notificationsProvider);
                      },
                      child: const Text('Tümünü Okundu İşaretle'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Notifications List
              Expanded(
                child: notifications.when(
                  data: (notifs) {
                    if (notifs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: AppColors.textHint,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Henüz bildiriminiz yok',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: notifs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final notif = notifs[index];
                        final isRead = notif['is_read'] == true;
                        final type = notif['type'] as String? ?? 'info';
                        final data =
                            notif['data'] as Map<String, dynamic>? ?? {};

                        IconData icon;
                        Color color;
                        switch (type) {
                          case 'order_update':
                            icon = Icons.delivery_dining;
                            color = AppColors.primary;
                            break;
                          case 'success':
                            icon = Icons.check_circle;
                            color = AppColors.success;
                            break;
                          case 'warning':
                            icon = Icons.warning;
                            color = AppColors.warning;
                            break;
                          case 'error':
                            icon = Icons.error;
                            color = AppColors.error;
                            break;
                          default:
                            icon = Icons.info;
                            color = AppColors.info;
                        }

                        return InkWell(
                          onTap: () async {
                            // Bildirimi okundu işaretle
                            if (!isRead) {
                              NotificationService.markAsRead(notif['id']);
                              ref.invalidate(notificationsProvider);
                            }
                            // Sipariş detayına git
                            if (data['order_id'] != null) {
                              Navigator.pop(context);
                              final result = await context.push(
                                '/orders/${data['order_id']}',
                              );
                              if (result == true) {
                                ref
                                    .read(courierDataProvider.notifier)
                                    .refreshOrders();
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? AppColors.background
                                  : color.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRead
                                    ? AppColors.border
                                    : color.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notif['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        notif['body'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Hata: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineCard(BuildContext context, WidgetRef ref, bool isOnline) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
              : [
                  AppColors.textSecondary,
                  AppColors.textSecondary.withValues(alpha: 0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Çevrimiçisiniz' : 'Çevrimdışısınız',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline
                      ? 'Sipariş almaya hazırsınız'
                      : 'Sipariş almak için çevrimiçi olun',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            onChanged: (value) async {
              await CourierService.updateOnlineStatus(value);
              // courierProfileProvider realtime ile otomatik güncellenecek
              if (value) {
                ref.invalidate(pendingOrdersProvider);
              }
            },
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkModeCard(
    BuildContext context,
    WidgetRef ref,
    WorkMode workMode,
  ) {
    // Kuryenin merchant_id'si var mı kontrol et
    final courierProfile = ref.watch(courierProfileProvider);
    final hasMerchant =
        courierProfile.whenData((data) => data?['merchant_id'] != null).value ??
        false;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Çalışma Modu',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _WorkModeButton(
                icon: Icons.public,
                label: 'Platform',
                isSelected: workMode == WorkMode.platform,
                onTap: () => CourierService.updateWorkMode('platform'),
              ),
              const SizedBox(width: 8),
              _WorkModeButton(
                icon: Icons.restaurant,
                label: 'Restoran',
                isSelected: workMode == WorkMode.restaurant,
                isDisabled: !hasMerchant,
                onTap: hasMerchant
                    ? () => CourierService.updateWorkMode('restaurant')
                    : null,
              ),
              const SizedBox(width: 8),
              _WorkModeButton(
                icon: Icons.all_inclusive,
                label: 'Her İkisi',
                isSelected: workMode == WorkMode.both,
                isDisabled: !hasMerchant,
                onTap: hasMerchant
                    ? () => CourierService.updateWorkMode('both')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !hasMerchant
                ? 'Restoran modları için bir restorana bağlı olmanız gerekiyor.'
                : _getWorkModeDescription(workMode),
            style: TextStyle(
              fontSize: 12,
              color: !hasMerchant ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getWorkModeDescription(WorkMode mode) {
    switch (mode) {
      case WorkMode.platform:
        return 'Sadece platform üzerinden gelen siparişleri alırsınız.';
      case WorkMode.restaurant:
        return 'Sadece anlaşmalı restoranların siparişlerini alırsınız.';
      case WorkMode.both:
        return 'Hem platform hem de restoran siparişlerini alırsınız.';
    }
  }

  Widget _buildAssignedOrdersSection(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> orders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assignment,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Size Atanan Siparişler',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${orders.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...orders.map((order) => _buildAssignedOrderCard(context, ref, order)),
      ],
    );
  }

  Widget _buildAssignedOrderCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
  ) {
    final merchant = order['merchants'] as Map<String, dynamic>?;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? '';
    final distanceKm = (order['distance_km'] as num?)?.toDouble();
    final estimatedMinutes = (order['estimated_minutes'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant?['business_name'] ?? 'Restoran',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order['order_number'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₺${deliveryFee.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: status == 'ready'
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status == 'ready' ? 'Hazır' : 'Hazırlanıyor',
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'ready'
                            ? AppColors.success
                            : AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mesafe ve tahmini süre
          if (distanceKm != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation, size: 14, color: AppColors.info),
                  const SizedBox(width: 6),
                  Text(
                    '${distanceKm.toStringAsFixed(1)} km',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (estimatedMinutes != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 14, color: AppColors.info),
                    const SizedBox(width: 4),
                    Text(
                      '~$estimatedMinutes dk',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // Teslimat adresi
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order['delivery_address'] ?? 'Teslimat adresi',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await context.push('/orders/${order['id']}');
                    if (result == true) {
                      ref.read(courierDataProvider.notifier).refreshOrders();
                    }
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Detay'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: status == 'ready'
                      ? () async {
                          // Siparişi teslim aldım olarak işaretle
                          final success =
                              await CourierService.updateOrderStatus(
                                order['id'],
                                'picked_up',
                              );
                          if (success) {
                            ref
                                .read(courierDataProvider.notifier)
                                .refreshOrders();
                            if (context.mounted) {
                              final result = await context.push(
                                '/orders/${order['id']}',
                              );
                              if (result == true) {
                                ref
                                    .read(courierDataProvider.notifier)
                                    .refreshOrders();
                              }
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.delivery_dining, size: 18),
                  label: Text(status == 'ready' ? 'Teslim Al' : 'Hazırlanıyor'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersSection(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> orders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Aktif Siparişler',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ...orders.map((order) => _buildActiveOrderCard(context, ref, order)),
      ],
    );
  }

  Widget _buildActiveOrderCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
  ) {
    final merchant = order['merchants'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delivery_dining, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchant?['business_name'] ?? 'Sipariş',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  order['delivery_address'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await context.push('/orders/${order['id']}');
              if (result == true) {
                ref.read(courierDataProvider.notifier).refreshOrders();
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Detay'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Çevrimdışısınız',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sipariş görmek için çevrimiçi olun',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Bekleyen sipariş yok',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni siparişler geldiğinde burada görünecek',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> order,
  ) {
    final merchant = order['merchants'] as Map<String, dynamic>?;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Restaurant icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant?['business_name'] ?? 'Restoran',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order['order_number'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₺${deliveryFee.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Addresses
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.store, size: 16, color: AppColors.primary),
                  Container(width: 2, height: 24, color: AppColors.border),
                  Icon(Icons.location_on, size: 16, color: AppColors.error),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant?['address'] ?? 'Restoran adresi',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      order['delivery_address'] ?? 'Teslimat adresi',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Accept button - Bu eski pending orders listesi için
          // Artık courier_requests sistemi kullanılıyor, bu kısım kullanılmıyor
          // Ancak backwards compatibility için tutuyoruz
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // Race condition'ı önlemek için atomik RPC kullan
                final orderData = await CourierService.acceptCourierRequest(
                  order['id'],
                );
                if (orderData != null) {
                  ref.read(courierDataProvider.notifier).refreshOrders();
                  if (context.mounted) {
                    final result = await context.push('/orders/${order['id']}');
                    if (result == true) {
                      ref.read(courierDataProvider.notifier).refreshOrders();
                    }
                  }
                }
              },
              child: const Text('Siparişi Al'),
            ),
          ),
        ],
      ),
    );
  }
}

// Courier Request Overlay Widget with Countdown Timer
class _CourierRequestOverlay extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _CourierRequestOverlay({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_CourierRequestOverlay> createState() => _CourierRequestOverlayState();
}

class _CourierRequestOverlayState extends State<_CourierRequestOverlay> {
  late Timer _timer;
  int _remainingSeconds = 30;
  int _initialSeconds = 30;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }

  void _calculateRemainingTime() {
    final expiresAt = DateTime.tryParse(widget.request['expires_at'] ?? '');
    if (expiresAt != null) {
      _remainingSeconds = expiresAt.difference(DateTime.now()).inSeconds;
      if (_remainingSeconds < 0) _remainingSeconds = 0;
    }
    _initialSeconds = _remainingSeconds > 0 ? _remainingSeconds : 30;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer.cancel();
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.request['orders'] as Map<String, dynamic>?;
    final merchant = order?['merchants'] as Map<String, dynamic>?;
    final deliveryFee =
        (widget.request['delivery_fee'] as num?)?.toDouble() ?? 0;
    final distance = (widget.request['distance_km'] as num?)?.toDouble() ?? 0;
    final merchantType = merchant?['type'] as String? ?? 'restaurant';
    final isStore = merchantType == 'store';

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Countdown Timer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: (_remainingSeconds / _initialSeconds).clamp(
                          0.0,
                          1.0,
                        ),
                        strokeWidth: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _remainingSeconds <= 10
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      '$_remainingSeconds',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds <= 10
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Title
                const Text(
                  'Yeni Sipariş Teklifi!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                // Merchant Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isStore ? Icons.store : Icons.restaurant,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  merchant?['business_name'] ??
                                      (isStore ? 'Mağaza' : 'Restoran'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  merchant?['address'] ?? '',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order?['delivery_address'] ?? 'Teslimat adresi',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Fee and Distance
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '₺${deliveryFee.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                            const Text(
                              'Kazanç',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
                              ),
                            ),
                            const Text(
                              'Mesafe',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onReject,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: widget.onAccept,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.success,
                        ),
                        child: const Text(
                          'Kabul Et',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Work Mode Button Widget
class _WorkModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _WorkModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled
        ? AppColors.textSecondary.withValues(alpha: 0.5)
        : (isSelected ? AppColors.primary : AppColors.textSecondary);

    return Expanded(
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected && !isDisabled
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected && !isDisabled
                    ? AppColors.primary
                    : AppColors.border,
                width: isSelected && !isDisabled ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, color: effectiveColor, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected && !isDisabled
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: effectiveColor,
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
