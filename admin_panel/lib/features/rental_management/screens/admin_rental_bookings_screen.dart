import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/rental_management_providers.dart';

class AdminRentalBookingsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminRentalBookingsScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminRentalBookingsScreen> createState() => _AdminRentalBookingsScreenState();
}

class _AdminRentalBookingsScreenState extends ConsumerState<AdminRentalBookingsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
  final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterBookings(List<Map<String, dynamic>> bookings) {
    return bookings.where((b) {
      final customerName = (b['customer_name'] as String? ?? '').toLowerCase();
      final bookingNumber = (b['booking_number'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          customerName.contains(query) ||
          bookingNumber.contains(query);

      final status = b['status'] as String? ?? '';
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('rental_bookings').update({'status': newStatus}).eq('id', bookingId);
      ref.invalidate(rentalCompanyBookingsProvider(widget.companyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rezervasyon durumu güncellendi'), backgroundColor: AppColors.success),
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

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(rentalCompanyBookingsProvider(widget.companyId));

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
                      'Rezervasyonlar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kiralama rezervasyonlarını yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(rentalCompanyBookingsProvider(widget.companyId)),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yenile'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Status Tabs
            _buildStatusTabs(),

            const SizedBox(height: 16),

            // Search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: TextField(
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) setState(() => _searchQuery = value);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Müşteri adı veya rezervasyon numarası ile ara...',
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

            const SizedBox(height: 16),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: bookingsAsync.when(
                  data: (bookings) {
                    final filtered = _filterBookings(bookings);
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('Rezervasyon bulunamadı', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    return _buildDataTable(filtered);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    final tabs = [
      {'label': 'Tümü', 'value': 'all'},
      {'label': 'Beklemede', 'value': 'pending'},
      {'label': 'Onaylandı', 'value': 'confirmed'},
      {'label': 'Aktif', 'value': 'active'},
      {'label': 'Tamamlandı', 'value': 'completed'},
      {'label': 'İptal', 'value': 'cancelled'},
    ];

    return Row(
      children: tabs.map((tab) {
        final isSelected = _statusFilter == tab['value'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(tab['label']!),
            selected: isSelected,
            onSelected: (_) => setState(() => _statusFilter = tab['value']!),
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected ? AppColors.primary : AppColors.surfaceLight,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> bookings) {
    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background.withValues(alpha: 0.5)),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        columns: const [
          DataColumn(label: Text('Rez. No', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Müşteri', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Araç', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Alış Tarihi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('İade Tarihi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Gün', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Alış Noktası', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('İade Noktası', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Tutar', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Durum', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Ödeme', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('İşlem', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        ],
        rows: bookings.map((b) {
          final bookingNumber = b['booking_number'] as String? ?? '-';
          final customerName = b['customer_name'] as String? ?? '-';
          final car = b['rental_cars'] as Map<String, dynamic>?;
          final carLabel = car != null ? '${car['brand'] ?? ''} ${car['model'] ?? ''}' : '-';
          final pickupDate = DateTime.tryParse(b['pickup_date'] as String? ?? '');
          final dropoffDate = DateTime.tryParse(b['dropoff_date'] as String? ?? '');
          final rentalDays = b['rental_days']?.toString() ?? '-';
          final pickupLocation = (b['rental_locations!pickup_location_id'] as Map<String, dynamic>?)?['name'] as String? ?? '-';
          final dropoffLocation = (b['rental_locations!dropoff_location_id'] as Map<String, dynamic>?)?['name'] as String? ?? '-';
          final totalAmount = (b['total_amount'] as num?)?.toDouble() ?? 0;
          final status = b['status'] as String? ?? '';
          final paymentStatus = b['payment_status'] as String? ?? '';

          return DataRow(cells: [
            DataCell(Text(bookingNumber, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
            DataCell(Text(customerName, style: const TextStyle(color: AppColors.textPrimary))),
            DataCell(Text(carLabel, style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(Text(pickupDate != null ? _dateFormat.format(pickupDate) : '-', style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(Text(dropoffDate != null ? _dateFormat.format(dropoffDate) : '-', style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(Text(rentalDays, style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(Text(pickupLocation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            DataCell(Text(dropoffLocation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            DataCell(Text(_currencyFormat.format(totalAmount), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(_buildStatusBadge(status)),
            DataCell(_buildPaymentBadge(paymentStatus)),
            DataCell(_buildActionButton(b['id'], status)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Beklemede';
        break;
      case 'confirmed':
        color = AppColors.info;
        label = 'Onaylandı';
        break;
      case 'active':
        color = AppColors.primary;
        label = 'Aktif';
        break;
      case 'completed':
        color = AppColors.success;
        label = 'Tamamlandı';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'İptal';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus) {
    final isPaid = paymentStatus == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPaid ? 'Ödendi' : 'Bekliyor',
        style: TextStyle(
          color: isPaid ? AppColors.success : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButton(String bookingId, String currentStatus) {
    final actions = <PopupMenuEntry<String>>[];

    if (currentStatus == 'pending') {
      actions.add(const PopupMenuItem(value: 'confirmed', child: Text('Onayla')));
      actions.add(const PopupMenuItem(value: 'cancelled', child: Text('İptal Et')));
    } else if (currentStatus == 'confirmed') {
      actions.add(const PopupMenuItem(value: 'active', child: Text('Aktif Et')));
      actions.add(const PopupMenuItem(value: 'cancelled', child: Text('İptal Et')));
    } else if (currentStatus == 'active') {
      actions.add(const PopupMenuItem(value: 'completed', child: Text('Tamamla')));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
      itemBuilder: (context) => actions,
      onSelected: (value) => _updateBookingStatus(bookingId, value),
    );
  }
}
