import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';
import '../../../shared/widgets/pagination_controls.dart';
import '../../invoices/screens/web_download_helper.dart'
    if (dart.library.io) '../../invoices/screens/io_download_helper.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;

  // Sorting
  String _sortColumn = 'created_at';
  bool _sortAscending = false;

  // Data
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  // Bulk operations
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);

      // Build query with server-side filters
      var countQuery = supabase.from('orders').select('id');
      var dataQuery = supabase.from('orders').select('*, merchants(business_name)');

      // Apply search filter (search by order id or customer name)
      if (_searchQuery.isNotEmpty) {
        countQuery = countQuery.or('id.ilike.%$_searchQuery%,customer_name.ilike.%$_searchQuery%');
        dataQuery = dataQuery.or('id.ilike.%$_searchQuery%,customer_name.ilike.%$_searchQuery%');
      }

      // Apply status filter
      if (_statusFilter != 'all') {
        countQuery = countQuery.eq('status', _statusFilter);
        dataQuery = dataQuery.eq('status', _statusFilter);
      }

      final countResponse = await countQuery.count();
      _totalCount = countResponse.count;

      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final response = await dataQuery
          .order(_sortColumn, ascending: _sortAscending)
          .range(from, to);

      if (!mounted) return;
      setState(() {
        _orders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 999999);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? AppColors.surfaceLight
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? AppColors.textPrimary
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? AppColors.textSecondary
        : const Color(0xFF475569);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Siparişler',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tüm siparişleri görüntüleyin ve yönetin',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isSelectionMode && _selectedIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_selectedIds.length} seçili',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _bulkCancelOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Toplu İptal'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _bulkExportSelected,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Seçileni Dışa Aktar'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedIds.clear();
                        }),
                        icon: const Icon(Icons.close),
                        tooltip: 'Seçimi İptal Et',
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _isSelectionMode = !_isSelectionMode,
                        ),
                        icon: Icon(
                          _isSelectionMode ? Icons.close : Icons.checklist,
                          size: 18,
                        ),
                        label: Text(
                          _isSelectionMode ? 'Seçimi Kapat' : 'Toplu İşlem',
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _fetchOrders,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Yenile'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _downloadReport,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Rapor İndir'),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsRow(),

            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            if (mounted) {
                              setState(() {
                                _searchQuery = value;
                                _currentPage = 0;
                              });
                              _fetchOrders();
                            }
                          },
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'Sipariş ara (ID, müşteri)...',
                        prefixIcon: Icon(Icons.search, color: textMuted),
                        filled: true,
                        fillColor: bgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: surfaceColor,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tüm Durumlar'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Bekleyen'),
                          ),
                          DropdownMenuItem(
                            value: 'confirmed',
                            child: Text('Onaylı'),
                          ),
                          DropdownMenuItem(
                            value: 'preparing',
                            child: Text('Hazırlanıyor'),
                          ),
                          DropdownMenuItem(
                            value: 'ready',
                            child: Text('Hazır'),
                          ),
                          DropdownMenuItem(
                            value: 'on_the_way',
                            child: Text('Yolda'),
                          ),
                          DropdownMenuItem(
                            value: 'delivered',
                            child: Text('Teslim Edildi'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('İptal'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value!;
                            _currentPage = 0;
                          });
                          _fetchOrders();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Expanded(
                            child: _buildDataTable(
                              textPrimary,
                              textMuted,
                              bgColor,
                            ),
                          ),
                          PaginationControls(
                            currentPage: _currentPage,
                            totalPages: _totalPages,
                            totalCount: _totalCount,
                            pageSize: _pageSize,
                            onPrevious: () {
                              setState(() => _currentPage--);
                              _fetchOrders();
                            },
                            onNext: () {
                              setState(() => _currentPage++);
                              _fetchOrders();
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_isLoading) {
      return Row(
        children: List.generate(
          5,
          (_) => Expanded(child: _buildStatCardLoading()),
        ),
      );
    }

    final pending = _orders.where((o) => o['status'] == 'pending').length;
    final preparing = _orders.where((o) => o['status'] == 'preparing').length;
    final onTheWay = _orders.where((o) => o['status'] == 'on_the_way').length;
    final delivered = _orders.where((o) => o['status'] == 'delivered').length;

    return Row(
      children: [
        _buildStatCard(
          'Toplam Sipariş',
          _totalCount.toString(),
          Icons.receipt_long,
          AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Bekleyen',
          pending.toString(),
          Icons.pending,
          AppColors.warning,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Hazırlanıyor',
          preparing.toString(),
          Icons.restaurant,
          AppColors.info,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Yolda',
          onTheWay.toString(),
          Icons.delivery_dining,
          AppColors.success,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Teslim',
          delivered.toString(),
          Icons.check_circle,
          AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? AppColors.surfaceLight
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? AppColors.textPrimary
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? AppColors.textSecondary
        : const Color(0xFF475569);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
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
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardLoading() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0),
        ),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildDataTable(Color textPrimary, Color textMuted, Color bgColor) {
    final filteredOrders = _orders;

    if (filteredOrders.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: textMuted),
            const SizedBox(height: 16),
            Text(
              'Sipariş bulunamadı',
              style: TextStyle(color: textPrimary, fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty || _statusFilter != 'all')
              TextButton(
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _statusFilter = 'all';
                }),
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
      headingRowColor: WidgetStateProperty.all(bgColor),
      headingTextStyle: TextStyle(
        color: textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      dataTextStyle: TextStyle(color: textPrimary, fontSize: 14),
      sortColumnIndex: _getSortColumnIndex(),
      sortAscending: _sortAscending,
      columns: [
        if (_isSelectionMode)
          DataColumn2(
            label: Checkbox(
              value:
                  _selectedIds.length == filteredOrders.length &&
                  filteredOrders.isNotEmpty,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.addAll(
                      filteredOrders.map((o) => o['id'].toString()),
                    );
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
            fixedWidth: 50,
          ),
        DataColumn2(
          label: const Text('SİPARİŞ NO'),
          size: ColumnSize.M,
          onSort: (_, asc) => _onSort('id', asc),
        ),
        DataColumn2(
          label: const Text('MÜŞTERİ'),
          size: ColumnSize.L,
          onSort: (_, asc) => _onSort('customer_name', asc),
        ),
        const DataColumn2(label: Text('İŞLETME'), size: ColumnSize.L),
        DataColumn2(
          label: const Text('TUTAR'),
          size: ColumnSize.S,
          onSort: (_, asc) => _onSort('total_amount', asc),
        ),
        DataColumn2(
          label: const Text('TARİH'),
          size: ColumnSize.M,
          onSort: (_, asc) => _onSort('created_at', asc),
        ),
        const DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        const DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: filteredOrders.map((order) {
        final orderId = order['id'].toString();
        return DataRow2(
          selected: _selectedIds.contains(orderId),
          onSelectChanged: _isSelectionMode
              ? (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(orderId);
                    } else {
                      _selectedIds.remove(orderId);
                    }
                  });
                }
              : null,
          cells: [
            if (_isSelectionMode)
              DataCell(
                Checkbox(
                  value: _selectedIds.contains(orderId),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.add(orderId);
                      } else {
                        _selectedIds.remove(orderId);
                      }
                    });
                  },
                ),
              ),
            DataCell(
              Text(
                '#${_getOrderIdShort(order['id'])}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            DataCell(Text(order['customer_name'] ?? 'Müşteri')),
            DataCell(Text(order['merchants']?['business_name'] ?? 'İşletme')),
            DataCell(
              Text('₺${(order['total_amount'] ?? 0).toStringAsFixed(2)}'),
            ),
            DataCell(Text(_formatDate(order['created_at']))),
            DataCell(_buildStatusBadge(order['status'] ?? 'pending')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _viewOrderDetails(order),
                    icon: const Icon(Icons.visibility, size: 18),
                    color: textMuted,
                    tooltip: 'Detay',
                  ),
                  IconButton(
                    onPressed: () => _editOrderStatus(order),
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.info,
                    tooltip: 'Düzenle',
                  ),
                  if (order['status'] != 'delivered' &&
                      order['status'] != 'cancelled')
                    IconButton(
                      onPressed: () => _cancelOrder(order),
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

  int? _getSortColumnIndex() {
    final offset = _isSelectionMode ? 1 : 0;
    switch (_sortColumn) {
      case 'id':
        return 0 + offset;
      case 'customer_name':
        return 1 + offset;
      case 'total_amount':
        return 3 + offset;
      case 'created_at':
        return 4 + offset;
      default:
        return null;
    }
  }

  void _onSort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _currentPage = 0;
    });
    _fetchOrders();
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
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
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

  String _getOrderIdShort(dynamic id) {
    final idStr = (id ?? '').toString();
    return idStr.length >= 8
        ? idStr.substring(0, 8).toUpperCase()
        : idStr.toUpperCase();
  }

  Future<void> _downloadReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor hazırlanıyor...'),
          backgroundColor: AppColors.info,
        ),
      );
      final supabase = ref.read(supabaseProvider);
      final allOrders = await supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);
      final orders = List<Map<String, dynamic>>.from(allOrders);
      final bytes = await InvoiceService.exportOrdersToExcel(orders);
      downloadFile(
        Uint8List.fromList(bytes),
        'siparisler_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor başarıyla indirildi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _bulkExportSelected() async {
    final selected = _orders
        .where((o) => _selectedIds.contains(o['id'].toString()))
        .toList();
    if (selected.isEmpty) return;
    try {
      final bytes = await InvoiceService.exportOrdersToExcel(selected);
      downloadFile(
        Uint8List.fromList(bytes),
        'secili_siparisler_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seçili siparişler dışa aktarıldı'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _bulkCancelOrders() async {
    final cancellableIds = _selectedIds.where((id) {
      final order = _orders.firstWhere(
        (o) => o['id'].toString() == id,
        orElse: () => {},
      );
      return order.isNotEmpty &&
          order['status'] != 'delivered' &&
          order['status'] != 'cancelled';
    }).toList();

    if (cancellableIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İptal edilebilecek sipariş yok'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplu İptal'),
        content: Text(
          '${cancellableIds.length} siparişi iptal etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      final previousStatuses = <String, String>{};

      for (final id in cancellableIds) {
        final order = _orders.firstWhere((o) => o['id'].toString() == id);
        previousStatuses[id] = order['status'] ?? 'pending';
        await supabase
            .from('orders')
            .update({
              'status': 'cancelled',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);
      }

      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${cancellableIds.length} sipariş iptal edildi'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Geri Al',
            textColor: Colors.white,
            onPressed: () async {
              for (final entry in previousStatuses.entries) {
                await supabase
                    .from('orders')
                    .update({
                      'status': entry.value,
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', entry.key);
              }
              _fetchOrders();
            },
          ),
        ),
      );

      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _viewOrderDetails(Map<String, dynamic> order) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: AppColors.primary),
            const SizedBox(width: 12),
            Text('Sipariş Detayı - #${_getOrderIdShort(order['id'])}'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Sipariş ID', order['id']?.toString() ?? '-'),
                const Divider(),
                _buildDetailRow(
                  'Durum',
                  _getStatusText(order['status'] ?? 'pending'),
                ),
                const Divider(),
                _buildDetailRow(
                  'Toplam Tutar',
                  '₺${(order['total_amount'] ?? 0).toStringAsFixed(2)}',
                ),
                const Divider(),
                _buildDetailRow(
                  'Müşteri Adı',
                  order['customer_name']?.toString() ?? '-',
                ),
                const Divider(),
                _buildDetailRow(
                  'İşletme Adı',
                  order['merchants']?['business_name']?.toString() ?? '-',
                ),
                const Divider(),
                _buildDetailRow(
                  'Teslimat Adresi',
                  order['delivery_address']?.toString() ?? '-',
                ),
                const Divider(),
                _buildDetailRow(
                  'Ödeme Yöntemi',
                  order['payment_method']?.toString() ?? '-',
                ),
                const Divider(),
                _buildDetailRow(
                  'Oluşturulma Tarihi',
                  _formatDate(order['created_at']),
                ),
                const Divider(),
                _buildDetailRow(
                  'Güncelleme Tarihi',
                  _formatDate(order['updated_at']),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Bekliyor';
      case 'confirmed':
        return 'Onaylı';
      case 'preparing':
        return 'Hazırlanıyor';
      case 'ready':
        return 'Hazır';
      case 'on_the_way':
        return 'Yolda';
      case 'delivered':
        return 'Teslim Edildi';
      case 'cancelled':
        return 'İptal';
      default:
        return status;
    }
  }

  Future<void> _editOrderStatus(Map<String, dynamic> order) async {
    String? selectedStatus = order['status'];
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppColors.info),
            const SizedBox(width: 12),
            const Text('Sipariş Durumu Düzenle'),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sipariş: #${_getOrderIdShort(order['id'])}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Bekliyor'),
                      ),
                      DropdownMenuItem(
                        value: 'confirmed',
                        child: Text('Onaylı'),
                      ),
                      DropdownMenuItem(
                        value: 'preparing',
                        child: Text('Hazırlanıyor'),
                      ),
                      DropdownMenuItem(value: 'ready', child: Text('Hazır')),
                      DropdownMenuItem(
                        value: 'on_the_way',
                        child: Text('Yolda'),
                      ),
                      DropdownMenuItem(
                        value: 'delivered',
                        child: Text('Teslim Edildi'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('İptal'),
                      ),
                    ],
                    onChanged: (v) => setState(() => selectedStatus = v),
                  ),
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
            onPressed: () => Navigator.pop(context, selectedStatus),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (result != null && result != order['status']) {
      final previousStatus = order['status'] ?? 'pending';
      try {
        final supabase = ref.read(supabaseProvider);
        await supabase
            .from('orders')
            .update({
              'status': result,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', order['id']);
        if (!mounted) return;

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sipariş durumu güncellendi'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Geri Al',
              textColor: Colors.white,
              onPressed: () async {
                await supabase
                    .from('orders')
                    .update({
                      'status': previousStatus,
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', order['id']);
                _fetchOrders();
              },
            ),
          ),
        );
        _fetchOrders();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: AppColors.error),
            const SizedBox(width: 12),
            const Text('Siparişi İptal Et'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sipariş #${_getOrderIdShort(order['id'])} iptal edilecek.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bu işlem geri alınabilir.',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previousStatus = order['status'] ?? 'pending';
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('orders')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', order['id']);
      if (!mounted) return;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sipariş iptal edildi'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Geri Al',
            textColor: Colors.white,
            onPressed: () async {
              await supabase
                  .from('orders')
                  .update({
                    'status': previousStatus,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', order['id']);
              _fetchOrders();
            },
          ),
        ),
      );
      _fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
