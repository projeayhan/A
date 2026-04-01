import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/theme/app_theme.dart';

// Web download helper - conditionally imported
import '../../invoices/screens/web_download_helper.dart'
    if (dart.library.io) '../../invoices/screens/io_download_helper.dart';

// Reuse providers from invoices screen
import '../../invoices/screens/invoices_screen.dart'
    show paymentsProvider, ordersForInvoiceProvider, rentalBookingsForInvoiceProvider, dateRangeProvider;

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  String _customerSourceFilter = 'all';
  String _selectedPaymentType = 'all';
  String _selectedStatus = 'all';

  // Toplu secim
  final Set<String> _selectedPaymentIds = {};
  final Set<String> _selectedOrderIds = {};
  bool _isSelectionMode = false;
  bool _isBulkExporting = false;

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsProvider);
    final ordersAsync = ref.watch(ordersForInvoiceProvider);
    final rentalsAsync = ref.watch(rentalBookingsForInvoiceProvider);
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
                      'Siparis Gecmisi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tum siparis ve islem gecmisi',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isSelectionMode &&
                        (_selectedPaymentIds.isNotEmpty ||
                            _selectedOrderIds.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ElevatedButton.icon(
                          onPressed: _exportSelectedToPdf,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: Text(
                            'Secilenleri PDF (${_selectedPaymentIds.length + _selectedOrderIds.length})',
                          ),
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
                          onPressed: () =>
                              ref.read(dateRangeProvider.notifier).state = null,
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Tarih filtresini temizle',
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _showDateRangeDialog(),
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        dateRange != null
                            ? '${_formatDateShort(dateRange.start)} - ${_formatDateShort(dateRange.end)}'
                            : 'Tarih Sec',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tumu'),
                    selected: _customerSourceFilter == 'all',
                    onSelected: (_) =>
                        setState(() => _customerSourceFilter = 'all'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Taksi'),
                    selected: _customerSourceFilter == 'taxi',
                    onSelected: (_) =>
                        setState(() => _customerSourceFilter = 'taxi'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Yemek'),
                    selected: _customerSourceFilter == 'restaurant',
                    onSelected: (_) =>
                        setState(() => _customerSourceFilter = 'restaurant'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Market'),
                    selected: _customerSourceFilter == 'market',
                    onSelected: (_) =>
                        setState(() => _customerSourceFilter = 'market'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Magaza'),
                    selected: _customerSourceFilter == 'store',
                    onSelected: (_) =>
                        setState(() => _customerSourceFilter = 'store'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Arac Kiralama'),
                    selected: _customerSourceFilter == 'rental',
                    onSelected: (_) =>
                        setState(() => _customerSourceFilter = 'rental'),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 16),
                  // Odeme tipi filtresi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPaymentType,
                        hint: const Text('Odeme Tipi'),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tum Tipler'),
                          ),
                          DropdownMenuItem(value: 'cash', child: Text('Nakit')),
                          DropdownMenuItem(value: 'card', child: Text('Kart')),
                          DropdownMenuItem(
                            value: 'online',
                            child: Text('Online'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedPaymentType = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Durum filtresi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        hint: const Text('Durum'),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tum Durumlar'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Bekliyor'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Tamamlandi'),
                          ),
                          DropdownMenuItem(
                            value: 'delivered',
                            child: Text('Teslim Edildi'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Iptal'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedStatus = value!),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Toplu secim
                  FilterChip(
                    label: Text(
                      _isSelectionMode ? 'Secim Modu Acik' : 'Toplu Secim',
                    ),
                    selected: _isSelectionMode,
                    onSelected: (value) {
                      setState(() {
                        _isSelectionMode = value;
                        if (!value) {
                          _selectedPaymentIds.clear();
                          _selectedOrderIds.clear();
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildContent(paymentsAsync, ordersAsync, rentalsAsync),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    AsyncValue<List<Map<String, dynamic>>> paymentsAsync,
    AsyncValue<List<Map<String, dynamic>>> ordersAsync,
    AsyncValue<List<Map<String, dynamic>>> rentalsAsync,
  ) {
    if (paymentsAsync is AsyncLoading ||
        ordersAsync is AsyncLoading ||
        rentalsAsync is AsyncLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (paymentsAsync is AsyncError) {
      return Center(child: Text('Hata: ${paymentsAsync.error}'));
    }
    if (ordersAsync is AsyncError) {
      return Center(child: Text('Hata: ${ordersAsync.error}'));
    }
    if (rentalsAsync is AsyncError) {
      return Center(child: Text('Hata: ${rentalsAsync.error}'));
    }

    final payments = paymentsAsync.valueOrNull ?? [];
    final orders = ordersAsync.valueOrNull ?? [];
    final rentals = rentalsAsync.valueOrNull ?? [];

    // Birlesik satir listesi olustur
    List<_OrderHistoryRow> rows = [];

    // Taksi odemeleri
    if (_customerSourceFilter == 'all' || _customerSourceFilter == 'taxi') {
      for (final p in payments) {
        if (_selectedPaymentType != 'all' &&
            p['payment_type'] != _selectedPaymentType) {
          continue;
        }
        if (_selectedStatus != 'all' && p['status'] != _selectedStatus) {
          continue;
        }
        rows.add(
          _OrderHistoryRow(
            id: p['id']?.toString() ?? '',
            date: p['created_at']?.toString() ?? '',
            customerName:
                p['users']?['full_name'] ??
                p['user_id']?.toString().substring(0, 8) ??
                '-',
            source: 'Taksi',
            amount: double.tryParse(p['amount']?.toString() ?? '0') ?? 0,
            paymentType: p['payment_type'] ?? p['payment_method'],
            status: p['status'],
            rawData: p,
            type: 'taxi',
          ),
        );
      }
    }

    // Siparisler (yemek, market, magaza)
    for (final o in orders) {
      final merchantType = o['merchants']?['type']?.toString() ?? 'restaurant';
      if (_customerSourceFilter != 'all' &&
          _customerSourceFilter != merchantType) {
        continue;
      }
      if (_selectedStatus != 'all' && o['status'] != _selectedStatus) continue;
      final payMethod = o['payment_method']?.toString() ?? '';
      if (_selectedPaymentType != 'all' && payMethod != _selectedPaymentType) {
        continue;
      }

      String sourceLabel;
      switch (merchantType) {
        case 'market':
          sourceLabel = 'Market';
          break;
        case 'store':
          sourceLabel = 'Magaza';
          break;
        default:
          sourceLabel = 'Yemek';
      }

      rows.add(
        _OrderHistoryRow(
          id: o['id']?.toString() ?? '',
          date: o['created_at']?.toString() ?? '',
          customerName:
              o['user_info']?['full_name'] ?? o['customer_name'] ?? '-',
          source: sourceLabel,
          detail: o['merchants']?['business_name'] ?? '-',
          amount: double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0,
          paymentType: payMethod,
          status: o['status'],
          rawData: o,
          type: merchantType,
        ),
      );
    }

    // Arac kiralama rezervasyonlari
    if (_customerSourceFilter == 'all' || _customerSourceFilter == 'rental') {
      for (final r in rentals) {
        if (_selectedStatus != 'all' && r['status'] != _selectedStatus) {
          continue;
        }
        final payMethod = r['payment_method']?.toString() ?? '';
        if (_selectedPaymentType != 'all' &&
            payMethod != _selectedPaymentType) {
          continue;
        }
        rows.add(
          _OrderHistoryRow(
            id: r['id']?.toString() ?? '',
            date: r['created_at']?.toString() ?? '',
            customerName:
                r['user_info']?['full_name'] ?? r['customer_name'] ?? '-',
            source: 'Arac Kiralama',
            detail: r['booking_number'] ?? '-',
            amount: double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0,
            paymentType: payMethod,
            status: r['status'],
            rawData: r,
            type: 'rental',
          ),
        );
      }
    }

    // Tarihe gore sirala (yeniden eskiye)
    rows.sort((a, b) => b.date.compareTo(a.date));

    final totalAmount = rows.fold<double>(0, (s, r) => s + r.amount);

    return Column(
      children: [
        // Stats
        Row(
          children: [
            _buildStatCard(
              'Toplam Islem',
              rows.length.toString(),
              Icons.receipt_long,
              AppColors.primary,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Toplam Tutar',
              '${totalAmount.toStringAsFixed(2)} TL',
              Icons.payments,
              AppColors.success,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Taksi',
              rows.where((r) => r.type == 'taxi').length.toString(),
              Icons.local_taxi,
              AppColors.info,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Siparis',
              rows
                  .where(
                    (r) =>
                        r.type == 'restaurant' ||
                        r.type == 'market' ||
                        r.type == 'store',
                  )
                  .length
                  .toString(),
              Icons.shopping_bag,
              AppColors.warning,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              'Kiralama',
              rows.where((r) => r.type == 'rental').length.toString(),
              Icons.directions_car,
              AppColors.success,
            ),
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
                minWidth: 1200,
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                headingTextStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                dataTextStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                columns: const [
                  DataColumn2(label: Text('ID'), fixedWidth: 100),
                  DataColumn2(label: Text('Tarih'), fixedWidth: 130),
                  DataColumn2(label: Text('Musteri'), size: ColumnSize.M),
                  DataColumn2(label: Text('Kaynak'), fixedWidth: 110),
                  DataColumn2(label: Text('Detay'), size: ColumnSize.M),
                  DataColumn2(label: Text('Tutar'), fixedWidth: 110),
                  DataColumn2(label: Text('Odeme'), fixedWidth: 100),
                  DataColumn2(label: Text('Durum'), fixedWidth: 120),
                  DataColumn2(label: Text('Islemler'), fixedWidth: 130),
                ],
                rows: rows.map((row) {
                  return DataRow2(
                    cells: [
                      DataCell(
                        Text(
                          '#${row.id.length > 8 ? row.id.substring(0, 8) : row.id}',
                        ),
                      ),
                      DataCell(Text(_formatDate(row.date))),
                      DataCell(Text(row.customerName)),
                      DataCell(_buildSourceBadge(row.source, row.type)),
                      DataCell(Text(row.detail)),
                      DataCell(Text('${row.amount.toStringAsFixed(2)} TL')),
                      DataCell(_buildPaymentTypeBadge(row.paymentType)),
                      DataCell(
                        row.type == 'taxi'
                            ? _buildStatusBadge(row.status)
                            : _buildOrderStatusBadge(row.status),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (row.type == 'taxi') ...[
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 18),
                                onPressed: () =>
                                    _showPaymentDetail(row.rawData),
                                tooltip: 'Detay',
                              ),
                              IconButton(
                                icon: const Icon(Icons.print, size: 18),
                                onPressed: () => _printOrderSummary(row.rawData),
                                tooltip: 'Siparis Ozeti',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    _downloadInvoicePdf(row.rawData),
                                tooltip: 'PDF Indir',
                              ),
                              if (row.rawData['status'] == 'completed' &&
                                  row.rawData['refund_amount'] == null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.replay,
                                    size: 18,
                                    color: AppColors.warning,
                                  ),
                                  onPressed: () =>
                                      _showRefundDialog(row.rawData),
                                  tooltip: 'Iade Et',
                                ),
                              FutureBuilder<bool>(
                                future: _hasRefundInvoice(
                                  row.rawData['ride_id']?.toString() ??
                                      row.rawData['id']?.toString() ??
                                      '',
                                ),
                                builder: (context, snap) {
                                  final hasRefund = snap.data ?? false;
                                  final refundAmt =
                                      double.tryParse(
                                        row.rawData['refund_amount']
                                                ?.toString() ??
                                            '0',
                                      ) ??
                                      0;
                                  if (refundAmt <= 0 || hasRefund) {
                                    return const SizedBox.shrink();
                                  }
                                  return IconButton(
                                    icon: const Icon(
                                      Icons.assignment_return,
                                      size: 18,
                                      color: AppColors.warning,
                                    ),
                                    tooltip: 'Iade Faturasi Kes',
                                    onPressed: () =>
                                        _createRefundInvoice(row.rawData),
                                  );
                                },
                              ),
                            ],
                            if (row.type == 'restaurant' ||
                                row.type == 'market' ||
                                row.type == 'store') ...[
                              IconButton(
                                icon: const Icon(Icons.print, size: 18),
                                onPressed: () =>
                                    _printFoodOrderSummary(row.rawData),
                                tooltip: 'Siparis Ozeti',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    _downloadFoodOrderPdf(row.rawData),
                                tooltip: 'PDF Indir',
                              ),
                            ],
                            if (row.type == 'rental') ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    _downloadRentalBookingPdf(row.rawData),
                                tooltip: 'PDF Indir',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
      case 'credit_card_on_delivery':
        color = AppColors.info;
        icon = Icons.credit_card;
        label = 'Kart';
        break;
      case 'cash_on_delivery':
        color = AppColors.success;
        icon = Icons.money;
        label = 'Nakit';
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

  Widget _buildSourceBadge(String source, String type) {
    Color color;
    switch (type) {
      case 'taxi':
        color = AppColors.info;
        break;
      case 'restaurant':
        color = AppColors.warning;
        break;
      case 'market':
        color = AppColors.success;
        break;
      case 'store':
        color = AppColors.primary;
        break;
      case 'rental':
        color = const Color(0xFF9C27B0);
        break;
      default:
        color = AppColors.textMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        source,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
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
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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

  // ==================== FORMATTING ====================

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

  String _sanitizeForFileName(String name) {
    const tr = 'cCgGiIoOsSuU';
    const en = 'cCgGiIoOsSuU';
    var result = name;
    for (var i = 0; i < tr.length; i++) {
      result = result.replaceAll(tr[i], en[i]);
    }
    return result
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  void _downloadFile(Uint8List bytes, String filename) {
    downloadFile(bytes, filename);
  }

  // ==================== ACTIONS ====================

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
        title: Text(
          'Siparis Detayi #${payment['id']?.toString().substring(0, 8)}',
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Tutar',
                '${payment['amount']} ${payment['currency'] ?? 'TRY'}',
              ),
              _buildDetailRow(
                'Yolculuk Ucreti',
                '${payment['ride_fare'] ?? 0} TL',
              ),
              _buildDetailRow('Bahsis', '${payment['tip_amount'] ?? 0} TL'),
              _buildDetailRow(
                'Gecis Ucreti',
                '${payment['toll_amount'] ?? 0} TL',
              ),
              _buildDetailRow(
                'Indirim',
                '${payment['discount_amount'] ?? 0} TL',
              ),
              _buildDetailRow('Odeme Tipi', payment['payment_type'] ?? '-'),
              _buildDetailRow('Durum', payment['status'] ?? '-'),
              _buildDetailRow('Saglayici', payment['provider'] ?? '-'),
              if (payment['refund_amount'] != null) ...[
                const Divider(),
                _buildDetailRow(
                  'Iade Tutari',
                  '${payment['refund_amount']} TL',
                ),
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

  void _showRefundDialog(Map<String, dynamic> payment) {
    final reasonController = TextEditingController();
    final amountController = TextEditingController(
      text: payment['amount']?.toString() ?? '0',
    );

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
                decoration: const InputDecoration(
                  labelText: 'Iade Tutari (TL)',
                ),
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
              await supabase
                  .from('payments')
                  .update({
                    'refund_amount': double.tryParse(amountController.text),
                    'refund_reason': reasonController.text,
                    'refunded_at': DateTime.now().toIso8601String(),
                    'status': 'refunded',
                  })
                  .eq('id', payment['id']);

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

  Future<void> _printOrderSummary(Map<String, dynamic> payment) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final paymentId = payment['id']?.toString() ?? '';
      final existing = await supabase
          .from('invoices')
          .select('invoice_number')
          .eq('source_type', 'taxi_payment')
          .eq('source_id', paymentId)
          .maybeSingle();
      final invoiceNumber =
          existing?['invoice_number'] as String? ??
          'YAZDIR-${paymentId.length > 8 ? paymentId.substring(0, 8) : paymentId}';

      final pdfBytes = await InvoiceService.generateInvoicePdf(
        payment: payment,
        invoiceNumber: invoiceNumber,
      );

      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yazdirilirken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadInvoicePdf(Map<String, dynamic> payment) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final paymentId = payment['id']?.toString() ?? '';

      final existing = await supabase
          .from('invoices')
          .select('id, invoice_number, pdf_url')
          .eq('source_type', 'taxi_payment')
          .eq('source_id', paymentId)
          .maybeSingle();

      if (existing != null && existing['pdf_url'] != null) {
        await launchUrl(
          Uri.parse(existing['pdf_url'] as String),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
      const kdvRate = 20.0;
      final kdvAmount = amount * kdvRate / (100 + kdvRate);
      final subtotal = amount - kdvAmount;

      final result = await InvoiceService.saveInvoice(
        sourceType: 'taxi_payment',
        sourceId: paymentId,
        buyerName: payment['users']?['full_name'] ?? 'Bilinmeyen Alici',
        subtotal: subtotal,
        kdvRate: kdvRate,
        kdvAmount: kdvAmount,
        total: amount,
        items: [
          {
            'description': 'Taksi Yolculuk Hizmeti',
            'quantity': 1,
            'unit_price': subtotal,
            'total': subtotal,
          },
        ],
      );

      final pdfUrl = result['pdf_url'] as String?;
      if (pdfUrl != null) {
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        final invoiceNumber =
            result['invoice_number'] as String? ??
            await InvoiceService.generateInvoiceNumberFromDB();
        final pdfBytes = await InvoiceService.generateInvoicePdf(
          payment: payment,
          invoiceNumber: invoiceNumber,
        );
        final driverName = payment['users']?['full_name'] ?? 'surucu';
        final safeName = _sanitizeForFileName(driverName);
        _downloadFile(pdfBytes, '${safeName}_siparis_$invoiceNumber.pdf');
      }

      if (mounted && !_isBulkExporting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Siparis ozeti kaydedildi ve indiriliyor'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF olusturulurken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _printFoodOrderSummary(Map<String, dynamic> order) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final orderId = order['id']?.toString() ?? '';
      final existing = await supabase
          .from('invoices')
          .select('invoice_number')
          .eq('source_type', 'food_order')
          .eq('source_id', orderId)
          .maybeSingle();
      final invoiceNumber =
          existing?['invoice_number'] as String? ??
          'YAZDIR-${orderId.length > 8 ? orderId.substring(0, 8) : orderId}';

      final pdfBytes = await InvoiceService.generateFoodOrderInvoicePdf(
        order: order,
        invoiceNumber: invoiceNumber,
      );

      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yazdirilirken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadFoodOrderPdf(Map<String, dynamic> order) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final orderId = order['id']?.toString() ?? '';

      final existing = await supabase
          .from('invoices')
          .select('id, invoice_number, pdf_url')
          .eq('source_type', 'food_order')
          .eq('source_id', orderId)
          .maybeSingle();

      if (existing != null && existing['pdf_url'] != null) {
        await launchUrl(
          Uri.parse(existing['pdf_url'] as String),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      final amount =
          double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0;
      const kdvRate = 10.0;
      final kdvAmount = amount * kdvRate / (100 + kdvRate);
      final subtotal = amount - kdvAmount;

      final result = await InvoiceService.saveInvoice(
        sourceType: 'food_order',
        sourceId: orderId,
        buyerName:
            order['user_info']?['full_name'] ??
            order['customer_name'] ??
            'Bilinmeyen Alici',
        subtotal: subtotal,
        kdvRate: kdvRate,
        kdvAmount: kdvAmount,
        total: amount,
        items: [
          {
            'description':
                'Siparis #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
            'quantity': 1,
            'unit_price': subtotal,
            'total': subtotal,
          },
        ],
      );

      final pdfUrl = result['pdf_url'] as String?;
      if (pdfUrl != null) {
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        final invoiceNumber =
            result['invoice_number'] as String? ??
            await InvoiceService.generateInvoiceNumberFromDB();
        final pdfBytes = await InvoiceService.generateFoodOrderInvoicePdf(
          order: order,
          invoiceNumber: invoiceNumber,
        );
        final merchantName =
            order['merchants']?['name'] ?? order['merchant_name'] ?? 'isletme';
        final safeName = _sanitizeForFileName(merchantName);
        _downloadFile(pdfBytes, '${safeName}_siparis_$invoiceNumber.pdf');
      }

      if (mounted && !_isBulkExporting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Siparis ozeti kaydedildi ve indiriliyor'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF olusturulurken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadRentalBookingPdf(Map<String, dynamic> booking) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final bookingId = booking['id']?.toString() ?? '';

      final existing = await supabase
          .from('invoices')
          .select('id, invoice_number, pdf_url')
          .eq('source_type', 'rental_booking')
          .eq('source_id', bookingId)
          .maybeSingle();

      if (existing != null && existing['pdf_url'] != null) {
        await launchUrl(
          Uri.parse(existing['pdf_url'] as String),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      final amount =
          double.tryParse(booking['total_amount']?.toString() ?? '0') ?? 0;
      const kdvRate = 20.0;
      final kdvAmount = amount * kdvRate / (100 + kdvRate);
      final subtotal = amount - kdvAmount;

      final result = await InvoiceService.saveInvoice(
        sourceType: 'rental_booking',
        sourceId: bookingId,
        buyerName:
            booking['user_info']?['full_name'] ??
            booking['customer_name'] ??
            'Bilinmeyen Alici',
        buyerEmail: booking['user_info']?['email'] ?? booking['customer_email'],
        subtotal: subtotal,
        kdvRate: kdvRate,
        kdvAmount: kdvAmount,
        total: amount,
        items: [
          {
            'description':
                'Arac Kiralama - ${booking['booking_number'] ?? bookingId.substring(0, 8)}',
            'quantity': booking['rental_days'] ?? 1,
            'unit_price':
                double.tryParse(booking['daily_rate']?.toString() ?? '0') ??
                subtotal,
            'total': subtotal,
          },
        ],
      );

      final pdfUrl = result['pdf_url'] as String?;
      if (pdfUrl != null) {
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kiralama siparis ozeti olusturuldu'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF olusturulurken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final payments = ref.read(paymentsProvider).valueOrNull ?? [];
      final orders = ref.read(ordersForInvoiceProvider).valueOrNull ?? [];

      List<int> excelBytes;
      String filename;

      if (_customerSourceFilter == 'taxi') {
        excelBytes = await InvoiceService.exportPaymentsToExcel(payments);
        filename =
            'taksi_siparisleri_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      } else {
        excelBytes = await InvoiceService.exportFoodOrdersToExcel(orders);
        filename =
            'siparisler_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      }

      _downloadFile(Uint8List.fromList(excelBytes), filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel dosyasi indirildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel olusturulurken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportSelectedToPdf() async {
    if (_selectedPaymentIds.isEmpty && _selectedOrderIds.isEmpty) return;

    setState(() => _isBulkExporting = true);

    try {
      final payments = ref.read(paymentsProvider).valueOrNull ?? [];
      final orders = ref.read(ordersForInvoiceProvider).valueOrNull ?? [];

      int count = 0;

      for (final id in _selectedPaymentIds) {
        final payment = payments.firstWhere(
          (p) => p['id'].toString() == id,
          orElse: () => {},
        );
        if (payment.isNotEmpty) {
          await _downloadInvoicePdf(payment);
          count++;
        }
      }

      for (final id in _selectedOrderIds) {
        final order = orders.firstWhere(
          (o) => o['id'].toString() == id,
          orElse: () => {},
        );
        if (order.isNotEmpty) {
          await _downloadFoodOrderPdf(order);
          count++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count adet siparis ozeti indirildi'),
            backgroundColor: AppColors.success,
          ),
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
    } finally {
      if (mounted) setState(() => _isBulkExporting = false);
    }
  }

  Future<bool> _hasRefundInvoice(String sourceId) async {
    final original = await ref
        .read(supabaseProvider)
        .from('invoices')
        .select('id')
        .eq('source_type', 'taxi_payment')
        .eq('source_id', sourceId)
        .eq('invoice_type', 'sale')
        .maybeSingle();
    if (original == null) return false;
    final refund = await ref
        .read(supabaseProvider)
        .from('invoices')
        .select('id')
        .eq('parent_invoice_id', original['id'])
        .maybeSingle();
    return refund != null;
  }

  Future<void> _createRefundInvoice(Map<String, dynamic> payment) async {
    final supabase = ref.read(supabaseProvider);

    final original = await supabase
        .from('invoices')
        .select()
        .eq('source_type', 'taxi_payment')
        .eq(
          'source_id',
          payment['ride_id']?.toString() ?? payment['id']?.toString() ?? '',
        )
        .eq('invoice_type', 'sale')
        .maybeSingle();

    if (original == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Once orijinal fatura olusturulmali')),
      );
      return;
    }

    final refundAmount =
        double.tryParse(payment['refund_amount']?.toString() ?? '0') ?? 0;
    final kdvAmt = double.parse((refundAmount * 20 / 120).toStringAsFixed(2));

    await InvoiceService.saveInvoice(
      sourceType: 'taxi_payment',
      sourceId:
          payment['ride_id']?.toString() ?? payment['id']?.toString() ?? '',
      buyerName: payment['users']?['full_name'] ?? 'Bilinmeyen Alici',
      buyerEmail: payment['users']?['email'],
      subtotal: refundAmount - kdvAmt,
      kdvRate: 20.0,
      kdvAmount: kdvAmt,
      total: refundAmount,
      invoiceType: 'refund',
      parentInvoiceId: original['id'],
      items: [
        {
          'description': 'Iade: ${payment['refund_reason'] ?? 'Hizmet iadesi'}',
          'quantity': 1,
          'unit_price': refundAmount - kdvAmt,
          'total': refundAmount - kdvAmt,
        },
      ],
    );

    await supabase
        .from('invoices')
        .update({
          'status': 'cancelled',
        })
        .eq('id', original['id']);

    ref.invalidate(paymentsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iade faturasi olusturuldu'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class _OrderHistoryRow {
  final String id;
  final String date;
  final String customerName;
  final String source;
  final String detail;
  final double amount;
  final String? paymentType;
  final String? status;
  final Map<String, dynamic> rawData;
  final String type;

  _OrderHistoryRow({
    required this.id,
    required this.date,
    required this.customerName,
    required this.source,
    this.detail = '-',
    required this.amount,
    this.paymentType,
    this.status,
    required this.rawData,
    required this.type,
  });
}
