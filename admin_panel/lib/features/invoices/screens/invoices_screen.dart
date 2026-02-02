import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/theme/app_theme.dart';

// Web download helper - conditionally imported
import 'web_download_helper.dart' if (dart.library.io) 'io_download_helper.dart';

// Date Range State
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Payments Provider with date filter
final paymentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final dateRange = ref.watch(dateRangeProvider);

  var query = supabase
      .from('payments')
      .select('*, rides(*), users(*)');

  if (dateRange != null) {
    query = query
        .gte('created_at', dateRange.start.toIso8601String())
        .lte('created_at', dateRange.end.add(const Duration(days: 1)).toIso8601String());
  }

  final response = await query.order('created_at', ascending: false).limit(500);
  return List<Map<String, dynamic>>.from(response);
});

// Food Orders Provider with date filter
final foodOrdersForInvoiceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final dateRange = ref.watch(dateRangeProvider);

  var query = supabase
      .from('food_orders')
      .select('*, users(*), merchants(*)');

  if (dateRange != null) {
    query = query
        .gte('created_at', dateRange.start.toIso8601String())
        .lte('created_at', dateRange.end.add(const Duration(days: 1)).toIso8601String());
  }

  final response = await query.order('created_at', ascending: false).limit(500);
  return List<Map<String, dynamic>>.from(response);
});

