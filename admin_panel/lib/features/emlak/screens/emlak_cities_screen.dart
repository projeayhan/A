import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakCitiesScreen extends ConsumerStatefulWidget {
  const EmlakCitiesScreen({super.key});

  @override
  ConsumerState<EmlakCitiesScreen> createState() => _EmlakCitiesScreenState();
}

class _EmlakCitiesScreenState extends ConsumerState<EmlakCitiesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(emlakCitiesProvider);

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
                      'Şehir Yönetimi',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'KKTC şehirlerini yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(emlakCitiesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddCityDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Şehir Ekle'),
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
                  hintText: 'Şehir ara...',
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

            // Cities Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: citiesAsync.when(
                  data: (cities) => _buildCitiesTable(cities),
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

  Widget _buildCitiesTable(List<EmlakCity> cities) {
    final filteredCities = cities.where((city) {
      return _searchQuery.isEmpty || city.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredCities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_city, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Şehir bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
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
              Expanded(flex: 3, child: Text('Şehir Adı', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Sıra', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Durum', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
              SizedBox(width: 100, child: Text('İşlemler', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        // Table Body
        Expanded(
          child: ListView.builder(
            itemCount: filteredCities.length,
            itemBuilder: (context, index) {
              final city = filteredCities[index];
              return _buildCityRow(city, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCityRow(EmlakCity city, int index) {
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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_city, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  city.name,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Sort Order
          Expanded(
            flex: 1,
            child: Text(
              city.sortOrder.toString(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          // Status
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: city.isActive
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                city.isActive ? 'Aktif' : 'Pasif',
                style: TextStyle(
                  color: city.isActive ? AppColors.success : AppColors.error,
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
                  onPressed: () => _showEditCityDialog(city),
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Düzenle',
                  color: AppColors.textMuted,
                ),
                IconButton(
                  onPressed: () => _showDeleteConfirmDialog(city),
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

  void _showAddCityDialog() {
    final nameController = TextEditingController();
    final sortController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Şehir Ekle'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Şehir Adı',
                  hintText: 'Örn: Girne',
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
              if (nameController.text.isEmpty) return;

              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.addCity(
                  nameController.text,
                  int.tryParse(sortController.text) ?? 0,
                );
                ref.invalidate(emlakCitiesProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Şehir eklendi'), backgroundColor: AppColors.success),
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
  }

  void _showEditCityDialog(EmlakCity city) {
    final nameController = TextEditingController(text: city.name);
    final sortController = TextEditingController(text: city.sortOrder.toString());
    bool isActive = city.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${city.name} Düzenle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Şehir Adı',
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
                  await service.updateCity(
                    city.id,
                    name: nameController.text,
                    sortOrder: int.tryParse(sortController.text),
                    isActive: isActive,
                  );
                  ref.invalidate(emlakCitiesProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Şehir güncellendi'), backgroundColor: AppColors.success),
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

  void _showDeleteConfirmDialog(EmlakCity city) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şehri Sil'),
        content: Text('"${city.name}" şehrini silmek istediğinize emin misiniz? Bu şehre bağlı tüm ilçeler de silinecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.deleteCity(city.id);
                ref.invalidate(emlakCitiesProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${city.name} silindi')),
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
