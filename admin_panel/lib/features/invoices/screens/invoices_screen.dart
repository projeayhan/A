import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../finance/screens/batch_invoice_screen.dart';

// Web download helper - conditionally imported
import 'web_download_helper.dart'
    if (dart.library.io) 'io_download_helper.dart';

// Date Range State
final dateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

// Payments Provider with date filter
final paymentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final dateRange = ref.watch(dateRangeProvider);

  var query = supabase.from('payments').select('*, taxi_rides(*), users(*)');

  if (dateRange != null) {
    query = query
        .gte('created_at', dateRange.start.toIso8601String())
        .lte(
          'created_at',
          dateRange.end.add(const Duration(days: 1)).toIso8601String(),
        );
  }

  final response = await query.order('created_at', ascending: false).limit(500);
  return List<Map<String, dynamic>>.from(response);
});

// Orders Provider (food, market, store) with date filter + user info
final ordersForInvoiceProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = ref.watch(supabaseProvider);
  final dateRange = ref.watch(dateRangeProvider);

  var query = supabase.from('orders').select('*, merchants(*)');

  if (dateRange != null) {
    query = query
        .gte('created_at', dateRange.start.toIso8601String())
        .lte(
          'created_at',
          dateRange.end.add(const Duration(days: 1)).toIso8601String(),
        );
  }

  final response = await query.order('created_at', ascending: false).limit(500);
  final orders = List<Map<String, dynamic>>.from(response);

  // User bilgilerini ayrıca çek
  final userIds = orders
      .map((o) => o['user_id']?.toString())
      .where((id) => id != null)
      .toSet()
      .toList();
  if (userIds.isNotEmpty) {
    final usersResp = await supabase
        .from('users')
        .select('id, first_name, last_name, email')
        .inFilter('id', userIds);
    final usersMap = <String, Map<String, dynamic>>{};
    for (final u in usersResp) {
      usersMap[u['id'].toString()] = u;
    }
    for (var i = 0; i < orders.length; i++) {
      final uid = orders[i]['user_id']?.toString();
      if (uid != null && usersMap.containsKey(uid)) {
        final u = usersMap[uid]!;
        orders[i] = {
          ...orders[i],
          'user_info': {
            'full_name': '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                .trim(),
            'email': u['email'],
          },
        };
      }
    }
  }

  return orders;
});

// Rental Bookings Provider with date filter + user info
final rentalBookingsForInvoiceProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final supabase = ref.watch(supabaseProvider);
      final dateRange = ref.watch(dateRangeProvider);

      var query = supabase.from('rental_bookings').select('*');

      if (dateRange != null) {
        query = query
            .gte('created_at', dateRange.start.toIso8601String())
            .lte(
              'created_at',
              dateRange.end.add(const Duration(days: 1)).toIso8601String(),
            );
      }

      // Sadece onaylanan/tamamlanan rezervasyonlar
      final response = await query
          .inFilter('status', ['confirmed', 'active', 'completed'])
          .order('created_at', ascending: false)
          .limit(500);
      final bookings = List<Map<String, dynamic>>.from(response);

      // User bilgilerini ayrıca çek
      final userIds = bookings
          .map((b) => b['user_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList();
      if (userIds.isNotEmpty) {
        final usersResp = await supabase
            .from('users')
            .select('id, first_name, last_name, email')
            .inFilter('id', userIds);
        final usersMap = <String, Map<String, dynamic>>{};
        for (final u in usersResp) {
          usersMap[u['id'].toString()] = u;
        }
        for (var i = 0; i < bookings.length; i++) {
          final uid = bookings[i]['user_id']?.toString();
          if (uid != null && usersMap.containsKey(uid)) {
            final u = usersMap[uid]!;
            bookings[i] = {
              ...bookings[i],
              'user_info': {
                'full_name': '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                    .trim(),
                'email': u['email'],
              },
            };
          }
        }
      }

      return bookings;
    });

// Fatura arşivi filtre state'i
final invoiceFilterProvider = StateProvider<Map<String, dynamic>>((ref) => {});

