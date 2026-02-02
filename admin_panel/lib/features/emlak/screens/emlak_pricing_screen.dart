import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakPricingScreen extends ConsumerStatefulWidget {
  const EmlakPricingScreen({super.key});

  @override
  ConsumerState<EmlakPricingScreen> createState() => _EmlakPricingScreenState();
}

class _EmlakPricingScreenState extends ConsumerState<EmlakPricingScreen> {
  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(promotionPricesProvider);
    final statsAsync = ref.watch(promotionStatsProvider);

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
                      'Promosyon Fiyatlandırma',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İlan öne çıkarma ve premium paket fiyatlarını yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(promotionPricesProvider);
                        ref.invalidate(promotionStatsProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddPriceDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Paket Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // İstatistik Kartları
            statsAsync.when(
              data: (stats) => _buildStatsCards(stats),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Fiyat Listesi
            Expanded(
              child: pricesAsync.when(
                data: (prices) => _buildPricesContent(prices),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Hata: $e', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Aktif Promosyonlar',
            '${stats['active_promotions'] ?? 0}',
            Icons.campaign,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Son 30 Gün',
            '${stats['recent_promotions'] ?? 0}',
            Icons.trending_up,
            AppColors.info,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Toplam Gelir (30 Gün)',
            '${((stats['total_revenue_30d'] ?? 0) as num).toStringAsFixed(0)} ₺',
            Icons.attach_money,
            AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricesContent(List<PromotionPrice> prices) {
    if (prices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.price_change, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Henüz fiyat paketi bulunmuyor',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddPriceDialog(),
              icon: const Icon(Icons.add),
              label: const Text('İlk Paketi Ekle'),
            ),
          ],
        ),
      );
    }

    // Fiyatları türlerine göre grupla
    final featuredPrices = prices.where((p) => p.promotionType == 'featured').toList();
    final premiumPrices = prices.where((p) => p.promotionType == 'premium').toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Öne Çıkan Paketleri
          _buildPriceSection(
            'Öne Çıkan Paketleri',
            'Arama sonuçlarında üst sıralarda gösterilir',
            featuredPrices,
            Icons.star,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 24),
          // Premium Paketleri
          _buildPriceSection(
            'Premium Paketleri',
            'Altın kenarlık, Premium rozeti ve en üst sırada gösterilir',
            premiumPrices,
            Icons.workspace_premium,
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection(
    String title,
    String description,
    List<PromotionPrice> prices,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.1), Colors.transparent],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: const Border(bottom: BorderSide(color: AppColors.surfaceLight)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${prices.length} paket',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          // Prices Grid
          if (prices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Bu kategoride paket bulunmuyor',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: prices.length,
                    itemBuilder: (context, index) => _buildPriceCard(prices[index], color),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(PromotionPrice price, Color color) {
    final hasDiscount = price.discountedPrice != null && price.discountedPrice! < price.price;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: price.isActive ? Colors.white : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: price.isActive ? color.withValues(alpha: 0.3) : AppColors.surfaceLight,
          width: price.isActive ? 2 : 1,
        ),
        boxShadow: price.isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${price.durationDays} Gün',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!price.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pasif',
                    style: TextStyle(color: AppColors.error, fontSize: 10),
                  ),
                ),
            ],
          ),
          const Spacer(),
          // Price
          if (hasDiscount) ...[
            Text(
              '${price.price.toStringAsFixed(0)} ₺',
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 14,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            Text(
              '${price.discountedPrice!.toStringAsFixed(0)} ₺',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else
            Text(
              '${price.price.toStringAsFixed(0)} ₺',
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          const Spacer(),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showEditPriceDialog(price),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Düzenle', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showDeleteConfirmDialog(price),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: const Color(0xFFEF4444),
                tooltip: 'Sil',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddPriceDialog() {
    String selectedType = 'featured';
    final durationController = TextEditingController(text: '7');
    final priceController = TextEditingController();
    final discountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Paket Ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Paket Türü
                const Text('Paket Türü', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeOption(
                        'featured',
                        'Öne Çıkan',
                        Icons.star,
                        const Color(0xFF3B82F6),
                        selectedType,
                        (value) => setDialogState(() => selectedType = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTypeOption(
                        'premium',
                        'Premium',
                        Icons.workspace_premium,
                        const Color(0xFFF59E0B),
                        selectedType,
                        (value) => setDialogState(() => selectedType = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Süre
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Süre (Gün)',
                    border: OutlineInputBorder(),
                    hintText: 'Örn: 7, 30, 90',
                  ),
                ),
                const SizedBox(height: 16),
                // Fiyat
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat',
                    border: OutlineInputBorder(),
                    suffixText: '₺',
                  ),
                ),
                const SizedBox(height: 16),
                // İndirimli Fiyat
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'İndirimli Fiyat (Opsiyonel)',
                    border: OutlineInputBorder(),
                    suffixText: '₺',
                    helperText: 'Kampanya dönemlerinde kullanılır',
                  ),
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
                final duration = int.tryParse(durationController.text);
                final price = double.tryParse(priceController.text);

                if (duration == null || price == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lütfen geçerli değerler girin'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final discount = double.tryParse(discountController.text);

                final service = ref.read(emlakAdminServiceProvider);
                try {
                  await service.addPromotionPrice(
                    promotionType: selectedType,
                    durationDays: duration,
                    price: price,
                    discountedPrice: discount,
                  );
                  ref.invalidate(promotionPricesProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Paket eklendi'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Dialog'u kapat

                    // Duplicate key hatası kontrolü
                    if (e.toString().contains('duplicate key') ||
                        e.toString().contains('unique constraint') ||
                        e.toString().contains('23505')) {
                      final typeName = selectedType == 'premium' ? 'Premium' : 'Öne Çıkan';
                      _showErrorDialog(
                        title: 'Paket Zaten Mevcut',
                        message: '$typeName - ${durationController.text} Gün paketi zaten sistemde kayıtlı.\n\nMevcut paketin fiyatını değiştirmek için "Düzenle" butonunu kullanabilirsiniz.',
                        icon: Icons.info_outline,
                        iconColor: AppColors.warning,
                      );
                    } else {
                      _showErrorDialog(
                        title: 'İşlem Başarısız',
                        message: 'Paket eklenirken bir hata oluştu.\n\nHata detayı: $e',
                        icon: Icons.error_outline,
                        iconColor: AppColors.error,
                      );
                    }
                  }
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(
    String value,
    String label,
    IconData icon,
    Color color,
    String selectedValue,
    Function(String) onSelect,
  ) {
    final isSelected = value == selectedValue;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPriceDialog(PromotionPrice price) {
    final priceController = TextEditingController(text: price.price.toStringAsFixed(0));
    final discountController = TextEditingController(
      text: price.discountedPrice?.toStringAsFixed(0) ?? '',
    );
    bool isActive = price.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(price.displayName),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fiyat',
                    border: OutlineInputBorder(),
                    suffixText: '₺',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'İndirimli Fiyat (Opsiyonel)',
                    border: OutlineInputBorder(),
                    suffixText: '₺',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  subtitle: Text(isActive ? 'Kullanıcılar bu paketi satın alabilir' : 'Bu paket görüntülenmez'),
                  value: isActive,
                  onChanged: (value) => setDialogState(() => isActive = value),
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
                    const SnackBar(
                      content: Text('Lütfen geçerli bir fiyat girin'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final discountText = discountController.text.trim();
                final discount = discountText.isNotEmpty ? double.tryParse(discountText) : null;
                final clearDiscount = discountText.isEmpty && price.discountedPrice != null;

                final service = ref.read(emlakAdminServiceProvider);
                try {
                  await service.updatePromotionPrice(
                    price.id,
                    price: newPrice,
                    discountedPrice: discount,
                    clearDiscount: clearDiscount,
                    isActive: isActive,
                  );
                  ref.invalidate(promotionPricesProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Paket güncellendi'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    _showErrorDialog(
                      title: 'Güncelleme Başarısız',
                      message: 'Paket güncellenirken bir hata oluştu.\n\nHata detayı: $e',
                      icon: Icons.error_outline,
                      iconColor: AppColors.error,
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

  void _showDeleteConfirmDialog(PromotionPrice price) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paketi Sil'),
        content: Text('"${price.displayName}" paketini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.deletePromotionPrice(price.id);
                ref.invalidate(promotionPricesProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paket silindi')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showErrorDialog(
                    title: 'Silme Başarısız',
                    message: 'Paket silinirken bir hata oluştu.\n\nHata detayı: $e',
                    icon: Icons.error_outline,
                    iconColor: AppColors.error,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
