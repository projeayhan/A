import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Orders provider
final ordersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('orders')
      .select()
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(response);
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

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
                      'Siparişler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm siparişleri görüntüleyin ve yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(ordersProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Rapor İndir'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsRow(ordersAsync),

            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Sipariş ara (ID, müşteri)...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tüm Durumlar')),
                          DropdownMenuItem(value: 'pending', child: Text('Bekleyen')),
                          DropdownMenuItem(value: 'confirmed', child: Text('Onaylı')),
                          DropdownMenuItem(value: 'preparing', child: Text('Hazırlanıyor')),
                          DropdownMenuItem(value: 'ready', child: Text('Hazır')),
                          DropdownMenuItem(value: 'on_the_way', child: Text('Yolda')),
                          DropdownMenuItem(value: 'delivered', child: Text('Teslim Edildi')),
                          DropdownMenuItem(value: 'cancelled', child: Text('İptal')),
                        ],
                        onChanged: (value) => setState(() => _statusFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: const Text('Filtrele'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: ordersAsync.when(
                  data: (orders) => _buildDataTable(orders),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('Henüz sipariş yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Hata: $e', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(AsyncValue<List<Map<String, dynamic>>> ordersAsync) {
    return ordersAsync.when(
      data: (orders) {
        final pending = orders.where((o) => o['status'] == 'pending').length;
        final preparing = orders.where((o) => o['status'] == 'preparing').length;
        final onTheWay = orders.where((o) => o['status'] == 'on_the_way').length;
        final delivered = orders.where((o) => o['status'] == 'delivered').length;

        return Row(
          children: [
            _buildStatCard('Toplam Sipariş', orders.length.toString(), Icons.receipt_long, AppColors.primary),
            const SizedBox(width: 16),
            _buildStatCard('Bekleyen', pending.toString(), Icons.pending, AppColors.warning),
            const SizedBox(width: 16),
            _buildStatCard('Hazırlanıyor', preparing.toString(), Icons.restaurant, AppColors.info),
            const SizedBox(width: 16),
            _buildStatCard('Yolda', onTheWay.toString(), Icons.delivery_dining, AppColors.success),
            const SizedBox(width: 16),
            _buildStatCard('Teslim', delivered.toString(), Icons.check_circle, AppColors.success),
          ],
        );
      },
      loading: () => Row(children: List.generate(5, (_) => Expanded(child: _buildStatCardLoading()))),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
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
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardLoading() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> orders) {
    var filteredOrders = orders.where((order) {
      final id = (order['id'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || id.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'all' || order['status'] == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Sipariş bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            if (_searchQuery.isNotEmpty || _statusFilter != 'all')
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _statusFilter = 'all';
                  });
                },
                child: const Text('Filtreleri Temizle'),
              ),
          ],
        ),
      );
    }

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 1200,
      headingRowColor: WidgetStateProperty.all(AppColors.background),
      headingTextStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12),
      dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      columns: const [
        DataColumn2(label: Text('SİPARİŞ NO'), size: ColumnSize.M),
        DataColumn2(label: Text('MÜŞTERİ'), size: ColumnSize.L),
        DataColumn2(label: Text('İŞLETME'), size: ColumnSize.L),
        DataColumn2(label: Text('TUTAR'), size: ColumnSize.S),
        DataColumn2(label: Text('TARİH'), size: ColumnSize.M),
        DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: filteredOrders.map((order) {
        return DataRow2(
          cells: [
            DataCell(
              Text(
                '#${(order['id'] ?? '').toString().substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ),
            DataCell(Text(order['customer_name'] ?? 'Müşteri')),
            DataCell(Text(order['merchant_name'] ?? 'İşletme')),
            DataCell(Text('₺${(order['total_amount'] ?? 0).toStringAsFixed(2)}')),
            DataCell(Text(_formatDate(order['created_at']))),
            DataCell(_buildStatusBadge(order['status'] ?? 'pending')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Detay',
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.info,
                    tooltip: 'Düzenle',
                  ),
                  if (order['status'] != 'delivered' && order['status'] != 'cancelled')
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.cancel, size: 18),
                      color: AppColors.error,
                      tooltip: 'İptal Et',
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'pending':
        color = AppColors.warning;
        text = 'Bekliyor';
        break;
      case 'confirmed':
        color = AppColors.info;
        text = 'Onaylı';
        break;
      case 'preparing':
        color = AppColors.info;
        text = 'Hazırlanıyor';
        break;
      case 'ready':
        color = AppColors.success;
        text = 'Hazır';
        break;
      case 'on_the_way':
        color = AppColors.primary;
        text = 'Yolda';
        break;
      case 'delivered':
        color = AppColors.success;
        text = 'Teslim';
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
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }
}
