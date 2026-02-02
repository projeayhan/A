import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';

// All orders provider
final allOrdersProvider = FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final active = await CourierService.getActiveOrders();
  final completed = await CourierService.getCompletedOrders();
  return {
    'active': active,
    'completed': completed,
  };
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Siparişlerim'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Aktif'),
              Tab(text: 'Tamamlanan'),
            ],
          ),
        ),
        body: ordersAsync.when(
          data: (orders) => TabBarView(
            children: [
              _buildOrdersList(context, orders['active'] ?? [], isActive: true),
              _buildOrdersList(context, orders['completed'] ?? [], isActive: false),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Hata: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(allOrdersProvider),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(BuildContext context, List<Map<String, dynamic>> orders, {required bool isActive}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.delivery_dining : Icons.check_circle_outline,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Aktif sipariş yok' : 'Tamamlanan sipariş yok',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Will be handled by parent
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) => _buildOrderCard(context, orders[index], isActive),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, bool isActive) {
    final merchant = order['merchants'] as Map<String, dynamic>?;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final status = order['status'] as String? ?? '';

    Color statusColor;
    String statusText;

    switch (status) {
      case 'picked_up':
        statusColor = AppColors.info;
        statusText = 'Teslimatta';
        break;
      case 'delivering':
        statusColor = AppColors.warning;
        statusText = 'Yolda';
        break;
      case 'delivered':
        statusColor = AppColors.success;
        statusText = 'Teslim Edildi';
        break;
      case 'assigned':
        statusColor = AppColors.primary;
        statusText = 'Atandı';
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/orders/${order['id']}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isActive ? Icons.delivery_dining : Icons.check_circle,
                        color: isActive ? AppColors.primary : AppColors.success,
                      ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₺${deliveryFee.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 24),

                // Address
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order['delivery_address'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (isActive) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/orders/${order['id']}'),
                      child: const Text('Detayları Gör'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
