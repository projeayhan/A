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

class _AdminInventoryScreenState extends ConsumerState<AdminInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Helpers ---

  int _getLowStockCount(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final stock = (item['stock'] as num?)?.toInt() ?? 0;
      final minStock = (item['low_stock_threshold'] as num?)?.toInt() ?? 5;
      return stock > 0 && stock <= minStock;
    }).length;
  }

  int _getOutOfStockCount(List<Map<String, dynamic>> items) {
    return items.where((item) {
      final stock = (item['stock'] as num?)?.toInt() ?? 0;
      return stock <= 0;
    }).length;
  }

  double _getTotalInventoryValue(List<Map<String, dynamic>> items) {
    return items.fold(0.0, (sum, item) {
      final stock = (item['stock'] as num?)?.toDouble() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0;
      return sum + (stock * price);
    });
  }

  String _getStockStatus(Map<String, dynamic> item) {
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final minStock = (item['low_stock_threshold'] as num?)?.toInt() ?? 5;
    if (stock <= 0) return 'out';
    if (stock <= minStock) return 'low';
    return 'normal';
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    var filtered = items;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        final name = (item['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    }

    if (_selectedCategory != 'all') {
      filtered = filtered.where((item) {
        final isAvailable = item['is_available'] as bool? ?? true;
        switch (_selectedCategory) {
          case 'available':
            return isAvailable;
          case 'unavailable':
            return !isAvailable;
          case 'low_stock':
            return _getStockStatus(item) == 'low';
          case 'out_of_stock':
            return _getStockStatus(item) == 'out';
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _getLowStockItems(
      List<Map<String, dynamic>> items) {
    return items.where((item) {
      final status = _getStockStatus(item);
      return status == 'low' || status == 'out';
    }).toList();
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M TL';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K TL';
    }
    return '${value.toStringAsFixed(0)} TL';
  }

  Future<void> _updateStock(String itemId, int newVal) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('products')
          .update({'stock': newVal}).eq('id', itemId);
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
              content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleAvailability(String itemId, bool currentValue) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('products')
          .update({'is_available': !currentValue}).eq('id', itemId);
      ref.invalidate(merchantInventoryProvider(widget.merchantId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showQuickStockUpdateDialog(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final name = item['name'] as String? ?? '-';
    final currentStock = (item['stock'] as num?)?.toInt() ?? 0;
    int newStock = currentStock;
    final controller = TextEditingController(text: currentStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.inventory_2, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mevcut Stok: $currentStock',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decrement by 10
                  _buildStockButton(
                    icon: Icons.remove,
                    label: '-10',
                    onPressed: () {
                      setDialogState(() {
                        newStock = (newStock - 10).clamp(0, 999999);
                        controller.text = newStock.toString();
                      });
                    },
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  // Decrement by 1
                  _buildStockButton(
                    icon: Icons.remove,
                    label: '-1',
                    onPressed: () {
                      setDialogState(() {
                        newStock = (newStock - 1).clamp(0, 999999);
                        controller.text = newStock.toString();
                      });
                    },
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 12),
                  // Stock input
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          newStock = int.tryParse(val) ?? 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Increment by 1
                  _buildStockButton(
                    icon: Icons.add,
                    label: '+1',
                    onPressed: () {
                      setDialogState(() {
                        newStock = (newStock + 1).clamp(0, 999999);
                        controller.text = newStock.toString();
                      });
                    },
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  // Increment by 10
                  _buildStockButton(
                    icon: Icons.add,
                    label: '+10',
                    onPressed: () {
                      setDialogState(() {
                        newStock = (newStock + 10).clamp(0, 999999);
                        controller.text = newStock.toString();
                      });
                    },
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (newStock != currentStock)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (newStock > currentStock
                            ? AppColors.success
                            : AppColors.warning)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    newStock > currentStock
                        ? '+${newStock - currentStock} adet eklenecek'
                        : '${newStock - currentStock} adet azaltılacak',
                    style: TextStyle(
                      color: newStock > currentStock
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'İptal',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: newStock == currentStock
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _updateStock(itemId, newStock);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(
      merchantInventoryProvider(widget.merchantId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: inventoryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Veriler yüklenirken hata oluştu',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(
                  merchantInventoryProvider(widget.merchantId),
                ),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (items) => _buildMainContent(items),
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> items) {
    final totalProducts = items.length;
    final lowStockCount = _getLowStockCount(items);
    final outOfStockCount = _getOutOfStockCount(items);
    final totalValue = _getTotalInventoryValue(items);
    final lowStockItems = _getLowStockItems(items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(
                  color: AppColors.surfaceLight.withValues(alpha: 0.5)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Stok Yönetimi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ürün stok durumlarını görüntüleyin ve güncelleyin',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),

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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Toplam Değer',
                      value: _formatCurrency(totalValue),
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Düşük Stok',
                      value: lowStockCount.toString(),
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
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
              const SizedBox(height: 20),

              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.dashboard_outlined, size: 20),
                    text: 'Genel Bakış',
                  ),
                  const Tab(
                    icon: Icon(Icons.swap_vert, size: 20),
                    text: 'Stok Hareketleri',
                  ),
                  Tab(
                    icon: Badge(
                      isLabelVisible: lowStockItems.isNotEmpty,
                      label: Text(
                        lowStockItems.length.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      backgroundColor: AppColors.error,
                      child: const Icon(Icons.notifications_outlined, size: 20),
                    ),
                    text: 'Uyarılar',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(items),
              _buildMovementsTab(),
              _buildAlertsTab(lowStockItems),
            ],
          ),
        ),
      ],
    );
  }

  // --- Summary Card ---

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Overview Tab ---

  Widget _buildOverviewTab(List<Map<String, dynamic>> items) {
    final filteredItems = _filterItems(items);

    return Column(
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: AppColors.surface,
          child: Row(
            children: [
              // Search
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ürün ara...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppColors.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 16),
              // Category filter
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.filter_list,
                        color: AppColors.textMuted, size: 20),
                  ),
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Tüm Ürünler')),
                    DropdownMenuItem(
                        value: 'available', child: Text('Aktif')),
                    DropdownMenuItem(
                        value: 'unavailable', child: Text('Pasif')),
                    DropdownMenuItem(
                        value: 'low_stock', child: Text('Düşük Stok')),
                    DropdownMenuItem(
                        value: 'out_of_stock', child: Text('Stok Dışı')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Result count
              Text(
                '${filteredItems.length} ürün',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),

        // Product list
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Aramanızla eşleşen ürün bulunamadı'
                            : 'Henüz ürün bulunmuyor',
                        style:
                            const TextStyle(color: AppColors.textMuted, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildProductCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final itemId = item['id'] as String;
    final name = item['name'] as String? ?? '-';
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final minStock = (item['low_stock_threshold'] as num?)?.toInt() ?? 5;
    final isAvailable = item['is_available'] as bool? ?? true;
    final imageUrl = item['image_url'] as String?;
    final status = _getStockStatus(item);
    final itemValue = stock * price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'out'
              ? AppColors.error.withValues(alpha: 0.3)
              : status == 'low'
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.surfaceLight.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Product image
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              image: imageUrl != null && imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageUrl == null || imageUrl.isEmpty
                ? const Icon(Icons.image_outlined,
                    color: AppColors.textMuted, size: 24)
                : null,
          ),
          const SizedBox(width: 16),

          // Product info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${price.toStringAsFixed(2)} TL',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),

          // Stock value
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Stok Değeri',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(itemValue),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Stock quantity with status
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildStatusBadge(status),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$stock',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: status == 'out'
                              ? AppColors.error
                              : status == 'low'
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' / $minStock',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Availability toggle
          Column(
            children: [
              const Text(
                'Aktif',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Switch(
                value: isAvailable,
                onChanged: (val) => _toggleAvailability(itemId, isAvailable),
                activeTrackColor: AppColors.success.withValues(alpha: 0.4),
                activeThumbColor: AppColors.success,
                inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.3),
                inactiveThumbColor: AppColors.textMuted,
              ),
            ],
          ),

          const SizedBox(width: 8),

          // Quick stock update button
          IconButton(
            onPressed: () => _showQuickStockUpdateDialog(item),
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: 'Stok Güncelle',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Movements Tab ---

  Widget _buildMovementsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchStockMovements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final movements = snapshot.data ?? [];

        if (movements.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                const Text(
                  'Henüz stok hareketi bulunmuyor',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stok güncellemeleri yaptığınızda hareketler burada görünecek.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: movements.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final m = movements[index];
            final productName =
                m['product_name'] as String? ?? m['product_id'] as String? ?? '-';
            final quantity = (m['quantity'] as num?)?.toInt() ?? 0;
            final type = m['type'] as String? ?? 'düzeltme';
            final createdAt = m['created_at'] as String? ?? '';

            String typeLabel;
            Color typeColor;
            IconData typeIcon;
            switch (type) {
              case 'giris':
              case 'giriş':
              case 'in':
                typeLabel = 'Giriş';
                typeColor = AppColors.success;
                typeIcon = Icons.arrow_downward;
                break;
              case 'cikis':
              case 'çıkış':
              case 'out':
                typeLabel = 'Çıkış';
                typeColor = AppColors.error;
                typeIcon = Icons.arrow_upward;
                break;
              default:
                typeLabel = 'Düzeltme';
                typeColor = AppColors.warning;
                typeIcon = Icons.edit;
            }

            final isPositive =
                type == 'giris' || type == 'giriş' || type == 'in' || quantity > 0;
            final quantityPrefix = isPositive ? '+' : '';
            final dateStr = _formatMovementDate(createdAt);

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.surfaceLight.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$typeLabel • $dateStr',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$quantityPrefix$quantity',
                    style: TextStyle(
                      color: isPositive ? AppColors.success : AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchStockMovements() async {
    try {
      final data = await ref
          .read(supabaseProvider)
          .from('stock_movements')
          .select()
          .eq('merchant_id', widget.merchantId)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  String _formatMovementDate(String isoDate) {
    if (isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day.$month.$year $hour:$minute';
    } catch (_) {
      return isoDate;
    }
  }

  // --- Alerts Tab ---

  Widget _buildAlertsTab(List<Map<String, dynamic>> lowStockItems) {
    if (lowStockItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 80, color: AppColors.success),
            const SizedBox(height: 24),
            const Text(
              'Tüm stoklar yeterli seviyede',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Düşük stok veya tükenen ürün bulunmuyor.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Separate out-of-stock and low-stock
    final outOfStock = lowStockItems
        .where((item) => _getStockStatus(item) == 'out')
        .toList();
    final lowStock = lowStockItems
        .where((item) => _getStockStatus(item) == 'low')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Out of stock section
          if (outOfStock.isNotEmpty) ...[
            _buildAlertSection(
              title: 'Tükenen Ürünler',
              subtitle: '${outOfStock.length} ürün stokta yok',
              icon: Icons.remove_shopping_cart,
              color: AppColors.error,
              items: outOfStock,
            ),
            const SizedBox(height: 24),
          ],

          // Low stock section
          if (lowStock.isNotEmpty)
            _buildAlertSection(
              title: 'Düşük Stok Uyarıları',
              subtitle: '${lowStock.length} ürün minimum stok seviyesinin altında',
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              items: lowStock,
            ),
        ],
      ),
    );
  }

  Widget _buildAlertSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
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
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) {
            final name = item['name'] as String? ?? '-';
            final stock = (item['stock'] as num?)?.toInt() ?? 0;
            final minStock =
                (item['low_stock_threshold'] as num?)?.toInt() ?? 5;
            final status = _getStockStatus(item);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    status == 'out'
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status == 'out'
                              ? 'Stok tükendi!'
                              : 'Stok: $stock adet (Min: $minStock)',
                          style: TextStyle(color: color, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Stock progress
                  if (status == 'low') ...[
                    SizedBox(
                      width: 80,
                      child: Column(
                        children: [
                          Text(
                            '$stock/$minStock',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: minStock > 0
                                  ? (stock / minStock).clamp(0.0, 1.0)
                                  : 0,
                              backgroundColor: color.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => _showQuickStockUpdateDialog(item),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Stok Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  // --- Status Badge ---

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
        label = 'Düşük';
        color = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      default:
        label = 'Normal';
        color = AppColors.success;
        icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
