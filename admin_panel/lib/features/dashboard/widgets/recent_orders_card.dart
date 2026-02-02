import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Recent orders provider
final recentOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('orders')
      .select('id, customer_name, total_amount, status, created_at, merchant_id, merchants(business_name)')
      .order('created_at', ascending: false)
      .limit(5);
  return List<Map<String, dynamic>>.from(response);
});

class RecentOrdersCard extends ConsumerWidget {
  const RecentOrdersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(recentOrdersProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Son Siparişler',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Son 5 sipariş',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Tümünü Gör'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Sipariş', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Müşteri', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('İşletme', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Tutar', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(child: Text('Durum', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Table Rows
          ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Henüz sipariş yok',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                );
              }
              return Column(
                children: orders.map((order) => _buildOrderRow(order)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order) {
    final id = (order['id'] ?? '').toString();
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
    final customerName = order['customer_name'] ?? 'Müşteri';
    final merchantName = order['merchants']?['business_name'] ?? 'İşletme';
    final amount = (order['total_amount'] ?? 0).toDouble();
    final status = order['status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '#$shortId',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              customerName,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              merchantName,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              '₺${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: _buildStatusBadge(status),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'delivered':
        color = AppColors.success;
        text = 'Teslim';
        break;
      case 'on_the_way':
        color = AppColors.info;
        text = 'Yolda';
        break;
      case 'preparing':
        color = AppColors.warning;
        text = 'Hazırlanıyor';
        break;
      case 'pending':
        color = AppColors.textMuted;
        text = 'Bekliyor';
        break;
      case 'confirmed':
        color = AppColors.info;
        text = 'Onaylı';
        break;
      case 'cancelled':
        color = AppColors.error;
        text = 'İptal';
        break;
      default:
        color = AppColors.textMuted;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}
