import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/rental_management_providers.dart';

class AdminRentalCarsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const AdminRentalCarsScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminRentalCarsScreen> createState() => _AdminRentalCarsScreenState();
}

class _AdminRentalCarsScreenState extends ConsumerState<AdminRentalCarsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterCars(List<Map<String, dynamic>> cars) {
    return cars.where((car) {
      final brand = (car['brand'] as String? ?? '').toLowerCase();
      final model = (car['model'] as String? ?? '').toLowerCase();
      final plate = (car['plate'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          brand.contains(query) ||
          model.contains(query) ||
          plate.contains(query);

      final status = car['status'] as String? ?? '';
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _updateCarStatus(String carId, String newStatus) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('rental_cars').update({'status': newStatus}).eq('id', carId);
      ref.invalidate(rentalCompanyCarsProvider(widget.companyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Araç durumu güncellendi'), backgroundColor: AppColors.success),
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

  void _showCarDetailDialog(Map<String, dynamic> car, Map<String, dynamic>? activeBooking) {
    final imageUrl = car['image_url'] as String?;
    final brand = car['brand'] as String? ?? '';
    final model = car['model'] as String? ?? '';
    final plate = car['plate'] as String? ?? '';
    final year = car['year']?.toString() ?? '';
    final category = car['category'] as String? ?? '';
    final transmission = car['transmission'] as String? ?? '';
    final fuelType = car['fuel_type'] as String? ?? '';
    final dailyPrice = (car['daily_price'] as num?)?.toDouble() ?? 0;
    final seats = car['seats']?.toString() ?? '-';
    final doors = car['doors']?.toString() ?? '-';
    final status = car['status'] as String? ?? '';
    final location = car['rental_locations'] as Map<String, dynamic>?;
    final locationName = location?['name'] as String? ?? '-';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Text('$brand $model', style: const TextStyle(color: AppColors.textPrimary)),
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
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholderImage(height: 250),
                        )
                      : _buildPlaceholderImage(height: 250),
                ),
                const SizedBox(height: 20),

                // Specs grid
                Row(
                  children: [
                    Expanded(child: _buildSpecItem(Icons.calendar_today, 'Yıl', year)),
                    Expanded(child: _buildSpecItem(Icons.category, 'Kategori', _categoryLabel(category))),
                    Expanded(child: _buildSpecItem(Icons.settings, 'Vites', _transmissionLabel(transmission))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSpecItem(Icons.local_gas_station, 'Yakıt', _fuelTypeLabel(fuelType))),
                    Expanded(child: _buildSpecItem(Icons.event_seat, 'Koltuk', seats)),
                    Expanded(child: _buildSpecItem(Icons.door_front_door, 'Kapı', doors)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSpecItem(Icons.confirmation_number, 'Plaka', plate)),
                    Expanded(child: _buildSpecItem(Icons.location_on, 'Lokasyon', locationName)),
                    Expanded(child: _buildSpecItem(Icons.attach_money, 'Günlük', _currencyFormat.format(dailyPrice))),
                  ],
                ),

                // Active booking info
                if (activeBooking != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, size: 18, color: AppColors.info),
                            SizedBox(width: 8),
                            Text('Aktif Kiralama', style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Müşteri: ${activeBooking['customer_name'] ?? '-'}',
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'İade Tarihi: ${activeBooking['dropoff_date'] ?? '-'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showAddEditCarDialog({Map<String, dynamic>? car}) {
    final isEdit = car != null;
    final brandController = TextEditingController(text: car?['brand'] as String? ?? '');
    final modelController = TextEditingController(text: car?['model'] as String? ?? '');
    final plateController = TextEditingController(text: car?['plate'] as String? ?? '');
    final yearController = TextEditingController(text: car?['year']?.toString() ?? '');
    final priceController = TextEditingController(text: (car?['daily_price'] as num?)?.toString() ?? '');
    final seatsController = TextEditingController(text: car?['seats']?.toString() ?? '4');
    final doorsController = TextEditingController(text: car?['doors']?.toString() ?? '4');
    final imageUrlController = TextEditingController(text: car?['image_url'] as String? ?? '');
    String selectedCategory = car?['category'] as String? ?? 'economy';
    String selectedTransmission = car?['transmission'] as String? ?? 'manual';
    String selectedFuelType = car?['fuel_type'] as String? ?? 'gasoline';
    String selectedStatus = car?['status'] as String? ?? 'available';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isEdit ? 'Aracı Düzenle' : 'Yeni Araç Ekle',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDialogField('Marka', brandController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDialogField('Model', modelController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDialogField('Plaka', plateController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDialogField('Yıl', yearController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDialogField('Günlük Fiyat (TL)', priceController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDialogField('Koltuk', seatsController)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDialogField('Kapı', doorsController)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField('Görsel URL', imageUrlController),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          dropdownColor: AppColors.surface,
                          items: const [
                            DropdownMenuItem(value: 'economy', child: Text('Ekonomi')),
                            DropdownMenuItem(value: 'compact', child: Text('Kompakt')),
                            DropdownMenuItem(value: 'midsize', child: Text('Orta')),
                            DropdownMenuItem(value: 'fullsize', child: Text('Büyük')),
                            DropdownMenuItem(value: 'suv', child: Text('SUV')),
                            DropdownMenuItem(value: 'luxury', child: Text('Lüks')),
                            DropdownMenuItem(value: 'van', child: Text('Van')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedTransmission,
                          decoration: InputDecoration(
                            labelText: 'Vites',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          dropdownColor: AppColors.surface,
                          items: const [
                            DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                            DropdownMenuItem(value: 'automatic', child: Text('Otomatik')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedTransmission = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedFuelType,
                          decoration: InputDecoration(
                            labelText: 'Yakıt',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          dropdownColor: AppColors.surface,
                          items: const [
                            DropdownMenuItem(value: 'gasoline', child: Text('Benzin')),
                            DropdownMenuItem(value: 'diesel', child: Text('Dizel')),
                            DropdownMenuItem(value: 'hybrid', child: Text('Hibrit')),
                            DropdownMenuItem(value: 'electric', child: Text('Elektrik')),
                            DropdownMenuItem(value: 'lpg', child: Text('LPG')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedFuelType = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Durum',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          dropdownColor: AppColors.surface,
                          items: const [
                            DropdownMenuItem(value: 'available', child: Text('Müsait')),
                            DropdownMenuItem(value: 'rented', child: Text('Kirada')),
                            DropdownMenuItem(value: 'maintenance', child: Text('Bakımda')),
                            DropdownMenuItem(value: 'inactive', child: Text('Pasif')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedStatus = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'brand': brandController.text.trim(),
                  'model': modelController.text.trim(),
                  'plate': plateController.text.trim(),
                  'year': int.tryParse(yearController.text.trim()) ?? 2024,
                  'daily_price': double.tryParse(priceController.text.trim()) ?? 0,
                  'seats': int.tryParse(seatsController.text.trim()) ?? 4,
                  'doors': int.tryParse(doorsController.text.trim()) ?? 4,
                  'image_url': imageUrlController.text.trim(),
                  'category': selectedCategory,
                  'transmission': selectedTransmission,
                  'fuel_type': selectedFuelType,
                  'status': selectedStatus,
                  'company_id': widget.companyId,
                };

                try {
                  final supabase = ref.read(supabaseProvider);
                  if (isEdit) {
                    await supabase.from('rental_cars').update(data).eq('id', car['id']);
                  } else {
                    await supabase.from('rental_cars').insert(data);
                  }
                  ref.invalidate(rentalCompanyCarsProvider(widget.companyId));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Araç güncellendi' : 'Araç eklendi'),
                        backgroundColor: AppColors.success,
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
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildPlaceholderImage({double height = 120}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.directions_car, size: 48, color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(rentalCompanyCarsProvider(widget.companyId));

    // Fetch active bookings for overlay on rented cars
    final activeBookingsAsync = ref.watch(_activeBookingsProvider(widget.companyId));

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
                      'Araç Filosu',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kiralık araçları yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(rentalCompanyCarsProvider(widget.companyId)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditCarDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Araç Ekle'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Fleet Summary
            carsAsync.when(
              data: (cars) => _buildFleetSummary(cars),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // Filter Tabs
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
                  hintText: 'Marka, model veya plaka ile ara...',
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

            // Car Cards Grid
            Expanded(
              child: carsAsync.when(
                data: (cars) {
                  final filtered = _filterCars(cars);
                  final activeBookings = activeBookingsAsync.valueOrNull ?? <String, Map<String, dynamic>>{};
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text('Araç bulunamadı', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final car = filtered[index];
                      final carId = car['id'] as String? ?? '';
                      final booking = activeBookings[carId];
                      return _buildCarCard(car, booking);
                    },
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

  Widget _buildFleetSummary(List<Map<String, dynamic>> cars) {
    final total = cars.length;
    final available = cars.where((c) => c['status'] == 'available').length;
    final rented = cars.where((c) => c['status'] == 'rented').length;
    final maintenance = cars.where((c) => c['status'] == 'maintenance').length;
    final inactive = cars.where((c) => c['status'] == 'inactive').length;

    return Row(
      children: [
        _buildSummaryChip('Toplam', total, AppColors.textPrimary),
        const SizedBox(width: 12),
        _buildSummaryChip('Müsait', available, AppColors.success),
        const SizedBox(width: 12),
        _buildSummaryChip('Kirada', rented, AppColors.info),
        const SizedBox(width: 12),
        _buildSummaryChip('Bakımda', maintenance, AppColors.warning),
        const SizedBox(width: 12),
        _buildSummaryChip('Pasif', inactive, AppColors.textMuted),
      ],
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    final tabs = [
      {'label': 'Tümü', 'value': 'all'},
      {'label': 'Müsait', 'value': 'available'},
      {'label': 'Kirada', 'value': 'rented'},
      {'label': 'Bakımda', 'value': 'maintenance'},
      {'label': 'Pasif', 'value': 'inactive'},
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

  Widget _buildCarCard(Map<String, dynamic> car, Map<String, dynamic>? activeBooking) {
    final imageUrl = car['image_url'] as String?;
    final brand = car['brand'] as String? ?? '';
    final model = car['model'] as String? ?? '';
    final plate = car['plate'] as String? ?? '';
    final year = car['year']?.toString() ?? '';
    final category = car['category'] as String? ?? '';
    final transmission = car['transmission'] as String? ?? '';
    final fuelType = car['fuel_type'] as String? ?? '';
    final dailyPrice = (car['daily_price'] as num?)?.toDouble() ?? 0;
    final status = car['status'] as String? ?? '';
    final carId = car['id'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showCarDetailDialog(car, activeBooking),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with status badge overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 140,
                            width: double.infinity,
                            color: AppColors.surfaceLight,
                            child: const Icon(Icons.directions_car, size: 48, color: AppColors.textMuted),
                          ),
                        )
                      : Container(
                          height: 140,
                          width: double.infinity,
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.directions_car, size: 48, color: AppColors.textMuted),
                        ),
                ),
                // Status badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildStatusBadge(status),
                ),
                // Quick status dropdown
                Positioned(
                  top: 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 18),
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'available', child: Text('Müsait')),
                      const PopupMenuItem(value: 'rented', child: Text('Kirada')),
                      const PopupMenuItem(value: 'maintenance', child: Text('Bakımda')),
                      const PopupMenuItem(value: 'inactive', child: Text('Pasif')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddEditCarDialog(car: car);
                      } else {
                        _updateCarStatus(carId, value);
                      }
                    },
                  ),
                ),
                // Active booking overlay
                if (status == 'rented' && activeBooking != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${activeBooking['customer_name'] ?? '-'} - ${activeBooking['dropoff_date'] ?? ''}',
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Model Year
                    Text(
                      '$brand $model ($year)',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Plate
                    Text(
                      plate,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    // Tags row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildTag(_categoryLabel(category)),
                        _buildTag(_transmissionLabel(transmission)),
                        _buildTag(_fuelTypeLabel(fuelType)),
                      ],
                    ),
                    const Spacer(),
                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_currencyFormat.format(dailyPrice)}/gün',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    );
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
        color = AppColors.textMuted;
        label = 'Pasif';
        break;
      default:
        color = AppColors.textMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _categoryLabel(String category) {
    final labels = {
      'economy': 'Ekonomi',
      'compact': 'Kompakt',
      'midsize': 'Orta',
      'fullsize': 'Büyük',
      'suv': 'SUV',
      'luxury': 'Lüks',
      'van': 'Van',
    };
    return labels[category] ?? category;
  }

  String _transmissionLabel(String t) {
    switch (t) {
      case 'manual':
        return 'Manuel';
      case 'automatic':
        return 'Otomatik';
      default:
        return t;
    }
  }

  String _fuelTypeLabel(String f) {
    switch (f) {
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
        return f;
    }
  }
}

// Active bookings provider for car overlay
final _activeBookingsProvider = FutureProvider.family<Map<String, Map<String, dynamic>>, String>(
  (ref, companyId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('rental_bookings')
        .select('car_id, customer_name, dropoff_date')
        .eq('company_id', companyId)
        .eq('status', 'active');

    final bookings = List<Map<String, dynamic>>.from(response);
    final Map<String, Map<String, dynamic>> bookingMap = {};
    for (final booking in bookings) {
      final carId = booking['car_id'] as String?;
      if (carId != null) {
        bookingMap[carId] = booking;
      }
    }
    return bookingMap;
  },
);
