import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/car_sales_admin_service.dart';

class CarSalesPricingScreen extends ConsumerStatefulWidget {
  const CarSalesPricingScreen({super.key});

  @override
  ConsumerState<CarSalesPricingScreen> createState() => _CarSalesPricingScreenState();
}

class _CarSalesPricingScreenState extends ConsumerState<CarSalesPricingScreen> {
  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(carPromotionPricesProvider);

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
                      'Öne Çıkarma Fiyatları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İlan öne çıkarma fiyatlarını yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(carPromotionPricesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showPriceDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Fiyat Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Prices Grid
            Expanded(
              child: pricesAsync.when(
                data: (prices) => _buildPricesGrid(prices),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricesGrid(List<PromotionPrice> prices) {
    if (prices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz fiyat tanımlanmamış', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    // Group by promotion type
    final featured = prices.where((p) => p.promotionType == 'featured').toList();
    final premium = prices.where((p) => p.promotionType == 'premium').toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Prices
          _buildPriceSection('Standart Öne Çıkarma', featured, AppColors.info),
          const SizedBox(height: 24),
          // Premium Prices
          _buildPriceSection('Premium Öne Çıkarma', premium, AppColors.warning),
        ],
      ),
    );
  }

  Widget _buildPriceSection(String title, List<PromotionPrice> prices, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              title.contains('Premium') ? Icons.workspace_premium : Icons.trending_up,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (prices.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: const Center(
              child: Text('Bu kategori için fiyat yok', style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: prices.map((price) => _buildPriceCard(price, color)).toList(),
          ),
      ],
    );
  }

  Widget _buildPriceCard(PromotionPrice price, Color color) {
    final hasDiscount = price.discountedPrice != null && price.discountedPrice! < price.price;
    final effectivePrice = price.discountedPrice ?? price.price;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${price.durationDays} Gün',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              if (!price.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Pasif',
                    style: TextStyle(color: AppColors.error, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${effectivePrice.toStringAsFixed(0)} ₺',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 8),
                Text(
                  '${price.price.toStringAsFixed(0)} ₺',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),

          if (hasDiscount) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '%${((1 - effectivePrice / price.price) * 100).toStringAsFixed(0)} indirim',
                style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],

          if (price.description != null) ...[
            const SizedBox(height: 12),
            Text(
              price.description!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPriceDialog(price: price),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Düzenle'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _deletePrice(price),
                icon: const Icon(Icons.delete, size: 20),
                color: AppColors.error,
                tooltip: 'Sil',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPriceDialog({PromotionPrice? price}) {
    final isEdit = price != null;
    final priceController = TextEditingController(text: price?.price.toStringAsFixed(0) ?? '');
    final discountedPriceController = TextEditingController(
      text: price?.discountedPrice?.toStringAsFixed(0) ?? '',
    );
    final descriptionController = TextEditingController(text: price?.description ?? '');
    final sortOrderController = TextEditingController(text: (price?.sortOrder ?? 0).toString());
    String selectedType = price?.promotionType ?? 'featured';
    int selectedDuration = price?.durationDays ?? 7;
    bool isActive = price?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Fiyat Düzenle' : 'Yeni Fiyat Ekle'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Promosyon Tipi'),
                    items: const [
                      DropdownMenuItem(value: 'featured', child: Text('Standart Öne Çıkarma')),
                      DropdownMenuItem(value: 'premium', child: Text('Premium Öne Çıkarma')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedDuration,
                    decoration: const InputDecoration(labelText: 'Süre'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 Gün')),
                      DropdownMenuItem(value: 3, child: Text('3 Gün')),
                      DropdownMenuItem(value: 7, child: Text('7 Gün')),
                      DropdownMenuItem(value: 14, child: Text('14 Gün')),
                      DropdownMenuItem(value: 30, child: Text('30 Gün')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedDuration = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Fiyat (₺) *'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: discountedPriceController,
                    decoration: const InputDecoration(
                      labelText: 'İndirimli Fiyat (₺)',
                      hintText: 'Boş bırakılırsa indirim yok',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sortOrderController,
                    decoration: const InputDecoration(labelText: 'Sıra'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final priceValue = double.tryParse(priceController.text);
                if (priceValue == null || priceValue <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir fiyat girin')),
                  );
                  return;
                }

                final discountedPrice = double.tryParse(discountedPriceController.text);

                final data = {
                  'promotion_type': selectedType,
                  'duration_days': selectedDuration,
                  'price': priceValue,
                  'discounted_price': discountedPrice,
                  'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_active': isActive,
                };

                final service = ref.read(carSalesAdminServiceProvider);
                try {
                  if (isEdit) {
                    await service.updatePromotionPrice(price.id, data);
                  } else {
                    await service.createPromotionPrice(data);
                  }
                  ref.invalidate(carPromotionPricesProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePrice(PromotionPrice price) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fiyatı Sil'),
        content: Text('${price.durationDays} günlük fiyatı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(carSalesAdminServiceProvider);
      try {
        await service.deletePromotionPrice(price.id);
        ref.invalidate(carPromotionPricesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fiyat silindi'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
