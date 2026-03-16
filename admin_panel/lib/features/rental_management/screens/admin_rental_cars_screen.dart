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
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterCars(List<Map<String, dynamic>> cars) {
    return cars.where((car) {
      final brand = (car['brand'] as String? ?? '').toLowerCase();
      final model = (car['model'] as String? ?? '').toLowerCase();
      final plate = (car['plate_number'] as String? ?? '').toLowerCase();
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

  Future<void> _toggleCarActive(String carId, bool isActive) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('rental_cars').update({'is_active': isActive}).eq('id', carId);
      ref.invalidate(rentalCompanyCarsProvider(widget.companyId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(rentalCompanyCarsProvider(widget.companyId));

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
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

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
                    if (mounted) setState(() => _searchQuery = value);
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

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: carsAsync.when(
                  data: (cars) {
                    final filtered = _filterCars(cars);
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('Araç bulunamadı', style: TextStyle(color: AppColors.textMuted)),
                      );
                    }
                    return _buildDataTable(filtered);
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
                ),
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

  Widget _buildDataTable(List<Map<String, dynamic>> cars) {
    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background.withValues(alpha: 0.5)),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        columns: const [
          DataColumn(label: Text('Görsel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Araç', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Plaka', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Yıl', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Kategori', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Vites', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Yakıt', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Günlük Fiyat', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Koltuk', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Durum', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Lokasyon', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('Aktif', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          DataColumn(label: Text('İşlem', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
        ],
        rows: cars.map((car) {
          final imageUrl = car['image_url'] as String?;
          final brand = car['brand'] as String? ?? '';
          final model = car['model'] as String? ?? '';
          final plate = car['plate_number'] as String? ?? '';
          final year = car['year']?.toString() ?? '';
          final category = car['category'] as String? ?? '';
          final transmission = car['transmission'] as String? ?? '';
          final fuelType = car['fuel_type'] as String? ?? '';
          final dailyPrice = (car['daily_price'] as num?)?.toDouble() ?? 0;
          final seats = car['seats']?.toString() ?? '';
          final status = car['status'] as String? ?? '';
          final isActive = car['is_active'] as bool? ?? true;
          final location = car['rental_locations'] as Map<String, dynamic>?;
          final locationName = location?['name'] as String? ?? '-';

          return DataRow(cells: [
            DataCell(
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, width: 48, height: 36, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 48, height: 36,
                          color: AppColors.surfaceLight,
                          child: const Icon(Icons.directions_car, size: 20, color: AppColors.textMuted),
                        ),
                      )
                    : Container(
                        width: 48, height: 36,
                        color: AppColors.surfaceLight,
                        child: const Icon(Icons.directions_car, size: 20, color: AppColors.textMuted),
                      ),
              ),
            ),
            DataCell(Text('$brand $model', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
            DataCell(Text(plate, style: const TextStyle(color: AppColors.textPrimary))),
            DataCell(Text(year, style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(_buildCategoryBadge(category)),
            DataCell(Text(_transmissionLabel(transmission), style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(Text(_fuelTypeLabel(fuelType), style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(Text(_currencyFormat.format(dailyPrice), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
            DataCell(Text(seats, style: const TextStyle(color: AppColors.textSecondary))),
            DataCell(_buildStatusBadge(status)),
            DataCell(Text(locationName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
            DataCell(
              Switch(
                value: isActive,
                onChanged: (val) => _toggleCarActive(car['id'], val),
                activeThumbColor: AppColors.success,
              ),
            ),
            DataCell(
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'available', child: Text('Müsait')),
                  const PopupMenuItem(value: 'rented', child: Text('Kirada')),
                  const PopupMenuItem(value: 'maintenance', child: Text('Bakımda')),
                  const PopupMenuItem(value: 'inactive', child: Text('Pasif')),
                ],
                onSelected: (value) => _updateCarStatus(car['id'], value),
              ),
            ),
          ]);
        }).toList(),
      ),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCategoryBadge(String category) {
    final labels = {
      'economy': 'Ekonomi',
      'compact': 'Kompakt',
      'midsize': 'Orta',
      'fullsize': 'Büyük',
      'suv': 'SUV',
      'luxury': 'Lüks',
      'van': 'Van',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        labels[category] ?? category,
        style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _transmissionLabel(String t) {
    switch (t) {
      case 'manual': return 'Manuel';
      case 'automatic': return 'Otomatik';
      default: return t;
    }
  }

  String _fuelTypeLabel(String f) {
    switch (f) {
      case 'gasoline': return 'Benzin';
      case 'diesel': return 'Dizel';
      case 'hybrid': return 'Hibrit';
      case 'electric': return 'Elektrik';
      case 'lpg': return 'LPG';
      default: return f;
    }
  }
}
