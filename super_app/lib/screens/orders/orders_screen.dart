import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/services/supabase_service.dart';

// Cached merchant data to avoid repeated queries
final _merchantCache = <String, Map<String, dynamic>>{};

// Active orders provider with real-time updates - optimized
final activeOrdersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final userId = SupabaseService.currentUser?.id;
  if (userId == null) {
    yield [];
    return;
  }

  await for (final orders in SupabaseService.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)) {

    // If no orders, yield empty list immediately
    if (orders.isEmpty) {
      yield [];
      continue;
    }

    // Find merchant IDs not in cache
    final merchantIds = orders
        .map((o) => o['merchant_id'] as String?)
        .where((id) => id != null && !_merchantCache.containsKey(id))
        .toSet()
        .toList();

    // Only fetch merchants not in cache
    if (merchantIds.isNotEmpty) {
      try {
        final merchants = await SupabaseService.client
            .from('merchants')
            .select('id, business_name, logo_url')
            .inFilter('id', merchantIds);

        for (final merchant in merchants) {
          final id = merchant['id'] as String?;
          if (id != null) {
            _merchantCache[id] = merchant;
          }
        }
      } catch (_) {
        // Continue without merchant data if fetch fails
      }
    }

    // Enrich orders with cached merchant data
    final enrichedOrders = orders.map((order) {
      final merchantId = order['merchant_id'] as String?;
      if (merchantId != null && _merchantCache.containsKey(merchantId)) {
        return {...order, 'merchants': _merchantCache[merchantId]};
      }
      return order;
    }).toList();

    yield enrichedOrders;
  }
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ordersAsync = ref.watch(activeOrdersStreamProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Siparişlerim',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmptyState(isDark);
          }

          // Separate active and past orders
          final activeOrders = orders.where((o) {
            final status = o['status'] as String? ?? '';
            return status != 'delivered' && status != 'cancelled';
          }).toList();

          final pastOrders = orders.where((o) {
            final status = o['status'] as String? ?? '';
            return status == 'delivered' || status == 'cancelled';
          }).toList();

          return CustomScrollView(
            slivers: [
              // Active Orders Section
              if (activeOrders.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delivery_dining,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Aktif Siparişler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${activeOrders.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = activeOrders[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildActiveOrderCard(context, order, isDark),
                      );
                    },
                    childCount: activeOrders.length,
                  ),
                ),
              ],

              // Past Orders Section
              if (pastOrders.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.history,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Geçmiş Siparişler',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = pastOrders[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildPastOrderCard(context, order, isDark),
                      );
                    },
                    childCount: pastOrders.length,
                  ),
                ),
              ],

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: context.bottomNavPadding),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Hata: $error')),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz siparişiniz yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk siparişinizi verin ve buradan takip edin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.restaurant),
            label: const Text('Yemek Sipariş Et'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(BuildContext context, Map<String, dynamic> order, bool isDark) {
    final status = order['status'] as String? ?? 'pending';
    final statusInfo = _getStatusInfo(status);
    final orderNumber = order['order_number'] as String? ?? order['id'].toString().substring(0, 8);
    final createdAt = DateTime.tryParse(order['created_at'] as String? ?? '') ?? DateTime.now();
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final merchantData = order['merchants'] as Map<String, dynamic>?;
    final storeName = merchantData?['business_name'] as String? ?? order['store_name'] as String? ?? 'Restoran';

    return GestureDetector(
      onTap: () {
        // Navigate to order tracking
        context.push('/food/order-tracking/${order['id']}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (statusInfo['color'] as Color).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (statusInfo['color'] as Color).withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusInfo['color'] as Color,
                    (statusInfo['color'] as Color).withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      statusInfo['icon'] as IconData,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusInfo['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          statusInfo['subtitle'] as String,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _getEstimatedTime(status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Order Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sipariş #$orderNumber',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₺${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Indicator
                  _buildProgressIndicator(status, isDark),

                  const SizedBox(height: 16),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/food/order-tracking/${order['id']}');
                      },
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Siparişi Takip Et'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusInfo['color'] as Color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildProgressIndicator(String status, bool isDark) {
    final steps = ['pending', 'confirmed', 'preparing', 'ready', 'delivering'];
    final currentIndex = steps.indexOf(status);

    return Row(
      children: List.generate(steps.length, (index) {
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? (isCurrent ? AppColors.primary : const Color(0xFF22C55E))
                      : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.circle,
                  color: isCompleted ? Colors.white : Colors.grey[500],
                  size: 14,
                ),
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    color: index < currentIndex
                        ? const Color(0xFF22C55E)
                        : (isDark ? Colors.grey[700] : Colors.grey[300]),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildPastOrderCard(BuildContext context, Map<String, dynamic> order, bool isDark) {
    final status = order['status'] as String? ?? 'delivered';
    final orderNumber = order['order_number'] as String? ?? order['id'].toString().substring(0, 8);
    final createdAt = DateTime.tryParse(order['created_at'] as String? ?? '') ?? DateTime.now();
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final merchantData = order['merchants'] as Map<String, dynamic>?;
    final storeName = merchantData?['business_name'] as String? ?? order['store_name'] as String? ?? 'Restoran';
    final isDelivered = status == 'delivered';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${createdAt.day}.${createdAt.month}.${createdAt.year} • ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDelivered ? const Color(0xFF22C55E) : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDelivered ? Icons.check_circle : Icons.cancel,
                        size: 14,
                        color: isDelivered ? const Color(0xFF22C55E) : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isDelivered ? 'Teslim Edildi' : 'İptal Edildi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDelivered ? const Color(0xFF22C55E) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sipariş #$orderNumber',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Text(
                  '₺${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (isDelivered) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Reorder functionality
                      },
                      icon: const Icon(Icons.replay, size: 16),
                      label: const Text('Tekrar Sipariş'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildReviewButton(context, order, isDark),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'title': 'Sipariş Alındı',
          'subtitle': 'Siparişiniz restorana iletildi',
          'icon': Icons.receipt_long,
          'color': const Color(0xFFF59E0B),
        };
      case 'confirmed':
        return {
          'title': 'Onaylandı',
          'subtitle': 'Restoran siparişinizi onayladı',
          'icon': Icons.check_circle,
          'color': const Color(0xFF3B82F6),
        };
      case 'preparing':
        return {
          'title': 'Hazırlanıyor',
          'subtitle': 'Siparişiniz hazırlanıyor',
          'icon': Icons.restaurant,
          'color': const Color(0xFF8B5CF6),
        };
      case 'ready':
        return {
          'title': 'Hazır',
          'subtitle': 'Siparişiniz kurye bekliyor',
          'icon': Icons.check_box,
          'color': const Color(0xFF10B981),
        };
      case 'delivering':
        return {
          'title': 'Yolda',
          'subtitle': 'Kurye siparişinizi getiriyor',
          'icon': Icons.delivery_dining,
          'color': const Color(0xFF06B6D4),
        };
      default:
        return {
          'title': 'Beklemede',
          'subtitle': 'İşlem bekleniyor',
          'icon': Icons.hourglass_empty,
          'color': Colors.grey,
        };
    }
  }

  String _getEstimatedTime(String status) {
    switch (status) {
      case 'pending':
        return '30-40 dk';
      case 'confirmed':
        return '25-35 dk';
      case 'preparing':
        return '20-30 dk';
      case 'ready':
        return '15-20 dk';
      case 'delivering':
        return '10-15 dk';
      default:
        return '30-40 dk';
    }
  }

  Widget _buildReviewButton(BuildContext context, Map<String, dynamic> order, bool isDark) {
    final isReviewed = order['is_reviewed'] as bool? ?? false;
    final orderId = order['id'] as String;

    if (isReviewed) {
      // Already reviewed - show disabled button with check
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF22C55E)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 16, color: Color(0xFF22C55E)),
            SizedBox(width: 6),
            Text(
              'Değerlendirildi',
              style: TextStyle(
                color: Color(0xFF22C55E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Not reviewed - show review button
    return ElevatedButton.icon(
      onPressed: () {
        context.push('/food/order-review/$orderId');
      },
      icon: const Icon(Icons.star, size: 16),
      label: const Text('Değerlendir'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }
}
