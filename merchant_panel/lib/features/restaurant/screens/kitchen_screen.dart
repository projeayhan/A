import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/merchant_models.dart';
import '../../../core/providers/merchant_provider.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Hata: $error')),
      data: (orderList) {
        // Filter active kitchen orders
        // Mutfak sadece onaylanmis siparisleri gorur (confirmed, preparing, ready)
        final confirmedOrders = orderList.where((o) => o.status == OrderStatus.confirmed).toList();
        final preparingOrders = orderList.where((o) => o.status == OrderStatus.preparing).toList();
        final readyOrders = orderList.where((o) => o.status == OrderStatus.ready).toList();

        return Column(
          children: [
            // Stats Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  _KitchenStat(
                    label: 'Onaylandi',
                    count: confirmedOrders.length,
                    color: AppColors.warning,
                    icon: Icons.receipt_long,
                  ),
                  const SizedBox(width: 16),
                  _KitchenStat(
                    label: 'Hazirlaniyor',
                    count: preparingOrders.length,
                    color: AppColors.info,
                    icon: Icons.soup_kitchen,
                  ),
                  const SizedBox(width: 16),
                  _KitchenStat(
                    label: 'Hazir',
                    count: readyOrders.length,
                    color: AppColors.success,
                    icon: Icons.done_all,
                  ),
                  const Spacer(),
                  // Auto-refresh indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Canli',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Kanban Board
            Expanded(
              child: Row(
                children: [
                  // Confirmed Column - Onaylanan siparisler mutfaga duser
                  Expanded(
                    child: _KanbanColumn(
                      title: 'Onaylandi',
                      color: AppColors.warning,
                      orders: confirmedOrders,
                      onOrderAction: (order, action) {
                        if (action == 'start') {
                          ref.read(ordersProvider.notifier).updateOrderStatus(
                            order.id,
                            OrderStatus.preparing,
                          );
                        }
                      },
                    ),
                  ),

                  // Preparing Column
                  Expanded(
                    child: _KanbanColumn(
                      title: 'Hazirlaniyor',
                      color: AppColors.info,
                      orders: preparingOrders,
                      onOrderAction: (order, action) {
                        if (action == 'ready') {
                          ref.read(ordersProvider.notifier).updateOrderStatus(
                            order.id,
                            OrderStatus.ready,
                          );
                        }
                      },
                    ),
                  ),

                  // Ready Column
                  Expanded(
                    child: _KanbanColumn(
                      title: 'Hazir',
                      color: AppColors.success,
                      orders: readyOrders,
                      onOrderAction: (order, action) {
                        if (action == 'pickedup') {
                          ref.read(ordersProvider.notifier).updateOrderStatus(
                            order.id,
                            OrderStatus.pickedUp,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

}

class _KitchenStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _KitchenStat({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final Color color;
  final List<Order> orders;
  final Function(Order, String) onOrderAction;

  const _KanbanColumn({
    required this.title,
    required this.color,
    required this.orders,
    required this.onOrderAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    orders.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'Siparis yok',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _KitchenOrderCard(
                        order: order,
                        color: color,
                        onAction: (action) => onOrderAction(order, action),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KitchenOrderCard extends StatelessWidget {
  final Order order;
  final Color color;
  final Function(String) onAction;

  const _KitchenOrderCard({
    required this.order,
    required this.color,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                // Waiting time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.waitingTime.inMinutes > 10
                        ? AppColors.error.withAlpha(30)
                        : AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: order.waitingTime.inMinutes > 10
                            ? AppColors.error
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.waitingTimeText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: order.waitingTime.inMinutes > 10
                              ? AppColors.error
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Items
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${item.quantity}x',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (item.notes != null)
                          Text(
                            item.notes!,
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )),

            const Divider(height: 24),

            // Customer Info
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  order.customerName,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('HH:mm').format(order.createdAt),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions - Mutfak sadece hazirlama islemleri yapar
            if (order.status == OrderStatus.confirmed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onAction('start'),
                  icon: const Icon(Icons.soup_kitchen, size: 18),
                  label: const Text('Hazirliyorum'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                  ),
                ),
              )
            else if (order.status == OrderStatus.preparing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onAction('ready'),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Hazir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              )
            else if (order.status == OrderStatus.ready)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onAction('pickedup'),
                  icon: const Icon(Icons.delivery_dining, size: 18),
                  label: const Text('Kurye Aldi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
