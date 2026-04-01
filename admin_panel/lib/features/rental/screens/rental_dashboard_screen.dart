import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../services/rental_service.dart';

class RentalDashboardScreen extends ConsumerStatefulWidget {
  const RentalDashboardScreen({super.key});

  @override
  ConsumerState<RentalDashboardScreen> createState() =>
      _RentalDashboardScreenState();
}

class _RentalDashboardScreenState extends ConsumerState<RentalDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(rentalStatsProvider);

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
                      'Araç Kiralama Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Araç filosunu, rezervasyonları ve lokasyonları yönetin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(rentalStatsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.go(AppRoutes.rentalVehicles),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Araç Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            statsAsync.when(
              data: (stats) => _buildStatsRow(stats),
              loading: () => _buildStatsRowLoading(),
              error: (e, _) => _buildStatsRow(RentalStats.empty()),
            ),

            const SizedBox(height: 24),

            // Main Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column - Recent Bookings
                  Expanded(flex: 2, child: _buildRecentBookingsCard()),
                  const SizedBox(width: 24),
                  // Right Column - Quick Stats
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildAvailabilityCard(),
                        const SizedBox(height: 16),
                        _buildTopCarsCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(RentalStats stats) {
    return Row(
      children: [
        _buildStatCard(
          'Toplam Araç',
          stats.totalCars.toString(),
          Icons.directions_car,
          AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Müsait Araç',
          stats.availableCars.toString(),
          Icons.check_circle,
          AppColors.success,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Kirada',
          stats.rentedCars.toString(),
          Icons.key,
          AppColors.warning,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Bekleyen Rezervasyon',
          stats.pendingBookings.toString(),
          Icons.pending_actions,
          AppColors.info,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Bugünkü Gelir',
          '₺${stats.todayRevenue.toStringAsFixed(0)}',
          Icons.payments,
          AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatsRowLoading() {
    return Row(
      children: List.generate(
        5,
        (_) => Expanded(child: _buildStatCardLoading()),
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardLoading() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildRecentBookingsCard() {
    final bookingsAsync = ref.watch(recentBookingsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son Rezervasyonlar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(onPressed: () => context.go(AppRoutes.rentalBookings), child: const Text('Tümünü Gör')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: bookingsAsync.when(
              data: (bookings) => bookings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Henüz rezervasyon yok',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: bookings.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        color: AppColors.surfaceLight,
                      ),
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return _buildBookingItem(booking);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Hata: $e',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingItem(RentalBookingView booking) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Car Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                booking.carImage,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.directions_car,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Booking Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.carName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.customerName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Dates
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatDate(booking.pickupDate)} - ${_formatDate(booking.dropoffDate)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₺${booking.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Status Badge
          _buildStatusBadge(booking.status),
          const SizedBox(width: 8),
          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (value) => _handleBookingAction(value, booking),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Text('Detay Görüntüle'),
              ),
              const PopupMenuItem(value: 'confirm', child: Text('Onayla')),
              const PopupMenuItem(value: 'cancel', child: Text('İptal Et')),
            ],
          ),
        ],
      ),
    );
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
      case 'active':
        color = AppColors.success;
        text = 'Aktif';
        break;
      case 'completed':
        color = AppColors.textMuted;
        text = 'Tamamlandı';
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

  Widget _buildAvailabilityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori Bazlı Durum',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Kategori verileri filo bilgilerinden yüklenecektir.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCarsCard() {
    final topCarsAsync = ref.watch(topRentalCarsProvider);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'En Çok Kiralanan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: topCarsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Hata: $e',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                data: (topCars) => topCars.isEmpty
                    ? const Center(
                        child: Text(
                          'Veri yok',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: topCars.length,
                        itemBuilder: (context, index) {
                          final car = topCars[index];
                          return _buildTopCarRow(
                            car.carName,
                            car.rentalCount,
                            car.avgRating,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCarRow(String name, int rentCount, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.directions_car,
            size: 18,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                    const SizedBox(width: 2),
                    Text(
                      '$rating',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$rentCount kiralama',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }

  void _handleBookingAction(String action, RentalBookingView booking) {
    switch (action) {
      case 'view':
        _showBookingDetailDialog(booking);
        break;
      case 'confirm':
        _updateBookingStatus(booking, 'confirmed');
        break;
      case 'cancel':
        _updateBookingStatus(booking, 'cancelled');
        break;
    }
  }

  void _showBookingDetailDialog(RentalBookingView booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rezervasyon #${booking.bookingNumber}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Araç', booking.carName),
              _buildDetailRow('Müşteri', booking.customerName),
              _buildDetailRow('Telefon', booking.customerPhone),
              _buildDetailRow('E-posta', booking.customerEmail),
              _buildDetailRow('Şirket', booking.companyName),
              _buildDetailRow('Alış Yeri', booking.pickupLocationName),
              _buildDetailRow('İade Yeri', booking.dropoffLocationName),
              _buildDetailRow('Alış Tarihi', _formatDate(booking.pickupDate)),
              _buildDetailRow('İade Tarihi', _formatDate(booking.dropoffDate)),
              _buildDetailRow('Gün Sayısı', '${booking.rentalDays} gün'),
              _buildDetailRow(
                'Günlük Ücret',
                '₺${booking.dailyRate.toStringAsFixed(0)}',
              ),
              _buildDetailRow(
                'Toplam',
                '₺${booking.totalPrice.toStringAsFixed(0)}',
              ),
              _buildDetailRow('Durum', booking.status),
              _buildDetailRow('Ödeme', booking.paymentStatus),
              if (booking.notes != null && booking.notes!.isNotEmpty)
                _buildDetailRow('Notlar', booking.notes!),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBookingStatus(
    RentalBookingView booking,
    String newStatus,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          newStatus == 'confirmed'
              ? 'Rezervasyonu Onayla'
              : 'Rezervasyonu İptal Et',
        ),
        content: Text(
          newStatus == 'confirmed'
              ? '#${booking.bookingNumber} rezervasyonunu onaylamak istiyor musunuz?'
              : '#${booking.bookingNumber} rezervasyonunu iptal etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'confirmed'
                  ? AppColors.success
                  : AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus == 'confirmed' ? 'Onayla' : 'İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('rental_bookings')
          .update({'status': newStatus})
          .eq('id', booking.id);
      ref.invalidate(recentBookingsProvider);
      ref.invalidate(rentalStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'confirmed'
                  ? 'Rezervasyon onaylandı'
                  : 'Rezervasyon iptal edildi',
            ),
            backgroundColor: newStatus == 'confirmed'
                ? AppColors.success
                : AppColors.error,
          ),
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
}