// Invoice Archive Provider
final invoiceArchiveProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  try {
    final response = await supabase
        .from('invoices')
        .select('*')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    // Tablo yoksa bos liste don
    return [];
  }
});

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPaymentType = 'all';
  String _selectedStatus = 'all';

  // Coklu secim
  final Set<String> _selectedPaymentIds = {};
  final Set<String> _selectedOrderIds = {};
  bool _isSelectionMode = false;

  // Manuel fatura formu
  final _customerNameController = TextEditingController();
  final _customerTaxController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final List<_InvoiceItemController> _invoiceItems = [];
  double _kdvRate = 20.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _addInvoiceItem();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameController.dispose();
    _customerTaxController.dispose();
    _customerAddressController.dispose();
    for (var item in _invoiceItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _addInvoiceItem() {
    setState(() {
      _invoiceItems.add(_InvoiceItemController());
    });
  }

  void _removeInvoiceItem(int index) {
    if (_invoiceItems.length > 1) {
      setState(() {
        _invoiceItems[index].dispose();
        _invoiceItems.removeAt(index);
      });
    }
  }

  double get _subtotal => _invoiceItems.fold(0, (sum, item) => sum + item.total);
  double get _kdvAmount => _subtotal * _kdvRate / 100;
  double get _grandTotal => _subtotal + _kdvAmount;

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(dateRangeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fatura ve Odeme Yonetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tum odemeleri ve faturalari yonetin, yazdir veya indir',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isSelectionMode && (_selectedPaymentIds.isNotEmpty || _selectedOrderIds.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ElevatedButton.icon(
                          onPressed: _exportSelectedToPdf,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text('Secilenleri PDF (${_selectedPaymentIds.length + _selectedOrderIds.length})'),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _exportToExcel,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Excel Indir'),
                    ),
                    const SizedBox(width: 12),
                    if (dateRange != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          onPressed: () => ref.read(dateRangeProvider.notifier).state = null,
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Tarih filtresini temizle',
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _showDateRangeDialog(),
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(dateRange != null
                          ? '${_formatDateShort(dateRange.start)} - ${_formatDateShort(dateRange.end)}'
                          : 'Tarih Sec'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(text: 'Taksi Odemeleri'),
                Tab(text: 'Yemek Siparis Odemeleri'),
                Tab(text: 'Fatura Olustur'),
                Tab(text: 'Fatura Arsivi'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaxiPaymentsTab(),
                _buildFoodOrderPaymentsTab(),
                _buildInvoiceGeneratorTab(),
                _buildInvoiceArchiveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxiPaymentsTab() {
    final paymentsAsync = ref.watch(paymentsProvider);

    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (payments) {
        // Filter payments
        var filtered = payments;
        if (_selectedPaymentType != 'all') {
          filtered = filtered.where((p) => p['payment_type'] == _selectedPaymentType).toList();
        }
        if (_selectedStatus != 'all') {
          filtered = filtered.where((p) => p['status'] == _selectedStatus).toList();
        }

        // Calculate totals
        final totalAmount = payments.fold<double>(0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0));
        final completedAmount = payments.where((p) => p['status'] == 'completed').fold<double>(0, (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Stats Row
              Row(
                children: [
                  _buildStatCard('Toplam Islem', payments.length.toString(), Icons.receipt_long, AppColors.primary),
                  const SizedBox(width: 16),
                  _buildStatCard('Toplam Tutar', '${totalAmount.toStringAsFixed(2)} TL', Icons.payments, AppColors.success),
                  const SizedBox(width: 16),
                  _buildStatCard('Tamamlanan', '${completedAmount.toStringAsFixed(2)} TL', Icons.check_circle, AppColors.info),
                  const SizedBox(width: 16),
                  _buildStatCard('Iade Edilen', '${payments.where((p) => p['refund_amount'] != null).length}', Icons.replay, AppColors.warning),
                ],
              ),
              const SizedBox(height: 16),

              // Filters & Selection Toggle
              Row(
                children: [
                  // Selection Mode Toggle
                  FilterChip(
                    label: Text(_isSelectionMode ? 'Secim Modu Acik' : 'Toplu Secim'),
                    selected: _isSelectionMode,
                    onSelected: (value) {
                      setState(() {
                        _isSelectionMode = value;
                        if (!value) {
                          _selectedPaymentIds.clear();
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 16),
                  // Payment Type Filter
                  DropdownButton<String>(
                    value: _selectedPaymentType,
                    hint: const Text('Odeme Tipi'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tum Tipler')),
                      DropdownMenuItem(value: 'cash', child: Text('Nakit')),
                      DropdownMenuItem(value: 'card', child: Text('Kart')),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                    ],
                    onChanged: (value) => setState(() => _selectedPaymentType = value!),
                  ),
                  const SizedBox(width: 16),
                  // Status Filter
                  DropdownButton<String>(
                    value: _selectedStatus,
                    hint: const Text('Durum'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Tum Durumlar')),
                      DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                      DropdownMenuItem(value: 'completed', child: Text('Tamamlandi')),
                      DropdownMenuItem(value: 'failed', child: Text('Basarisiz')),
                      DropdownMenuItem(value: 'refunded', child: Text('Iade Edildi')),
                    ],
                    onChanged: (value) => setState(() => _selectedStatus = value!),
                  ),
                  const Spacer(),
                  if (_isSelectionMode && _selectedPaymentIds.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selectedPaymentIds.clear()),
                      child: Text('Secimi Temizle (${_selectedPaymentIds.length})'),
                    ),
                  Text('${filtered.length} kayit', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 16),

              // Table
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      columns: [
                        if (_isSelectionMode)
                          DataColumn2(
                            label: Checkbox(
                              value: _selectedPaymentIds.length == filtered.length && filtered.isNotEmpty,
                              tristate: true,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedPaymentIds.addAll(filtered.map((p) => p['id'].toString()));
                                  } else {
                                    _selectedPaymentIds.clear();
                                  }
                                });
                              },
                            ),
                            size: ColumnSize.S,
                          ),
                        const DataColumn2(label: Text('ID'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Tarih'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Kullanici'), size: ColumnSize.M),
                        const DataColumn2(label: Text('Surucu'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Tutar'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Tip'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Islemler'), size: ColumnSize.M),
                      ],
                      rows: filtered.map((payment) {
                        final paymentId = payment['id'].toString();
                        final isSelected = _selectedPaymentIds.contains(paymentId);

                        return DataRow2(
                          selected: isSelected,
                          onSelectChanged: _isSelectionMode ? (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedPaymentIds.add(paymentId);
                              } else {
                                _selectedPaymentIds.remove(paymentId);
                              }
                            });
                          } : null,
                          cells: [
                            if (_isSelectionMode)
                              DataCell(Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedPaymentIds.add(paymentId);
                                    } else {
                                      _selectedPaymentIds.remove(paymentId);
                                    }
                                  });
                                },
                              )),
                            DataCell(Text('#${payment['id']?.toString().substring(0, 8) ?? ''}')),
                            DataCell(Text(_formatDate(payment['created_at']))),
                            DataCell(Text(payment['users']?['full_name'] ?? payment['user_id']?.toString().substring(0, 8) ?? '-')),
                            DataCell(Text(payment['driver_id']?.toString().substring(0, 8) ?? '-')),
                            DataCell(Text('${payment['amount']} ${payment['currency'] ?? 'TRY'}')),
                            DataCell(_buildPaymentTypeBadge(payment['payment_type'])),
                            DataCell(_buildStatusBadge(payment['status'])),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18),
                                  onPressed: () => _showPaymentDetail(payment),
                                  tooltip: 'Detay',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.print, size: 18),
                                  onPressed: () => _printInvoice(payment),
                                  tooltip: 'Fatura Yazdir',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                                  onPressed: () => _downloadInvoicePdf(payment),
                                  tooltip: 'PDF Indir',
                                ),
                                if (payment['status'] == 'completed' && payment['refund_amount'] == null)
                                  IconButton(
                                    icon: const Icon(Icons.replay, size: 18, color: AppColors.warning),
                                    onPressed: () => _showRefundDialog(payment),
                                    tooltip: 'Iade Et',
                                  ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFoodOrderPaymentsTab() {
    final ordersAsync = ref.watch(foodOrdersForInvoiceProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (orders) {
        final totalAmount = orders.fold<double>(0, (sum, o) => sum + (double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Stats Row
              Row(
                children: [
                  _buildStatCard('Toplam Siparis', orders.length.toString(), Icons.shopping_bag, AppColors.primary),
                  const SizedBox(width: 16),
                  _buildStatCard('Toplam Tutar', '${totalAmount.toStringAsFixed(2)} TL', Icons.payments, AppColors.success),
                  const SizedBox(width: 16),
                  _buildStatCard('Tamamlanan', orders.where((o) => o['status'] == 'delivered').length.toString(), Icons.check_circle, AppColors.info),
                  const SizedBox(width: 16),
                  _buildStatCard('Iptal Edilen', orders.where((o) => o['status'] == 'cancelled').length.toString(), Icons.cancel, AppColors.error),
                ],
              ),
              const SizedBox(height: 16),

              // Selection Toggle
              Row(
                children: [
                  FilterChip(
                    label: Text(_isSelectionMode ? 'Secim Modu Acik' : 'Toplu Secim'),
                    selected: _isSelectionMode,
                    onSelected: (value) {
                      setState(() {
                        _isSelectionMode = value;
                        if (!value) {
                          _selectedOrderIds.clear();
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const Spacer(),
                  if (_isSelectionMode && _selectedOrderIds.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _selectedOrderIds.clear()),
                      child: Text('Secimi Temizle (${_selectedOrderIds.length})'),
                    ),
                  Text('${orders.length} kayit', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 16),

              // Table
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      columns: [
                        if (_isSelectionMode)
                          DataColumn2(
                            label: Checkbox(
                              value: _selectedOrderIds.length == orders.length && orders.isNotEmpty,
                              tristate: true,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedOrderIds.addAll(orders.map((o) => o['id'].toString()));
                                  } else {
                                    _selectedOrderIds.clear();
                                  }
                                });
                              },
                            ),
                            size: ColumnSize.S,
                          ),
                        const DataColumn2(label: Text('Siparis No'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Tarih'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Musteri'), size: ColumnSize.M),
                        const DataColumn2(label: Text('Isletme'), size: ColumnSize.M),
                        const DataColumn2(label: Text('Tutar'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Odeme'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Durum'), size: ColumnSize.S),
                        const DataColumn2(label: Text('Islemler'), size: ColumnSize.S),
                      ],
                      rows: orders.map((order) {
                        final orderId = order['id'].toString();
                        final isSelected = _selectedOrderIds.contains(orderId);

                        return DataRow2(
                          selected: isSelected,
                          cells: [
                            if (_isSelectionMode)
                              DataCell(Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedOrderIds.add(orderId);
                                    } else {
                                      _selectedOrderIds.remove(orderId);
                                    }
                                  });
                                },
                              )),
                            DataCell(Text('#${order['id']?.toString().substring(0, 8) ?? ''}')),
                            DataCell(Text(_formatDate(order['created_at']))),
                            DataCell(Text(order['users']?['full_name'] ?? '-')),
                            DataCell(Text(order['merchants']?['name'] ?? '-')),
                            DataCell(Text('${order['total_amount']} TL')),
                            DataCell(_buildPaymentTypeBadge(order['payment_method'])),
                            DataCell(_buildOrderStatusBadge(order['status'])),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.print, size: 18),
                                  onPressed: () => _printFoodOrderInvoice(order),
                                  tooltip: 'Fatura Yazdir',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                                  onPressed: () => _downloadFoodOrderPdf(order),
                                  tooltip: 'PDF Indir',
                                ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoiceGeneratorTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Form
          Expanded(
            flex: 2,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Manuel Fatura Olustur', style: Theme.of(context).textTheme.titleLarge),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Fatura No: ${InvoiceService.generateInvoiceNumber()}',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sirket Bilgileri Ozeti
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.surfaceLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Satici: ${InvoiceService.companyInfo['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Vergi Dairesi: ${InvoiceService.companyInfo['taxOffice']} - ${InvoiceService.companyInfo['taxNumber']}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Customer Info
                      Text('Musteri Bilgileri', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customerNameController,
                              decoration: const InputDecoration(labelText: 'Musteri Adi *'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _customerTaxController,
                              decoration: const InputDecoration(labelText: 'Vergi No / TC'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customerAddressController,
                        decoration: const InputDecoration(labelText: 'Adres'),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 24),

                      // Invoice Items
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fatura Kalemleri', style: Theme.of(context).textTheme.titleSmall),
                          Row(
                            children: [
                              Text('KDV: ', style: Theme.of(context).textTheme.bodySmall),
                              SizedBox(
                                width: 80,
                                child: DropdownButton<double>(
                                  value: _kdvRate,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 0.0, child: Text('%0')),
                                    DropdownMenuItem(value: 1.0, child: Text('%1')),
                                    DropdownMenuItem(value: 10.0, child: Text('%10')),
                                    DropdownMenuItem(value: 20.0, child: Text('%20')),
                                  ],
                                  onChanged: (value) => setState(() => _kdvRate = value!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: const [
                                Expanded(flex: 3, child: Text('Aciklama', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(child: Text('Miktar', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Expanded(child: Text('Birim Fiyat', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Expanded(child: Text('Toplam', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                SizedBox(width: 40),
                              ],
                            ),
                            const Divider(),
                            ..._invoiceItems.asMap().entries.map((entry) => _buildInvoiceItemRow(entry.key)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _addInvoiceItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Kalem Ekle'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Totals
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildTotalRow('Ara Toplam', '${_subtotal.toStringAsFixed(2)} TL'),
                              _buildTotalRow('KDV (%${_kdvRate.toInt()})', '${_kdvAmount.toStringAsFixed(2)} TL'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Text('Genel Toplam: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${_grandTotal.toStringAsFixed(2)} TL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _clearForm,
                            child: const Text('Temizle'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _createAndSaveInvoice,
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Fatura Olustur ve Kaydet'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Preview
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Onizleme', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Preview Header
                              Text(
                                InvoiceService.companyInfo['name']!,
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'Musteri: ${_customerNameController.text.isEmpty ? '-' : _customerNameController.text}',
                                style: const TextStyle(color: Colors.black54, fontSize: 11),
                              ),
                              if (_customerTaxController.text.isNotEmpty)
                                Text(
                                  'Vergi/TC: ${_customerTaxController.text}',
                                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                                ),
                              const SizedBox(height: 16),
                              ..._invoiceItems.where((item) => item.description.text.isNotEmpty).map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(item.description.text, style: const TextStyle(color: Colors.black87, fontSize: 11))),
                                    Text('${item.total.toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.black87, fontSize: 11)),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.grey),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOPLAM', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('${_grandTotal.toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _previewPdf,
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Yazdir'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _downloadManualInvoicePdf,
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('PDF'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceArchiveTab() {
    final archiveAsync = ref.watch(invoiceArchiveProvider);

    return archiveAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.archive_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Fatura arsivi yuklenemedi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$err', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      data: (invoices) {
        if (invoices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.archive_outlined, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text('Henuz kayitli fatura yok', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Manuel fatura olusturdugunda burada gorunecek', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                children: [
                  _buildStatCard('Toplam Fatura', invoices.length.toString(), Icons.receipt, AppColors.primary),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Toplam Tutar',
                    '${invoices.fold<double>(0, (sum, i) => sum + (double.tryParse(i['total']?.toString() ?? '0') ?? 0)).toStringAsFixed(2)} TL',
                    Icons.payments,
                    AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 12,
                      columns: const [
                        DataColumn2(label: Text('Fatura No'), size: ColumnSize.M),
                        DataColumn2(label: Text('Tarih'), size: ColumnSize.S),
                        DataColumn2(label: Text('Musteri'), size: ColumnSize.L),
                        DataColumn2(label: Text('Tutar'), size: ColumnSize.S),
                        DataColumn2(label: Text('Islemler'), size: ColumnSize.S),
                      ],
                      rows: invoices.map((invoice) {
                        return DataRow2(
                          cells: [
                            DataCell(Text(invoice['invoice_number'] ?? '-')),
                            DataCell(Text(_formatDate(invoice['created_at']))),
                            DataCell(Text(invoice['customer_name'] ?? '-')),
                            DataCell(Text('${invoice['total'] ?? 0} TL')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 18),
                                  onPressed: () => _showArchivedInvoiceDetail(invoice),
                                  tooltip: 'Detay',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                                  onPressed: () => _downloadArchivedInvoicePdf(invoice),
                                  tooltip: 'PDF Indir',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                                  onPressed: () => _deleteArchivedInvoice(invoice),
                                  tooltip: 'Sil',
                                ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoiceItemRow(int index) {
    final item = _invoiceItems[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.description,
              decoration: const InputDecoration(
                hintText: 'Aciklama',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: item.quantity,
              decoration: const InputDecoration(
                hintText: '1',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: item.unitPrice,
              decoration: const InputDecoration(
                hintText: '0.00',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.total.toStringAsFixed(2)} TL',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, size: 18, color: _invoiceItems.length > 1 ? AppColors.error : AppColors.textMuted),
            onPressed: _invoiceItems.length > 1 ? () => _removeInvoiceItem(index) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 48),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTypeBadge(String? type) {
    Color color;
    IconData icon;
    String label;
    switch (type) {
      case 'cash':
        color = AppColors.success;
        icon = Icons.money;
        label = 'Nakit';
        break;
      case 'card':
        color = AppColors.info;
        icon = Icons.credit_card;
        label = 'Kart';
        break;
      case 'online':
        color = AppColors.primary;
        icon = Icons.phone_android;
        label = 'Online';
        break;
      default:
        color = AppColors.textMuted;
        icon = Icons.payment;
        label = type ?? '-';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = AppColors.success;
        label = 'Tamamlandi';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Bekliyor';
        break;
      case 'failed':
        color = AppColors.error;
        label = 'Basarisiz';
        break;
      case 'refunded':
        color = AppColors.info;
        label = 'Iade Edildi';
        break;
      default:
        color = AppColors.textMuted;
        label = status ?? '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildOrderStatusBadge(String? status) {
    Color color;
    String label;
    switch (status) {
      case 'delivered':
        color = AppColors.success;
        label = 'Teslim Edildi';
        break;
      case 'preparing':
        color = AppColors.warning;
        label = 'Hazirlaniyor';
        break;
      case 'on_the_way':
        color = AppColors.info;
        label = 'Yolda';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'Iptal';
        break;
      default:
        color = AppColors.textMuted;
        label = status ?? '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }

  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}';
  }

  void _showDateRangeDialog() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: ref.read(dateRangeProvider),
    );

    if (picked != null) {
      ref.read(dateRangeProvider.notifier).state = picked;
    }
  }

  void _showPaymentDetail(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Odeme Detayi #${payment['id']?.toString().substring(0, 8)}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Tutar', '${payment['amount']} ${payment['currency'] ?? 'TRY'}'),
              _buildDetailRow('Yolculuk Ucreti', '${payment['ride_fare'] ?? 0} TL'),
              _buildDetailRow('Bahsis', '${payment['tip_amount'] ?? 0} TL'),
              _buildDetailRow('Gecis Ucreti', '${payment['toll_amount'] ?? 0} TL'),
              _buildDetailRow('Indirim', '${payment['discount_amount'] ?? 0} TL'),
              _buildDetailRow('Odeme Tipi', payment['payment_type'] ?? '-'),
              _buildDetailRow('Durum', payment['status'] ?? '-'),
              _buildDetailRow('Saglayici', payment['provider'] ?? '-'),
              if (payment['refund_amount'] != null) ...[
                const Divider(),
                _buildDetailRow('Iade Tutari', '${payment['refund_amount']} TL'),
                _buildDetailRow('Iade Nedeni', payment['refund_reason'] ?? '-'),
              ],
            ],
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showRefundDialog(Map<String, dynamic> payment) {
    final reasonController = TextEditingController();
    final amountController = TextEditingController(text: payment['amount']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Iade Yap'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Iade Tutari (TL)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Iade Nedeni'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final supabase = ref.read(supabaseProvider);
              await supabase.from('payments').update({
                'refund_amount': double.tryParse(amountController.text),
                'refund_reason': reasonController.text,
                'refunded_at': DateTime.now().toIso8601String(),
                'status': 'refunded',
              }).eq('id', payment['id']);

              ref.invalidate(paymentsProvider);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Iade Yap'),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(Map<String, dynamic> payment) async {
    try {
      final invoiceNumber = InvoiceService.generateInvoiceNumber();
      final pdfBytes = await InvoiceService.generateInvoicePdf(
        payment: payment,
        invoiceNumber: invoiceNumber,
      );

      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yazdirilirken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _downloadInvoicePdf(Map<String, dynamic> payment) async {
    try {
      final invoiceNumber = InvoiceService.generateInvoiceNumber();
      final pdfBytes = await InvoiceService.generateInvoicePdf(
        payment: payment,
        invoiceNumber: invoiceNumber,
      );

      _downloadFile(pdfBytes, 'fatura_$invoiceNumber.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF indirildi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF olusturulurken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _printFoodOrderInvoice(Map<String, dynamic> order) async {
    try {
      final invoiceNumber = InvoiceService.generateInvoiceNumber(prefix: 'YMK');
      final pdfBytes = await InvoiceService.generateFoodOrderInvoicePdf(
        order: order,
        invoiceNumber: invoiceNumber,
      );

      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yazdirilirken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _downloadFoodOrderPdf(Map<String, dynamic> order) async {
    try {
      final invoiceNumber = InvoiceService.generateInvoiceNumber(prefix: 'YMK');
      final pdfBytes = await InvoiceService.generateFoodOrderInvoicePdf(
        order: order,
        invoiceNumber: invoiceNumber,
      );

      _downloadFile(pdfBytes, 'siparis_fatura_$invoiceNumber.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF indirildi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF olusturulurken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final currentTab = _tabController.index;
      List<int> excelBytes;
      String filename;

      if (currentTab == 0) {
        final payments = ref.read(paymentsProvider).valueOrNull ?? [];
        excelBytes = await InvoiceService.exportPaymentsToExcel(payments);
        filename = 'taksi_odemeleri_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      } else if (currentTab == 1) {
        final orders = ref.read(foodOrdersForInvoiceProvider).valueOrNull ?? [];
        excelBytes = await InvoiceService.exportFoodOrdersToExcel(orders);
        filename = 'yemek_siparisleri_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      } else {
        return;
      }

      _downloadFile(Uint8List.fromList(excelBytes), filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel dosyasi indirildi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel olusturulurken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportSelectedToPdf() async {
    if (_selectedPaymentIds.isEmpty && _selectedOrderIds.isEmpty) return;

    try {
      final payments = ref.read(paymentsProvider).valueOrNull ?? [];
      final orders = ref.read(foodOrdersForInvoiceProvider).valueOrNull ?? [];

      int count = 0;

      for (final id in _selectedPaymentIds) {
        final payment = payments.firstWhere((p) => p['id'].toString() == id, orElse: () => {});
        if (payment.isNotEmpty) {
          await _downloadInvoicePdf(payment);
          count++;
        }
      }

      for (final id in _selectedOrderIds) {
        final order = orders.firstWhere((o) => o['id'].toString() == id, orElse: () => {});
        if (order.isNotEmpty) {
          await _downloadFoodOrderPdf(order);
          count++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count adet fatura indirildi'), backgroundColor: AppColors.success),
        );
      }

      setState(() {
        _selectedPaymentIds.clear();
        _selectedOrderIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _clearForm() {
    setState(() {
      _customerNameController.clear();
      _customerTaxController.clear();
      _customerAddressController.clear();
      for (var item in _invoiceItems) {
        item.dispose();
      }
      _invoiceItems.clear();
      _addInvoiceItem();
      _kdvRate = 20.0;
    });
  }

  Future<void> _createAndSaveInvoice() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musteri adi gerekli'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_invoiceItems.isEmpty || _invoiceItems.every((item) => item.description.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir fatura kalemi gerekli'), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final invoiceNumber = InvoiceService.generateInvoiceNumber(prefix: 'MNL');
      final supabase = ref.read(supabaseProvider);

      // Fatura verisini kaydet
      await supabase.from('invoices').insert({
        'invoice_number': invoiceNumber,
        'customer_name': _customerNameController.text,
        'customer_tax_number': _customerTaxController.text.isEmpty ? null : _customerTaxController.text,
        'customer_address': _customerAddressController.text.isEmpty ? null : _customerAddressController.text,
        'items': _invoiceItems.map((item) => {
          'description': item.description.text,
          'quantity': item.quantityValue,
          'unit_price': item.unitPriceValue,
          'total': item.total,
        }).toList(),
        'subtotal': _subtotal,
        'kdv_rate': _kdvRate,
        'kdv_amount': _kdvAmount,
        'total': _grandTotal,
        'created_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(invoiceArchiveProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fatura $invoiceNumber kaydedildi'), backgroundColor: AppColors.success),
        );
      }

      _clearForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fatura kaydedilirken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _previewPdf() async {
    // TODO: Implement preview
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Onizleme hazirlaniyor...')),
    );
  }

  Future<void> _downloadManualInvoicePdf() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musteri adi gerekli'), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final invoiceNumber = InvoiceService.generateInvoiceNumber(prefix: 'MNL');

      // Manuel fatura icin basit bir payment objesi olustur
      final payment = {
        'amount': _grandTotal.toString(),
        'payment_type': 'manual',
        'users': {'full_name': _customerNameController.text},
      };

      final pdfBytes = await InvoiceService.generateInvoicePdf(
        payment: payment,
        invoiceNumber: invoiceNumber,
        customerInfo: {
          'name': _customerNameController.text,
          'taxNumber': _customerTaxController.text,
          'address': _customerAddressController.text,
        },
        invoiceType: 'MANUEL FATURA',
      );

      _downloadFile(pdfBytes, 'manuel_fatura_$invoiceNumber.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF indirildi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF olusturulurken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showArchivedInvoiceDetail(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fatura ${invoice['invoice_number']}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Musteri', invoice['customer_name'] ?? '-'),
              if (invoice['customer_tax_number'] != null)
                _buildDetailRow('Vergi/TC No', invoice['customer_tax_number']),
              if (invoice['customer_address'] != null)
                _buildDetailRow('Adres', invoice['customer_address']),
              const Divider(),
              _buildDetailRow('Ara Toplam', '${invoice['subtotal']} TL'),
              _buildDetailRow('KDV (%${invoice['kdv_rate']?.toInt() ?? 20})', '${invoice['kdv_amount']} TL'),
              _buildDetailRow('Toplam', '${invoice['total']} TL'),
              _buildDetailRow('Tarih', _formatDate(invoice['created_at'])),
            ],
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

  Future<void> _downloadArchivedInvoicePdf(Map<String, dynamic> invoice) async {
    try {
      final payment = {
        'amount': invoice['total'].toString(),
        'payment_type': 'manual',
        'users': {'full_name': invoice['customer_name']},
      };

      final pdfBytes = await InvoiceService.generateInvoicePdf(
        payment: payment,
        invoiceNumber: invoice['invoice_number'],
        customerInfo: {
          'name': invoice['customer_name'] ?? '',
          'taxNumber': invoice['customer_tax_number'] ?? '',
          'address': invoice['customer_address'] ?? '',
        },
        invoiceType: 'FATURA',
      );

      _downloadFile(pdfBytes, 'fatura_${invoice['invoice_number']}.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF indirildi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF olusturulurken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteArchivedInvoice(Map<String, dynamic> invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fatura Sil'),
        content: Text('${invoice['invoice_number']} numarali faturayi silmek istediginizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = ref.read(supabaseProvider);
        await supabase.from('invoices').delete().eq('id', invoice['id']);
        ref.invalidate(invoiceArchiveProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fatura silindi'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Silinirken hata: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _downloadFile(Uint8List bytes, String filename) {
    downloadFile(bytes, filename);
  }
}

// Invoice Item Controller Helper
class _InvoiceItemController {
  final TextEditingController description = TextEditingController();
  final TextEditingController quantity = TextEditingController(text: '1');
  final TextEditingController unitPrice = TextEditingController(text: '0');

  int get quantityValue => int.tryParse(quantity.text) ?? 0;
  double get unitPriceValue => double.tryParse(unitPrice.text) ?? 0;
  double get total => quantityValue * unitPriceValue;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
