import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/job_listings_admin_service.dart';

class JobPricingScreen extends ConsumerWidget {
  const JobPricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricingAsync = ref.watch(jobPromotionPricesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promosyon Fiyatları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İş ilanı promosyon fiyatlarını düzenleyin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(jobPromotionPricesProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yenile'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Pricing Cards
            Expanded(
              child: pricingAsync.when(
                data: (prices) => _buildPricingGrid(context, ref, prices),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingGrid(BuildContext context, WidgetRef ref, List<JobPromotionPrice> prices) {
    // Group by promotion type
    final featured = prices.where((p) => p.promotionType == 'featured').toList();
    final premium = prices.where((p) => p.promotionType == 'premium').toList();
    final urgent = prices.where((p) => p.promotionType == 'urgent').toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured.isNotEmpty) ...[
            _buildSectionTitle('Öne Çıkarma', Icons.star_rounded, AppColors.warning),
            const SizedBox(height: 16),
            _buildPriceCards(context, ref, featured, AppColors.warning),
            const SizedBox(height: 32),
          ],
          if (premium.isNotEmpty) ...[
            _buildSectionTitle('Premium', Icons.workspace_premium_rounded, AppColors.primary),
            const SizedBox(height: 16),
            _buildPriceCards(context, ref, premium, AppColors.primary),
            const SizedBox(height: 32),
          ],
          if (urgent.isNotEmpty) ...[
            _buildSectionTitle('Acil', Icons.priority_high_rounded, AppColors.error),
            const SizedBox(height: 16),
            _buildPriceCards(context, ref, urgent, AppColors.error),
          ],
          if (prices.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(Icons.monetization_on_outlined, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('Fiyat tanımı bulunamadı', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCards(BuildContext context, WidgetRef ref, List<JobPromotionPrice> prices, Color color) {
    return Row(
      children: prices.map((price) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildPriceCard(context, ref, price, color),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceCard(BuildContext context, WidgetRef ref, JobPromotionPrice price, Color color) {
    final hasDiscount = price.discountedPrice != null && price.discountedPrice! < price.price;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${price.durationDays} Gün',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (!price.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pasif',
                    style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasDiscount) ...[
            Text(
              '₺${price.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₺${(hasDiscount ? price.discountedPrice! : price.price).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '%${((1 - price.discountedPrice! / price.price) * 100).toStringAsFixed(0)} İndirim',
                    style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditDialog(context, ref, price),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Düzenle'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, JobPromotionPrice price) {
    final priceController = TextEditingController(text: price.price.toStringAsFixed(0));
    final discountController = TextEditingController(
      text: price.discountedPrice?.toStringAsFixed(0) ?? '',
    );
    bool isActive = price.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${price.promotionTypeLabel} - ${price.durationDays} Gün'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat (₺)',
                    prefixText: '₺ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: discountController,
                  decoration: const InputDecoration(
                    labelText: 'İndirimli Fiyat (₺) - Opsiyonel',
                    prefixText: '₺ ',
                    hintText: 'Boş bırakılırsa indirim uygulanmaz',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  subtitle: const Text('Bu fiyat seçeneği kullanılabilir mi?'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPrice = double.tryParse(priceController.text);
                if (newPrice == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir fiyat girin')),
                  );
                  return;
                }

                final discountedPrice = discountController.text.isNotEmpty
                    ? double.tryParse(discountController.text)
                    : null;

                final data = {
                  'price': newPrice,
                  'discounted_price': discountedPrice,
                  'is_active': isActive,
                };

                final service = ref.read(jobListingsAdminServiceProvider);
                try {
                  await service.updatePromotionPrice(price.id, data);
                  ref.invalidate(jobPromotionPricesProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
