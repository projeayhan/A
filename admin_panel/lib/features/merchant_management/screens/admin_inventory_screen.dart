import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';
import '../../../core/services/supabase_service.dart';

class AdminInventoryScreen extends ConsumerStatefulWidget {
  final String merchantId;
  const AdminInventoryScreen({super.key, required this.merchantId});

  @override
  ConsumerState<AdminInventoryScreen> createState() =>
      _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen> {
  String? _editingItemId;
  final TextEditingController _stockController = TextEditingController();
  bool _isUpdating = false;

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  int _getLowStockCount(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final stock = (item['stock_quantity'] as num?)?.toInt() ?? 0;
      final minStock = (item['min_stock_level'] as num?)?.toInt() ?? 5;
      return stock > 0 && stock <= minStock;
    }).length;
  }

  int _getOutOfStockCount(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final stock = (item['stock_quantity'] as num?)?.toInt() ?? 0;
      return stock <= 0;
    }).length;
  }

  String _getStockStatus(Map<String, dynamic> item) {
    final stock = (item['stock_quantity'] as num?)?.toInt() ?? 0;
    final minStock = (item['min_stock_level'] as num?)?.toInt() ?? 5;
    if (stock <= 0) return 'out';
    if (stock <= minStock) return 'low';
    return 'normal';
  }

  Color _getRowColor(String status) {
    switch (status) {
      case 'out':
        return AppColors.error.withOpacity(0.08);
      case 'low':
        return AppColors.warning.withOpacity(0.08);
      default:
        return Colors.transparent;
    }
  }

  Future<void> _updateStock(String itemId, int newVal) async {
    setState(() => _isUpdating = true);
    try {
      await ref
          .read(supabaseProvider)
          .from('products')
          .update({'stock_quantity': newVal}).eq('id', itemId);
      ref.invalidate(merchantInventoryProvider(widget.merchantId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stok güncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _editingItemId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync =
        ref.watch(merchantInventoryProvider(widget.merchantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Stok Yönetimi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ürün stok durumlarını görüntüleyin ve güncelleyin',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: inventoryAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Veriler yüklenirken hata oluştu',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(
                            merchantInventoryProvider(widget.merchantId)),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
                data: (items) => _buildContent(items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> items) {
    final totalProducts = items.length;
    final lowStockCount = _getLowStockCount(items);
    final outOfStockCount = _getOutOfStockCount(items);

    return Column(
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Toplam Ürün',
                value: totalProducts.toString(),
                icon: Icons.inventory_2_outlined,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                title: 'Düşük Stok',
                value: lowStockCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                title: 'Stok Dışı',
                value: outOfStockCount.toString(),
                icon: Icons.remove_shopping_cart_outlined,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Data Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
            ),
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz ürün bulunmuyor',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.surfaceLight.withOpacity(0.3),
                          ),
                          headingTextStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          dataTextStyle: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          columnSpacing: 24,
                          columns: const [
                            DataColumn(label: Text('Ürün Adı')),
                            DataColumn(
                                label: Text('Stok Miktarı'), numeric: true),
                            DataColumn(
                                label: Text('Min. Stok'), numeric: true),
                            DataColumn(label: Text('Durum')),
                            DataColumn(label: Text('İşlem')),
                          ],
                          rows: items.map((item) {
                            final itemId = item['id'] as String;
                            final name = item['name'] as String? ?? '-';
                            final stock =
                                (item['stock_quantity'] as num?)?.toInt() ?? 0;
                            final minStock =
                                (item['min_stock_level'] as num?)?.toInt() ?? 5;
                            final status = _getStockStatus(item);
                            final isEditing = _editingItemId == itemId;

                            return DataRow(
                              color: WidgetStateProperty.all(
                                  _getRowColor(status)),
                              cells: [
                                // Name
                                DataCell(
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                // Stock Quantity (editable)
                                DataCell(
                                  isEditing
                                      ? SizedBox(
                                          width: 80,
                                          child: TextField(
                                            controller: _stockController,
                                            autofocus: true,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 14,
                                            ),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                              filled: true,
                                              fillColor: AppColors.surfaceLight,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                borderSide: const BorderSide(
                                                    color: AppColors.primary),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                borderSide: const BorderSide(
                                                    color: AppColors.primary),
                                              ),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          stock.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: status == 'out'
                                                ? AppColors.error
                                                : status == 'low'
                                                    ? AppColors.warning
                                                    : AppColors.textPrimary,
                                          ),
                                        ),
                                  onTap: () {
                                    setState(() {
                                      _editingItemId = itemId;
                                      _stockController.text = stock.toString();
                                    });
                                  },
                                ),
                                // Min Stock Level
                                DataCell(Text(minStock.toString())),
                                // Status
                                DataCell(_buildStatusBadge(status)),
                                // Action
                                DataCell(
                                  isEditing
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: _isUpdating
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.check_circle,
                                                      color: AppColors.success,
                                                      size: 20,
                                                    ),
                                              onPressed: _isUpdating
                                                  ? null
                                                  : () {
                                                      final newVal = int.tryParse(
                                                          _stockController
                                                              .text);
                                                      if (newVal != null) {
                                                        _updateStock(
                                                            itemId, newVal);
                                                      }
                                                    },
                                              tooltip: 'Kaydet',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.cancel,
                                                color: AppColors.textMuted,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _editingItemId = null;
                                                });
                                              },
                                              tooltip: 'İptal',
                                            ),
                                          ],
                                        )
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: AppColors.textSecondary,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _editingItemId = itemId;
                                              _stockController.text =
                                                  stock.toString();
                                            });
                                          },
                                          tooltip: 'Stok Güncelle',
                                        ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final String label;
    final Color color;
    final IconData icon;

    switch (status) {
      case 'out':
        label = 'Stok Dışı';
        color = AppColors.error;
        icon = Icons.error_outline;
        break;
      case 'low':
        label = 'Düşük Stok';
        color = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      default:
        label = 'Normal';
        color = AppColors.success;
        icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
