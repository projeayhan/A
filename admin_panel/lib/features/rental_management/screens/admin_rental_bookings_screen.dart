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
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM', 'tr_TR');
  final _fullDateFormat = DateFormat('dd.MM.yyyy');

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

  String _calculateDateRange(DateTime? pickup, DateTime? dropoff) {
    if (pickup == null || dropoff == null) {
      return '-';
    }
    final days = dropoff.difference(pickup).inDays;
    return '${_dateFormat.format(pickup)} - ${_dateFormat.format(dropoff)} ($days gün)';
  }

  void _showBookingDetailDialog(Map<String, dynamic> booking) {
    final car = booking['rental_cars'] as Map<String, dynamic>?;
    final carLabel = car != null ? '${car['brand'] ?? ''} ${car['model'] ?? ''}' : '-';
    final carImage = car?['image_url'] as String?;
    final customerName = booking['customer_name'] as String? ?? '-';
    final customerPhone = booking['customer_phone'] as String? ?? '-';
    final customerEmail = booking['customer_email'] as String? ?? '-';
    final pickupDate = DateTime.tryParse(booking['pickup_date'] as String? ?? '');
    final dropoffDate = DateTime.tryParse(booking['dropoff_date'] as String? ?? '');
    final totalPrice = (booking['total_amount'] as num?)?.toDouble() ?? (booking['total_price'] as num?)?.toDouble() ?? 0;
    final status = booking['status'] as String? ?? '';
    final paymentStatus = booking['payment_status'] as String? ?? '';
    final paymentMethod = booking['payment_method'] as String? ?? '-';
    final bookingNumber = booking['booking_number'] as String? ?? '-';
    final pickupLoc = booking['rental_locations'] as Map<String, dynamic>?;
    final pickupLocation = pickupLoc?['name'] as String? ?? (booking['pickup_custom_address'] as String? ?? '-');
    final dropoffLocation = booking['dropoff_custom_address'] as String? ?? '-';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.book_online, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Rezervasyon #$bookingNumber', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18)),
            const Spacer(),
            _buildStatusBadge(status),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Car info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: carImage != null && carImage.isNotEmpty
                            ? Image.network(carImage, width: 80, height: 60, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 80, height: 60, color: AppColors.surfaceLight,
                                  child: const Icon(Icons.directions_car, size: 24, color: AppColors.textMuted),
                                ),
                              )
                            : Container(
                                width: 80, height: 60, color: AppColors.surfaceLight,
                                child: const Icon(Icons.directions_car, size: 24, color: AppColors.textMuted),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(carLabel, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                          if (car?['plate'] != null)
                            Text(car!['plate'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Customer info
                const Text('Müşteri Bilgileri', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.person, 'Ad Soyad', customerName),
                _buildDetailRow(Icons.phone, 'Telefon', customerPhone),
                _buildDetailRow(Icons.email, 'E-posta', customerEmail),
                const SizedBox(height: 16),

                // Date info
                const Text('Tarih Bilgileri', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.calendar_today, 'Alış Tarihi', pickupDate != null ? _fullDateFormat.format(pickupDate) : '-'),
                _buildDetailRow(Icons.event, 'İade Tarihi', dropoffDate != null ? _fullDateFormat.format(dropoffDate) : '-'),
                if (pickupDate != null && dropoffDate != null)
                  _buildDetailRow(Icons.timelapse, 'Süre', '${dropoffDate.difference(pickupDate).inDays} gün'),
                const SizedBox(height: 16),

                // Location info
                const Text('Lokasyon', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.location_on, 'Alış Noktası', pickupLocation),
                _buildDetailRow(Icons.flag, 'İade Noktası', dropoffLocation),
                const SizedBox(height: 16),

                // Payment info
                const Text('Ödeme', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildDetailRow(Icons.attach_money, 'Toplam', _currencyFormat.format(totalPrice))),
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Ödeme: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          _buildPaymentBadge(paymentStatus),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildDetailRow(Icons.payment, 'Ödeme Yöntemi', _paymentMethodLabel(paymentMethod)),
              ],
            ),
          ),
        ),
        actions: [
          if (status == 'pending') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateBookingStatus(booking['id'], 'cancelled');
              },
              child: const Text('İptal Et', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateBookingStatus(booking['id'], 'confirmed');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              child: const Text('Onayla'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
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
                    if (mounted) {
                      setState(() => _searchQuery = value);
                    }
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

            // Booking Cards
            Expanded(
              child: bookingsAsync.when(
                data: (bookings) {
                  final filtered = _filterBookings(bookings);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.book_online_outlined, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text('Rezervasyon bulunamadı', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildBookingCard(filtered[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
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
      {'label': 'Bekleyen', 'value': 'pending'},
      {'label': 'Onaylanan', 'value': 'confirmed'},
      {'label': 'Aktif', 'value': 'active'},
      {'label': 'Tamamlanan', 'value': 'completed'},
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final car = booking['rental_cars'] as Map<String, dynamic>?;
    final carLabel = car != null ? '${car['brand'] ?? ''} ${car['model'] ?? ''}' : '-';
    final carImage = car?['image_url'] as String?;
    final customerName = booking['customer_name'] as String? ?? '-';
    final pickupDate = DateTime.tryParse(booking['pickup_date'] as String? ?? '');
    final dropoffDate = DateTime.tryParse(booking['dropoff_date'] as String? ?? '');
    final totalPrice = (booking['total_amount'] as num?)?.toDouble() ?? (booking['total_price'] as num?)?.toDouble() ?? 0;
    final status = booking['status'] as String? ?? '';
    final paymentStatus = booking['payment_status'] as String? ?? '';
    final bookingId = booking['id'] as String? ?? '';
    final pickupLoc = booking['rental_locations'] as Map<String, dynamic>?;
    final pickupLocation = pickupLoc?['name'] as String? ?? '-';

    return GestureDetector(
      onTap: () => _showBookingDetailDialog(booking),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            // Car image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: carImage != null && carImage.isNotEmpty
                  ? Image.network(carImage, width: 90, height: 65, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 90, height: 65, color: AppColors.surfaceLight,
                        child: const Icon(Icons.directions_car, size: 28, color: AppColors.textMuted),
                      ),
                    )
                  : Container(
                      width: 90, height: 65, color: AppColors.surfaceLight,
                      child: const Icon(Icons.directions_car, size: 28, color: AppColors.textMuted),
                    ),
            ),
            const SizedBox(width: 16),

            // Car + Customer info
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(carLabel, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(customerName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),

            // Date range
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _calculateDateRange(pickupDate, dropoffDate),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(pickupLocation, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            // Price
            SizedBox(
              width: 100,
              child: Text(
                _currencyFormat.format(totalPrice),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

            // Payment status
            SizedBox(
              width: 80,
              child: Center(child: _buildPaymentBadge(paymentStatus)),
            ),

            // Status badge
            SizedBox(
              width: 100,
              child: Center(child: _buildStatusBadge(status)),
            ),

            // Actions
            SizedBox(
              width: 100,
              child: _buildQuickActions(bookingId, status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(String bookingId, String status) {
    if (status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => _updateBookingStatus(bookingId, 'confirmed'),
            icon: const Icon(Icons.check_circle, color: AppColors.success, size: 22),
            tooltip: 'Onayla',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _updateBookingStatus(bookingId, 'cancelled'),
            icon: const Icon(Icons.cancel, color: AppColors.error, size: 22),
            tooltip: 'İptal Et',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    }

    final actions = <PopupMenuEntry<String>>[];
    if (status == 'confirmed') {
      actions.add(const PopupMenuItem(value: 'active', child: Text('Aktif Et')));
      actions.add(const PopupMenuItem(value: 'cancelled', child: Text('İptal Et')));
    } else if (status == 'active') {
      actions.add(const PopupMenuItem(value: 'completed', child: Text('Tamamla')));
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
        itemBuilder: (context) => actions,
        onSelected: (value) => _updateBookingStatus(bookingId, value),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Bekleyen';
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

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'credit_card':
        return 'Kredi Kartı';
      case 'cash':
        return 'Nakit';
      case 'bank_transfer':
        return 'Havale/EFT';
      default:
        return method;
    }
  }
}
