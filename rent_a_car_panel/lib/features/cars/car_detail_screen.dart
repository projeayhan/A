import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import 'package:rent_a_car_panel/core/services/log_service.dart';

// Car detail provider
final carDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, carId) async {
      final client = ref.watch(supabaseClientProvider);
      final companyId = await ref.watch(companyIdProvider.future);

      final response = await client
          .from('rental_cars')
          .select('*, rental_locations(id, name, city, address)')
          .eq('id', carId)
          .eq('company_id', companyId ?? '')
          .maybeSingle();

      return response;
    });

// Car bookings provider
final carBookingsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, carId) async {
      final client = ref.watch(supabaseClientProvider);
      final companyId = await ref.watch(companyIdProvider.future);

      final response = await client
          .from('rental_bookings')
          .select('*')
          .eq('car_id', carId)
          .eq('company_id', companyId ?? '')
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
                        const PopupMenuItem(
                          value: 'available',
                          child: Text('Müsait'),
                        ),
                        const PopupMenuItem(
                          value: 'maintenance',
                          child: Text('Bakımda'),
                        ),
                        const PopupMenuItem(
                          value: 'inactive',
                          child: Text('Pasif'),
                        ),
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
                          // Image carousel
                          _buildImageCarousel(car),
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    childAspectRatio: 2.5,
                                    children: [
                                      _buildSpecItem(
                                        Icons.calendar_today,
                                        'Yıl',
                                        '${car['year']}',
                                      ),
                                      _buildSpecItem(
                                        Icons.category,
                                        'Kategori',
                                        _getCategoryLabel(car['category']),
                                      ),
                                      _buildSpecItem(
                                        Icons.settings,
                                        'Vites',
                                        _getTransmissionLabel(
                                          car['transmission'],
                                        ),
                                      ),
                                      _buildSpecItem(
                                        Icons.local_gas_station,
                                        'Yakıt',
                                        _getFuelLabel(car['fuel_type']),
                                      ),
                                      _buildSpecItem(
                                        Icons.airline_seat_recline_normal,
                                        'Koltuk',
                                        '${car['seats']}',
                                      ),
                                      _buildSpecItem(
                                        Icons.door_front_door,
                                        'Kapı',
                                        '${car['doors']}',
                                      ),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Günlük Fiyat',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        formatter.format(
                                          car['daily_price'] ?? 0,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),
                                  _buildInfoRow(
                                    'Plaka',
                                    car['plate_number'] ?? '-',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    'Lokasyon',
                                    location?['name'] ?? '-',
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow(
                                    'Şehir',
                                    location?['city'] ?? '-',
                                  ),
                                  if (car['deposit_amount'] != null &&
                                      car['deposit_amount'] > 0) ...[
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      'Depozito',
                                      formatter.format(car['deposit_amount']),
                                    ),
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
                                              style: TextStyle(
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      return ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: bookings.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(),
                                        itemBuilder: (context, index) {
                                          final booking = bookings[index];
                                          final pickupDate = DateTime.tryParse(
                                            booking['pickup_date'] ?? '',
                                          );

                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              booking['customer_name'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: pickupDate != null
                                                ? Text(
                                                    DateFormat(
                                                      'dd MMM yyyy',
                                                    ).format(pickupDate),
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.textMuted,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                : null,
                                            trailing: _buildBookingStatusBadge(
                                              booking['status'] ?? '',
                                            ),
                                            onTap: () => context.go(
                                              '/bookings/${booking['id']}',
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    loading: () => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
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

  Widget _buildImageCarousel(Map<String, dynamic> car) {
    // Collect all image URLs: images array + fallback to image_url
    final List<String> imageUrls = [];
    if (car['images'] != null && car['images'] is List) {
      for (final img in car['images']) {
        if (img is String && img.isNotEmpty) imageUrls.add(img);
      }
    }
    if (imageUrls.isEmpty && car['image_url'] != null) {
      imageUrls.add(car['image_url'] as String);
    }

    if (imageUrls.isEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: AppColors.surfaceLight,
            child: const Icon(
              Icons.directions_car,
              size: 80,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    if (imageUrls.length == 1) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            imageUrls.first,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: AppColors.surfaceLight,
              child: const Icon(
                Icons.directions_car,
                size: 80,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    // Multiple images - show PageView carousel
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _ImageCarousel(imageUrls: imageUrls),
      ),
    );
  }

  Future<void> _updateStatus(WidgetRef ref, String status) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final companyId = await ref.read(companyIdProvider.future);
      await client
          .from('rental_cars')
          .update({'status': status})
          .eq('id', carId)
          .eq('company_id', companyId ?? '');

      ref.invalidate(carDetailProvider(carId));
    } catch (e, st) {
      LogService.error('Error updating status', error: e, stackTrace: st, source: 'CarDetailScreen:_updateStatus');
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
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _getCategoryLabel(String? category) {
    switch (category) {
      case 'economy':
        return 'Ekonomi';
      case 'compact':
        return 'Kompakt';
      case 'midsize':
        return 'Orta';
      case 'fullsize':
        return 'Büyük';
      case 'suv':
        return 'SUV';
      case 'luxury':
        return 'Lüks';
      case 'van':
        return 'Van';
      default:
        return category ?? '-';
    }
  }

  String _getTransmissionLabel(String? transmission) {
    switch (transmission) {
      case 'manual':
        return 'Manuel';
      case 'automatic':
        return 'Otomatik';
      default:
        return transmission ?? '-';
    }
  }

  String _getFuelLabel(String? fuel) {
    switch (fuel) {
      case 'gasoline':
        return 'Benzin';
      case 'diesel':
        return 'Dizel';
      case 'hybrid':
        return 'Hibrit';
      case 'electric':
        return 'Elektrik';
      case 'lpg':
        return 'LPG';
      default:
        return fuel ?? '-';
    }
  }
}

class _ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;

  const _ImageCarousel({required this.imageUrls});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            return Image.network(
              widget.imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.surfaceLight,
                child: const Icon(
                  Icons.broken_image,
                  size: 48,
                  color: AppColors.textMuted,
                ),
              ),
            );
          },
        ),
        // Left arrow
        if (_currentPage > 0)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                icon: const Icon(Icons.chevron_left, size: 32),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        // Right arrow
        if (_currentPage < widget.imageUrls.length - 1)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                icon: const Icon(Icons.chevron_right, size: 32),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        // Page indicator
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.imageUrls.length, (index) {
              return Container(
                width: index == _currentPage ? 10 : 6,
                height: index == _currentPage ? 10 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentPage
                      ? AppColors.primary
                      : Colors.white54,
                ),
              );
            }),
          ),
        ),
        // Counter
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPage + 1}/${widget.imageUrls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
