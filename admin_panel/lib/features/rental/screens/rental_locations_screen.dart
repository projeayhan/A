import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/rental_service.dart';

class RentalLocationsScreen extends ConsumerStatefulWidget {
  const RentalLocationsScreen({super.key});

  @override
  ConsumerState<RentalLocationsScreen> createState() => _RentalLocationsScreenState();
}

class _RentalLocationsScreenState extends ConsumerState<RentalLocationsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(allLocationsProvider);

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
                      'Lokasyon Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Teslim ve iade noktalarını yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(allLocationsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddLocationDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Lokasyon Ekle'),
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
            locationsAsync.when(
              data: (locations) => _buildStatsRow(locations),
              loading: () => _buildStatsRowLoading(),
              error: (_, _) => const SizedBox(),
            ),

            const SizedBox(height: 24),

            // Search
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Lokasyon ara...',
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

            const SizedBox(height: 24),

            // Locations Grid
            Expanded(
              child: locationsAsync.when(
                data: (locations) => _buildLocationsGrid(locations),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      const Text('Lokasyonlar yüklenemedi', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Hata: $e', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<RentalLocationView> locations) {
    final totalCars = locations.fold<int>(0, (sum, l) => sum + l.totalCarCount);
    final availableCars = locations.fold<int>(0, (sum, l) => sum + l.availableCarCount);
    final airportLocations = locations.where((l) => l.isAirport).length;
    final locations24h = locations.where((l) => l.is24Hours).length;

    return Row(
      children: [
        _buildStatCard('Toplam Lokasyon', locations.length.toString(), Icons.location_on, AppColors.primary),
        const SizedBox(width: 16),
        _buildStatCard('Toplam Araç', totalCars.toString(), Icons.directions_car, AppColors.info),
        const SizedBox(width: 16),
        _buildStatCard('Müsait Araç', availableCars.toString(), Icons.check_circle, AppColors.success),
        const SizedBox(width: 16),
        _buildStatCard('Havalimanı', airportLocations.toString(), Icons.flight, AppColors.warning),
        const SizedBox(width: 16),
        _buildStatCard('7/24 Açık', locations24h.toString(), Icons.access_time, AppColors.success),
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

  Widget _buildLocationsGrid(List<RentalLocationView> locations) {
    final filteredLocations = locations.where((location) {
      final searchLower = _searchQuery.toLowerCase();
      return _searchQuery.isEmpty ||
          location.name.toLowerCase().contains(searchLower) ||
          location.address.toLowerCase().contains(searchLower);
    }).toList();

    if (filteredLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Lokasyon bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            if (_searchQuery.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _searchQuery = ''),
                child: const Text('Aramayı Temizle'),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.8,
      ),
      itemCount: filteredLocations.length,
      itemBuilder: (context, index) => _buildLocationCard(filteredLocations[index]),
    );
  }

  Widget _buildLocationCard(RentalLocationView location) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: location.isAirport
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  location.isAirport ? Icons.flight : Icons.location_on,
                  color: location.isAirport ? AppColors.warning : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            location.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (location.is24Hours) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '7/24',
                              style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location.address,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (value) => _handleLocationAction(value, location),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                  const PopupMenuItem(value: 'cars', child: Text('Araçları Gör')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Sil', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Info Row
          Row(
            children: [
              _buildInfoChip(Icons.phone, location.phone),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.access_time, location.workingHours),
            ],
          ),

          const SizedBox(height: 16),

          // Car Availability
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        '${location.availableCarCount} / ${location.totalCarCount} müsait',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: location.availableCarCount > 0 ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      location.availableCarCount > 0 ? 'Aktif' : 'Dolu',
                      style: TextStyle(
                        color: location.availableCarCount > 0 ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
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
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final hoursController = TextEditingController();
    bool isAirport = false;
    bool is24Hours = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Lokasyon Ekle'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Lokasyon Adı',
                      hintText: 'Örn: Ercan Havalimanı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adres',
                      hintText: 'Tam adres',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Telefon',
                            hintText: '+90 392 xxx xxxx',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          decoration: const InputDecoration(
                            labelText: 'Çalışma Saatleri',
                            hintText: '08:00 - 20:00',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Havalimanı'),
                          value: isAirport,
                          onChanged: (value) => setDialogState(() => isAirport = value!),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('7/24 Açık'),
                          value: is24Hours,
                          onChanged: (value) => setDialogState(() => is24Hours = value!),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lokasyon eklendi'), backgroundColor: AppColors.success),
                );
                ref.invalidate(allLocationsProvider);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLocationAction(String action, RentalLocationView location) {
    switch (action) {
      case 'edit':
        _showEditLocationDialog(location);
        break;
      case 'cars':
        _showLocationCarsDialog(location);
        break;
      case 'delete':
        _showDeleteConfirmDialog(location);
        break;
    }
  }

  void _showEditLocationDialog(RentalLocationView location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${location.name} Düzenle'),
        content: const SizedBox(
          width: 500,
          child: Text('Lokasyon düzenleme formu burada görüntülenecek.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Kaydet')),
        ],
      ),
    );
  }

  void _showLocationCarsDialog(RentalLocationView location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${location.name} - Araçlar'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_car, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  '${location.totalCarCount} araç bu lokasyonda',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  '${location.availableCarCount} müsait',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(RentalLocationView location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasyonu Sil'),
        content: Text('${location.name} lokasyonunu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${location.name} silindi')),
              );
              ref.invalidate(allLocationsProvider);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
