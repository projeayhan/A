import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Car detail provider
final carDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, carId) async {
  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from('rental_cars')
      .select('*, rental_locations(id, name, city, address)')
      .eq('id', carId)
      .maybeSingle();

  return response;
});

// Car bookings provider
final carBookingsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, carId) async {
  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from('rental_bookings')
      .select('*')
      .eq('car_id', carId)
      .order('pickup_date', ascending: false)
      .limit(10);

  return List<Map<String, dynamic>>.from(response);
});

class CarDetailScreen extends ConsumerWidget {
  final String carId;

  const CarDetailScreen({super.key, required this.carId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carAsync = ref.watch(carDetailProvider(carId));
    final bookingsAsync = ref.watch(carBookingsProvider(carId));
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: carAsync.when(
        data: (car) {
          if (car == null) {
            return const Center(child: Text('Araç bulunamadı'));
          }

          final location = car['rental_locations'] as Map<String, dynamic>?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button & Title
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/cars'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${car['brand']} ${car['model']}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusBadge(car['status'] ?? ''),
                    const SizedBox(width: 16),
                    PopupMenuButton<String>(
                      onSelected: (status) => _updateStatus(ref, status),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'available', child: Text('Müsait')),
                        const PopupMenuItem(value: 'maintenance', child: Text('Bakımda')),
                        const PopupMenuItem(value: 'inactive', child: Text('Pasif')),
                      ],
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.edit),
                        label: const Text('Durumu Değiştir'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Image & Details
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Image
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: car['image_url'] != null
                                  ? Image.network(
                                      car['image_url'],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppColors.surfaceLight,
                                        child: const Icon(
                                          Icons.directions_car,
                                          size: 80,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.surfaceLight,
                                      child: const Icon(
                                        Icons.directions_car,
                                        size: 80,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Specs
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Araç Özellikleri',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  GridView.count(
                                    crossAxisCount: 3,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    childAspectRatio: 2.5,
                                    children: [
                                      _buildSpecItem(Icons.calendar_today, 'Yıl', '${car['year']}'),
                                      _buildSpecItem(Icons.category, 'Kategori', _getCategoryLabel(car['category'])),
                                      _buildSpecItem(Icons.settings, 'Vites', _getTransmissionLabel(car['transmission'])),
                                      _buildSpecItem(Icons.local_gas_station, 'Yakıt', _getFuelLabel(car['fuel_type'])),
                                      _buildSpecItem(Icons.airline_seat_recline_normal, 'Koltuk', '${car['seats']}'),
                                      _buildSpecItem(Icons.door_front_door, 'Kapı', '${car['doors']}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right column - Info & Bookings
                    Expanded(
                      child: Column(
                        children: [
                          // Price & Location
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
                                        'Günlük Fiyat',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        formatter.format(car['daily_price'] ?? 0),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),
                                  _buildInfoRow('Plaka', car['plate_number'] ?? '-'),
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Lokasyon', location?['name'] ?? '-'),
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Şehir', location?['city'] ?? '-'),
                                  if (car['deposit_amount'] != null && car['deposit_amount'] > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildInfoRow('Depozito', formatter.format(car['deposit_amount'])),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Recent bookings
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Son Rezervasyonlar',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  bookingsAsync.when(
                                    data: (bookings) {
                                      if (bookings.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: Text(
                                              'Henüz rezervasyon yok',
                                              style: TextStyle(color: AppColors.textMuted),
                                            ),
                                          ),
                                        );
                                      }

                                      return ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: bookings.length,
                                        separatorBuilder: (_, __) => const Divider(),
                                        itemBuilder: (context, index) {
                                          final booking = bookings[index];
                                          final pickupDate = DateTime.tryParse(booking['pickup_date'] ?? '');

                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              booking['customer_name'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            subtitle: pickupDate != null
                                                ? Text(
                                                    DateFormat('dd MMM yyyy').format(pickupDate),
                                                    style: const TextStyle(
                                                      color: AppColors.textMuted,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                : null,
                                            trailing: _buildBookingStatusBadge(booking['status'] ?? ''),
                                            onTap: () => context.go('/bookings/${booking['id']}'),
                                          );
                                        },
                                      );
                                    },
                                    loading: () => const Center(child: CircularProgressIndicator()),
                                    error: (e, _) => Text('Hata: $e'),
                                  ),
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

  Future<void> _updateStatus(WidgetRef ref, String status) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('rental_cars')
          .update({'status': status})
          .eq('id', carId);

      ref.invalidate(carDetailProvider(carId));
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'available':
        color = AppColors.success;
        label = 'Müsait';
        break;
      case 'rented':
        color = AppColors.info;
        label = 'Kirada';
        break;
      case 'maintenance':
        color = AppColors.warning;
        label = 'Bakımda';
        break;
      case 'inactive':
        color = AppColors.error;
        label = 'Pasif';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBookingStatusBadge(String status) {
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
        label = 'İptal';
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _getCategoryLabel(String? category) {
    switch (category) {
      case 'economy': return 'Ekonomi';
      case 'compact': return 'Kompakt';
      case 'midsize': return 'Orta';
      case 'fullsize': return 'Büyük';
      case 'suv': return 'SUV';
      case 'luxury': return 'Lüks';
      case 'van': return 'Van';
      default: return category ?? '-';
    }
  }

  String _getTransmissionLabel(String? transmission) {
    switch (transmission) {
      case 'manual': return 'Manuel';
      case 'automatic': return 'Otomatik';
      default: return transmission ?? '-';
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
}
