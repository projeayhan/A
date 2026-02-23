import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Model
class CourierVehicleType {
  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;

  CourierVehicleType({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CourierVehicleType.fromJson(Map<String, dynamic> json) {
    return CourierVehicleType(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// Provider
final courierVehicleTypesProvider = FutureProvider<List<CourierVehicleType>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('courier_vehicle_types')
      .select()
      .order('sort_order');
  return (response as List).map((e) => CourierVehicleType.fromJson(e)).toList();
});

class CourierVehicleTypesScreen extends ConsumerStatefulWidget {
  const CourierVehicleTypesScreen({super.key});

  @override
  ConsumerState<CourierVehicleTypesScreen> createState() => _CourierVehicleTypesScreenState();
}

class _CourierVehicleTypesScreenState extends ConsumerState<CourierVehicleTypesScreen> {
  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(courierVehicleTypesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kurye Araç Tipleri',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kurye kayıt ekranında gösterilecek araç tiplerini yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(courierVehicleTypesProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Araç Tipi Ekle'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: typesAsync.when(
                data: (types) => _buildTable(types),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<CourierVehicleType> items) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.two_wheeler, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Henüz araç tipi yok', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 32,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Ad')),
            DataColumn(label: Text('Ikon')),
            DataColumn(label: Text('Sira')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('Islemler')),
          ],
          rows: items.map((item) => _buildRow(item)).toList(),
        ),
      ),
    );
  }

  DataRow _buildRow(CourierVehicleType item) {
    return DataRow(
      cells: [
        DataCell(Text(item.id, style: const TextStyle(fontFamily: 'monospace'))),
        DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconData(item.icon), size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(item.icon ?? '-', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        DataCell(Text(item.sortOrder.toString())),
        DataCell(_buildStatusBadge(item.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showDialog(item: item),
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Duzenle',
                color: AppColors.info,
              ),
              IconButton(
                onPressed: () => _delete(item),
                icon: const Icon(Icons.delete, size: 20),
                tooltip: 'Sil',
                color: AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconData(String? iconName) {
    const iconMap = {
      'two_wheeler': Icons.two_wheeler,
      'pedal_bike': Icons.pedal_bike,
      'directions_car': Icons.directions_car,
      'sports_motorsports': Icons.sports_motorsports,
      'electric_scooter': Icons.electric_scooter,
      'local_shipping': Icons.local_shipping,
      'motorcycle': Icons.two_wheeler,
    };
    return iconMap[iconName] ?? Icons.two_wheeler;
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showDialog({CourierVehicleType? item}) {
    final isEdit = item != null;
    final idController = TextEditingController(text: item?.id ?? '');
    final nameController = TextEditingController(text: item?.name ?? '');
    final iconController = TextEditingController(text: item?.icon ?? 'two_wheeler');
    final sortOrderController = TextEditingController(text: (item?.sortOrder ?? 0).toString());
    bool isActive = item?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Arac Tipi Duzenle' : 'Yeni Arac Tipi Ekle'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'ID *',
                      hintText: 'motorcycle, bicycle, car, moto_taxi',
                    ),
                    enabled: !isEdit,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Ad *'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: iconController.text,
                    decoration: const InputDecoration(labelText: 'Ikon'),
                    items: const [
                      DropdownMenuItem(value: 'two_wheeler', child: Text('Motosiklet')),
                      DropdownMenuItem(value: 'sports_motorsports', child: Text('Moto Taksi')),
                      DropdownMenuItem(value: 'pedal_bike', child: Text('Bisiklet')),
                      DropdownMenuItem(value: 'directions_car', child: Text('Araba')),
                      DropdownMenuItem(value: 'electric_scooter', child: Text('Scooter')),
                      DropdownMenuItem(value: 'local_shipping', child: Text('Kamyonet')),
                    ],
                    onChanged: (v) => iconController.text = v ?? 'two_wheeler',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sortOrderController,
                    decoration: const InputDecoration(labelText: 'Sira'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (idController.text.isEmpty || nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID ve Ad zorunludur')),
                  );
                  return;
                }

                final data = {
                  'id': idController.text.toLowerCase().replaceAll(' ', '_'),
                  'name': nameController.text,
                  'icon': iconController.text,
                  'sort_order': int.tryParse(sortOrderController.text) ?? 0,
                  'is_active': isActive,
                };

                final supabase = ref.read(supabaseProvider);
                try {
                  if (isEdit) {
                    await supabase.from('courier_vehicle_types').update(data).eq('id', item.id);
                  } else {
                    await supabase.from('courier_vehicle_types').insert(data);
                  }
                  ref.invalidate(courierVehicleTypesProvider);
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Guncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _delete(CourierVehicleType item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arac Tipini Sil'),
        content: Text('"${item.name}" arac tipini silmek istediginize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final supabase = ref.read(supabaseProvider);
      try {
        await supabase.from('courier_vehicle_types').delete().eq('id', item.id);
        ref.invalidate(courierVehicleTypesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arac tipi silindi'), backgroundColor: AppColors.success),
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
  }
}
