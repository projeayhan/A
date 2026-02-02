import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakPropertyTypesScreen extends ConsumerStatefulWidget {
  const EmlakPropertyTypesScreen({super.key});

  @override
  ConsumerState<EmlakPropertyTypesScreen> createState() => _EmlakPropertyTypesScreenState();
}

class _EmlakPropertyTypesScreenState extends ConsumerState<EmlakPropertyTypesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(emlakPropertyTypesProvider);

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
                      'Emlak Türleri',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Daire, villa, arsa gibi emlak türlerini yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(emlakPropertyTypesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddTypeDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Tür Ekle'),
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
                  hintText: 'Tür ara...',
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

            // Types Grid
            Expanded(
              child: typesAsync.when(
                data: (types) => _buildTypesGrid(types),
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

  Widget _buildTypesGrid(List<EmlakPropertyType> types) {
    final filteredTypes = types.where((type) {
      return _searchQuery.isEmpty || type.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredTypes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Emlak türü bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
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
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: filteredTypes.length,
      itemBuilder: (context, index) => _buildTypeCard(filteredTypes[index]),
    );
  }

  Widget _buildTypeCard(EmlakPropertyType type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getIconForType(type.icon),
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: type.isActive
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      type.isActive ? 'Aktif' : 'Pasif',
                      style: TextStyle(
                        color: type.isActive ? AppColors.success : AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onSelected: (value) => _handleTypeAction(value, type),
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
          const Spacer(),
          Text(
            type.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sıra: ${type.sortOrder}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String? icon) {
    switch (icon) {
      case 'apartment':
        return Icons.apartment;
      case 'villa':
        return Icons.villa;
      case 'land':
        return Icons.landscape;
      case 'office':
        return Icons.business;
      case 'shop':
        return Icons.storefront;
      case 'warehouse':
        return Icons.warehouse;
      case 'building':
        return Icons.domain;
      case 'farm':
        return Icons.agriculture;
      default:
        return Icons.home;
    }
  }

  void _handleTypeAction(String action, EmlakPropertyType type) {
    switch (action) {
      case 'edit':
        _showEditTypeDialog(type);
        break;
      case 'delete':
        _showDeleteConfirmDialog(type);
        break;
    }
  }

  void _showAddTypeDialog() {
    final nameController = TextEditingController();
    final sortController = TextEditingController(text: '0');
    String? selectedIcon = 'home';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Emlak Türü Ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tür Adı',
                    hintText: 'Örn: Villa',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'İkon',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'home', child: Text('Ev')),
                    DropdownMenuItem(value: 'apartment', child: Text('Daire')),
                    DropdownMenuItem(value: 'villa', child: Text('Villa')),
                    DropdownMenuItem(value: 'land', child: Text('Arsa')),
                    DropdownMenuItem(value: 'office', child: Text('Ofis')),
                    DropdownMenuItem(value: 'shop', child: Text('Dükkan')),
                    DropdownMenuItem(value: 'warehouse', child: Text('Depo')),
                    DropdownMenuItem(value: 'building', child: Text('Bina')),
                    DropdownMenuItem(value: 'farm', child: Text('Çiftlik')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedIcon = value),
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
                  await service.addPropertyType(
                    nameController.text,
                    selectedIcon,
                    int.tryParse(sortController.text) ?? 0,
                  );
                  ref.invalidate(emlakPropertyTypesProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Emlak türü eklendi'), backgroundColor: AppColors.success),
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

  void _showEditTypeDialog(EmlakPropertyType type) {
    final nameController = TextEditingController(text: type.name);
    final sortController = TextEditingController(text: type.sortOrder.toString());
    String? selectedIcon = type.icon ?? 'home';
    bool isActive = type.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${type.name} Düzenle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tür Adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedIcon,
                  decoration: const InputDecoration(
                    labelText: 'İkon',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'home', child: Text('Ev')),
                    DropdownMenuItem(value: 'apartment', child: Text('Daire')),
                    DropdownMenuItem(value: 'villa', child: Text('Villa')),
                    DropdownMenuItem(value: 'land', child: Text('Arsa')),
                    DropdownMenuItem(value: 'office', child: Text('Ofis')),
                    DropdownMenuItem(value: 'shop', child: Text('Dükkan')),
                    DropdownMenuItem(value: 'warehouse', child: Text('Depo')),
                    DropdownMenuItem(value: 'building', child: Text('Bina')),
                    DropdownMenuItem(value: 'farm', child: Text('Çiftlik')),
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
                  await service.updatePropertyType(
                    type.id,
                    name: nameController.text,
                    icon: selectedIcon,
                    sortOrder: int.tryParse(sortController.text),
                    isActive: isActive,
                  );
                  ref.invalidate(emlakPropertyTypesProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Emlak türü güncellendi'), backgroundColor: AppColors.success),
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

  void _showDeleteConfirmDialog(EmlakPropertyType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emlak Türünü Sil'),
        content: Text('"${type.name}" türünü silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.deletePropertyType(type.id);
                ref.invalidate(emlakPropertyTypesProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${type.name} silindi')),
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
