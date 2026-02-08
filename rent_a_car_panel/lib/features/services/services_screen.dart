import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/supabase_config.dart';

// Services provider
final companyServicesProvider = FutureProvider.autoDispose((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) return <Map<String, dynamic>>[];

  final response = await client
      .from('rental_services')
      .select('*')
      .eq('company_id', companyId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(companyServicesProvider);

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
                const Row(
                  children: [
                    Icon(Icons.build, size: 32, color: AppColors.secondary),
                    SizedBox(width: 12),
                    Text(
                      'Ek Hizmetler',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddServiceDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Hizmet'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Musterilere sundugunuz ek hizmetleri yonetin',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Services list
            Expanded(
              child: servicesAsync.when(
                data: (services) {
                  if (services.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.build_outlined,
                              size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'Henuz ek hizmet eklenmemis',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _showAddServiceDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: const Text('Ilk Hizmeti Ekle'),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      return _buildServiceCard(
                          context, ref, services[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('Hata: $e',
                      style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(
      BuildContext context, WidgetRef ref, Map<String, dynamic> service) {
    final isActive = service['is_active'] as bool? ?? true;
    final priceType = service['price_type'] as String? ?? 'per_day';
    final price = (service['price'] as num?)?.toDouble() ?? 0;
    final icon = _getIconData(service['icon'] as String? ?? 'build');

    String priceTypeLabel;
    switch (priceType) {
      case 'per_day':
        priceTypeLabel = '/gun';
        break;
      case 'per_rental':
        priceTypeLabel = '/kiralama';
        break;
      case 'per_km':
        priceTypeLabel = '/km';
        break;
      default:
        priceTypeLabel = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.surfaceLight
              : AppColors.surfaceLight.withValues(alpha: 0.3),
        ),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary),
          ),
          title: Text(
            service['name'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            service['description'] as String? ?? '',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Price
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\u20BA${price.toStringAsFixed(0)}$priceTypeLabel',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Active toggle
              Switch(
                value: isActive,
                onChanged: (val) async {
                  final client = ref.read(supabaseClientProvider);
                  await client.from('rental_services').update({
                    'is_active': val,
                  }).eq('id', service['id']);
                  ref.invalidate(companyServicesProvider);
                },
                activeColor: AppColors.success,
              ),
              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppColors.textSecondary,
                onPressed: () =>
                    _showEditServiceDialog(context, ref, service),
              ),
              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.error,
                onPressed: () =>
                    _showDeleteConfirm(context, ref, service),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'gps_fixed':
        return Icons.gps_fixed;
      case 'child_care':
        return Icons.child_care;
      case 'person_add':
        return Icons.person_add;
      case 'wifi':
        return Icons.wifi;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'luggage':
        return Icons.luggage;
      case 'local_car_wash':
        return Icons.local_car_wash;
      case 'shield':
        return Icons.shield;
      case 'speed':
        return Icons.speed;
      default:
        return Icons.build;
    }
  }

  void _showAddServiceDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    String priceType = 'per_day';
    String icon = 'build';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Yeni Ek Hizmet'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Hizmet Adi *',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Aciklama',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Fiyat (TL) *',
                          prefixText: '\u20BA ',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priceType,
                        decoration: InputDecoration(
                          labelText: 'Fiyat Tipi',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'per_day', child: Text('Gunluk')),
                          DropdownMenuItem(
                              value: 'per_rental',
                              child: Text('Kiralama Basi')),
                          DropdownMenuItem(
                              value: 'per_km', child: Text('KM Basi')),
                        ],
                        onChanged: (val) {
                          setDialogState(() => priceType = val ?? 'per_day');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: icon,
                  decoration: InputDecoration(
                    labelText: 'Ikon',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    _iconDropdownItem('build', Icons.build, 'Varsayilan'),
                    _iconDropdownItem(
                        'gps_fixed', Icons.gps_fixed, 'GPS'),
                    _iconDropdownItem(
                        'child_care', Icons.child_care, 'Cocuk'),
                    _iconDropdownItem(
                        'person_add', Icons.person_add, 'Kisi'),
                    _iconDropdownItem('wifi', Icons.wifi, 'WiFi'),
                    _iconDropdownItem(
                        'ac_unit', Icons.ac_unit, 'Kar/Klima'),
                    _iconDropdownItem(
                        'luggage', Icons.luggage, 'Bagaj'),
                    _iconDropdownItem('local_car_wash',
                        Icons.local_car_wash, 'Yikama'),
                    _iconDropdownItem(
                        'shield', Icons.shield, 'Sigorta'),
                    _iconDropdownItem('speed', Icons.speed, 'Hiz'),
                  ],
                  onChanged: (val) {
                    setDialogState(() => icon = val ?? 'build');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Iptal', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  return;
                }
                final client = ref.read(supabaseClientProvider);
                final companyId =
                    await ref.read(companyIdProvider.future);

                await client.from('rental_services').insert({
                  'company_id': companyId,
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'price_type': priceType,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'icon': icon,
                  'is_active': true,
                });

                ref.invalidate(companyServicesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServiceDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> service) {
    final nameController =
        TextEditingController(text: service['name'] as String? ?? '');
    final descController =
        TextEditingController(text: service['description'] as String? ?? '');
    final priceController = TextEditingController(
        text: (service['price'] as num?)?.toStringAsFixed(0) ?? '0');
    String priceType = service['price_type'] as String? ?? 'per_day';
    String icon = service['icon'] as String? ?? 'build';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Hizmeti Duzenle'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Hizmet Adi *',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Aciklama',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Fiyat (TL) *',
                          prefixText: '\u20BA ',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priceType,
                        decoration: InputDecoration(
                          labelText: 'Fiyat Tipi',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'per_day', child: Text('Gunluk')),
                          DropdownMenuItem(
                              value: 'per_rental',
                              child: Text('Kiralama Basi')),
                          DropdownMenuItem(
                              value: 'per_km', child: Text('KM Basi')),
                        ],
                        onChanged: (val) {
                          setDialogState(() => priceType = val ?? 'per_day');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: icon,
                  decoration: InputDecoration(
                    labelText: 'Ikon',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    _iconDropdownItem('build', Icons.build, 'Varsayilan'),
                    _iconDropdownItem(
                        'gps_fixed', Icons.gps_fixed, 'GPS'),
                    _iconDropdownItem(
                        'child_care', Icons.child_care, 'Cocuk'),
                    _iconDropdownItem(
                        'person_add', Icons.person_add, 'Kisi'),
                    _iconDropdownItem('wifi', Icons.wifi, 'WiFi'),
                    _iconDropdownItem(
                        'ac_unit', Icons.ac_unit, 'Kar/Klima'),
                    _iconDropdownItem(
                        'luggage', Icons.luggage, 'Bagaj'),
                    _iconDropdownItem('local_car_wash',
                        Icons.local_car_wash, 'Yikama'),
                    _iconDropdownItem(
                        'shield', Icons.shield, 'Sigorta'),
                    _iconDropdownItem('speed', Icons.speed, 'Hiz'),
                  ],
                  onChanged: (val) {
                    setDialogState(() => icon = val ?? 'build');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Iptal', style: TextStyle(color: AppColors.error)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  return;
                }
                final client = ref.read(supabaseClientProvider);

                await client.from('rental_services').update({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'price_type': priceType,
                  'price': double.tryParse(priceController.text) ?? 0,
                  'icon': icon,
                }).eq('id', service['id']);

                ref.invalidate(companyServicesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guncelle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Hizmeti Sil'),
        content: Text(
            '"${service['name']}" hizmetini silmek istediginize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final client = ref.read(supabaseClientProvider);
              await client
                  .from('rental_services')
                  .delete()
                  .eq('id', service['id']);
              ref.invalidate(companyServicesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<String> _iconDropdownItem(
      String value, IconData icon, String label) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
