import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Top merchants provider
final topMerchantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('merchants')
      .select('id, business_name, rating, total_orders, logo_url')
      .eq('is_approved', true)
      .order('total_orders', ascending: false)
      .limit(5);
  return List<Map<String, dynamic>>.from(response);
});

class TopMerchantsCard extends ConsumerWidget {
  const TopMerchantsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantsAsync = ref.watch(topMerchantsProvider);

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
                    'En İyi İşletmeler',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Sipariş sayısına göre',
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
          merchantsAsync.when(
            data: (merchants) {
              if (merchants.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Henüz işletme yok',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                );
              }
              return Column(
                children: List.generate(
                  merchants.length,
                  (index) => _buildMerchantRow(merchants[index], index),
                ),
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

  Widget _buildMerchantRow(Map<String, dynamic> merchant, int index) {
    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.error,
    ];

    final color = colors[index % colors.length];
    final name = merchant['business_name'] ?? 'İsimsiz';
    final orders = merchant['total_orders'] ?? 0;
    final rating = (merchant['rating'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: index < 4
            ? Border(bottom: BorderSide(color: AppColors.surfaceLight.withValues(alpha: 0.5)))
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.2),
            backgroundImage: merchant['logo_url'] != null
                ? NetworkImage(merchant['logo_url'])
                : null,
            child: merchant['logo_url'] == null
                ? Text(
                    name.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$orders sipariş',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Rating
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, color: AppColors.warning, size: 14),
              const SizedBox(width: 4),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