// Fatura sorgusu — paymentFilter key: 'all' | 'paid' | 'unpaid'
final invoiceArchiveProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      paymentFilter,
    ) async {
      final supabase = ref.watch(supabaseProvider);
      final filters = ref.watch(invoiceFilterProvider);
      var query = supabase.from('invoices').select('*, invoice_items(*)');

      // Payment filter (tab bazlı)
      if (paymentFilter == 'paid') {
        query = query.eq('payment_status', 'paid');
      } else if (paymentFilter == 'unpaid') {
        query = query.inFilter('payment_status', ['pending', 'overdue']);
      }

      if (filters['source_type'] != null) {
        query = query.eq('source_type', filters['source_type'] as String);
      }
      if (filters['status'] != null) {
        query = query.eq('status', filters['status'] as String);
      }
      if (filters['invoice_type'] != null) {
        query = query.eq('invoice_type', filters['invoice_type'] as String);
      }
      if (filters['payment_status'] != null) {
        query = query.eq('payment_status', filters['payment_status'] as String);
      }
      if (filters['date_from'] != null) {
        query = query.gte('created_at', filters['date_from'] as String);
      }
      if (filters['date_to'] != null) {
        query = query.lte('created_at', filters['date_to'] as String);
      }
      final search = filters['search'] as String?;
      if (search != null && search.isNotEmpty) {
        query = query.or(
          'invoice_number.ilike.%$search%,'
          'buyer_name.ilike.%$search%,'
          'buyer_email.ilike.%$search%',
        );
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(response);
    });

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPaymentType = 'all';
  String _selectedStatus = 'all';
  String _customerSourceFilter = 'all'; // all, taxi, food

  // Coklu secim - her tab icin ayri
  final Set<String> _selectedPaymentIds = {};
  final Set<String> _selectedOrderIds = {};
  bool _isPaymentSelectionMode = false;
  bool _isOrderSelectionMode = false;

  // Manuel fatura formu
  final _customerNameController = TextEditingController();
  final _customerTaxController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final List<_InvoiceItemController> _invoiceItems = [];
  double _kdvRate = 20.0;
  final TextEditingController _invoiceNumberController = TextEditingController();

  // Alici autocomplete
  List<Map<String, dynamic>> _buyerSuggestions = [];
  bool _showBuyerSuggestions = false;
  Timer? _buyerSearchDebounce;

  // Şirket bilgisi
  Map<String, String> _companyInfo = {};

  // Fatura arşivi arama
  final TextEditingController _archiveSearchController =
      TextEditingController();

  // İşletme faturaları
  List<Map<String, dynamic>> _merchantsForInvoice = [];
  Map<String, double> _merchantRevenues = {};
  final Set<String> _selectedMerchantForInvoiceIds = {};
  bool _merchantsLoading = false;
  bool _bulkInvoiceCreating = false;
  bool _isBulkExporting = false;
  DateTimeRange? _merchantInvoicePeriod;
  int _selectedMonth = DateTime.now().month == 1
      ? 12
      : DateTime.now().month - 1;
  int _selectedYear = DateTime.now().month == 1
      ? DateTime.now().year - 1
      : DateTime.now().year;
  double _merchantKdvRate = 20.0;
  final TextEditingController _kdvController = TextEditingController(
    text: '20',
  );
  final TextEditingController _merchantSearchController =
      TextEditingController();
  String _merchantSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _addInvoiceItem();
    InvoiceService.getCompanyInfo().then((info) {
      if (mounted) setState(() => _companyInfo = info);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameController.dispose();
    _customerTaxController.dispose();
    _customerAddressController.dispose();
    _invoiceNumberController.dispose();
    _buyerSearchDebounce?.cancel();
    _archiveSearchController.dispose();
    _merchantSearchController.dispose();
    _kdvController.dispose();
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

  double get _subtotal =>
      _invoiceItems.fold(0, (sum, item) => sum + item.total);
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
                      'Fatura Yönetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fatura takibi, oluşturma ve ödeme yönetimi',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    if ((_isPaymentSelectionMode || _isOrderSelectionMode) &&
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
                            'Seçilenleri PDF (${_selectedPaymentIds.length + _selectedOrderIds.length})',
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _exportToExcel,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Excel İndir'),
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
                            : 'Tarih Seç',
                      ),
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
                Tab(text: 'Toplu Fatura'),
                Tab(text: 'Manuel Fatura'),
                Tab(text: 'Ödenmemiş'),
                Tab(text: 'Ödenmiş'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const BatchInvoiceScreen(embedded: true),
                _buildInvoiceGeneratorTab(),
                _buildInvoiceArchiveTab(paymentFilter: 'unpaid'),
                _buildInvoiceArchiveTab(paymentFilter: 'paid'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInvoicesTab() {
    final paymentsAsync = ref.watch(paymentsProvider);
    final ordersAsync = ref.watch(ordersForInvoiceProvider);
    final rentalsAsync = ref.watch(rentalBookingsForInvoiceProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Kaynak filtresi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tümü'),
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
                  label: const Text('Mağaza'),
                  selected: _customerSourceFilter == 'store',
                  onSelected: (_) =>
                      setState(() => _customerSourceFilter = 'store'),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Araç Kiralama'),
                  selected: _customerSourceFilter == 'rental',
                  onSelected: (_) =>
                      setState(() => _customerSourceFilter = 'rental'),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 16),
                // Ödeme tipi filtresi
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
                      hint: const Text('Ödeme Tipi'),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Tüm Tipler'),
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
                          child: Text('Tüm Durumlar'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Bekliyor'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Tamamlandı'),
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
                      onChanged: (value) =>
                          setState(() => _selectedStatus = value!),
                    ),
                  ),
                ),
                const Spacer(),
                // Toplu seçim
                FilterChip(
                  label: Text(
                    _isPaymentSelectionMode ? 'Seçim Modu Açık' : 'Toplu Seçim',
                  ),
                  selected: _isPaymentSelectionMode,
                  onSelected: (value) {
                    setState(() {
                      _isPaymentSelectionMode = value;
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
          const SizedBox(height: 16),

          // Birleşik tablo
          Expanded(
            child: _buildCustomerInvoicesContent(
              paymentsAsync,
              ordersAsync,
              rentalsAsync,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInvoicesContent(
    AsyncValue<List<Map<String, dynamic>>> paymentsAsync,
    AsyncValue<List<Map<String, dynamic>>> ordersAsync,
    AsyncValue<List<Map<String, dynamic>>> rentalsAsync,
  ) {
    // Tüm veriler yüklenene kadar bekle
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

    // Birleşik satır listesi oluştur
    List<_CustomerInvoiceRow> rows = [];

    // Taksi ödemeleri
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
          _CustomerInvoiceRow(
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

    // Siparişler (yemek, market, mağaza) - merchants.type'a göre ayrılıyor
    for (final o in orders) {
      final merchantType = o['merchants']?['type']?.toString() ?? 'restaurant';
      // Kaynak filtresine göre kontrol
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
          sourceLabel = 'Mağaza';
          break;
        default:
          sourceLabel = 'Yemek';
      }

      rows.add(
        _CustomerInvoiceRow(
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

    // Araç kiralama rezervasyonları
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
          _CustomerInvoiceRow(
            id: r['id']?.toString() ?? '',
            date: r['created_at']?.toString() ?? '',
            customerName:
                r['user_info']?['full_name'] ?? r['customer_name'] ?? '-',
            source: 'Araç Kiralama',
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

    // Tarihe göre sırala (yeniden eskiye)
    rows.sort((a, b) => b.date.compareTo(a.date));

    final totalAmount = rows.fold<double>(0, (s, r) => s + r.amount);

    return Column(
      children: [
        // Stats
        Row(
          children: [
            _buildStatCard(
              'Toplam İşlem',
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
              'Sipariş',
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
                  DataColumn2(label: Text('Müşteri'), size: ColumnSize.M),
                  DataColumn2(label: Text('Kaynak'), fixedWidth: 110),
                  DataColumn2(label: Text('Detay'), size: ColumnSize.M),
                  DataColumn2(label: Text('Tutar'), fixedWidth: 110),
                  DataColumn2(label: Text('Ödeme'), fixedWidth: 100),
                  DataColumn2(label: Text('Durum'), fixedWidth: 120),
                  DataColumn2(label: Text('İşlemler'), fixedWidth: 130),
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
                                onPressed: () => _printInvoice(row.rawData),
                                tooltip: 'Fatura Yazdır',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    _downloadInvoicePdf(row.rawData),
                                tooltip: 'PDF İndir',
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
                                  tooltip: 'İade Et',
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
                                    tooltip: 'İade Faturası Kes',
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
                                    _printFoodOrderInvoice(row.rawData),
                                tooltip: 'Fatura Yazdır',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    _downloadFoodOrderPdf(row.rawData),
                                tooltip: 'PDF İndir',
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
                                tooltip: 'PDF İndir',
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
                          Text(
                            'Manuel Fatura Oluştur',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _invoiceNumberController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Fatura No',
                                hintText: 'Boş bırakılırsa otomatik',
                                hintStyle: const TextStyle(fontSize: 11),
                                prefixIcon: const Icon(Icons.tag, size: 18),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                            Text(
                              'Satıcı: ${_companyInfo['name'] ?? '—'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Vergi Dairesi: ${_companyInfo['taxOffice'] ?? '—'} - ${_companyInfo['taxNumber'] ?? '—'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Customer Info
                      Text(
                        'Alıcı Bilgileri',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _customerNameController,
                                  onChanged: _onBuyerNameChanged,
                                  onTap: () {
                                    if (_customerNameController.text.length >= 2) {
                                      _onBuyerNameChanged(_customerNameController.text);
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Alıcı Adı *',
                                    prefixIcon: Icon(Icons.search, size: 18),
                                  ),
                                ),
                                if (_showBuyerSuggestions && _buyerSuggestions.isNotEmpty)
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 240),
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.surfaceLight),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: _buyerSuggestions.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        color: AppColors.surfaceLight.withValues(alpha: 0.5),
                                      ),
                                      itemBuilder: (context, index) {
                                        final buyer = _buyerSuggestions[index];
                                        return ListTile(
                                          dense: true,
                                          visualDensity: VisualDensity.compact,
                                          leading: Icon(
                                            buyer['icon'] as IconData,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          title: Text(
                                            buyer['name'] as String,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          subtitle: Text(
                                            [
                                              buyer['type'] as String,
                                              if ((buyer['tax_number'] as String?)?.isNotEmpty == true)
                                                'VN: ${buyer['tax_number']}',
                                              if ((buyer['address'] as String?)?.isNotEmpty == true)
                                                buyer['address'] as String,
                                            ].join(' · '),
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onTap: () => _selectBuyer(buyer),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _customerTaxController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Vergi No / TC',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customerAddressController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Adres'),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 24),

                      // Invoice Items
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fatura Kalemleri',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Row(
                            children: [
                              Text(
                                'KDV Oranı:',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.surfaceLight,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<double>(
                                    value: _kdvRate,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 0.0,
                                        child: Text('%0'),
                                      ),
                                      DropdownMenuItem(
                                        value: 1.0,
                                        child: Text('%1'),
                                      ),
                                      DropdownMenuItem(
                                        value: 10.0,
                                        child: Text('%10'),
                                      ),
                                      DropdownMenuItem(
                                        value: 20.0,
                                        child: Text('%20'),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _kdvRate = value!),
                                  ),
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
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Açıklama',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Miktar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Birim Fiyat',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    'Toplam',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(width: 40),
                              ],
                            ),
                            const Divider(),
                            ..._invoiceItems.asMap().entries.map(
                              (entry) => _buildInvoiceItemRow(entry.key),
                            ),
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
                              _buildTotalRow(
                                'Ara Toplam',
                                '${_subtotal.toStringAsFixed(2)} TL',
                              ),
                              _buildTotalRow(
                                'KDV (%${_kdvRate.toInt()})',
                                '${_kdvAmount.toStringAsFixed(2)} TL',
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Genel Toplam: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${_grandTotal.toStringAsFixed(2)} TL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
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
                            label: const Text('Fatura Oluştur ve Kaydet'),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Önizleme', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          DateFormat('dd.MM.yyyy').format(DateTime.now()),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // === HEADER: Logo + Company + Invoice Info ===
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Company logo & name
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6C5CE7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _companyInfo['name'] ?? '—',
                                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _companyInfo['address'] ?? '',
                                                style: const TextStyle(color: Colors.black54, fontSize: 9),
                                              ),
                                              Text(
                                                '${_companyInfo['phone'] ?? ''} | ${_companyInfo['email'] ?? ''}',
                                                style: const TextStyle(color: Colors.black54, fontSize: 9),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Invoice info
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6C5CE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('FATURA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _invoiceNumberController.text.isNotEmpty
                                            ? '#${_invoiceNumberController.text}'
                                            : '#Otomatik',
                                        style: TextStyle(
                                          color: _invoiceNumberController.text.isNotEmpty ? Colors.black87 : Colors.black38,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                        style: const TextStyle(color: Colors.black54, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // === SELLER & BUYER INFO ===
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Satici
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE9ECEF)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('SATICI', style: TextStyle(color: Colors.black45, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          const SizedBox(height: 4),
                                          Text(_companyInfo['name'] ?? '—', style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600)),
                                          Text('VD: ${_companyInfo['taxOffice'] ?? '—'}', style: const TextStyle(color: Colors.black54, fontSize: 9)),
                                          Text('VN: ${_companyInfo['taxNumber'] ?? '—'}', style: const TextStyle(color: Colors.black54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Alici
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE9ECEF)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('ALICI', style: TextStyle(color: Colors.black45, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                          const SizedBox(height: 4),
                                          Text(
                                            _customerNameController.text.isEmpty ? '—' : _customerNameController.text,
                                            style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                          if (_customerTaxController.text.isNotEmpty)
                                            Text('VN/TC: ${_customerTaxController.text}', style: const TextStyle(color: Colors.black54, fontSize: 9)),
                                          if (_customerAddressController.text.isNotEmpty)
                                            Text(_customerAddressController.text, style: const TextStyle(color: Colors.black54, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // === ITEMS TABLE ===
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFDEE2E6)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    // Table header
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F3F5),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(5),
                                          topRight: Radius.circular(5),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Expanded(flex: 4, child: Text('Açıklama', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold))),
                                          Expanded(child: Text('Miktar', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                          Expanded(flex: 2, child: Text('Birim Fiyat', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                          Expanded(flex: 2, child: Text('Toplam', style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                        ],
                                      ),
                                    ),
                                    // Table rows
                                    ..._invoiceItems.where((item) => item.description.text.isNotEmpty).map(
                                      (item) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: const BoxDecoration(
                                          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(flex: 4, child: Text(item.description.text, style: const TextStyle(color: Colors.black87, fontSize: 10))),
                                            Expanded(child: Text('${item.quantityValue}', style: const TextStyle(color: Colors.black87, fontSize: 10), textAlign: TextAlign.center)),
                                            Expanded(flex: 2, child: Text('${item.unitPriceValue.toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.black87, fontSize: 10), textAlign: TextAlign.right)),
                                            Expanded(flex: 2, child: Text('${item.total.toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Empty state
                                    if (_invoiceItems.every((item) => item.description.text.isEmpty))
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text('Henüz kalem eklenmedi', style: TextStyle(color: Colors.black38, fontSize: 10, fontStyle: FontStyle.italic)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // === TOTALS ===
                              Row(
                                children: [
                                  const Spacer(flex: 2),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Ara Toplam', style: TextStyle(color: Colors.black54, fontSize: 10)),
                                            Text('${_subtotal.toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.black87, fontSize: 10)),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('KDV (%${_kdvRate.toInt()})', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                                            Text('${_kdvAmount.toStringAsFixed(2)} TL', style: const TextStyle(color: Colors.black87, fontSize: 10)),
                                          ],
                                        ),
                                        const Divider(color: Color(0xFFDEE2E6), height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('GENEL TOPLAM', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${_grandTotal.toStringAsFixed(2)} TL',
                                                style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // === FOOTER ===
                              const Divider(color: Color(0xFFEEEEEE)),
                              const SizedBox(height: 4),
                              Center(
                                child: Text(
                                  '${_companyInfo['website'] ?? ''} | ${_companyInfo['phone'] ?? ''}',
                                  style: const TextStyle(color: Colors.black38, fontSize: 8),
                                ),
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
                            label: const Text('Yazdır'),
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

  Widget _buildInvoiceArchiveTab({String? paymentFilter}) {
    final filters = ref.watch(invoiceFilterProvider);
    final archiveAsync = ref.watch(invoiceArchiveProvider(paymentFilter ?? 'all'));
    // Sync controller text with filter state without rebuilding controller
    final filterSearch = filters['search'] ?? '';
    if (_archiveSearchController.text != filterSearch) {
      _archiveSearchController.text = filterSearch;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    controller: _archiveSearchController,
                    decoration: InputDecoration(
                      hintText: 'Fatura no, müşteri adı veya email ara...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) => ref
                        .read(invoiceFilterProvider.notifier)
                        .update((s) => {...s, 'search': v}),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: filters['source_type'],
                      hint: const Text('Kaynak'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tümü')),
                        DropdownMenuItem(
                          value: 'merchant_commission',
                          child: Text('Komisyon'),
                        ),
                        DropdownMenuItem(
                          value: 'merchant_invoice',
                          child: Text('İşletme Faturası'),
                        ),
                        DropdownMenuItem(
                          value: 'manual',
                          child: Text('Manuel'),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(invoiceFilterProvider.notifier)
                          .update((s) => {...s, 'source_type': v}),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: filters['status'],
                      hint: const Text('Durum'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tümü')),
                        DropdownMenuItem(
                          value: 'issued',
                          child: Text('Kesildi'),
                        ),
                        DropdownMenuItem(
                          value: 'sent',
                          child: Text('Gönderildi'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('İptal'),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(invoiceFilterProvider.notifier)
                          .update((s) => {...s, 'status': v}),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (paymentFilter == null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: filters['payment_status'],
                        hint: const Text('Ödeme'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tümü')),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Bekliyor'),
                          ),
                          DropdownMenuItem(value: 'paid', child: Text('Ödendi')),
                          DropdownMenuItem(
                            value: 'overdue',
                            child: Text('Gecikmiş'),
                          ),
                        ],
                        onChanged: (v) => ref
                            .read(invoiceFilterProvider.notifier)
                            .update((s) => {...s, 'payment_status': v}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: filters['invoice_type'],
                      hint: const Text('Tür'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Tümü')),
                        DropdownMenuItem(value: 'sale', child: Text('Satış')),
                        DropdownMenuItem(value: 'refund', child: Text('İade')),
                      ],
                      onChanged: (v) => ref
                          .read(invoiceFilterProvider.notifier)
                          .update((s) => {...s, 'invoice_type': v}),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _exportArchiveToExcel(),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: archiveAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (invoices) {
                if (invoices.isEmpty) {
                  return const Center(child: Text('Fatura bulunamadı'));
                }
                final totalGross = invoices.fold<double>(
                  0,
                  (s, inv) => s + ((inv['total'] as num?)?.toDouble() ?? 0),
                );
                final paidTotal = invoices
                    .where((inv) => inv['payment_status'] == 'paid')
                    .fold<double>(
                      0,
                      (s, inv) => s + ((inv['total'] as num?)?.toDouble() ?? 0),
                    );
                final pendingTotal = invoices
                    .where(
                      (inv) =>
                          inv['payment_status'] != 'paid' &&
                          inv['status'] != 'cancelled',
                    )
                    .fold<double>(
                      0,
                      (s, inv) => s + ((inv['total'] as num?)?.toDouble() ?? 0),
                    );
                final overdueCount = invoices
                    .where((inv) => inv['payment_status'] == 'overdue')
                    .length;
                return Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCard(
                          'Fatura Sayısı',
                          invoices.length.toString(),
                          Icons.receipt_long,
                          AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Toplam',
                          '₺${totalGross.toStringAsFixed(2)}',
                          Icons.payments,
                          AppColors.info,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Ödenen',
                          '₺${paidTotal.toStringAsFixed(2)}',
                          Icons.check_circle,
                          AppColors.success,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Bekleyen',
                          '₺${pendingTotal.toStringAsFixed(2)}',
                          Icons.schedule,
                          AppColors.warning,
                        ),
                        if (overdueCount > 0) ...[
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Gecikmiş',
                            overdueCount.toString(),
                            Icons.warning,
                            AppColors.error,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: DataTable2(
                            columnSpacing: 12,
                            headingRowColor: WidgetStateProperty.all(
                              AppColors.background,
                            ),
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
                              DataColumn2(
                                label: Text('FATURA NO'),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text('TARİH'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('DÖNEM'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('ALICI'),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text('TOPLAM'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('ÖDEME'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('VADE'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('DURUM'),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text('İŞLEM'),
                                size: ColumnSize.S,
                              ),
                            ],
                            rows: invoices.map((inv) {
                              final dateStr = inv['created_at'] as String?;
                              final date = dateStr != null
                                  ? DateFormat(
                                      'dd.MM.yyyy',
                                    ).format(DateTime.parse(dateStr))
                                  : '-';
                              final paymentStatus =
                                  inv['payment_status'] as String? ?? 'pending';
                              final dueDate =
                                  inv['payment_due_date'] as String?;
                              final dueDateStr = dueDate != null
                                  ? DateFormat(
                                      'dd.MM.yyyy',
                                    ).format(DateTime.parse(dueDate))
                                  : '-';
                              final period =
                                  inv['invoice_period'] as String? ?? '-';
                              return DataRow2(
                                cells: [
                                  DataCell(
                                    Text(
                                      inv['invoice_number'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(date)),
                                  DataCell(Text(period)),
                                  DataCell(Text(inv['buyer_name'] ?? '-')),
                                  DataCell(
                                    Text(
                                      '₺${(inv['total'] as num?)?.toStringAsFixed(2) ?? '0'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _buildPaymentStatusBadge(paymentStatus),
                                  ),
                                  DataCell(
                                    Text(
                                      dueDateStr,
                                      style: TextStyle(
                                        color: paymentStatus == 'overdue'
                                            ? AppColors.error
                                            : AppColors.textMuted,
                                        fontWeight: paymentStatus == 'overdue'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _buildInvoiceStatusBadge(inv['status']),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.download,
                                            size: 18,
                                          ),
                                          tooltip: 'PDF İndir',
                                          onPressed: () async {
                                            try {
                                              await _downloadArchiveInvoicePdf(inv);
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('PDF hatası: $e'), backgroundColor: AppColors.error),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        if (paymentStatus != 'paid' &&
                                            inv['status'] != 'cancelled')
                                          IconButton(
                                            icon: const Icon(
                                              Icons.check_circle_outline,
                                              size: 18,
                                              color: AppColors.success,
                                            ),
                                            tooltip: 'Ödendi olarak işaretle',
                                            onPressed: () async {
                                              await _markInvoicePaid(inv['id'] as String);
                                            },
                                          ),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTypeBadge(String? type) {
    final color = type == 'refund' ? AppColors.warning : AppColors.primary;
    final label = type == 'refund'
        ? 'İade'
        : type == 'proforma'
        ? 'Proforma'
        : 'Satış';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'paid':
        color = AppColors.success;
        label = 'Ödendi';
        icon = Icons.check_circle;
        break;
      case 'overdue':
        color = AppColors.error;
        label = 'Gecikmiş';
        icon = Icons.warning;
        break;
      default:
        color = AppColors.warning;
        label = 'Bekliyor';
        icon = Icons.schedule;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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

  Future<void> _markInvoicePaid(String invoiceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Onay'),
        content: const Text('Bu faturayı ödendi olarak işaretlemek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Evet, Ödendi')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final supabase = ref.read(supabaseProvider);
      try {
        await supabase.rpc('mark_invoice_paid', params: {
          'p_invoice_id': invoiceId,
          'p_payment_method': 'manual',
          'p_payment_note': 'Admin tarafından ödendi olarak işaretlendi',
        });
      } catch (_) {
        await supabase.from('invoices').update({
          'payment_status': 'paid',
          'paid_at': DateTime.now().toIso8601String(),
          'payment_method': 'manual',
          'payment_note': 'Admin tarafından ödendi olarak işaretlendi',
        }).eq('id', invoiceId);
      }
      ref.invalidate(invoiceArchiveProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fatura ödendi olarak işaretlendi'), backgroundColor: Colors.green),
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

  Widget _buildInvoiceStatusBadge(String? status) {
    Color color;
    String label;
    switch (status) {
      case 'issued':
        color = AppColors.info;
        label = 'Kesildi';
        break;
      case 'sent':
        color = AppColors.success;
        label = 'Gönderildi';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'İptal';
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
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  void _openPdfUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
                hintText: 'Açıklama',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
            icon: Icon(
              Icons.delete,
              size: 18,
              color: _invoiceItems.length > 1
                  ? AppColors.error
                  : AppColors.textMuted,
            ),
            onPressed: _invoiceItems.length > 1
                ? () => _removeInvoiceItem(index)
                : null,
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
        label = 'Tamamlandı';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Bekliyor';
        break;
      case 'failed':
        color = AppColors.error;
        label = 'Başarısız';
        break;
      case 'refunded':
        color = AppColors.info;
        label = 'İade Edildi';
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
        label = 'Hazırlanıyor';
        break;
      case 'on_the_way':
        color = AppColors.info;
        label = 'Yolda';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'İptal';
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

  static const _turkishMonths = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  void _showMonthYearPicker() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Fatura Dönemi Seç',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Yıl seçici
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () => setDialogState(() => tempYear--),
                    ),
                    Text(
                      '$tempYear',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onPressed: tempYear < DateTime.now().year
                          ? () => setDialogState(() => tempYear++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Ay grid
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (ctx, i) {
                    final month = i + 1;
                    final isSelected = month == tempMonth;
                    final isFuture =
                        tempYear == DateTime.now().year &&
                        month > DateTime.now().month;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: isFuture
                          ? null
                          : () => setDialogState(() => tempMonth = month),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isFuture
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade600),
                          ),
                        ),
                        child: Text(
                          _turkishMonths[i],
                          style: TextStyle(
                            color: isFuture
                                ? Colors.grey.shade700
                                : (isSelected
                                      ? Colors.white
                                      : Colors.grey.shade300),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _selectedMonth = tempMonth;
                  _selectedYear = tempYear;
                  final start = DateTime(_selectedYear, _selectedMonth);
                  final end = DateTime(
                    _selectedYear,
                    _selectedMonth + 1,
                    0,
                    23,
                    59,
                    59,
                  );
                  _merchantInvoicePeriod = DateTimeRange(
                    start: start,
                    end: end,
                  );
                });
                _fetchMerchantsForInvoice();
              },
              child: const Text('Seç'),
            ),
          ],
        ),
      ),
    );
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
        title: Text(
          'Ödeme Detayı #${payment['id']?.toString().substring(0, 8)}',
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
                'Yolculuk Ücreti',
                '${payment['ride_fare'] ?? 0} TL',
              ),
              _buildDetailRow('Bahşiş', '${payment['tip_amount'] ?? 0} TL'),
              _buildDetailRow(
                'Geçiş Ücreti',
                '${payment['toll_amount'] ?? 0} TL',
              ),
              _buildDetailRow(
                'İndirim',
                '${payment['discount_amount'] ?? 0} TL',
              ),
              _buildDetailRow('Ödeme Tipi', payment['payment_type'] ?? '-'),
              _buildDetailRow('Durum', payment['status'] ?? '-'),
              _buildDetailRow('Sağlayıcı', payment['provider'] ?? '-'),
              if (payment['refund_amount'] != null) ...[
                const Divider(),
                _buildDetailRow(
                  'İade Tutarı',
                  '${payment['refund_amount']} TL',
                ),
                _buildDetailRow('İade Nedeni', payment['refund_reason'] ?? '-'),
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
    final amountController = TextEditingController(
      text: payment['amount']?.toString() ?? '0',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İade Yap'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'İade Tutarı (TL)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'İade Nedeni'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
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
            child: const Text('İade Yap'),
          ),
        ],
      ),
    );
  }

  Future<void> _printInvoice(Map<String, dynamic> payment) async {
    try {
      // Mevcut fatura varsa onun numarasını kullan, yoksa önizleme olarak yazdır
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
            content: Text('Yazdırılırken hata: $e'),
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

      // Mevcut fatura var mı kontrol et
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

      // Yeni fatura oluştur ve kaydet
      final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
      const kdvRate = 20.0;
      final kdvAmount = amount * kdvRate / (100 + kdvRate);
      final subtotal = amount - kdvAmount;

      final result = await InvoiceService.saveInvoice(
        sourceType: 'taxi_payment',
        sourceId: paymentId,
        buyerName: payment['users']?['full_name'] ?? 'Bilinmeyen Alıcı',
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
        _downloadFile(pdfBytes, '${safeName}_fatura_$invoiceNumber.pdf');
      }

      if (mounted && !_isBulkExporting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fatura kaydedildi ve indiriliyor'),
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

  Future<void> _printFoodOrderInvoice(Map<String, dynamic> order) async {
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
            content: Text('Yazdırılırken hata: $e'),
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

      // Mevcut fatura var mı kontrol et
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

      // Yeni fatura oluştur ve kaydet
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
            'Bilinmeyen Alıcı',
        subtotal: subtotal,
        kdvRate: kdvRate,
        kdvAmount: kdvAmount,
        total: amount,
        items: [
          {
            'description':
                'Yemek Siparişi #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
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
            content: Text('Fatura kaydedildi ve indiriliyor'),
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

      // Mevcut fatura var mı kontrol et
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

      // Yeni fatura oluştur ve kaydet
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
            'Bilinmeyen Alıcı',
        buyerEmail: booking['user_info']?['email'] ?? booking['customer_email'],
        subtotal: subtotal,
        kdvRate: kdvRate,
        kdvAmount: kdvAmount,
        total: amount,
        items: [
          {
            'description':
                'Araç Kiralama - ${booking['booking_number'] ?? bookingId.substring(0, 8)}',
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
            content: Text('Kiralama faturası oluşturuldu'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF oluşturulurken hata: $e'),
            backgroundColor: AppColors.error,
          ),
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
        filename =
            'taksi_odemeleri_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      } else if (currentTab == 1) {
        final orders = ref.read(ordersForInvoiceProvider).valueOrNull ?? [];
        excelBytes = await InvoiceService.exportFoodOrdersToExcel(orders);
        filename =
            'yemek_siparisleri_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu sekme için Excel dışa aktarma desteklenmiyor'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      _downloadFile(Uint8List.fromList(excelBytes), filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel dosyası indirildi'),
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
            content: Text('$count adet fatura indirildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }

      setState(() {
        _selectedPaymentIds.clear();
        _selectedOrderIds.clear();
        _isPaymentSelectionMode = false;
        _isOrderSelectionMode = false;
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

  void _onBuyerNameChanged(String query) {
    setState(() {}); // Update preview
    _buyerSearchDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _buyerSuggestions = [];
        _showBuyerSuggestions = false;
      });
      return;
    }
    _buyerSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final supabase = ref.read(supabaseProvider);
      final results = <Map<String, dynamic>>[];

      // 1. Merchants (isletmeler)
      try {
        final merchants = await supabase
            .from('merchants')
            .select('id, business_name, tax_number, address')
            .ilike('business_name', '%$query%')
            .limit(5);
        for (final m in merchants) {
          results.add({
            'name': m['business_name'] ?? '',
            'tax_number': m['tax_number'] ?? '',
            'address': m['address'] ?? '',
            'type': 'İşletme',
            'icon': Icons.store,
          });
        }
      } catch (e) {
        debugPrint('Merchant search error: $e');
      }

      // 2. Users (musteriler)
      try {
        final users = await supabase
            .from('users')
            .select('id, full_name, phone, email')
            .ilike('full_name', '%$query%')
            .not('full_name', 'eq', '')
            .limit(5);
        for (final u in users) {
          results.add({
            'name': u['full_name'] ?? '',
            'tax_number': '',
            'address': '',
            'phone': u['phone'] ?? '',
            'email': u['email'] ?? '',
            'type': 'Müşteri',
            'icon': Icons.person,
          });
        }
      } catch (e) {
        debugPrint('User search error: $e');
      }

      // 3. Car dealers
      try {
        final dealers = await supabase
            .from('car_dealers')
            .select('id, business_name, tax_number, address')
            .ilike('business_name', '%$query%')
            .limit(3);
        for (final d in dealers) {
          results.add({
            'name': d['business_name'] ?? '',
            'tax_number': d['tax_number'] ?? '',
            'address': d['address'] ?? '',
            'type': 'Galeri',
            'icon': Icons.directions_car,
          });
        }
      } catch (e) {
        debugPrint('Dealer search error: $e');
      }

      // 4. Realtors
      try {
        final realtors = await supabase
            .from('realtors')
            .select('id, company_name, tax_number, address')
            .ilike('company_name', '%$query%')
            .limit(3);
        for (final r in realtors) {
          results.add({
            'name': r['company_name'] ?? '',
            'tax_number': r['tax_number'] ?? '',
            'address': r['address'] ?? '',
            'type': 'Emlakçı',
            'icon': Icons.apartment,
          });
        }
      } catch (e) {
        debugPrint('Realtor search error: $e');
      }

      // 5. Past invoice buyers
      try {
        final pastBuyers = await supabase
            .from('invoices')
            .select('buyer_name, buyer_tax_number, buyer_address')
            .ilike('buyer_name', '%$query%')
            .not('buyer_name', 'is', null)
            .limit(5);
        final seenNames = results.map((r) => (r['name'] as String).toLowerCase()).toSet();
        for (final b in pastBuyers) {
          final name = b['buyer_name'] as String? ?? '';
          if (name.isNotEmpty && !seenNames.contains(name.toLowerCase())) {
            seenNames.add(name.toLowerCase());
            results.add({
              'name': name,
              'tax_number': b['buyer_tax_number'] ?? '',
              'address': b['buyer_address'] ?? '',
              'type': 'Geçmiş Fatura',
              'icon': Icons.receipt_long,
            });
          }
        }
      } catch (e) {
        debugPrint('Invoice search error: $e');
      }

      if (mounted) {
        setState(() {
          _buyerSuggestions = results;
          _showBuyerSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  void _selectBuyer(Map<String, dynamic> buyer) {
    setState(() {
      _customerNameController.text = buyer['name'] as String;
      final taxNum = buyer['tax_number'] as String? ?? '';
      if (taxNum.isNotEmpty) _customerTaxController.text = taxNum;
      final address = buyer['address'] as String? ?? '';
      if (address.isNotEmpty) _customerAddressController.text = address;
      _showBuyerSuggestions = false;
      _buyerSuggestions = [];
    });
  }

  void _clearForm() {
    setState(() {
      _customerNameController.clear();
      _customerTaxController.clear();
      _customerAddressController.clear();
      _invoiceNumberController.clear();
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
        const SnackBar(
          content: Text('Alıcı adı gerekli'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_invoiceItems.isEmpty ||
        _invoiceItems.every((item) => item.description.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir fatura kalemi gerekli'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final items = _invoiceItems
          .where((item) => item.description.text.isNotEmpty)
          .map(
            (item) => {
              'description': item.description.text,
              'quantity': item.quantityValue,
              'unit_price': item.unitPriceValue,
              'total': item.total,
            },
          )
          .toList();

      final result = await InvoiceService.saveInvoice(
        sourceType: 'manual',
        sourceId: DateTime.now().millisecondsSinceEpoch.toString(),
        buyerName: _customerNameController.text,
        buyerTaxNumber: _customerTaxController.text.isEmpty
            ? null
            : _customerTaxController.text,
        buyerAddress: _customerAddressController.text.isEmpty
            ? null
            : _customerAddressController.text,
        subtotal: _subtotal,
        kdvRate: _kdvRate,
        kdvAmount: _kdvAmount,
        total: _grandTotal,
        items: items,
        customInvoiceNumber: _invoiceNumberController.text.isEmpty
            ? null
            : _invoiceNumberController.text,
      );

      ref.invalidate(invoiceArchiveProvider);

      final invoiceNumber = result['invoice_number'] ?? '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fatura $invoiceNumber kaydedildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }

      _clearForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fatura kaydedilirken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _previewPdf() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alıcı adı gerekli'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final payment = {
        'amount': _grandTotal.toString(),
        'payment_type': 'manual',
        'users': {'full_name': _customerNameController.text},
      };

      // Fatura kalemlerini PDF'e gonder
      final items = _invoiceItems
          .where((item) => item.description.text.isNotEmpty)
          .map((item) => {
                'description': item.description.text,
                'quantity': item.quantityValue,
                'unit_price': item.unitPriceValue,
                'total': item.total,
              })
          .toList();

      final pdfBytes = await InvoiceService.generateInvoicePdf(
        payment: payment,
        invoiceNumber: _invoiceNumberController.text.isNotEmpty
            ? _invoiceNumberController.text
            : 'ONIZLEME',
        customerInfo: {
          'name': _customerNameController.text,
          'taxNumber': _customerTaxController.text,
          'address': _customerAddressController.text,
        },
        invoiceType: 'MANUEL FATURA (ÖNİZLEME)',
        items: items,
        subtotalOverride: _subtotal,
        kdvRateOverride: _kdvRate / 100,
        kdvAmountOverride: _kdvAmount,
      );

      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Önizleme hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadManualInvoicePdf() async {
    if (_customerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alıcı adı gerekli'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final items = _invoiceItems
          .where((item) => item.description.text.isNotEmpty)
          .map(
            (item) => {
              'description': item.description.text,
              'quantity': item.quantityValue,
              'unit_price': item.unitPriceValue,
              'total': item.total,
            },
          )
          .toList();

      final result = await InvoiceService.saveInvoice(
        sourceType: 'manual',
        sourceId: DateTime.now().millisecondsSinceEpoch.toString(),
        buyerName: _customerNameController.text,
        buyerTaxNumber: _customerTaxController.text.isEmpty
            ? null
            : _customerTaxController.text,
        buyerAddress: _customerAddressController.text.isEmpty
            ? null
            : _customerAddressController.text,
        subtotal: _subtotal,
        kdvRate: _kdvRate,
        kdvAmount: _kdvAmount,
        total: _grandTotal,
        items: items,
        customInvoiceNumber: _invoiceNumberController.text.isEmpty
            ? null
            : _invoiceNumberController.text,
      );

      final pdfUrl = result['pdf_url'] as String?;
      if (pdfUrl != null) {
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
        );
      }

      ref.invalidate(invoiceArchiveProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fatura kaydedildi ve PDF indirildi'),
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

  Future<void> _downloadArchiveInvoicePdf(Map<String, dynamic> inv) async {
    try {
      final pdfUrl = inv['pdf_url'] as String?;
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
        return;
      }
      // pdf_url yoksa detaylı şablon ile generate et
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF oluşturuluyor...'), backgroundColor: AppColors.info, duration: Duration(seconds: 1)),
        );
      }
      final invoiceItems = (inv['invoice_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final subtotal = double.tryParse(inv['subtotal']?.toString() ?? '0') ?? 0;
      final kdvRate = double.tryParse(inv['kdv_rate']?.toString() ?? '20') ?? 20;
      final kdvAmount = double.tryParse(inv['kdv_amount']?.toString() ?? '0') ?? 0;
      final total = double.tryParse(inv['total']?.toString() ?? '0') ?? 0;
      final sourceType = inv['source_type']?.toString() ?? '';
      String invoiceTypeLabel;
      switch (sourceType) {
        case 'merchant_commission': invoiceTypeLabel = 'KOMİSYON FATURASI'; break;
        case 'merchant_invoice': invoiceTypeLabel = 'İŞLETME FATURASI'; break;
        default: invoiceTypeLabel = 'FATURA';
      }

      final pdfBytes = await InvoiceService.generateInvoicePdf(
        payment: {'amount': total, 'users': {'full_name': inv['buyer_name'] ?? ''}},
        invoiceNumber: inv['invoice_number']?.toString() ?? '-',
        customerInfo: {
          'name': inv['buyer_name']?.toString() ?? '',
          if (inv['buyer_tax_number'] != null) 'taxNumber': inv['buyer_tax_number'].toString(),
          if (inv['buyer_address'] != null) 'address': inv['buyer_address'].toString(),
          if (inv['buyer_email'] != null) 'email': inv['buyer_email'].toString(),
        },
        invoiceType: invoiceTypeLabel,
        items: invoiceItems.isNotEmpty ? invoiceItems : [
          {'description': invoiceTypeLabel, 'unit_price': subtotal, 'total': subtotal},
        ],
        subtotalOverride: subtotal,
        kdvAmountOverride: kdvAmount,
        kdvRateOverride: kdvRate >= 1 ? kdvRate / 100 : kdvRate,
      );
      final invoiceNo = inv['invoice_number']?.toString() ?? 'fatura';
      final safeName = _sanitizeForFileName(inv['buyer_name']?.toString() ?? 'fatura');
      _downloadFile(pdfBytes, '${safeName}_$invoiceNo.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulurken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _exportArchiveToExcel() async {
    final invoices = ref.read(invoiceArchiveProvider('all')).valueOrNull ?? [];
    if (invoices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dışa aktarılacak fatura bulunamadı'), backgroundColor: AppColors.warning),
        );
      }
      return;
    }
    try {
      final excelBytes = await InvoiceService.exportInvoicesToExcel(invoices);
      _downloadFile(Uint8List.fromList(excelBytes), 'fatura_arsivi_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${invoices.length} fatura Excel olarak indirildi'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel oluşturulurken hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _downloadFile(Uint8List bytes, String filename) {
    downloadFile(bytes, filename);
  }

  String _sanitizeForFileName(String name) {
    const tr = 'çÇğĞıİöÖşŞüÜ';
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
        const SnackBar(content: Text('Önce orijinal fatura oluşturulmalı')),
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
      buyerName: payment['users']?['full_name'] ?? 'Bilinmeyen Alıcı',
      buyerEmail: payment['users']?['email'],
      subtotal: refundAmount - kdvAmt,
      kdvRate: 20.0,
      kdvAmount: kdvAmt,
      total: refundAmount,
      invoiceType: 'refund',
      parentInvoiceId: original['id'],
      items: [
        {
          'description': 'İade: ${payment['refund_reason'] ?? 'Hizmet iadesi'}',
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
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', original['id']);

    ref.invalidate(paymentsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İade faturası oluşturuldu'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ─── İşletme Faturaları ────────────────────────────────────────────────────

  Future<void> _fetchMerchantsForInvoice() async {
    setState(() => _merchantsLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('merchants')
          .select(
            'id, business_name, email, phone, type, commission_rate, is_approved',
          )
          .order('business_name');
      _merchantsForInvoice = List<Map<String, dynamic>>.from(response);

      // Dönem seçildiyse sipariş gelirlerini çek
      if (_merchantInvoicePeriod != null) {
        final orders = await supabase
            .from('orders')
            .select('merchant_id, total_amount')
            .eq('status', 'delivered')
            .gte('created_at', _merchantInvoicePeriod!.start.toIso8601String())
            .lte(
              'created_at',
              _merchantInvoicePeriod!.end
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            );
        _merchantRevenues = {};
        for (final o in List<Map<String, dynamic>>.from(orders)) {
          final id = o['merchant_id']?.toString() ?? '';
          final amt =
              double.tryParse(o['total_amount']?.toString() ?? '0') ?? 0;
          _merchantRevenues[id] = (_merchantRevenues[id] ?? 0) + amt;
        }
      } else {
        _merchantRevenues = {};
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşletmeler yüklenirken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _merchantsLoading = false);
    }
  }

  Future<void> _createMerchantInvoice(Map<String, dynamic> merchant) async {
    final merchantId = merchant['id'].toString();
    final revenue = _merchantRevenues[merchantId] ?? 0;
    final commissionRate =
        (merchant['commission_rate'] as num?)?.toDouble() ?? 0;
    final commissionAmount = revenue * commissionRate / 100;

    if (commissionAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komisyon tutarı 0 ₺, dönem seçin veya siparişler yok'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      final supabase = ref.read(supabaseProvider);

      final periodLabel = _merchantInvoicePeriod != null
          ? '${_turkishMonths[_selectedMonth - 1]} $_selectedYear'
          : '${_turkishMonths[DateTime.now().month - 1]} ${DateTime.now().year}';

      final invoicePeriod = _merchantInvoicePeriod != null
          ? '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}'
          : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

      // Aynı dönem için aynı işletmeye fatura kesilmiş mi kontrol et
      final existing = await supabase
          .from('invoices')
          .select('id, invoice_number')
          .eq('source_type', 'merchant_commission')
          .eq('source_id', merchantId)
          .eq('invoice_period', invoicePeriod)
          .neq('status', 'cancelled')
          .maybeSingle();
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${merchant['business_name']} için $periodLabel döneminde zaten fatura kesilmiş (${existing['invoice_number']})',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Dönemdeki siparişleri çek
      var ordersQuery = supabase
          .from('orders')
          .select('id, total_amount, status, created_at, order_number')
          .eq('merchant_id', merchantId)
          .eq('status', 'delivered');
      if (_merchantInvoicePeriod != null) {
        ordersQuery = ordersQuery
            .gte('created_at', _merchantInvoicePeriod!.start.toIso8601String())
            .lte(
              'created_at',
              _merchantInvoicePeriod!.end
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            );
      }
      final orders = await ordersQuery.order('created_at');
      final ordersList = List<Map<String, dynamic>>.from(orders);
      final orderCount = ordersList.length;

      // KDV hesaplama
      final commissionNet = revenue * commissionRate / 100;
      final kdvAmount = double.parse(
        (commissionNet * _merchantKdvRate / 100).toStringAsFixed(2),
      );
      final totalWithKdv = commissionNet + kdvAmount;

      // Fatura kalemleri: her siparişi listele
      final items = <Map<String, dynamic>>[];

      // Siparişleri satır satır ekle (max 50, fazlası özet)
      const maxDetailRows = 50;
      final detailOrders = ordersList.length <= maxDetailRows
          ? ordersList
          : ordersList.sublist(0, maxDetailRows);

      for (final order in detailOrders) {
        final orderNo =
            order['order_number']?.toString() ??
            order['id'].toString().substring(0, 8);
        final orderDate = order['created_at'] != null
            ? DateFormat(
                'dd.MM.yyyy',
              ).format(DateTime.parse(order['created_at']))
            : '';
        final orderAmount = (order['total_amount'] as num?)?.toDouble() ?? 0;
        final orderCommission = double.parse(
          (orderAmount * commissionRate / 100).toStringAsFixed(2),
        );
        items.add({
          'description': '#$orderNo – $orderDate',
          'order_amount': orderAmount,
          'commission': orderCommission,
        });
      }

      // Çok fazla sipariş varsa kalan özet satırı
      if (ordersList.length > maxDetailRows) {
        final remainingCount = ordersList.length - maxDetailRows;
        final remainingTotal = ordersList
            .sublist(maxDetailRows)
            .fold<double>(
              0,
              (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0),
            );
        final remainingCommission = double.parse(
          (remainingTotal * commissionRate / 100).toStringAsFixed(2),
        );
        items.add({
          'description': '... ve $remainingCount sipariş daha',
          'order_amount': remainingTotal,
          'commission': remainingCommission,
        });
      }

      // Toplam satış satırı
      items.add({
        'description': '── TOPLAM SATIŞ ($orderCount sipariş)',
        'order_amount': revenue,
        'commission': double.parse(commissionNet.toStringAsFixed(2)),
        'bold': true,
      });

      // Komisyon satırı (faturalanacak kalem)
      items.add({
        'description':
            '► Platform Komisyon Hizmeti (%${commissionRate.toStringAsFixed(0)})',
        'order_amount': 0,
        'commission': double.parse(commissionNet.toStringAsFixed(2)),
        'bold': true,
      });

      final subtotal = double.parse(commissionNet.toStringAsFixed(2));

      final result = await InvoiceService.saveInvoice(
        sourceType: 'merchant_commission',
        sourceId: merchantId,
        buyerName: merchant['business_name'] ?? '',
        buyerEmail: merchant['email'],
        buyerPhone: merchant['phone'],
        buyerAddress: merchant['address'],
        buyerTaxNumber: merchant['tax_number'],
        buyerTaxOffice: merchant['tax_office'],
        subtotal: subtotal,
        kdvRate: _merchantKdvRate,
        kdvAmount: kdvAmount,
        total: totalWithKdv,
        invoicePeriod: invoicePeriod,
        items: items,
      );

      final invoiceNumber = result['invoice_number'] ?? '';
      final pdfUrl = result['pdf_url'] as String?;
      if (pdfUrl != null) {
        await launchUrl(
          Uri.parse(pdfUrl),
          mode: LaunchMode.externalApplication,
        );
      }

      ref.invalidate(invoiceArchiveProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${merchant['business_name']} → Fatura $invoiceNumber oluşturuldu',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fatura oluşturulamadı: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _createBulkMerchantInvoices() async {
    if (_selectedMerchantForInvoiceIds.isEmpty) return;
    setState(() => _bulkInvoiceCreating = true);

    int success = 0;
    int failed = 0;
    for (final id in _selectedMerchantForInvoiceIds) {
      final merchant = _merchantsForInvoice.firstWhere(
        (m) => m['id'].toString() == id,
        orElse: () => {},
      );
      if (merchant.isEmpty) continue;

      final revenue = _merchantRevenues[id] ?? 0;
      final commissionRate =
          (merchant['commission_rate'] as num?)?.toDouble() ?? 0;
      final commissionAmount = revenue * commissionRate / 100;
      if (commissionAmount <= 0) {
        failed++;
        continue;
      }

      try {
        final supabase = ref.read(supabaseProvider);

        final invoicePeriod = _merchantInvoicePeriod != null
            ? '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}'
            : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

        // Aynı dönemde bu işletme için fatura var mı?
        final dup = await supabase
            .from('invoices')
            .select('id')
            .eq('source_type', 'merchant_commission')
            .eq('source_id', id)
            .eq('invoice_period', invoicePeriod)
            .neq('status', 'cancelled')
            .maybeSingle();
        if (dup != null) {
          failed++;
          continue;
        }

        // Siparişleri çek
        var oQuery = supabase
            .from('orders')
            .select('id, total_amount, created_at, order_number')
            .eq('merchant_id', id)
            .eq('status', 'delivered');
        if (_merchantInvoicePeriod != null) {
          oQuery = oQuery
              .gte(
                'created_at',
                _merchantInvoicePeriod!.start.toIso8601String(),
              )
              .lte(
                'created_at',
                _merchantInvoicePeriod!.end
                    .add(const Duration(days: 1))
                    .toIso8601String(),
              );
        }
        final oList = List<Map<String, dynamic>>.from(
          await oQuery.order('created_at'),
        );
        final orderCount = oList.length;

        final commissionNet = revenue * commissionRate / 100;
        final kdvAmount = double.parse(
          (commissionNet * _merchantKdvRate / 100).toStringAsFixed(2),
        );
        final totalWithKdv = commissionNet + kdvAmount;
        final subtotal = double.parse(commissionNet.toStringAsFixed(2));

        final items = <Map<String, dynamic>>[];
        const maxRows = 50;
        final detailList = oList.length <= maxRows
            ? oList
            : oList.sublist(0, maxRows);
        for (final o in detailList) {
          final oNo =
              o['order_number']?.toString() ??
              o['id'].toString().substring(0, 8);
          final oDate = o['created_at'] != null
              ? DateFormat('dd.MM.yyyy').format(DateTime.parse(o['created_at']))
              : '';
          final oAmt = (o['total_amount'] as num?)?.toDouble() ?? 0;
          final oCom = double.parse(
            (oAmt * commissionRate / 100).toStringAsFixed(2),
          );
          items.add({
            'description': '#$oNo – $oDate',
            'order_amount': oAmt,
            'commission': oCom,
          });
        }
        if (oList.length > maxRows) {
          final remCount = oList.length - maxRows;
          final remTotal = oList
              .sublist(maxRows)
              .fold<double>(
                0,
                (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0),
              );
          final remCom = double.parse(
            (remTotal * commissionRate / 100).toStringAsFixed(2),
          );
          items.add({
            'description': '... ve $remCount sipariş daha',
            'order_amount': remTotal,
            'commission': remCom,
          });
        }
        items.add({
          'description': '── TOPLAM SATIŞ ($orderCount sipariş)',
          'order_amount': revenue,
          'commission': subtotal,
          'bold': true,
        });
        items.add({
          'description':
              '► Platform Komisyon Hizmeti (%${commissionRate.toStringAsFixed(0)})',
          'order_amount': 0,
          'commission': subtotal,
          'bold': true,
        });

        await InvoiceService.saveInvoice(
          sourceType: 'merchant_commission',
          sourceId: id,
          buyerName: merchant['business_name'] ?? '',
          buyerEmail: merchant['email'],
          buyerPhone: merchant['phone'],
          buyerAddress: merchant['address'],
          buyerTaxNumber: merchant['tax_number'],
          buyerTaxOffice: merchant['tax_office'],
          subtotal: subtotal,
          kdvRate: _merchantKdvRate,
          kdvAmount: kdvAmount,
          total: totalWithKdv,
          invoicePeriod: invoicePeriod,
          items: items,
        );

        success++;
      } catch (_) {
        failed++;
      }
    }

    ref.invalidate(invoiceArchiveProvider);
    setState(() {
      _bulkInvoiceCreating = false;
      _selectedMerchantForInvoiceIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$success fatura oluşturuldu${failed > 0 ? ', $failed başarısız' : ''}',
          ),
          backgroundColor: failed > 0 ? AppColors.warning : AppColors.success,
        ),
      );
    }
  }

  String _merchantTypeLabel(String? type) {
    switch (type) {
      case 'restaurant':
        return 'Restoran';
      case 'store':
        return 'Mağaza';
      case 'market':
        return 'Market';
      case 'pharmacy':
        return 'Eczane';
      default:
        return type ?? '-';
    }
  }

  Widget _buildMerchantInvoicesTab() {
    final filtered = _merchantsForInvoice.where((m) {
      if (_merchantSearchQuery.isEmpty) return true;
      final name = (m['business_name'] ?? '').toString().toLowerCase();
      return name.contains(_merchantSearchQuery.toLowerCase());
    }).toList();

    final totalSelectedCommission = _selectedMerchantForInvoiceIds.fold<double>(
      0,
      (sum, id) {
        final m = _merchantsForInvoice.firstWhere(
          (m) => m['id'].toString() == id,
          orElse: () => {},
        );
        if (m.isEmpty) return sum;
        final rev = _merchantRevenues[id] ?? 0;
        final rate = (m['commission_rate'] as num?)?.toDouble() ?? 0;
        return sum + (rev * rate / 100);
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Filtre / kontrol çubuğu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Row(
              children: [
                // Arama
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _merchantSearchController,
                    decoration: InputDecoration(
                      hintText: 'İşletme adı ara...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) => setState(() => _merchantSearchQuery = v),
                  ),
                ),
                const SizedBox(width: 12),
                // Dönem seçici (Ay/Yıl)
                OutlinedButton.icon(
                  onPressed: _showMonthYearPicker,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    _merchantInvoicePeriod != null
                        ? '${_turkishMonths[_selectedMonth - 1]} $_selectedYear'
                        : 'Dönem Seç',
                  ),
                ),
                if (_merchantInvoicePeriod != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Dönemi temizle',
                    onPressed: () => setState(() {
                      _merchantInvoicePeriod = null;
                      _merchantRevenues = {};
                    }),
                  ),
                ],
                const SizedBox(width: 12),
                // KDV oranı (serbest giriş)
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _kdvController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'KDV %',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null && parsed >= 0 && parsed <= 100) {
                        setState(() => _merchantKdvRate = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Yükle butonu
                ElevatedButton.icon(
                  onPressed: _merchantsLoading
                      ? null
                      : _fetchMerchantsForInvoice,
                  icon: _merchantsLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Yükle'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // İstatistik kartları (veri varsa)
          if (_merchantsForInvoice.isNotEmpty) ...[
            Row(
              children: [
                _buildStatCard(
                  'Toplam İşletme',
                  _merchantsForInvoice.length.toString(),
                  Icons.store,
                  AppColors.primary,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Seçili',
                  _selectedMerchantForInvoiceIds.length.toString(),
                  Icons.check_box,
                  AppColors.info,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Dönem Cirosu',
                  _merchantRevenues.isEmpty
                      ? 'Dönem seç'
                      : '₺${_merchantRevenues.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}',
                  Icons.trending_up,
                  AppColors.success,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Toplam Komisyon',
                  _merchantRevenues.isEmpty
                      ? 'Dönem seç'
                      : '₺${_merchantsForInvoice.fold<double>(0, (s, m) {
                          final rev = _merchantRevenues[m['id'].toString()] ?? 0;
                          final rate = (m['commission_rate'] as num?)?.toDouble() ?? 0;
                          return s + rev * rate / 100;
                        }).toStringAsFixed(2)}',
                  Icons.percent,
                  AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Tablo
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _merchantsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _merchantsForInvoice.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.store_mall_directory,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'İşletmeleri yüklemek için "Yükle" butonuna basın',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : DataTable2(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        headingRowColor: WidgetStateProperty.all(
                          AppColors.background,
                        ),
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
                          DataColumn2(
                            label: Text(''),
                            size: ColumnSize.S,
                            fixedWidth: 48,
                          ),
                          DataColumn2(
                            label: Text('İŞLETME'),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(label: Text('TİP'), size: ColumnSize.S),
                          DataColumn2(
                            label: Text('KOMİSYON'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('DÖNEM CİROSU'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('KOMİSYON TUTARI'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('İŞLEMLER'),
                            size: ColumnSize.S,
                          ),
                        ],
                        rows: filtered.map((merchant) {
                          final id = merchant['id'].toString();
                          final isSelected = _selectedMerchantForInvoiceIds
                              .contains(id);
                          final revenue = _merchantRevenues[id] ?? 0;
                          final commissionRate =
                              (merchant['commission_rate'] as num?)
                                  ?.toDouble() ??
                              0;
                          final commissionAmount =
                              revenue * commissionRate / 100;

                          return DataRow2(
                            selected: isSelected,
                            color: isSelected
                                ? WidgetStateProperty.all(
                                    AppColors.primary.withValues(alpha: 0.05),
                                  )
                                : null,
                            cells: [
                              // Checkbox
                              DataCell(
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selectedMerchantForInvoiceIds.add(id);
                                    } else {
                                      _selectedMerchantForInvoiceIds.remove(id);
                                    }
                                  }),
                                ),
                              ),
                              // İşletme adı + email
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      merchant['business_name'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (merchant['email'] != null)
                                      Text(
                                        merchant['email'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Tip
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _merchantTypeLabel(merchant['type']),
                                    style: const TextStyle(
                                      color: AppColors.info,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              // Komisyon oranı
                              DataCell(
                                Text('%${commissionRate.toStringAsFixed(0)}'),
                              ),
                              // Dönem cirosu
                              DataCell(
                                Text(
                                  _merchantRevenues.isEmpty
                                      ? '—'
                                      : '₺${revenue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: _merchantRevenues.isEmpty
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              // Komisyon tutarı
                              DataCell(
                                Text(
                                  _merchantRevenues.isEmpty
                                      ? '—'
                                      : '₺${commissionAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: commissionAmount > 0
                                        ? AppColors.success
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                              // Fatura oluştur butonu
                              DataCell(
                                ElevatedButton.icon(
                                  onPressed: commissionAmount > 0
                                      ? () => _createMerchantInvoice(merchant)
                                      : null,
                                  icon: const Icon(Icons.receipt, size: 16),
                                  label: const Text('Fatura Kes'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
              ),
            ),
          ),

          // Toplu fatura aksiyonu
          if (_selectedMerchantForInvoiceIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedMerchantForInvoiceIds.length} işletme seçili',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Toplam komisyon: ₺${totalSelectedCommission.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedMerchantForInvoiceIds.clear()),
                    child: const Text('Seçimi Temizle'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _bulkInvoiceCreating
                        ? null
                        : _createBulkMerchantInvoices,
                    icon: _bulkInvoiceCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.receipt_long, size: 18),
                    label: Text(
                      _bulkInvoiceCreating
                          ? 'Oluşturuluyor...'
                          : 'Toplu Fatura Kes (${_selectedMerchantForInvoiceIds.length})',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// Invoice Item Controller Helper
class _CustomerInvoiceRow {
  final String id;
  final String date;
  final String customerName;
  final String source;
  final String detail;
  final double amount;
  final String? paymentType;
  final String? status;
  final Map<String, dynamic> rawData;
  final String type; // 'taxi' or 'food'

  _CustomerInvoiceRow({
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
