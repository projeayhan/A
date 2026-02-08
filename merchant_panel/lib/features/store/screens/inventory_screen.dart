import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as exc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/merchant_models.dart';
import '../../../core/providers/merchant_provider.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _selectedView = 'overview'; // overview, movements, alerts

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(storeProductsProvider);
    final lowStockProducts = ref.watch(lowStockProductsProvider);

    return Column(
      children: [
        // Header with Stats
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              // Stats Row
              Row(
                children: [
                  _buildStatCard(
                    context,
                    'Toplam Urun',
                    products.maybeWhen(
                      data: (list) => list.length.toString(),
                      orElse: () => '0',
                    ),
                    Icons.inventory_2,
                    AppColors.primary,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    'Toplam Stok Degeri',
                    products.maybeWhen(
                      data: (list) {
                        final total = list.fold(0.0, (sum, p) => sum + (p.price * p.stock));
                        return '${NumberFormat.compact().format(total)} TL';
                      },
                      orElse: () => '0 TL',
                    ),
                    Icons.attach_money,
                    AppColors.success,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    'Dusuk Stok',
                    lowStockProducts.length.toString(),
                    Icons.warning_amber,
                    AppColors.warning,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    context,
                    'Tukenmis',
                    products.maybeWhen(
                      data: (list) => list.where((p) => p.isOutOfStock).length.toString(),
                      orElse: () => '0',
                    ),
                    Icons.remove_shopping_cart,
                    AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // View Tabs
              Row(
                children: [
                  _ViewTab(
                    label: 'Genel Bakis',
                    icon: Icons.dashboard,
                    isSelected: _selectedView == 'overview',
                    onTap: () => setState(() => _selectedView = 'overview'),
                  ),
                  const SizedBox(width: 12),
                  _ViewTab(
                    label: 'Stok Hareketleri',
                    icon: Icons.swap_vert,
                    isSelected: _selectedView == 'movements',
                    onTap: () => setState(() => _selectedView = 'movements'),
                  ),
                  const SizedBox(width: 12),
                  _ViewTab(
                    label: 'Uyarilar',
                    icon: Icons.notifications,
                    isSelected: _selectedView == 'alerts',
                    badge: lowStockProducts.length,
                    onTap: () => setState(() => _selectedView = 'alerts'),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _showBulkUpdateDialog(context),
                    icon: const Icon(Icons.edit_note, size: 20),
                    label: const Text('Toplu Guncelle'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _downloadReport(context),
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Rapor Indir'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _buildContent(products, lowStockProducts),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AsyncValue<List<StoreProduct>> products, List<StoreProduct> lowStock) {
    switch (_selectedView) {
      case 'movements':
        return _buildMovementsView();
      case 'alerts':
        return _buildAlertsView(lowStock);
      default:
        return _buildOverviewView(products);
    }
  }

  Widget _buildOverviewView(AsyncValue<List<StoreProduct>> products) {
    return products.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Hata: $error')),
      data: (productList) {
        if (productList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textMuted),
                const SizedBox(height: 24),
                Text(
                  'Urun bulunamadi',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Category Distribution
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCategoryDistribution(productList),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildTopStockItems(productList),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Stock Level Table
              _buildStockLevelTable(productList),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryDistribution(List<StoreProduct> products) {
    // Category name lookup
    final categories = ref.watch(productCategoriesProvider).valueOrNull ?? [];
    final categoryNames = <String, String>{};
    for (final cat in categories) {
      categoryNames[cat.id] = cat.name;
    }

    // Group by category name
    final categoryMap = <String, int>{};
    for (final product in products) {
      final catName = categoryNames[product.categoryId] ?? 'Kategorisiz';
      categoryMap[catName] = (categoryMap[catName] ?? 0) + product.stock;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kategori Bazli Stok Dagilimi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          ...categoryMap.entries.map((entry) {
            final total = categoryMap.values.reduce((a, b) => a + b);
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(
                        '${entry.value} adet (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopStockItems(List<StoreProduct> products) {
    final sorted = [...products]..sort((a, b) => b.stock.compareTo(a.stock));
    final top5 = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'En Yuksek Stok',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          ...top5.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      product.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${product.stock}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStockLevelTable(List<StoreProduct> products) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Stok Seviyeleri',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Urun', style: _headerStyle)),
                Expanded(child: Text('Mevcut', style: _headerStyle, textAlign: TextAlign.center)),
                Expanded(child: Text('Min. Stok', style: _headerStyle, textAlign: TextAlign.center)),
                Expanded(child: Text('Durum', style: _headerStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...products.take(10).map((product) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(100))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(product.name),
                ),
                Expanded(
                  child: Text(
                    '${product.stock}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: product.isOutOfStock
                          ? AppColors.error
                          : product.isLowStock
                              ? AppColors.warning
                              : AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${product.lowStockThreshold}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: product.isOutOfStock
                            ? AppColors.error.withAlpha(30)
                            : product.isLowStock
                                ? AppColors.warning.withAlpha(30)
                                : AppColors.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.isOutOfStock
                            ? 'Tukendi'
                            : product.isLowStock
                                ? 'Dusuk'
                                : 'Normal',
                        style: TextStyle(
                          color: product.isOutOfStock
                              ? AppColors.error
                              : product.isLowStock
                                  ? AppColors.warning
                                  : AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  Widget _buildMovementsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Son Stok Hareketleri',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _MovementItem(
              type: 'in',
              product: 'iPhone 15 Pro',
              quantity: 50,
              date: DateTime.now().subtract(const Duration(hours: 2)),
              note: 'Tedarikci siparisi',
            ),
            _MovementItem(
              type: 'out',
              product: 'Samsung Galaxy S24',
              quantity: 5,
              date: DateTime.now().subtract(const Duration(hours: 5)),
              note: 'Siparis #12458',
            ),
            _MovementItem(
              type: 'adjustment',
              product: 'AirPods Pro',
              quantity: -2,
              date: DateTime.now().subtract(const Duration(days: 1)),
              note: 'Sayim farki',
            ),
            _MovementItem(
              type: 'in',
              product: 'MacBook Air M3',
              quantity: 20,
              date: DateTime.now().subtract(const Duration(days: 2)),
              note: 'Tedarikci siparisi',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsView(List<StoreProduct> lowStock) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lowStock.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: AppColors.success),
                  const SizedBox(height: 24),
                  Text(
                    'Tum stoklar yeterli seviyede',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
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
                      Icon(Icons.warning_amber, color: AppColors.warning),
                      const SizedBox(width: 12),
                      Text(
                        'Dusuk Stok Uyarilari',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...lowStock.map((product) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: product.isOutOfStock
                          ? AppColors.error.withAlpha(20)
                          : AppColors.warning.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: product.isOutOfStock
                            ? AppColors.error.withAlpha(50)
                            : AppColors.warning.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: product.isOutOfStock
                                ? AppColors.error.withAlpha(30)
                                : AppColors.warning.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            product.isOutOfStock
                                ? Icons.remove_shopping_cart
                                : Icons.warning_amber,
                            color: product.isOutOfStock
                                ? AppColors.error
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                product.isOutOfStock
                                    ? 'Stok tukendi!'
                                    : 'Stok: ${product.stock} adet (Min: ${product.lowStockThreshold})',
                                style: TextStyle(
                                  color: product.isOutOfStock
                                      ? AppColors.error
                                      : AppColors.warning,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showUpdateStockDialog(product),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Stok Ekle'),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showBulkUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: AppColors.primary),
            SizedBox(width: 12),
            Text('Toplu Stok Guncelleme'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Excel dosyasi yukleyerek urunlerin stok bilgilerini toplu olarak guncelleyebilirsiniz.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beklenen Excel Formati:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _formatRow('A Sutunu:', 'Urun Adi (tam eslesmeli)'),
                    _formatRow('B Sutunu:', 'Yeni Stok Miktari (sayi)'),
                    const SizedBox(height: 8),
                    Text(
                      'Ilk satir baslik olarak atlanir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndProcessExcel();
            },
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Dosya Sec'),
          ),
        ],
      ),
    );
  }

  Widget _formatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Future<void> _pickAndProcessExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dosya okunamadi'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final excel = exc.Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel dosyasi bos veya gecersiz'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Parse rows (skip header row)
      final parsed = <String, int>{}; // productName -> newStock
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.length < 2) continue;

        final nameCell = row[0]?.value?.toString().trim();
        final stockCell = row[1]?.value;
        if (nameCell == null || nameCell.isEmpty) continue;

        final stockVal = int.tryParse(stockCell?.toString() ?? '');
        if (stockVal == null) continue;

        parsed[nameCell] = stockVal;
      }

      if (parsed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dosyada gecerli veri bulunamadi'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Match parsed names with existing products
      final products = ref.read(storeProductsProvider).valueOrNull ?? [];
      final matches = <String, _BulkUpdateItem>{}; // productId -> update info
      final unmatched = <String>[];

      for (final entry in parsed.entries) {
        final product = products.where(
          (p) => p.name.trim().toLowerCase() == entry.key.toLowerCase(),
        ).firstOrNull;

        if (product != null) {
          matches[product.id] = _BulkUpdateItem(
            name: product.name,
            currentStock: product.stock,
            newStock: entry.value,
          );
        } else {
          unmatched.add(entry.key);
        }
      }

      if (matches.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hicbir urun eslesmedi. Urun adlarini kontrol edin.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) _showBulkPreviewDialog(matches, unmatched);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showBulkPreviewDialog(Map<String, _BulkUpdateItem> matches, List<String> unmatched) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.preview, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('Onizleme (${matches.length} urun)'),
          ],
        ),
        content: SizedBox(
          width: 560,
          height: 400,
          child: Column(
            children: [
              if (unmatched.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withAlpha(50)),
                  ),
                  child: Text(
                    '${unmatched.length} urun eslesmedi: ${unmatched.take(5).join(", ")}${unmatched.length > 5 ? "..." : ""}',
                    style: TextStyle(color: AppColors.warning, fontSize: 13),
                  ),
                ),
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('Urun', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                    Expanded(child: Text('Mevcut', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                    const SizedBox(width: 24, child: Center(child: Icon(Icons.arrow_forward, size: 14))),
                    Expanded(child: Text('Yeni', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final entry = matches.entries.elementAt(index);
                    final item = entry.value;
                    final diff = item.newStock - item.currentStock;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border.withAlpha(80))),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(item.name, overflow: TextOverflow.ellipsis)),
                          Expanded(child: Text('${item.currentStock}', textAlign: TextAlign.center)),
                          SizedBox(
                            width: 24,
                            child: Icon(
                              diff > 0 ? Icons.arrow_upward : diff < 0 ? Icons.arrow_downward : Icons.remove,
                              size: 14,
                              color: diff > 0 ? AppColors.success : diff < 0 ? AppColors.error : AppColors.textMuted,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${item.newStock}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: diff > 0 ? AppColors.success : diff < 0 ? AppColors.error : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final stockUpdates = <String, int>{};
              for (final e in matches.entries) {
                stockUpdates[e.key] = e.value.newStock;
              }
              final count = await ref.read(storeProductsProvider.notifier).bulkUpdateStock(stockUpdates);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count urun stoku guncellendi'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: Text('${matches.length} Urunu Guncelle'),
          ),
        ],
      ),
    );
  }

  void _downloadReport(BuildContext context) {
    final products = ref.read(storeProductsProvider).valueOrNull ?? [];
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapor olusturmak icin urun bulunamadi'), backgroundColor: Colors.orange),
      );
      return;
    }

    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    final businessName = merchant?.businessName ?? 'Magaza';
    final now = DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(now);

    final totalProducts = products.length;
    final totalStockValue = products.fold(0.0, (sum, p) => sum + (p.price * p.stock));
    final lowStockCount = products.where((p) => p.isLowStock).length;
    final outOfStockCount = products.where((p) => p.isOutOfStock).length;
    final normalCount = totalProducts - lowStockCount - outOfStockCount;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Stok Yonetimi Raporu', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
            pw.Divider(),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          // Summary stats
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _pdfStatBox('Toplam Urun', '$totalProducts'),
              _pdfStatBox('Stok Degeri', '${NumberFormat.compact().format(totalStockValue)} TL'),
              _pdfStatBox('Normal', '$normalCount', PdfColors.green),
              _pdfStatBox('Dusuk Stok', '$lowStockCount', PdfColors.orange),
              _pdfStatBox('Tukenmis', '$outOfStockCount', PdfColors.red),
            ],
          ),
          pw.SizedBox(height: 20),

          // Products table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
            },
            headers: ['Urun Adi', 'SKU', 'Fiyat (TL)', 'Stok', 'Min.', 'Durum'],
            data: products.map((p) => [
              p.name,
              p.sku ?? '-',
              p.price.toStringAsFixed(2),
              '${p.stock}',
              '${p.lowStockThreshold}',
              p.isOutOfStock ? 'Tukendi' : p.isLowStock ? 'Dusuk' : 'Normal',
            ]).toList(),
          ),
        ],
      ),
    );

    Printing.layoutPdf(
      name: 'Stok_Raporu_${DateFormat('yyyyMMdd').format(now)}',
      onLayout: (format) => pdf.save(),
    );
  }

  pw.Widget _pdfStatBox(String label, String value, [PdfColor color = PdfColors.blueGrey800]) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  void _showUpdateStockDialog(StoreProduct product) {
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Stok Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${product.name} icin eklenecek stok miktarini girin'),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Eklenecek Miktar',
                suffixText: 'adet',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final addStock = int.tryParse(stockController.text) ?? 0;
              ref.read(storeProductsProvider.notifier).updateStock(
                product.id,
                product.stock + addStock,
              );
              Navigator.pop(context);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;

  const _ViewTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementItem extends StatelessWidget {
  final String type;
  final String product;
  final int quantity;
  final DateTime date;
  final String note;

  const _MovementItem({
    required this.type,
    required this.product,
    required this.quantity,
    required this.date,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final isIn = type == 'in';
    final isAdjustment = type == 'adjustment';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIn
                  ? AppColors.success.withAlpha(30)
                  : isAdjustment
                      ? AppColors.warning.withAlpha(30)
                      : AppColors.error.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIn
                  ? Icons.arrow_downward
                  : isAdjustment
                      ? Icons.sync
                      : Icons.arrow_upward,
              color: isIn
                  ? AppColors.success
                  : isAdjustment
                      ? AppColors.warning
                      : AppColors.error,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  note,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${quantity > 0 ? '+' : ''}$quantity',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIn
                      ? AppColors.success
                      : isAdjustment
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
              Text(
                DateFormat('d MMM, HH:mm').format(date),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulkUpdateItem {
  final String name;
  final int currentStock;
  final int newStock;

  _BulkUpdateItem({
    required this.name,
    required this.currentStock,
    required this.newStock,
  });
}
