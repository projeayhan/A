import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakAmenitiesScreen extends ConsumerStatefulWidget {
  const EmlakAmenitiesScreen({super.key});

  @override
  ConsumerState<EmlakAmenitiesScreen> createState() => _EmlakAmenitiesScreenState();
}

class _EmlakAmenitiesScreenState extends ConsumerState<EmlakAmenitiesScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  final List<String> _categories = ['Genel', 'İç Mekan', 'Dış Mekan', 'Güvenlik', 'Isıtma/Soğutma'];

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(emlakAmenitiesProvider);

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
                      'Özellikler (Amenities)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Otopark, havuz, mobilya gibi emlak özelliklerini yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(emlakAmenitiesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddAmenityDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Özellik Ekle'),
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
                  // Category Filter
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Kategori Filtrele',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Tüm Kategoriler')),
                        ..._categories.map((cat) => DropdownMenuItem<String?>(value: cat, child: Text(cat))),
                      ],
                      onChanged: (value) => setState(() => _selectedCategory = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Özellik ara...',
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

            // Amenities Grid
            Expanded(
              child: amenitiesAsync.when(
                data: (amenities) => _buildAmenitiesGrid(amenities),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAmenitiesGrid(List<EmlakAmenity> amenities) {
    var filteredAmenities = amenities.where((amenity) {
      final matchesSearch = _searchQuery.isEmpty ||
          amenity.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null ||
          amenity.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    if (filteredAmenities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.featured_play_list, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Özellik bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            if (_searchQuery.isNotEmpty || _selectedCategory != null)
              TextButton(
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _selectedCategory = null;
                }),
                child: const Text('Filtreleri Temizle'),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2,
      ),
      itemCount: filteredAmenities.length,
      itemBuilder: (context, index) => _buildAmenityCard(filteredAmenities[index]),
    );
  }

  Widget _buildAmenityCard(EmlakAmenity amenity) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getCategoryColor(amenity.category).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIconForAmenity(amenity.icon),
              color: _getCategoryColor(amenity.category),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amenity.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  amenity.category ?? 'Genel',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: amenity.isActive
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  amenity.isActive ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    color: amenity.isActive ? AppColors.success : AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                onSelected: (value) => _handleAmenityAction(value, amenity),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Sil', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'İç Mekan':
        return AppColors.info;
      case 'Dış Mekan':
        return AppColors.success;
      case 'Güvenlik':
        return AppColors.error;
      case 'Isıtma/Soğutma':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconForAmenity(String? icon) {
    switch (icon) {
      case 'parking':
        return Icons.local_parking;
      case 'pool':
        return Icons.pool;
      case 'furniture':
        return Icons.chair;
      case 'elevator':
        return Icons.elevator;
      case 'security':
        return Icons.security;
      case 'garden':
        return Icons.yard;
      case 'balcony':
        return Icons.balcony;
      case 'ac':
        return Icons.ac_unit;
      case 'heating':
        return Icons.whatshot;
      case 'internet':
        return Icons.wifi;
      case 'gym':
        return Icons.fitness_center;
      case 'playground':
        return Icons.toys;
      default:
        return Icons.check_circle;
    }
  }

  void _handleAmenityAction(String action, EmlakAmenity amenity) {
    switch (action) {
      case 'edit':
        _showEditAmenityDialog(amenity);
        break;
      case 'delete':
        _showDeleteConfirmDialog(amenity);
        break;
    }
  }

  void _showAddAmenityDialog() {
    final nameController = TextEditingController();
    final sortController = TextEditingController(text: '0');
    String? selectedIcon = 'check_circle';
    String? selectedCategory = 'Genel';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Özellik Ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Özellik Adı',
                    hintText: 'Örn: Otopark',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (value) => setDialogState(() => selectedCategory = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'İkon',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'check_circle', child: Text('Varsayılan')),
                    DropdownMenuItem(value: 'parking', child: Text('Otopark')),
                    DropdownMenuItem(value: 'pool', child: Text('Havuz')),
                    DropdownMenuItem(value: 'furniture', child: Text('Mobilya')),
                    DropdownMenuItem(value: 'elevator', child: Text('Asansör')),
                    DropdownMenuItem(value: 'security', child: Text('Güvenlik')),
                    DropdownMenuItem(value: 'garden', child: Text('Bahçe')),
                    DropdownMenuItem(value: 'balcony', child: Text('Balkon')),
                    DropdownMenuItem(value: 'ac', child: Text('Klima')),
                    DropdownMenuItem(value: 'heating', child: Text('Isıtma')),
                    DropdownMenuItem(value: 'internet', child: Text('İnternet')),
                    DropdownMenuItem(value: 'gym', child: Text('Spor Salonu')),
                    DropdownMenuItem(value: 'playground', child: Text('Oyun Alanı')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedIcon = value),
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
                  await service.addAmenity(
                    nameController.text,
                    selectedIcon,
                    selectedCategory,
                    int.tryParse(sortController.text) ?? 0,
                  );
                  ref.invalidate(emlakAmenitiesProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Özellik eklendi'), backgroundColor: AppColors.success),
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
      ),
    );
  }

  void _showEditAmenityDialog(EmlakAmenity amenity) {
    final nameController = TextEditingController(text: amenity.name);
    final sortController = TextEditingController(text: amenity.sortOrder.toString());
    String? selectedIcon = amenity.icon ?? 'check_circle';
    String? selectedCategory = amenity.category ?? 'Genel';
    bool isActive = amenity.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${amenity.name} Düzenle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Özellik Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (value) => setDialogState(() => selectedCategory = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'İkon',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'check_circle', child: Text('Varsayılan')),
                    DropdownMenuItem(value: 'parking', child: Text('Otopark')),
                    DropdownMenuItem(value: 'pool', child: Text('Havuz')),
                    DropdownMenuItem(value: 'furniture', child: Text('Mobilya')),
                    DropdownMenuItem(value: 'elevator', child: Text('Asansör')),
                    DropdownMenuItem(value: 'security', child: Text('Güvenlik')),
                    DropdownMenuItem(value: 'garden', child: Text('Bahçe')),
                    DropdownMenuItem(value: 'balcony', child: Text('Balkon')),
                    DropdownMenuItem(value: 'ac', child: Text('Klima')),
                    DropdownMenuItem(value: 'heating', child: Text('Isıtma')),
                    DropdownMenuItem(value: 'internet', child: Text('İnternet')),
                    DropdownMenuItem(value: 'gym', child: Text('Spor Salonu')),
                    DropdownMenuItem(value: 'playground', child: Text('Oyun Alanı')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedIcon = value),
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
                  await service.updateAmenity(
                    amenity.id,
                    name: nameController.text,
                    icon: selectedIcon,
                    category: selectedCategory,
                    sortOrder: int.tryParse(sortController.text),
                    isActive: isActive,
                  );
                  ref.invalidate(emlakAmenitiesProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Özellik güncellendi'), backgroundColor: AppColors.success),
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

  void _showDeleteConfirmDialog(EmlakAmenity amenity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Özelliği Sil'),
        content: Text('"${amenity.name}" özelliğini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.deleteAmenity(amenity.id);
                ref.invalidate(emlakAmenitiesProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${amenity.name} silindi')),
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
