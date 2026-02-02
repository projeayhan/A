import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../services/rental_service.dart';

class RentalBookingsScreen extends ConsumerStatefulWidget {
  const RentalBookingsScreen({super.key});

  @override
  ConsumerState<RentalBookingsScreen> createState() => _RentalBookingsScreenState();
}

class _RentalBookingsScreenState extends ConsumerState<RentalBookingsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(recentBookingsProvider);

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
                      'Rezervasyon Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tüm rezervasyonları görüntüleyin ve yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(recentBookingsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Rapor İndir'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            bookingsAsync.when(
              data: (bookings) => _buildStatsRow(bookings),
              loading: () => _buildStatsRowLoading(),
              error: (_, _) => const SizedBox(),
            ),

            const SizedBox(height: 24),

            // Filters
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
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Rezervasyon ara (müşteri, araç)...',
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
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tüm Durumlar')),
                          DropdownMenuItem(value: 'pending', child: Text('Bekleyen')),
                          DropdownMenuItem(value: 'confirmed', child: Text('Onaylı')),
                          DropdownMenuItem(value: 'active', child: Text('Aktif')),
                          DropdownMenuItem(value: 'completed', child: Text('Tamamlandı')),
                          DropdownMenuItem(value: 'cancelled', child: Text('İptal')),
                        ],
                        onChanged: (value) => setState(() => _statusFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => _selectDateRange(),
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(_dateRange != null
                        ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                        : 'Tarih Seç'),
                  ),
                  if (_dateRange != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _dateRange = null),
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Tarihi Temizle',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: bookingsAsync.when(
                  data: (bookings) => _buildDataTable(bookings),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('Rezervasyon yüklenemedi', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Hata: $e', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<RentalBookingView> bookings) {
    final pending = bookings.where((b) => b.status == 'pending').length;
    final confirmed = bookings.where((b) => b.status == 'confirmed').length;
    final active = bookings.where((b) => b.status == 'active').length;
    final completed = bookings.where((b) => b.status == 'completed').length;
    final totalRevenue = bookings.fold<double>(0, (sum, b) => sum + b.totalPrice);

    return Row(
      children: [
        _buildStatCard('Toplam Rezervasyon', bookings.length.toString(), Icons.event_note, AppColors.primary),
        const SizedBox(width: 16),
        _buildStatCard('Bekleyen', pending.toString(), Icons.pending, AppColors.warning),
        const SizedBox(width: 16),
        _buildStatCard('Onaylı', confirmed.toString(), Icons.check_circle_outline, AppColors.info),
        const SizedBox(width: 16),
        _buildStatCard('Aktif', active.toString(), Icons.directions_car, AppColors.success),
        const SizedBox(width: 16),
        _buildStatCard('Toplam Gelir', '₺${totalRevenue.toStringAsFixed(0)}', Icons.payments, AppColors.success),
      ],
    );
  }

  Widget _buildStatsRowLoading() {
    return Row(
      children: List.generate(5, (_) => Expanded(child: _buildStatCardLoading())),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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

  Widget _buildDataTable(List<RentalBookingView> bookings) {
    var filteredBookings = bookings.where((booking) {
      final searchLower = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          booking.customerName.toLowerCase().contains(searchLower) ||
          booking.carName.toLowerCase().contains(searchLower) ||
          booking.id.toLowerCase().contains(searchLower);
      final matchesStatus = _statusFilter == 'all' || booking.status == _statusFilter;
      final matchesDate = _dateRange == null ||
          (booking.pickupDate.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
              booking.dropoffDate.isBefore(_dateRange!.end.add(const Duration(days: 1))));
      return matchesSearch && matchesStatus && matchesDate;
    }).toList();

    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Rezervasyon bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            if (_searchQuery.isNotEmpty || _statusFilter != 'all' || _dateRange != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _statusFilter = 'all';
                    _dateRange = null;
                  });
                },
                child: const Text('Filtreleri Temizle'),
              ),
          ],
        ),
      );
    }

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 1400,
      headingRowColor: WidgetStateProperty.all(AppColors.background),
      headingTextStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12),
      dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      columns: const [
        DataColumn2(label: Text('REZERVASYON NO'), size: ColumnSize.S),
        DataColumn2(label: Text('MÜŞTERİ'), size: ColumnSize.L),
        DataColumn2(label: Text('ARAÇ'), size: ColumnSize.L),
        DataColumn2(label: Text('TARİHLER'), size: ColumnSize.M),
        DataColumn2(label: Text('LOKASYONLAR'), size: ColumnSize.L),
        DataColumn2(label: Text('TUTAR'), size: ColumnSize.S),
        DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: filteredBookings.map((booking) {
        return DataRow2(
          cells: [
            DataCell(
              Text(
                '#${booking.id.substring(booking.id.length - 6).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontFamily: 'monospace'),
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(booking.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(booking.customerPhone, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            DataCell(
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        booking.carImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.directions_car, size: 20, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(booking.carName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_formatDate(booking.pickupDate)} - ${_formatDate(booking.dropoffDate)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text('${booking.rentalDays} gün', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.success),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking.pickupLocationName,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.flag, size: 12, color: AppColors.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking.dropoffLocationName,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₺${booking.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Depozito: ₺${booking.depositAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            DataCell(_buildStatusBadge(booking.status)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showBookingDetailDialog(booking),
                    icon: const Icon(Icons.visibility, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Detay',
                  ),
                  if (booking.status == 'pending')
                    IconButton(
                      onPressed: () => _confirmBooking(booking),
                      icon: const Icon(Icons.check_circle, size: 18),
                      color: AppColors.success,
                      tooltip: 'Onayla',
                    ),
                  if (booking.status == 'pending' || booking.status == 'confirmed')
                    IconButton(
                      onPressed: () => _cancelBooking(booking),
                      icon: const Icon(Icons.cancel, size: 18),
                      color: AppColors.error,
                      tooltip: 'İptal Et',
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
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
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _showBookingDetailDialog(RentalBookingView booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text('Rezervasyon #${booking.id.substring(booking.id.length - 6).toUpperCase()}'),
            const SizedBox(width: 12),
            _buildStatusBadge(booking.status),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Araç Bilgisi
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
                        child: Image.network(
                          booking.carImage,
                          width: 100,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.carName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text('Paket: ${booking.packageName}', style: const TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Müşteri Bilgileri
                const Text('Müşteri Bilgileri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _buildDetailRow('Ad Soyad', booking.customerName),
                _buildDetailRow('Telefon', booking.customerPhone),
                _buildDetailRow('E-posta', booking.customerEmail),
                if (booking.driverLicenseNumber != null)
                  _buildDetailRow('Ehliyet No', booking.driverLicenseNumber!),

                const SizedBox(height: 20),

                // Rezervasyon Detayları
                const Text('Rezervasyon Detayları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _buildDetailRow('Alış Tarihi', _formatDate(booking.pickupDate)),
                _buildDetailRow('Teslim Tarihi', _formatDate(booking.dropoffDate)),
                _buildDetailRow('Kiralama Süresi', '${booking.rentalDays} gün'),
                _buildDetailRow('Alış Lokasyonu', booking.pickupLocationName),
                _buildDetailRow('Teslim Lokasyonu', booking.dropoffLocationName),

                if (booking.additionalServices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Ek Hizmetler', booking.additionalServices.join(', ')),
                ],

                const SizedBox(height: 20),

                // Ücret Bilgileri
                const Text('Ücret Bilgileri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _buildDetailRow('Toplam Tutar', '₺${booking.totalPrice.toStringAsFixed(2)}'),
                _buildDetailRow('Depozito', '₺${booking.depositAmount.toStringAsFixed(2)}'),

                if (booking.notes != null) ...[
                  const SizedBox(height: 20),
                  const Text('Notlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(booking.notes!, style: const TextStyle(color: AppColors.textMuted)),
                ],

                if (booking.cancellationReason != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'İptal Nedeni: ${booking.cancellationReason}',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          if (booking.status == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmBooking(booking);
              },
              child: const Text('Onayla'),
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
            width: 140,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _confirmBooking(RentalBookingView booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezervasyonu Onayla'),
        content: Text('${booking.customerName} adına yapılan ${booking.carName} rezervasyonunu onaylamak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rezervasyon onaylandı'),
                  backgroundColor: AppColors.success,
                ),
              );
              ref.invalidate(recentBookingsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }

  void _cancelBooking(RentalBookingView booking) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezervasyonu İptal Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${booking.customerName} adına yapılan ${booking.carName} rezervasyonunu iptal etmek istediğinize emin misiniz?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'İptal Nedeni',
                hintText: 'İptal nedenini girin...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rezervasyon iptal edildi'),
                  backgroundColor: AppColors.error,
                ),
              );
              ref.invalidate(recentBookingsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }
}
