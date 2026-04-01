import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../services/rental_service.dart';

class RentalVehiclesScreen extends ConsumerStatefulWidget {
  const RentalVehiclesScreen({super.key});

  @override
  ConsumerState<RentalVehiclesScreen> createState() =>
      _RentalVehiclesScreenState();
}

class _RentalVehiclesScreenState extends ConsumerState<RentalVehiclesScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(allCarsProvider);

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
                      'Araç Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Araç filosunu görüntüleyin ve yönetin',
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
                      onPressed: () => ref.invalidate(allCarsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddCarDialog(),
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
            carsAsync.when(
              data: (cars) => _buildStatsRow(cars),
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
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Araç ara (marka, model, plaka)...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tüm Durumlar'),
                          ),
                          DropdownMenuItem(
                            value: 'available',
                            child: Text('Müsait'),
                          ),
                          DropdownMenuItem(
                            value: 'rented',
                            child: Text('Kirada'),
                          ),
                          DropdownMenuItem(
                            value: 'reserved',
                            child: Text('Rezerveli'),
                          ),
                          DropdownMenuItem(
                            value: 'maintenance',
                            child: Text('Bakımda'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value!),
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
                        value: _categoryFilter,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tüm Kategoriler'),
                          ),
                          DropdownMenuItem(value: 'Lüks', child: Text('Lüks')),
                          DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                          DropdownMenuItem(
                            value: 'Sedan',
                            child: Text('Sedan'),
                          ),
                          DropdownMenuItem(
                            value: 'Kompakt',
                            child: Text('Kompakt'),
                          ),
                          DropdownMenuItem(value: 'Spor', child: Text('Spor')),
                          DropdownMenuItem(
                            value: 'Elektrikli',
                            child: Text('Elektrikli'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _categoryFilter = value!),
                      ),
                    ),
                  ),
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
                child: carsAsync.when(
                  data: (cars) => _buildDataTable(cars),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions_car,
                          size: 64,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Araç yüklenemedi',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hata: $e',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
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

  Widget _buildStatsRow(List<RentalCarView> cars) {
    final available = cars.where((c) => c.status == 'available').length;
    final rented = cars.where((c) => c.status == 'rented').length;
    final reserved = cars.where((c) => c.status == 'reserved').length;
    final maintenance = cars.where((c) => c.status == 'maintenance').length;

    return Row(
      children: [
        _buildStatCard(
          'Toplam Araç',
          cars.length.toString(),
          Icons.directions_car,
          AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Müsait',
          available.toString(),
          Icons.check_circle,
          AppColors.success,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Kirada',
          rented.toString(),
          Icons.key,
          AppColors.warning,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Rezerveli',
          reserved.toString(),
          Icons.event,
          AppColors.info,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Bakımda',
          maintenance.toString(),
          Icons.build,
          AppColors.error,
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

  Widget _buildDataTable(List<RentalCarView> cars) {
    var filteredCars = cars.where((car) {
      final searchLower = _searchQuery.toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty ||
          car.brandName.toLowerCase().contains(searchLower) ||
          car.model.toLowerCase().contains(searchLower) ||
          car.licensePlate.toLowerCase().contains(searchLower);
      final matchesStatus =
          _statusFilter == 'all' || car.status == _statusFilter;
      final matchesCategory =
          _categoryFilter == 'all' || car.category == _categoryFilter;
      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();

    if (filteredCars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Araç bulunamadı',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty ||
                _statusFilter != 'all' ||
                _categoryFilter != 'all')
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _statusFilter = 'all';
                    _categoryFilter = 'all';
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
      headingTextStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      dataTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      columns: const [
        DataColumn2(label: Text('ARAÇ'), size: ColumnSize.L),
        DataColumn2(label: Text('KATEGORİ'), size: ColumnSize.S),
        DataColumn2(label: Text('PLAKA'), size: ColumnSize.S),
        DataColumn2(label: Text('GÜNLÜK FİYAT'), size: ColumnSize.S),
        DataColumn2(label: Text('LOKASYON'), size: ColumnSize.M),
        DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        DataColumn2(label: Text('PUAN'), size: ColumnSize.S),
        DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: filteredCars.map((car) {
        return DataRow2(
          cells: [
            DataCell(
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        car.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.directions_car,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                car.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (car.isPremium) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Premium',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${car.year} • ${car.transmission} • ${car.fuelType}',
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
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(car.category, style: const TextStyle(fontSize: 12)),
              ),
            ),
            DataCell(
              Text(
                car.licensePlate,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            DataCell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₺${car.dailyPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (car.discountPercentage != null)
                    Text(
                      '%${car.discountPercentage!.toStringAsFixed(0)} indirim',
                      style: TextStyle(color: AppColors.success, fontSize: 11),
                    ),
                ],
              ),
            ),
            DataCell(
              Text(
                car.currentLocationName ?? '-',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            DataCell(_buildStatusBadge(car.status)),
            DataCell(
              Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                  const SizedBox(width: 4),
                  Text('${car.rating}', style: const TextStyle(fontSize: 13)),
                  Text(
                    ' (${car.reviewCount})',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showCarDetailDialog(car),
                    icon: const Icon(Icons.visibility, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Detay',
                  ),
                  IconButton(
                    onPressed: () => _showEditCarDialog(car),
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.info,
                    tooltip: 'Düzenle',
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (value) => _handleCarAction(value, car),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'calendar',
                        child: Text('Takvimi Gör'),
                      ),
                      const PopupMenuItem(
                        value: 'maintenance',
                        child: Text('Bakıma Al'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Sil',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
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
      case 'available':
        color = AppColors.success;
        text = 'Müsait';
        break;
      case 'rented':
        color = AppColors.warning;
        text = 'Kirada';
        break;
      case 'reserved':
        color = AppColors.info;
        text = 'Rezerveli';
        break;
      case 'maintenance':
        color = AppColors.error;
        text = 'Bakımda';
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

  void _showAddCarDialog() {
    final formKey = GlobalKey<FormState>();
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final plateController = TextEditingController();
    final dailyPriceController = TextEditingController();
    final weeklyPriceController = TextEditingController();
    final monthlyPriceController = TextEditingController();
    final colorController = TextEditingController();
    String selectedCategory = 'economy';
    String selectedFuelType = 'gasoline';
    String selectedTransmission = 'automatic';
    int seats = 5;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Araç Ekle'),
          content: SizedBox(
            width: 550,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: brandController,
                            decoration: const InputDecoration(
                              labelText: 'Araç Markası *',
                              hintText: 'Örn: Toyota',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Marka gerekli' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: modelController,
                            decoration: const InputDecoration(
                              labelText: 'Model *',
                              hintText: 'Örn: Corolla',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Model gerekli' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: yearController,
                            decoration: const InputDecoration(
                              labelText: 'Yıl *',
                              hintText: 'Örn: 2024',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Yıl gerekli';
                              final year = int.tryParse(v);
                              if (year == null || year < 1990 || year > 2030) return 'Geçerli bir yıl girin';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: plateController,
                            decoration: const InputDecoration(
                              labelText: 'Plaka *',
                              hintText: 'Örn: 34 ABC 123',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Plaka gerekli' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: colorController,
                            decoration: const InputDecoration(
                              labelText: 'Renk',
                              hintText: 'Örn: Beyaz',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: seats,
                            decoration: const InputDecoration(
                              labelText: 'Koltuk Sayısı',
                              border: OutlineInputBorder(),
                            ),
                            items: [2, 4, 5, 7, 8, 9].map((s) => DropdownMenuItem(value: s, child: Text('$s kişilik'))).toList(),
                            onChanged: (v) => setDialogState(() => seats = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'economy', child: Text('Ekonomik')),
                              DropdownMenuItem(value: 'compact', child: Text('Kompakt')),
                              DropdownMenuItem(value: 'midsize', child: Text('Orta')),
                              DropdownMenuItem(value: 'fullsize', child: Text('Büyük')),
                              DropdownMenuItem(value: 'suv', child: Text('SUV')),
                              DropdownMenuItem(value: 'luxury', child: Text('Lüks')),
                              DropdownMenuItem(value: 'van', child: Text('Van')),
                            ],
                            onChanged: (v) => setDialogState(() => selectedCategory = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedTransmission,
                            decoration: const InputDecoration(
                              labelText: 'Şanzıman',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'automatic', child: Text('Otomatik')),
                              DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                            ],
                            onChanged: (v) => setDialogState(() => selectedTransmission = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFuelType,
                      decoration: const InputDecoration(
                        labelText: 'Yakıt Tipi',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'gasoline', child: Text('Benzin')),
                        DropdownMenuItem(value: 'diesel', child: Text('Dizel')),
                        DropdownMenuItem(value: 'hybrid', child: Text('Hibrit')),
                        DropdownMenuItem(value: 'electric', child: Text('Elektrik')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedFuelType = v!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dailyPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Günlük Fiyat (TL) *',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixText: '₺ ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Fiyat gerekli';
                              if (double.tryParse(v) == null) return 'Geçerli bir fiyat girin';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: weeklyPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Haftalık Fiyat (TL)',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixText: '₺ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: monthlyPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Aylık Fiyat (TL)',
                              hintText: '0',
                              border: OutlineInputBorder(),
                              prefixText: '₺ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      try {
                        final client = ref.read(supabaseClientProvider);
                        final dailyPrice = double.parse(dailyPriceController.text);
                        final weeklyPrice = double.tryParse(weeklyPriceController.text) ?? (dailyPrice * 6);
                        final monthlyPrice = double.tryParse(monthlyPriceController.text) ?? (dailyPrice * 25);

                        await client.from('rental_cars').insert({
                          'brand': brandController.text.trim(),
                          'model': modelController.text.trim(),
                          'year': int.parse(yearController.text.trim()),
                          'plate': plateController.text.trim(),
                          'vehicle_color': colorController.text.trim().isNotEmpty ? colorController.text.trim() : null,
                          'category': selectedCategory,
                          'transmission': selectedTransmission,
                          'fuel_type': selectedFuelType,
                          'seats': seats,
                          'doors': 4,
                          'daily_price': dailyPrice,
                          'weekly_price': weeklyPrice,
                          'monthly_price': monthlyPrice,
                          'status': 'available',
                          'mileage': 0,
                          'fuel_level': 1.0,
                        });

                        ref.invalidate(allCarsProvider);
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Araç başarıyla eklendi'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCarDetailDialog(RentalCarView car) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(car.fullName),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  car.thumbnailUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Kategori', car.category),
              _buildDetailRow('Yıl', car.year.toString()),
              _buildDetailRow('Şanzıman', car.transmission),
              _buildDetailRow('Yakıt', car.fuelType),
              _buildDetailRow('Koltuk', '${car.seats} kişilik'),
              _buildDetailRow('Plaka', car.licensePlate),
              _buildDetailRow('Renk', car.color),
              _buildDetailRow('Kilometre', '${car.mileage} km'),
              _buildDetailRow(
                'Günlük Fiyat',
                '₺${car.dailyPrice.toStringAsFixed(0)}',
              ),
              _buildDetailRow(
                'Haftalık Fiyat',
                '₺${car.weeklyPrice.toStringAsFixed(0)}',
              ),
              _buildDetailRow(
                'Aylık Fiyat',
                '₺${car.monthlyPrice.toStringAsFixed(0)}',
              ),
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
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCarDialog(RentalCarView car) {
    final formKey = GlobalKey<FormState>();
    final brandController = TextEditingController(text: car.brandName);
    final modelController = TextEditingController(text: car.model);
    final yearController = TextEditingController(text: car.year.toString());
    final plateController = TextEditingController(text: car.licensePlate);
    final dailyPriceController = TextEditingController(text: car.dailyPrice.toStringAsFixed(0));
    final weeklyPriceController = TextEditingController(text: car.weeklyPrice.toStringAsFixed(0));
    final monthlyPriceController = TextEditingController(text: car.monthlyPrice.toStringAsFixed(0));
    final colorController = TextEditingController(text: car.color);
    final mileageController = TextEditingController(text: car.mileage.toString());
    String selectedStatus = car.status;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${car.fullName} Düzenle'),
          content: SizedBox(
            width: 550,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: brandController,
                            decoration: const InputDecoration(
                              labelText: 'Araç Markası *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Marka gerekli' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: modelController,
                            decoration: const InputDecoration(
                              labelText: 'Model *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Model gerekli' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: yearController,
                            decoration: const InputDecoration(
                              labelText: 'Yıl *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Yıl gerekli';
                              final year = int.tryParse(v);
                              if (year == null || year < 1990 || year > 2030) return 'Geçerli bir yıl girin';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: plateController,
                            decoration: const InputDecoration(
                              labelText: 'Plaka *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Plaka gerekli' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: colorController,
                            decoration: const InputDecoration(
                              labelText: 'Renk',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: mileageController,
                            decoration: const InputDecoration(
                              labelText: 'Kilometre',
                              border: OutlineInputBorder(),
                              suffixText: 'km',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Durum',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'available', child: Text('Müsait')),
                        DropdownMenuItem(value: 'rented', child: Text('Kirada')),
                        DropdownMenuItem(value: 'reserved', child: Text('Rezerveli')),
                        DropdownMenuItem(value: 'maintenance', child: Text('Bakımda')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedStatus = v!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dailyPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Günlük Fiyat (TL) *',
                              border: OutlineInputBorder(),
                              prefixText: '₺ ',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Fiyat gerekli';
                              if (double.tryParse(v) == null) return 'Geçerli bir fiyat girin';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: weeklyPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Haftalık Fiyat (TL)',
                              border: OutlineInputBorder(),
                              prefixText: '₺ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: monthlyPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Aylık Fiyat (TL)',
                              border: OutlineInputBorder(),
                              prefixText: '₺ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      try {
                        final client = ref.read(supabaseClientProvider);
                        final dailyPrice = double.parse(dailyPriceController.text);

                        await client.from('rental_cars').update({
                          'brand': brandController.text.trim(),
                          'model': modelController.text.trim(),
                          'year': int.parse(yearController.text.trim()),
                          'plate': plateController.text.trim(),
                          'vehicle_color': colorController.text.trim().isNotEmpty ? colorController.text.trim() : null,
                          'daily_price': dailyPrice,
                          'weekly_price': double.tryParse(weeklyPriceController.text) ?? (dailyPrice * 6),
                          'monthly_price': double.tryParse(monthlyPriceController.text) ?? (dailyPrice * 25),
                          'mileage': int.tryParse(mileageController.text) ?? car.mileage,
                          'status': selectedStatus,
                        }).eq('id', car.id);

                        ref.invalidate(allCarsProvider);
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('${car.fullName} güncellendi'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCarAction(String action, RentalCarView car) {
    switch (action) {
      case 'calendar':
        _showCarCalendarDialog(car);
        break;
      case 'maintenance':
        _showMaintenanceDialog(car);
        break;
      case 'delete':
        _showDeleteConfirmDialog(car);
        break;
    }
  }

  void _showCarCalendarDialog(RentalCarView car) {
    final bookingsAsync = ref.read(supabaseClientProvider)
        .from('rental_bookings')
        .select('id, booking_number, pickup_date, dropoff_date, status, customer_name')
        .eq('car_id', car.id)
        .order('pickup_date', ascending: false)
        .limit(20);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('${car.fullName} - Rezervasyonlar')),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: FutureBuilder<List<dynamic>>(
            future: bookingsAsync,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Hata: ${snapshot.error}', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }
              final bookings = List<Map<String, dynamic>>.from(snapshot.data ?? []);
              if (bookings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'Bu araca ait rezervasyon bulunmuyor',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Durum: ${car.statusDisplay}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                itemCount: bookings.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final booking = bookings[index];
                  final pickupDate = DateTime.tryParse(booking['pickup_date'] ?? '');
                  final dropoffDate = DateTime.tryParse(booking['dropoff_date'] ?? '');
                  final status = booking['status'] ?? 'pending';

                  Color statusColor;
                  String statusText;
                  switch (status) {
                    case 'active':
                      statusColor = AppColors.success;
                      statusText = 'Aktif';
                      break;
                    case 'confirmed':
                      statusColor = AppColors.info;
                      statusText = 'Onaylandı';
                      break;
                    case 'pending':
                      statusColor = AppColors.warning;
                      statusText = 'Beklemede';
                      break;
                    case 'completed':
                      statusColor = AppColors.textMuted;
                      statusText = 'Tamamlandı';
                      break;
                    case 'cancelled':
                      statusColor = AppColors.error;
                      statusText = 'İptal';
                      break;
                    default:
                      statusColor = AppColors.textMuted;
                      statusText = status;
                  }

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.event, color: statusColor, size: 20),
                    ),
                    title: Text(
                      booking['customer_name'] ?? booking['booking_number'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      pickupDate != null && dropoffDate != null
                          ? '${pickupDate.day}/${pickupDate.month}/${pickupDate.year} - ${dropoffDate.day}/${dropoffDate.month}/${dropoffDate.year}'
                          : '-',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(RentalCarView car) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bakıma Al'),
        content: Text(
          '${car.fullName} aracını bakıma almak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final client = ref.read(supabaseClientProvider);
                final success = await updateCarStatus(
                  client,
                  car.id,
                  'maintenance',
                );
                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${car.fullName} bakıma alındı'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('İşlem başarısız oldu'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
                ref.invalidate(allCarsProvider);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Bakıma Al'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(RentalCarView car) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aracı Sil'),
        content: Text(
          '${car.fullName} aracını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final client = ref.read(supabaseClientProvider);
                await client.from('rental_cars').delete().eq('id', car.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${car.fullName} silindi'),
                    backgroundColor: AppColors.success,
                  ),
                );
                ref.invalidate(allCarsProvider);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Silme hatası: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
