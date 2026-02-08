import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/rental_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RentalService _rentalService = RentalService();
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

  List<Map<String, dynamic>> _activeBookings = [];
  List<Map<String, dynamic>> _pastBookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
    _subscribeToBookings();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _subscribeToBookings() {
    _realtimeSubscription = _rentalService.subscribeToUserBookings().listen((_) {
      if (!mounted) return;
      // Realtime only returns basic columns, reload full data with joins
      _loadBookings(silent: true);
    });
  }

  Future<void> _loadBookings({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final bookings = await _rentalService.getUserBookings();

      final active = bookings.where((b) {
        final status = b['status'] as String?;
        return status == 'pending' || status == 'confirmed' || status == 'active';
      }).toList();

      final past = bookings.where((b) {
        final status = b['status'] as String?;
        return status == 'completed' || status == 'cancelled' || status == 'no_show';
      }).toList();

      if (mounted) {
        setState(() {
          _activeBookings = active;
          _pastBookings = past;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezervasyonlarım'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Aktif (${_activeBookings.length})'),
            Tab(text: 'Geçmiş (${_pastBookings.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _error != null
              ? _buildErrorView(theme)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingsList(_activeBookings, isActive: true, theme: theme),
                    _buildBookingsList(_pastBookings, isActive: false, theme: theme),
                  ],
                ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 64),
          const SizedBox(height: 16),
          Text('Bir hata oluştu', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings,
      {required bool isActive, required ThemeData theme}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.car_rental : Icons.history,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Aktif rezervasyonunuz yok' : 'Geçmiş rezervasyonunuz yok',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: theme.colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(bookings[index], isActive: isActive, theme: theme);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking,
      {required bool isActive, required ThemeData theme}) {
    final colors = theme.colorScheme;
    final car = booking['rental_cars'] as Map<String, dynamic>?;
    final company = booking['rental_companies'] as Map<String, dynamic>?;
    final pickupLocation = booking['pickup_location'] as Map<String, dynamic>?;
    final dropoffLocation = booking['dropoff_location'] as Map<String, dynamic>?;

    final pickupDate = DateTime.tryParse(booking['pickup_date'] ?? '');
    final dropoffDate = DateTime.tryParse(booking['dropoff_date'] ?? '');
    final status = booking['status'] as String? ?? 'pending';
    final bookingNumber = booking['booking_number'] as String? ?? '';
    final totalAmount = (booking['total_amount'] as num?)?.toDouble() ?? 0;

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'tr_TR');
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(bookingNumber,
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant)),
              ],
            ),
          ),

          // Car Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: car?['image_url'] != null
                      ? Image.network(
                          car!['image_url'],
                          width: 100,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildCarPlaceholder(theme),
                        )
                      : _buildCarPlaceholder(theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car?['brand'] ?? ''} ${car?['model'] ?? ''}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        company?['company_name'] ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₺${totalAmount.toStringAsFixed(0)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dates
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.login, color: AppColors.success, size: 20),
                        const SizedBox(height: 4),
                        Text('Alış', style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          pickupDate != null ? dateFormat.format(pickupDate) : '-',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          pickupLocation?['name'] ?? '',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: colors.outlineVariant,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.logout, color: AppColors.error, size: 20),
                        const SizedBox(height: 4),
                        Text('Teslim', style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          dropoffDate != null ? dateFormat.format(dropoffDate) : '-',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          dropoffLocation?['name'] ?? '',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          if (isActive && (status == 'pending' || status == 'confirmed'))
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(booking),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('İptal Et'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _callCompany(company?['phone']),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Ara'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!isActive && status == 'completed')
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReviewDialog(booking),
                  icon: const Icon(Icons.star, size: 18),
                  label: const Text('Değerlendir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCarPlaceholder(ThemeData theme) {
    return Container(
      width: 100,
      height: 70,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.directions_car,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), size: 32),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.primary;
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.textSecondaryLight;
      case 'cancelled':
        return AppColors.error;
      case 'no_show':
        return Colors.purple;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Onay Bekliyor';
      case 'confirmed':
        return 'Onaylandı';
      case 'active':
        return 'Aktif';
      case 'completed':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal Edildi';
      case 'no_show':
        return 'Gelmedi';
      default:
        return status;
    }
  }

  void _showCancelDialog(Map<String, dynamic> booking) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezervasyonu İptal Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu rezervasyonu iptal etmek istediğinizden emin misiniz?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'İptal sebebi (opsiyonel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking(
                booking['id'],
                reasonController.text.isNotEmpty
                    ? reasonController.text
                    : 'Kullanıcı tarafından iptal edildi',
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(String bookingId, String reason) async {
    try {
      final success = await _rentalService.cancelBooking(bookingId, reason);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervasyon iptal edildi'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervasyon iptal edilemedi'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _callCompany(String? phone) {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon numarası bulunamadı')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aranıyor: $phone')),
    );
  }

  void _showReviewDialog(Map<String, dynamic> booking) {
    int overallRating = 5;
    int carConditionRating = 5;
    int cleanlinessRating = 5;
    int serviceRating = 5;
    int valueRating = 5;
    final commentController = TextEditingController();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Değerlendirme',
                          style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRatingSection(
                        'Genel Değerlendirme', overallRating,
                        (rating) => setDialogState(() => overallRating = rating),
                        isMain: true, theme: theme,
                      ),
                      const SizedBox(height: 24),
                      Text('Detaylı Değerlendirme',
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      _buildRatingSection('Araç Durumu', carConditionRating,
                          (r) => setDialogState(() => carConditionRating = r), theme: theme),
                      _buildRatingSection('Temizlik', cleanlinessRating,
                          (r) => setDialogState(() => cleanlinessRating = r), theme: theme),
                      _buildRatingSection('Hizmet Kalitesi', serviceRating,
                          (r) => setDialogState(() => serviceRating = r), theme: theme),
                      _buildRatingSection('Fiyat/Performans', valueRating,
                          (r) => setDialogState(() => valueRating = r), theme: theme),
                      const SizedBox(height: 24),
                      Text('Yorumunuz',
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: colors.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Deneyiminizi paylaşın...',
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Submit Button
              Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  top: 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _submitDetailedReview(
                        booking, overallRating, carConditionRating,
                        cleanlinessRating, serviceRating, valueRating,
                        commentController.text,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Değerlendirmeyi Gönder',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection(
    String label, int rating, Function(int) onRatingChanged,
    {bool isMain = false, required ThemeData theme}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: isMain
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
          ),
          Row(
            children: List.generate(5, (index) {
              return InkWell(
                onTap: () => onRatingChanged(index + 1),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: AppColors.warning,
                    size: isMain ? 32 : 24,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDetailedReview(
    Map<String, dynamic> booking,
    int overallRating, int carConditionRating, int cleanlinessRating,
    int serviceRating, int valueRating, String comment,
  ) async {
    try {
      final success = await _rentalService.createReview(
        bookingId: booking['id'],
        companyId: booking['company_id'],
        carId: booking['car_id'],
        overallRating: overallRating,
        carConditionRating: carConditionRating,
        cleanlinessRating: cleanlinessRating,
        serviceRating: serviceRating,
        valueRating: valueRating,
        comment: comment.isNotEmpty ? comment : null,
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değerlendirmeniz kaydedildi. Teşekkürler!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değerlendirme kaydedilemedi'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
