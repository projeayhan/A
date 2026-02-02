import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  List<Map<String, dynamic>> _activeBookings = [];
  List<Map<String, dynamic>> _pastBookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await _rentalService.getUserBookings();

      _activeBookings = bookings.where((b) {
        final status = b['status'] as String?;
        return status == 'pending' || status == 'confirmed' || status == 'active';
      }).toList();

      _pastBookings = bookings.where((b) {
        final status = b['status'] as String?;
        return status == 'completed' || status == 'cancelled' || status == 'no_show';
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Rezervasyonlarım',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1976D2),
          indicatorWeight: 3,
          labelColor: const Color(0xFF1976D2),
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'Aktif (${_activeBookings.length})'),
            Tab(text: 'Geçmiş (${_pastBookings.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
          : _error != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingsList(_activeBookings, isActive: true),
                    _buildBookingsList(_pastBookings, isActive: false),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Bir hata oluştu',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings, {required bool isActive}) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.car_rental : Icons.history,
              color: Colors.white24,
              size: 80,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Aktif rezervasyonunuz yok' : 'Geçmiş rezervasyonunuz yok',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: const Color(0xFF1976D2),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(bookings[index], isActive: isActive);
        },
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {required bool isActive}) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
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
                Text(
                  bookingNumber,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Car Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: car?['image_url'] != null
                      ? Image.network(
                          car!['image_url'],
                          width: 100,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildCarPlaceholder(),
                        )
                      : _buildCarPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${car?['brand'] ?? ''} ${car?['model'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        company?['company_name'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₺${totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dates
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.login, color: Color(0xFF4CAF50), size: 20),
                      const SizedBox(height: 4),
                      const Text(
                        'Alış',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pickupDate != null ? dateFormat.format(pickupDate) : '-',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        pickupLocation?['name'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
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
                  color: Colors.white12,
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.logout, color: Color(0xFFF44336), size: 20),
                      const SizedBox(height: 4),
                      const Text(
                        'Teslim',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dropoffDate != null ? dateFormat.format(dropoffDate) : '-',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        dropoffLocation?['name'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
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
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
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
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
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
                    backgroundColor: const Color(0xFFFFC107),
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

  Widget _buildCarPlaceholder() {
    return Container(
      width: 100,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_car, color: Colors.white24, size: 32),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return const Color(0xFF1976D2);
      case 'active':
        return const Color(0xFF4CAF50);
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'no_show':
        return Colors.purple;
      default:
        return Colors.grey;
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
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Rezervasyonu İptal Et',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bu rezervasyonu iptal etmek istediğinizden emin misiniz?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'İptal sebebi (opsiyonel)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        _loadBookings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rezervasyon iptal edilemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
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
    // TODO: Implement phone call using url_launcher
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Değerlendirme',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overall Rating
                      _buildRatingSection(
                        'Genel Değerlendirme',
                        overallRating,
                        (rating) => setDialogState(() => overallRating = rating),
                        isMain: true,
                      ),

                      const SizedBox(height: 24),

                      // Detailed Ratings
                      Text(
                        'Detaylı Değerlendirme',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildRatingSection(
                        'Araç Durumu',
                        carConditionRating,
                        (rating) => setDialogState(() => carConditionRating = rating),
                      ),
                      _buildRatingSection(
                        'Temizlik',
                        cleanlinessRating,
                        (rating) => setDialogState(() => cleanlinessRating = rating),
                      ),
                      _buildRatingSection(
                        'Hizmet Kalitesi',
                        serviceRating,
                        (rating) => setDialogState(() => serviceRating = rating),
                      ),
                      _buildRatingSection(
                        'Fiyat/Performans',
                        valueRating,
                        (rating) => setDialogState(() => valueRating = rating),
                      ),

                      const SizedBox(height: 24),

                      // Comment
                      Text(
                        'Yorumunuz',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Deneyiminizi paylaşın...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Submit Button
              Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _submitDetailedReview(
                        booking,
                        overallRating,
                        carConditionRating,
                        cleanlinessRating,
                        serviceRating,
                        valueRating,
                        commentController.text,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Değerlendirmeyi Gönder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
    String label,
    int rating,
    Function(int) onRatingChanged, {
    bool isMain = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: isMain ? 1 : 0.7),
                fontSize: isMain ? 16 : 14,
                fontWeight: isMain ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => onRatingChanged(index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFFC107),
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
    int overallRating,
    int carConditionRating,
    int cleanlinessRating,
    int serviceRating,
    int valueRating,
    String comment,
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
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değerlendirme kaydedilemedi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
