import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakDistrictsScreen extends ConsumerStatefulWidget {
  const EmlakDistrictsScreen({super.key});

  @override
  ConsumerState<EmlakDistrictsScreen> createState() => _EmlakDistrictsScreenState();
}

class _EmlakDistrictsScreenState extends ConsumerState<EmlakDistrictsScreen> {
  String _searchQuery = '';
  String? _selectedCityId;

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(emlakCitiesProvider);
    final districtsAsync = ref.watch(emlakDistrictsProvider(_selectedCityId));

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
                      'İlçe Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Şehirlere bağlı ilçeleri yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(emlakDistrictsProvider(_selectedCityId)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddDistrictDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni İlçe Ekle'),
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
                  // City Filter
                  Expanded(
                    child: citiesAsync.when(
                      data: (cities) => DropdownButtonFormField<String?>(
                        initialValue: _selectedCityId,
                        decoration: InputDecoration(
                          labelText: 'Şehir Filtrele',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tüm Şehirler'),
                          ),
                          ...cities.map((city) => DropdownMenuItem<String?>(
                                value: city.id,
                                child: Text(city.name),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedCityId = value);
                        },
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Şehirler yüklenemedi'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'İlçe ara...',
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
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Districts Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: districtsAsync.when(
                  data: (districts) => _buildDistrictsTable(districts),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Hata: $e', style: const TextStyle(color: AppColors.textSecondary)),
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

  Widget _buildDistrictsTable(List<EmlakDistrict> districts) {
    final filteredDistricts = districts.where((district) {
      return _searchQuery.isEmpty || district.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredDistricts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('İlçe bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            if (_searchQuery.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _searchQuery = ''),
                child: const Text('Aramayı Temizle'),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('İlçe Adı', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 2, child: Text('Şehir', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Sıra', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Durum', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              SizedBox(width: 100, child: Text('İşlemler', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        // Table Body
        Expanded(
          child: ListView.builder(
            itemCount: filteredDistricts.length,
            itemBuilder: (context, index) {
              final district = filteredDistricts[index];
              return _buildDistrictRow(district, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictRow(EmlakDistrict district, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.transparent : AppColors.background.withValues(alpha: 0.5),
        border: const Border(bottom: BorderSide(color: AppColors.surfaceLight, width: 0.5)),
      ),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  district.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // City
          Expanded(
            flex: 2,
            child: Text(
              district.cityName ?? '-',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          // Sort Order
          Expanded(
            flex: 1,
            child: Text(
              district.sortOrder.toString(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: district.isActive
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                district.isActive ? 'Aktif' : 'Pasif',
                style: TextStyle(
                  color: district.isActive ? AppColors.success : AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _showEditDistrictDialog(district),
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Düzenle',
                  color: AppColors.textMuted,
                ),
                IconButton(
                  onPressed: () => _showDeleteConfirmDialog(district),
                  icon: const Icon(Icons.delete, size: 18),
                  tooltip: 'Sil',
                  color: AppColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDistrictDialog() {
    final nameController = TextEditingController();
    final sortController = TextEditingController(text: '0');
    String? selectedCityId;

    showDialog(
      context: context,
      builder: (context) {
        final citiesAsync = ref.watch(emlakCitiesProvider);

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Yeni İlçe Ekle'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  citiesAsync.when(
                    data: (cities) => DropdownButtonFormField<String>(
                      initialValue: selectedCityId,
                      decoration: const InputDecoration(
                        labelText: 'Şehir Seçin',
                        border: OutlineInputBorder(),
                      ),
                      items: cities.map((city) => DropdownMenuItem<String>(
                            value: city.id,
                            child: Text(city.name),
                          )).toList(),
                      onChanged: (value) => setDialogState(() => selectedCityId = value),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('Şehirler yüklenemedi'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'İlçe Adı',
                      hintText: 'Örn: Alsancak',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sıra Numarası',
                      hintText: 'Örn: 1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty || selectedCityId == null) return;

                  final service = ref.read(emlakAdminServiceProvider);
                  try {
                    await service.addDistrict(
                      selectedCityId!,
                      nameController.text,
                      int.tryParse(sortController.text) ?? 0,
                    );
                    ref.invalidate(emlakDistrictsProvider(_selectedCityId));
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İlçe eklendi'), backgroundColor: AppColors.success),
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
                child: const Text('Ekle'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDistrictDialog(EmlakDistrict district) {
    final nameController = TextEditingController(text: district.name);
    final sortController = TextEditingController(text: district.sortOrder.toString());
    bool isActive = district.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${district.name} Düzenle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'İlçe Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sıra Numarası',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aktif'),
                  value: isActive,
                  onChanged: (value) => setDialogState(() => isActive = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;

                final service = ref.read(emlakAdminServiceProvider);
                try {
                  await service.updateDistrict(
                    district.id,
                    name: nameController.text,
                    sortOrder: int.tryParse(sortController.text),
                    isActive: isActive,
                  );
                  ref.invalidate(emlakDistrictsProvider(_selectedCityId));
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('İlçe güncellendi'), backgroundColor: AppColors.success),
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
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(EmlakDistrict district) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlçeyi Sil'),
        content: Text('"${district.name}" ilçesini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.deleteDistrict(district.id);
                ref.invalidate(emlakDistrictsProvider(_selectedCityId));
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${district.name} silindi')),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
