import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Bookings provider
final bookingsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_bookings')
      .select('''
        *,
        rental_cars(brand, model, plate, image_url),
        pickup_location:rental_locations!pickup_location_id(name, city),
        dropoff_location:rental_locations!dropoff_location_id(name, city)
      ''')
      .eq('company_id', companyId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

// Available cars provider for manual booking
final availableCarsProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_cars')
      .select('id, brand, model, plate, daily_price')
      .eq('company_id', companyId)
      .eq('status', 'available')
      .eq('is_active', true)
      .order('brand');

  return List<Map<String, dynamic>>.from(response);
});

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String _searchQuery = '';
  String? _statusFilter;

  Map<String, int> _getStatusCounts(List<Map<String, dynamic>> bookings) {
    final counts = <String, int>{
      'pending': 0,
      'confirmed': 0,
      'active': 0,
      'completed': 0,
      'cancelled': 0,
    };
    for (final b in bookings) {
      final status = b['status'] as String? ?? '';
      if (counts.containsKey(status)) {
        counts[status] = counts[status]! + 1;
      }
    }
    return counts;
  }

  bool _isToday(String? dateStr) {
    if (dateStr == null) return false;
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isOverdue(Map<String, dynamic> booking) {
    if (booking['status'] != 'active') return false;
    final dropoff = DateTime.tryParse(booking['dropoff_date'] ?? '');
    if (dropoff == null) return false;
    final today = DateTime.now();
    return DateTime(dropoff.year, dropoff.month, dropoff.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(bookingsProvider);
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            bookingsAsync.when(
              data: (bookings) {
                final counts = _getStatusCounts(bookings);
                return _buildHeader(context, counts);
              },
              loading: () => _buildHeader(context, {}),
              error: (_, __) => _buildHeader(context, {}),
            ),
            const SizedBox(height: 20),

            // Search
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rezervasyon ara (musteri adi, telefon, plaka)',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: Card(
                child: bookingsAsync.when(
                  data: (bookings) {
                    var filtered = bookings.where((b) {
                      if (_statusFilter != null && b['status'] != _statusFilter) {
                        return false;
                      }
                      if (_searchQuery.isNotEmpty) {
                        final name = (b['customer_name'] ?? '').toString().toLowerCase();
                        final phone = (b['customer_phone'] ?? '').toString().toLowerCase();
                        final car = b['rental_cars'] as Map<String, dynamic>?;
                        final plate = (car?['plate'] ?? '').toString().toLowerCase();
                        final bookingNo = (b['booking_number'] ?? '').toString().toLowerCase();
                        if (!name.contains(_searchQuery) &&
                            !phone.contains(_searchQuery) &&
                            !plate.contains(_searchQuery) &&
                            !bookingNo.contains(_searchQuery)) {
                          return false;
                        }
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.book_online, size: 56, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _statusFilter != null
                                  ? 'Bu durumda rezervasyon yok'
                                  : 'Rezervasyon bulunamadi',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
                            ),
                            if (_statusFilter != null) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => setState(() => _statusFilter = null),
                                child: const Text('Tum rezervasyonlari goster'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 16,
                      minWidth: 1000,
                      columns: const [
                        DataColumn2(label: Text('Arac'), size: ColumnSize.L),
                        DataColumn2(label: Text('Musteri'), size: ColumnSize.L),
                        DataColumn2(label: Text('Tarih')),
                        DataColumn2(label: Text('Sure'), fixedWidth: 70),
                        DataColumn2(label: Text('Tutar'), fixedWidth: 100),
                        DataColumn2(label: Text('Durum'), fixedWidth: 110),
                        DataColumn2(label: Text('Islemler'), fixedWidth: 180),
                      ],
                      rows: filtered.map((booking) {
                        final car = booking['rental_cars'] as Map<String, dynamic>?;
                        final pickupDate = DateTime.tryParse(booking['pickup_date'] ?? '');
                        final dropoffDate = DateTime.tryParse(booking['dropoff_date'] ?? '');
                        final rentalDays = (booking['rental_days'] as num?)?.toInt() ?? 0;
                        final isOverdue = _isOverdue(booking);
                        final isTodayPickup = booking['status'] == 'confirmed' &&
                            _isToday(booking['pickup_date']);
                        final isTodayReturn = booking['status'] == 'active' &&
                            _isToday(booking['dropoff_date']);

                        return DataRow2(
                          onTap: () => context.go('/bookings/${booking['id']}'),
                          color: WidgetStateProperty.resolveWith((states) {
                            if (isOverdue) return AppColors.error.withValues(alpha: 0.08);
                            if (isTodayPickup) return AppColors.info.withValues(alpha: 0.06);
                            if (isTodayReturn) return AppColors.success.withValues(alpha: 0.06);
                            return null;
                          }),
                          cells: [
                            // Arac
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: car?['image_url'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              car!['image_url'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.directions_car,
                                                color: AppColors.textMuted,
                                                size: 20,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.directions_car,
                                            color: AppColors.textMuted,
                                            size: 20,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          car != null
                                              ? '${car['brand']} ${car['model']}'
                                              : '-',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          car?['plate'] ?? '',
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
                            // Musteri
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          booking['customer_name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (booking['is_pickup_custom_address'] == true ||
                                          booking['is_dropoff_custom_address'] == true) ...[
                                        const SizedBox(width: 4),
                                        const Tooltip(
                                          message: 'Adrese Teslim',
                                          child: Icon(
                                            Icons.home,
                                            size: 14,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    booking['customer_phone'] ?? '',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Tarih
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      if (isTodayPickup)
                                        Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.info.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text('Bugun',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.info,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      Text(
                                        pickupDate != null ? dateFormat.format(pickupDate) : '-',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (isOverdue)
                                        Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text('Gecikti',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.error,
                                                  fontWeight: FontWeight.w600)),
                                        )
                                      else if (isTodayReturn)
                                        Container(
                                          margin: const EdgeInsets.only(right: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text('Bugun',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.success,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      Text(
                                        dropoffDate != null ? dateFormat.format(dropoffDate) : '-',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Sure
                            DataCell(
                              Text(
                                '$rentalDays gun',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            // Tutar
                            DataCell(
                              Text(
                                formatter.format(booking['total_amount'] ?? 0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            // Durum
                            DataCell(_buildStatusBadge(booking['status'] ?? '')),
                            // Islemler
                            DataCell(_buildActionButtons(booking)),
                          ],
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Hata: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, int> counts) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Rezervasyonlar',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildQuickFilter('Tumu', null, null),
            _buildQuickFilter('Beklemede', 'pending', counts['pending']),
            _buildQuickFilter('Onayli', 'confirmed', counts['confirmed']),
            _buildQuickFilter('Aktif', 'active', counts['active']),
            _buildQuickFilter('Tamamlandi', 'completed', counts['completed']),
            _buildQuickFilter('Iptal', 'cancelled', counts['cancelled']),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showManualBookingDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Manuel Kiralama'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickFilter(String label, String? status, int? count) {
    final isSelected = _statusFilter == status;
    final hasCount = count != null && count > 0;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (hasCount) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : _getStatusColor(status).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _statusFilter = status;
          });
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.info;
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.secondary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    String label;
    switch (status) {
      case 'pending':
        label = 'Beklemede';
      case 'confirmed':
        label = 'Onaylandi';
      case 'active':
        label = 'Aktif';
      case 'completed':
        label = 'Tamamlandi';
      case 'cancelled':
        label = 'Iptal';
      default:
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> booking) {
    final status = booking['status'] ?? '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == 'pending') ...[
          _buildActionBtn(
            label: 'Onayla',
            icon: Icons.check,
            color: AppColors.success,
            onPressed: () => _handleAction(booking, 'confirm'),
          ),
          const SizedBox(width: 6),
          _buildActionBtn(
            label: 'Reddet',
            icon: Icons.close,
            color: AppColors.error,
            onPressed: () => _showRejectDialog(booking),
          ),
        ],
        if (status == 'confirmed')
          _buildActionBtn(
            label: 'Teslim Et',
            icon: Icons.car_rental,
            color: AppColors.info,
            onPressed: () => _handleAction(booking, 'activate'),
          ),
        if (status == 'active')
          _buildActionBtn(
            label: 'Teslim Al',
            icon: Icons.done_all,
            color: AppColors.success,
            onPressed: () => _handleAction(booking, 'complete'),
          ),
        if (status != 'pending') ...[
          if (status == 'confirmed' || status == 'active')
            const SizedBox(width: 6),
          _buildIconBtn(
            tooltip: 'Detay',
            icon: Icons.visibility,
            color: AppColors.textSecondary,
            onPressed: () => context.go('/bookings/${booking['id']}'),
          ),
        ],
        if (status == 'pending') ...[
          const SizedBox(width: 6),
          _buildIconBtn(
            tooltip: 'Detay',
            icon: Icons.info_outline,
            color: AppColors.textSecondary,
            onPressed: () => context.go('/bookings/${booking['id']}'),
          ),
        ],
      ],
    );
  }

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _buildIconBtn({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }

  Future<void> _showManualBookingDialog(BuildContext context) async {
    final availableCars = await ref.read(availableCarsProvider.future);

    if (availableCars.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Musait arac bulunamadi'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _ManualBookingDialog(
        availableCars: availableCars,
        onSave: (bookingData) async {
          try {
            final client = ref.read(supabaseClientProvider);
            final companyId = await ref.read(companyIdProvider.future);

            final bookingNumber = 'MN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

            await client.from('rental_bookings').insert({
              ...bookingData,
              'company_id': companyId,
              'booking_number': bookingNumber,
              'status': 'active',
              'payment_status': bookingData['payment_status'] ?? 'pending',
              'net_amount': bookingData['total_amount'],
            });

            await client
                .from('rental_cars')
                .update({'status': 'rented'})
                .eq('id', bookingData['car_id']);

            ref.invalidate(bookingsProvider);
            ref.invalidate(availableCarsProvider);

            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manuel kiralama olusturuldu')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Hata: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _handleAction(Map<String, dynamic> booking, String action) async {
    if (action == 'view') {
      context.go('/bookings/${booking['id']}');
      return;
    }

    String? newStatus;
    switch (action) {
      case 'confirm':
        newStatus = 'confirmed';
      case 'cancel':
        newStatus = 'cancelled';
      case 'activate':
        newStatus = 'active';
      case 'complete':
        newStatus = 'completed';
    }

    if (newStatus != null) {
      try {
        final client = ref.read(supabaseClientProvider);
        await client
            .from('rental_bookings')
            .update({
              'status': newStatus,
              if (newStatus == 'confirmed') 'confirmed_at': DateTime.now().toIso8601String(),
              if (newStatus == 'active') 'actual_pickup_date': DateTime.now().toIso8601String(),
              if (newStatus == 'completed') 'actual_dropoff_date': DateTime.now().toIso8601String(),
            })
            .eq('id', booking['id']);

        if (newStatus == 'active') {
          await client
              .from('rental_cars')
              .update({'status': 'rented'})
              .eq('id', booking['car_id']);
        }

        if (newStatus == 'completed' || newStatus == 'cancelled') {
          await client
              .from('rental_cars')
              .update({'status': 'available'})
              .eq('id', booking['car_id']);
        }

        await _sendNotification(
          bookingId: booking['id'],
          notificationType: newStatus == 'confirmed'
              ? 'booking_confirmed'
              : newStatus == 'completed'
                  ? 'rental_completed'
                  : newStatus == 'active'
                      ? 'car_ready'
                      : null,
        );

        ref.invalidate(bookingsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              newStatus == 'confirmed'
                  ? 'Rezervasyon onaylandi ve musteriye bildirim gonderildi'
                  : 'Rezervasyon guncellendi',
            )),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendNotification({
    required String bookingId,
    String? notificationType,
  }) async {
    if (notificationType == null) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client.functions.invoke(
        'send-booking-notification',
        body: {
          'booking_id': bookingId,
          'notification_type': notificationType,
        },
      );
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  Future<void> _showRejectDialog(Map<String, dynamic> booking) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezervasyonu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${booking['customer_name']} adli musterinin rezervasyonunu reddetmek istediginize emin misiniz?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Red Sebebi (Opsiyonel)',
                hintText: 'Musteriye bildirilecek...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(supabaseClientProvider);
        await client.from('rental_bookings').update({
          'status': 'cancelled',
          'cancellation_reason': reasonController.text.trim().isEmpty
              ? 'Sirket tarafindan reddedildi'
              : reasonController.text.trim(),
          'cancelled_at': DateTime.now().toIso8601String(),
        }).eq('id', booking['id']);

        await _sendNotification(
          bookingId: booking['id'],
          notificationType: 'booking_rejected',
        );

        ref.invalidate(bookingsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rezervasyon reddedildi ve musteriye bildirildi')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }
}

// Manuel Kiralama Dialog
class _ManualBookingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableCars;
  final Function(Map<String, dynamic>) onSave;

  const _ManualBookingDialog({
    required this.availableCars,
    required this.onSave,
  });

  @override
  State<_ManualBookingDialog> createState() => _ManualBookingDialogState();
}

class _ManualBookingDialogState extends State<_ManualBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _licenseNoController = TextEditingController();
  final _notesController = TextEditingController();
  final _carSearchController = TextEditingController();

  String? _selectedCarId;
  String _carSearchQuery = '';
  DateTime _pickupDate = DateTime.now();
  DateTime _dropoffDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _pickupTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _dropoffTime = const TimeOfDay(hour: 18, minute: 0);
  String _paymentStatus = 'pending';
  String _paymentMethod = 'cash';

  bool _isLoading = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _licenseNoController.dispose();
    _notesController.dispose();
    _carSearchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredCars {
    if (_carSearchQuery.isEmpty) return widget.availableCars;
    final query = _carSearchQuery.toLowerCase();
    return widget.availableCars.where((car) {
      final brand = (car['brand'] ?? '').toString().toLowerCase();
      final model = (car['model'] ?? '').toString().toLowerCase();
      final plate = (car['plate'] ?? '').toString().toLowerCase();
      return brand.contains(query) || model.contains(query) || plate.contains(query);
    }).toList();
  }

  Map<String, dynamic>? get _selectedCar {
    if (_selectedCarId == null) return null;
    return widget.availableCars.firstWhere(
      (c) => c['id'] == _selectedCarId,
      orElse: () => <String, dynamic>{},
    );
  }

  int get _rentalDays {
    return _dropoffDate.difference(_pickupDate).inDays;
  }

  double get _totalAmount {
    final car = _selectedCar;
    if (car == null) return 0;
    final dailyPrice = (car['daily_price'] as num?)?.toDouble() ?? 0;
    return dailyPrice * _rentalDays;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd MMM yyyy');

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_note, color: AppColors.secondary),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Manuel Kiralama',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Uygulama disindan yapilan kiralamalari sisteme kaydedin',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  _buildCarSelector(formatter),
                  const SizedBox(height: 16),

                  const Text(
                    'Teslim Alma',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _pickupDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _pickupDate = date;
                                if (_dropoffDate.isBefore(_pickupDate)) {
                                  _dropoffDate = _pickupDate.add(const Duration(days: 1));
                                }
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tarih',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(dateFormat.format(_pickupDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _pickupTime,
                            );
                            if (time != null) {
                              setState(() => _pickupTime = time);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Saat',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_pickupTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Teslim',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _dropoffDate,
                              firstDate: _pickupDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() => _dropoffDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tarih',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(dateFormat.format(_dropoffDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _dropoffTime,
                            );
                            if (time != null) {
                              setState(() => _dropoffTime = time);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Saat',
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_dropoffTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Musteri Bilgileri',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Ad Soyad *',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _customerPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Telefon *',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (v) => v?.isEmpty == true ? 'Zorunlu' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customerEmailController,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _licenseNoController,
                          decoration: const InputDecoration(
                            labelText: 'Ehliyet No',
                            prefixIcon: Icon(Icons.badge),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentStatus,
                          decoration: const InputDecoration(
                            labelText: 'Odeme Durumu',
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
                            DropdownMenuItem(value: 'paid', child: Text('Odendi')),
                            DropdownMenuItem(value: 'partial', child: Text('Kismi Odeme')),
                          ],
                          onChanged: (v) => setState(() => _paymentStatus = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Odeme Yontemi',
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Nakit')),
                            DropdownMenuItem(value: 'credit_card', child: Text('Kredi Karti')),
                            DropdownMenuItem(value: 'bank_transfer', child: Text('Havale/EFT')),
                          ],
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notlar',
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  if (_selectedCarId != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_rentalDays gun',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatter.format(_totalAmount),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const Icon(
                            Icons.receipt_long,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Iptal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _save,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Kiralamavi Baslat'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarSelector(NumberFormat formatter) {
    final selectedCar = _selectedCar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedCar != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedCar['brand']} ${selectedCar['model']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${selectedCar['plate']} - ${formatter.format(selectedCar['daily_price'])}/gun',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedCarId = null;
                      _carSearchController.clear();
                      _carSearchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Arac Degistir',
                ),
              ],
            ),
          ),
        ] else ...[
          TextField(
            controller: _carSearchController,
            decoration: InputDecoration(
              labelText: 'Arac Ara *',
              hintText: 'Marka, model veya plaka yazin...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _carSearchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _carSearchController.clear();
                          _carSearchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear, size: 20),
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _carSearchQuery = value);
            },
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: _filteredCars.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Arac bulunamadi',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filteredCars.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final car = _filteredCars[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.directions_car, size: 20),
                        title: Text(
                          '${car['brand']} ${car['model']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${car['plate']} - ${formatter.format(car['daily_price'])}/gun',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCarId = car['id'] as String;
                            _carSearchQuery = '';
                            _carSearchController.clear();
                          });
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_filteredCars.length} / ${widget.availableCars.length} musait arac',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen bir arac secin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final car = _selectedCar!;
    final dailyPrice = (car['daily_price'] as num?)?.toDouble() ?? 0;

    final pickupDateTime = DateTime(
      _pickupDate.year,
      _pickupDate.month,
      _pickupDate.day,
      _pickupTime.hour,
      _pickupTime.minute,
    );
    final dropoffDateTime = DateTime(
      _dropoffDate.year,
      _dropoffDate.month,
      _dropoffDate.day,
      _dropoffTime.hour,
      _dropoffTime.minute,
    );

    widget.onSave({
      'car_id': _selectedCarId,
      'pickup_date': pickupDateTime.toIso8601String(),
      'dropoff_date': dropoffDateTime.toIso8601String(),
      'daily_rate': dailyPrice,
      'rental_days': _rentalDays,
      'subtotal': _totalAmount,
      'total_amount': _totalAmount,
      'customer_name': _customerNameController.text.trim(),
      'customer_phone': _customerPhoneController.text.trim(),
      'customer_email': _customerEmailController.text.trim().isEmpty
          ? null
          : _customerEmailController.text.trim(),
      'driver_license_no': _licenseNoController.text.trim().isEmpty
          ? null
          : _licenseNoController.text.trim(),
      'company_notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'payment_status': _paymentStatus,
      'payment_method': _paymentMethod,
    });
  }
}
