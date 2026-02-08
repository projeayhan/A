import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Booking detail provider
final bookingDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from('rental_bookings')
      .select('''
        *,
        rental_cars(*),
        rental_companies(company_name, phone, email),
        pickup_location:rental_locations!pickup_location_id(*),
        dropoff_location:rental_locations!dropoff_location_id(*)
      ''')
      .eq('id', bookingId)
      .maybeSingle();

  return response;
});

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final dateFormat = DateFormat('dd MMMM yyyy', 'tr_TR');
    final timeFormat = DateFormat('HH:mm', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bookingAsync.when(
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Rezervasyon bulunamadı'));
          }

          final car = booking['rental_cars'] as Map<String, dynamic>?;
          final pickupLocation = booking['pickup_location'] as Map<String, dynamic>?;
          final dropoffLocation = booking['dropoff_location'] as Map<String, dynamic>?;
          final pickupDate = DateTime.tryParse(booking['pickup_date'] ?? '');
          final dropoffDate = DateTime.tryParse(booking['dropoff_date'] ?? '');
          final status = booking['status'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/bookings'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rezervasyon #${booking['booking_number'] ?? bookingId.substring(0, 8)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Oluşturulma: ${DateTime.tryParse(booking['created_at'] ?? '') != null ? dateFormat.format(DateTime.parse(booking['created_at'])) : '-'}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                    const SizedBox(width: 16),
                    _buildActionButtons(context, ref, booking),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Timeline
                _buildStatusTimeline(status, booking),
                const SizedBox(height: 24),

                // Content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Car info
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Car image
                                  Container(
                                    width: 200,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: car?['image_url'] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              car!['image_url'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.directions_car,
                                                size: 48,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.directions_car,
                                            size: 48,
                                            color: AppColors.textMuted,
                                          ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Car details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          car != null
                                              ? '${car['brand']} ${car['model']}'
                                              : 'Araç',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            _buildCarSpec(Icons.calendar_today, '${car?['year'] ?? '-'}'),
                                            const SizedBox(width: 16),
                                            _buildCarSpec(Icons.settings, car?['transmission'] == 'automatic' ? 'Otomatik' : 'Manuel'),
                                            const SizedBox(width: 16),
                                            _buildCarSpec(Icons.local_gas_station, _getFuelLabel(car?['fuel_type'])),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceLight,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                car?['plate'] ?? car?['plate_number'] ?? '-',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  letterSpacing: 1.2,
                                                ),
                                              ),
                                            ),
                                            if (car?['id'] != null) ...[
                                              const SizedBox(width: 12),
                                              TextButton.icon(
                                                onPressed: () => context.go('/cars/${car!['id']}'),
                                                icon: const Icon(Icons.open_in_new, size: 14),
                                                label: const Text('Araç Detayı', style: TextStyle(fontSize: 12)),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  minimumSize: Size.zero,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dates & Locations
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kiralama Detayları',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      // Pickup
                                      Expanded(
                                        child: _buildLocationCard(
                                          'Alış',
                                          pickupLocation?['name'] ?? '-',
                                          pickupLocation?['city'] ?? '',
                                          pickupDate != null ? dateFormat.format(pickupDate) : '-',
                                          pickupDate != null ? timeFormat.format(pickupDate) : '-',
                                          AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Arrow
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Dropoff
                                      Expanded(
                                        child: _buildLocationCard(
                                          'İade',
                                          dropoffLocation?['name'] ?? '-',
                                          dropoffLocation?['city'] ?? '',
                                          dropoffDate != null ? dateFormat.format(dropoffDate) : '-',
                                          dropoffDate != null ? timeFormat.format(dropoffDate) : '-',
                                          AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Duration & overdue warning
                                  _buildDurationBar(booking, pickupDate, dropoffDate),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Delivery details card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Teslim Bilgileri',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDeliveryDetailCard(
                                          title: booking['is_pickup_custom_address'] == true
                                              ? 'Araç Alış (Adrese Teslim)'
                                              : 'Araç Alış',
                                          icon: booking['is_pickup_custom_address'] == true
                                              ? Icons.home
                                              : Icons.login,
                                          color: AppColors.success,
                                          items: [
                                            _buildDetailItem('Tarih', pickupDate != null ? dateFormat.format(pickupDate) : '-'),
                                            _buildDetailItem('Saat', pickupDate != null ? timeFormat.format(pickupDate) : '-'),
                                            if (booking['actual_pickup_date'] != null)
                                              _buildDetailItem('Gerçek Alış', DateFormat('dd MMM HH:mm', 'tr_TR').format(DateTime.parse(booking['actual_pickup_date']))),
                                            if (booking['is_pickup_custom_address'] == true) ...[
                                              _buildDetailItem('Adres', booking['pickup_custom_address'] ?? '-'),
                                              if (booking['pickup_custom_address_notes'] != null &&
                                                  booking['pickup_custom_address_notes'].toString().isNotEmpty)
                                                _buildDetailItem('Not', booking['pickup_custom_address_notes']),
                                            ] else ...[
                                              _buildDetailItem('Lokasyon', pickupLocation?['name'] ?? '-'),
                                              _buildDetailItem('Şehir', pickupLocation?['city'] ?? '-'),
                                              if (pickupLocation?['address'] != null)
                                                _buildDetailItem('Adres', pickupLocation!['address']),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildDeliveryDetailCard(
                                          title: booking['is_dropoff_custom_address'] == true
                                              ? 'Araç İade (Adrese Teslim)'
                                              : 'Araç İade',
                                          icon: booking['is_dropoff_custom_address'] == true
                                              ? Icons.home
                                              : Icons.logout,
                                          color: AppColors.error,
                                          items: [
                                            _buildDetailItem('Tarih', dropoffDate != null ? dateFormat.format(dropoffDate) : '-'),
                                            _buildDetailItem('Saat', dropoffDate != null ? timeFormat.format(dropoffDate) : '-'),
                                            if (booking['actual_dropoff_date'] != null)
                                              _buildDetailItem('Gerçek İade', DateFormat('dd MMM HH:mm', 'tr_TR').format(DateTime.parse(booking['actual_dropoff_date']))),
                                            if (booking['is_dropoff_custom_address'] == true) ...[
                                              _buildDetailItem('Adres', booking['dropoff_custom_address'] ?? '-'),
                                              if (booking['dropoff_custom_address_notes'] != null &&
                                                  booking['dropoff_custom_address_notes'].toString().isNotEmpty)
                                                _buildDetailItem('Not', booking['dropoff_custom_address_notes']),
                                            ] else ...[
                                              _buildDetailItem('Lokasyon', dropoffLocation?['name'] ?? '-'),
                                              _buildDetailItem('Şehir', dropoffLocation?['city'] ?? '-'),
                                              if (dropoffLocation?['address'] != null)
                                                _buildDetailItem('Adres', dropoffLocation!['address']),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Package & Services card
                          if (booking['package_name'] != null || (booking['selected_services'] is List && (booking['selected_services'] as List).isNotEmpty))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Paket & Ek Hizmetler',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (booking['package_name'] != null)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: _getPackageColor(booking['package_tier']).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getPackageColor(booking['package_tier']).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getPackageIcon(booking['package_tier']),
                                              color: _getPackageColor(booking['package_tier']),
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${booking['package_name']} Paket',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    (booking['package_tier'] ?? '').toString().toUpperCase(),
                                                    style: TextStyle(
                                                      color: _getPackageColor(booking['package_tier']),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if ((booking['package_daily_price'] ?? 0) > 0)
                                              Text(
                                                '${formatter.format(booking['package_daily_price'])}/gün',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _getPackageColor(booking['package_tier']),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    if (booking['selected_services'] is List && (booking['selected_services'] as List).isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Seçilen Ek Hizmetler',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...(booking['selected_services'] as List).map((service) {
                                        final s = service as Map<String, dynamic>;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  s['name'] ?? '',
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                              ),
                                              Text(
                                                formatter.format(s['total_price'] ?? 0),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Ek Hizmetler Toplamı',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            formatter.format(booking['services_total'] ?? 0),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          if (booking['package_name'] != null || (booking['selected_services'] is List && (booking['selected_services'] as List).isNotEmpty))
                            const SizedBox(height: 16),

                          // Customer notes
                          if (booking['customer_notes'] != null && booking['customer_notes'].toString().isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Müşteri Notları',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        booking['customer_notes'].toString(),
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Company notes
                          if (booking['company_notes'] != null && booking['company_notes'].toString().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.note_alt, size: 20, color: AppColors.warning),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Şirket Notları',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                                      ),
                                      child: Text(
                                        booking['company_notes'].toString(),
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right column
                    Expanded(
                      child: Column(
                        children: [
                          // Customer info
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Müşteri Bilgileri',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow(Icons.person, 'Ad Soyad', booking['customer_name'] ?? '-'),
                                  const Divider(height: 24),
                                  _buildCopyableInfoRow(
                                    context,
                                    Icons.phone,
                                    'Telefon',
                                    booking['customer_phone'] ?? '-',
                                  ),
                                  const Divider(height: 24),
                                  _buildCopyableInfoRow(
                                    context,
                                    Icons.email,
                                    'E-posta',
                                    booking['customer_email'] ?? '-',
                                  ),
                                  if (booking['driver_license_no'] != null) ...[
                                    const Divider(height: 24),
                                    _buildInfoRow(Icons.badge, 'Ehliyet No', booking['driver_license_no']),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Payment info
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Ödeme Detayları',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      _buildPaymentStatusBadge(booking['payment_status'] ?? ''),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (booking['payment_method'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getPaymentMethodIcon(booking['payment_method']),
                                            size: 18,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _getPaymentMethodLabel(booking['payment_method']),
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  _buildPriceRow(
                                    'Günlük Ücret',
                                    '${formatter.format(booking['daily_rate'] ?? 0)} x ${booking['rental_days']} gün',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildPriceRow(
                                    'Kiralama Tutarı',
                                    formatter.format((booking['daily_rate'] ?? 0) * (booking['rental_days'] ?? 0)),
                                  ),
                                  if ((booking['services_total'] ?? 0) > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildPriceRow(
                                      'Ek Hizmetler',
                                      formatter.format(booking['services_total']),
                                    ),
                                  ],
                                  if ((booking['insurance_total'] ?? 0) > 0) ...[
                                    const SizedBox(height: 8),
                                    _buildPriceRow(
                                      'Sigorta',
                                      formatter.format(booking['insurance_total']),
                                    ),
                                  ],
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Toplam',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        formatter.format(booking['total_amount'] ?? 0),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((booking['deposit_amount'] ?? 0) > 0) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Depozito: ${formatter.format(booking['deposit_amount'])}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  // Status Timeline Widget
  Widget _buildStatusTimeline(String currentStatus, Map<String, dynamic> booking) {
    final steps = [
      {'key': 'pending', 'label': 'Oluşturuldu', 'icon': Icons.fiber_new},
      {'key': 'confirmed', 'label': 'Onaylandı', 'icon': Icons.check_circle},
      {'key': 'active', 'label': 'Teslim Edildi', 'icon': Icons.car_rental},
      {'key': 'completed', 'label': 'Tamamlandı', 'icon': Icons.done_all},
    ];

    final statusOrder = ['pending', 'confirmed', 'active', 'completed'];
    final currentIndex = statusOrder.indexOf(currentStatus);
    final isCancelled = currentStatus == 'cancelled';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: isCancelled
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel, color: AppColors.error, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Bu rezervasyon iptal edildi',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : Row(
                children: List.generate(steps.length * 2 - 1, (index) {
                  if (index.isOdd) {
                    // Connector line
                    final stepIndex = index ~/ 2;
                    final isCompleted = stepIndex < currentIndex;
                    return Expanded(
                      child: Container(
                        height: 3,
                        color: isCompleted
                            ? AppColors.success
                            : AppColors.surfaceLight,
                      ),
                    );
                  }

                  final stepIndex = index ~/ 2;
                  final step = steps[stepIndex];
                  final isCompleted = stepIndex < currentIndex;
                  final isCurrent = stepIndex == currentIndex;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success
                              : isCurrent
                                  ? AppColors.primary
                                  : AppColors.surfaceLight,
                          shape: BoxShape.circle,
                          border: isCurrent
                              ? Border.all(color: AppColors.primary, width: 3)
                              : null,
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check
                              : step['icon'] as IconData,
                          color: isCompleted || isCurrent
                              ? Colors.white
                              : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? AppColors.primary
                              : isCompleted
                                  ? AppColors.success
                                  : AppColors.textMuted,
                        ),
                      ),
                    ],
                  );
                }),
              ),
      ),
    );
  }

  // Duration bar with overdue warning
  Widget _buildDurationBar(Map<String, dynamic> booking, DateTime? pickupDate, DateTime? dropoffDate) {
    final now = DateTime.now();
    final status = booking['status'] as String? ?? '';
    final isActive = status == 'active';
    final isOverdue = isActive && dropoffDate != null && now.isAfter(dropoffDate);
    final overdueDays = isOverdue ? now.difference(dropoffDate!).inDays : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: isOverdue
            ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.access_time,
            size: 18,
            color: isOverdue ? AppColors.error : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            '${booking['rental_days'] ?? 0} Gün Kiralama',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isOverdue ? AppColors.error : null,
            ),
          ),
          if (isOverdue) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$overdueDays GÜN GECİKME!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Map<String, dynamic> booking) {
    final status = booking['status'] as String?;

    List<Widget> buttons = [];

    if (status == 'pending') {
      buttons.addAll([
        OutlinedButton.icon(
          onPressed: () => _updateStatus(context, ref, 'cancelled'),
          icon: const Icon(Icons.close, color: AppColors.error),
          label: const Text('Reddet', style: TextStyle(color: AppColors.error)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _updateStatus(context, ref, 'confirmed'),
          icon: const Icon(Icons.check),
          label: const Text('Onayla'),
        ),
      ]);
    } else if (status == 'confirmed') {
      buttons.addAll([
        OutlinedButton.icon(
          onPressed: () => _updateStatus(context, ref, 'cancelled'),
          icon: const Icon(Icons.close, size: 18, color: AppColors.error),
          label: const Text('İptal', style: TextStyle(color: AppColors.error, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _updateStatus(context, ref, 'active'),
          icon: const Icon(Icons.car_rental),
          label: const Text('Teslim Et'),
        ),
      ]);
    } else if (status == 'active') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _updateStatus(context, ref, 'completed'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          icon: const Icon(Icons.done_all),
          label: const Text('Teslim Al'),
        ),
      );
    }

    return Row(children: buttons);
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String newStatus) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final booking = await ref.read(bookingDetailProvider(bookingId).future);

      final updateData = <String, dynamic>{'status': newStatus};
      if (newStatus == 'active') {
        updateData['actual_pickup_date'] = DateTime.now().toIso8601String();
      } else if (newStatus == 'completed') {
        updateData['actual_dropoff_date'] = DateTime.now().toIso8601String();
      }

      await client
          .from('rental_bookings')
          .update(updateData)
          .eq('id', bookingId);

      // Update car status
      if (booking != null) {
        if (newStatus == 'active') {
          await client
              .from('rental_cars')
              .update({'status': 'rented'})
              .eq('id', booking['car_id']);
        } else if (newStatus == 'completed' || newStatus == 'cancelled') {
          await client
              .from('rental_cars')
              .update({'status': 'available'})
              .eq('id', booking['car_id']);
        }
      }

      ref.invalidate(bookingDetailProvider(bookingId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Durum güncellendi: ${_getStatusLabel(newStatus)}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Beklemede';
      case 'confirmed': return 'Onaylandı';
      case 'active': return 'Aktif';
      case 'completed': return 'Tamamlandı';
      case 'cancelled': return 'İptal Edildi';
      default: return status;
    }
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
        color = AppColors.success;
        label = 'Aktif';
        break;
      case 'completed':
        color = AppColors.secondary;
        label = 'Tamamlandı';
        break;
      case 'cancelled':
        color = AppColors.error;
        label = 'İptal Edildi';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = AppColors.warning;
        label = 'Bekliyor';
        break;
      case 'paid':
        color = AppColors.success;
        label = 'Ödendi';
        break;
      case 'partial':
        color = AppColors.info;
        label = 'Kısmi Ödeme';
        break;
      case 'refunded':
        color = AppColors.info;
        label = 'İade Edildi';
        break;
      default:
        color = AppColors.textMuted;
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

  Widget _buildCarSpec(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildLocationCard(String title, String name, String city, String date, String time, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              city,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  date,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                time,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  // Copyable info row (for phone/email)
  Widget _buildCopyableInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (value != '-')
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label kopyalandı'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16, color: AppColors.textMuted),
            tooltip: 'Kopyala',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getPackageColor(String? tier) {
    switch (tier) {
      case 'basic': return AppColors.info;
      case 'comfort': return AppColors.warning;
      case 'premium': return AppColors.primary;
      default: return AppColors.textSecondary;
    }
  }

  IconData _getPackageIcon(String? tier) {
    switch (tier) {
      case 'basic': return Icons.directions_car;
      case 'comfort': return Icons.star;
      case 'premium': return Icons.workspace_premium;
      default: return Icons.inventory_2;
    }
  }

  String _getFuelLabel(String? fuel) {
    switch (fuel) {
      case 'gasoline': return 'Benzin';
      case 'diesel': return 'Dizel';
      case 'hybrid': return 'Hibrit';
      case 'electric': return 'Elektrik';
      case 'lpg': return 'LPG';
      default: return fuel ?? '-';
    }
  }

  IconData _getPaymentMethodIcon(String? method) {
    switch (method) {
      case 'cash': return Icons.payments;
      case 'credit_card': return Icons.credit_card;
      case 'bank_transfer': return Icons.account_balance;
      default: return Icons.payment;
    }
  }

  String _getPaymentMethodLabel(String? method) {
    switch (method) {
      case 'cash': return 'Nakit';
      case 'credit_card': return 'Kredi Kartı';
      case 'bank_transfer': return 'Havale/EFT';
      default: return method ?? '-';
    }
  }

  Widget _buildDeliveryDetailCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
